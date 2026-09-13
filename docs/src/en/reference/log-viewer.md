---
order: 1
description: Reference for the LogViewer class, its options, methods, events and labels, the theme and font readers, formatTimestamp, and the React LogViewer component.
---

# LogViewer

```ts
import { LogViewer } from 'lognal';

const viewer = new LogViewer(container, options);
```

A log viewer: a toolbar, the log drawn by a renderer, an optional input line and a status bar. The viewer handles scrolling, selection, the keyboard and accessibility, and hands each frame to the renderer. Import `lognal/style.css` once for the layout and the themes.

## Constructor

```ts
new LogViewer(container: HTMLElement, options?: LogViewerOptions)
```

Creates the viewer and appends its root element to `container`.

## Properties

| Property      | Type             | Description                                                                                         |
| ------------- | ---------------- | --------------------------------------------------------------------------------------------------- |
| `store`       | `LogStore`       | The store the viewer shows. Read-only.                                                              |
| `layout`      | `LogLayout`      | The layout of the viewer. Read-only.                                                                |
| `element`     | `HTMLDivElement` | The root element, with the class `lognal`. Read-only.                                               |
| `console`     | `LognalConsole`  | An object with the console methods that writes to the store. It is created on first use and reused. |
| `isFollowing` | `boolean`        | Whether the view follows new entries.                                                               |

## Methods

| Method                                                               | Returns             | Description                                                                                                                                                                                                                              |
| -------------------------------------------------------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `setOptions(options: Omit<LogViewerOptions, 'store' \| 'renderer'>)` | `void`              | Changes the options given and keeps the others. A new `locale` switches the built-in labels and keeps the overrides from `labels`.                                                                                                       |
| `write(text: string, options?: WriteOptions)`                        | `void`              | Adds text as one entry. Line breaks stay inside the entry.                                                                                                                                                                               |
| `writeLines(text: string, options?: WriteOptions)`                   | `void`              | Adds text as one entry per line.                                                                                                                                                                                                         |
| `hookConsole(target?: Console, options?: HookConsoleOptions)`        | `() => void`        | Records a console, `console` by default, into the store. Returns a function that stops recording. Recording also stops when the viewer is disposed.                                                                                      |
| `clear()`                                                            | `void`              | Removes every entry from the store and clears the selection.                                                                                                                                                                             |
| `setFilter(filter: LogFilter \| null)`                               | `void`              | Sets the filter. `null` shows every entry. Emits `filter`.                                                                                                                                                                               |
| `getFilter()`                                                        | `LogFilter \| null` | Returns the filter.                                                                                                                                                                                                                      |
| `setFollowing(following: boolean)`                                   | `void`              | Turns following on or off. Turning it on scrolls to the newest entry. Emits `follow` when the value changes.                                                                                                                             |
| `scrollToTop()`                                                      | `void`              | Stops following and scrolls to the first row.                                                                                                                                                                                            |
| `scrollToBottom()`                                                   | `void`              | Turns following on, which scrolls to the newest entry.                                                                                                                                                                                   |
| `scrollToEntry(entryId: number)`                                     | `void`              | Stops following and scrolls so the entry is at the top. Does nothing when the entry is not visible.                                                                                                                                      |
| `getSelectionText()`                                                 | `string`            | Returns the selected text, or an empty string.                                                                                                                                                                                           |
| `selectAll()`                                                        | `void`              | Selects the text of every visible entry. Emits `selection`.                                                                                                                                                                              |
| `clearSelection()`                                                   | `void`              | Clears the selection. Emits `selection` when there was one.                                                                                                                                                                              |
| `copySelection()`                                                    | `Promise<boolean>`  | Copies the selected text to the clipboard. Resolves to whether anything was copied.                                                                                                                                                      |
| `getEntryText(entryId: number, options?: EntryTextOptions)`          | `string`            | Returns the whole of an entry, whether its values are open or closed, in the format of `options.format`. With `timestamp: true`, the time of the entry comes first. Returns an empty string for an entry that is no longer in the store. |
| `copyEntry(entryId: number, options?: EntryTextOptions)`             | `Promise<boolean>`  | Copies the text `getEntryText` returns to the clipboard, together with HTML in the colors of the theme for `'formatted'`. Resolves to whether anything was copied.                                                                       |
| `expandEntry(entryId: number)`                                       | `void`              | Expands every value of an entry, and every value inside them, as far as they were captured.                                                                                                                                              |
| `collapseEntry(entryId: number)`                                     | `void`              | Collapses every value of an entry, including an error logged on its own.                                                                                                                                                                 |
| `openSearch(query?: string)`                                         | `void`              | Opens the search bar and searches for `query`, for the text already in the bar, or for a selection on one line. Does nothing when `search` is off.                                                                                       |
| `closeSearch()`                                                      | `void`              | Closes the search bar and removes the highlights.                                                                                                                                                                                        |
| `findNext()`                                                         | `void`              | Makes the next match current and scrolls to it. After the last match comes the first.                                                                                                                                                    |
| `findPrevious()`                                                     | `void`              | Makes the previous match current and scrolls to it.                                                                                                                                                                                      |
| `focus()`                                                            | `void`              | Moves focus to the input line, or to the log when there is no input line.                                                                                                                                                                |
| `refresh()`                                                          | `void`              | Reads the theme and the font from CSS again, for example after the page changed them.                                                                                                                                                    |
| `on(name, listener)`                                                 | `() => void`        | Calls `listener` for an event. Returns a function that removes the listener.                                                                                                                                                             |
| `dispose()`                                                          | `void`              | Removes the viewer from the page and stops everything it started. Calling it again does nothing.                                                                                                                                         |

## Events

```ts
const copyButton = document.querySelector<HTMLButtonElement>('#copy')!;
const off = viewer.on('selection', (text) => {
	copyButton.disabled = text === '';
});

// Later:
off();
```

| Event       | Value               | Emitted when                                              |
| ----------- | ------------------- | --------------------------------------------------------- |
| `follow`    | `boolean`           | Following was turned on or off.                           |
| `filter`    | `LogFilter \| null` | The filter changed, from the toolbar or from `setFilter`. |
| `selection` | `string`            | The selected text changed.                                |

The events and their values are described by the `LogViewerEvents` type.

## LogViewerOptions

| Option       | Type                                    | Default          | Description                                                                                                                   |
| ------------ | --------------------------------------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `store`      | `LogStore`                              | A new store      | A store to show. Several viewers can share one store.                                                                         |
| `core`       | `Partial<CoreOptions>`                  | `{}`             | Core options. The store options also apply to a store passed in `store`.                                                      |
| `theme`      | `ThemeMode`                             | `'auto'`         | The color scheme. `'auto'` follows the operating system.                                                                      |
| `font`       | `Partial<FontSettings>`                 | `{}`             | The font. Values left out come from the `--lognal-font-*` CSS properties.                                                     |
| `timestamps` | `boolean \| TimestampFormat`            | `true`           | Whether each entry shows its time, and in which format. `true` is `'time'`.                                                   |
| `follow`     | `boolean`                               | `true`           | Whether the view follows new entries at the start.                                                                            |
| `toolbar`    | `boolean \| Partial<ToolbarOptions>`    | `true`           | The toolbar, or `false` to hide it. An object turns single controls off.                                                      |
| `statusBar`  | `boolean`                               | `true`           | Whether the status bar is shown.                                                                                              |
| `input`      | `InputOptions \| null`                  | `null`           | The input line. Leave it out for a read-only viewer.                                                                          |
| `locale`     | `string`                                | `undefined`      | The language of the built-in labels and number formatting, such as `'en'` or `'ko'`.                                          |
| `labels`     | `Partial<ViewerLabels>`                 | `{}`             | Labels that replace the built-in ones.                                                                                        |
| `entryMenu`  | `boolean \| EntryMenuOptions`           | `true`           | The menu of actions of the entry under the pointer, or `false` to turn it off.                                                |
| `search`     | `boolean`                               | `true`           | Whether Ctrl+F or Cmd+F, while focus is in the viewer, opens a search bar that highlights every match without hiding entries. |
| `renderer`   | `(ownerDocument: Document) => Renderer` | `CanvasRenderer` | Creates the renderer.                                                                                                         |

## CoreOptions

`CoreOptions` combines `LogStoreOptions`, `LayoutOptions` and a filter.

| Option           | Type                | Default  | Description                                                                           |
| ---------------- | ------------------- | -------- | ------------------------------------------------------------------------------------- |
| `maxEntries`     | `number`            | `10000`  | The most entries the store keeps. Use `Infinity` to keep everything.                  |
| `mergeRepeats`   | `boolean`           | `true`   | Whether a message identical to the one before it increases that entry's repeat count. |
| `wrap`           | `WrapMode`          | `'word'` | `'word'`, `'char'` or `'none'`.                                                       |
| `tabSize`        | `number`            | `8`      | Cells between tab stops.                                                              |
| `ambiguousWidth` | `AmbiguousWidth`    | `1`      | Cells an East Asian Ambiguous character takes, `1` or `2`.                            |
| `maxClusters`    | `number`            | `10000`  | The most grapheme clusters a line keeps. The rest is replaced with `…`.               |
| `filter`         | `LogFilter \| null` | `null`   | The filter. See [`LogFilter`](/reference/layout#logfilter).                           |

## ToolbarOptions

Every control is `true` by default.

| Option   | Type      | Control                            |
| -------- | --------- | ---------------------------------- |
| `follow` | `boolean` | Follow new logs                    |
| `clear`  | `boolean` | Clear logs                         |
| `scroll` | `boolean` | Scroll to top and Scroll to bottom |
| `wrap`   | `boolean` | Wrap long lines                    |
| `filter` | `boolean` | The filter field                   |
| `levels` | `boolean` | The log level menu                 |

## InputOptions

| Option        | Type                                              | Default                   | Description                                                                                                                                            |
| ------------- | ------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `onSubmit`    | `(command: string, viewer: LogViewer) => unknown` | Required                  | Called with each command. A returned value, or the value a returned promise resolves to, is printed as the reply. Return `undefined` to print nothing. |
| `prompt`      | `string`                                          | `'>'`                     | The prompt shown before the input.                                                                                                                     |
| `placeholder` | `string`                                          | `labels.inputPlaceholder` | The placeholder of the input.                                                                                                                          |
| `echo`        | `boolean`                                         | `true`                    | Whether the command is added to the log before it runs.                                                                                                |
| `historySize` | `number`                                          | `100`                     | How many past commands the arrow keys go through.                                                                                                      |

## EntryMenuOptions

| Option  | Type                                                      | Default | Description                                                                                                                                                         |
| ------- | --------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `copy`  | `boolean`                                                 | `true`  | Whether the menu starts with the copy items: **Copy as text**, **Copy with timestamp**, **Copy as formatted text** and, for an entry with values, **Copy as data**. |
| `items` | `(entry: LogEntry, viewer: LogViewer) => EntryMenuItem[]` | None    | Called every time the menu opens. The items it returns follow the built-in ones, below a separator.                                                                 |

With `copy: false` and no `items`, the menu is off. A menu that would have no items does not open.

### EntryMenuItem

| Field      | Type                                           | Description                                             |
| ---------- | ---------------------------------------------- | ------------------------------------------------------- |
| `label`    | `string`                                       | The text of the item.                                   |
| `onSelect` | `(entry: LogEntry, viewer: LogViewer) => void` | Called with the entry the menu opened for, when chosen. |

### EntryTextOptions

| Option      | Type              | Default  | Description                                                                                                                          |
| ----------- | ----------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `format`    | `EntryTextFormat` | `'text'` | How the entry is written.                                                                                                            |
| `timestamp` | `boolean`         | `false`  | Whether the text starts with the time of the entry, in the format of `timestamps`, or `'time'` when it is off. Ignored for `'data'`. |

| `EntryTextFormat` | Result                                                                                                                                                                                                                                                                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`          | Plain text, with every value in full on one line.                                                                                                                                                                                                                                                                                           |
| `'formatted'`     | Values too long for one line broken over several indented lines. `copyEntry` also copies HTML with the colors of the theme.                                                                                                                                                                                                                 |
| `'data'`          | The values as JSON: the value, an array of the values when there are several, or the text of the entry when it has none. `undefined` becomes `null`, sets become arrays, maps with text keys become objects, errors become objects with `name`, `message` and `stack`, and types JSON lacks, such as `10n` or `Symbol(token)`, become text. |

## ViewerLabels

Every label is used as visible text or as an accessible name.

| Label                | English (`EN_LABELS`)             | Korean (`KO_LABELS`)          |
| -------------------- | --------------------------------- | ----------------------------- |
| `viewer`             | Log viewer                        | 로그 뷰어                     |
| `toolbar`            | Log viewer tools                  | 로그 뷰어 도구                |
| `follow`             | Follow new logs                   | 새 로그 따라가기              |
| `clear`              | Clear logs                        | 로그 지우기                   |
| `scrollToTop`        | Scroll to top                     | 맨 위로 이동                  |
| `scrollToBottom`     | Scroll to bottom                  | 맨 아래로 이동                |
| `wrap`               | Wrap long lines                   | 긴 줄 바꾸기                  |
| `filter`             | Filter                            | 필터                          |
| `invalidFilter`      | The filter is not a valid pattern | 필터 패턴이 올바르지 않습니다 |
| `levels`             | Log levels                        | 로그 수준                     |
| `levelAll`           | All levels                        | 모든 수준                     |
| `levelLog`           | Log and above                     | 로그 이상                     |
| `levelInfo`          | Info and above                    | 정보 이상                     |
| `levelWarn`          | Warnings and errors               | 경고와 오류                   |
| `levelError`         | Errors only                       | 오류만                        |
| `input`              | Command                           | 명령                          |
| `inputPlaceholder`   | Type a command                    | 명령을 입력하세요             |
| `newLogs`            | New logs                          | 새 로그                       |
| `entryList`          | Visible log entries               | 화면에 보이는 로그            |
| `entryActions`       | Entry actions                     | 항목 작업                     |
| `copyEntry`          | Copy as text                      | 텍스트로 복사                 |
| `copyEntryWithTime`  | Copy with timestamp               | 타임스탬프와 함께 복사        |
| `copyEntryFormatted` | Copy as formatted text            | 서식 있는 텍스트로 복사       |
| `copyEntryData`      | Copy as data                      | 데이터로 복사                 |
| `expandAll`          | Expand all                        | 모두 펼치기                   |
| `collapseAll`        | Collapse all                      | 모두 접기                     |
| `search`             | Find in log                       | 로그에서 찾기                 |
| `searchPrevious`     | Previous match                    | 이전 결과                     |
| `searchNext`         | Next match                        | 다음 결과                     |
| `searchClose`        | Close search                      | 검색 닫기                     |
| `searchResults`      | `3/12`, `No results`              | `3/12`, `결과 없음`           |
| `following`          | Following                         | 따라가는 중                   |
| `paused`             | Paused                            | 멈춤                          |
| `entries`            | `3 entries`, `1 of 3 entries`     | `로그 3개`, `로그 3개 중 1개` |

`searchResults` is a function: `(current: number, total: number, format: (value: number) => string) => string`, where `current` is 0 while no match is current.

`entries` is a function: `(shown: number, total: number, format: (value: number) => string) => string`. `format` formats a number for the locale.

### labelsFor

```ts
labelsFor(locale: string | undefined): ViewerLabels
```

Returns `KO_LABELS` for `ko` and tags such as `ko-KR`, and `EN_LABELS` for every other language.

## Themes and fonts

### ThemeMode

```ts
type ThemeMode = 'auto' | 'light' | 'dark';
```

### readTheme

```ts
readTheme(element: Element): RenderTheme
```

Reads the render colors from the `--lognal-*` custom properties of an element. A property that is not set keeps the value from `DEFAULT_RENDER_THEME`, which is the dark palette of `lognal.css`.

### readFont

```ts
readFont(element: Element, overrides: Partial<FontSettings>): FontSettings
```

Reads the font from the `--lognal-font-family`, `--lognal-font-size`, `--lognal-font-weight` and `--lognal-line-height` properties, with `overrides` on top. The size may be written in `px`, `rem` or `em`. The line height may be a number or an `em` value, which is a multiple of the size, a percentage, or a length in `px` or `rem`, which is divided by the size. A missing or invalid value falls back to `DEFAULT_FONT`.

### DEFAULT_FONT

| Field        | Value                                                                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `family`     | `ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "D2Coding", "Noto Sans Mono CJK KR", "Liberation Mono", monospace` |
| `size`       | `13`                                                                                                                          |
| `weight`     | `400`                                                                                                                         |
| `lineHeight` | `1.6`                                                                                                                         |

## Timestamps

### TimestampFormat

```ts
type TimestampFormat = 'time' | 'datetime' | 'iso' | ((time: number) => string);
```

### formatTimestamp

```ts
formatTimestamp(time: number, format?: TimestampFormat): string
```

Formats an epoch time in milliseconds. `format` defaults to `'time'`.

| Format       | Example                    |
| ------------ | -------------------------- |
| `'time'`     | `14:03:09.120`             |
| `'datetime'` | `2026-09-13 14:03:09.120`  |
| `'iso'`      | `2026-09-13T05:03:09.120Z` |

`'time'` and `'datetime'` use local time. `'iso'` uses UTC.

## React component

```tsx
import { LogViewer, type LogViewerProps } from 'lognal/react';
```

`LogViewerProps` extends `LogViewerOptions` with the props below. The component forwards its ref to the `LogViewer` instance. See [React](/guide/react) for how prop changes are applied.

| Prop                | Type                                  | Description                                                                  |
| ------------------- | ------------------------------------- | ---------------------------------------------------------------------------- |
| `className`         | `string`                              | The class of the container.                                                  |
| `style`             | `CSSProperties`                       | The style of the container, applied on top of `height: 100%`.                |
| `hookConsole`       | `boolean \| HookConsoleOptions`       | Records the global `console` into the viewer while the component is mounted. |
| `onReady`           | `(viewer: LogViewer \| null) => void` | Called with the viewer once it exists, and with `null` after it is disposed. |
| `onFollowChange`    | `(following: boolean) => void`        | The `follow` event.                                                          |
| `onFilterChange`    | `(filter: LogFilter \| null) => void` | The `filter` event.                                                          |
| `onSelectionChange` | `(text: string) => void`              | The `selection` event.                                                       |
