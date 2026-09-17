---
order: 1
description: What lognal is, why it draws logs on a canvas, what it can do, and which platforms it supports.
---

# Introduction

lognal is a log viewer that looks and works like a terminal. It draws log output on a canvas, so it keeps up with a fast stream of messages and a long history without slowing the application down.

It ships as two packages built from the same library: `lognal` on npm for the web, and `lognal` on pub.dev for Flutter. The core is one translation of the other, file for file, so the store, the filters, the wrapping, the value capture and the layout behave the same on both sides. What differs is what only one platform has, and every page says so where it comes up.

## What it does

- **Mirror what the application prints.** Record <Fw js="console.log, console.warn, console.table, console.group and the other console methods" flutter="debugPrint, print and the errors the framework reports" />, and show them the way browser developer tools do. The original output keeps working. See [Capturing output](/guide/console).
- **Show typed values.** <Fw js="Objects, arrays, Map, Set, errors and DOM elements" flutter="Lists, maps, sets, errors and your own classes" /> are captured when they are logged and open and close with a tap. See [Typed values](/guide/values).
- **Read text files.** Read a log file in chunks, detect its encoding, and turn ANSI escape codes into colors. lognal can also follow a file that keeps growing. See [Text files](/guide/text-files).
- **Work like a log viewer.** A toolbar follows new logs, clears the log, scrolls to the top or bottom, turns wrapping on and off, and filters by text and level. The find shortcut searches the log and highlights every match without hiding anything. A status bar counts entries, each entry can show a timestamp, and text can be selected and copied, or copied a whole entry at a time from the menu of that entry. Addresses in the log are links, opened after a confirmation by default. In entry mode, whole entries are selected the way files are, and copied together. See [The viewer](/guide/viewer).
- **Accept commands.** An optional input line passes each command to a function you provide and prints the reply. See [Input line](/guide/viewer#input-line).
- **Follow your theme.** Six palettes are built in, `auto` follows the platform, and a theme of your own is <Fw js="one block of CSS custom properties" flutter="one call to buildTheme" />. See [Themes and fonts](/guide/theming).
- **Handle Korean and other CJK text.** Wide characters take two cells, Hangul words stay together when a line wraps, the input line works with an input method, and legacy encodings such as EUC-KR are handled. See [Korean and CJK text](/guide/cjk).

## Why a canvas

A log viewer that creates one <Fw js="DOM element" flutter="widget" /> per line gets slower as the history grows. Every one of them costs memory, layout and paint work, and a list of a hundred thousand lines is expensive even when only forty are on screen.

lognal keeps entries as plain data and draws only the rows that are visible. The work is split into three parts:

1. A `LogStore` holds the entries in the order they were added, up to a limit of 10,000 by default. The oldest entries are dropped once the limit is reached.
1. A `LogLayout` turns entries into rows for the current width. It caches measured lines, so most frames reuse the work of earlier ones.
1. A renderer draws the visible rows on a canvas. Any number of new messages between two frames costs one draw.

The cost of a frame depends on the number of rows on screen, not on the size of the history.

::: fw js

The browser still does the jobs it does better than a canvas. The log area is a native scroll container, so the mouse wheel, touch and keyboard scrolling work as usual. The input line is a real `<textarea>`, so the browser handles the caret, paste and IME composition. The toolbar is made of real buttons, and a visually hidden list mirrors the visible entries for screen readers.

Text on a canvas is not part of the page text. The viewer provides its own selection, copy and filter instead: drag to select, press Ctrl+C or Cmd+C to copy, and use the filter in the toolbar to search. The text is laid out on a grid of cells, so the log area needs a monospace font.

:::

::: fw flutter

The framework still does the jobs it does better than a canvas. The toolbar, the dialogs and the menus are ordinary widgets, the input line is a real text field, so the platform handles the caret, paste and input method, and a semantics node mirrors the visible entries for a screen reader.

Text on a canvas is not part of the widget tree. The viewer provides its own selection, copy and filter instead: drag to select, use the platform's copy shortcut, and use the filter in the toolbar to search. The text is laid out on a grid of cells, so the log needs a monospace font.

:::

## Package contents

::: fw js

lognal is one npm package with three entry points. The core has no runtime dependencies. React is an optional peer dependency, needed only for `lognal/react`.

| Entry point        | Contents                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `lognal`           | The viewer, the store and layout, console capture, text sources and the Canvas 2D renderer |
| `lognal/react`     | The `LogViewer` React component, for React 18 or later                                     |
| `lognal/style.css` | The layout of the viewer and its palettes                                                  |

:::

::: fw flutter

lognal is one pub.dev package with one import, `package:lognal/lognal.dart`, holding the viewer widget and its controller, the store and layout, the output hooks, the text sources and the painter.

It depends on `package:flutter` and nothing else. It is built on `package:flutter/widgets.dart` alone, with no Material and no Cupertino, so it sits inside a `MaterialApp`, a `CupertinoApp` or a bare `WidgetsApp` without bringing a second design system along.

:::

## Platform support

::: fw js

lognal targets current versions of Chrome, Edge, Firefox and Safari. The package is compiled to ES2022. A few features depend on newer browser APIs:

- **Grapheme clusters.** lognal splits text into user-perceived characters with `Intl.Segmenter`, available in Chrome 87, Firefox 125 and Safari 14.1. Where it is missing, a built-in fallback joins combining marks, variation selectors, emoji modifiers, zero width joiner sequences and flag pairs to the character before them. `setGraphemeSplitter` replaces the splitter with your own.
- **Following a file.** `followTextFile` needs a file handle from the File System Access API (`showOpenFilePicker`). Only Chromium-based browsers provide it, and only on secure pages served over HTTPS or from `localhost`. `readTextFile` works in every browser.
- **Copying.** `copySelection` uses the asynchronous Clipboard API on secure pages and falls back to `document.execCommand('copy')` elsewhere.
- **IME input on Safari.** Safari up to version 26 fires `compositionend` before the `keydown` of the key that commits a composition. The input line accounts for this, so pressing Enter to confirm a Japanese or Chinese candidate does not submit the command.

:::

::: fw flutter

lognal needs Dart 3.8 and Flutter 3.32, and runs on every target Flutter does. A few things depend on the platform:

- **Fonts.** With no `family` of your own, the viewer picks the platform's monospace font. Flutter for the web has no system fonts to fall back to, so a web application has to bundle a monospace font and name it. See [Fonts](/guide/theming#fonts).
- **Opening a file by path.** `localTextFile` needs `dart:io`, so it works everywhere except the web. A file picked on the web is read through `CallbackTextFile` instead, and reading a stream of bytes works everywhere. See [Text files](/guide/text-files).
- **Opening a link.** Handing a URL to the platform needs a plugin, which this package does not take. The viewer draws the link and asks, and `onOpenLink` is where your application answers. See [Links](/guide/viewer#links).
- **Legacy encodings.** UTF-8, UTF-16, Windows-1252 and Latin-1 are decoded here. A legacy CJK encoding such as EUC-KR needs a table Dart does not ship, so `registerTextDecoder` takes one from a package you already depend on. See [File encodings](/guide/cjk#file-encodings).
- **Type names in a release web build.** A class with no `toJson()` and no `toString()` of its own is shown by its type name, and `dart compile js` minifies those. Such a value shows as `Object` rather than a made-up name. See [Typed values](/guide/values).

:::
