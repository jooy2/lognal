---
order: 4
description: Every LogViewer option with its default, and how the toolbar, status bar, timestamps, following, filtering, links, selection, input line, labels and events work.
---

# The viewer

## Create and dispose

`new LogViewer(container, options)` adds the viewer to the end of `container`. The viewer fills the container, so give the container a height.

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!, {
	theme: 'dark',
	core: { maxEntries: 50000 }
});

// Later, when the viewer is no longer needed:
viewer.dispose();
```

`dispose()` removes the viewer from the page, removes its event listeners, and stops the console hooks started with `viewer.hookConsole`. The store keeps its entries, so another viewer can show them.

## Options

| Option          | Type                                    | Default         | Description                                                                                                       |
| --------------- | --------------------------------------- | --------------- | ----------------------------------------------------------------------------------------------------------------- |
| `store`         | `LogStore`                              | A new store     | The store to show. Several viewers can share one store.                                                           |
| `core`          | `Partial<CoreOptions>`                  | See below       | What is kept, how lines are laid out, and which entries are shown.                                                |
| `theme`         | `'auto' \| 'light' \| 'dark'`           | `'auto'`        | The color scheme. `'auto'` follows the operating system.                                                          |
| `font`          | `Partial<FontSettings>`                 | From CSS        | The font of the log. Values left out come from the `--lognal-font-*` properties.                                  |
| `timestamps`    | `boolean \| TimestampFormat`            | `true`          | Whether each entry shows its time, and in which format. `true` means `'time'`.                                    |
| `follow`        | `boolean`                               | `true`          | Whether the view follows new entries at the start.                                                                |
| `toolbar`       | `boolean \| Partial<ToolbarOptions>`    | `true`          | The toolbar controls, or `false` to hide the toolbar.                                                             |
| `statusBar`     | `boolean`                               | `true`          | Whether the status bar is shown.                                                                                  |
| `input`         | `InputOptions \| null`                  | `null`          | The input line. Leave it out for a read-only viewer.                                                              |
| `locale`        | `string`                                | None            | The language of the built-in labels and of number formatting, such as `'ko'`.                                     |
| `labels`        | `Partial<ViewerLabels>`                 | Built-in labels | Labels that replace the built-in ones.                                                                            |
| `entryMenu`     | `boolean \| EntryMenuOptions`           | `true`          | The menu of actions of the entry under the pointer, or `false` to turn it off. See [Entry menu](#entry-menu).     |
| `search`        | `boolean`                               | `true`          | Whether Ctrl+F or Cmd+F opens a search bar over the log. See [Search](#search).                                   |
| `linkClick`     | `'confirm' \| 'open' \| 'ignore'`       | `'confirm'`     | What a click or a tap on a link does. See [Links](#links).                                                        |
| `selectionMode` | `'text' \| 'entry'`                     | `'text'`        | Whether the pointer and the keyboard select text or whole entries. See [Selection and copy](#selection-and-copy). |
| `tooltips`      | `boolean`                               | `true`          | Whether a toolbar control shows its name as soon as the pointer reaches it. See [Toolbar](#toolbar).              |
| `renderer`      | `(ownerDocument: Document) => Renderer` | Canvas 2D       | Creates the renderer. See [Layout and renderers](/reference/layout#renderer).                                     |

### Core options

| Option           | Type                         | Default  | Description                                                                                                                 |
| ---------------- | ---------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `number`                     | `10000`  | The most entries the store keeps. The oldest entry is dropped for every new one past it. Use `Infinity` to keep everything. |
| `mergeRepeats`   | `boolean`                    | `true`   | Whether a message identical to the one before it increases that entry's repeat count.                                       |
| `wrap`           | `'word' \| 'char' \| 'none'` | `'word'` | How lines longer than the viewer are handled. See [Word wrapping](/guide/cjk#word-wrapping).                                |
| `tabSize`        | `number`                     | `8`      | Cells between tab stops.                                                                                                    |
| `ambiguousWidth` | `1 \| 2`                     | `1`      | Cells an East Asian Ambiguous character takes.                                                                              |
| `maxClusters`    | `number`                     | `10000`  | The most characters a line keeps. The rest is replaced with `…`.                                                            |
| `links`          | `boolean`                    | `true`   | Whether `http` and `https` addresses in the text are drawn as links. See [Links](#links).                                   |
| `filter`         | `LogFilter \| null`          | `null`   | The initial filter. See [Filtering](#filtering).                                                                            |

`maxEntries` and `mergeRepeats` belong to the store. When you pass a `store` together with these options, they are applied to that store, and so to every viewer that shares it.

### Change options later

`setOptions` changes the options you pass and keeps the others. `store` and `renderer` cannot be changed after creation.

```ts
viewer.setOptions({ theme: 'light', toolbar: { levels: false } });
viewer.setOptions({ core: { wrap: 'none' } });
viewer.setOptions({ locale: 'ko' });
```

Passing `toolbar`, `statusBar`, `input`, `labels` or `locale` builds the toolbar, the input line and the status bar again. For `locale`, this happens whenever the key is present, even when its value is `undefined`. See [Labels and locale](#labels-and-locale) for how `locale` and `labels` combine.

## Toolbar

| Control                         | `ToolbarOptions` key | What it does                                                                                                |
| ------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------- |
| Follow new logs                 | `follow`             | Turns following on or off.                                                                                  |
| Clear logs                      | `clear`              | Removes every entry from the store.                                                                         |
| Scroll to top, Scroll to bottom | `scroll`             | Jumps to the oldest or the newest entry. Scrolling to the bottom turns following on.                        |
| Wrap long lines                 | `wrap`               | Turns wrapping off. Pressing it again restores the mode it turned off, `'word'` or `'char'`.                |
| Select whole entries            | `selectionMode`      | Switches between selecting text and selecting whole entries. See [Selection and copy](#selection-and-copy). |
| Filter                          | `filter`             | Shows the entries that contain the text. The filter applies 120 ms after typing stops.                      |
| Log levels                      | `levels`             | Chooses the levels the log shows. It sets `levels` on the filter.                                           |

Each control shows its name in a small label as soon as the pointer reaches it, without the wait of the tooltip of the browser. The same label appears when the keyboard moves to the control. Pass `tooltips: false` to leave the tooltip to the browser, which then shows the name from the `title` attribute.

Every control is shown by default. Pass an object to hide some of them, or `false` to hide the toolbar:

```ts
new LogViewer(container, { toolbar: { wrap: false, levels: false } });
new LogViewer(container, { toolbar: false });
```

When wrapping was turned off another way, for example with `core: { wrap: 'none' }`, the wrap button turns on `'word'`, or `'char'` if the button turned `'char'` off before.

Some text keeps its lines whole whatever `wrap` says: the output of `console.table`, and text written with `wrap: false`. When such a line is wider than the viewer, the log scrolls sideways and the horizontal scrollbar appears.

```ts
viewer.write(['+-------+------+', '| build | pass |', '+-------+------+'].join('\n'), { wrap: false });
```

## Status bar

The status bar shows the number of entries on the left, such as `3 entries`, or `1 of 3 entries` while a filter or a collapsed group hides some of them. In entry mode, the number of selected entries follows it, such as `2 entries selected`. On the right it shows `Following` or `Paused`. It updates with every frame the viewer draws, and numbers are formatted for the `locale` option.

## Timestamps

Each entry shows the time it was added, or the `time` passed with it, in a column on the left.

| `timestamps`               | Example                    |
| -------------------------- | -------------------------- |
| `true`, `'time'`           | `14:03:09.120`             |
| `'datetime'`               | `2026-09-13 14:03:09.120`  |
| `'iso'`                    | `2026-09-13T05:03:09.120Z` |
| `(time: number) => string` | Your own format            |
| `false`                    | No timestamp column        |

`'time'` and `'datetime'` use local time, and `'iso'` uses UTC. The width of the column is measured from the current time in the chosen format, so a function should return text of the same length every time. Longer text is squeezed to fit.

```ts
new LogViewer(container, {
	timestamps: (time) => new Date(time).toLocaleTimeString('en-GB')
});
```

## Following new logs

The viewer starts at the bottom and stays there as entries arrive. Scrolling up pauses following, and entries that arrive while paused show a **New logs** button. Scrolling back to the bottom, pressing the button, or pressing the follow button in the toolbar resumes following.

```ts
const checkpoint = viewer.store.write('Checkpoint', { level: 'info' });

// Later: pause following and show the checkpoint at the top of the view.
if (checkpoint) {
	viewer.scrollToEntry(checkpoint.id);
}

viewer.on('follow', (following) => {
	document.body.classList.toggle('logs-paused', !following);
});
```

`scrollToTop()` and `scrollToEntry(id)` pause following. `scrollToBottom()` and `setFollowing(true)` resume it, and `viewer.isFollowing` tells whether the view follows.

While following is paused, the view keeps the entry at its top in place. Entries dropped from the front of the store, a value expanded above the view, or a new width that wraps lines differently do not move what you are reading.

With a large log, a change of width lays out the rows on screen first, and the rest of the log in small steps between frames. Until that finishes, the scrollbar is based on estimated row heights, so its thumb can move a little while the view stays put.

## Filtering

```ts
// Entries that contain "timeout", at the warning level or above.
viewer.setFilter({ text: 'timeout', minLevel: 'warn' });

// A case-sensitive regular expression.
viewer.setFilter({ text: '^GET /api/', regex: true, caseSensitive: true });

// Only debug and info entries.
viewer.setFilter({ levels: ['debug', 'info'] });

// Show every entry.
viewer.setFilter(null);
```

| `LogFilter` field | Type         | Description                                                       |
| ----------------- | ------------ | ----------------------------------------------------------------- |
| `text`            | `string`     | Text an entry must contain. Empty text matches every entry.       |
| `regex`           | `boolean`    | Whether `text` is a regular expression.                           |
| `caseSensitive`   | `boolean`    | Whether letter case must match. Matching ignores case by default. |
| `minLevel`        | `LogLevel`   | The least severe level shown.                                     |
| `levels`          | `LogLevel[]` | The levels shown. When set, `minLevel` is ignored.                |

Levels go from least to most severe: `debug`, `log`, `info`, `warn`, `error`.

- The text is searched in the text of an entry and in the one-line preview of each value. An error is searched by its title and its stack trace. Only the first 20,000 characters of an entry are searched.
- Matches are highlighted in the visible rows.
- A regular expression that does not compile hides every entry and marks the filter field as invalid.
- The level filter never hides commands typed into the input line or notices from the viewer, such as `Console was cleared`. Group headers stay visible unless there is a text filter.
- The filter field in the toolbar changes only `text`, so a `regex` set with `setFilter` stays on while the user types. The level menu sets `levels` and removes `minLevel`, and it reads a `minLevel` you set as the levels from that level up.
- The entry text and the filter text are compared in Unicode normalization form C, so decomposed Hangul matches what the user types. See [Korean and CJK text](/guide/cjk#filtering-decomposed-hangul).

### The level menu

The menu lists every level with a mark next to the ones the log shows, and it stays open while you choose, so several levels take one visit. While every level is shown, choosing one shows that level alone. From there, choosing a level adds it or takes it away, and **All levels** goes back to showing them all. The button says which levels are shown: the name of the only level, the number of levels, or **All levels**.

Every change, from the toolbar or from `setFilter`, emits the `filter` event. `getFilter()` returns the current filter.

To keep every entry on screen and highlight the matches instead, use [Search](#search).

## Search

Press Ctrl+F, or Cmd+F on macOS, while focus is anywhere in the viewer, to open a search bar over the top right corner of the log. Unlike the filter, a search hides nothing: every entry stays in place, every match is highlighted, and the current match has a stronger highlight. The bar shows the position of the current match, such as `3/12`.

| Key                        | Result                                      |
| -------------------------- | ------------------------------------------- |
| Enter, F3, Ctrl+G or Cmd+G | Goes to the next match.                     |
| Shift with any of them     | Goes to the previous match.                 |
| Alt+C in the search field  | Turns **Match case** on or off.             |
| Alt+R in the search field  | Turns **Use regular expression** on or off. |
| Escape in the search field | Closes the bar and removes the highlights.  |

- Two toggles in the bar, `Aa` and `.*`, decide how text is compared. By default the search ignores letter case and takes the text as typed. **Match case** makes letter case count, and **Use regular expression** reads the text as a JavaScript regular expression. A pattern that does not compile marks the field and finds nothing. Text is compared in Unicode normalization form C, so decomposed Hangul matches too.
- It searches what the log shows: the visible entries, with the rows of open values. Entries hidden by the filter or by a closed group are not searched.
- When the bar opens with text selected on one line, the search starts with that text.
- The first match at the top of the view or below it becomes current, and the view scrolls to the current match when it is off screen. Moving to a match pauses following.
- A long log is searched in small steps between frames. New entries are searched as they arrive, and the count grows with them.

The same actions are available as methods: `openSearch(query?, options?)`, `closeSearch()`, `findNext()` and `findPrevious()`. `options` is `{ caseSensitive?, regex? }` and switches the toggles. `search: false` turns off the shortcut and the bar, and Ctrl+F reaches the browser again.

## Links

`http` and `https` addresses in the log are drawn as links, underlined in the `--lognal-link` color. A click or a tap on a link does what `linkClick` says, and the link opens in a new tab.

| `linkClick` | What a click on a link does                                                                                                                  |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `'confirm'` | Opens a dialog that shows the whole address. **Open link** opens it, and **Cancel**, Escape or a click outside the dialog closes the dialog. |
| `'open'`    | Opens the link right away.                                                                                                                   |
| `'ignore'`  | Nothing. The address is still drawn as a link, and a click selects text as it does anywhere else.                                            |

```ts
// Open links without asking.
new LogViewer(container, { linkClick: 'open' });

// Draw addresses as plain text.
new LogViewer(container, { core: { links: false } });
```

- An address starts with `http://` or `https://` and ends before the next space, quote or angle bracket. Punctuation at its end, such as the period of a sentence, is left out, and so is a closing bracket that has no opening bracket in the address. Addresses with other schemes, such as `javascript:` or `file:`, never become links.
- An address inside the preview of a value that opens, such as `{ url: 'https://…' }`, is not a link, because a click there opens the value. Open the value, and the address on its own row is a link.
- The dialog writes the host the way the browser reads it, so a host made of letters that look like other letters shows its `xn--` form. An invisible or bidirectional formatting character is never part of an address; the link ends before it.
- A link opens with `noopener` and `noreferrer`, so the new page cannot reach the page of the viewer and is not told where it was opened from.
- The entry menu lists up to five links of the entry, so a link also opens from the keyboard with Shift+F10. With `linkClick: 'ignore'`, the menu leaves them out.
- Ctrl+click, or Cmd+click on macOS, opens a link right away, without the dialog. It does nothing with `linkClick: 'ignore'`, and in entry mode it adds the entry to the selection instead.
- Any other click with Shift, Ctrl, Alt or Cmd held selects text and does not open the link.

`findLinks(text)` returns the addresses the viewer finds in a string, with their positions.

## Selection and copy

The viewer has two selection modes. `selectionMode: 'text'`, the default, selects text the way a terminal does. `selectionMode: 'entry'` selects whole entries the way a file manager selects files. The **Select whole entries** button in the toolbar switches between them, and switching clears the selection.

### Text mode

While the log area has focus, the mouse and the keyboard work like this:

| Action              | Result                                       |
| ------------------- | -------------------------------------------- |
| Drag with the mouse | Selects text. Dragging past an edge scrolls. |
| Shift and click     | Extends the selection.                       |
| Double-click        | Selects a word.                              |
| Ctrl+A or Cmd+A     | Selects every visible entry.                 |
| Ctrl+C or Cmd+C     | Copies the selection.                        |
| Escape              | Clears the selection.                        |

Touch input scrolls the log and does not select. A tap opens or closes a value or a group. A line that wraps over several rows is copied as one line, and the rows of open values are included.

### Entry mode

A selected entry gets a light background, set with `--lognal-entry-selection`, and the status bar counts the selected entries that are visible.

| Action                                    | Result                                                                                                          |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Click                                     | Selects the entry alone. A click below the last entry clears the selection.                                     |
| Ctrl and click, or Cmd and click on macOS | Adds the entry to the selection, or removes it.                                                                 |
| Shift and click                           | Selects the range from the entry chosen last. With Ctrl or Cmd held too, the range is added to the selection.   |
| Drag with the mouse                       | Selects the entries the pointer passes over. Dragging past an edge scrolls.                                     |
| Drag from the empty space                 | Starts from the entry nearest the press, so a drag up from below the last entry selects the entries it reaches. |
| Right click                               | Opens the menu of the selected entries. On an entry outside the selection, it selects that entry alone first.   |
| ArrowUp, ArrowDown                        | Moves to the previous or the next entry and selects it alone.                                                   |
| Home, End, Page Up, Page Down             | Moves to the first or the last entry, or a screen up or down, and selects that entry alone.                     |
| Shift with one of the keys above          | Selects the range from the entry chosen last to the entry the key moves to.                                     |
| Ctrl or Cmd with one of the keys above    | Moves without changing the selection.                                                                           |
| Space                                     | Selects or deselects the entry the keyboard is on.                                                              |
| Ctrl+A or Cmd+A                           | Selects every visible entry.                                                                                    |
| Ctrl+C or Cmd+C                           | Copies the selected entries as text.                                                                            |
| Shift+F10 or the context menu key         | Opens the menu of the selected entries.                                                                         |
| Escape                                    | Clears the selection.                                                                                           |

After the keyboard moves, the entry it is on has an outline in the `--lognal-focus-ring` color, and the view scrolls to keep that entry on screen.

The menu of a single selected entry is its [entry menu](#entry-menu). The menu of several entries has the copy items, **Expand all** and **Collapse all**, and each item acts on every selected entry, oldest first. Copied entries are separated by line breaks, and **Copy as data** copies one JSON array with an item for each entry. The menu follows the `entryMenu` option, so `entryMenu: false` turns it off as well.

A click on a value, a group header or a link still opens it, and selects its entry too.

### Selection methods

`getSelectionText(options?)` returns the selection as text, `selectAll()` and `clearSelection()` change it, and `copySelection(options?)` copies it and resolves to whether anything was copied. In entry mode, `options` takes the `format` and `timestamp` that [`getEntryText`](#entry-menu) takes, and `copySelection` adds HTML for `'formatted'`. `getSelectedEntryIds()` returns the ids of the selected entries, or in text mode the ids of the entries the selected text runs through. The `selection` event reports the text of the selection whenever it changes.

```ts
viewer.setOptions({ selectionMode: 'entry' });
viewer.selectAll();
await viewer.copySelection({ format: 'data' });
```

## Entry menu

When the pointer is over an entry, the rows of that entry get a light background, and a button with three vertical dots appears at the right end of its first row on screen. The button opens a menu of actions for the entry. On a touch screen, press and hold an entry to open the same menu.

| Menu item              | What it does                                                                                                                                                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Copy as text           | Copies the whole entry as plain text, whether its values are open or closed. Every value is written out in full on one line, as far as it was captured.                                                            |
| Copy with timestamp    | Copies the same text after the time of the entry, in the format of the `timestamps` option, or in `'time'` when timestamps are hidden.                                                                             |
| Copy as formatted text | Copies the entry with values that are too long for one line broken over several indented lines. The clipboard also gets the text as HTML with the colors of the theme, so an app that pastes rich text keeps them. |
| Copy as data           | Copies the values of the entry as JSON: the value itself, or an array when the entry holds several. Shown only for entries with values.                                                                            |
| Expand all             | Opens every value of the entry, and every value inside them, as far as they were captured. Shown only for entries with values that open.                                                                           |
| Collapse all           | Closes every value of the entry, including an error logged on its own.                                                                                                                                             |
| Open https://…         | Opens a link of the entry the way `linkClick` says. The menu lists up to five links, and none with `linkClick: 'ignore'`.                                                                                          |

While the log area has focus, Shift+F10 or the context menu key opens the menu for the entry where the selection ends, or for the first entry on screen. The arrow keys move through the menu, Enter chooses an item, and Escape closes the menu. In entry mode, a right click, Shift+F10 and the context menu key open the menu of the selected entries instead. See [Entry mode](#entry-mode).

### Add your own items

Pass an object as `entryMenu` to add items after the built-in ones. `items` is called every time the menu opens, with the entry the menu opens for, and `onSelect` receives the same entry.

```ts
const socket = new WebSocket('wss://example.com/reports');

new LogViewer(container, {
	entryMenu: {
		items: (entry) => [
			{
				label: 'Show only this level',
				onSelect: (_, viewer) => viewer.setFilter({ levels: [entry.level] })
			},
			{
				label: 'Report this entry',
				onSelect: (item, viewer) => socket.send(viewer.getEntryText(item.id, { timestamp: true }))
			}
		]
	}
});
```

| `EntryMenuOptions` field | Type                                                      | Default | Description                                           |
| ------------------------ | --------------------------------------------------------- | ------- | ----------------------------------------------------- |
| `copy`                   | `boolean`                                                 | `true`  | Whether the menu starts with the built-in copy items. |
| `items`                  | `(entry: LogEntry, viewer: LogViewer) => EntryMenuItem[]` | None    | Returns the items that follow the built-in ones.      |

An `EntryMenuItem` has a `label` and an `onSelect(entry, viewer)` function. Your items come after the built-in ones, below a separator. `copy: false` without `items` turns the menu off, and a menu that would have no items does not open.

`entryMenu: false` turns off the button, the long press and the keyboard shortcut. The hover background stays; set `--lognal-hover` to `transparent` to remove it.

The copies are also available as methods. `getEntryText(id, options?)` returns an entry in the format `options.format` names, `'text'`, `'formatted'` or `'data'`, with the time in front when `options.timestamp` is `true`. `copyEntry(id, options?)` copies the same text, adds the HTML for `'formatted'`, and resolves to whether anything was copied.

```ts
const entry = viewer.store.write('Deploy finished', { level: 'info' });

if (entry) {
	await viewer.copyEntry(entry.id, { format: 'formatted', timestamp: true });
}
```

## Input line

The input line appears when you pass `input`. Each command goes to `onSubmit`, and what the function returns is printed as the reply.

<ClientOnly>
  <LiveViewer preset="input" :height="300" />
</ClientOnly>

```ts
const socket = new WebSocket('wss://example.com/console');
const viewer = new LogViewer(container, {
	input: {
		prompt: '$',
		onSubmit: (command) => {
			if (command === 'time') {
				return new Date();
			}

			// Send the command to a server. The reply arrives later through viewer.write.
			socket.send(command);
		}
	}
});

socket.addEventListener('message', (event) => viewer.write(String(event.data)));
```

| `InputOptions` field | Type                                              | Default          | Description                                             |
| -------------------- | ------------------------------------------------- | ---------------- | ------------------------------------------------------- |
| `onSubmit`           | `(command: string, viewer: LogViewer) => unknown` | Required         | Called with each command.                               |
| `prompt`             | `string`                                          | `'>'`            | The prompt shown before the input.                      |
| `placeholder`        | `string`                                          | `Type a command` | The placeholder text, from the labels by default.       |
| `echo`               | `boolean`                                         | `true`           | Whether the command is added to the log before it runs. |
| `historySize`        | `number`                                          | `100`            | How many past commands the arrow keys go through.       |

What `onSubmit` returns decides the reply:

- A string is printed as text.
- Any other value is printed as a [typed value](/guide/values).
- `undefined` prints nothing. Use it when the reply arrives later.
- A promise is awaited, and the value it resolves to is printed the same way.
- An error thrown by the function, or a rejected promise, is printed as an error-level entry.

Enter submits the command, and Shift+Enter adds a line. The field grows up to six lines. A command made only of spaces is ignored. ArrowUp and ArrowDown go through past commands when the caret is on the first or the last line. Submitting a command turns following on. While an IME composition is open, Enter finishes a Korean syllable and submits, and only confirms a Japanese or Chinese candidate. See [Input line and IME](/guide/cjk#input-line-and-ime).

## Labels and locale

With `locale: 'ko'`, or a language tag such as `'ko-KR'`, the toolbar, the status bar and the accessible names are in Korean. Every other language uses the English labels. The `locale` also decides how the status bar formats numbers.

`setOptions({ locale })` switches the built-in labels of a viewer that already exists. The labels you passed in `labels` stay on top of the new built-in labels. Passing `labels` to `setOptions` replaces the earlier overrides, and `labels: {}` removes them.

Replace any label with `labels`. `entries` is a function that receives the number of shown entries, the total, and a function that formats a number for the locale.

```ts
new LogViewer(container, {
	locale: 'de',
	labels: {
		clear: 'Protokoll leeren',
		filter: 'Filtern',
		entries: (shown, total, format) => (shown === total ? `${format(total)} Einträge` : `${format(shown)} von ${format(total)} Einträgen`)
	}
});
```

Every label is listed in [`ViewerLabels`](/reference/log-viewer#viewerlabels).

## Methods and events

| Member                                                                                                              | Description                                                                                |
| ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `console`                                                                                                           | An object with the console methods that writes to this viewer's store.                     |
| `write(text, options?)`                                                                                             | Adds text as one entry.                                                                    |
| `writeLines(text, options?)`                                                                                        | Adds text as one entry per line.                                                           |
| `hookConsole(target?, options?)`                                                                                    | Records a console into the store. Returns a function that stops recording.                 |
| `clear()`                                                                                                           | Removes every entry.                                                                       |
| `setFilter(filter)`, `getFilter()`                                                                                  | Sets or returns the filter.                                                                |
| `setFollowing(following)`                                                                                           | Turns following on or off.                                                                 |
| `scrollToTop()`, `scrollToBottom()`, `scrollToEntry(id)`                                                            | Scroll the view.                                                                           |
| `getSelectionText(options?)`, `getSelectedEntryIds()`, `selectAll()`, `clearSelection()`, `copySelection(options?)` | Work with the selection.                                                                   |
| `getEntryText(id, options?)`, `copyEntry(id, options?)`                                                             | Return or copy the text of an entry.                                                       |
| `expandEntry(id)`, `collapseEntry(id)`                                                                              | Open or close every value of an entry.                                                     |
| `openSearch(query?, options?)`, `closeSearch()`, `findNext()`, `findPrevious()`                                     | Open or close the search bar and move between matches.                                     |
| `focus()`                                                                                                           | Focuses the input line, or the log when there is no input line.                            |
| `refresh()`                                                                                                         | Reads the theme and the font from CSS again.                                               |
| `on(name, listener)`                                                                                                | Adds a listener for `follow`, `filter` or `selection`. Returns a function that removes it. |
| `setOptions(options)`                                                                                               | Changes the options given and keeps the others.                                            |
| `dispose()`                                                                                                         | Removes the viewer and stops everything it started.                                        |

The full signatures are in the [LogViewer reference](/reference/log-viewer).

## Accessibility

- The viewer is a region named by the `viewer` label, and the toolbar is a toolbar of labeled buttons. The follow, wrap and selection mode buttons report whether they are pressed.
- The log area can take keyboard focus, and the arrow keys and Page Up and Page Down scroll it the way they scroll any scrollable element. In entry mode, the same keys move from entry to entry, and a live region tells a screen reader which entry the keyboard is on and how many entries are selected.
- The level menu is a button that opens a list box. The arrow keys, Home and End move through the levels, Enter or Space chooses one, and Escape closes the list and gives focus back to the button.
- The entry menu button is named by the `entryActions` label. Shift+F10 or the context menu key opens the menu without a pointer, and a long press opens it on a touch screen.
- A link takes no keyboard focus of its own. Shift+F10 opens the entry menu, which lists the links of the entry. The link dialog is a modal dialog named by its title. Focus starts on **Open link** and returns to the log when the dialog closes.
- A visually hidden list mirrors the entries on screen for screen readers. Warnings and errors start with `warn:` and `error:`.
- The input line is a labeled `<textarea>`.
- The search bar is a search landmark named by the `search` label. Its buttons are labeled, and the position of the current match is announced when it changes.
- The log area, the input line and the filter field draw no focus outline, and the caret shows focus in the two text fields. To outline the focused log area, add a rule such as `.lognal-viewport:focus-visible { box-shadow: inset 0 0 0 2px var(--lognal-focus-ring); }`.
