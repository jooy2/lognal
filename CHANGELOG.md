# Changelog

Changes to `lognal` that affect its users, newest first.

## vNext (2026--)

### Breaking changes

- `ViewerLabels` has three new labels, `entryActions`, `copyEntry` and `copyEntryWithTime`. A complete `ViewerLabels` object of your own needs all three. Overrides passed in `labels` are not affected.
- `RenderTheme` has a new color, `hover`, and `RowDecoration` a new flag, `hovered`. A `RenderTheme` object built by hand needs `hover`; spreading `DEFAULT_RENDER_THEME` covers it.
- The level menu in the toolbar is a `<button class="lognal-levels">` that opens a list box, instead of a `<select>`. Styles or tests written for the `<select>` need to target the button and its menu.

### Changes

- The level menu follows the theme of the viewer. The arrow keys, Home and End move through the levels, Enter or Space chooses one, and Escape closes it.
- The entry under the pointer gets a light background, set with `--lognal-hover`, and a button that opens a menu of actions for it. **Copy as text** copies every line of the entry, and **Copy with timestamp** puts the time of the entry in front. A long press opens the menu on a touch screen, and Shift+F10 or the context menu key opens it from the keyboard.
- `entryMenu` takes `false` to turn the menu off, or an object whose `items` function adds items of your own after the built-in ones. `getEntryText` and `copyEntry` copy an entry from code, with `{ timestamp: true }` for the time.
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
