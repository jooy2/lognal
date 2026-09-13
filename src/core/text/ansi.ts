import type { TextColor, TextPart, TextStyle } from '../types.js';

const ESCAPE = '\x1b';
const BELL = '\x07';

/**
 * Turns text with ANSI escape codes into styled parts.
 *
 * Select Graphic Rendition codes (colors, bold, italic, underline and so on) become styles.
 * Every other escape sequence, such as cursor movement or an OSC hyperlink wrapper, is removed
 * so it cannot show up as stray characters. The style carries over between calls, the way a
 * terminal keeps it from one line to the next.
 */
export class AnsiParser {
	private style: TextStyle = {};

	/** Parses one piece of text, usually a line. */
	parse(text: string): TextPart[] {
		if (!text.includes(ESCAPE)) {
			return [this.createPart(text)];
		}

		const parts: TextPart[] = [];
		let buffer = '';
		let index = 0;

		const flush = (): void => {
			if (buffer) {
				parts.push(this.createPart(buffer));
				buffer = '';
			}
		};

		while (index < text.length) {
			const character = text[index];

			if (character !== ESCAPE) {
				buffer += character;
				index++;
				continue;
			}

			const next = text[index + 1];

			if (next === '[') {
				const end = findCsiEnd(text, index + 2);

				if (end < 0) {
					break;
				}

				if (text[end] === 'm') {
					flush();
					this.applySgr(text.slice(index + 2, end));
				}

				index = end + 1;
			} else if (next === ']') {
				index = findOscEnd(text, index + 2);
			} else {
				// A two-character escape such as `ESC c`, or a lone escape at the end.
				index += next === undefined ? 1 : 2;
			}
		}

		flush();

		return parts.length ? parts : [this.createPart('')];
	}

	/** Forgets the current style. */
	reset(): void {
		this.style = {};
	}

	private createPart(text: string): TextPart {
		const part: TextPart = { type: 'text', text };

		if (Object.keys(this.style).length > 0) {
			part.style = { ...this.style };
		}

		return part;
	}

	private applySgr(sequence: string): void {
		const codes = sequence === '' ? [0] : sequence.split(/[;:]/).map((code) => Number(code) || 0);
		const style = { ...this.style };

		for (let index = 0; index < codes.length; index++) {
			const code = codes[index];

			if (code === 0) {
				for (const key of Object.keys(style) as (keyof TextStyle)[]) {
					delete style[key];
				}
			} else if (code === 1) {
				style.bold = true;
			} else if (code === 2) {
				style.dim = true;
			} else if (code === 3) {
				style.italic = true;
			} else if (code === 4) {
				style.underline = true;
			} else if (code === 9) {
				style.strikethrough = true;
			} else if (code === 22) {
				delete style.bold;
				delete style.dim;
			} else if (code === 23) {
				delete style.italic;
			} else if (code === 24) {
				delete style.underline;
			} else if (code === 29) {
				delete style.strikethrough;
			} else if (code >= 30 && code <= 37) {
				style.color = code - 30;
			} else if (code >= 90 && code <= 97) {
				style.color = code - 90 + 8;
			} else if (code >= 40 && code <= 47) {
				style.background = code - 40;
			} else if (code >= 100 && code <= 107) {
				style.background = code - 100 + 8;
			} else if (code === 39) {
				delete style.color;
			} else if (code === 49) {
				delete style.background;
			} else if (code === 38 || code === 48) {
				const [color, used] = readExtendedColor(codes, index + 1);

				if (color !== undefined) {
					if (code === 38) {
						style.color = color;
					} else {
						style.background = color;
					}
				}

				index += used;
			}
		}

		this.style = style;
	}
}

/** Reads a `5;n` or `2;r;g;b` color after code 38 or 48. Returns the color and codes consumed. */
const readExtendedColor = (codes: number[], start: number): [TextColor | undefined, number] => {
	const mode = codes[start];

	if (mode === 5) {
		const index = codes[start + 1];

		return [index >= 0 && index <= 255 ? index : undefined, 2];
	}

	if (mode === 2) {
		const [red, green, blue] = codes.slice(start + 1, start + 4).map((value) => clampByte(value));

		return [`#${toHex(red)}${toHex(green)}${toHex(blue)}`, 4];
	}

	return [undefined, 0];
};

const clampByte = (value: number | undefined): number => {
	return Math.min(255, Math.max(0, value ?? 0));
};

const toHex = (value: number): string => {
	return value.toString(16).padStart(2, '0');
};

/** Returns the index of the final byte of a CSI sequence, or -1 if the text ends first. */
const findCsiEnd = (text: string, start: number): number => {
	for (let index = start; index < text.length; index++) {
		const code = text.charCodeAt(index);

		if (code >= 0x40 && code <= 0x7e) {
			return index;
		}
	}

	return -1;
};

/** Returns the index just after an OSC sequence, which ends with BEL or `ESC \`. */
const findOscEnd = (text: string, start: number): number => {
	for (let index = start; index < text.length; index++) {
		if (text[index] === BELL) {
			return index + 1;
		}

		if (text[index] === ESCAPE && text[index + 1] === '\\') {
			return index + 2;
		}
	}

	return text.length;
};

/** Removes every ANSI escape sequence from text. */
export const stripAnsi = (text: string): string => {
	return new AnsiParser()
		.parse(text)
		.map((part) => part.text)
		.join('');
};
