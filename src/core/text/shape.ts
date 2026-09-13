import {
	BREAK_KEEP,
	BREAK_NORMAL,
	BREAK_SPACE,
	BREAK_WIDE,
	type LineSpan,
	type ShapedLine,
	type ShapedSpan
} from '../layout/types.js';
import { splitGraphemes } from './graphemes.js';
import { clusterWidth, isHangul, type AmbiguousWidth } from './width.js';

export interface ShapeOptions {
	/** Cells between tab stops. */
	tabSize: number;
	/** Cells an East Asian Ambiguous character takes. */
	ambiguousWidth: AmbiguousWidth;
	/** The most clusters a line keeps. The rest is replaced with `…`. */
	maxClusters: number;
}

export const DEFAULT_SHAPE_OPTIONS: ShapeOptions = {
	tabSize: 8,
	ambiguousWidth: 1,
	maxClusters: 10000
};

const PRINTABLE_ASCII = /^[\x20-\x7e]*$/;
const SPECIAL_CHARACTER = /[\x00-\x1f\x7f-\x9f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]/;
const ELLIPSIS = '…';

/**
 * Returns the visible notation for a character that must not be drawn as is: a control
 * character, which would be invisible or move the cursor, or a bidirectional formatting
 * character, which can make a line read differently from what it contains.
 */
const notationOf = (code: number): string => {
	if (code < 0x20) {
		return `^${String.fromCharCode(code + 0x40)}`;
	}

	if (code === 0x7f) {
		return '^?';
	}

	return `<U+${code.toString(16).toUpperCase().padStart(4, '0')}>`;
};

class LineBuilder {
	readonly spans: ShapedSpan[] = [];
	readonly spanStarts: number[] = [];
	readonly clusters: string[] = [];
	readonly widths: number[] = [];
	readonly breaks: number[] = [];
	cells = 0;
	simple = true;
	full = false;

	constructor(readonly options: ShapeOptions) {}

	openSpan(span: ShapedSpan): void {
		this.spans.push(span);
		this.spanStarts.push(this.clusters.length);
	}

	addCluster(cluster: string, width: number, breakClass: number): void {
		if (this.clusters.length >= this.options.maxClusters) {
			this.full = true;

			return;
		}

		this.clusters.push(cluster);
		this.widths.push(width);
		this.breaks.push(breakClass);
		this.cells += width;
	}

	/** Drops clusters past `count`, and spans that no longer have a cluster. */
	truncate(count: number): void {
		this.clusters.length = count;
		this.widths.length = count;
		this.breaks.length = count;
		this.cells = this.widths.reduce((sum, width) => sum + width, 0);
		this.full = false;

		while (this.spanStarts.length > 0 && this.spanStarts[this.spanStarts.length - 1] >= count) {
			this.spanStarts.pop();
			this.spans.pop();
		}
	}

	addText(source: ShapedSpan, text: string): void {
		if (!text || this.full) {
			return;
		}

		this.openSpan({ ...source, text });

		if (PRINTABLE_ASCII.test(text)) {
			for (let index = 0; index < text.length && !this.full; index++) {
				const character = text[index];

				this.addCluster(character, 1, character === ' ' ? BREAK_SPACE : BREAK_NORMAL);
			}

			return;
		}

		this.simple = false;

		for (const cluster of splitGraphemes(text)) {
			if (this.full) {
				return;
			}

			const width = clusterWidth(cluster, this.options.ambiguousWidth);
			let breakClass = BREAK_NORMAL;

			if (cluster === ' ') {
				breakClass = BREAK_SPACE;
			} else if (width === 2) {
				breakClass = isHangul(cluster.codePointAt(0) ?? 0) ? BREAK_KEEP : BREAK_WIDE;
			}

			this.addCluster(cluster, width, breakClass);
		}
	}

	addSpan(span: LineSpan): void {
		if ('icon' in span) {
			this.openSpan({ text: '', icon: span.icon, expanded: span.expanded, action: span.action });
			this.simple = false;
			this.addCluster('', 2, BREAK_NORMAL);

			return;
		}

		const source: ShapedSpan = {
			text: '',
			token: span.token,
			style: span.style,
			action: span.action
		};
		const { text } = span;

		if (!SPECIAL_CHARACTER.test(text)) {
			this.addText(source, text);

			return;
		}

		let start = 0;

		for (let index = 0; index < text.length; index++) {
			if (!SPECIAL_CHARACTER.test(text[index])) {
				continue;
			}

			const code = text.charCodeAt(index);

			this.addText(source, text.slice(start, index));
			start = index + 1;

			if (code === 0x09) {
				const size = this.options.tabSize;

				this.addText(source, ' '.repeat(size - (this.cells % size)));
			} else {
				this.addText({ ...source, token: 'muted', style: undefined }, notationOf(code));
			}
		}

		this.addText(source, text.slice(start));
	}
}

/** Builds a simple line without splitting it, for the common case of one ASCII span. */
const shapeSimple = (span: ShapedSpan, indent: number): ShapedLine => {
	return {
		indent,
		spans: [span],
		spanStarts: Uint32Array.of(0),
		simple: true,
		text: span.text,
		clusters: null,
		widths: null,
		breaks: null,
		length: span.text.length,
		cells: span.text.length
	};
};

/**
 * Splits the spans of a logical line into clusters and measures them.
 *
 * Tabs become spaces up to the next tab stop, and control and bidirectional formatting
 * characters are replaced with a visible notation in the muted style.
 */
export const shapeLine = (
	spans: readonly LineSpan[],
	indent: number,
	options: ShapeOptions = DEFAULT_SHAPE_OPTIONS
): ShapedLine => {
	if (spans.length === 1) {
		const [span] = spans;

		if (
			!('icon' in span) &&
			span.text.length <= options.maxClusters &&
			PRINTABLE_ASCII.test(span.text)
		) {
			return shapeSimple(
				{ text: span.text, token: span.token, style: span.style, action: span.action },
				indent
			);
		}
	}

	const builder = new LineBuilder(options);

	for (const span of spans) {
		if (builder.full) {
			break;
		}

		builder.addSpan(span);
	}

	if (builder.full) {
		builder.truncate(Math.max(0, builder.clusters.length - 2));
		builder.openSpan({ text: ` ${ELLIPSIS}`, token: 'muted' });
		builder.addCluster(' ', 1, BREAK_SPACE);
		builder.addCluster(ELLIPSIS, 1, BREAK_NORMAL);
		builder.simple = false;
	}

	const text = builder.clusters.join('');
	const spanStarts = Uint32Array.from(builder.spanStarts);

	if (builder.simple) {
		return {
			indent,
			spans: builder.spans,
			spanStarts,
			simple: true,
			text,
			clusters: null,
			widths: null,
			breaks: null,
			length: builder.clusters.length,
			cells: builder.cells
		};
	}

	return {
		indent,
		spans: builder.spans,
		spanStarts,
		simple: false,
		text,
		clusters: builder.clusters,
		widths: Uint8Array.from(builder.widths),
		breaks: Uint8Array.from(builder.breaks),
		length: builder.clusters.length,
		cells: builder.cells
	};
};

/** Returns the width of a cluster of a shaped line. */
export const widthAt = (line: ShapedLine, index: number): number => {
	return line.widths ? line.widths[index] : 1;
};

/** Returns the break class of a cluster of a shaped line. */
export const breakAt = (line: ShapedLine, index: number): number => {
	if (line.breaks) {
		return line.breaks[index];
	}

	return line.text.charCodeAt(index) === 0x20 ? BREAK_SPACE : BREAK_NORMAL;
};

/** Returns the text of the clusters from `start` to `end`. */
export const textBetween = (line: ShapedLine, start: number, end: number): string => {
	return line.clusters ? line.clusters.slice(start, end).join('') : line.text.slice(start, end);
};
