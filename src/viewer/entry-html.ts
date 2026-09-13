import type { LineTextSpan } from '../core/layout/types.js';
import type { LogEntry } from '../core/types.js';
import { resolveAnsiColor } from '../renderer/canvas/palette.js';
import type { FontSettings, RenderTheme } from '../renderer/types.js';

/** Characters a CSS color written into a `style` attribute may use. Anything else is dropped. */
const SAFE_COLOR = /^[#\w\s(),.%+\-/]+$/;

const escapeHtml = (text: string): string => {
	return text
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;');
};

const safeColor = (color: string): string | null => {
	return SAFE_COLOR.test(color) ? color : null;
};

/** The color of a span, the way the canvas renderer picks it. */
const colorOf = (span: LineTextSpan, entry: LogEntry, theme: RenderTheme): string => {
	if (span.style?.color !== undefined) {
		return resolveAnsiColor(span.style.color, theme.ansi);
	}

	if (span.token && span.token !== 'default') {
		return theme.tokens[span.token];
	}

	if (entry.kind === 'system') {
		return theme.muted;
	}

	if (entry.level === 'debug' || entry.level === 'error' || entry.level === 'warn') {
		return theme[entry.level];
	}

	return theme.foreground;
};

const spanHtml = (span: LineTextSpan, entry: LogEntry, theme: RenderTheme): string => {
	const declarations: string[] = [];
	const color = safeColor(colorOf(span, entry, theme));
	const style = span.style;

	if (color) {
		declarations.push(`color: ${color}`);
	}

	if (style?.background !== undefined) {
		const background = safeColor(resolveAnsiColor(style.background, theme.ansi));

		if (background) {
			declarations.push(`background-color: ${background}`);
		}
	}

	if (style?.bold) {
		declarations.push('font-weight: 700');
	}

	if (style?.italic) {
		declarations.push('font-style: italic');
	}

	if (style?.dim) {
		declarations.push('opacity: 0.7');
	}

	const lines = [style?.underline ? 'underline' : '', style?.strikethrough ? 'line-through' : '']
		.filter(Boolean)
		.join(' ');

	if (lines) {
		declarations.push(`text-decoration: ${lines}`);
	}

	return `<span style="${escapeHtml(declarations.join('; '))}">${escapeHtml(span.text)}</span>`;
};

/**
 * Writes the spans of entries as HTML with the colors of the theme, for the clipboard, one entry
 * after another. Text from the log is escaped, so it can never become markup.
 */
export const entriesHtml = (options: {
	entries: readonly { entry: LogEntry; spans: readonly LineTextSpan[] }[];
	theme: RenderTheme;
	font: FontSettings;
}): string => {
	const { entries, theme, font } = options;
	const background = safeColor(theme.background) ?? '#ffffff';
	const foreground = safeColor(theme.foreground) ?? '#000000';
	const block = [
		'margin: 0',
		'padding: 8px 12px',
		`color: ${foreground}`,
		`background-color: ${background}`,
		`font-family: ${font.family}`,
		`font-size: ${font.size}px`,
		`line-height: ${font.lineHeight}`,
		'white-space: pre-wrap'
	].join('; ');
	const content = entries
		.map(({ entry, spans }) => spans.map((span) => spanHtml(span, entry, theme)).join(''))
		.join('\n');

	return `<meta charset="utf-8"><pre style="${escapeHtml(block)}">${content}</pre>`;
};
