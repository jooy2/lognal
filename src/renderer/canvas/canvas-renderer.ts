import type { RowRun, VisualRow } from '../../core/layout/types.js';
import type { LogEntry, TextStyle } from '../../core/types.js';
import type {
	CellMetrics,
	FontSettings,
	RenderFrame,
	RenderTheme,
	Renderer,
	RowDecoration
} from '../types.js';
import { DEFAULT_RENDER_THEME } from '../theme.js';
import { resolveAnsiColor } from './palette.js';

/** How long a measured glyph width stays cached, as a count of entries. */
const MEASURE_CACHE_SIZE = 4096;
const PRINTABLE_ASCII = /^[\x20-\x7e]*$/;
const WHITESPACE = /^\s*$/;

/**
 * Box-drawing characters drawn as lines, as bits for the arms that leave the cell center: up,
 * right, down and left. Drawing them lets table borders join across rows, which a font glyph
 * does not do once rows are taller than the font.
 */
const ARM_UP = 1;
const ARM_RIGHT = 2;
const ARM_DOWN = 4;
const ARM_LEFT = 8;
const BOX_ARMS = new Map<string, number>([
	['\u2500', ARM_LEFT | ARM_RIGHT],
	['\u2502', ARM_UP | ARM_DOWN],
	['\u250c', ARM_RIGHT | ARM_DOWN],
	['\u2510', ARM_LEFT | ARM_DOWN],
	['\u2514', ARM_UP | ARM_RIGHT],
	['\u2518', ARM_UP | ARM_LEFT],
	['\u251c', ARM_UP | ARM_DOWN | ARM_RIGHT],
	['\u2524', ARM_UP | ARM_DOWN | ARM_LEFT],
	['\u252c', ARM_LEFT | ARM_RIGHT | ARM_DOWN],
	['\u2534', ARM_LEFT | ARM_RIGHT | ARM_UP],
	['\u253c', ARM_UP | ARM_RIGHT | ARM_DOWN | ARM_LEFT],
	['\u256d', ARM_RIGHT | ARM_DOWN],
	['\u256e', ARM_LEFT | ARM_DOWN],
	['\u256f', ARM_UP | ARM_LEFT],
	['\u2570', ARM_UP | ARM_RIGHT]
]);

const fontString = (font: FontSettings, bold: boolean, italic: boolean): string => {
	const weight = bold ? Math.max(700, font.weight) : font.weight;

	return `${italic ? 'italic ' : ''}${weight} ${font.size}px ${font.family}`;
};

interface FontSetLike {
	load(font: string, text?: string): Promise<unknown[]>;
	status?: string;
	ready?: Promise<unknown>;
}

const documentFonts = (): FontSetLike | undefined => {
	return (globalThis as { document?: { fonts?: FontSetLike } }).document?.fonts;
};

/**
 * Draws the log on a `<canvas>` with the 2D context.
 *
 * Every frame repaints the visible rows. Text that is plain ASCII in one style is drawn with a
 * single `fillText` call; other text is drawn one grapheme cluster at a time at its grid
 * position, so wide characters and characters from a fallback font stay aligned. `fillText`'s
 * `maxWidth` squeezes a glyph that is wider than its cells instead of letting it overlap.
 */
export class CanvasRenderer implements Renderer {
	readonly element: HTMLCanvasElement;
	private readonly context: CanvasRenderingContext2D;
	private theme: RenderTheme = DEFAULT_RENDER_THEME;
	private font: FontSettings = {
		family: 'monospace',
		size: 13,
		weight: 400,
		lineHeight: 1.5
	};
	private metrics: CellMetrics = { width: 8, height: 20, baseline: 14 };
	private width = 0;
	private height = 0;
	private pixelRatio = 1;
	private readonly measureCache = new Map<string, number>();
	private readonly requestedGlyphs = new Set<string>();
	private pendingGlyphs = '';
	private glyphRequestScheduled = false;
	private fontsListener: (() => void) | null = null;
	private disposed = false;

	constructor(ownerDocument: Document = document) {
		this.element = ownerDocument.createElement('canvas');
		this.element.className = 'lognal-canvas';
		this.element.setAttribute('aria-hidden', 'true');
		// Set here as well as in the stylesheet: a canvas in the normal flow would grow its
		// container, and the container's new size would grow the canvas again.
		this.element.style.position = 'absolute';
		this.element.style.left = '0';
		this.element.style.top = '0';

		const context = this.element.getContext('2d', { alpha: false });

		if (!context) {
			throw new Error('lognal: the 2D canvas context is not available.');
		}

		this.context = context;
	}

	setTheme(theme: RenderTheme): void {
		this.theme = theme;
	}

	setFont(font: FontSettings): CellMetrics {
		this.font = font;
		this.measureCache.clear();
		this.requestedGlyphs.clear();

		const context = this.context;

		context.font = fontString(font, false, false);

		const sample = context.measureText('M'.repeat(20));
		const width = sample.width / 20;
		const height = Math.max(1, Math.round(font.size * font.lineHeight));
		const ascent =
			sample.fontBoundingBoxAscent ?? sample.actualBoundingBoxAscent ?? font.size * 0.8;
		const descent =
			sample.fontBoundingBoxDescent ?? sample.actualBoundingBoxDescent ?? font.size * 0.2;

		this.metrics = {
			width: width > 0 ? width : font.size * 0.6,
			height,
			baseline: Math.round((height - (ascent + descent)) / 2 + ascent)
		};

		return this.metrics;
	}

	getMetrics(): CellMetrics {
		return this.metrics;
	}

	resize(width: number, height: number, pixelRatio: number): void {
		this.width = Math.max(0, width);
		this.height = Math.max(0, height);
		this.pixelRatio = pixelRatio > 0 ? pixelRatio : 1;
		this.element.width = Math.max(1, Math.round(this.width * this.pixelRatio));
		this.element.height = Math.max(1, Math.round(this.height * this.pixelRatio));
		this.element.style.width = `${this.width}px`;
		this.element.style.height = `${this.height}px`;
	}

	onFontsChanged(listener: () => void): void {
		this.fontsListener = listener;
	}

	render(frame: RenderFrame): void {
		const context = this.context;
		const { width: cellWidth, height: rowHeight } = this.metrics;
		const gutterWidth = (frame.timestampCells + frame.markerCells) * cellWidth;
		const contentLeft = frame.paddingLeft + gutterWidth;

		context.setTransform(this.pixelRatio, 0, 0, this.pixelRatio, 0, 0);
		context.textBaseline = 'alphabetic';
		context.fillStyle = this.theme.background;
		context.fillRect(0, 0, this.width, this.height);

		frame.rows.forEach((row, index) => {
			const top = frame.offsetY + index * rowHeight;

			this.drawRowBackground(row, frame.decorations[index], top);
		});

		context.save();
		context.beginPath();
		context.rect(contentLeft, 0, Math.max(0, this.width - contentLeft), this.height);
		context.clip();

		frame.rows.forEach((row, index) => {
			const top = frame.offsetY + index * rowHeight;
			const left = contentLeft - frame.scrollX;

			this.drawDecoration(frame.decorations[index], left, top);
			this.drawRuns(row, left, top);
		});

		context.restore();

		frame.rows.forEach((row, index) => {
			const top = frame.offsetY + index * rowHeight;

			if (row.last) {
				context.fillStyle = this.theme.separator;
				context.fillRect(0, top + rowHeight - 1 / this.pixelRatio, this.width, 1 / this.pixelRatio);
			}

			if (row.first) {
				this.drawGutter(row.entry, frame, top);
			}
		});

		this.flushGlyphRequests();
	}

	dispose(): void {
		this.disposed = true;
		this.fontsListener = null;
		this.measureCache.clear();
		this.element.remove();
	}

	private drawRowBackground(
		row: VisualRow,
		decoration: RowDecoration | undefined,
		top: number
	): void {
		const { entry } = row;
		let color: string | null = null;

		if (entry.level === 'error') {
			color = this.theme.errorBackground;
		} else if (entry.level === 'warn') {
			color = this.theme.warnBackground;
		}

		if (color) {
			this.context.fillStyle = color;
			this.context.fillRect(0, top, this.width, this.metrics.height);
		}

		// The hover color is translucent, so it also shows on the background of a warning or an error.
		if (decoration?.hovered) {
			this.context.fillStyle = this.theme.hover;
			this.context.fillRect(0, top, this.width, this.metrics.height);
		}
	}

	private drawDecoration(decoration: RowDecoration | undefined, left: number, top: number): void {
		if (!decoration) {
			return;
		}

		const context = this.context;
		const { width: cellWidth, height: rowHeight } = this.metrics;

		if (decoration.matches) {
			context.fillStyle = this.theme.match;

			for (const [from, to] of decoration.matches) {
				context.fillRect(left + from * cellWidth, top, (to - from) * cellWidth, rowHeight);
			}
		}

		if (decoration.selection) {
			const [from, to] = decoration.selection;

			context.fillStyle = this.theme.selection;
			context.fillRect(left + from * cellWidth, top, Math.max(0, to - from) * cellWidth, rowHeight);
		}
	}

	private colorOf(run: RowRun, entry: LogEntry): string {
		if (run.style?.color !== undefined) {
			return resolveAnsiColor(run.style.color, this.theme.ansi);
		}

		if (run.token && run.token !== 'default') {
			return this.theme.tokens[run.token];
		}

		if (entry.kind === 'system') {
			return this.theme.muted;
		}

		if (entry.level === 'debug') {
			return this.theme.debug;
		}

		if (entry.level === 'error') {
			return this.theme.error;
		}

		if (entry.level === 'warn') {
			return this.theme.warn;
		}

		return this.theme.foreground;
	}

	private drawRuns(row: VisualRow, left: number, top: number): void {
		const context = this.context;
		const { width: cellWidth, height: rowHeight, baseline } = this.metrics;
		const y = top + baseline;
		let currentFont = '';

		for (const run of row.runs) {
			const x = left + run.column * cellWidth;
			const runWidth = run.cells * cellWidth;

			if (x > this.width || x + runWidth < 0) {
				continue;
			}

			const style: TextStyle | undefined = run.style;

			if (style?.background !== undefined) {
				context.fillStyle = resolveAnsiColor(style.background, this.theme.ansi);
				context.fillRect(x, top, runWidth, rowHeight);
			}

			if (run.icon === 'expander') {
				this.drawExpander(x, top, Boolean(run.expanded));
				continue;
			}

			if (WHITESPACE.test(run.text)) {
				continue;
			}

			const font = fontString(this.font, Boolean(style?.bold), Boolean(style?.italic));

			if (font !== currentFont) {
				context.font = font;
				currentFont = font;
			}

			const color = this.colorOf(run, row.entry);

			context.fillStyle = color;
			context.globalAlpha = style?.dim ? 0.6 : 1;

			if (run.simple) {
				context.fillText(run.text, x, y, runWidth);
			} else {
				let clusterLeft = x;

				run.clusters.forEach((cluster, index) => {
					const cells = run.widths[index] ?? 1;
					const slot = cells * cellWidth;

					const arms = BOX_ARMS.get(cluster);

					if (arms !== undefined) {
						this.drawBox(arms, clusterLeft, top);
					} else if (cluster && !WHITESPACE.test(cluster)) {
						const natural = this.measure(cluster, font);
						const drawn = Math.min(natural, slot);
						const offset = cells > 1 ? (slot - drawn) / 2 : 0;

						context.fillText(cluster, clusterLeft + offset, y, slot);
						this.requestGlyphs(cluster);
					}

					clusterLeft += slot;
				});
			}

			context.globalAlpha = 1;

			if (style?.underline) {
				context.fillRect(x, top + baseline + 2, runWidth, 1);
			}

			if (style?.strikethrough) {
				context.fillRect(x, top + Math.round(rowHeight / 2), runWidth, 1);
			}
		}
	}

	private drawBox(arms: number, left: number, top: number): void {
		const context = this.context;
		const { width: cellWidth, height: rowHeight } = this.metrics;
		const ratio = this.pixelRatio;
		const thickness = Math.max(1, Math.round((this.font.size / 13) * ratio)) / ratio;
		const snap = (value: number): number => Math.round(value * ratio) / ratio;
		const centerX = snap(left + cellWidth / 2 - thickness / 2);
		const centerY = snap(top + rowHeight / 2 - thickness / 2);
		const right = left + cellWidth;
		const bottom = top + rowHeight;

		if (arms & ARM_LEFT) {
			context.fillRect(left, centerY, centerX + thickness - left, thickness);
		}

		if (arms & ARM_RIGHT) {
			context.fillRect(centerX, centerY, right - centerX, thickness);
		}

		if (arms & ARM_UP) {
			context.fillRect(centerX, top, thickness, centerY + thickness - top);
		}

		if (arms & ARM_DOWN) {
			context.fillRect(centerX, centerY, thickness, bottom - centerY);
		}
	}

	private drawExpander(x: number, top: number, expanded: boolean): void {
		const context = this.context;
		const { width: cellWidth, height: rowHeight } = this.metrics;
		const size = Math.max(4, Math.round(this.font.size * 0.36));
		const centerX = x + cellWidth * 0.9;
		const centerY = top + rowHeight / 2;

		context.fillStyle = this.theme.muted;
		context.beginPath();

		if (expanded) {
			context.moveTo(centerX - size / 2, centerY - size / 4);
			context.lineTo(centerX + size / 2, centerY - size / 4);
			context.lineTo(centerX, centerY + size / 3);
		} else {
			context.moveTo(centerX - size / 4, centerY - size / 2);
			context.lineTo(centerX + size / 3, centerY);
			context.lineTo(centerX - size / 4, centerY + size / 2);
		}

		context.closePath();
		context.fill();
	}

	private drawGutter(entry: LogEntry, frame: RenderFrame, top: number): void {
		const context = this.context;
		const { width: cellWidth, height: rowHeight, baseline } = this.metrics;
		let x = frame.paddingLeft;

		if (frame.timestampCells > 0) {
			context.font = fontString(this.font, false, false);
			context.fillStyle = this.theme.muted;
			context.fillText(
				frame.formatTime(entry.time),
				x,
				top + baseline,
				(frame.timestampCells - 1) * cellWidth
			);
			x += frame.timestampCells * cellWidth;
		}

		// The marker sits in the first two cells of its column; the last cell is a gap.
		const centerX = x + cellWidth;
		const centerY = top + rowHeight / 2;
		const radius = Math.max(3, this.font.size * 0.32);

		if (entry.repeat > 1) {
			this.drawRepeatBadge(entry, x, top);

			return;
		}

		context.lineWidth = Math.max(1, this.font.size / 12);
		context.lineCap = 'round';
		context.lineJoin = 'round';

		if (entry.kind === 'input') {
			context.strokeStyle = this.theme.accent;
			context.beginPath();
			context.moveTo(centerX - radius * 0.45, centerY - radius * 0.8);
			context.lineTo(centerX + radius * 0.45, centerY);
			context.lineTo(centerX - radius * 0.45, centerY + radius * 0.8);
			context.stroke();

			return;
		}

		if (entry.kind === 'output') {
			context.strokeStyle = this.theme.muted;
			context.beginPath();
			context.moveTo(centerX + radius * 0.45, centerY - radius * 0.8);
			context.lineTo(centerX - radius * 0.45, centerY);
			context.lineTo(centerX + radius * 0.45, centerY + radius * 0.8);
			context.stroke();

			return;
		}

		if (entry.level === 'error') {
			context.fillStyle = this.theme.error;
			context.beginPath();
			context.arc(centerX, centerY, radius, 0, Math.PI * 2);
			context.fill();
			context.strokeStyle = this.theme.background;
			context.beginPath();
			context.moveTo(centerX - radius * 0.4, centerY - radius * 0.4);
			context.lineTo(centerX + radius * 0.4, centerY + radius * 0.4);
			context.moveTo(centerX + radius * 0.4, centerY - radius * 0.4);
			context.lineTo(centerX - radius * 0.4, centerY + radius * 0.4);
			context.stroke();
		} else if (entry.level === 'warn') {
			context.fillStyle = this.theme.warn;
			context.beginPath();
			context.moveTo(centerX, centerY - radius * 1.05);
			context.lineTo(centerX + radius * 1.1, centerY + radius * 0.85);
			context.lineTo(centerX - radius * 1.1, centerY + radius * 0.85);
			context.closePath();
			context.fill();
			context.fillStyle = this.theme.background;
			context.fillRect(
				centerX - context.lineWidth / 2,
				centerY - radius * 0.45,
				context.lineWidth,
				radius * 0.7
			);
			context.fillRect(
				centerX - context.lineWidth / 2,
				centerY + radius * 0.4,
				context.lineWidth,
				context.lineWidth
			);
		} else if (entry.level === 'info') {
			context.fillStyle = this.theme.info;
			context.beginPath();
			context.arc(centerX, centerY, radius * 0.55, 0, Math.PI * 2);
			context.fill();
		}
	}

	private drawRepeatBadge(entry: LogEntry, x: number, top: number): void {
		const context = this.context;
		const { width: cellWidth, height: rowHeight } = this.metrics;
		const label = entry.repeat > 99 ? '99+' : String(entry.repeat);
		const fontSize = Math.max(8, Math.round(this.font.size * 0.75));
		const badgeHeight = Math.min(rowHeight - 4, fontSize + 4);

		context.font = `600 ${fontSize}px ${this.font.family}`;

		const textWidth = context.measureText(label).width;
		const badgeWidth = Math.max(badgeHeight, textWidth + 8);
		const left = x + Math.max(0, cellWidth - badgeWidth / 2);
		const badgeTop = top + (rowHeight - badgeHeight) / 2;
		const color =
			entry.level === 'error'
				? this.theme.error
				: entry.level === 'warn'
					? this.theme.warn
					: this.theme.muted;

		context.fillStyle = color;
		context.beginPath();

		if (typeof context.roundRect === 'function') {
			context.roundRect(left, badgeTop, badgeWidth, badgeHeight, badgeHeight / 2);
		} else {
			context.rect(left, badgeTop, badgeWidth, badgeHeight);
		}

		context.fill();
		context.fillStyle = this.theme.background;
		context.textAlign = 'center';
		context.fillText(label, left + badgeWidth / 2, badgeTop + badgeHeight / 2 + fontSize * 0.36);
		context.textAlign = 'start';
	}

	private measure(cluster: string, font: string): number {
		const key = `${font}|${cluster}`;
		const cached = this.measureCache.get(key);

		if (cached !== undefined) {
			return cached;
		}

		const width = this.context.measureText(cluster).width;

		if (this.measureCache.size >= MEASURE_CACHE_SIZE) {
			this.measureCache.clear();
		}

		this.measureCache.set(key, width);

		return width;
	}

	/** Asks the browser to load web font faces that cover characters the frame drew. */
	private requestGlyphs(cluster: string): void {
		if (PRINTABLE_ASCII.test(cluster) || this.requestedGlyphs.has(cluster)) {
			return;
		}

		this.requestedGlyphs.add(cluster);
		this.pendingGlyphs += cluster;
	}

	private flushGlyphRequests(): void {
		const fonts = documentFonts();

		if (!this.pendingGlyphs || this.glyphRequestScheduled || !fonts) {
			return;
		}

		const text = this.pendingGlyphs;
		const font = fontString(this.font, false, false);

		this.pendingGlyphs = '';
		this.glyphRequestScheduled = true;

		fonts
			.load(font, text)
			.then((faces) => {
				this.glyphRequestScheduled = false;

				if (!this.disposed && faces.length > 0) {
					this.measureCache.clear();
					this.fontsListener?.();
				}
			})
			.catch(() => {
				this.glyphRequestScheduled = false;
			});
	}
}
