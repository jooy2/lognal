import type { StyleToken } from '../core/types.js';
import { DEFAULT_RENDER_THEME } from '../renderer/theme.js';
import type { FontSettings, RenderTheme } from '../renderer/types.js';

/** Which color scheme the viewer uses. `auto` follows the operating system setting. */
export type ThemeMode = 'auto' | 'light' | 'dark';

const TOKEN_NAMES: Exclude<StyleToken, 'default'>[] = [
	'muted',
	'string',
	'number',
	'boolean',
	'null',
	'key',
	'symbol',
	'function',
	'regexp',
	'date',
	'tag',
	'attribute',
	'error',
	'warn',
	'info',
	'accent'
];

export const DEFAULT_FONT: FontSettings = {
	family:
		'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "D2Coding", "Noto Sans Mono CJK KR", "Liberation Mono", monospace',
	size: 13,
	weight: 400,
	lineHeight: 1.6
};

/**
 * Reads the render colors from the `--lognal-*` custom properties of an element, so a theme is
 * written in CSS and the canvas follows it. A property that is not set keeps the default.
 */
export const readTheme = (element: Element): RenderTheme => {
	const style = getComputedStyle(element);
	const read = (name: string, fallback: string): string => {
		return style.getPropertyValue(`--lognal-${name}`).trim() || fallback;
	};
	const defaults = DEFAULT_RENDER_THEME;
	const tokens = {} as RenderTheme['tokens'];

	for (const token of TOKEN_NAMES) {
		tokens[token] = read(`token-${token}`, defaults.tokens[token]);
	}

	return {
		background: read('background', defaults.background),
		foreground: read('foreground', defaults.foreground),
		muted: read('muted', defaults.muted),
		accent: read('accent', defaults.accent),
		selection: read('selection', defaults.selection),
		match: read('match', defaults.match),
		separator: read('separator', defaults.separator),
		hover: read('hover', defaults.hover),
		error: read('error', defaults.error),
		errorBackground: read('error-background', defaults.errorBackground),
		warn: read('warn', defaults.warn),
		warnBackground: read('warn-background', defaults.warnBackground),
		info: read('info', defaults.info),
		debug: read('debug', defaults.debug),
		tokens,
		ansi: defaults.ansi.map((color, index) => read(`ansi-${index}`, color))
	};
};

/** Converts a CSS length in `px`, `rem` or `em` to pixels. Returns `NaN` for anything else. */
const toPixels = (value: string, element: Element): number => {
	const match = /^(-?[\d.]+)(px|rem|em)?$/i.exec(value);

	if (!match) {
		return Number.NaN;
	}

	const amount = Number.parseFloat(match[1]);
	const unit = (match[2] ?? 'px').toLowerCase();

	if (unit === 'rem') {
		return (
			amount * Number.parseFloat(getComputedStyle(element.ownerDocument.documentElement).fontSize)
		);
	}

	if (unit === 'em') {
		return amount * Number.parseFloat(getComputedStyle(element).fontSize);
	}

	return amount;
};

/**
 * Reads a line height as a multiple of the font size: `1.6` and `1.6em` stay `1.6`, `150%`
 * becomes `1.5`, and a length such as `20px` or `1.25rem` is divided by the font size.
 */
const toLineHeight = (value: string, fontSize: number, element: Element): number => {
	if (/^[\d.]+(em)?$/i.test(value)) {
		return Number.parseFloat(value);
	}

	if (value.endsWith('%')) {
		return Number.parseFloat(value) / 100;
	}

	return toPixels(value, element) / fontSize;
};

/**
 * Reads the font from the `--lognal-font-*` custom properties, with explicit options on top.
 * The size may be written in `px`, `rem` or `em`, and the line height as a number, a
 * percentage or a length.
 */
export const readFont = (element: Element, overrides: Partial<FontSettings>): FontSettings => {
	const style = getComputedStyle(element);
	const read = (name: string): string => style.getPropertyValue(`--lognal-${name}`).trim();
	const cssSize = toPixels(read('font-size'), element);
	const size = overrides.size ?? (cssSize > 0 ? cssSize : DEFAULT_FONT.size);
	const lineHeight = toLineHeight(read('line-height'), size, element);
	const weight = Number.parseFloat(read('font-weight'));

	return {
		family: overrides.family ?? (read('font-family') || DEFAULT_FONT.family),
		size,
		weight: overrides.weight ?? (weight > 0 ? weight : DEFAULT_FONT.weight),
		lineHeight: overrides.lineHeight ?? (lineHeight > 0 ? lineHeight : DEFAULT_FONT.lineHeight)
	};
};
