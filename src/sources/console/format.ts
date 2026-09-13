import type { LogPart, TextPart, TextStyle, ValueNode } from '../../core/types.js';

/** Captures a value for display. */
export type ValueCapture = (value: unknown) => ValueNode;

const SAFE_COLOR_FUNCTION = /^(rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\([\d\s.,%+\-/a-z]*\)$/i;
const SAFE_COLOR_HEX = /^#[0-9a-f]{3,8}$/i;
const SAFE_COLOR_NAME = /^[a-z]{3,30}$/i;
const SPECIFIER = /%([sdifoOc%])/g;

/** Returns whether a CSS color can be used as is. Anything that could load a resource is rejected. */
export const isSafeColor = (value: string): boolean => {
	const color = value.trim();

	return (
		SAFE_COLOR_HEX.test(color) || SAFE_COLOR_FUNCTION.test(color) || SAFE_COLOR_NAME.test(color)
	);
};

/** Splits a CSS value on spaces that are not inside parentheses. */
const splitCssValue = (value: string): string[] => {
	const tokens: string[] = [];
	let depth = 0;
	let current = '';

	for (const character of value) {
		if (character === '(') {
			depth++;
		} else if (character === ')') {
			depth = Math.max(0, depth - 1);
		}

		if (/\s/.test(character) && depth === 0) {
			if (current) {
				tokens.push(current);
				current = '';
			}
		} else {
			current += character;
		}
	}

	if (current) {
		tokens.push(current);
	}

	return tokens;
};

/**
 * Reads the CSS given to `%c` and keeps only what the viewer can draw: text and background
 * color, weight, style and decoration. Everything else is ignored, including any value that
 * refers to a URL, so a log message cannot make the page load anything.
 */
export const parseConsoleCss = (css: string): TextStyle | undefined => {
	const style: TextStyle = {};

	for (const declaration of css.split(';')) {
		const separator = declaration.indexOf(':');

		if (separator < 0) {
			continue;
		}

		const property = declaration.slice(0, separator).trim().toLowerCase();
		const value = declaration.slice(separator + 1).trim();

		if (property === 'color' && isSafeColor(value)) {
			style.color = value;
		} else if (property === 'background' || property === 'background-color') {
			const color = splitCssValue(value).find((token) => isSafeColor(token));

			if (color) {
				style.background = color;
			}
		} else if (property === 'font-weight') {
			const weight = Number(value);

			if (value === 'bold' || value === 'bolder' || weight >= 600) {
				style.bold = true;
			}
		} else if (property === 'font-style' && /^(italic|oblique)/i.test(value)) {
			style.italic = true;
		} else if (property === 'text-decoration' || property === 'text-decoration-line') {
			if (/underline/i.test(value)) {
				style.underline = true;
			}

			if (/line-through/i.test(value)) {
				style.strikethrough = true;
			}
		}
	}

	return Object.keys(style).length > 0 ? style : undefined;
};

const toText = (value: unknown): string => {
	if (typeof value === 'string') {
		return value;
	}

	try {
		return String(value);
	} catch {
		return Object.prototype.toString.call(value);
	}
};

const toInteger = (value: unknown): string => {
	return typeof value === 'symbol' ? 'NaN' : String(parseInt(toText(value), 10));
};

const toFloat = (value: unknown): string => {
	return typeof value === 'symbol' ? 'NaN' : String(parseFloat(toText(value)));
};

/**
 * Applies the format specifiers in the first argument, following the Formatter operation of
 * the Console Standard, and returns the parts of the message together with the arguments the
 * specifiers did not consume.
 *
 * `%s` converts with `String`, `%d` and `%i` with `parseInt`, `%f` with `parseFloat`, `%o`
 * and `%O` insert the value itself, and `%c` styles the text that follows it. `%%` writes a
 * percent sign. A specifier with no argument left stays in the text as written.
 */
export const applyFormat = (
	args: readonly unknown[],
	capture: ValueCapture
): { parts: LogPart[]; rest: unknown[] } => {
	const [format, ...values] = args;
	const parts: LogPart[] = [];

	if (typeof format !== 'string') {
		return { parts, rest: [...args] };
	}

	let style: TextStyle | undefined;
	let text = '';
	let last = 0;
	let consumed = 0;

	const flush = (): void => {
		if (text) {
			const part: TextPart = { type: 'text', text };

			if (style) {
				part.style = style;
			}

			parts.push(part);
			text = '';
		}
	};

	for (const match of format.matchAll(SPECIFIER)) {
		const specifier = match[1];
		const index = match.index ?? 0;

		text += format.slice(last, index);
		last = index + match[0].length;

		if (specifier === '%') {
			text += '%';
			continue;
		}

		if (consumed >= values.length) {
			text += match[0];
			continue;
		}

		const value = values[consumed++];

		switch (specifier) {
			case 's':
				text += toText(value);
				break;
			case 'd':
			case 'i':
				text += toInteger(value);
				break;
			case 'f':
				text += toFloat(value);
				break;
			case 'c':
				flush();
				style = parseConsoleCss(toText(value));
				break;
			default:
				flush();
				parts.push({ type: 'value', value: capture(value) });
				break;
		}
	}

	text += format.slice(last);
	flush();

	return { parts, rest: values.slice(consumed) };
};

/**
 * Turns the arguments of a console call into the parts of an entry.
 *
 * With more than one argument and a string first, the format specifiers are applied. The
 * remaining arguments follow, separated by spaces: strings as plain text and everything else
 * as a captured value.
 */
export const formatArguments = (args: readonly unknown[], capture: ValueCapture): LogPart[] => {
	let parts: LogPart[] = [];
	let rest: unknown[] = [...args];

	if (args.length > 1 && typeof args[0] === 'string') {
		const formatted = applyFormat(args, capture);

		parts = formatted.parts;
		rest = formatted.rest;
	}

	for (const value of rest) {
		if (parts.length > 0) {
			parts.push({ type: 'text', text: ' ' });
		}

		parts.push(
			typeof value === 'string'
				? { type: 'text', text: value }
				: { type: 'value', value: capture(value) }
		);
	}

	return parts;
};
