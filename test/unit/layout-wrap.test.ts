import { describe, expect, it } from 'vitest';
import { LogLayout } from '../../src/core/layout/layout.ts';
import { LogStore } from '../../src/core/store.ts';
import { createConsole } from '../../src/sources/console/hook.ts';

const LONG_LINE = 'The quick brown fox jumps over the lazy dog while the logs keep coming in.';

describe('lines that do not wrap', () => {
	it('keeps a part with wrap set to false on one row and reports its width', () => {
		const store = new LogStore({ mergeRepeats: false });
		const layout = new LogLayout(store);

		layout.setColumns(20);
		store.write('a long line that wraps onto several rows');
		store.write('a long line that stays on a single row\nand a second line', { wrap: false });
		layout.sync();

		const rows = layout.getRows(0, layout.rowCount);

		expect(rows.filter((row) => row.entry.id === 1).length).toBeGreaterThan(1);
		expect(rows.filter((row) => row.entry.id === 2).length).toBe(2);
		expect(layout.maxCells).toBe('a long line that stays on a single row'.length);
	});

	it('keeps console.table from wrapping', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);

		layout.setColumns(16);
		createConsole(store).table([{ name: 'Alice', role: 'administrator' }]);
		layout.sync();

		expect(layout.rowCount).toBe(5);
	});

	it('does not report wrapped lines as wide', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);

		layout.setColumns(30);
		store.write(LONG_LINE.repeat(3));
		layout.sync();

		expect(layout.maxCells).toBeLessThanOrEqual(30);
	});
});
