# Changelog

Changes to the `lognal` package on npm that affect its users, newest first.

The pub.dev package versions on its own and keeps its own changelog, in [`packages/flutter/CHANGELOG.md`](../flutter/CHANGELOG.md).

## 1.0.0 (2026-09-17)

### Breaking changes

- `ViewerLabels` has twenty-two new labels: `entryActions`, `copyEntry`, `copyEntryWithTime`, `copyEntryFormatted`, `copyEntryData`, `expandAll`, `collapseAll`, `search`, `searchPrevious`, `searchNext`, `searchClose`, `searchCase`, `searchRegex`, `searchInvalid`, `searchResults`, `openLink`, `linkDialogTitle`, `linkDialogMessage`, `linkDialogOpen`, `linkDialogCancel`, `selectEntries` and `selectedEntries`. A complete `ViewerLabels` object of your own needs all of them. Overrides passed in `labels` are not affected.
- `RenderTheme` has the new colors `hover`, `searchMatch`, `searchCurrent`, `link`, `entrySelection` and `focusRing`, and `RowDecoration` the new fields `hovered`, `searchMatches`, `searchCurrent`, `entrySelected` and `entryFocused`. A `RenderTheme` object built by hand needs the six colors; spreading `DEFAULT_RENDER_THEME` covers them.
- `ToolbarOptions` has the new key `selectionMode`, and the toolbar shows its button by default. A complete `ToolbarOptions` object of your own needs the key.
- `LineAction` has a new type, `{ type: 'open-link'; url: string }`, on the spans of links. Code that handles every type of action, such as a custom renderer, needs to handle it too.
- `theme: 'auto'` is resolved to `light` or `dark` before it is written to the `data-theme` attribute, so `.lognal[data-theme='auto']` no longer matches anything. CSS that overrode a color inside a `prefers-color-scheme: dark` media query for `data-theme='auto'` can drop that block and keep the one for `data-theme='dark'`.
- `ToolbarOptions` has the new key `theme`, and the toolbar shows its button by default. A complete `ToolbarOptions` object of your own needs the key.
- `ViewerLabels` has the new labels `expandRepeats`, `collapseRepeats`, `mute`, `muteMessage`, `muteEmpty`, `muteText`, `muteAdd`, `muteRemove`, `muteEnabled`, `muteClose` and `muteCount`.
- `ToolbarOptions` has the new key `mute`, and the toolbar shows its button by default. A complete `ToolbarOptions` object of your own needs the key.
- `CompiledFilter` has the new field `muted`, which tests an entry against the mute rules. A `CompiledFilter` object built by hand needs it.
- `LineAction` has a new type, `{ type: 'toggle-repeat' }`. Code that handles every type of action, such as a custom renderer, needs to handle it too.
- `ViewerLabels` has the new labels `theme`, `themeAuto`, `themeLight`, `themePaper`, `themeDark`, `themeMidnight`, `themeEmber` and `themeMoss`.
- The level menu in the toolbar is a `<button class="lognal-levels">` that opens a list box, instead of a `<select>`. Styles or tests written for the `<select>` need to target the button and its menu.
- The level menu chooses any set of levels and writes them to `levels` on the filter, where it wrote `minLevel` before. `levelLog`, `levelInfo`, `levelWarn` and `levelError` are now the names of the levels, such as **Warning** instead of **Warnings and errors**, and `ViewerLabels` has the new labels `levelDebug` and `levelSome`. Code that read `minLevel` after a user chose a level reads `levels` instead. `setFilter({ minLevel })` still works.

### Changes

- The level menu follows the theme of the viewer. The arrow keys, Home and End move through the levels, Enter or Space chooses one, and Escape closes it.
- The entry under the pointer gets a light background, set with `--lognal-hover`, and a button that opens a menu of actions for it. **Copy as text** copies the whole entry as plain text, with every captured value written out in full on one line, even when the value is closed, and **Copy with timestamp** puts the time of the entry in front. **Copy as formatted text** breaks long values over indented lines and adds HTML with the colors of the theme for rich text, and **Copy as data** copies the values as JSON. A long press opens the menu on a touch screen, and Shift+F10 or the context menu key opens it from the keyboard.
- `entryMenu` takes `false` to turn the menu off, or an object whose `items` function adds items of your own after the built-in ones. `getEntryText` and `copyEntry` do the same from code, with `format: 'text' | 'formatted' | 'data'` and `timestamp: true`.
- **Expand all** and **Collapse all** in the entry menu open or close every value of an entry at once, and so do `expandEntry` and `collapseEntry`.
- Ctrl+F or Cmd+F, while focus is in the viewer, opens a search bar over the log. Unlike the filter, it hides nothing: every match is highlighted, the current one more strongly, and Enter, F3 or Ctrl+G move between matches. Toggles, also on Alt+C and Alt+R, make the search match letter case or read the text as a regular expression. `openSearch`, with `caseSensitive` and `regex`, `closeSearch`, `findNext` and `findPrevious` do the same from code, `search: false` turns it off, and `--lognal-search-match` and `--lognal-search-current` color it.
- The log area, the input line and the filter field no longer draw a focus outline.
- `--lognal-popup-shadow` sets the shadow of the level menu and the entry menu.
- Enter at the end of Korean text in the input line submits the command with one press. Before, the first press added a line and the second one submitted. Enter that confirms a Japanese or Chinese candidate still does not submit.
- A tap on a value or a group header on a touch screen opens or closes it, as a click does. Before, a tap did nothing.
- `http` and `https` addresses in the log are drawn as links in `--lognal-link` and open in a new tab. `linkClick` decides what a click or a tap does: `'confirm'`, the default, shows the address in a dialog and asks first, `'open'` opens the link right away, and `'ignore'` only draws it. `core: { links: false }` draws addresses as plain text. The entry menu lists the links of an entry, so they also open from the keyboard, and `findLinks` finds the addresses in a string.
- A click with Shift, Ctrl, Alt or Cmd held on a value, a group header or a link selects text instead of opening it. The exception is Ctrl+click, or Cmd+click on macOS, on a link in text mode: it opens the link right away, without the dialog, unless `linkClick` is `'ignore'`.
- `selectionMode: 'entry'` selects whole entries the way a file manager selects files. A click selects an entry, Ctrl or Cmd adds or removes one, Shift selects a range, and a drag selects the entries it passes over. The arrow keys, Home, End, Page Up and Page Down move from entry to entry and outline the entry in `--lognal-focus-ring`, Space selects the entry the keyboard is on, and Ctrl+A, Ctrl+C and Escape select every entry, copy the selection and clear it. A right click, Shift+F10 or the context menu key opens a menu that copies the selected entries in the formats of the entry menu, or opens and closes their values. The **Select whole entries** button in the toolbar switches modes, `--lognal-entry-selection` colors the selected entries, and the status bar counts them.
- `getSelectionText` and `copySelection` take the options of `getEntryText` in entry mode, and `getSelectedEntryIds` returns the ids of the selected entries.
- In entry mode, a drag that starts on the empty space around the entries selects the entries it reaches, starting from the entry nearest the press. Before, such a drag selected nothing.
- `LogFilter` takes `mute`, a list of `MuteRule` objects that keep matching entries out of the log whatever the rest of the filter says. A rule is plain text or a regular expression, matches letter case only when it is asked to, and `enabled: false` keeps it without applying it. The **Hidden messages** button in the toolbar opens a dialog that manages the rules and carries the number of entries they hide; `getMuteRules`, `setMuteRules`, `getMutedCount` and `openMuteDialog` do the same from code, `layout.mutedCount` counts them, and `toolbar: { mute: false }` hides the button. The rules sit in a box of a fixed height that scrolls, so adding or removing one leaves the dialog where it is, and every control of the dialog that has no visible name shows one while the pointer rests on it.
- `core: { mergeRepeats: 'collapse' }` keeps every message of a run of identical messages instead of dropping them. The run shows as its first entry with the count, and the count badge opens it to show each message; **Show repeats** and **Hide repeats** in the entry menu do the same. `a a b a a` reads as `a` twice, `b`, then `a` twice. `mergeRepeats` still takes `true`, the default, and `false`.
- `LogEntry` has the new field `runHead`, the id of the entry a repeated message belongs to, `store.isRunHead` tells whether an entry starts a run, and a `'update'` store change carries `visibility: true` when it hides or shows other entries.
- Four palettes join `light` and `dark`: `paper`, a warm light one, and the dark `midnight`, `ember` and `moss`. `BUILT_IN_THEMES` lists them, and `theme` also takes a name of your own, which the viewer writes to `data-theme` so one block of CSS is a whole theme.
- The **Theme** button in the toolbar opens a menu of the themes. `themes` chooses which ones it offers, as names or as `{ name, label }` objects, and `toolbar: { theme: false }` hides the button.
- Every palette is written once in `lognal.css`, rather than a second time inside a media query for `auto`. `--lognal-on-accent` sets the text color on the accent background of the **New logs** button and the primary dialog button.
- The level menu lists every level, `debug` included, with a mark next to the ones the log shows, and it stays open while levels are chosen. While every level is shown, choosing one shows that level alone; after that, choosing a level adds it or takes it away, and **All levels** shows them all again. The button names the only level shown, the number of levels, or **All levels**.
- A toolbar control shows its name in a small label as soon as the pointer reaches it, instead of waiting for the tooltip of the browser. The label also appears when the keyboard moves to the control, and `tooltips: false` leaves the tooltip to the browser.

## 0.1.0 (2026-09-13)

The first release.

- `LogViewer` shows logs drawn on a canvas, with a toolbar (follow new logs, clear, scroll to top and bottom, line wrapping, text filter, level filter), a status bar, timestamps and an optional input line for commands.
- `hookConsole` and `createConsole` record console calls. Arguments are captured when the method is called, and format specifiers, counters, timers, groups and `console.table` follow the Console Standard.
- Logged objects, arrays, maps, sets, errors and DOM elements expand and collapse. Getters are never run while a value is captured.
- Text written with `wrap: false`, and the output of `console.table`, keeps its lines on one row. When such a line is wider than the viewer, the log scrolls sideways.
- A large log lays out the rows on screen first and the rest in small steps between frames, so changing the width does not stall the page. While the view is not following, the entry at its top stays in place when rows above it change height.
- `readTextFile` reads a text file in chunks and detects UTF-8, UTF-16 and the legacy encoding of the browser language, such as EUC-KR. `followTextFile` keeps reading a growing file in Chromium-based browsers.
- Korean, Chinese, Japanese and emoji take two cells, Korean text wraps at spaces, and Enter in the input line waits for IME composition to finish.
- Light, dark and automatic themes come from `--lognal-*` CSS custom properties in `lognal/style.css`.
- `lognal/react` provides a `LogViewer` React component.
