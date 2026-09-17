---
order: 4
description: npm 패키지가 공개하는 export와 pub.dev 패키지가 공개하는 이름을 페이지별로 묶어 안내합니다.
---

# 레퍼런스

이 섹션은 패키지가 공개하는 것을 모두 다룹니다. 각 부분이 함께 동작하는 방식은 가이드에서 설명하고, 레퍼런스의 각 페이지에서는 정확한 시그니처와 옵션, 기본값을 정리합니다.

| 페이지                                    | 공개하는 이름                                                                                                                                                                                                                                                                                      |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [LogViewer](/ko/reference/log-viewer)     | <Fw js="LogViewer와 옵션, 이벤트, 레이블, readTheme, readFont, DEFAULT_FONT, React LogViewer 컴포넌트" flutter="LogViewer 위젯, LogViewerController, LogViewerOptions, ViewerLabels, 팔레트와 FontSettings" />                                                                                     |
| [LogStore](/ko/reference/log-store)       | <Fw js="LogStore, LogStoreOptions, DEFAULT_STORE_OPTIONS, StoreChange, StoreListener, WriteOptions" flutter="LogStore, LogStoreOptions, defaultStoreOptions, StoreChange, StoreListener, WriteOptions" />                                                                                          |
| [콘솔 기록](/ko/reference/console)        | <Fw js="hookConsole, createConsole, ConsoleRecorder, snapshotValue, formatArguments, applyFormat, ValueCapture, parseConsoleCss, previewValue" flutter="hookDebugPrint, runZonedWithLognal, hookFlutterErrors, LognalConsole, ConsoleRecorder, captureValue, formatArguments, previewValue" />     |
| [텍스트 소스](/ko/reference/text-sources) | <Fw js="readTextFile, followTextFile, TextLineWriter, detectEncoding, legacyEncodingFor, AnsiParser, stripAnsi, LineSplitter, splitLines, 텍스트 폭 함수" flutter="readTextStream, readTextBytes, followTextFile, TextFileSource, registerTextDecoder, AnsiParser, stripAnsi" />                   |
| [레이아웃과 렌더러](/ko/reference/layout) | <Fw js="LogLayout, compileFilter, entrySearchText, LineAction, LineSpan, LineTextSpan, LineIconSpan, LogicalLine, Renderer, RenderFrame, CanvasRenderer, DEFAULT_RENDER_THEME" flutter="LogLayout, LogSearch, compileFilter, LineAction, LineSpan, LogicalLine, LogRenderer, CanvasLogRenderer" /> |
| [타입](/ko/reference/types)               | <Fw js="LogEntry, LogPart, ValueNode, LogLevel, LOG_LEVELS, TextStyle, StyleToken을 비롯한 공통 타입" flutter="LogEntry, LogPart, ValueNode, LogLevel, logLevels, LogTextStyle, StyleToken을 비롯한 공통 타입" />                                                                                  |

## 진입점 {#entry-points}

::: fw js

| 가져오는 경로      | 내용                                                              |
| ------------------ | ----------------------------------------------------------------- |
| `lognal`           | React 컴포넌트를 뺀, 이 섹션에서 다루는 모든 것입니다.            |
| `lognal/react`     | `LogViewer`와 `LogViewerProps`입니다. React 18 이상이 필요합니다. |
| `lognal/style.css` | 스타일시트입니다. [테마와 글꼴](/ko/guide/theming)을 참고하세요.  |

패키지는 TypeScript로 작성했으며 타입 선언 파일이 들어 있습니다.

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';
```

이 섹션에서 다루는 모든 것이 이 한 줄로 들어옵니다. 두 번째 진입점도, 스타일시트도 없습니다. 팔레트는 값이고, 위젯이 그 값을 인자로 받습니다.

패키지가 의존하는 것은 `package:flutter`뿐입니다. 자모 묶음은 `package:characters`에서 오는데, `package:flutter/widgets.dart`가 이미 다시 내보내고 있어 따로 드는 비용이 없습니다.

이 페이지들은 각 이름의 모양과 쓰임새를 정리합니다. 모든 멤버와 문서 주석은 같은 소스에서 만든 [pub.dev의 API 문서](https://pub.dev/documentation/lognal/latest/)에 있습니다.

:::

두 패키지는 Dart가 허락하는 한 같은 이름을 씁니다. 셋만 이름을 바꿨는데, `package:flutter/widgets.dart`가 먼저 쓰고 있었기 때문입니다.

| npm              | pub.dev                | 먼저 쓰고 있던 이름            |
| ---------------- | ---------------------- | ------------------------------ |
| `RepeatMode`     | `MergeRepeats`         | 애니메이션의 `RepeatMode`      |
| `TextPosition`   | `LogPosition`          | `dart:ui`의 `TextPosition`     |
| `ToolbarOptions` | `ViewerToolbarOptions` | 텍스트 선택의 `ToolbarOptions` |
