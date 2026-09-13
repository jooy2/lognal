/** How many removed items the index tolerates at the front before it compacts its arrays. */
const COMPACT_THRESHOLD = 4096;

/**
 * Keeps the number of rows of every visible entry, and answers which entry a row belongs to.
 *
 * Appending an entry and dropping entries from the front are cheap, which is what a log does
 * almost all the time. Changing row counts in the middle marks the running totals after the
 * first change as stale, and they are recomputed once, the next time a position is read, so
 * many changes in a row cost one pass.
 */
export class RowIndex {
	private counts: number[] = [];
	/** `sums[i]` is the number of rows before item `i`. It has one more element than `counts`. */
	private sums: number[] = [0];
	private start = 0;
	/** The first element of `sums` that is out of date, or `Infinity` when all are current. */
	private staleFrom = Number.POSITIVE_INFINITY;

	/** The number of items. */
	get length(): number {
		return this.counts.length - this.start;
	}

	/** The number of rows of all items. */
	get total(): number {
		this.refresh();

		return this.sums[this.counts.length] - this.sums[this.start];
	}

	push(rows: number): void {
		this.refresh();
		this.counts.push(rows);
		this.sums.push(this.sums[this.sums.length - 1] + rows);
	}

	/** Removes items from the front. */
	shift(count: number): void {
		this.refresh();
		this.start = Math.min(this.counts.length, this.start + count);

		if (this.start > COMPACT_THRESHOLD && this.start > this.counts.length / 2) {
			const base = this.sums[this.start];

			this.counts = this.counts.slice(this.start);
			this.sums = this.sums.slice(this.start).map((sum) => sum - base);
			this.start = 0;
		}
	}

	clear(): void {
		this.counts = [];
		this.sums = [0];
		this.start = 0;
		this.staleFrom = Number.POSITIVE_INFINITY;
	}

	/** Returns the number of rows of an item. */
	get(index: number): number {
		return this.counts[this.start + index] ?? 0;
	}

	/** Changes the number of rows of an item. */
	set(index: number, rows: number): void {
		const position = this.start + index;

		if (this.counts[position] === rows) {
			return;
		}

		this.counts[position] = rows;
		this.staleFrom = Math.min(this.staleFrom, position + 1);
	}

	/** Returns the first row of an item. */
	rowOf(index: number): number {
		this.refresh();

		return this.sums[this.start + index] - this.sums[this.start];
	}

	/** Returns the item that holds a row, or -1 when the row is past the end. */
	find(row: number): number {
		if (row < 0 || row >= this.total) {
			return -1;
		}

		const target = row + this.sums[this.start];
		let low = this.start;
		let high = this.counts.length - 1;

		while (low < high) {
			const middle = (low + high + 1) >> 1;

			if (this.sums[middle] <= target) {
				low = middle;
			} else {
				high = middle - 1;
			}
		}

		// Skip items with no rows, which share their first row with the next item.
		while (low < this.counts.length - 1 && this.counts[low] === 0) {
			low++;
		}

		return low - this.start;
	}

	private refresh(): void {
		if (this.staleFrom === Number.POSITIVE_INFINITY) {
			return;
		}

		for (let index = this.staleFrom; index < this.sums.length; index++) {
			this.sums[index] = this.sums[index - 1] + this.counts[index - 1];
		}

		this.staleFrom = Number.POSITIVE_INFINITY;
	}
}
