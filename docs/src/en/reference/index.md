---
order: 4
description: Every public export of lognal and lognal/react, grouped by page.
---

# Reference

This section lists every public export of the `lognal` package. The guide explains how the parts work together; these pages give the exact signatures, options and defaults.

| Page                                      | Exports                                                                                                                                                                                       |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [LogViewer](/reference/log-viewer)        | `LogViewer`, its options, events and labels, `readTheme`, `readFont`, `DEFAULT_FONT`, and the React `LogViewer` component                                                                     |
| [LogStore](/reference/log-store)          | `LogStore`, `LogStoreOptions`, `DEFAULT_STORE_OPTIONS`, `StoreChange`, `StoreListener`, `WriteOptions`                                                                                        |
| [Console capture](/reference/console)     | `hookConsole`, `createConsole`, `ConsoleRecorder`, `snapshotValue`, `formatArguments`, `applyFormat`, `ValueCapture`, `parseConsoleCss`, `previewValue`                                       |
| [Text sources](/reference/text-sources)   | `readTextFile`, `followTextFile`, `TextLineWriter`, `detectEncoding`, `legacyEncodingFor`, `AnsiParser`, `stripAnsi`, `LineSplitter`, `splitLines`, and the text measuring functions          |
| [Layout and renderers](/reference/layout) | `LogLayout`, `compileFilter`, `entrySearchText`, `LineAction`, `LineSpan`, `LineTextSpan`, `LineIconSpan`, `LogicalLine`, `Renderer`, `RenderFrame`, `CanvasRenderer`, `DEFAULT_RENDER_THEME` |
| [Types](/reference/types)                 | `LogEntry`, `LogPart`, `ValueNode`, `LogLevel`, `LOG_LEVELS`, `TextStyle`, `StyleToken` and the other shared types                                                                            |

## Entry points

| Import             | Contents                                                      |
| ------------------ | ------------------------------------------------------------- |
| `lognal`           | Everything on these pages except the React component.         |
| `lognal/react`     | `LogViewer` and `LogViewerProps`. Requires React 18 or later. |
| `lognal/style.css` | The stylesheet. See [Themes and fonts](/guide/theming).       |

The package is written in TypeScript and ships its type declarations.
