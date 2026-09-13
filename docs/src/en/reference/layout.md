---
order: 5
description: Reference for LogLayout, the filter functions, the line and row types, and the Renderer interface for writing a custom lognal renderer.
---

# Layout and renderers

A viewer passes entries through two stages before they reach the screen. `LogLayout` decides which entries are visible and breaks them into rows, and a `Renderer` draws the rows. Both are replaceable parts, and you only need this page to build something on top of them, such as a custom renderer.

## LogLayout

```ts
new LogLayout(store: LogStore, options?: Partial<LayoutOptions>)
```

Turns the entries of a store into rows for a viewer of a given width. The layout decides which entries are visible (the filter and collapsed groups), how each entry breaks into lines and rows, and which values are expanded. It listens to the store's changes and does the pending work when `sync` is called, so any number of messages between two frames costs one update.

A viewer creates its own layout, available as `viewer.layout`.

### LayoutOptions

`DEFAULT_LAYOUT_OPTIONS` holds the defaults.

| Option           | Type             | Default  | Description                                                    |
| ---------------- | ---------------- | -------- | -------------------------------------------------------------- |
| `wrap`           | `WrapMode`       | `'word'` | How lines longer than the viewer are handled.                  |
| `tabSize`        | `number`         | `8`      | Cells between tab stops.                                       |
| `ambiguousWidth` | `AmbiguousWidth` | `1`      | Cells an East Asian Ambiguous character takes.                 |
| `maxClusters`    | `number`         | `10000`  | The most clusters a line keeps. The rest is replaced with `…`. |

```ts
type WrapMode = 'word' | 'char' | 'none';
```

### Properties

Call `sync()` before reading `rowCount` and `visibleCount`.

| Property           | Type      | Description                                                                                                                    |
| ------------------ | --------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `rowCount`         | `number`  | The number of rows of all visible entries.                                                                                     |
| `visibleCount`     | `number`  | The number of visible entries.                                                                                                 |
| `maxCells`         | `number`  | The widest row seen, in cells, including indentation.                                                                          |
| `isDirty`          | `boolean` | Whether the store changed since the last `sync`.                                                                               |
| `pendingCount`     | `number`  | The number of visible entries whose row count is an estimate.                                                                  |
| `positionsVersion` | `number`  | Increases whenever the first row of an entry that was already visible may have moved. Appending at the end does not change it. |

### Methods

| Method                                                                          | Returns                                         | Description                                                                                                                        |
| ------------------------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `getOptions()`                                                                  | `Readonly<LayoutOptions>`                       | Returns the options.                                                                                                               |
| `setOptions(options: Partial<LayoutOptions>)`                                   | `void`                                          | Changes options.                                                                                                                   |
| `setColumns(columns: number)`                                                   | `void`                                          | Sets the number of columns rows wrap into.                                                                                         |
| `setFilter(filter: LogFilter \| null)`                                          | `CompiledFilter`                                | Sets which entries are visible. The result reports a pattern that does not compile.                                                |
| `getFilter()`                                                                   | `CompiledFilter`                                | Returns the compiled filter in use.                                                                                                |
| `sync(budget?: number)`                                                         | `boolean`                                       | Applies pending store changes. Returns whether anything changed. See [Estimated row counts](#estimated-row-counts).                |
| `measureAround(entryId: number \| null, rowsBefore: number, rowsAfter: number)` | `boolean`                                       | Lays out exactly the entries around one entry, or around the last entry for `null`. Returns whether a row count changed.           |
| `measurePending(budget: number, entryId?: number \| null)`                      | `boolean`                                       | Lays out exactly up to `budget` entries that still have estimates, nearest to an entry first. Returns whether a row count changed. |
| `locateRow(row: number)`                                                        | `{ entry: LogEntry; entryRow: number } \| null` | Returns the entry that holds a row and the index of the row within it.                                                             |
| `rowsOf(entryId: number)`                                                       | `number`                                        | Returns the number of rows of a visible entry, or 0.                                                                               |
| `getRows(start: number, count: number)`                                         | `VisualRow[]`                                   | Returns up to `count` rows starting at row `start`.                                                                                |
| `entryAt(index: number)`                                                        | `LogEntry \| undefined`                         | Returns the entry at a visible position, where 0 is the oldest visible entry.                                                      |
| `indexOf(entryId: number)`                                                      | `number`                                        | Returns the visible position of an entry, or -1.                                                                                   |
| `rowOfEntry(entryId: number)`                                                   | `number`                                        | Returns the first row of an entry, or -1 when it is not visible.                                                                   |
| `isExpanded(entry: LogEntry, path: string)`                                     | `boolean`                                       | Returns whether the value at a path of an entry is expanded.                                                                       |
| `setExpanded(entry: LogEntry, path: string, expanded: boolean)`                 | `void`                                          | Expands or collapses the value at a path of an entry.                                                                              |
| `runAction(entryId: number, action: LineAction)`                                | `void`                                          | Runs the action of a clicked span.                                                                                                 |
| `positionAt(row: number, column: number)`                                       | `TextPosition \| null`                          | Returns the text position under a row and a column of the content area.                                                            |
| `wordAt(position: TextPosition)`                                                | `[TextPosition, TextPosition] \| null`          | Returns the start and end of the word at a position.                                                                               |
| `getText(from: TextPosition, to: TextPosition)`                                 | `string`                                        | Returns the text between two positions, one line per logical line.                                                                 |
| `getAllText()`                                                                  | `string`                                        | Returns the text of every visible entry.                                                                                           |
| `dispose()`                                                                     | `void`                                          | Stops listening to the store.                                                                                                      |

### Estimated row counts

Laying out a large log at a new width takes time in proportion to its size. `sync(budget)` lays out at most `budget` entries exactly and gives the rest an estimate: the previous row count scaled by the change in width, and never fewer rows than the entry has lines. The default budget has no limit, so a layout used on its own is always exact.

The viewer calls `sync` with a budget, lays out the entries on screen with `measureAround` before it draws, and calls `measurePending` in short slices between frames until `pendingCount` is 0. It compares `positionsVersion` between frames to keep the entry at the top of the view in place.

```ts
layout.setColumns(60);
layout.sync(500);
layout.measureAround(topEntryId, 50, 100);

while (layout.pendingCount > 0) {
	layout.measurePending(200, topEntryId);
}
```

A value path is the index of the part in the entry, followed by the index of each child, joined with dots. `'1'` is the second part of an entry, and `'1.0'` is the first child of that value.

`setExpanded` does not ask the viewer to draw again. After calling it on `viewer.layout`, the change appears with the next frame the viewer draws, for example after the next entry or scroll.

```ts
// Copy every visible entry as text.
viewer.layout.sync();
await navigator.clipboard.writeText(viewer.layout.getAllText());
```

## Filters

### LogFilter

| Field           | Type                  | Description                                                 |
| --------------- | --------------------- | ----------------------------------------------------------- |
| `text`          | `string`              | Text an entry must contain. Empty text matches every entry. |
| `regex`         | `boolean`             | Whether `text` is a regular expression.                     |
| `caseSensitive` | `boolean`             | Whether letter case must match.                             |
| `minLevel`      | `LogLevel`            | The least severe level shown.                               |
| `levels`        | `readonly LogLevel[]` | The levels shown. When set, `minLevel` is ignored.          |

### compileFilter

```ts
compileFilter(filter: LogFilter | null | undefined): CompiledFilter
```

Turns a filter into a function that tests entries.

| `CompiledFilter` field | Type                                     | Description                                                                             |
| ---------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------- |
| `matches`              | `((entry: LogEntry) => boolean) \| null` | Tests an entry. `null` when the filter lets every entry through.                        |
| `pattern`              | `RegExp \| null`                         | Finds matches in a line of text, for highlighting. `null` when there is no text filter. |
| `error`                | `string \| null`                         | The error message when `text` is not a valid regular expression.                        |

```ts
import { compileFilter } from 'lognal';

const filter = compileFilter({ text: 'timeout', minLevel: 'warn' });
const matching = viewer.store.toArray().filter((entry) => filter.matches?.(entry) ?? true);
```

### entrySearchText

```ts
entrySearchText(entry: LogEntry): string
```

Returns the text of an entry as the filter sees it: its text parts and a one-line preview of every value, in Unicode normalization form C, cut at 20,000 characters.

## Rows

### VisualRow

One row of the screen.

| Field       | Type       | Description                                                                              |
| ----------- | ---------- | ---------------------------------------------------------------------------------------- |
| `entry`     | `LogEntry` | The entry the row belongs to.                                                            |
| `line`      | `number`   | The index of the logical line within the entry.                                          |
| `lineRow`   | `number`   | The index of the row within the logical line.                                            |
| `entryRow`  | `number`   | The index of the row within the entry.                                                   |
| `first`     | `boolean`  | Whether this is the first row of the entry.                                              |
| `last`      | `boolean`  | Whether this is the last row of the entry.                                               |
| `indent`    | `number`   | Cells of indentation before the first run.                                               |
| `startCell` | `number`   | The cell offset of the row's first cluster within the logical line, without indentation. |
| `cells`     | `number`   | The width of the row's content in cells, without indentation.                            |
| `runs`      | `RowRun[]` | The runs of the row.                                                                     |

An entry has one logical line for each line of its text, plus one for each row of an open value.

### RowRun

A run of clusters on one row that share a style.

| Field      | Type         | Description                                                                                            |
| ---------- | ------------ | ------------------------------------------------------------------------------------------------------ |
| `column`   | `number`     | The column where the run starts, counted from the start of the content area. Includes the indentation. |
| `cells`    | `number`     | The width in cells.                                                                                    |
| `text`     | `string`     | The text of the run.                                                                                   |
| `simple`   | `boolean`    | Whether the run is plain ASCII that can be drawn in one call.                                          |
| `clusters` | `string[]`   | The clusters of a run that is not simple. Empty for a simple run.                                      |
| `widths`   | `number[]`   | The width of every cluster in `clusters`.                                                              |
| `token`    | `StyleToken` | The semantic color, if any.                                                                            |
| `style`    | `TextStyle`  | Explicit styling, if any.                                                                              |
| `action`   | `LineAction` | What happens when the run is clicked, if anything.                                                     |
| `icon`     | `'expander'` | Set for the triangle that expands a value or a group. Such a run has no text and takes two cells.      |
| `expanded` | `boolean`    | For an expander, whether it is open.                                                                   |

### TextPosition

```ts
interface TextPosition {
	entryId: number;
	/** The index of the logical line within the entry. */
	line: number;
	/** The cell offset within the logical line, without indentation. */
	cell: number;
}
```

A position in the text of an entry that stays the same when the rows wrap differently.

### LineAction

```ts
type LineAction = { type: 'toggle-value'; path: string } | { type: 'toggle-group' };
```

What happens when a span is clicked. `toggle-value` opens or closes the value at `path`, and `toggle-group` collapses or expands the group the entry starts.

### Line spans

An entry is first built as logical lines of spans, before it is split into clusters and wrapped into rows. `previewValue` returns spans of the same kind.

```ts
type LineSpan = LineTextSpan | LineIconSpan;
```

#### LineTextSpan

A run of text on a logical line.

| Field    | Type         | Description                                         |
| -------- | ------------ | --------------------------------------------------- |
| `text`   | `string`     | The text.                                           |
| `token`  | `StyleToken` | The semantic color, if any.                         |
| `style`  | `TextStyle`  | Explicit styling, if any.                           |
| `action` | `LineAction` | What happens when the text is clicked, if anything. |

#### LineIconSpan

A small drawn symbol that takes two cells, such as the triangle that expands a value.

| Field      | Type         | Description                              |
| ---------- | ------------ | ---------------------------------------- |
| `icon`     | `'expander'` | The symbol.                              |
| `expanded` | `boolean`    | Whether the expander is open.            |
| `action`   | `LineAction` | What happens when the symbol is clicked. |

#### LogicalLine

One line of an entry before wrapping. An entry has one logical line for each line of its text, plus one for each row of an open value.

| Field    | Type         | Description                                                                              |
| -------- | ------------ | ---------------------------------------------------------------------------------------- |
| `indent` | `number`     | Cells of indentation before the content, repeated on every wrapped row.                  |
| `spans`  | `LineSpan[]` | The spans of the line, in order.                                                         |
| `wrap`   | `boolean`    | `false` when the line holds a text part with `wrap: false`, so it never wraps. Optional. |

## Renderer

```ts
interface Renderer {
	readonly element: HTMLElement;
	setTheme(theme: RenderTheme): void;
	setFont(font: FontSettings): CellMetrics;
	getMetrics(): CellMetrics;
	resize(width: number, height: number, pixelRatio: number): void;
	render(frame: RenderFrame): void;
	onFontsChanged(listener: () => void): void;
	dispose(): void;
}
```

The viewer owns the layout, scrolling and input. A renderer only turns a frame into pixels, so a different drawing technology can take its place.

| Member                              | Description                                                                                                     |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `element`                           | The element the renderer draws into. The viewer places it under the scroll area of the log.                     |
| `setTheme(theme)`                   | Sets the colors. Called on creation and whenever the theme changes.                                             |
| `setFont(font)`                     | Sets the font and returns the size of a cell. The viewer lays out text and maps the pointer with these metrics. |
| `getMetrics()`                      | Returns the size of a cell.                                                                                     |
| `resize(width, height, pixelRatio)` | Sets the drawing size in CSS pixels and the device pixel ratio.                                                 |
| `render(frame)`                     | Draws one frame. The viewer calls it at most once per animation frame.                                          |
| `onFontsChanged(listener)`          | Registers a function to call when fonts finish loading glyphs, so the viewer can measure again.                 |
| `dispose()`                         | Releases resources and removes the element.                                                                     |

### RenderFrame

| Field            | Type                       | Description                                                           |
| ---------------- | -------------------------- | --------------------------------------------------------------------- |
| `rows`           | `VisualRow[]`              | The rows to draw, from the top.                                       |
| `decorations`    | `RowDecoration[]`          | The highlights of each row, at the same index as `rows`.              |
| `offsetY`        | `number`                   | The vertical offset of the first row in CSS pixels, zero or negative. |
| `scrollX`        | `number`                   | The horizontal scroll of the content area in CSS pixels.              |
| `paddingLeft`    | `number`                   | Space before the gutter in CSS pixels.                                |
| `timestampCells` | `number`                   | Cells taken by the timestamp column, or 0 when timestamps are hidden. |
| `markerCells`    | `number`                   | Cells taken by the level marker column.                               |
| `formatTime`     | `(time: number) => string` | Formats the time of an entry for the timestamp column.                |

The content area starts at `paddingLeft + (timestampCells + markerCells) * cellWidth`.

### RowDecoration

| Field       | Type                 | Description                                                                                 |
| ----------- | -------------------- | ------------------------------------------------------------------------------------------- |
| `selection` | `[number, number]`   | The selected columns of the content area, if any.                                           |
| `matches`   | `[number, number][]` | The columns of filter matches, if any.                                                      |
| `hovered`   | `boolean`            | Whether the row belongs to the entry under the pointer, or to the entry whose menu is open. |

### CellMetrics and FontSettings

| `CellMetrics` field | Type     | Description                                              |
| ------------------- | -------- | -------------------------------------------------------- |
| `width`             | `number` | The width of one cell in CSS pixels.                     |
| `height`            | `number` | The height of one row in CSS pixels.                     |
| `baseline`          | `number` | The distance from the top of a row to the text baseline. |

| `FontSettings` field | Type     | Description                                                              |
| -------------------- | -------- | ------------------------------------------------------------------------ |
| `family`             | `string` | A CSS font family list, such as `"JetBrains Mono", D2Coding, monospace`. |
| `size`               | `number` | The font size in CSS pixels.                                             |
| `weight`             | `number` | The font weight of regular text, such as `400`.                          |
| `lineHeight`         | `number` | The row height as a multiple of the font size.                           |

### RenderTheme

The colors a renderer draws with. `readTheme` builds it from the `--lognal-*` custom properties, and any CSS color works.

| Field                                                                 | Type                                             | CSS property                                            |
| --------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------- |
| `background`, `foreground`, `muted`, `accent`                         | `string`                                         | `--lognal-background` and so on                         |
| `selection`, `match`, `separator`, `hover`                            | `string`                                         | `--lognal-selection` and so on                          |
| `error`, `errorBackground`, `warn`, `warnBackground`, `info`, `debug` | `string`                                         | `--lognal-error`, `--lognal-error-background` and so on |
| `tokens`                                                              | `Record<Exclude<StyleToken, 'default'>, string>` | `--lognal-token-*`                                      |
| `ansi`                                                                | `string[]`                                       | `--lognal-ansi-0` to `--lognal-ansi-15`                 |

`DEFAULT_RENDER_THEME` holds the colors used until a theme is read from CSS. They are the dark palette of `lognal.css`, and a unit test keeps the two equal.

### CanvasRenderer

```ts
new CanvasRenderer(ownerDocument?: Document)
```

The built-in renderer. It draws on a `<canvas>` with the 2D context and repaints the visible rows every frame. Plain ASCII text in one style is drawn with one `fillText` call. Other text is drawn one grapheme cluster at a time at its grid position, so wide characters and characters from a fallback font stay aligned. Box-drawing characters are drawn as lines so table borders join across rows.

### A custom renderer

This sketch draws the rows as plain text in a `<pre>` element. It shows how the parts of a frame fit together. It leaves out the timestamps, markers, colors and highlights, and a `<pre>` does not keep wide characters on the grid.

```ts
import { LogViewer, type CellMetrics, type FontSettings, type RenderFrame, type RenderTheme, type Renderer } from 'lognal';

class PreRenderer implements Renderer {
	readonly element: HTMLPreElement;
	private readonly measure: CanvasRenderingContext2D | null;
	private metrics: CellMetrics = { width: 8, height: 20, baseline: 14 };

	constructor(ownerDocument: Document) {
		this.element = ownerDocument.createElement('pre');
		// The class of the built-in canvas positions the element under the scroll area.
		this.element.className = 'lognal-canvas';
		this.element.style.margin = '0';
		this.element.style.overflow = 'hidden';
		this.measure = ownerDocument.createElement('canvas').getContext('2d');
	}

	setTheme(theme: RenderTheme): void {
		this.element.style.color = theme.foreground;
		this.element.style.backgroundColor = theme.background;
	}

	setFont(font: FontSettings): CellMetrics {
		const css = `${font.weight} ${font.size}px ${font.family}`;
		const height = Math.round(font.size * font.lineHeight);

		this.element.style.font = css;
		this.element.style.lineHeight = `${height}px`;

		if (this.measure) {
			this.measure.font = css;
		}

		const width = this.measure?.measureText('M').width || font.size * 0.6;

		this.metrics = { width, height, baseline: Math.round(height * 0.75) };

		return this.metrics;
	}

	getMetrics(): CellMetrics {
		return this.metrics;
	}

	resize(): void {}

	render(frame: RenderFrame): void {
		const gutterCells = frame.timestampCells + frame.markerCells;

		this.element.style.top = `${frame.offsetY}px`;
		this.element.style.paddingLeft = `${frame.paddingLeft + gutterCells * this.metrics.width}px`;
		this.element.textContent = frame.rows
			.map((row) => {
				let line = '';
				let column = 0;

				for (const run of row.runs) {
					line += ' '.repeat(Math.max(0, run.column - column));
					line += run.icon ? (run.expanded ? '- ' : '+ ') : run.text;
					column = run.column + run.cells;
				}

				return line;
			})
			.join('\n');
		this.element.scrollLeft = frame.scrollX;
	}

	onFontsChanged(): void {}

	dispose(): void {
		this.element.remove();
	}
}

const viewer = new LogViewer(document.getElementById('logs')!, {
	renderer: (ownerDocument) => new PreRenderer(ownerDocument)
});
```
