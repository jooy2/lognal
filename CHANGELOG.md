# Changelog

Changes to `lognal` that affect its users, newest first.

## vNext (2026--)

### Breaking changes

- `ViewerLabels` has two new labels, `entryActions` and `copyEntry`. A complete `ViewerLabels` object of your own needs both. Overrides passed in `labels` are not affected.
- The level menu in the toolbar is a `<button class="lognal-levels">` that opens a list box, instead of a `<select>`. Styles or tests written for the `<select>` need to target the button and its menu.

### Changes

- The level menu follows the theme of the viewer. The arrow keys, Home and End move through the levels, Enter or Space chooses one, and Escape closes it.
- The entry under the pointer shows a button that opens a menu of actions for it. **Copy as text** copies every line of the entry. Shift+F10 or the context menu key opens the menu from the keyboard, and `entryMenu: false` turns it off. `getEntryText` and `copyEntry` do the same from code.
- The log area and the input line no longer draw a focus outline.
- `--lognal-popup-shadow` sets the shadow of the level menu and the entry menu.
- Enter at the end of Korean text in the input line submits the command with one press. Before, the first press added a line and the second one submitted. Enter that confirms a Japanese or Chinese candidate still does not submit.

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
