import { describe, expect, it } from 'vitest';
import { LogLayout } from '../../src/core/layout/layout.ts';
import { RowIndex } from '../../src/core/layout/row-index.ts';
import { LogStore } from '../../src/core/store.ts';

const LONG_LINE = 'The quick brown fox jumps over the lazy dog while the logs keep coming in.';

const fillStore = (count: number): LogStore => {
	const store = new LogStore({ mergeRepeats: false, maxEntries: Number.POSITIVE_INFINITY });

	for (let index = 0; index < count; index++) {
		store.write(`${index}: ${LONG_LINE.repeat((index % 3) + 1)}`);
	}

	return store;
};

describe('RowIndex', () => {
	it('keeps positions right after many changes in the middle', () => {
		const index = new RowIndex();
		const counts: number[] = [];

		for (let item = 0; item < 200; item++) {
			const rows = (item % 4) + 1;

			index.push(rows);
			counts.push(rows);
		}

		for (let step = 0; step < 300; step++) {
			const item = (step * 37) % counts.length;
			const rows = (step % 5) + 1;

			index.set(item, rows);
			counts[item] = rows;

			if (step % 7 === 0) {
				index.shift(1);
				counts.shift();
				index.push(2);
				counts.push(2);
			}
		}

		let row = 0;

		counts.forEach((rows, item) => {
			expect(index.rowOf(item)).toBe(row);
			expect(index.find(row)).toBe(item);
			row += rows;
		});

		expect(index.total).toBe(row);
	});
});

describe('estimated row counts', () => {
	it('estimates past the budget and measures the rest to the exact result', () => {
		const store = fillStore(300);
		const layout = new LogLayout(store);
		const reference = new LogLayout(store);

		layout.setColumns(120);
		layout.sync();
		reference.setColumns(30);
		reference.sync();

		const before = layout.positionsVersion;

		layout.setColumns(30);
		layout.sync(10);

		expect(layout.pendingCount).toBe(290);
		expect(layout.positionsVersion).toBeGreaterThan(before);

		// The estimate scales the previous row count, so it is close before any measuring.
		expect(Math.abs(layout.rowCount - reference.rowCount)).toBeLessThan(reference.rowCount * 0.2);

		expect(layout.measureAround(150, 5, 10)).toBe(true);
		expect(layout.rowsOf(150)).toBe(reference.rowsOf(150));

		while (layout.pendingCount > 0) {
			layout.measurePending(40, 150);
		}

		expect(layout.rowCount).toBe(reference.rowCount);
		expect(layout.rowOfEntry(299)).toBe(reference.rowOfEntry(299));
		expect(layout.getRows(400, 5).map((row) => row.runs.map((run) => run.text).join(''))).toEqual(
			reference.getRows(400, 5).map((row) => row.runs.map((run) => run.text).join(''))
		);
	});

	it('measures the entries nearest to the focus first', () => {
		const store = fillStore(100);
		const layout = new LogLayout(store);

		layout.setColumns(40);
		layout.sync(0);
		layout.measurePending(10, 50);

		const measured = [45, 46, 47, 48, 49, 50, 51, 52, 53, 54];
		const reference = new LogLayout(store);

		reference.setColumns(40);
		reference.sync();

		for (const entryId of measured) {
			expect(layout.rowsOf(entryId)).toBe(reference.rowsOf(entryId));
		}

		expect(layout.pendingCount).toBe(90);
	});

	it('changes the positions version when entries are dropped from the front', () => {
		const store = new LogStore({ maxEntries: 3, mergeRepeats: false });
		const layout = new LogLayout(store);

		store.write('a');
		layout.sync();

		const before = layout.positionsVersion;

		store.write('b');
		layout.sync();
		expect(layout.positionsVersion).toBe(before);

		store.write('c');
		store.write('d');
		layout.sync();
		expect(layout.positionsVersion).toBeGreaterThan(before);
	});

	it('locates a row within its entry', () => {
		const store = new LogStore({ mergeRepeats: false });
		const layout = new LogLayout(store);

		layout.setColumns(20);
		store.write('short');
		store.write(LONG_LINE);
		layout.sync();

		expect(layout.locateRow(2)).toMatchObject({ entry: { id: 2 }, entryRow: 1 });
		expect(layout.locateRow(layout.rowCount)).toBeNull();
	});
});
