import type { TextColor } from '../../core/types.js';

const CUBE_LEVELS = [0, 95, 135, 175, 215, 255];

const toHex = (value: number): string => {
	return value.toString(16).padStart(2, '0');
};

/**
 * Returns the CSS color for an ANSI color. Indexes 0 to 15 come from the theme, 16 to 231 are
 * the 6×6×6 color cube, and 232 to 255 are the gray ramp. Strings are used as they are.
 */
export const resolveAnsiColor = (color: TextColor, themeColors: readonly string[]): string => {
	if (typeof color === 'string') {
		return color;
	}

	if (color < 16) {
		return themeColors[color] ?? themeColors[7] ?? '#ffffff';
	}

	if (color < 232) {
		const index = color - 16;
		const red = CUBE_LEVELS[Math.floor(index / 36) % 6];
		const green = CUBE_LEVELS[Math.floor(index / 6) % 6];
		const blue = CUBE_LEVELS[index % 6];

		return `#${toHex(red)}${toHex(green)}${toHex(blue)}`;
	}

	const gray = 8 + (Math.min(color, 255) - 232) * 10;

	return `#${toHex(gray)}${toHex(gray)}${toHex(gray)}`;
};
