# Changelog

Changes to `lognal` that affect its users, newest first.

## vNext (2026--)

### Breaking changes

- `ViewerLabels` has twelve new labels: `entryActions`, `copyEntry`, `copyEntryWithTime`, `copyEntryFormatted`, `copyEntryData`, `expandAll`, `collapseAll`, `search`, `searchPrevious`, `searchNext`, `searchClose` and `searchResults`. A complete `ViewerLabels` object of your own needs all of them. Overrides passed in `labels` are not affected.
- `RenderTheme` has the new colors `hover`, `searchMatch` and `searchCurrent`, and `RowDecoration` the new fields `hovered`, `searchMatches` and `searchCurrent`. A `RenderTheme` object built by hand needs the three colors; spreading `DEFAULT_RENDER_THEME` covers them.
- The level menu in the toolbar is a `<button class="lognal-levels">` that opens a list box, instead of a `<select>`. Styles or tests written for the `<select>` need to target the button and its menu.

### Changes

- The level menu follows the theme of the viewer. The arrow keys, Home and End move through the levels, Enter or Space chooses one, and Escape closes it.
- The entry under the pointer gets a light background, set with `--lognal-hover`, and a button that opens a menu of actions for it. **Copy as text** copies the whole entry as plain text, with every captured value written out in full on one line, even when the value is closed, and **Copy with timestamp** puts the time of the entry in front. **Copy as formatted text** breaks long values over indented lines and adds HTML with the colors of the theme for rich text, and **Copy as data** copies the values as JSON. A long press opens the menu on a touch screen, and Shift+F10 or the context menu key opens it from the keyboard.
- `entryMenu` takes `false` to turn the menu off, or an object whose `items` function adds items of your own after the built-in ones. `getEntryText` and `copyEntry` do the same from code, with `format: 'text' | 'formatted' | 'data'` and `timestamp: true`.
- **Expand all** and **Collapse all** in the entry menu open or close every value of an entry at once, and so do `expandEntry` and `collapseEntry`.
- Ctrl+F or Cmd+F, while focus is in the viewer, opens a search bar over the log. Unlike the filter, it hides nothing: every match is highlighted, the current one more strongly, and Enter, F3 or Ctrl+G move between matches. `openSearch`, `closeSearch`, `findNext` and `findPrevious` do the same from code, `search: false` turns it off, and `--lognal-search-match` and `--lognal-search-current` color it.
- The log area, the input line and the filter field no longer draw a focus outline.
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
