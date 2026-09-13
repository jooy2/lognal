import { splitGraphemes } from './graphemes.js';
import { clusterWidth, type AmbiguousWidth } from './width.js';

const PRINTABLE_ASCII = /^[\x20-\x7e]*$/;

/** Returns how many cells a string takes on one row. */
export const measureCells = (text: string, ambiguousWidth: AmbiguousWidth = 1): number => {
	if (PRINTABLE_ASCII.test(text)) {
		return text.length;
	}

	let cells = 0;

	for (const cluster of splitGraphemes(text)) {
		cells += clusterWidth(cluster, ambiguousWidth);
	}

	return cells;
};

/**
 * Cuts a string to at most `maxCells` cells, ending it with `…` when anything was cut.
 * A wide character that would cross the limit is left out rather than split.
 */
export const truncateCells = (
	text: string,
	maxCells: number,
	ambiguousWidth: AmbiguousWidth = 1
): string => {
	if (measureCells(text, ambiguousWidth) <= maxCells) {
		return text;
	}

	let result = '';
	let cells = 0;

	for (const cluster of splitGraphemes(text)) {
		const width = clusterWidth(cluster, ambiguousWidth);

		if (cells + width > maxCells - 1) {
			break;
		}

		result += cluster;
		cells += width;
	}

	return `${result}…`;
};

/** Pads a string with spaces on the right to `cells` cells. */
export const padCells = (
	text: string,
	cells: number,
	ambiguousWidth: AmbiguousWidth = 1
): string => {
	return text + ' '.repeat(Math.max(0, cells - measureCells(text, ambiguousWidth)));
};
