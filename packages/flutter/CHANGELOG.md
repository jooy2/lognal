# Changelog

Changes to the `lognal` package on pub.dev that affect its users, newest first.

The npm package versions on its own and keeps its own changelog, in
[`packages/js/CHANGELOG.md`](../js/CHANGELOG.md).

## vNext (2026--)

### Breaking changes

- `ChromeTheme` has the new color `error`, which marks a field whose text is not a pattern that compiles. A `ChromeTheme` built by hand needs it; `buildTheme` and the six palettes it ships already have it. Before this a field marked itself in the accent color, which is what a field in focus is drawn in, so nothing told the two apart.

### Changes

- The log is cut off at the edges of the area it is drawn in, so the row that a scroll leaves half above the top no longer paints over the toolbar.
- The text of a row is centred in it, so it lines up with the level marks, the expanders and the box-drawing lines beside it instead of sitting above them. The underline of a link and the line through struck-out text move with it.
- A blank line in the stack trace of a logged error no longer becomes an empty row under it.
- The toolbar menus, the entry menu and the link and hidden-message dialogs open again. The viewer draws them over itself instead of pushing a route onto the application's navigator, so they work in an application that has none, such as a `WidgetsApp` with nothing but a `builder`.
- The pointer over the log says what a press would do, the way the stylesheet already says it on the web: a bar over text to select, a hand over a link or an expander, and an arrow while whole entries are being picked out.
- The sentence a dialog explains itself with wraps instead of ending in an ellipsis.
- A right press opens the menu of the selected entries in entry mode, and is left to the platform in the mode where the log is read, which is what the npm package has always done. The entry under the press is selected alone first when it was not already selected.
- On the web, the browser no longer draws its own menu over the entry menu. The viewer turns the browser's menu off while it is in entry mode and puts it back as soon as no viewer is.
- A menu that would have no items in it does not open.
- A rule in the **Hidden messages** dialog is edited where it stands: its text in a field of its own, and **Match case** and **Use regular expression** beside it, as in the npm package. A rule whose regular expression does not compile marks its field, once the keyboard has left it: while it is being written, the border says where the keyboard is instead.
- The toolbar puts the filter and the levels on a second line when the viewer is too narrow to hold them beside the buttons, instead of running off the right edge. The filter gives way to 96 pixels before that happens, as it does on the web.
- Two buttons of the toolbar or the search bar no longer touch, so a pair of toggles that are both on reads as two buttons rather than one. The space around the lines between groups is unchanged.
- The level menu stays open while levels are added and taken away, so a set of them is a few presses rather than a few trips to the button. A press outside it closes it.
- A filter, a mute rule or anything else that leaves fewer rows behind no longer scrolls the log off the bottom of the view. The view comes back inside the log it is showing, and a view that was following new entries stays at the end.

## 1.0.0 (2026-09-17)

The first release, and the same library the npm package has shipped since
`0.1.0`, translated file for file.

- `LogViewer` shows logs drawn on a canvas, with a toolbar (follow new logs, clear, scroll to top and bottom, line wrapping, entry selection, themes, hidden messages, text filter and level filter), a status bar, timestamps, its own scrollbars and an optional input line for commands. `LogViewerController` holds the state, so log entries never go through `setState`.
- `hookDebugPrint`, `runZonedWithLognal` and `hookFlutterErrors` record what the application already prints: the first replaces the variable Flutter prints through and puts it back, the second catches `print`, which belongs to the zone rather than to a variable, and the third puts a failed build in the log with its stack.
- `LognalConsole` writes into a store from your own code, with the levels, groups, counters, timers, assertions and tables a console has, and the format specifiers `%s`, `%d`, `%i`, `%f`, `%o`, `%O` and `%c`.
- `captureValue` takes a value as it was at the moment of the call. A class that writes `toJson()` opens into its properties, one that writes `toString()` shows what it says, and the rest show their type. Depth, item count, string length and total node count each have a limit, and whatever they cut is counted.
- Logged lists, maps, sets and errors expand and collapse, an error is open by default so its stack is visible, and `console.table` draws a table whose columns line up around wide characters.
- `readTextStream` and `readTextBytes` read a text file one entry per line, from a file on disk or the bytes a browser handed the page. `followTextFile` keeps reading a file as it grows, and reads it again from the start when it was replaced. UTF-8, UTF-16, Latin-1 and Windows-1252 decode here, and `registerTextDecoder` takes a legacy CJK decoder from your application.
- Korean, Chinese, Japanese and emoji take two cells, Korean text wraps at spaces, the filter and the search compare text in Unicode normalization form C so decomposed Hangul matches what a reader types, and the input line is a real text field, so an input method composes into it.
- Text written with `wrap: false`, and the output of a table, keeps its lines on one row; a line wider than the viewer scrolls sideways.
- A large log lays out the rows on screen first and the rest in small steps between frames. While the view is not following, the entry at its top stays in place when rows above it change height.
- `core: mergeRepeats` merges identical consecutive messages into a repeat count, or keeps them as a run that opens from the count badge.
- `LogFilter` takes `mute`, rules that keep matching entries out of the log whatever the rest of the filter says, with a dialog in the toolbar that manages them.
- The search bar highlights every match without hiding an entry, and matches letter case or reads the text as a regular expression when asked.
- `selectionMode` selects whole entries the way a file manager selects files, with the arrow keys, Shift and the platform's own multi-select modifier.
- `http` and `https` addresses in the text are drawn as links; `linkClick` decides whether a tap asks first, opens straight away, or does nothing, and `onOpenLink` is what actually opens one.
- Six palettes — `light`, `paper`, `dark`, `midnight`, `ember` and `moss` — with `auto` following the system. `buildTheme` makes one of your own out of a background, an accent and a sixteen-colour ramp.
- English and Korean labels, with `labels` to replace any of them.
