---
order: 5
description: Reference for LogLayout, the filter functions, the line and row types, and the Renderer interface for writing a custom lognal renderer.
---

# Layout and renderers

A viewer passes entries through two stages before they reach the screen. `LogLayout` decides which entries are visible and breaks them into rows, and a renderer draws the rows. Both are replaceable parts, and you only need this page to build something on top of them, such as a renderer of your own.

## LogLayout

```
new LogLayout(store, options)
```

Turns the entries of a store into rows for a viewer of a given width. The layout decides which entries are visible (the filter and collapsed groups), how each entry breaks into lines and rows, and which values are expanded. It listens to the store's changes and does the pending work when `sync` is called, so any number of messages between two frames costs one update.

A viewer creates its own layout, available as <Fw js="viewer.layout" flutter="controller.layout" code />.

### LayoutOptions

<Fw js="DEFAULT_LAYOUT_OPTIONS" flutter="defaultLayoutOptions" code /> holds the defaults.

| Option           | Type                                    | Default                                         | Description                                                                         |
| ---------------- | --------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| `wrap`           | `WrapMode`                              | <Fw js="'word'" flutter="WrapMode.word" code /> | How lines longer than the viewer are handled.                                       |
| `tabSize`        | <Fw js="number" flutter="int" code />   | `8`                                             | Cells between tab stops.                                                            |
| `ambiguousWidth` | `AmbiguousWidth`                        | `1`                                             | Cells an East Asian Ambiguous character takes.                                      |
| `maxClusters`    | <Fw js="number" flutter="int" code />   | `10000`                                         | The most clusters a line keeps. The rest is replaced with `…`.                      |
| `links`          | <Fw js="boolean" flutter="bool" code /> | `true`                                          | Whether `http` and `https` addresses in text become spans with an open-link action. |

::: fw js

```ts
type WrapMode = 'word' | 'char' | 'none';
```

:::

::: fw flutter

```dart
enum WrapMode { word, char, none }
```

`LayoutOptions` extends `ShapeOptions`, which is the three that shaping needs, and `copyWith` returns a copy with some of them replaced.

:::

### Properties

Call `sync()` before reading `rowCount` and `visibleCount`.

| Property           | Type                                    | Description                                                                                                                    |
| ------------------ | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `rowCount`         | <Fw js="number" flutter="int" code />   | The number of rows of all visible entries.                                                                                     |
| `visibleCount`     | <Fw js="number" flutter="int" code />   | The number of visible entries.                                                                                                 |
| `maxCells`         | <Fw js="number" flutter="int" code />   | The widest row seen, in cells, including indentation.                                                                          |
| `isDirty`          | <Fw js="boolean" flutter="bool" code /> | Whether the store changed since the last `sync`.                                                                               |
| `pendingCount`     | <Fw js="number" flutter="int" code />   | The number of visible entries whose row count is an estimate.                                                                  |
| `positionsVersion` | <Fw js="number" flutter="int" code />   | Increases whenever the first row of an entry that was already visible may have moved. Appending at the end does not change it. |

<Fw flutter="mutedCount, an int, is the number of entries the mute rules keep out of the log." />

### Methods

::: fw js

| Method                                                                          | Returns                                         | Description                                                                                                                                                                                                           |
| ------------------------------------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `getOptions()`                                                                  | `Readonly<LayoutOptions>`                       | Returns the options.                                                                                                                                                                                                  |
| `setOptions(options: Partial<LayoutOptions>)`                                   | `void`                                          | Changes options.                                                                                                                                                                                                      |
| `setColumns(columns: number)`                                                   | `void`                                          | Sets the number of columns rows wrap into.                                                                                                                                                                            |
| `setFilter(filter: LogFilter \| null)`                                          | `CompiledFilter`                                | Sets which entries are visible. The result reports a pattern that does not compile.                                                                                                                                   |
| `getFilter()`                                                                   | `CompiledFilter`                                | Returns the compiled filter in use.                                                                                                                                                                                   |
| `sync(budget?: number)`                                                         | `boolean`                                       | Applies pending store changes. Returns whether anything changed. See [Estimated row counts](#estimated-row-counts).                                                                                                   |
| `measureAround(entryId: number \| null, rowsBefore: number, rowsAfter: number)` | `boolean`                                       | Lays out exactly the entries around one entry, or around the last entry for `null`. Returns whether a row count changed.                                                                                              |
| `measurePending(budget: number, entryId?: number \| null)`                      | `boolean`                                       | Lays out exactly up to `budget` entries that still have estimates, nearest to an entry first. Returns whether a row count changed.                                                                                    |
| `locateRow(row: number)`                                                        | `{ entry: LogEntry; entryRow: number } \| null` | Returns the entry that holds a row and the index of the row within it.                                                                                                                                                |
| `rowsOf(entryId: number)`                                                       | `number`                                        | Returns the number of rows of a visible entry, or 0.                                                                                                                                                                  |
| `getRows(start: number, count: number)`                                         | `VisualRow[]`                                   | Returns up to `count` rows starting at row `start`.                                                                                                                                                                   |
| `entryAt(index: number)`                                                        | `LogEntry \| undefined`                         | Returns the entry at a visible position, where 0 is the oldest visible entry.                                                                                                                                         |
| `indexOf(entryId: number)`                                                      | `number`                                        | Returns the visible position of an entry, or -1.                                                                                                                                                                      |
| `rowOfEntry(entryId: number)`                                                   | `number`                                        | Returns the first row of an entry, or -1 when it is not visible.                                                                                                                                                      |
| `isExpanded(entry: LogEntry, path: string)`                                     | `boolean`                                       | Returns whether the value at a path of an entry is expanded.                                                                                                                                                          |
| `setExpanded(entry: LogEntry, path: string, expanded: boolean)`                 | `void`                                          | Expands or collapses the value at a path of an entry.                                                                                                                                                                 |
| `expandAll(entryId: number)`                                                    | `void`                                          | Expands every value of an entry, and every value inside them, as far as they were captured.                                                                                                                           |
| `collapseAll(entryId: number)`                                                  | `void`                                          | Collapses every value of an entry, including an error logged on its own.                                                                                                                                              |
| `hasExpandableValues(entry: LogEntry)`                                          | `boolean`                                       | Returns whether an entry holds a value that can be expanded.                                                                                                                                                          |
| `linksOf(entryId: number)`                                                      | `string[]`                                      | Returns the addresses of the links of an entry as shown, with the rows of open values, each address once and in order.                                                                                                |
| `indexFrom(entryId: number)`                                                    | `number`                                        | Returns the visible position of the first visible entry whose id is at least `entryId`.                                                                                                                               |
| `findInEntry(entry: LogEntry, pattern: RegExp, limit?: number)`                 | `TextMatch[]`                                   | Finds the matches of a global pattern in the lines of an entry as shown, compared in Unicode normalization form C. A `TextMatch` is `{ entryId, line, from, to }`, with `from` and `to` in cells of the logical line. |
| `locatePosition(position: TextPosition)`                                        | `{ entryRow: number; indent: number } \| null`  | Returns the row within its entry that shows a text position, and the indent of that row.                                                                                                                              |
| `runAction(entryId: number, action: LineAction)`                                | `void`                                          | Runs the action of a clicked span. Opening a link is left to the viewer.                                                                                                                                              |
| `positionAt(row: number, column: number)`                                       | `TextPosition \| null`                          | Returns the text position under a row and a column of the content area.                                                                                                                                               |
| `wordAt(position: TextPosition)`                                                | `[TextPosition, TextPosition] \| null`          | Returns the start and end of the word at a position.                                                                                                                                                                  |
| `getText(from: TextPosition, to: TextPosition)`                                 | `string`                                        | Returns the text between two positions, one line per logical line.                                                                                                                                                    |
| `getAllText()`                                                                  | `string`                                        | Returns the text of every visible entry.                                                                                                                                                                              |
| `dispose()`                                                                     | `void`                                          | Stops listening to the store.                                                                                                                                                                                         |

:::

::: fw flutter

| Method                                                       | Returns              | Description                                                                                                         |
| ------------------------------------------------------------ | -------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `options`                                                    | `LayoutOptions`      | The options. Assigning to it changes them.                                                                          |
| `columns`                                                    | `int`                | The number of columns rows wrap into. Assigning to it re-wraps.                                                     |
| `setFilter(LogFilter? filter)`                               | `CompiledFilter`     | Sets which entries are visible. The result reports a pattern that does not compile.                                 |
| `filter`                                                     | `CompiledFilter`     | The compiled filter in use.                                                                                         |
| `sync({int? budget})`                                        | `bool`               | Applies pending store changes. Returns whether anything changed. See [Estimated row counts](#estimated-row-counts). |
| `measureAround(int? entryId, int rowsBefore, int rowsAfter)` | `bool`               | Lays out exactly the entries around one entry, or around the last entry for `null`.                                 |
| `measurePending(int budget, [int? entryId])`                 | `bool`               | Lays out exactly up to `budget` entries that still have estimates, nearest to an entry first.                       |
| `locateRow(int row)`                                         | `RowLocation?`       | The entry that holds a row and the index of the row within it.                                                      |
| `rowsOf(int entryId)`                                        | `int`                | The number of rows of a visible entry, or 0.                                                                        |
| `getRows(int start, int count)`                              | `List<VisualRow>`    | Up to `count` rows starting at row `start`.                                                                         |
| `entryAt(int index)`                                         | `LogEntry?`          | The entry at a visible position, where 0 is the oldest visible entry.                                               |
| `indexOf(int entryId)`                                       | `int`                | The visible position of an entry, or -1.                                                                            |
| `rowOfEntry(int entryId)`                                    | `int`                | The first row of an entry, or -1 when it is not visible.                                                            |
| `isExpanded(LogEntry entry, String path)`                    | `bool`               | Whether the value at a path of an entry is expanded.                                                                |
| `setExpanded(LogEntry entry, String path, bool expanded)`    | `void`               | Expands or collapses the value at a path of an entry.                                                               |
| `expandAll(int entryId)`, `collapseAll(int entryId)`         | `void`               | Expands or collapses every value of an entry, as far as it was captured.                                            |
| `hasExpandableValues(LogEntry entry)`                        | `bool`               | Whether an entry holds a value that can be expanded.                                                                |
| `linksOf(int entryId)`                                       | `List<String>`       | The addresses of the links of an entry as shown, with the rows of open values, each address once and in order.      |
| `indexFrom(int entryId)`                                     | `int`                | The visible position of the first visible entry whose id is at least `entryId`.                                     |
| `findInEntry(LogEntry entry, RegExp pattern, [int? limit])`  | `List<TextMatch>`    | The matches of a pattern in the lines of an entry as shown, compared in Unicode normalization form C.               |
| `locatePosition(LogPosition position)`                       | `PositionLocation?`  | The row within its entry that shows a text position, and the indent of that row.                                    |
| `runAction(int entryId, LineAction action)`                  | `void`               | Runs the action of a tapped span. Opening a link is left to the viewer.                                             |
| `positionAt(int row, int column)`                            | `LogPosition?`       | The text position under a row and a column of the content area.                                                     |
| `wordAt(LogPosition position)`                               | `List<LogPosition>?` | The start and end of the word at a position.                                                                        |
| `getText(LogPosition from, LogPosition to)`                  | `String`             | The text between two positions, one line per logical line.                                                          |
| `getAllText()`                                               | `String`             | The text of every visible entry.                                                                                    |
| `dispose()`                                                  | `void`               | Stops listening to the store.                                                                                       |

`getOptions` and `getFilter` are properties here rather than methods, and `setColumns` is an assignment to `columns`.

:::

### Estimated row counts

Laying out a large log at a new width takes time in proportion to its size. `sync(budget)` lays out at most `budget` entries exactly and gives the rest an estimate: the previous row count scaled by the change in width, and never fewer rows than the entry has lines. The default budget has no limit, so a layout used on its own is always exact.

The viewer calls `sync` with a budget, lays out the entries on screen with `measureAround` before it draws, and calls `measurePending` in short slices between frames until `pendingCount` is 0. It compares `positionsVersion` between frames to keep the entry at the top of the view in place.

::: fw js

```ts
layout.setColumns(60);
layout.sync(500);
layout.measureAround(topEntryId, 50, 100);

while (layout.pendingCount > 0) {
	layout.measurePending(200, topEntryId);
}
```

:::

::: fw flutter

```dart
layout.columns = 60;
layout.sync(budget: 500);
layout.measureAround(topEntryId, 50, 100);

while (layout.pendingCount > 0) {
  layout.measurePending(200, topEntryId);
}
```

:::

A value path is the index of the part in the entry, followed by the index of each child, joined with dots. `'1'` is the second part of an entry, and `'1.0'` is the first child of that value.

`setExpanded` does not ask the viewer to draw again. After calling it on `viewer.layout`, the change appears with the next frame the viewer draws, for example after the next entry or scroll.

::: fw js

```ts
// Copy every visible entry as text.
viewer.layout.sync();
await navigator.clipboard.writeText(viewer.layout.getAllText());
```

:::

::: fw flutter

```dart
// Copy every visible entry as text.
controller.layout.sync();
await Clipboard.setData(ClipboardData(text: controller.layout.getAllText()));
```

:::

## Filters

### LogFilter

| Field           | Type                                                           | Description                                                                                |
| --------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `text`          | <Fw js="string" flutter="String" code />                       | Text an entry must contain. Empty text matches every entry.                                |
| `regex`         | <Fw js="boolean" flutter="bool" code />                        | Whether `text` is a regular expression.                                                    |
| `caseSensitive` | <Fw js="boolean" flutter="bool" code />                        | Whether letter case must match.                                                            |
| `minLevel`      | <Fw js="LogLevel" flutter="LogLevel?" code />                  | The least severe level shown.                                                              |
| `levels`        | <Fw js="readonly LogLevel[]" flutter="List<LogLevel>?" code /> | The levels shown. When set, `minLevel` is ignored.                                         |
| `mute`          | <Fw js="readonly MuteRule[]" flutter="List<MuteRule>" code />  | Rules that hide entries whatever the rest of the filter says. See [`MuteRule`](#muterule). |

### compileFilter

```
compileFilter(filter)
```

Turns a filter into a function that tests entries.

::: fw js

| `CompiledFilter` field | Type                                     | Description                                                                             |
| ---------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------- |
| `matches`              | `((entry: LogEntry) => boolean) \| null` | Tests an entry. `null` when the filter lets every entry through.                        |
| `muted`                | `((entry: LogEntry) => boolean) \| null` | Tests an entry against the mute rules. `null` when no rule applies.                     |
| `pattern`              | `RegExp \| null`                         | Finds matches in a line of text, for highlighting. `null` when there is no text filter. |
| `error`                | `string \| null`                         | The error message when `text` is not a valid regular expression.                        |

```ts
import { compileFilter } from 'lognal';

const filter = compileFilter({ text: 'timeout', minLevel: 'warn' });
const matching = viewer.store.toArray().filter((entry) => filter.matches?.(entry) ?? true);
```

:::

::: fw flutter

| `CompiledFilter` field | Type                       | Description                                                                             |
| ---------------------- | -------------------------- | --------------------------------------------------------------------------------------- |
| `matches`              | `bool Function(LogEntry)?` | Tests an entry. `null` when the filter lets every entry through.                        |
| `muted`                | `bool Function(LogEntry)?` | Tests an entry against the mute rules. `null` when no rule applies.                     |
| `pattern`              | `RegExp?`                  | Finds matches in a line of text, for highlighting. `null` when there is no text filter. |
| `error`                | `String?`                  | The error message when `text` is not a valid regular expression.                        |

```dart
import 'package:lognal/lognal.dart';

final CompiledFilter filter = compileFilter(
  const LogFilter(text: 'timeout', minLevel: LogLevel.warn),
);
final List<LogEntry> matching = store.toList()
    .where((LogEntry entry) => filter.matches?.call(entry) ?? true)
    .toList();
```

`escapeRegExp(text)` escapes a string for use inside a pattern, which is how a text filter becomes one.

:::

### entrySearchText

```
entrySearchText(entry)
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

::: fw js

```ts
interface TextPosition {
	entryId: number;
	/** The index of the logical line within the entry. */
	line: number;
	/** The cell offset within the logical line, without indentation. */
	cell: number;
}
```

:::

::: fw flutter

```dart
class LogPosition {
  const LogPosition({
    required int entryId,
    required int line,
    required int cell,
  });
}
```

The class is `LogPosition`, because `TextPosition` is already a name in `dart:ui`. `line` is the index of the logical line within the entry, and `cell` is the cell offset within that line, without indentation.

:::

A position in the text of an entry that stays the same when the rows wrap differently.

### LineAction

::: fw js

```ts
type LineAction = { type: 'toggle-value'; path: string } | { type: 'toggle-group' } | { type: 'toggle-repeat' } | { type: 'open-link'; url: string };
```

What happens when a span is clicked. `toggle-value` opens or closes the value at `path`, `toggle-group` collapses or expands the group the entry starts, and `toggle-repeat` shows or hides the messages that repeat the first entry of a run. `open-link` opens `url`, which the viewer does the way its `linkClick` option says.

:::

::: fw flutter

```dart
sealed class LineAction {}

class ToggleValueAction extends LineAction { final String path; }
class ToggleGroupAction extends LineAction {}
class ToggleRepeatAction extends LineAction {}
class OpenLinkAction extends LineAction { final String url; }
```

What happens when a span is tapped. `ToggleValueAction` opens or closes the value at `path`, `ToggleGroupAction` collapses or expands the group the entry starts, and `ToggleRepeatAction` shows or hides the messages that repeat the first entry of a run. `OpenLinkAction` carries a `url`, which the viewer hands on the way its `linkClick` option says.

:::

### findLinks

```
findLinks(text)
```

Finds the `http` and `https` addresses in a string, the way the layout finds them while `links` is on. A `TextLink` carries `start`, `end` and `url`: the first two are indexes of UTF-16 code units, and `url` is the text between them.

```
findLinks('Docs: https://lognal.cdget.com/guide/viewer.');
// one link, from 6 to 43
```

### Line spans

An entry is first built as logical lines of spans, before it is split into clusters and wrapped into rows. `previewValue` returns spans of the same kind.

::: fw js

```ts
type LineSpan = LineTextSpan | LineIconSpan;
```

:::

::: fw flutter

```dart
sealed class LineSpan {}
```

`LineTextSpan` and `LineIconSpan` extend it.

:::

#### LineTextSpan

A run of text on a logical line.

| Field    | Type                                               | Description                                        |
| -------- | -------------------------------------------------- | -------------------------------------------------- |
| `text`   | <Fw js="string" flutter="String" code />           | The text.                                          |
| `token`  | <Fw js="StyleToken" flutter="StyleToken?" code />  | The semantic color, if any.                        |
| `style`  | <Fw js="TextStyle" flutter="LogTextStyle?" code /> | Explicit styling, if any.                          |
| `action` | <Fw js="LineAction" flutter="LineAction?" code />  | What happens when the text is tapped, if anything. |

#### LineIconSpan

A small drawn symbol that takes two cells, such as the triangle that expands a value.

| Field      | Type                                              | Description                             |
| ---------- | ------------------------------------------------- | --------------------------------------- |
| `expanded` | <Fw js="boolean" flutter="bool" code />           | Whether the expander is open.           |
| `action`   | <Fw js="LineAction" flutter="LineAction?" code /> | What happens when the symbol is tapped. |

<Fw js="An icon field, the string 'expander', says which symbol it is." flutter="There is no icon field: the expander is the only symbol, and the class says so." />

#### LogicalLine

One line of an entry before wrapping. An entry has one logical line for each line of its text, plus one for each row of an open value.

| Field    | Type                                                 | Description                                                                          |
| -------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `indent` | <Fw js="number" flutter="int" code />                | Cells of indentation before the content, repeated on every wrapped row.              |
| `spans`  | <Fw js="LineSpan[]" flutter="List<LineSpan>" code /> | The spans of the line, in order.                                                     |
| `wrap`   | <Fw js="boolean" flutter="bool" code />              | `false` when the line holds a text part that does not wrap, so the line never wraps. |

## Renderer

::: fw js

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

:::

::: fw flutter

```dart
abstract class LogRenderer {
  const LogRenderer();

  set theme(RenderTheme theme);
  CellMetrics setFont(FontSettings font);
  CellMetrics get metrics;
  void paint(Canvas canvas, Size size, RenderFrame frame);
  void dispose();
}
```

:::

The viewer owns the layout, scrolling and input. A renderer only turns a frame into pixels, so a different drawing technology can take its place.

::: fw js

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

:::

::: fw flutter

| Member                       | Description                                                                                                     |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `theme`                      | Sets the colors. Set on creation and whenever the palette changes.                                              |
| `setFont(font)`              | Sets the font and returns the size of a cell. The viewer lays out text and maps the pointer with these metrics. |
| `metrics`                    | The size of a cell.                                                                                             |
| `paint(canvas, size, frame)` | Draws one frame onto a canvas. A `CustomPainter` calls it, so the framework decides when.                       |
| `dispose()`                  | Releases what it cached.                                                                                        |

There is no element, no `resize` and no `onFontsChanged`. A painter is given the canvas and its size on every paint, and the widget listens to `PaintingBinding.instance.systemFonts` itself, so a fallback font that arrives late makes the viewer measure again.

:::

### RenderFrame

| Field            | Type                                                                          | Description                                                               |
| ---------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `rows`           | <Fw js="VisualRow[]" flutter="List<VisualRow>" code />                        | The rows to draw, from the top.                                           |
| `decorations`    | <Fw js="RowDecoration[]" flutter="List<RowDecoration>" code />                | The highlights of each row, at the same index as `rows`.                  |
| `offsetY`        | <Fw js="number" flutter="double" code />                                      | The vertical offset of the first row in logical pixels, zero or negative. |
| `scrollX`        | <Fw js="number" flutter="double" code />                                      | The horizontal scroll of the content area in logical pixels.              |
| `paddingLeft`    | <Fw js="number" flutter="double" code />                                      | Space before the gutter in logical pixels.                                |
| `timestampCells` | <Fw js="number" flutter="int" code />                                         | Cells taken by the timestamp column, or 0 when timestamps are hidden.     |
| `markerCells`    | <Fw js="number" flutter="int" code />                                         | Cells taken by the level marker column.                                   |
| `formatTime`     | <Fw js="(time: number) => string" flutter="String Function(DateTime)" code /> | Formats the time of an entry for the timestamp column.                    |

The content area starts at `paddingLeft + (timestampCells + markerCells) * cellWidth`.

### RowDecoration

| Field           | Type                                                          | Description                                                                                          |
| --------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `selection`     | <Fw js="[number, number]" flutter="List<int>?" code />        | The selected columns of the content area, if any.                                                    |
| `matches`       | <Fw js="[number, number][]" flutter="List<List<int>>" code /> | The columns of filter matches, if any.                                                               |
| `hovered`       | <Fw js="boolean" flutter="bool" code />                       | Whether the row belongs to the entry under the pointer, or to the entry whose menu is open.          |
| `searchMatches` | <Fw js="[number, number][]" flutter="List<List<int>>" code /> | The columns of the matches of a search, other than the current match, if any.                        |
| `searchCurrent` | <Fw js="[number, number]" flutter="List<int>?" code />        | The columns of the current match of a search, if the row shows it.                                   |
| `entrySelected` | <Fw js="boolean" flutter="bool" code />                       | Whether the row belongs to an entry selected in entry mode.                                          |
| `entryFocused`  | <Fw js="boolean" flutter="bool" code />                       | Whether the row belongs to the entry the keyboard moves from in entry mode, while the log has focus. |

### CellMetrics and FontSettings

| `CellMetrics` field | Type                                     | Description                                              |
| ------------------- | ---------------------------------------- | -------------------------------------------------------- |
| `width`             | <Fw js="number" flutter="double" code /> | The width of one cell in logical pixels.                 |
| `height`            | <Fw js="number" flutter="double" code /> | The height of one row in logical pixels.                 |
| `baseline`          | <Fw js="number" flutter="double" code /> | The distance from the top of a row to the text baseline. |

::: fw js

| `FontSettings` field | Type     | Description                                                              |
| -------------------- | -------- | ------------------------------------------------------------------------ |
| `family`             | `string` | A CSS font family list, such as `"JetBrains Mono", D2Coding, monospace`. |
| `size`               | `number` | The font size in CSS pixels.                                             |
| `weight`             | `number` | The font weight of regular text, such as `400`.                          |
| `lineHeight`         | `number` | The row height as a multiple of the font size.                           |

:::

::: fw flutter

| `FontSettings` field | Type           | Description                                                   |
| -------------------- | -------------- | ------------------------------------------------------------- |
| `family`             | `String?`      | One family, or `null` for the platform's monospace font.      |
| `fallbackFamilies`   | `List<String>` | The families a character the chosen font lacks falls back to. |
| `size`               | `double`       | The font size in logical pixels.                              |
| `weight`             | `FontWeight`   | The font weight of regular text.                              |
| `lineHeight`         | `double`       | The row height as a multiple of the font size.                |

One family and a fallback list rather than one CSS list, because that is the shape `ui.TextStyle` takes.

:::

### RenderTheme

The colors a renderer draws with.

::: fw js

`readTheme` builds it from the `--lognal-*` custom properties, and any CSS color works.

| Field                                                                                                             | Type                                             | CSS property                                            |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------- |
| `background`, `foreground`, `muted`, `accent`                                                                     | `string`                                         | `--lognal-background` and so on                         |
| `selection`, `match`, `separator`, `hover`, `searchMatch`, `searchCurrent`, `link`, `entrySelection`, `focusRing` | `string`                                         | `--lognal-selection` and so on                          |
| `error`, `errorBackground`, `warn`, `warnBackground`, `info`, `debug`                                             | `string`                                         | `--lognal-error`, `--lognal-error-background` and so on |
| `tokens`                                                                                                          | `Record<Exclude<StyleToken, 'default'>, string>` | `--lognal-token-*`                                      |
| `ansi`                                                                                                            | `string[]`                                       | `--lognal-ansi-0` to `--lognal-ansi-15`                 |

`DEFAULT_RENDER_THEME` holds the colors used until a theme is read from CSS. They are the dark palette of `lognal.css`, and a unit test keeps the two equal.

:::

::: fw flutter

It is the `renderer` half of a [`LognalTheme`](/reference/log-viewer#lognaltheme), and every field is a `Color`.

| Field                                                                                                             | Type                        |
| ----------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `background`, `foreground`, `muted`, `accent`                                                                     | `Color`                     |
| `selection`, `match`, `separator`, `hover`, `searchMatch`, `searchCurrent`, `link`, `entrySelection`, `focusRing` | `Color`                     |
| `error`, `errorBackground`, `warn`, `warnBackground`, `info`, `debug`                                             | `Color`                     |
| `tokens`                                                                                                          | `Map<StyleToken, Color>`    |
| `ansi`                                                                                                            | `List<Color>`, sixteen long |

`resolveTextColor(color, theme)` turns a [`TextColor`](/reference/types#textstyle) into a `Color` against one of these, which is how an ANSI index reaches the palette.

:::

### CanvasRenderer

::: fw js

```ts
new CanvasRenderer(ownerDocument?: Document)
```

The built-in renderer. It draws on a `<canvas>` with the 2D context and repaints the visible rows every frame. Plain ASCII text in one style is drawn with one `fillText` call. Other text is drawn one grapheme cluster at a time at its grid position, so wide characters and characters from a fallback font stay aligned. Box-drawing characters are drawn as lines so table borders join across rows.

:::

::: fw flutter

```dart
CanvasLogRenderer()
```

The built-in renderer, which the widget's painter uses. It builds a `ui.Paragraph` for each run and keeps them in a small cache keyed by text, style and font, so a row that has not changed is not laid out again. Plain runs are drawn as one paragraph. Other text is drawn one grapheme cluster at a time at its grid position, so wide characters and characters from a fallback font stay aligned. Box-drawing characters are drawn as lines so table borders join across rows.

:::

### A custom renderer

::: fw js

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

:::

::: fw flutter

A renderer of your own extends `LogRenderer` and draws a frame onto a canvas. The viewer does not take one as an option, so a painter of your own is a widget of your own over the same controller:

```dart
class MyRenderer extends LogRenderer {
  // theme, setFont, metrics and dispose, then:
  @override
  void paint(Canvas canvas, Size size, RenderFrame frame) {
    final double cell = metrics.width;
    final double gutter = frame.paddingLeft + (frame.timestampCells + frame.markerCells) * cell;
    double y = frame.offsetY;

    for (final VisualRow row in frame.rows) {
      for (final RowRun run in row.runs) {
        // Draw run.text at gutter + run.column * cell - frame.scrollX, y.
      }

      y += metrics.height;
    }
  }
}
```

`CustomPaint` with a painter that calls it, a `Listener` over the controller's `hitTest`, and the controller's `frame()` for what to draw are the three pieces the built-in widget puts together.

:::
