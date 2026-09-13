---
order: 4
description: Every LogViewer option with its default, and how the toolbar, status bar, timestamps, following, filtering, selection, input line, labels and events work.
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

| Option       | Type                                    | Default         | Description                                                                                                   |
| ------------ | --------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------- |
| `store`      | `LogStore`                              | A new store     | The store to show. Several viewers can share one store.                                                       |
| `core`       | `Partial<CoreOptions>`                  | See below       | What is kept, how lines are laid out, and which entries are shown.                                            |
| `theme`      | `'auto' \| 'light' \| 'dark'`           | `'auto'`        | The color scheme. `'auto'` follows the operating system.                                                      |
| `font`       | `Partial<FontSettings>`                 | From CSS        | The font of the log. Values left out come from the `--lognal-font-*` properties.                              |
| `timestamps` | `boolean \| TimestampFormat`            | `true`          | Whether each entry shows its time, and in which format. `true` means `'time'`.                                |
| `follow`     | `boolean`                               | `true`          | Whether the view follows new entries at the start.                                                            |
| `toolbar`    | `boolean \| Partial<ToolbarOptions>`    | `true`          | The toolbar controls, or `false` to hide the toolbar.                                                         |
| `statusBar`  | `boolean`                               | `true`          | Whether the status bar is shown.                                                                              |
| `input`      | `InputOptions \| null`                  | `null`          | The input line. Leave it out for a read-only viewer.                                                          |
| `locale`     | `string`                                | None            | The language of the built-in labels and of number formatting, such as `'ko'`.                                 |
| `labels`     | `Partial<ViewerLabels>`                 | Built-in labels | Labels that replace the built-in ones.                                                                        |
| `entryMenu`  | `boolean \| EntryMenuOptions`           | `true`          | The menu of actions of the entry under the pointer, or `false` to turn it off. See [Entry menu](#entry-menu). |
| `renderer`   | `(ownerDocument: Document) => Renderer` | Canvas 2D       | Creates the renderer. See [Layout and renderers](/reference/layout#renderer).                                 |

### Core options

| Option           | Type                         | Default  | Description                                                                                                                 |
| ---------------- | ---------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `number`                     | `10000`  | The most entries the store keeps. The oldest entry is dropped for every new one past it. Use `Infinity` to keep everything. |
| `mergeRepeats`   | `boolean`                    | `true`   | Whether a message identical to the one before it increases that entry's repeat count.                                       |
| `wrap`           | `'word' \| 'char' \| 'none'` | `'word'` | How lines longer than the viewer are handled. See [Word wrapping](/guide/cjk#word-wrapping).                                |
| `tabSize`        | `number`                     | `8`      | Cells between tab stops.                                                                                                    |
| `ambiguousWidth` | `1 \| 2`                     | `1`      | Cells an East Asian Ambiguous character takes.                                                                              |
| `maxClusters`    | `number`                     | `10000`  | The most characters a line keeps. The rest is replaced with `…`.                                                            |
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

| Control                         | `ToolbarOptions` key | What it does                                                                                              |
| ------------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------- |
| Follow new logs                 | `follow`             | Turns following on or off.                                                                                |
| Clear logs                      | `clear`              | Removes every entry from the store.                                                                       |
| Scroll to top, Scroll to bottom | `scroll`             | Jumps to the oldest or the newest entry. Scrolling to the bottom turns following on.                      |
| Wrap long lines                 | `wrap`               | Turns wrapping off. Pressing it again restores the mode it turned off, `'word'` or `'char'`.              |
| Filter                          | `filter`             | Shows the entries that contain the text. The filter applies 120 ms after typing stops.                    |
| Log levels                      | `levels`             | Shows all levels, log and above, info and above, warnings and errors, or errors only. It sets `minLevel`. |

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

The status bar shows the number of entries on the left, such as `3 entries`, or `1 of 3 entries` while a filter or a collapsed group hides some of them. On the right it shows `Following` or `Paused`. It updates with every frame the viewer draws, and numbers are formatted for the `locale` option.

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
- The filter field in the toolbar changes only `text`, so a `regex` set with `setFilter` stays on while the user types. The level menu sets `minLevel` and removes `levels`, so it also works after `setFilter({ levels })`.
- The entry text and the filter text are compared in Unicode normalization form C, so decomposed Hangul matches what the user types. See [Korean and CJK text](/guide/cjk#filtering-decomposed-hangul).

Every change, from the toolbar or from `setFilter`, emits the `filter` event. `getFilter()` returns the current filter.

## Selection and copy

While the log area has focus, the mouse and the keyboard work like this:

| Action              | Result                                       |
| ------------------- | -------------------------------------------- |
| Drag with the mouse | Selects text. Dragging past an edge scrolls. |
| Shift and click     | Extends the selection.                       |
| Double-click        | Selects a word.                              |
| Ctrl+A or Cmd+A     | Selects every visible entry.                 |
| Ctrl+C or Cmd+C     | Copies the selection.                        |
| Escape              | Clears the selection.                        |

Touch input scrolls the log and does not select. A line that wraps over several rows is copied as one line, and the rows of open values are included.

The same actions are available as methods: `getSelectionText()`, `selectAll()`, `clearSelection()` and `copySelection()`, which resolves to whether anything was copied. The `selection` event reports the selected text whenever it changes.

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

While the log area has focus, Shift+F10 or the context menu key opens the menu for the entry where the selection ends, or for the first entry on screen. The arrow keys move through the menu, Enter chooses an item, and Escape closes the menu.

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

| Member                                                                     | Description                                                                                |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `console`                                                                  | An object with the console methods that writes to this viewer's store.                     |
| `write(text, options?)`                                                    | Adds text as one entry.                                                                    |
| `writeLines(text, options?)`                                               | Adds text as one entry per line.                                                           |
| `hookConsole(target?, options?)`                                           | Records a console into the store. Returns a function that stops recording.                 |
| `clear()`                                                                  | Removes every entry.                                                                       |
| `setFilter(filter)`, `getFilter()`                                         | Sets or returns the filter.                                                                |
| `setFollowing(following)`                                                  | Turns following on or off.                                                                 |
| `scrollToTop()`, `scrollToBottom()`, `scrollToEntry(id)`                   | Scroll the view.                                                                           |
| `getSelectionText()`, `selectAll()`, `clearSelection()`, `copySelection()` | Work with the selection.                                                                   |
| `getEntryText(id, options?)`, `copyEntry(id, options?)`                    | Return or copy the text of an entry.                                                       |
| `expandEntry(id)`, `collapseEntry(id)`                                     | Open or close every value of an entry.                                                     |
| `focus()`                                                                  | Focuses the input line, or the log when there is no input line.                            |
| `refresh()`                                                                | Reads the theme and the font from CSS again.                                               |
| `on(name, listener)`                                                       | Adds a listener for `follow`, `filter` or `selection`. Returns a function that removes it. |
| `setOptions(options)`                                                      | Changes the options given and keeps the others.                                            |
| `dispose()`                                                                | Removes the viewer and stops everything it started.                                        |

The full signatures are in the [LogViewer reference](/reference/log-viewer).

## Accessibility

- The viewer is a region named by the `viewer` label, and the toolbar is a toolbar of labeled buttons. The follow and wrap buttons report whether they are pressed.
- The log area can take keyboard focus, and the arrow keys and Page Up and Page Down scroll it the way they scroll any scrollable element.
- The level menu is a button that opens a list box. The arrow keys, Home and End move through the levels, Enter or Space chooses one, and Escape closes the list and gives focus back to the button.
- The entry menu button is named by the `entryActions` label. Shift+F10 or the context menu key opens the menu without a pointer, and a long press opens it on a touch screen.
- A visually hidden list mirrors the entries on screen for screen readers. Warnings and errors start with `warn:` and `error:`.
- The input line is a labeled `<textarea>`.
- The log area, the input line and the filter field draw no focus outline, and the caret shows focus in the two text fields. To outline the focused log area, add a rule such as `.lognal-viewport:focus-visible { box-shadow: inset 0 0 0 2px var(--lognal-focus-ring); }`.
