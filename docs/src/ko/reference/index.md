---
order: 4
description: lognal과 lognal/react가 공개하는 모든 export를 페이지별로 묶어 안내합니다.
---

# 레퍼런스

이 섹션은 `lognal` 패키지가 공개하는 export를 모두 다룹니다. 각 부분이 함께 동작하는 방식은 가이드에서 설명하고, 레퍼런스의 각 페이지에서는 정확한 시그니처와 옵션, 기본값을 정리합니다.

| 페이지                                    | export                                                                                                                                                                                        |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [LogViewer](/ko/reference/log-viewer)     | `LogViewer`와 옵션, 이벤트, 레이블, `readTheme`, `readFont`, `DEFAULT_FONT`, React `LogViewer` 컴포넌트                                                                                       |
| [LogStore](/ko/reference/log-store)       | `LogStore`, `LogStoreOptions`, `DEFAULT_STORE_OPTIONS`, `StoreChange`, `StoreListener`, `WriteOptions`                                                                                        |
| [콘솔 기록](/ko/reference/console)        | `hookConsole`, `createConsole`, `ConsoleRecorder`, `snapshotValue`, `formatArguments`, `applyFormat`, `ValueCapture`, `parseConsoleCss`, `previewValue`                                       |
| [텍스트 소스](/ko/reference/text-sources) | `readTextFile`, `followTextFile`, `TextLineWriter`, `detectEncoding`, `legacyEncodingFor`, `AnsiParser`, `stripAnsi`, `LineSplitter`, `splitLines`, 텍스트 폭 함수                            |
| [레이아웃과 렌더러](/ko/reference/layout) | `LogLayout`, `compileFilter`, `entrySearchText`, `LineAction`, `LineSpan`, `LineTextSpan`, `LineIconSpan`, `LogicalLine`, `Renderer`, `RenderFrame`, `CanvasRenderer`, `DEFAULT_RENDER_THEME` |
| [타입](/ko/reference/types)               | `LogEntry`, `LogPart`, `ValueNode`, `LogLevel`, `LOG_LEVELS`, `TextStyle`, `StyleToken`을 비롯한 공통 타입                                                                                    |

## 진입점 {#entry-points}

| 가져오는 경로      | 내용                                                              |
| ------------------ | ----------------------------------------------------------------- |
| `lognal`           | React 컴포넌트를 뺀, 이 섹션에서 다루는 모든 것입니다.            |
| `lognal/react`     | `LogViewer`와 `LogViewerProps`입니다. React 18 이상이 필요합니다. |
| `lognal/style.css` | 스타일시트입니다. [테마와 글꼴](/ko/guide/theming)을 참고하세요.  |

패키지는 TypeScript로 작성했으며 타입 선언 파일이 들어 있습니다.
