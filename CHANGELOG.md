# Changelog

Changes to `lognal` that affect its users, newest first.

## vNext (2026--)

The first release.

- `LogViewer` shows logs drawn on a canvas, with a toolbar (follow new logs, clear, scroll to top and bottom, line wrapping, text filter, level filter), a status bar, timestamps and an optional input line for commands.
- `hookConsole` and `createConsole` record console calls. Arguments are captured when the method is called, and format specifiers, counters, timers, groups and `console.table` follow the Console Standard.
- Logged objects, arrays, maps, sets, errors and DOM elements expand and collapse. Getters are never run while a value is captured.
- `readTextFile` reads a text file in chunks and detects UTF-8, UTF-16 and the legacy encoding of the browser language, such as EUC-KR. `followTextFile` keeps reading a growing file in Chromium-based browsers.
- Korean, Chinese, Japanese and emoji take two cells, Korean text wraps at spaces, and Enter in the input line waits for IME composition to finish.
- Light, dark and automatic themes come from `--lognal-*` CSS custom properties in `lognal/style.css`.
- `lognal/react` provides a `LogViewer` React component.
