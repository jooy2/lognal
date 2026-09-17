---
order: 3
description: How the parts of lognal fit together, and where to read about each of them.
---

# Guide

A lognal viewer is built from a few parts that you can also use on their own. The names are the same in both packages, because the parts are the same parts.

- **`LogStore`** holds entries in the order they were added. It knows nothing about display, so one store can feed several viewers or collect messages before any viewer exists.
- **Sources** write into a store. <Fw js="hookConsole and createConsole record console calls, readTextFile and followTextFile read files" flutter="hookDebugPrint, runZonedWithLognal and hookFlutterErrors record what the application prints, readTextStream and followTextFile read files" />, and `store.write` adds text directly.
- **`LogLayout`** decides which entries are visible and breaks them into rows for the width of the viewer.
- **A renderer** draws the visible rows. The built-in one is <Fw js="CanvasRenderer, which uses the Canvas 2D context" flutter="CanvasLogRenderer, which paints onto the canvas a CustomPainter is handed" code />.
- **`LogViewer`** puts it together: the toolbar, scrolling, selection, the input line, the status bar and what a screen reader reads.

::: fw js

```ts
import { LogStore, LogViewer, hookConsole } from 'lognal';

// Record the console from the start of the page.
const store = new LogStore({ maxEntries: 50000 });

hookConsole(console, store);

// Show the store once the page has a place for it.
const viewer = new LogViewer(document.getElementById('logs')!, { store });
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

// Record what the application prints from the start.
final LogStore store = LogStore(options: const LogStoreOptions(maxEntries: 50000));

void main() {
  hookDebugPrint(store);
  runZonedWithLognal(store, () => runApp(const MyApp()));
}

// Show the store wherever the log belongs on screen.
SizedBox(height: 400, child: LogViewer(store: store));
```

:::

## Pages in this guide

- [Capturing output](/guide/console): hooking what the application prints, the methods, format specifiers and capture limits.
- [Typed values](/guide/values): previews, expanding and collapsing, errors, tables, groups and repeated messages.
- [Text files](/guide/text-files): reading a file, encodings, following a growing file and ANSI colors.
- [The viewer](/guide/viewer): options, the toolbar, the status bar, timestamps, filtering, selection, the input line, labels and events.
- [Themes and fonts](/guide/theming): theme modes, palettes and monospace fonts.
- [In a framework](/guide/framework): the React component or the Flutter widget, the state it holds, and sharing a store.
- [Korean and CJK text](/guide/cjk): character widths, line wrapping, input methods, filtering and file encodings.
