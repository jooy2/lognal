import { measureCells, padCells, truncateCells } from '../../core/text/measure.js';
import type { ValueEntry, ValueNode } from '../../core/types.js';
import { previewValue } from '../../core/value/preview.js';

/** The most rows and columns a table shows, and the widest cell. */
const MAX_ROWS = 100;
const MAX_COLUMNS = 20;
const MAX_CELL_CELLS = 40;

const INDEX_COLUMN = '(index)';
const VALUES_COLUMN = 'Values';

const cellText = (node: ValueNode): string => {
	return previewValue(node, true)
		.map((span) => span.text)
		.join('');
};

const keyText = (entry: ValueEntry): string => {
	if (entry.keyValue) {
		return cellText(entry.keyValue);
	}

	return entry.key ?? '';
};

const isRowObject = (node: ValueNode): boolean => {
	return (node.kind === 'object' || node.kind === 'array') && node.children !== undefined;
};

/**
 * Draws a captured value as a text table with box-drawing characters, the way `console.table`
 * shows it: one row per property or item, one column per key of the row values, and a
 * `Values` column for rows that are not objects.
 *
 * Returns `null` when the value has no rows, in which case the caller logs it as usual.
 */
export const formatTable = (node: ValueNode, properties?: readonly string[]): string | null => {
	if (!node.children || node.children.length === 0) {
		return null;
	}

	const rows = node.children.slice(0, MAX_ROWS);
	const columns: string[] = [];
	let hasValues = false;

	for (const row of rows) {
		if (isRowObject(row.value)) {
			for (const child of row.value.children ?? []) {
				const key = child.key ?? '';

				if (!columns.includes(key) && columns.length < MAX_COLUMNS) {
					columns.push(key);
				}
			}
		} else {
			hasValues = true;
		}
	}

	const shownColumns = properties ? properties.filter((key) => columns.includes(key)) : columns;
	const header = [
		INDEX_COLUMN,
		...shownColumns,
		...(hasValues && !properties ? [VALUES_COLUMN] : [])
	];
	const body = rows.map((row) => {
		const cells = [keyText(row)];
		const children = isRowObject(row.value) ? (row.value.children ?? []) : [];

		for (const key of shownColumns) {
			const child = children.find((item) => item.key === key);

			cells.push(child ? cellText(child.value) : '');
		}

		if (hasValues && !properties) {
			cells.push(isRowObject(row.value) ? '' : cellText(row.value));
		}

		return cells.map((cell) => truncateCells(cell, MAX_CELL_CELLS));
	});
	const widths = header.map((title, column) =>
		Math.max(measureCells(title), ...body.map((cells) => measureCells(cells[column])))
	);
	const line = (left: string, middle: string, right: string): string => {
		return `${left}${widths.map((width) => '─'.repeat(width + 2)).join(middle)}${right}`;
	};
	const row = (cells: string[]): string => {
		return `│${cells.map((cell, column) => ` ${padCells(cell, widths[column])} `).join('│')}│`;
	};
	const lines = [
		line('┌', '┬', '┐'),
		row(header),
		line('├', '┼', '┤'),
		...body.map(row),
		line('└', '┴', '┘')
	];
	const hidden = node.children.length - rows.length + (node.omitted ?? 0);

	if (hidden > 0) {
		lines.push(`… ${hidden} more`);
	}

	return lines.join('\n');
};
