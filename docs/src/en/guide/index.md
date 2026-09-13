---
order: 3
description: How the parts of lognal fit together, and where to read about each of them.
---

# Guide

A lognal viewer is built from a few parts that you can also use on their own.

- **`LogStore`** holds entries in the order they were added. It knows nothing about display, so one store can feed several viewers or collect messages before any viewer exists.
- **Sources** write into a store. `hookConsole` and `createConsole` record console calls, `readTextFile` and `followTextFile` read files, and `store.write` adds text directly.
- **`LogLayout`** decides which entries are visible and breaks them into rows for the width of the viewer.
- **A renderer** draws the visible rows. The built-in `CanvasRenderer` uses the Canvas 2D context.
- **`LogViewer`** puts it together: the toolbar, scrolling, selection, the input line, the status bar and the screen reader mirror.

```ts
import { LogStore, LogViewer, hookConsole } from 'lognal';

// Record the console from the start of the page.
const store = new LogStore({ maxEntries: 50000 });

hookConsole(console, store);

// Show the store once the page has a place for it.
const viewer = new LogViewer(document.getElementById('logs')!, { store });
```

## Pages in this guide

- [Console capture](/guide/console): hooking the console, supported methods, format specifiers and capture limits.
- [Typed values](/guide/values): previews, expanding and collapsing, errors, tables, groups and repeated messages.
- [Text files](/guide/text-files): reading a file, encodings, following a growing file and ANSI colors.
- [The viewer](/guide/viewer): options, the toolbar, the status bar, timestamps, filtering, selection, the input line, labels and events.
- [Themes and fonts](/guide/theming): theme modes, CSS custom properties and monospace fonts.
- [React](/guide/react): the component, its props and ref, sharing a store and server rendering.
- [Korean and CJK text](/guide/cjk): character widths, line wrapping, IME input, filtering and file encodings.
