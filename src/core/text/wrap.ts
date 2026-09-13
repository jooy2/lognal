import { BREAK_SPACE, BREAK_WIDE, type ShapedLine, type WrapMode } from '../layout/types.js';
import { breakAt, widthAt } from './shape.js';

/**
 * Returns the index of the first cluster of every row a line wraps into.
 *
 * - `none` keeps the line on one row.
 * - `char` fills every row and breaks between any two clusters.
 * - `word` breaks after a space, or on either side of a wide character such as a Han
 *   ideograph. Hangul syllables keep words together, so Korean text breaks at spaces. A word
 *   longer than the row is broken between characters.
 *
 * A space that does not fit at the end of a row hangs past the edge, so a row never starts
 * with the space that ended the word before it.
 */
export const wrapLine = (line: ShapedLine, columns: number, mode: WrapMode): number[] => {
	const count = line.length;

	if (mode === 'none' || count === 0 || line.cells <= columns) {
		return [0];
	}

	const width = Math.max(1, columns);
	const isWord = mode === 'word';

	if (line.simple) {
		return wrapAscii(line.text, width, isWord);
	}

	const rows = [0];
	let rowStart = 0;
	let rowCells = 0;
	let breakIndex = -1;

	for (let index = 0; index < count; index++) {
		const clusterCells = widthAt(line, index);
		const breakClass = breakAt(line, index);

		if (isWord && index > rowStart) {
			const previous = breakAt(line, index - 1);

			if (
				(previous === BREAK_SPACE && breakClass !== BREAK_SPACE) ||
				previous === BREAK_WIDE ||
				breakClass === BREAK_WIDE
			) {
				breakIndex = index;
			}
		}

		if (rowCells > 0 && rowCells + clusterCells > width) {
			if (breakClass === BREAK_SPACE) {
				rowCells += clusterCells;
				continue;
			}

			const start = isWord && breakIndex > rowStart ? breakIndex : index;

			rows.push(start);
			rowStart = start;
			rowCells = 0;
			breakIndex = -1;

			for (let cluster = start; cluster < index; cluster++) {
				rowCells += widthAt(line, cluster);
			}

			// The carried-over part of a word can still leave no room for a wide character.
			if (rowCells > 0 && rowCells + clusterCells > width) {
				rows.push(index);
				rowStart = index;
				rowCells = 0;
			}
		}

		rowCells += clusterCells;
	}

	return rows;
};

/**
 * `wrapLine` for a line where every character is one cell and only spaces allow a break. It
 * follows the same rules without looking up widths and break classes, which makes laying out
 * a large plain-text log several times faster.
 */
const wrapAscii = (text: string, width: number, isWord: boolean): number[] => {
	const rows = [0];
	const count = text.length;
	let rowStart = 0;
	let rowCells = 0;
	let breakIndex = -1;

	for (let index = 0; index < count; index++) {
		const isSpace = text.charCodeAt(index) === 0x20;

		if (isWord && index > rowStart && !isSpace && text.charCodeAt(index - 1) === 0x20) {
			breakIndex = index;
		}

		if (rowCells > 0 && rowCells + 1 > width) {
			if (isSpace) {
				rowCells++;
				continue;
			}

			const start = isWord && breakIndex > rowStart ? breakIndex : index;

			rows.push(start);
			rowStart = start;
			rowCells = index - start;
			breakIndex = -1;
		}

		rowCells++;
	}

	return rows;
};
