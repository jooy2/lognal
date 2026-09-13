import { compileFilter, type CompiledFilter, type LogFilter } from '../filter.js';
import type { LogStore, StoreChange } from '../store.js';
import {
	DEFAULT_SHAPE_OPTIONS,
	shapeLine,
	textBetween,
	widthAt,
	type ShapeOptions
} from '../text/shape.js';
import { wrapLine } from '../text/wrap.js';
import type { LogEntry } from '../types.js';
import { buildEntryLines, INDENT_CELLS, isExpandedByDefault } from './entry-lines.js';
import { RowIndex } from './row-index.js';
import type { LineAction, RowRun, ShapedLine, TextPosition, VisualRow, WrapMode } from './types.js';

export interface LayoutOptions extends ShapeOptions {
	/** How lines longer than the viewer are handled. */
	wrap: WrapMode;
}

export const DEFAULT_LAYOUT_OPTIONS: LayoutOptions = {
	...DEFAULT_SHAPE_OPTIONS,
	wrap: 'word'
};

/** The fewest columns a line wraps into, however deeply it is indented. */
const MIN_WRAP_COLUMNS = 16;

/** How many entries keep their shaped lines in memory. */
const LAYOUT_CACHE_SIZE = 4000;

const PRINTABLE_ASCII = /^[\x20-\x7e]*$/;
const WORD_CHARACTER = /^[\p{L}\p{N}\p{M}_$]/u;

interface EntryLayout {
	stateKey: number;
	optionsVersion: number;
	lines: ShapedLine[];
	wrapKey: string;
	wraps: number[][];
	rows: number;
	cells: number;
}

interface RowCount {
	stateKey: number;
	layoutVersion: number;
	rows: number;
}

interface Expansion {
	version: number;
	paths: Map<string, boolean>;
}

const cellsBetween = (line: ShapedLine, start: number, end: number): number => {
	if (!line.widths) {
		return end - start;
	}

	let cells = 0;

	for (let index = start; index < end; index++) {
		cells += line.widths[index];
	}

	return cells;
};

/** Returns the index of the span that holds a cluster. */
const spanAt = (line: ShapedLine, cluster: number): number => {
	const starts = line.spanStarts;
	let low = 0;
	let high = starts.length - 1;

	while (low < high) {
		const middle = (low + high + 1) >> 1;

		if (starts[middle] <= cluster) {
			low = middle;
		} else {
			high = middle - 1;
		}
	}

	return low;
};

const comparePositions = (a: TextPosition, b: TextPosition): number => {
	return a.entryId - b.entryId || a.line - b.line || a.cell - b.cell;
};

/**
 * Turns the entries of a store into rows for a viewer of a given width.
 *
 * The layout decides which entries are visible (the filter and collapsed groups), how each
 * entry breaks into lines and rows, and which values are expanded. It works from the store's
 * change notifications, and does the pending work when `sync` is called, so any number of
 * messages between two frames costs one update.
 */
export class LogLayout {
	private options: LayoutOptions;
	private optionsVersion = 0;
	private layoutVersion = 0;
	private columns = 80;
	private filter: CompiledFilter = compileFilter(null);
	private visible: LogEntry[] = [];
	private visibleStart = 0;
	private readonly rowIndex = new RowIndex();
	private readonly layouts = new Map<number, EntryLayout>();
	private readonly rowCounts = new Map<number, RowCount>();
	private readonly expansions = new Map<number, Expansion>();
	private lastSyncedId = 0;
	private needsRebuild = true;
	private dirty = true;
	private widest = 0;
	private readonly unsubscribe: () => void;

	constructor(
		private readonly store: LogStore,
		options: Partial<LayoutOptions> = {}
	) {
		this.options = { ...DEFAULT_LAYOUT_OPTIONS, ...options };
		this.unsubscribe = store.subscribe((change) => this.onStoreChange(change));
	}

	/** The number of rows of all visible entries. Call `sync` first. */
	get rowCount(): number {
		return this.rowIndex.total;
	}

	/** The number of visible entries. Call `sync` first. */
	get visibleCount(): number {
		return this.visible.length - this.visibleStart;
	}

	/** The widest row seen, in cells, including indentation. */
	get maxCells(): number {
		return this.widest;
	}

	/** Whether the store changed since the last `sync`. */
	get isDirty(): boolean {
		return this.dirty;
	}

	getOptions(): Readonly<LayoutOptions> {
		return this.options;
	}

	setOptions(options: Partial<LayoutOptions>): void {
		const next = { ...this.options, ...options };
		const shapeChanged =
			next.tabSize !== this.options.tabSize ||
			next.ambiguousWidth !== this.options.ambiguousWidth ||
			next.maxClusters !== this.options.maxClusters;

		if (!shapeChanged && next.wrap === this.options.wrap) {
			return;
		}

		this.options = next;

		if (shapeChanged) {
			this.optionsVersion++;
			this.layouts.clear();
		}

		this.invalidateRows();
	}

	/** Sets the number of columns rows wrap into. */
	setColumns(columns: number): void {
		const next = Math.max(1, Math.floor(columns));

		if (next === this.columns) {
			return;
		}

		this.columns = next;

		if (this.options.wrap !== 'none') {
			this.invalidateRows();
		}
	}

	/** Sets which entries are visible. Returns the compiled filter, which reports a bad pattern. */
	setFilter(filter: LogFilter | null): CompiledFilter {
		this.filter = compileFilter(filter);
		this.needsRebuild = true;
		this.dirty = true;

		return this.filter;
	}

	/** The compiled filter in use. */
	getFilter(): CompiledFilter {
		return this.filter;
	}

	/** Applies pending store changes. Returns whether anything changed. */
	sync(): boolean {
		if (!this.dirty) {
			return false;
		}

		this.dirty = false;

		if (this.needsRebuild) {
			this.rebuild();

			return true;
		}

		const firstId = this.store.firstId;
		let trimmed = 0;

		while (
			this.visibleStart + trimmed < this.visible.length &&
			this.visible[this.visibleStart + trimmed].id < firstId
		) {
			this.forget(this.visible[this.visibleStart + trimmed].id);
			trimmed++;
		}

		if (trimmed > 0) {
			this.visibleStart += trimmed;
			this.rowIndex.shift(trimmed);
			this.compactVisible();
		}

		const lastId = this.store.lastId;

		for (let id = Math.max(this.lastSyncedId + 1, firstId); id <= lastId; id++) {
			const entry = this.store.get(id);

			if (entry && this.isVisible(entry)) {
				this.visible.push(entry);
				this.rowIndex.push(this.countRows(entry));
			}
		}

		this.lastSyncedId = lastId;

		return true;
	}

	/** Returns rows starting at a row index. Call `sync` first. */
	getRows(start: number, count: number): VisualRow[] {
		const rows: VisualRow[] = [];
		let index = this.rowIndex.find(Math.max(0, start));

		if (index < 0) {
			return rows;
		}

		let skip = start - this.rowIndex.rowOf(index);

		while (rows.length < count && index < this.visibleCount) {
			const entry = this.visible[this.visibleStart + index];
			const layout = this.layoutOf(entry);
			let entryRow = 0;

			for (let lineIndex = 0; lineIndex < layout.lines.length; lineIndex++) {
				const line = layout.lines[lineIndex];
				const wraps = layout.wraps[lineIndex];
				let startCell = 0;

				for (let lineRow = 0; lineRow < wraps.length; lineRow++) {
					const from = wraps[lineRow];
					const to = lineRow + 1 < wraps.length ? wraps[lineRow + 1] : line.length;

					if (entryRow >= skip && rows.length < count) {
						rows.push({
							entry,
							line: lineIndex,
							lineRow,
							entryRow,
							first: entryRow === 0,
							last: entryRow === layout.rows - 1,
							indent: line.indent,
							startCell,
							cells: cellsBetween(line, from, to),
							runs: this.buildRuns(line, from, to)
						});
					}

					startCell += cellsBetween(line, from, to);
					entryRow++;
				}
			}

			skip = 0;
			index++;
		}

		return rows;
	}

	/** Returns the entry at a visible position, where 0 is the oldest visible entry. */
	entryAt(index: number): LogEntry | undefined {
		return index >= 0 && index < this.visibleCount
			? this.visible[this.visibleStart + index]
			: undefined;
	}

	/** Returns the visible position of an entry, or -1 when it is not visible. */
	indexOf(entryId: number): number {
		let low = this.visibleStart;
		let high = this.visible.length - 1;

		while (low <= high) {
			const middle = (low + high) >> 1;
			const id = this.visible[middle].id;

			if (id === entryId) {
				return middle - this.visibleStart;
			}

			if (id < entryId) {
				low = middle + 1;
			} else {
				high = middle - 1;
			}
		}

		return -1;
	}

	/** Returns the first row of an entry, or -1 when it is not visible. */
	rowOfEntry(entryId: number): number {
		const index = this.indexOf(entryId);

		return index < 0 ? -1 : this.rowIndex.rowOf(index);
	}

	/** Returns whether the value at a path of an entry is expanded. */
	isExpanded(entry: LogEntry, path: string): boolean {
		return this.expansions.get(entry.id)?.paths.get(path) ?? isExpandedByDefault(entry, path);
	}

	/** Runs the action of a clicked span. */
	runAction(entryId: number, action: LineAction): void {
		const entry = this.store.get(entryId);

		if (!entry) {
			return;
		}

		if (action.type === 'toggle-group') {
			this.store.setCollapsed(entryId, !entry.collapsed);

			return;
		}

		if (action.type === 'toggle-value') {
			this.setExpanded(entry, action.path, !this.isExpanded(entry, action.path));
		}
	}

	/** Expands or collapses the value at a path of an entry. */
	setExpanded(entry: LogEntry, path: string, expanded: boolean): void {
		const expansion = this.expansions.get(entry.id) ?? {
			version: 0,
			paths: new Map()
		};

		expansion.paths.set(path, expanded);
		expansion.version++;
		this.expansions.set(entry.id, expansion);

		const index = this.indexOf(entry.id);

		if (index >= 0) {
			this.rowIndex.set(index, this.countRows(entry));
		}
	}

	/**
	 * Returns the text position under a row and a column of the content area. The position
	 * snaps to the nearest boundary between clusters.
	 */
	positionAt(row: number, column: number): TextPosition | null {
		const total = this.rowCount;

		if (total === 0) {
			return null;
		}

		const [visualRow] = this.getRows(Math.min(Math.max(0, row), total - 1), 1);

		if (!visualRow) {
			return null;
		}

		if (row >= total) {
			return {
				entryId: visualRow.entry.id,
				line: visualRow.line,
				cell: visualRow.startCell + visualRow.cells
			};
		}

		const target = Math.max(0, column - visualRow.indent);
		let offset = 0;
		let cell = visualRow.cells;

		for (const run of visualRow.runs) {
			if (target >= offset + run.cells) {
				offset += run.cells;
				continue;
			}

			if (run.simple) {
				cell = target;
			} else {
				cell = offset;

				for (const width of run.widths) {
					if (target < cell + width) {
						cell = target - cell < width / 2 ? cell : cell + width;
						break;
					}

					cell += width;
				}
			}

			break;
		}

		return {
			entryId: visualRow.entry.id,
			line: visualRow.line,
			cell: visualRow.startCell + cell
		};
	}

	/**
	 * Returns the start and end of the word at a position: a run of letters, digits, marks and
	 * underscores. On any other character, the range covers that character alone.
	 */
	wordAt(position: TextPosition): [TextPosition, TextPosition] | null {
		const index = this.indexOf(position.entryId);

		if (index < 0) {
			return null;
		}

		const entry = this.visible[this.visibleStart + index];
		const line = this.layoutOf(entry).lines[position.line];

		if (!line || line.length === 0) {
			return null;
		}

		const starts: number[] = [];
		let cell = 0;
		let target = line.length - 1;

		for (let cluster = 0; cluster < line.length; cluster++) {
			starts.push(cell);

			if (target === line.length - 1 && cell + widthAt(line, cluster) > position.cell) {
				target = cluster;
			}

			cell += widthAt(line, cluster);
		}

		starts.push(cell);

		const isWord = (cluster: number): boolean =>
			WORD_CHARACTER.test(textBetween(line, cluster, cluster + 1));
		let first = target;
		let last = target;

		if (isWord(target)) {
			while (first > 0 && isWord(first - 1)) {
				first--;
			}

			while (last < line.length - 1 && isWord(last + 1)) {
				last++;
			}
		}

		return [
			{ entryId: entry.id, line: position.line, cell: starts[first] },
			{ entryId: entry.id, line: position.line, cell: starts[last + 1] }
		];
	}

	/** Returns the text between two positions, one line of the output per logical line. */
	getText(from: TextPosition, to: TextPosition): string {
		const [start, end] = comparePositions(from, to) <= 0 ? [from, to] : [to, from];
		const lines: string[] = [];
		let index = this.firstIndexFrom(start.entryId);

		for (; index < this.visibleCount; index++) {
			const entry = this.visible[this.visibleStart + index];

			if (entry.id > end.entryId) {
				break;
			}

			const layout = this.layoutOf(entry);
			const baseIndent = entry.groups.length * INDENT_CELLS;

			for (let lineIndex = 0; lineIndex < layout.lines.length; lineIndex++) {
				if (entry.id === start.entryId && lineIndex < start.line) {
					continue;
				}

				if (entry.id === end.entryId && lineIndex > end.line) {
					break;
				}

				const line = layout.lines[lineIndex];
				const fromCell = entry.id === start.entryId && lineIndex === start.line ? start.cell : 0;
				const toCell = entry.id === end.entryId && lineIndex === end.line ? end.cell : Infinity;
				const indent = fromCell === 0 ? ' '.repeat(Math.max(0, line.indent - baseIndent)) : '';

				lines.push(indent + this.textInCells(line, fromCell, toCell));
			}
		}

		return lines.join('\n');
	}

	/** Returns the whole text of the visible entries. */
	getAllText(): string {
		const first = this.entryAt(0);
		const last = this.entryAt(this.visibleCount - 1);

		if (!first || !last) {
			return '';
		}

		return this.getText(
			{ entryId: first.id, line: 0, cell: 0 },
			{
				entryId: last.id,
				line: Number.MAX_SAFE_INTEGER,
				cell: Number.MAX_SAFE_INTEGER
			}
		);
	}

	/** Stops listening to the store. */
	dispose(): void {
		this.unsubscribe();
		this.layouts.clear();
		this.rowCounts.clear();
		this.expansions.clear();
	}

	private onStoreChange(change: StoreChange): void {
		this.dirty = true;

		if (change.type === 'clear') {
			this.needsRebuild = true;
			this.layouts.clear();
			this.rowCounts.clear();
			this.expansions.clear();
		} else if (change.type === 'update' && change.entry.kind === 'group') {
			this.needsRebuild = true;
		}
	}

	private invalidateRows(): void {
		this.layoutVersion++;
		this.needsRebuild = true;
		this.dirty = true;
	}

	private rebuild(): void {
		this.needsRebuild = false;
		this.visible = [];
		this.visibleStart = 0;
		this.rowIndex.clear();
		this.widest = 0;

		for (let index = 0; index < this.store.size; index++) {
			const entry = this.store.at(index) as LogEntry;

			if (this.isVisible(entry)) {
				this.visible.push(entry);
				this.rowIndex.push(this.countRows(entry));
			}
		}

		this.lastSyncedId = this.store.lastId;
		this.pruneCaches();
	}

	private isVisible(entry: LogEntry): boolean {
		if (this.filter.matches && !this.filter.matches(entry)) {
			return false;
		}

		for (const groupId of entry.groups) {
			if (this.store.get(groupId)?.collapsed) {
				return false;
			}
		}

		return true;
	}

	private stateKeyOf(entry: LogEntry): number {
		const version = this.expansions.get(entry.id)?.version ?? 0;

		return version * 2 + (entry.collapsed ? 1 : 0);
	}

	private countRows(entry: LogEntry): number {
		const stateKey = this.stateKeyOf(entry);
		const cached = this.rowCounts.get(entry.id);

		if (cached && cached.stateKey === stateKey && cached.layoutVersion === this.layoutVersion) {
			return cached.rows;
		}

		const rows = this.countPlainRows(entry) ?? this.layoutOf(entry).rows;

		this.rowCounts.set(entry.id, {
			stateKey,
			layoutVersion: this.layoutVersion,
			rows
		});

		return rows;
	}

	/**
	 * Counts the rows of the most common entry, one line of plain ASCII text, without building and
	 * caching its layout. Returns `null` for any other entry.
	 */
	private countPlainRows(entry: LogEntry): number | null {
		if (entry.kind !== 'message' || entry.groups.length > 0 || entry.parts.length !== 1) {
			return null;
		}

		const [part] = entry.parts;

		if (
			part.type !== 'text' ||
			part.wrap === false ||
			part.text.length > this.options.maxClusters ||
			!PRINTABLE_ASCII.test(part.text)
		) {
			return null;
		}

		const line = shapeLine([{ text: part.text }], 0, this.options);
		const width = Math.max(MIN_WRAP_COLUMNS, this.columns);
		const rows = wrapLine(line, width, this.options.wrap).length;

		this.widest = Math.max(this.widest, rows > 1 ? Math.min(line.cells, width) : line.cells);

		return rows;
	}

	private layoutOf(entry: LogEntry): EntryLayout {
		const stateKey = this.stateKeyOf(entry);
		let layout = this.layouts.get(entry.id);

		if (!layout || layout.stateKey !== stateKey || layout.optionsVersion !== this.optionsVersion) {
			const lines = buildEntryLines(entry, (path) => this.isExpanded(entry, path)).map(
				(logical) => {
					const shaped = shapeLine(logical.spans, logical.indent, this.options);

					shaped.wrap = logical.wrap !== false;

					return shaped;
				}
			);

			layout = {
				stateKey,
				optionsVersion: this.optionsVersion,
				lines,
				wrapKey: '',
				wraps: [],
				rows: 0,
				cells: 0
			};
		}

		const wrapKey = `${this.options.wrap}:${this.columns}`;

		if (layout.wrapKey !== wrapKey) {
			let rows = 0;
			let cells = 0;

			layout.wraps = layout.lines.map((line) => {
				const width = Math.max(MIN_WRAP_COLUMNS, this.columns - line.indent);
				const wraps = wrapLine(line, width, line.wrap ? this.options.wrap : 'none');
				const widest = wraps.length > 1 ? Math.min(line.cells, width) : line.cells;

				rows += wraps.length;
				cells = Math.max(cells, line.indent + widest);

				return wraps;
			});
			layout.rows = rows;
			layout.cells = cells;
			layout.wrapKey = wrapKey;
		}

		this.widest = Math.max(this.widest, layout.cells);
		this.layouts.delete(entry.id);
		this.layouts.set(entry.id, layout);

		if (this.layouts.size > LAYOUT_CACHE_SIZE) {
			const oldest = this.layouts.keys().next().value;

			if (oldest !== undefined) {
				this.layouts.delete(oldest);
			}
		}

		return layout;
	}

	private buildRuns(line: ShapedLine, from: number, to: number): RowRun[] {
		const runs: RowRun[] = [];
		let spanIndex = spanAt(line, from);
		let cursor = from;
		let column = line.indent;

		while (cursor < to && spanIndex < line.spans.length) {
			const spanEnd =
				spanIndex + 1 < line.spans.length ? line.spanStarts[spanIndex + 1] : line.length;
			const end = Math.min(to, spanEnd);

			if (end > cursor) {
				const span = line.spans[spanIndex];
				const text = textBetween(line, cursor, end);
				let cells = end - cursor;
				let clusters: string[] = [];
				let widths: number[] = [];
				let simple = true;

				if (line.clusters && line.widths) {
					widths = Array.from(line.widths.subarray(cursor, end));
					cells = widths.reduce((sum, width) => sum + width, 0);
					simple = !span.icon && cells === end - cursor && PRINTABLE_ASCII.test(text);

					if (!simple) {
						clusters = line.clusters.slice(cursor, end);
					} else {
						widths = [];
					}
				}

				runs.push({
					column,
					cells,
					text,
					clusters,
					widths,
					simple,
					token: span.token,
					style: span.style,
					action: span.action,
					icon: span.icon,
					expanded: span.expanded
				});
				column += cells;
			}

			cursor = end;
			spanIndex++;
		}

		return runs;
	}

	private textInCells(line: ShapedLine, fromCell: number, toCell: number): string {
		let text = '';
		let cell = 0;

		for (let index = 0; index < line.length; index++) {
			const width = widthAt(line, index);

			if (cell >= toCell) {
				break;
			}

			if (cell >= fromCell) {
				const isIcon = line.clusters !== null && line.clusters[index] === '' && width === 2;

				text += isIcon ? '' : textBetween(line, index, index + 1);
			}

			cell += width;
		}

		return text;
	}

	private firstIndexFrom(entryId: number): number {
		let low = this.visibleStart;
		let high = this.visible.length;

		while (low < high) {
			const middle = (low + high) >> 1;

			if (this.visible[middle].id < entryId) {
				low = middle + 1;
			} else {
				high = middle;
			}
		}

		return low - this.visibleStart;
	}

	private forget(entryId: number): void {
		this.layouts.delete(entryId);
		this.rowCounts.delete(entryId);
		this.expansions.delete(entryId);
	}

	private compactVisible(): void {
		if (this.visibleStart > 4096 && this.visibleStart > this.visible.length / 2) {
			this.visible = this.visible.slice(this.visibleStart);
			this.visibleStart = 0;
		}
	}

	private pruneCaches(): void {
		const firstId = this.store.firstId;

		for (const map of [this.layouts, this.rowCounts, this.expansions]) {
			for (const id of map.keys()) {
				if (id < firstId) {
					map.delete(id);
				}
			}
		}
	}
}
