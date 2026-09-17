---
order: 1
description: Reference for the viewer, its options, methods, events and labels, the palettes and the font, and formatTimestamp.
---

# LogViewer

::: fw js

```ts
import { LogViewer } from 'lognal';

const viewer = new LogViewer(container, options);
```

A log viewer: a toolbar, the log drawn by a renderer, an optional input line and a status bar. The viewer handles scrolling, selection, the keyboard and accessibility, and hands each frame to the renderer. Import `lognal/style.css` once for the layout and the themes.

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

LogViewer(store: store, options: options);
```

A log viewer: a toolbar, the log drawn on a canvas, an optional input line and a status bar. The widget handles scrolling, selection, the keyboard and semantics, and hands each frame to the painter. The state behind it is a `LogViewerController`, which is where the methods on this page are.

The widget is built on `package:flutter/widgets.dart` alone, with no Material and no Cupertino, so it sits inside a `MaterialApp`, a `CupertinoApp` or a bare `WidgetsApp` without bringing a second design system along.

:::

## Constructor

::: fw js

```ts
new LogViewer(container: HTMLElement, options?: LogViewerOptions)
```

Creates the viewer and appends its root element to `container`.

:::

::: fw flutter

```dart
LogViewer({
  LogStore? store,
  LogViewerController? controller,
  LogViewerOptions options = const LogViewerOptions(),
  FocusNode? focusNode,
  bool autofocus = false,
})
```

Pass a `store` and the widget makes a controller over it, or pass a `controller` you already hold and keep it across rebuilds. Passing both is an error: the controller already has a store.

`options` always wins, controller or not, so an option that changes on a rebuild reaches the viewer.

:::

## Properties

::: fw js

| Property      | Type             | Description                                                                                         |
| ------------- | ---------------- | --------------------------------------------------------------------------------------------------- |
| `store`       | `LogStore`       | The store the viewer shows. Read-only.                                                              |
| `layout`      | `LogLayout`      | The layout of the viewer. Read-only.                                                                |
| `element`     | `HTMLDivElement` | The root element, with the class `lognal`. Read-only.                                               |
| `console`     | `LognalConsole`  | An object with the console methods that writes to the store. It is created on first use and reused. |
| `isFollowing` | `boolean`        | Whether the view follows new entries.                                                               |

:::

::: fw flutter

These are on `LogViewerController`, which extends `ChangeNotifier`.

| Property       | Type               | Description                                                                         |
| -------------- | ------------------ | ----------------------------------------------------------------------------------- |
| `store`        | `LogStore`         | The store the viewer shows.                                                         |
| `layout`       | `LogLayout`        | The layout of the viewer.                                                           |
| `search`       | `LogSearch`        | The search over the layout.                                                         |
| `options`      | `LogViewerOptions` | The options in use.                                                                 |
| `isFollowing`  | `bool`             | Whether the view follows new entries.                                               |
| `hasUnseen`    | `bool`             | Whether entries arrived while following was paused, which is what the button shows. |
| `filter`       | `LogFilter?`       | The filter.                                                                         |
| `muteRules`    | `List<MuteRule>`   | The rules that keep entries out of the log.                                         |
| `mutedCount`   | `int`              | How many of the entries the store holds those rules keep out.                       |
| `visibleCount` | `int`              | How many entries the log shows, which is what the status bar counts.                |
| `entryCount`   | `int`              | How many entries the store holds.                                                   |
| `themeName`    | `String`           | The palette in use, which the toolbar menu can change.                              |
| `isSearchOpen` | `bool`             | Whether the search bar is open.                                                     |

:::

## Methods

::: fw js

| Method                                                               | Returns             | Description                                                                                                                                                                                                                              |
| -------------------------------------------------------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `setOptions(options: Omit<LogViewerOptions, 'store' \| 'renderer'>)` | `void`              | Changes the options given and keeps the others. A new `locale` switches the built-in labels and keeps the overrides from `labels`.                                                                                                       |
| `write(text: string, options?: WriteOptions)`                        | `void`              | Adds text as one entry. Line breaks stay inside the entry.                                                                                                                                                                               |
| `writeLines(text: string, options?: WriteOptions)`                   | `void`              | Adds text as one entry per line.                                                                                                                                                                                                         |
| `hookConsole(target?: Console, options?: HookConsoleOptions)`        | `() => void`        | Records a console, `console` by default, into the store. Returns a function that stops recording. Recording also stops when the viewer is disposed.                                                                                      |
| `clear()`                                                            | `void`              | Removes every entry from the store and clears the selection.                                                                                                                                                                             |
| `setFilter(filter: LogFilter \| null)`                               | `void`              | Sets the filter. `null` shows every entry. Emits `filter`.                                                                                                                                                                               |
| `getFilter()`                                                        | `LogFilter \| null` | Returns the filter.                                                                                                                                                                                                                      |
| `getMuteRules()`                                                     | `MuteRule[]`        | Returns the rules that keep entries out of the log.                                                                                                                                                                                      |
| `setMuteRules(rules: readonly MuteRule[])`                           | `void`              | Replaces those rules. Emits `filter`.                                                                                                                                                                                                    |
| `getMutedCount()`                                                    | `number`            | How many of the entries the store holds those rules keep out of the log.                                                                                                                                                                 |
| `openMuteDialog()`                                                   | `void`              | Opens the dialog that manages the rules.                                                                                                                                                                                                 |
| `setFollowing(following: boolean)`                                   | `void`              | Turns following on or off. Turning it on scrolls to the newest entry. Emits `follow` when the value changes.                                                                                                                             |
| `scrollToTop()`                                                      | `void`              | Stops following and scrolls to the first row.                                                                                                                                                                                            |
| `scrollToBottom()`                                                   | `void`              | Turns following on, which scrolls to the newest entry.                                                                                                                                                                                   |
| `scrollToEntry(entryId: number)`                                     | `void`              | Stops following and scrolls so the entry is at the top. Does nothing when the entry is not visible.                                                                                                                                      |
| `getSelectionText(options?: EntryTextOptions)`                       | `string`            | Returns the selection as text, or an empty string: the selected text, or in entry mode the selected entries, each written with `options` the way `getEntryText` writes it.                                                               |
| `getSelectedEntryIds()`                                              | `number[]`          | Returns the ids of the visible selected entries, oldest first. In text mode, returns the ids of the entries the selected text runs through.                                                                                              |
| `selectAll()`                                                        | `void`              | Selects every visible entry: all of their text in text mode, or the entries in entry mode. Emits `selection`.                                                                                                                            |
| `clearSelection()`                                                   | `void`              | Clears the selection. Emits `selection` when there was one.                                                                                                                                                                              |
| `copySelection(options?: EntryTextOptions)`                          | `Promise<boolean>`  | Copies the selection to the clipboard: the selected text, or in entry mode the selected entries written with `options`, with HTML for `'formatted'`. Resolves to whether anything was copied.                                            |
| `getEntryText(entryId: number, options?: EntryTextOptions)`          | `string`            | Returns the whole of an entry, whether its values are open or closed, in the format of `options.format`. With `timestamp: true`, the time of the entry comes first. Returns an empty string for an entry that is no longer in the store. |
| `copyEntry(entryId: number, options?: EntryTextOptions)`             | `Promise<boolean>`  | Copies the text `getEntryText` returns to the clipboard, together with HTML in the colors of the theme for `'formatted'`. Resolves to whether anything was copied.                                                                       |
| `expandEntry(entryId: number)`                                       | `void`              | Expands every value of an entry, and every value inside them, as far as they were captured.                                                                                                                                              |
| `collapseEntry(entryId: number)`                                     | `void`              | Collapses every value of an entry, including an error logged on its own.                                                                                                                                                                 |
| `openSearch(query?: string, options?: SearchOptions)`                | `void`              | Opens the search bar and searches for `query`, for the text already in the bar, or for a selection on one line. `options` switches the toggles of the bar. Does nothing when `search` is off.                                            |
| `closeSearch()`                                                      | `void`              | Closes the search bar and removes the highlights.                                                                                                                                                                                        |
| `findNext()`                                                         | `void`              | Makes the next match current and scrolls to it. After the last match comes the first.                                                                                                                                                    |
| `findPrevious()`                                                     | `void`              | Makes the previous match current and scrolls to it.                                                                                                                                                                                      |
| `focus()`                                                            | `void`              | Moves focus to the input line, or to the log when there is no input line.                                                                                                                                                                |
| `refresh()`                                                          | `void`              | Reads the theme and the font from CSS again, for example after the page changed them.                                                                                                                                                    |
| `on(name, listener)`                                                 | `() => void`        | Calls `listener` for an event. Returns a function that removes the listener.                                                                                                                                                             |
| `dispose()`                                                          | `void`              | Removes the viewer from the page and stops everything it started. Calling it again does nothing.                                                                                                                                         |

:::

::: fw flutter

These are on `LogViewerController`. The ones that change what is drawn notify the controller's listeners.

| Method                                                        | Returns        | Description                                                                                                                                                     |
| ------------------------------------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `setOptions(LogViewerOptions next)`                           | `void`         | Replaces the options. The widget calls it on every build, and an identical value costs nothing.                                                                 |
| `write(String text, [WriteOptions options])`                  | `void`         | Adds text as one entry. Line breaks stay inside the entry.                                                                                                      |
| `writeLines(String text, [WriteOptions options])`             | `void`         | Adds text as one entry per line.                                                                                                                                |
| `clear()`                                                     | `void`         | Removes every entry from the store and clears the selection.                                                                                                    |
| `setFilter(LogFilter? filter)`                                | `void`         | Sets the filter. `null` shows every entry.                                                                                                                      |
| `setMuteRules(List<MuteRule> rules)`                          | `void`         | Replaces the rules that keep entries out of the log.                                                                                                            |
| `setFollowing(bool following)`                                | `void`         | Turns following on or off. Turning it on scrolls to the newest entry.                                                                                           |
| `scrollToTop()`                                               | `void`         | Stops following and scrolls to the first row.                                                                                                                   |
| `scrollToBottom()`                                            | `void`         | Turns following on, which scrolls to the newest entry.                                                                                                          |
| `scrollToEntry(int entryId, {bool top})`                      | `void`         | Stops following and scrolls to the entry. Does nothing when the entry is not visible.                                                                           |
| `selectionText([EntryTextOptions options])`                   | `String`       | Returns the selection as text, or an empty string: the selected text, or in entry mode the selected entries, each written the way `entryText` writes one.       |
| `selectedEntryIds`                                            | `List<int>`    | The ids of the visible selected entries, oldest first. In text mode, the ids of the entries the selected text runs through.                                     |
| `selectAll()`                                                 | `void`         | Selects every visible entry: all of their text in text mode, or the entries in entry mode.                                                                      |
| `clearSelection()`                                            | `void`         | Clears the selection.                                                                                                                                           |
| `copySelection([EntryTextOptions options])`                   | `Future<bool>` | Copies the selection to the clipboard and completes with whether anything was copied.                                                                           |
| `entryText(int entryId, [EntryTextOptions options])`          | `String`       | Returns the whole of an entry, whether its values are open or closed, in the format of `options.format`. An entry no longer in the store gives an empty string. |
| `entriesText(List<int> entryIds, [EntryTextOptions options])` | `String`       | The same for several entries, oldest first, separated by line breaks. `EntryTextFormat.data` gives one JSON array.                                              |
| `copyEntry(int entryId, [EntryTextOptions options])`          | `Future<bool>` | Copies what `entryText` returns and completes with whether anything was copied.                                                                                 |
| `copyEntries(List<int> entryIds, [EntryTextOptions options])` | `Future<bool>` | The same for several entries.                                                                                                                                   |
| `expandEntry(int entryId)`                                    | `void`         | Expands every value of an entry, and every value inside them, as far as they were captured.                                                                     |
| `collapseEntry(int entryId)`                                  | `void`         | Collapses every value of an entry, including an error logged on its own.                                                                                        |
| `openSearch([String? query, SearchOptions options])`          | `void`         | Opens the search bar and searches for `query`, for the text already in the bar, or for a selection on one line. Does nothing when `search` is off.              |
| `closeSearch()`                                               | `void`         | Closes the search bar and removes the highlights.                                                                                                               |
| `findNext()`, `findPrevious()`                                | `void`         | Makes the next or the previous match current and scrolls to it. After the last match comes the first.                                                           |
| `setTheme(String name)`                                       | `void`         | Picks a palette, the way the toolbar menu does.                                                                                                                 |
| `toggleWrap()`                                                | `void`         | Turns wrapping off, or back on to the mode it turned off.                                                                                                       |
| `refresh()`                                                   | `void`         | Draws the viewer again, for a change the controller cannot see.                                                                                                 |
| `dispose()`                                                   | `void`         | Stops listening to the store and releases what it cached. A controller the widget made is disposed with the widget.                                             |

The controller also carries the geometry the widget draws with: `frame()`, `hitTest(Offset)`, `positionAt(Offset)`, `setViewport(Size, CellMetrics)`, `setTopPixels(double)` and `setScrollX(double)`. They are public because a renderer of your own would need them, and an application usually does not.

:::

## Events

::: fw js

```ts
const copyButton = document.querySelector<HTMLButtonElement>('#copy')!;
const off = viewer.on('selection', (text) => {
	copyButton.disabled = text === '';
});

// Later:
off();
```

| Event       | Value               | Emitted when                                                             |
| ----------- | ------------------- | ------------------------------------------------------------------------ |
| `follow`    | `boolean`           | Following was turned on or off.                                          |
| `filter`    | `LogFilter \| null` | The filter changed, from the toolbar or from `setFilter`.                |
| `selection` | `string`            | The selection changed. The value is the text `getSelectionText` returns. |

The events and their values are described by the `LogViewerEvents` type.

:::

::: fw flutter

`LogViewerController` is a `ChangeNotifier`, so there is one signal rather than three:

```dart
controller.addListener(() => setState(() {}));
```

It notifies whenever anything the viewer draws changes, including following, the filter and the selection. Read `isFollowing`, `filter` or `selectionText()` for the value that changed. The store has its own listener for the entries alone, which is `store.listen`.

:::

## LogViewerOptions

::: fw js

| Option          | Type                                    | Default                        | Description                                                                                                                   |
| --------------- | --------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `store`         | `LogStore`                              | A new store                    | A store to show. Several viewers can share one store.                                                                         |
| `core`          | `Partial<CoreOptions>`                  | `{}`                           | Core options. The store options also apply to a store passed in `store`.                                                      |
| `theme`         | `ThemeMode`                             | `'auto'`                       | The palette. `'auto'` follows the operating system, and any other name goes to `data-theme`.                                  |
| `themes`        | `(ThemeMode \| ThemeChoice)[]`          | `['auto', ...BUILT_IN_THEMES]` | The themes the toolbar menu offers. A string is a name; an object gives it a label.                                           |
| `font`          | `Partial<FontSettings>`                 | `{}`                           | The font. Values left out come from the `--lognal-font-*` CSS properties.                                                     |
| `timestamps`    | `boolean \| TimestampFormat`            | `true`                         | Whether each entry shows its time, and in which format. `true` is `'time'`.                                                   |
| `follow`        | `boolean`                               | `true`                         | Whether the view follows new entries at the start.                                                                            |
| `toolbar`       | `boolean \| Partial<ToolbarOptions>`    | `true`                         | The toolbar, or `false` to hide it. An object turns single controls off.                                                      |
| `statusBar`     | `boolean`                               | `true`                         | Whether the status bar is shown.                                                                                              |
| `input`         | `InputOptions \| null`                  | `null`                         | The input line. Leave it out for a read-only viewer.                                                                          |
| `locale`        | `string`                                | `undefined`                    | The language of the built-in labels and number formatting, such as `'en'` or `'ko'`.                                          |
| `labels`        | `Partial<ViewerLabels>`                 | `{}`                           | Labels that replace the built-in ones.                                                                                        |
| `entryMenu`     | `boolean \| EntryMenuOptions`           | `true`                         | The menu of actions of the entry under the pointer, or `false` to turn it off.                                                |
| `search`        | `boolean`                               | `true`                         | Whether Ctrl+F or Cmd+F, while focus is in the viewer, opens a search bar that highlights every match without hiding entries. |
| `linkClick`     | `LinkClick`                             | `'confirm'`                    | What a click or a tap on a link does. See [`LinkClick`](#linkclick).                                                          |
| `selectionMode` | `SelectionMode`                         | `'text'`                       | Whether the pointer and the keyboard select text or whole entries. See [`SelectionMode`](#selectionmode).                     |
| `tooltips`      | `boolean`                               | `true`                         | Whether a toolbar control shows its name as soon as the pointer reaches it.                                                   |
| `renderer`      | `(ownerDocument: Document) => Renderer` | `CanvasRenderer`               | Creates the renderer.                                                                                                         |

:::

::: fw flutter

| Option            | Type                             | Default                      | Description                                                                                               |
| ----------------- | -------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------- |
| `core`            | `CoreOptions`                    | `CoreOptions()`              | Core options. The store options also apply to a store the widget was given.                               |
| `theme`           | `String`                         | `'auto'`                     | The palette: `auto`, a palette that ships with lognal, or a name `themeResolver` answers to.              |
| `themes`          | `List<ThemeChoice>?`             | `auto` and the built-in ones | The themes the toolbar menu offers.                                                                       |
| `themeResolver`   | `LognalTheme? Function(String)?` | `null`                       | Returns the palette for a name of your own, or `null` to fall back.                                       |
| `font`            | `FontSettings`                   | `FontSettings()`             | The font. See [`FontSettings`](#fontsettings).                                                            |
| `timestamps`      | `bool`                           | `true`                       | Whether each entry shows its time.                                                                        |
| `timestampFormat` | `TimestampFormat`                | `TimestampFormat.time`       | How the time is written, unless `formatTimestamp` replaces it.                                            |
| `formatTimestamp` | `String Function(DateTime)?`     | `null`                       | Writes the time of an entry in your own format.                                                           |
| `follow`          | `bool`                           | `true`                       | Whether the view follows new entries at the start.                                                        |
| `toolbar`         | `ViewerToolbarOptions`           | `ViewerToolbarOptions()`     | The toolbar, or `ViewerToolbarOptions.hidden` to leave it out.                                            |
| `statusBar`       | `bool`                           | `true`                       | Whether the status bar is shown.                                                                          |
| `input`           | `InputOptions?`                  | `null`                       | The input line. Leave it out for a read-only viewer.                                                      |
| `locale`          | `String?`                        | `null`                       | The language of the built-in labels, such as `en` or `ko`.                                                |
| `labels`          | `ViewerLabels?`                  | `null`                       | Labels that replace the built-in ones, as a complete set.                                                 |
| `entryMenu`       | `EntryMenuOptions`               | `EntryMenuOptions()`         | The menu of actions of the entry under the pointer.                                                       |
| `search`          | `bool`                           | `true`                       | Whether the find shortcut opens a search bar that highlights every match without hiding entries.          |
| `linkClick`       | `LinkClick`                      | `LinkClick.confirm`          | What a tap on a link does. See [`LinkClick`](#linkclick).                                                 |
| `selectionMode`   | `SelectionMode`                  | `SelectionMode.text`         | Whether the pointer and the keyboard select text or whole entries. See [`SelectionMode`](#selectionmode). |
| `tooltips`        | `bool`                           | `true`                       | Whether a toolbar control shows its name as soon as the pointer reaches it.                               |
| `formatNumber`    | `NumberFormatter`                | `formatCount`                | Formats a count for the reader's language.                                                                |
| `onOpenLink`      | `void Function(String)?`         | `null`                       | Opens a link. Without it, `linkClick` still draws links and still asks, and the answer goes nowhere.      |

There is no `store` option and no `renderer` option. The store is a constructor argument of the widget or of the controller, and the painter is chosen by the widget.

`copyWith` returns a copy with the fields given replaced, which is how an option changes between builds.

:::

## CoreOptions

`CoreOptions` combines the store options, the layout options and a filter.

::: fw js

| Option           | Type                | Default  | Description                                                                                                    |
| ---------------- | ------------------- | -------- | -------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `number`            | `10000`  | The most entries the store keeps. Use `Infinity` to keep everything.                                           |
| `mergeRepeats`   | `RepeatMode`        | `true`   | What happens to a message identical to the one before it. See [`RepeatMode`](/reference/log-store#repeatmode). |
| `wrap`           | `WrapMode`          | `'word'` | `'word'`, `'char'` or `'none'`.                                                                                |
| `tabSize`        | `number`            | `8`      | Cells between tab stops.                                                                                       |
| `ambiguousWidth` | `AmbiguousWidth`    | `1`      | Cells an East Asian Ambiguous character takes, `1` or `2`.                                                     |
| `maxClusters`    | `number`            | `10000`  | The most grapheme clusters a line keeps. The rest is replaced with `…`.                                        |
| `links`          | `boolean`           | `true`   | Whether `http` and `https` addresses in the text become links.                                                 |
| `filter`         | `LogFilter \| null` | `null`   | The filter. See [`LogFilter`](/reference/layout#logfilter).                                                    |

:::

::: fw flutter

| Option           | Type             | Default              | Description                                                                                                      |
| ---------------- | ---------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `int`            | `10000`              | The most entries the store keeps.                                                                                |
| `mergeRepeats`   | `MergeRepeats`   | `MergeRepeats.merge` | What happens to a message identical to the one before it. See [`MergeRepeats`](/reference/log-store#repeatmode). |
| `wrap`           | `WrapMode`       | `WrapMode.word`      | `WrapMode.word`, `WrapMode.char` or `WrapMode.none`.                                                             |
| `tabSize`        | `int`            | `8`                  | Cells between tab stops.                                                                                         |
| `ambiguousWidth` | `AmbiguousWidth` | `1`                  | Cells an East Asian Ambiguous character takes, `1` or `2`.                                                       |
| `maxClusters`    | `int`            | `10000`              | The most grapheme clusters a line keeps. The rest is replaced with `…`.                                          |
| `links`          | `bool`           | `true`               | Whether `http` and `https` addresses in the text become links.                                                   |
| `filter`         | `LogFilter?`     | `null`               | The filter. See [`LogFilter`](/reference/layout#logfilter).                                                      |

`storeOptions` and `layoutOptions` return the halves that belong to the store and to the layout. `copyWith` takes `clearFilter: true` to remove a filter, because passing `null` to a named parameter cannot be told from leaving it out.

:::

## ToolbarOptions

Every control is on by default.

::: fw js

| Option          | Type      | Control                            |
| --------------- | --------- | ---------------------------------- |
| `follow`        | `boolean` | Follow new logs                    |
| `clear`         | `boolean` | Clear logs                         |
| `scroll`        | `boolean` | Scroll to top and Scroll to bottom |
| `wrap`          | `boolean` | Wrap long lines                    |
| `selectionMode` | `boolean` | Select whole entries               |
| `theme`         | `boolean` | The theme menu                     |
| `mute`          | `boolean` | The dialog of hidden messages      |
| `filter`        | `boolean` | The filter field                   |
| `levels`        | `boolean` | The log level menu                 |

:::

::: fw flutter

The class is `ViewerToolbarOptions`, because `ToolbarOptions` is already a name in `package:flutter/widgets.dart`.

| Option          | Type   | Control                            |
| --------------- | ------ | ---------------------------------- |
| `visible`       | `bool` | The toolbar itself                 |
| `follow`        | `bool` | Follow new logs                    |
| `clear`         | `bool` | Clear logs                         |
| `scroll`        | `bool` | Scroll to top and Scroll to bottom |
| `wrap`          | `bool` | Wrap long lines                    |
| `selectionMode` | `bool` | Select whole entries               |
| `theme`         | `bool` | The theme menu                     |
| `mute`          | `bool` | The dialog of hidden messages      |
| `filter`        | `bool` | The filter field                   |
| `levels`        | `bool` | The log level menu                 |

`ViewerToolbarOptions.hidden` is the toolbar with `visible: false`, which is how it is left out.

:::

## InputOptions

::: fw js

| Option        | Type                                              | Default                   | Description                                                                                                                                            |
| ------------- | ------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `onSubmit`    | `(command: string, viewer: LogViewer) => unknown` | Required                  | Called with each command. A returned value, or the value a returned promise resolves to, is printed as the reply. Return `undefined` to print nothing. |
| `prompt`      | `string`                                          | `'>'`                     | The prompt shown before the input.                                                                                                                     |
| `placeholder` | `string`                                          | `labels.inputPlaceholder` | The placeholder of the input.                                                                                                                          |
| `echo`        | `boolean`                                         | `true`                    | Whether the command is added to the log before it runs.                                                                                                |
| `historySize` | `number`                                          | `100`                     | How many past commands the arrow keys go through.                                                                                                      |

:::

::: fw flutter

| Option        | Type                       | Default                   | Description                                                                                                                                |
| ------------- | -------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `onSubmit`    | `Object? Function(String)` | Required                  | Called with each command. A returned value, or the value a returned future completes with, is printed as the reply. `null` prints nothing. |
| `prompt`      | `String`                   | `'>'`                     | The prompt shown before the input.                                                                                                         |
| `placeholder` | `String?`                  | `labels.inputPlaceholder` | The hint inside the field.                                                                                                                 |
| `echo`        | `bool`                     | `true`                    | Whether the command is added to the log before it runs.                                                                                    |
| `historySize` | `int`                      | `100`                     | How many past commands the arrow keys go through.                                                                                          |

`onSubmit` receives the command alone. The viewer is not passed to it, because the controller that would be passed is already the one the application holds.

:::

## EntryMenuOptions

::: fw js

| Option  | Type                                                      | Default | Description                                                                                                                                                         |
| ------- | --------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `copy`  | `boolean`                                                 | `true`  | Whether the menu starts with the copy items: **Copy as text**, **Copy with timestamp**, **Copy as formatted text** and, for an entry with values, **Copy as data**. |
| `items` | `(entry: LogEntry, viewer: LogViewer) => EntryMenuItem[]` | None    | Called every time the menu opens. The items it returns follow the built-in ones, below a separator.                                                                 |

With `copy: false` and no `items`, the menu is off. A menu that would have no items does not open.

:::

::: fw flutter

| Option    | Type                                      | Default | Description                                                                                                                                                         |
| --------- | ----------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `visible` | `bool`                                    | `true`  | Whether the button is there at all.                                                                                                                                 |
| `copy`    | `bool`                                    | `true`  | Whether the menu starts with the copy items: **Copy as text**, **Copy with timestamp**, **Copy as formatted text** and, for an entry with values, **Copy as data**. |
| `items`   | `List<EntryMenuItem> Function(LogEntry)?` | `null`  | Called every time the menu opens. The items it returns follow the built-in ones, below a separator.                                                                 |

`EntryMenuOptions.hidden` is the menu with `visible: false`. A menu that would have no items does not open.

:::

### EntryMenuItem

| Field      | Type                                                                                                  | Description                                             |
| ---------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `label`    | <Fw js="string" flutter="String" code />                                                              | The text of the item.                                   |
| `onSelect` | <Fw js="(entry: LogEntry, viewer: LogViewer) => void" flutter="void Function(LogEntry entry)" code /> | Called with the entry the menu opened for, when chosen. |

### EntryTextOptions

| Option      | Type                                    | Default                                                | Description                                                                                                                                             |
| ----------- | --------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `format`    | `EntryTextFormat`                       | <Fw js="'text'" flutter="EntryTextFormat.text" code /> | How the entry is written.                                                                                                                               |
| `timestamp` | <Fw js="boolean" flutter="bool" code /> | `false`                                                | Whether the text starts with the time of the entry, in the format of `timestampFormat`, or `time` when timestamps are off. Ignored for the data format. |

::: fw js

| `EntryTextFormat` | Result                                                                                                                                                                                                                                                                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`          | Plain text, with every value in full on one line.                                                                                                                                                                                                                                                                                           |
| `'formatted'`     | Values too long for one line broken over several indented lines. `copyEntry` also copies HTML with the colors of the theme.                                                                                                                                                                                                                 |
| `'data'`          | The values as JSON: the value, an array of the values when there are several, or the text of the entry when it has none. `undefined` becomes `null`, sets become arrays, maps with text keys become objects, errors become objects with `name`, `message` and `stack`, and types JSON lacks, such as `10n` or `Symbol(token)`, become text. |

:::

::: fw flutter

| `EntryTextFormat`           | Result                                                                                                                                                                                                                                                    |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EntryTextFormat.text`      | Plain text, with every value in full on one line.                                                                                                                                                                                                         |
| `EntryTextFormat.formatted` | Values too long for one line broken over several indented lines.                                                                                                                                                                                          |
| `EntryTextFormat.data`      | The values as JSON: the value, a list of the values when there are several, or the text of the entry when it has none. Sets become lists, maps with text keys become objects, and types JSON lacks, such as `DateTime` or `Symbol("token")`, become text. |

The formatted output carries no HTML. The clipboard on the platforms this package runs on takes plain text, so the colors would have nowhere to go.

:::

### SearchOptions

| Option          | Type                                    | Default | Description                                                         |
| --------------- | --------------------------------------- | ------- | ------------------------------------------------------------------- |
| `caseSensitive` | <Fw js="boolean" flutter="bool" code /> | `false` | Whether letter case must match.                                     |
| `regex`         | <Fw js="boolean" flutter="bool" code /> | `false` | Whether the text is a regular expression rather than text as typed. |

### SelectionMode

::: fw js

```ts
type SelectionMode = 'text' | 'entry';
```

| Value     | How the pointer and the keyboard select                                                                                                  |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`  | A drag selects text across entries, and a double-click selects a word.                                                                   |
| `'entry'` | A click selects a whole entry. Ctrl or Cmd adds or removes an entry, Shift selects a range, and the arrow keys move from entry to entry. |

:::

::: fw flutter

```dart
enum SelectionMode { text, entry }
```

| Value                 | How the pointer and the keyboard select                                                                                                                    |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SelectionMode.text`  | A drag selects text across entries, and a double tap selects a word.                                                                                       |
| `SelectionMode.entry` | A tap selects a whole entry. The platform's multi-select modifier adds or removes one, Shift selects a range, and the arrow keys move from entry to entry. |

:::

Every key is listed in [Selection and copy](/guide/viewer#selection-and-copy).

### LinkClick

::: fw js

```ts
type LinkClick = 'confirm' | 'open' | 'ignore';
```

| Value       | What a click or a tap on a link does                                               |
| ----------- | ---------------------------------------------------------------------------------- |
| `'confirm'` | Opens a dialog that shows the address and asks before the link opens in a new tab. |
| `'open'`    | Opens the link in a new tab right away.                                            |
| `'ignore'`  | Nothing. The address is still drawn as a link.                                     |

Only `http` and `https` addresses open, and they open with `noopener` and `noreferrer`. In text mode, Ctrl+click, or Cmd+click on macOS, opens a link right away unless the value is `'ignore'`.

:::

::: fw flutter

```dart
enum LinkClick { confirm, open, ignore }
```

| Value               | What a tap on a link does                                                    |
| ------------------- | ---------------------------------------------------------------------------- |
| `LinkClick.confirm` | Opens a dialog that shows the address and asks before the link is handed on. |
| `LinkClick.open`    | Hands the address to `onOpenLink` right away.                                |
| `LinkClick.ignore`  | Nothing. The address is still drawn as a link.                               |

Only `http` and `https` addresses reach `onOpenLink`, and without an `onOpenLink` nothing opens. The platform's multi-select modifier with a tap opens a link right away unless the value is `LinkClick.ignore`.

:::

## ViewerLabels

Every label is used as visible text or as an accessible name. Both packages carry the same labels under the same names.

| Label                | English (`EN_LABELS`)                                              | Korean (`KO_LABELS`)                                    |
| -------------------- | ------------------------------------------------------------------ | ------------------------------------------------------- |
| `viewer`             | Log viewer                                                         | 로그 뷰어                                               |
| `toolbar`            | Log viewer tools                                                   | 로그 뷰어 도구                                          |
| `follow`             | Follow new logs                                                    | 새 로그 따라가기                                        |
| `clear`              | Clear logs                                                         | 로그 지우기                                             |
| `scrollToTop`        | Scroll to top                                                      | 맨 위로 이동                                            |
| `scrollToBottom`     | Scroll to bottom                                                   | 맨 아래로 이동                                          |
| `wrap`               | Wrap long lines                                                    | 긴 줄 바꾸기                                            |
| `filter`             | Filter                                                             | 필터                                                    |
| `invalidFilter`      | The filter is not a valid pattern                                  | 필터 패턴이 올바르지 않습니다                           |
| `levels`             | Log levels                                                         | 로그 수준                                               |
| `levelAll`           | All levels                                                         | 모든 수준                                               |
| `levelDebug`         | Debug                                                              | 디버그                                                  |
| `levelLog`           | Log                                                                | 로그                                                    |
| `levelInfo`          | Info                                                               | 정보                                                    |
| `levelWarn`          | Warning                                                            | 경고                                                    |
| `levelError`         | Error                                                              | 오류                                                    |
| `levelSome`          | 3 levels                                                           | 수준 3개                                                |
| `theme`              | Theme                                                              | 테마                                                    |
| `themeAuto`          | System                                                             | 시스템                                                  |
| `themeLight`         | Light                                                              | 라이트                                                  |
| `themePaper`         | Paper                                                              | 페이퍼                                                  |
| `themeDark`          | Dark                                                               | 다크                                                    |
| `themeMidnight`      | Midnight                                                           | 미드나이트                                              |
| `themeEmber`         | Ember                                                              | 엠버                                                    |
| `themeMoss`          | Moss                                                               | 모스                                                    |
| `mute`               | Hidden messages                                                    | 숨긴 메시지                                             |
| `muteMessage`        | An entry that matches one of these is kept out of the log.         | 여기에 해당하는 항목은 로그에 나오지 않습니다.          |
| `muteEmpty`          | Nothing is hidden yet.                                             | 아직 숨긴 메시지가 없습니다.                            |
| `muteText`           | Text to hide                                                       | 숨길 텍스트                                             |
| `muteAdd`            | Add                                                                | 추가                                                    |
| `muteRemove`         | Remove                                                             | 삭제                                                    |
| `muteEnabled`        | Apply this rule                                                    | 이 규칙 적용                                            |
| `muteClose`          | Done                                                               | 완료                                                    |
| `muteCount`          | 2 entries hidden                                                   | 항목 2개 숨김                                           |
| `input`              | Command                                                            | 명령                                                    |
| `inputPlaceholder`   | Type a command                                                     | 명령을 입력하세요                                       |
| `newLogs`            | New logs                                                           | 새 로그                                                 |
| `entryList`          | Visible log entries                                                | 화면에 보이는 로그                                      |
| `entryActions`       | Entry actions                                                      | 항목 작업                                               |
| `copyEntry`          | Copy as text                                                       | 텍스트로 복사                                           |
| `copyEntryWithTime`  | Copy with timestamp                                                | 타임스탬프와 함께 복사                                  |
| `copyEntryFormatted` | Copy as formatted text                                             | 서식 있는 텍스트로 복사                                 |
| `copyEntryData`      | Copy as data                                                       | 데이터로 복사                                           |
| `expandAll`          | Expand all                                                         | 모두 펼치기                                             |
| `collapseAll`        | Collapse all                                                       | 모두 접기                                               |
| `expandRepeats`      | Show repeats                                                       | 반복 펼치기                                             |
| `collapseRepeats`    | Hide repeats                                                       | 반복 접기                                               |
| `openLink`           | `Open https://…`                                                   | `링크 열기: https://…`                                  |
| `linkDialogTitle`    | Open this link?                                                    | 이 링크를 열까요?                                       |
| `linkDialogMessage`  | The link opens in a new tab. Check the address before you open it. | 링크는 새 탭에서 열립니다. 열기 전에 주소를 확인하세요. |
| `linkDialogOpen`     | Open link                                                          | 링크 열기                                               |
| `linkDialogCancel`   | Cancel                                                             | 취소                                                    |
| `selectEntries`      | Select whole entries                                               | 항목 단위로 선택                                        |
| `selectedEntries`    | `2 entries selected`                                               | `항목 2개 선택됨`                                       |
| `search`             | Find in log                                                        | 로그에서 찾기                                           |
| `searchPrevious`     | Previous match                                                     | 이전 결과                                               |
| `searchNext`         | Next match                                                         | 다음 결과                                               |
| `searchClose`        | Close search                                                       | 검색 닫기                                               |
| `searchCase`         | Match case                                                         | 대소문자 구분                                           |
| `searchRegex`        | Use regular expression                                             | 정규 표현식 사용                                        |
| `searchInvalid`      | Not a valid regular expression                                     | 올바른 정규 표현식이 아닙니다                           |
| `searchResults`      | `3/12`, `No results`                                               | `3/12`, `결과 없음`                                     |
| `following`          | Following                                                          | 따라가는 중                                             |
| `paused`             | Paused                                                             | 멈춤                                                    |
| `entries`            | `3 entries`, `1 of 3 entries`                                      | `로그 3개`, `로그 3개 중 1개`                           |

`openLink` receives the address of the link and returns the text of the menu item: <Fw js="(url: string) => string" flutter="String Function(String url)" code />.

`selectedEntries` returns the number of selected entries in entry mode, which the status bar shows and a screen reader hears after the keyboard changes the selection: <Fw js="(count: number, format: (value: number) => string) => string" flutter="String Function(int count, NumberFormatter format)" code />.

`searchResults` is <Fw js="(current: number, total: number, format: (value: number) => string) => string" flutter="String Function(int current, int total, NumberFormatter format)" code />, where `current` is 0 while no match is current.

`entries` is <Fw js="(shown: number, total: number, format: (value: number) => string) => string" flutter="String Function(int shown, int total, NumberFormatter format)" code />. `format` writes a number for the reader's language, and it is the `formatNumber` option.

<Fw flutter="ViewerLabels is a complete set rather than a partial one, so copyWith on enLabels or koLabels is how a few of them are replaced." />

### labelsFor

```
labelsFor(locale)
```

Returns the Korean labels for `ko` and tags such as `ko-KR`, and the English labels for every other language. The two sets are <Fw js="EN_LABELS and KO_LABELS" flutter="enLabels and koLabels" code />.

## Themes and fonts

::: fw js

### ThemeMode

```ts
const BUILT_IN_THEMES = ['light', 'paper', 'dark', 'midnight', 'ember', 'moss'] as const;

type BuiltInTheme = (typeof BUILT_IN_THEMES)[number];
type ThemeMode = 'auto' | BuiltInTheme | (string & {});
```

`'auto'` follows the operating system. Any other name is written to the `data-theme` attribute of the viewer, so a palette defined in your own CSS works as well. See [Themes](/guide/theming#themes).

### ThemeChoice

```ts
interface ThemeChoice {
	name: ThemeMode;
	label?: string;
}
```

One entry of `themes`, the list the theme menu offers. A theme that ships with lognal falls back to its built-in label; any other name is its own label.

### resolveTheme

```ts
resolveTheme(theme: ThemeMode, prefersDark: boolean): string
```

The palette a mode ends up using: `'light'` or `'dark'` for `'auto'`, and the name itself for anything else. The viewer calls it with the result of `matchMedia('(prefers-color-scheme: dark)')`.

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

:::

::: fw flutter

### LognalTheme {#lognaltheme}

```dart
class LognalTheme {
  const LognalTheme({
    required String name,
    required Brightness brightness,
    required RenderTheme renderer,
    required ChromeTheme chrome,
  });
}
```

A palette, in two halves. `renderer` is what the log is drawn with, which is the same [`RenderTheme`](/reference/layout#rendertheme) the JavaScript package reads out of CSS. `chrome` is everything around it: the toolbar, the status bar, the scrollbar and the popups. `brightness` decides what the platform draws on top, such as the keyboard and the text selection handles.

### ChromeTheme {#chrometheme}

| Field                                        | What it colors                                                                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------ |
| `background`                                 | Behind the viewer.                                                                   |
| `foreground`, `muted`                        | Ordinary and secondary text in the chrome.                                           |
| `accent`, `onAccent`                         | The accent, and text on it.                                                          |
| `border`, `surface`                          | The line between the chrome and the log, and the toolbar and status bar behind it.   |
| `controlHover`, `controlActive`, `focusRing` | A control under the pointer, a control that is on, and the ring the keyboard leaves. |
| `error`                                      | A field whose text is not a pattern that compiles.                                   |
| `scrollbarThumb`, `scrollbarThumbHover`      | The scrollbar's handle.                                                              |
| `shadow`                                     | Under a menu or a dialog.                                                            |

### buildTheme {#buildtheme}

```dart
LognalTheme buildTheme({
  required String name,
  required Brightness brightness,
  required Color background,
  required Color foreground,
  required Color muted,
  required Color accent,
  required Color border,
  required Color surface,
  required Color selection,
  required Color entrySelection,
  required Color controlActive,
  required List<Color> ansi,
})
```

Builds a whole palette from a handful of colors and a sixteen-color ANSI ramp, the way the four palettes after `light` and `dark` are built. Every token the log uses follows from the ramp, so a palette of your own is these arguments and nothing more. See [Themes](/guide/theming#themes).

### The palettes {#palettes}

`lightTheme`, `paperTheme`, `darkTheme`, `midnightTheme`, `emberTheme` and `mossTheme` are the palettes this package ships. `builtInThemes` is the list of them in the order the menu lists them, `builtInThemeNames` is their names, and `builtInTheme(name)` returns one or `null`.

```dart
LognalTheme resolveTheme(String name, Brightness platform)
```

The palette a name ends up meaning. `auto` follows `platform`, anything else is looked up by name, and a name nothing ships under falls back to the platform too. That last fallback is what makes `themeResolver` the way to add a palette of your own.

### FontSettings {#fontsettings}

| Field              | Type           | Default           | Description                                                                                |
| ------------------ | -------------- | ----------------- | ------------------------------------------------------------------------------------------ |
| `family`           | `String?`      | The platform's    | The font family, or `null` for the platform's own monospace font.                          |
| `fallbackFamilies` | `List<String>` | `[]`              | The families a character the chosen font lacks falls back to, such as one that has Hangul. |
| `size`             | `double`       | `13`              | Font size in logical pixels.                                                               |
| `weight`           | `FontWeight`   | `FontWeight.w400` | Font weight of regular text.                                                               |
| `lineHeight`       | `double`       | `1.6`             | Row height as a multiple of the size.                                                      |

With no `family`, the viewer picks the platform's monospace font: `SF Mono` on Apple platforms, `Roboto Mono` on Android, `Consolas` on Windows, `DejaVu Sans Mono` on Linux. Flutter for the web has no system fonts to fall back to, so a web application has to bundle a monospace font and name it here. See [Fonts](/guide/theming#fonts).

:::

## Timestamps

### TimestampFormat

::: fw js

```ts
type TimestampFormat = 'time' | 'datetime' | 'iso' | ((time: number) => string);
```

:::

::: fw flutter

```dart
enum TimestampFormat { time, datetime, iso }
```

A format of your own is the `formatTimestamp` option rather than a member of this enum, because a Dart enum holds no functions.

:::

### formatTimestamp

```
formatTimestamp(time, format)
```

Writes a time in the chosen format. It takes <Fw js="an epoch time in milliseconds" flutter="a DateTime" /> and defaults to <Fw js="'time'" flutter="TimestampFormat.time" code />.

| Format                                                         | Example                    |
| -------------------------------------------------------------- | -------------------------- |
| <Fw js="'time'" flutter="TimestampFormat.time" code />         | `14:03:09.120`             |
| <Fw js="'datetime'" flutter="TimestampFormat.datetime" code /> | `2026-09-13 14:03:09.120`  |
| <Fw js="'iso'" flutter="TimestampFormat.iso" code />           | `2026-09-13T05:03:09.120Z` |

The first two use local time. The last one uses UTC.

::: fw js

## React component

```tsx
import { LogViewer, type LogViewerProps } from 'lognal/react';
```

`LogViewerProps` extends `LogViewerOptions` with the props below. The component forwards its ref to the `LogViewer` instance. See [In a framework](/guide/framework) for how prop changes are applied.

| Prop                | Type                                  | Description                                                                  |
| ------------------- | ------------------------------------- | ---------------------------------------------------------------------------- |
| `className`         | `string`                              | The class of the container.                                                  |
| `style`             | `CSSProperties`                       | The style of the container, applied on top of `height: 100%`.                |
| `hookConsole`       | `boolean \| HookConsoleOptions`       | Records the global `console` into the viewer while the component is mounted. |
| `onReady`           | `(viewer: LogViewer \| null) => void` | Called with the viewer once it exists, and with `null` after it is disposed. |
| `onFollowChange`    | `(following: boolean) => void`        | The `follow` event.                                                          |
| `onFilterChange`    | `(filter: LogFilter \| null) => void` | The `filter` event.                                                          |
| `onSelectionChange` | `(text: string) => void`              | The `selection` event.                                                       |

:::

::: fw flutter

## The widget's arguments {#widget-arguments}

| Argument     | Type                   | Default              | Description                                                                 |
| ------------ | ---------------------- | -------------------- | --------------------------------------------------------------------------- |
| `store`      | `LogStore?`            | a new store          | The store to show. The widget makes a controller over it.                   |
| `controller` | `LogViewerController?` | —                    | A controller you hold. Cannot be passed together with `store`.              |
| `options`    | `LogViewerOptions`     | `LogViewerOptions()` | The options, applied on every build whether or not a controller was passed. |
| `focusNode`  | `FocusNode?`           | one of its own       | The focus node of the log area.                                             |
| `autofocus`  | `bool`                 | `false`              | Whether the log area takes focus when it appears.                           |

A controller the widget made is disposed with the widget. One you passed is yours to dispose. See [In a framework](/guide/framework) for where each shape fits.

:::
