---
order: 4
description: Every public export of the npm package and every public name of the pub.dev package, grouped by page.
---

# Reference

This section lists what the package makes public. The guide explains how the parts work together; these pages give the exact signatures, options and defaults.

| Page                                      | Exports                                                                                                                                                                                                                                                                                            |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [LogViewer](/reference/log-viewer)        | <Fw js="LogViewer, its options, events and labels, readTheme, readFont, DEFAULT_FONT, and the React LogViewer component" flutter="the LogViewer widget, LogViewerController, LogViewerOptions, ViewerLabels, the palettes and FontSettings" />                                                     |
| [LogStore](/reference/log-store)          | <Fw js="LogStore, LogStoreOptions, DEFAULT_STORE_OPTIONS, StoreChange, StoreListener, WriteOptions" flutter="LogStore, LogStoreOptions, defaultStoreOptions, StoreChange, StoreListener, WriteOptions" />                                                                                          |
| [Console capture](/reference/console)     | <Fw js="hookConsole, createConsole, ConsoleRecorder, snapshotValue, formatArguments, applyFormat, ValueCapture, parseConsoleCss, previewValue" flutter="hookDebugPrint, runZonedWithLognal, hookFlutterErrors, LognalConsole, ConsoleRecorder, captureValue, formatArguments, previewValue" />     |
| [Text sources](/reference/text-sources)   | <Fw js="readTextFile, followTextFile, TextLineWriter, detectEncoding, legacyEncodingFor, AnsiParser, stripAnsi, LineSplitter, splitLines, and the text measuring functions" flutter="readTextStream, readTextBytes, followTextFile, TextFileSource, registerTextDecoder, AnsiParser, stripAnsi" /> |
| [Layout and renderers](/reference/layout) | <Fw js="LogLayout, compileFilter, entrySearchText, LineAction, LineSpan, LineTextSpan, LineIconSpan, LogicalLine, Renderer, RenderFrame, CanvasRenderer, DEFAULT_RENDER_THEME" flutter="LogLayout, LogSearch, compileFilter, LineAction, LineSpan, LogicalLine, LogRenderer, CanvasLogRenderer" /> |
| [Types](/reference/types)                 | <Fw js="LogEntry, LogPart, ValueNode, LogLevel, LOG_LEVELS, TextStyle, StyleToken and the other shared types" flutter="LogEntry, LogPart, ValueNode, LogLevel, logLevels, LogTextStyle, StyleToken and the other shared types" />                                                                  |

## Entry points

::: fw js

| Import             | Contents                                                      |
| ------------------ | ------------------------------------------------------------- |
| `lognal`           | Everything on these pages except the React component.         |
| `lognal/react`     | `LogViewer` and `LogViewerProps`. Requires React 18 or later. |
| `lognal/style.css` | The stylesheet. See [Themes and fonts](/guide/theming).       |

The package is written in TypeScript and ships its type declarations.

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';
```

One import for everything on these pages. There is no second entry point and no stylesheet: the palettes are values, and a widget takes them as arguments.

The package depends on `package:flutter` and nothing else. Grapheme clusters come from `package:characters`, which `package:flutter/widgets.dart` re-exports, so it costs nothing extra.

These pages give the shape of each name and what it is for. The generated API documentation on [pub.dev](https://pub.dev/documentation/lognal/latest/) has every member and every doc comment, and it is written from the same source.

:::

The two packages carry the same names wherever Dart allows it. Three could not keep theirs, because `package:flutter/widgets.dart` was already using them:

| npm              | pub.dev                | Taken by                                 |
| ---------------- | ---------------------- | ---------------------------------------- |
| `RepeatMode`     | `MergeRepeats`         | `RepeatMode`, the animation one          |
| `TextPosition`   | `LogPosition`          | `TextPosition`, the one in `dart:ui`     |
| `ToolbarOptions` | `ViewerToolbarOptions` | `ToolbarOptions`, the text selection one |
