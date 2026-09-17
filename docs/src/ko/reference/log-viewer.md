---
order: 1
description: 뷰어와 옵션, 메서드, 이벤트, 레이블, 팔레트와 글꼴, formatTimestamp의 레퍼런스입니다.
---

# LogViewer

::: fw js

```ts
import { LogViewer } from 'lognal';

const viewer = new LogViewer(container, options);
```

도구 모음, 렌더러가 그리는 로그, 선택적인 입력 줄, 상태 표시줄로 이루어진 로그 뷰어입니다. 뷰어는 스크롤, 선택, 키보드, 접근성을 처리하고 프레임마다 렌더러에 그리기를 맡깁니다. 레이아웃과 테마를 위해 `lognal/style.css`를 한 번 가져오세요.

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

LogViewer(store: store, options: options);
```

도구 모음, 캔버스에 그리는 로그, 선택적인 입력 줄, 상태 표시줄로 이루어진 로그 뷰어입니다. 위젯은 스크롤, 선택, 키보드, 시맨틱스를 처리하고 프레임마다 페인터에 그리기를 맡깁니다. 그 뒤의 상태는 `LogViewerController`이고, 이 페이지의 메서드는 모두 거기에 있습니다.

위젯은 `package:flutter/widgets.dart`만으로 만들었습니다. Material도 Cupertino도 쓰지 않으므로 `MaterialApp`, `CupertinoApp`, 맨 `WidgetsApp` 어디에 넣어도 다른 디자인 시스템이 따라 들어오지 않습니다.

:::

## 생성자 {#constructor}

::: fw js

```ts
new LogViewer(container: HTMLElement, options?: LogViewerOptions)
```

뷰어를 만들고 루트 요소를 `container`에 추가합니다.

:::

::: fw flutter

```dart
LogViewer({
  LogStore? store,
  LogViewerController? controller,
  LogViewerOptions options = const LogViewerOptions(),
  FocusNode? focusNode,
  bool autofocus = false,
})
```

`store`를 넘기면 위젯이 그 위에 컨트롤러를 만들고, 이미 들고 있는 `controller`를 넘기면 리빌드를 넘어 그대로 씁니다. 둘을 함께 넘기는 것은 오류입니다. 컨트롤러에는 이미 스토어가 있기 때문입니다.

컨트롤러를 넘겼든 아니든 `options`가 언제나 이깁니다. 그래서 리빌드하며 바뀐 옵션이 뷰어에 닿습니다.

:::

## 속성 {#properties}

::: fw js

| 속성          | 타입             | 설명                                                                                         |
| ------------- | ---------------- | -------------------------------------------------------------------------------------------- |
| `store`       | `LogStore`       | 뷰어가 보여 주는 스토어입니다. 읽기 전용입니다.                                              |
| `layout`      | `LogLayout`      | 뷰어의 레이아웃입니다. 읽기 전용입니다.                                                      |
| `element`     | `HTMLDivElement` | `lognal` 클래스가 붙은 루트 요소입니다. 읽기 전용입니다.                                     |
| `console`     | `LognalConsole`  | 스토어에 쓰는, 콘솔 메서드를 갖춘 객체입니다. 처음 쓸 때 만들고 이후에는 같은 객체를 씁니다. |
| `isFollowing` | `boolean`        | 새 항목을 따라가는 중인지 나타냅니다.                                                        |

:::

::: fw flutter

모두 `ChangeNotifier`를 상속한 `LogViewerController`의 멤버입니다.

| 속성           | 타입               | 설명                                                         |
| -------------- | ------------------ | ------------------------------------------------------------ |
| `store`        | `LogStore`         | 뷰어가 보여 주는 스토어입니다.                               |
| `layout`       | `LogLayout`        | 뷰어의 레이아웃입니다.                                       |
| `search`       | `LogSearch`        | 레이아웃 위의 검색입니다.                                    |
| `options`      | `LogViewerOptions` | 지금 적용된 옵션입니다.                                      |
| `isFollowing`  | `bool`             | 새 항목을 따라가는 중인지 나타냅니다.                        |
| `hasUnseen`    | `bool`             | 따라가기가 멈춘 사이에 들어온 항목이 있는지 나타냅니다.      |
| `filter`       | `LogFilter?`       | 필터입니다.                                                  |
| `muteRules`    | `List<MuteRule>`   | 항목을 로그에서 빼는 규칙입니다.                             |
| `mutedCount`   | `int`              | 스토어의 항목 가운데 그 규칙이 가린 수입니다.                |
| `visibleCount` | `int`              | 로그에 보이는 항목 수로, 상태 표시줄이 세는 수입니다.        |
| `entryCount`   | `int`              | 스토어가 보관하는 항목 수입니다.                             |
| `themeName`    | `String`           | 지금 쓰는 팔레트입니다. 도구 모음 메뉴에서 바뀔 수 있습니다. |
| `isSearchOpen` | `bool`             | 검색 창이 열려 있는지 나타냅니다.                            |

:::

## 메서드 {#methods}

::: fw js

| 메서드                                                               | 반환값              | 설명                                                                                                                                                                                 |
| -------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `setOptions(options: Omit<LogViewerOptions, 'store' \| 'renderer'>)` | `void`              | 넘긴 옵션만 바꾸고 나머지는 그대로 둡니다. `locale`을 바꾸면 내장 레이블이 바뀌고, `labels`로 넘긴 레이블은 그대로 남습니다.                                                         |
| `write(text: string, options?: WriteOptions)`                        | `void`              | 텍스트를 항목 하나로 추가합니다. 줄 바꿈은 항목 안에 그대로 둡니다.                                                                                                                  |
| `writeLines(text: string, options?: WriteOptions)`                   | `void`              | 텍스트를 줄마다 항목 하나씩 추가합니다.                                                                                                                                              |
| `hookConsole(target?: Console, options?: HookConsoleOptions)`        | `() => void`        | 콘솔을 스토어에 기록합니다. 기본 대상은 `console`입니다. 기록을 멈추는 함수를 반환하며, 뷰어를 정리해도 기록이 멈춥니다.                                                             |
| `clear()`                                                            | `void`              | 스토어의 항목을 모두 지우고 선택을 해제합니다.                                                                                                                                       |
| `setFilter(filter: LogFilter \| null)`                               | `void`              | 필터를 정합니다. `null`이면 모든 항목을 보여 줍니다. `filter` 이벤트가 발생합니다.                                                                                                   |
| `getFilter()`                                                        | `LogFilter \| null` | 필터를 반환합니다.                                                                                                                                                                   |
| `getMuteRules()`                                                     | `MuteRule[]`        | 항목을 로그에서 빼는 규칙을 돌려줍니다.                                                                                                                                              |
| `setMuteRules(rules: readonly MuteRule[])`                           | `void`              | 그 규칙을 통째로 바꿉니다. `filter` 이벤트가 발생합니다.                                                                                                                             |
| `getMutedCount()`                                                    | `number`            | 스토어가 든 항목 가운데 그 규칙이 가리는 항목 수입니다.                                                                                                                              |
| `openMuteDialog()`                                                   | `void`              | 규칙을 관리하는 대화 상자를 엽니다.                                                                                                                                                  |
| `setFollowing(following: boolean)`                                   | `void`              | 따라가기를 켜거나 끕니다. 켜면 가장 새 항목으로 스크롤합니다. 값이 바뀌면 `follow` 이벤트가 발생합니다.                                                                              |
| `scrollToTop()`                                                      | `void`              | 따라가기를 멈추고 첫 행으로 스크롤합니다.                                                                                                                                            |
| `scrollToBottom()`                                                   | `void`              | 따라가기를 켜서 가장 새 항목으로 스크롤합니다.                                                                                                                                       |
| `scrollToEntry(entryId: number)`                                     | `void`              | 따라가기를 멈추고 항목이 맨 위에 오도록 스크롤합니다. 보이지 않는 항목이면 아무것도 하지 않습니다.                                                                                   |
| `getSelectionText(options?: EntryTextOptions)`                       | `string`            | 선택을 텍스트로 반환합니다. 텍스트 모드에서는 선택한 텍스트이고, 항목 모드에서는 선택한 항목을 `getEntryText`처럼 `options`에 따라 적은 텍스트입니다. 선택이 없으면 빈 문자열입니다. |
| `getSelectedEntryIds()`                                              | `number[]`          | 보이는 항목 가운데 선택한 항목의 id를 오래된 순서로 반환합니다. 텍스트 모드에서는 선택한 텍스트가 걸친 항목의 id를 반환합니다.                                                       |
| `selectAll()`                                                        | `void`              | 보이는 항목을 모두 선택합니다. 텍스트 모드에서는 그 텍스트를, 항목 모드에서는 항목을 선택합니다. `selection` 이벤트가 발생합니다.                                                    |
| `clearSelection()`                                                   | `void`              | 선택을 해제합니다. 선택이 있었다면 `selection` 이벤트가 발생합니다.                                                                                                                  |
| `copySelection(options?: EntryTextOptions)`                          | `Promise<boolean>`  | 선택을 클립보드에 복사합니다. 항목 모드에서는 선택한 항목을 `options`에 따라 적고, `'formatted'`이면 HTML도 함께 넣습니다. 복사한 내용이 있는지를 이행 값으로 돌려줍니다.            |
| `getEntryText(entryId: number, options?: EntryTextOptions)`          | `string`            | 값을 펼쳤는지와 상관없이 항목 전체를 `options.format` 형식으로 반환합니다. `timestamp: true`이면 앞에 항목의 시각을 붙입니다. 스토어에 더는 없는 항목이면 빈 문자열을 반환합니다.    |
| `copyEntry(entryId: number, options?: EntryTextOptions)`             | `Promise<boolean>`  | `getEntryText`가 반환하는 텍스트를 클립보드에 복사하고, `'formatted'`이면 테마 색을 입힌 HTML도 함께 넣습니다. 복사한 내용이 있는지를 이행 값으로 돌려줍니다.                        |
| `expandEntry(entryId: number)`                                       | `void`              | 항목의 값과 그 안의 값을 캡처된 만큼 모두 펼칩니다.                                                                                                                                  |
| `collapseEntry(entryId: number)`                                     | `void`              | 따로 로그를 남긴 오류까지 포함해 항목의 값을 모두 접습니다.                                                                                                                          |
| `openSearch(query?: string, options?: SearchOptions)`                | `void`              | 검색 창을 열고 `query`나 검색 창에 있던 텍스트, 또는 한 줄 안의 선택 영역으로 검색합니다. `options`로 검색 창의 토글을 바꿉니다. `search`가 꺼져 있으면 아무것도 하지 않습니다.      |
| `closeSearch()`                                                      | `void`              | 검색 창을 닫고 강조를 없앱니다.                                                                                                                                                      |
| `findNext()`                                                         | `void`              | 다음 결과를 현재 결과로 만들고 그 위치로 스크롤합니다. 마지막 결과 다음은 첫 결과입니다.                                                                                             |
| `findPrevious()`                                                     | `void`              | 이전 결과를 현재 결과로 만들고 그 위치로 스크롤합니다.                                                                                                                               |
| `focus()`                                                            | `void`              | 입력 줄에, 입력 줄이 없으면 로그 영역에 포커스를 줍니다.                                                                                                                             |
| `refresh()`                                                          | `void`              | 페이지가 CSS를 바꾼 뒤처럼 필요할 때 CSS에서 테마와 글꼴을 다시 읽습니다.                                                                                                            |
| `on(name, listener)`                                                 | `() => void`        | 이벤트가 일어나면 `listener`를 호출합니다. 리스너를 떼는 함수를 반환합니다.                                                                                                          |
| `dispose()`                                                          | `void`              | 페이지에서 뷰어를 없애고 뷰어가 시작한 작업을 모두 멈춥니다. 두 번 호출해도 문제없습니다.                                                                                            |

:::

::: fw flutter

모두 `LogViewerController`의 멤버입니다. 그리는 내용을 바꾸는 메서드는 컨트롤러의 리스너에게 알립니다.

| 메서드                                                        | 반환값         | 설명                                                                                                                       |
| ------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `setOptions(LogViewerOptions next)`                           | `void`         | 옵션을 통째로 바꿉니다. 위젯이 빌드할 때마다 호출하며, 같은 값이면 아무 일도 하지 않습니다.                                |
| `write(String text, [WriteOptions options])`                  | `void`         | 텍스트를 항목 하나로 추가합니다. 줄 바꿈은 항목 안에 그대로 둡니다.                                                        |
| `writeLines(String text, [WriteOptions options])`             | `void`         | 텍스트를 줄마다 항목 하나씩 추가합니다.                                                                                    |
| `clear()`                                                     | `void`         | 스토어의 항목을 모두 지우고 선택을 해제합니다.                                                                             |
| `setFilter(LogFilter? filter)`                                | `void`         | 필터를 정합니다. `null`이면 모든 항목을 보여 줍니다.                                                                       |
| `setMuteRules(List<MuteRule> rules)`                          | `void`         | 항목을 로그에서 빼는 규칙을 바꿉니다.                                                                                      |
| `setFollowing(bool following)`                                | `void`         | 따라가기를 켜거나 끕니다. 켜면 가장 새 항목으로 스크롤합니다.                                                              |
| `scrollToTop()`                                               | `void`         | 따라가기를 멈추고 첫 행으로 스크롤합니다.                                                                                  |
| `scrollToBottom()`                                            | `void`         | 따라가기를 켜고, 그 결과로 가장 새 항목으로 스크롤합니다.                                                                  |
| `scrollToEntry(int entryId, {bool top})`                      | `void`         | 따라가기를 멈추고 그 항목으로 스크롤합니다. 보이지 않는 항목이면 아무 일도 하지 않습니다.                                  |
| `selectionText([EntryTextOptions options])`                   | `String`       | 선택을 텍스트로 반환합니다. 항목 모드에서는 선택한 항목을 `entryText`와 같은 방식으로 적습니다.                            |
| `selectedEntryIds`                                            | `List<int>`    | 보이는 선택 항목의 id를 오래된 것부터 반환합니다. 텍스트 모드에서는 선택한 텍스트가 걸친 항목의 id입니다.                  |
| `selectAll()`                                                 | `void`         | 보이는 항목을 모두 선택합니다. 텍스트 모드에서는 그 텍스트 전체를, 항목 모드에서는 항목을 선택합니다.                      |
| `clearSelection()`                                            | `void`         | 선택을 해제합니다.                                                                                                         |
| `copySelection([EntryTextOptions options])`                   | `Future<bool>` | 선택을 클립보드에 복사하고, 복사한 내용이 있는지로 완료합니다.                                                             |
| `entryText(int entryId, [EntryTextOptions options])`          | `String`       | 값을 펼쳤는지와 상관없이 항목 전체를 `options.format` 형식으로 반환합니다. 스토어에 없는 항목이면 빈 문자열입니다.         |
| `entriesText(List<int> entryIds, [EntryTextOptions options])` | `String`       | 여러 항목을 오래된 것부터 줄 바꿈으로 나눠 반환합니다. 데이터 형식이면 JSON 배열 하나입니다.                               |
| `copyEntry(int entryId, [EntryTextOptions options])`          | `Future<bool>` | `entryText`가 반환하는 텍스트를 복사하고, 복사한 내용이 있는지로 완료합니다.                                               |
| `copyEntries(List<int> entryIds, [EntryTextOptions options])` | `Future<bool>` | 여러 항목에 대해 같은 일을 합니다.                                                                                         |
| `expandEntry(int entryId)`                                    | `void`         | 항목의 값과 그 안의 값을 캡처된 만큼 모두 펼칩니다.                                                                        |
| `collapseEntry(int entryId)`                                  | `void`         | 따로 로그를 남긴 오류까지 포함해 항목의 값을 모두 접습니다.                                                                |
| `openSearch([String? query, SearchOptions options])`          | `void`         | 검색 창을 열고 `query`나 창에 남아 있던 텍스트, 한 줄 안의 선택으로 검색합니다. `search`가 꺼져 있으면 아무 일도 없습니다. |
| `closeSearch()`                                               | `void`         | 검색 창을 닫고 강조를 없앱니다.                                                                                            |
| `findNext()`, `findPrevious()`                                | `void`         | 다음이나 이전 결과를 현재 결과로 삼고 그곳으로 스크롤합니다. 마지막 다음은 처음입니다.                                     |
| `setTheme(String name)`                                       | `void`         | 도구 모음 메뉴처럼 팔레트를 고릅니다.                                                                                      |
| `toggleWrap()`                                                | `void`         | 줄 바꿈을 끄거나, 끄기 전의 모드로 되돌립니다.                                                                             |
| `refresh()`                                                   | `void`         | 컨트롤러가 알 수 없는 변화가 있을 때 다시 그립니다.                                                                        |
| `dispose()`                                                   | `void`         | 스토어 구독을 끊고 캐시한 것을 놓아 줍니다. 위젯이 만든 컨트롤러는 위젯과 함께 정리됩니다.                                 |

위젯이 그릴 때 쓰는 기하 정보도 컨트롤러에 있습니다. `frame()`, `hitTest(Offset)`, `positionAt(Offset)`, `setViewport(Size, CellMetrics)`, `setTopPixels(double)`, `setScrollX(double)`입니다. 직접 만든 렌더러에는 필요하기 때문에 공개하며, 애플리케이션에서는 쓸 일이 거의 없습니다.

:::

## 이벤트 {#events}

::: fw js

```ts
const copyButton = document.querySelector<HTMLButtonElement>('#copy')!;
const off = viewer.on('selection', (text) => {
	copyButton.disabled = text === '';
});

// 나중에:
off();
```

| 이벤트      | 값                  | 발생 시점                                                                  |
| ----------- | ------------------- | -------------------------------------------------------------------------- |
| `follow`    | `boolean`           | 따라가기가 켜지거나 꺼졌을 때입니다.                                       |
| `filter`    | `LogFilter \| null` | 도구 모음이나 `setFilter`로 필터가 바뀌었을 때입니다.                      |
| `selection` | `string`            | 선택이 바뀌었을 때입니다. 값은 `getSelectionText`가 반환하는 텍스트입니다. |

이벤트 이름과 값의 타입은 `LogViewerEvents` 타입에 정의되어 있습니다.

:::

::: fw flutter

`LogViewerController`는 `ChangeNotifier`이므로 신호가 셋이 아니라 하나입니다.

```dart
controller.addListener(() => setState(() {}));
```

따라가기, 필터, 선택을 포함해 뷰어가 그리는 무엇이든 바뀌면 알립니다. 무엇이 바뀌었는지는 `isFollowing`, `filter`, `selectionText()`에서 읽습니다. 항목만 따로 듣고 싶다면 스토어의 `store.listen`이 있습니다.

:::

## LogViewerOptions {#logvieweroptions}

::: fw js

| 옵션            | 타입                                    | 기본값                         | 설명                                                                                                                  |
| --------------- | --------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `store`         | `LogStore`                              | 새 스토어                      | 보여 줄 스토어입니다. 여러 뷰어가 스토어 하나를 함께 쓸 수 있습니다.                                                  |
| `core`          | `Partial<CoreOptions>`                  | `{}`                           | 코어 옵션입니다. 스토어 옵션은 `store`로 넘긴 스토어에도 적용합니다.                                                  |
| `theme`         | `ThemeMode`                             | `'auto'`                       | 팔레트입니다. `'auto'`는 운영체제 설정을 따르고, 그 밖의 이름은 `data-theme`에 그대로 들어갑니다.                     |
| `themes`        | `(ThemeMode \| ThemeChoice)[]`          | `['auto', ...BUILT_IN_THEMES]` | 도구 모음 메뉴에 넣을 테마입니다. 문자열은 이름이고, 객체는 레이블까지 정합니다.                                      |
| `font`          | `Partial<FontSettings>`                 | `{}`                           | 글꼴입니다. 빠진 값은 `--lognal-font-*` CSS 속성에서 가져옵니다.                                                      |
| `timestamps`    | `boolean \| TimestampFormat`            | `true`                         | 항목마다 시각을 보여 줄지, 어떤 형식으로 보여 줄지 정합니다. `true`는 `'time'`입니다.                                 |
| `follow`        | `boolean`                               | `true`                         | 처음에 새 항목을 따라갈지 정합니다.                                                                                   |
| `toolbar`       | `boolean \| Partial<ToolbarOptions>`    | `true`                         | 도구 모음입니다. `false`이면 숨기고, 객체를 넘기면 컨트롤을 하나씩 끌 수 있습니다.                                    |
| `statusBar`     | `boolean`                               | `true`                         | 상태 표시줄을 보여 줄지 정합니다.                                                                                     |
| `input`         | `InputOptions \| null`                  | `null`                         | 입력 줄입니다. 읽기 전용 뷰어라면 생략합니다.                                                                         |
| `locale`        | `string`                                | `undefined`                    | 내장 레이블과 숫자 서식의 언어입니다. 예를 들면 `'en'`, `'ko'`입니다.                                                 |
| `labels`        | `Partial<ViewerLabels>`                 | `{}`                           | 내장 레이블 대신 쓸 레이블입니다.                                                                                     |
| `entryMenu`     | `boolean \| EntryMenuOptions`           | `true`                         | 포인터가 올라간 항목의 작업 메뉴입니다. `false`이면 끕니다.                                                           |
| `search`        | `boolean`                               | `true`                         | 뷰어에 포커스가 있을 때 Ctrl+F나 Cmd+F로, 항목을 숨기지 않고 일치하는 곳을 모두 강조하는 검색 창을 열지 정합니다.     |
| `linkClick`     | `LinkClick`                             | `'confirm'`                    | 링크를 클릭하거나 탭했을 때의 동작입니다. [`LinkClick`](#linkclick)을 참고하세요.                                     |
| `selectionMode` | `SelectionMode`                         | `'text'`                       | 포인터와 키보드로 텍스트를 선택할지, 항목을 통째로 선택할지 정합니다. [`SelectionMode`](#selectionmode)를 참고하세요. |
| `tooltips`      | `boolean`                               | `true`                         | 도구 모음 컨트롤에 포인터가 닿는 즉시 이름을 보여 줄지 정합니다.                                                      |
| `renderer`      | `(ownerDocument: Document) => Renderer` | `CanvasRenderer`               | 렌더러를 만듭니다.                                                                                                    |

:::

::: fw flutter

| 옵션              | 타입                             | 기본값                   | 설명                                                                                                |
| ----------------- | -------------------------------- | ------------------------ | --------------------------------------------------------------------------------------------------- |
| `core`            | `CoreOptions`                    | `CoreOptions()`          | 코어 옵션입니다. 스토어 옵션은 위젯이 받은 스토어에도 적용합니다.                                   |
| `theme`           | `String`                         | `'auto'`                 | 팔레트입니다. `auto`, lognal이 제공하는 팔레트, `themeResolver`가 답하는 이름 가운데 하나입니다.    |
| `themes`          | `List<ThemeChoice>?`             | `auto`와 기본 팔레트     | 도구 모음 메뉴에 넣을 테마입니다.                                                                   |
| `themeResolver`   | `LognalTheme? Function(String)?` | `null`                   | 직접 지은 이름의 팔레트를 반환하거나, `null`로 기본 동작에 맡깁니다.                                |
| `font`            | `FontSettings`                   | `FontSettings()`         | 글꼴입니다. [`FontSettings`](#fontsettings)를 참고하세요.                                           |
| `timestamps`      | `bool`                           | `true`                   | 항목마다 시각을 보여 줄지 정합니다.                                                                 |
| `timestampFormat` | `TimestampFormat`                | `TimestampFormat.time`   | 시각을 적는 형식입니다. `formatTimestamp`가 있으면 그쪽이 이깁니다.                                 |
| `formatTimestamp` | `String Function(DateTime)?`     | `null`                   | 항목의 시각을 직접 정한 형식으로 적습니다.                                                          |
| `follow`          | `bool`                           | `true`                   | 처음에 새 항목을 따라갈지 정합니다.                                                                 |
| `toolbar`         | `ViewerToolbarOptions`           | `ViewerToolbarOptions()` | 도구 모음입니다. `ViewerToolbarOptions.hidden`이면 빼고 그립니다.                                   |
| `statusBar`       | `bool`                           | `true`                   | 상태 표시줄을 보여 줄지 정합니다.                                                                   |
| `input`           | `InputOptions?`                  | `null`                   | 입력 줄입니다. 읽기 전용 뷰어라면 생략합니다.                                                       |
| `locale`          | `String?`                        | `null`                   | 내장 레이블의 언어입니다. 예를 들면 `en`, `ko`입니다.                                               |
| `labels`          | `ViewerLabels?`                  | `null`                   | 내장 레이블 대신 쓸 레이블 한 벌입니다.                                                             |
| `entryMenu`       | `EntryMenuOptions`               | `EntryMenuOptions()`     | 포인터가 올라간 항목의 작업 메뉴입니다.                                                             |
| `search`          | `bool`                           | `true`                   | 찾기 단축키로, 항목을 숨기지 않고 일치하는 곳을 모두 강조하는 검색 창을 열지 정합니다.              |
| `linkClick`       | `LinkClick`                      | `LinkClick.confirm`      | 링크를 탭했을 때의 동작입니다. [`LinkClick`](#linkclick)을 참고하세요.                              |
| `selectionMode`   | `SelectionMode`                  | `SelectionMode.text`     | 텍스트를 선택할지, 항목을 통째로 선택할지 정합니다. [`SelectionMode`](#selectionmode)를 참고하세요. |
| `tooltips`        | `bool`                           | `true`                   | 도구 모음 컨트롤에 포인터가 닿는 즉시 이름을 보여 줄지 정합니다.                                    |
| `formatNumber`    | `NumberFormatter`                | `formatCount`            | 숫자를 읽는 사람의 언어에 맞게 적습니다.                                                            |
| `onOpenLink`      | `void Function(String)?`         | `null`                   | 링크를 엽니다. 없으면 `linkClick`은 링크를 그리고 묻기까지 하지만 답이 아무 데도 가지 않습니다.     |

`store` 옵션도 `renderer` 옵션도 없습니다. 스토어는 위젯이나 컨트롤러의 생성자 인자이고, 페인터는 위젯이 정합니다.

`copyWith`는 넘긴 필드만 바꾼 사본을 반환하며, 빌드 사이에 옵션을 바꾸는 방법이 이것입니다.

:::

## CoreOptions {#coreoptions}

`CoreOptions`는 스토어 옵션과 레이아웃 옵션, 필터를 합친 타입입니다.

::: fw js

| 옵션             | 타입                | 기본값   | 설명                                                                                                                 |
| ---------------- | ------------------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `number`            | `10000`  | 스토어가 보관하는 최대 항목 수입니다. 모두 보관하려면 `Infinity`를 씁니다.                                           |
| `mergeRepeats`   | `RepeatMode`        | `true`   | 바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. [`RepeatMode`](/ko/reference/log-store#repeatmode)를 참고하세요. |
| `wrap`           | `WrapMode`          | `'word'` | `'word'`, `'char'`, `'none'` 가운데 하나입니다.                                                                      |
| `tabSize`        | `number`            | `8`      | 탭 위치 사이의 칸 수입니다.                                                                                          |
| `ambiguousWidth` | `AmbiguousWidth`    | `1`      | 동아시아 모호 폭 문자가 차지하는 칸 수로, `1`이나 `2`입니다.                                                         |
| `maxClusters`    | `number`            | `10000`  | 한 줄에 남기는 최대 그래핌 클러스터 수입니다. 나머지는 `…`로 대신합니다.                                             |
| `links`          | `boolean`           | `true`   | 텍스트 안의 `http`, `https` 주소를 링크로 만들지 정합니다.                                                           |
| `filter`         | `LogFilter \| null` | `null`   | 필터입니다. [`LogFilter`](/ko/reference/layout#logfilter)를 참고하세요.                                              |

:::

::: fw flutter

| 옵션             | 타입             | 기본값               | 설명                                                                                                                   |
| ---------------- | ---------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `int`            | `10000`              | 스토어가 보관하는 최대 항목 수입니다.                                                                                  |
| `mergeRepeats`   | `MergeRepeats`   | `MergeRepeats.merge` | 바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. [`MergeRepeats`](/ko/reference/log-store#repeatmode)를 참고하세요. |
| `wrap`           | `WrapMode`       | `WrapMode.word`      | `WrapMode.word`, `WrapMode.char`, `WrapMode.none` 가운데 하나입니다.                                                   |
| `tabSize`        | `int`            | `8`                  | 탭 위치 사이의 칸 수입니다.                                                                                            |
| `ambiguousWidth` | `AmbiguousWidth` | `1`                  | 동아시아 모호 폭 문자가 차지하는 칸 수로, `1`이나 `2`입니다.                                                           |
| `maxClusters`    | `int`            | `10000`              | 한 줄에 남기는 최대 그래핌 클러스터 수입니다. 나머지는 `…`로 대신합니다.                                               |
| `links`          | `bool`           | `true`               | 텍스트 안의 `http`, `https` 주소를 링크로 만들지 정합니다.                                                             |
| `filter`         | `LogFilter?`     | `null`               | 필터입니다. [`LogFilter`](/ko/reference/layout#logfilter)를 참고하세요.                                                |

`storeOptions`와 `layoutOptions`는 각각 스토어와 레이아웃에 해당하는 절반을 반환합니다. `copyWith`로 필터를 지우려면 `clearFilter: true`를 넘깁니다. 이름 있는 매개변수에 `null`을 넘긴 것과 아예 넘기지 않은 것을 구별할 수 없기 때문입니다.

:::

## ToolbarOptions {#toolbaroptions}

모든 컨트롤이 기본으로 켜져 있습니다.

::: fw js

| 옵션            | 타입      | 컨트롤                       |
| --------------- | --------- | ---------------------------- |
| `follow`        | `boolean` | 새 로그 따라가기             |
| `clear`         | `boolean` | 로그 지우기                  |
| `scroll`        | `boolean` | 맨 위로 이동, 맨 아래로 이동 |
| `wrap`          | `boolean` | 긴 줄 바꾸기                 |
| `selectionMode` | `boolean` | 항목 단위로 선택             |
| `theme`         | `boolean` | 테마 메뉴                    |
| `mute`          | `boolean` | 숨긴 메시지 대화 상자        |
| `filter`        | `boolean` | 필터 입력란                  |
| `levels`        | `boolean` | 로그 수준 메뉴               |

:::

::: fw flutter

클래스 이름은 `ViewerToolbarOptions`입니다. `ToolbarOptions`는 `package:flutter/widgets.dart`가 먼저 쓰고 있습니다.

| 옵션            | 타입   | 컨트롤                       |
| --------------- | ------ | ---------------------------- |
| `visible`       | `bool` | 도구 모음 자체               |
| `follow`        | `bool` | 새 로그 따라가기             |
| `clear`         | `bool` | 로그 지우기                  |
| `scroll`        | `bool` | 맨 위로 이동, 맨 아래로 이동 |
| `wrap`          | `bool` | 긴 줄 바꾸기                 |
| `selectionMode` | `bool` | 항목 단위로 선택             |
| `theme`         | `bool` | 테마 메뉴                    |
| `mute`          | `bool` | 숨긴 메시지 대화 상자        |
| `filter`        | `bool` | 필터 입력란                  |
| `levels`        | `bool` | 로그 수준 메뉴               |

`ViewerToolbarOptions.hidden`은 `visible: false`인 도구 모음이고, 도구 모음을 빼는 방법이 이것입니다.

:::

## InputOptions {#inputoptions}

::: fw js

| 옵션          | 타입                                              | 기본값                    | 설명                                                                                                                                       |
| ------------- | ------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `onSubmit`    | `(command: string, viewer: LogViewer) => unknown` | 필수                      | 명령마다 호출합니다. 반환한 값이나 반환한 프로미스가 이행한 값을 응답으로 출력합니다. 아무것도 출력하지 않으려면 `undefined`를 반환합니다. |
| `prompt`      | `string`                                          | `'>'`                     | 입력 앞에 보이는 프롬프트입니다.                                                                                                           |
| `placeholder` | `string`                                          | `labels.inputPlaceholder` | 입력란의 자리 표시 텍스트입니다.                                                                                                           |
| `echo`        | `boolean`                                         | `true`                    | 명령을 실행하기 전에 로그에 추가할지 정합니다.                                                                                             |
| `historySize` | `number`                                          | `100`                     | 화살표 키로 오갈 수 있는 이전 명령 수입니다.                                                                                               |

:::

::: fw flutter

| 옵션          | 타입                       | 기본값                    | 설명                                                                                                                     |
| ------------- | -------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `onSubmit`    | `Object? Function(String)` | 필수                      | 명령마다 호출합니다. 반환한 값이나 반환한 퓨처가 완료한 값을 응답으로 출력합니다. `null`이면 아무것도 출력하지 않습니다. |
| `prompt`      | `String`                   | `'>'`                     | 입력 앞에 보이는 프롬프트입니다.                                                                                         |
| `placeholder` | `String?`                  | `labels.inputPlaceholder` | 입력란 안의 안내 문구입니다.                                                                                             |
| `echo`        | `bool`                     | `true`                    | 명령을 실행하기 전에 로그에 추가할지 정합니다.                                                                           |
| `historySize` | `int`                      | `100`                     | 화살표 키로 오갈 수 있는 이전 명령 수입니다.                                                                             |

`onSubmit`은 명령만 받습니다. 함께 넘길 컨트롤러는 이미 애플리케이션이 들고 있는 것이기 때문입니다.

:::

## EntryMenuOptions {#entrymenuoptions}

::: fw js

| 옵션    | 타입                                                      | 기본값 | 설명                                                                                                                                                                                   |
| ------- | --------------------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `copy`  | `boolean`                                                 | `true` | 메뉴를 복사 항목으로 시작할지 정합니다. 복사 항목은 **텍스트로 복사**, **타임스탬프와 함께 복사**, **서식 있는 텍스트로 복사**이고, 값이 있는 항목에는 **데이터로 복사**가 더해집니다. |
| `items` | `(entry: LogEntry, viewer: LogViewer) => EntryMenuItem[]` | 없음   | 메뉴가 열릴 때마다 호출합니다. 반환한 메뉴 항목은 구분선 아래, 내장 항목 다음에 나옵니다.                                                                                              |

`copy: false`이면서 `items`가 없으면 메뉴가 꺼집니다. 메뉴 항목이 하나도 없는 메뉴는 열리지 않습니다.

:::

::: fw flutter

| 옵션      | 타입                                      | 기본값 | 설명                                                                                                                                                                                   |
| --------- | ----------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `visible` | `bool`                                    | `true` | 버튼을 아예 둘지 정합니다.                                                                                                                                                             |
| `copy`    | `bool`                                    | `true` | 메뉴를 복사 항목으로 시작할지 정합니다. 복사 항목은 **텍스트로 복사**, **타임스탬프와 함께 복사**, **서식 있는 텍스트로 복사**이고, 값이 있는 항목에는 **데이터로 복사**가 더해집니다. |
| `items`   | `List<EntryMenuItem> Function(LogEntry)?` | `null` | 메뉴가 열릴 때마다 호출합니다. 반환한 메뉴 항목은 구분선 아래, 내장 항목 다음에 나옵니다.                                                                                              |

`EntryMenuOptions.hidden`은 `visible: false`인 메뉴입니다. 메뉴 항목이 하나도 없는 메뉴는 열리지 않습니다.

:::

### EntryMenuItem {#entrymenuitem}

| 필드       | 타입                                                                                                  | 설명                                                 |
| ---------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `label`    | <Fw js="string" flutter="String" code />                                                              | 메뉴 항목의 텍스트입니다.                            |
| `onSelect` | <Fw js="(entry: LogEntry, viewer: LogViewer) => void" flutter="void Function(LogEntry entry)" code /> | 고르면 메뉴를 연 로그 항목을 인자로 받아 호출합니다. |

### EntryTextOptions {#entrytextoptions}

| 옵션        | 타입                                    | 기본값                                                 | 설명                                                                                                                                  |
| ----------- | --------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `format`    | `EntryTextFormat`                       | <Fw js="'text'" flutter="EntryTextFormat.text" code /> | 항목을 적는 형식입니다.                                                                                                               |
| `timestamp` | <Fw js="boolean" flutter="bool" code /> | `false`                                                | 텍스트 앞에 항목의 시각을 붙일지 정합니다. 시각은 시각 형식 옵션을 따르고, 꺼져 있으면 `time`을 씁니다. 데이터 형식에서는 무시합니다. |

::: fw js

| `EntryTextFormat` | 결과                                                                                                                                                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`          | 서식 없는 텍스트입니다. 값은 모두 한 줄에 적습니다.                                                                                                                                                                                                                                   |
| `'formatted'`     | 한 줄에 다 들어가지 않는 값을 들여쓴 여러 줄로 나눕니다. `copyEntry`는 테마 색을 입힌 HTML도 함께 복사합니다.                                                                                                                                                                         |
| `'data'`          | 값을 JSON으로 적습니다. 값이 하나면 그 값, 여러 개면 값의 배열, 값이 없으면 항목의 텍스트입니다. `undefined`는 `null`, Set은 배열, 텍스트 키를 쓰는 Map은 객체, 오류는 `name`, `message`, `stack`이 든 객체가 되고, `10n`이나 `Symbol(token)`처럼 JSON에 없는 타입은 텍스트가 됩니다. |

:::

::: fw flutter

| `EntryTextFormat`           | 결과                                                                                                                                                                                                                          |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EntryTextFormat.text`      | 서식 없는 텍스트입니다. 값은 모두 한 줄에 적습니다.                                                                                                                                                                           |
| `EntryTextFormat.formatted` | 한 줄에 다 들어가지 않는 값을 들여쓴 여러 줄로 나눕니다.                                                                                                                                                                      |
| `EntryTextFormat.data`      | 값을 JSON으로 적습니다. 값이 하나면 그 값, 여러 개면 값의 리스트, 값이 없으면 항목의 텍스트입니다. Set은 리스트, 텍스트 키를 쓰는 Map은 객체가 되고, `DateTime`이나 `Symbol("token")`처럼 JSON에 없는 타입은 텍스트가 됩니다. |

서식 있는 형식에 HTML은 없습니다. 이 패키지가 도는 플랫폼의 클립보드는 서식 없는 텍스트를 받으므로, 색을 넣을 자리가 없습니다.

:::

### SearchOptions {#searchoptions}

| 옵션            | 타입                                    | 기본값  | 설명                                                           |
| --------------- | --------------------------------------- | ------- | -------------------------------------------------------------- |
| `caseSensitive` | <Fw js="boolean" flutter="bool" code /> | `false` | 대소문자가 맞아야 하는지 정합니다.                             |
| `regex`         | <Fw js="boolean" flutter="bool" code /> | `false` | 텍스트를 글자 그대로가 아니라 정규 표현식으로 읽을지 정합니다. |

### SelectionMode {#selectionmode}

::: fw js

```ts
type SelectionMode = 'text' | 'entry';
```

| 값        | 포인터와 키보드로 선택하는 방식                                                                                                                       |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`  | 드래그하면 여러 항목에 걸쳐 텍스트를 선택하고, 더블클릭하면 낱말 하나를 선택합니다.                                                                   |
| `'entry'` | 클릭하면 항목을 통째로 선택합니다. Ctrl이나 Cmd를 누르면 항목을 더하거나 빼고, Shift를 누르면 범위를 선택하며, 화살표 키로 항목 사이를 옮겨 다닙니다. |

:::

::: fw flutter

```dart
enum SelectionMode { text, entry }
```

| 값                    | 포인터와 키보드로 선택하는 방식                                                                                                                    |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SelectionMode.text`  | 드래그하면 여러 항목에 걸쳐 텍스트를 선택하고, 두 번 탭하면 낱말 하나를 선택합니다.                                                                |
| `SelectionMode.entry` | 탭하면 항목을 통째로 선택합니다. 플랫폼의 다중 선택 수정자로 항목을 더하거나 빼고, Shift로 범위를 선택하며, 화살표 키로 항목 사이를 옮겨 다닙니다. |

:::

모든 키의 동작은 [선택과 복사](/ko/guide/viewer#selection-and-copy)에 있습니다.

### LinkClick {#linkclick}

::: fw js

```ts
type LinkClick = 'confirm' | 'open' | 'ignore';
```

| 값          | 링크를 클릭하거나 탭했을 때                                      |
| ----------- | ---------------------------------------------------------------- |
| `'confirm'` | 주소를 보여 주는 대화 상자를 열고, 새 탭에서 열기 전에 묻습니다. |
| `'open'`    | 새 탭에서 바로 엽니다.                                           |
| `'ignore'`  | 아무것도 하지 않습니다. 주소는 링크 모양 그대로 보입니다.        |

`http`, `https` 주소만 열고, 열 때는 `noopener`와 `noreferrer`를 붙입니다. 텍스트 모드에서 Ctrl+클릭(macOS에서는 Cmd+클릭)은 값이 `'ignore'`가 아니면 링크를 바로 엽니다.

:::

::: fw flutter

```dart
enum LinkClick { confirm, open, ignore }
```

| 값                  | 링크를 탭했을 때                                          |
| ------------------- | --------------------------------------------------------- |
| `LinkClick.confirm` | 주소를 보여 주는 대화 상자를 열고, 넘기기 전에 묻습니다.  |
| `LinkClick.open`    | 주소를 바로 `onOpenLink`에 넘깁니다.                      |
| `LinkClick.ignore`  | 아무것도 하지 않습니다. 주소는 링크 모양 그대로 보입니다. |

`onOpenLink`에 닿는 것은 `http`, `https` 주소뿐이고, `onOpenLink`가 없으면 아무것도 열리지 않습니다. 플랫폼의 다중 선택 수정자를 누른 채 탭하면 값이 `LinkClick.ignore`가 아닌 한 링크를 바로 엽니다.

:::

## ViewerLabels {#viewerlabels}

레이블은 모두 화면에 보이는 텍스트나 접근성 이름으로 쓰입니다.

| 레이블               | 영어(`EN_LABELS`)                                                  | 한국어(`KO_LABELS`)                                     |
| -------------------- | ------------------------------------------------------------------ | ------------------------------------------------------- |
| `viewer`             | Log viewer                                                         | 로그 뷰어                                               |
| `toolbar`            | Log viewer tools                                                   | 로그 뷰어 도구                                          |
| `follow`             | Follow new logs                                                    | 새 로그 따라가기                                        |
| `clear`              | Clear logs                                                         | 로그 지우기                                             |
| `scrollToTop`        | Scroll to top                                                      | 맨 위로 이동                                            |
| `scrollToBottom`     | Scroll to bottom                                                   | 맨 아래로 이동                                          |
| `wrap`               | Wrap long lines                                                    | 긴 줄 바꾸기                                            |
| `filter`             | Filter                                                             | 필터                                                    |
| `invalidFilter`      | The filter is not a valid pattern                                  | 필터 패턴이 올바르지 않습니다                           |
| `levels`             | Log levels                                                         | 로그 수준                                               |
| `levelAll`           | All levels                                                         | 모든 수준                                               |
| `levelDebug`         | Debug                                                              | 디버그                                                  |
| `levelLog`           | Log                                                                | 로그                                                    |
| `levelInfo`          | Info                                                               | 정보                                                    |
| `levelWarn`          | Warning                                                            | 경고                                                    |
| `levelError`         | Error                                                              | 오류                                                    |
| `levelSome`          | 3 levels                                                           | 수준 3개                                                |
| `theme`              | Theme                                                              | 테마                                                    |
| `themeAuto`          | System                                                             | 시스템                                                  |
| `themeLight`         | Light                                                              | 라이트                                                  |
| `themePaper`         | Paper                                                              | 페이퍼                                                  |
| `themeDark`          | Dark                                                               | 다크                                                    |
| `themeMidnight`      | Midnight                                                           | 미드나이트                                              |
| `themeEmber`         | Ember                                                              | 엠버                                                    |
| `themeMoss`          | Moss                                                               | 모스                                                    |
| `mute`               | Hidden messages                                                    | 숨긴 메시지                                             |
| `muteMessage`        | An entry that matches one of these is kept out of the log.         | 여기에 해당하는 항목은 로그에 나오지 않습니다.          |
| `muteEmpty`          | Nothing is hidden yet.                                             | 아직 숨긴 메시지가 없습니다.                            |
| `muteText`           | Text to hide                                                       | 숨길 텍스트                                             |
| `muteAdd`            | Add                                                                | 추가                                                    |
| `muteRemove`         | Remove                                                             | 삭제                                                    |
| `muteEnabled`        | Apply this rule                                                    | 이 규칙 적용                                            |
| `muteClose`          | Done                                                               | 완료                                                    |
| `muteCount`          | 2 entries hidden                                                   | 항목 2개 숨김                                           |
| `input`              | Command                                                            | 명령                                                    |
| `inputPlaceholder`   | Type a command                                                     | 명령을 입력하세요                                       |
| `newLogs`            | New logs                                                           | 새 로그                                                 |
| `entryList`          | Visible log entries                                                | 화면에 보이는 로그                                      |
| `entryActions`       | Entry actions                                                      | 항목 작업                                               |
| `copyEntry`          | Copy as text                                                       | 텍스트로 복사                                           |
| `copyEntryWithTime`  | Copy with timestamp                                                | 타임스탬프와 함께 복사                                  |
| `copyEntryFormatted` | Copy as formatted text                                             | 서식 있는 텍스트로 복사                                 |
| `copyEntryData`      | Copy as data                                                       | 데이터로 복사                                           |
| `expandAll`          | Expand all                                                         | 모두 펼치기                                             |
| `collapseAll`        | Collapse all                                                       | 모두 접기                                               |
| `expandRepeats`      | Show repeats                                                       | 반복 펼치기                                             |
| `collapseRepeats`    | Hide repeats                                                       | 반복 접기                                               |
| `openLink`           | `Open https://…`                                                   | `링크 열기: https://…`                                  |
| `linkDialogTitle`    | Open this link?                                                    | 이 링크를 열까요?                                       |
| `linkDialogMessage`  | The link opens in a new tab. Check the address before you open it. | 링크는 새 탭에서 열립니다. 열기 전에 주소를 확인하세요. |
| `linkDialogOpen`     | Open link                                                          | 링크 열기                                               |
| `linkDialogCancel`   | Cancel                                                             | 취소                                                    |
| `selectEntries`      | Select whole entries                                               | 항목 단위로 선택                                        |
| `selectedEntries`    | `2 entries selected`                                               | `항목 2개 선택됨`                                       |
| `search`             | Find in log                                                        | 로그에서 찾기                                           |
| `searchPrevious`     | Previous match                                                     | 이전 결과                                               |
| `searchNext`         | Next match                                                         | 다음 결과                                               |
| `searchClose`        | Close search                                                       | 검색 닫기                                               |
| `searchCase`         | Match case                                                         | 대소문자 구분                                           |
| `searchRegex`        | Use regular expression                                             | 정규 표현식 사용                                        |
| `searchInvalid`      | Not a valid regular expression                                     | 올바른 정규 표현식이 아닙니다                           |
| `searchResults`      | `3/12`, `No results`                                               | `3/12`, `결과 없음`                                     |
| `following`          | Following                                                          | 따라가는 중                                             |
| `paused`             | Paused                                                             | 멈춤                                                    |
| `entries`            | `3 entries`, `1 of 3 entries`                                      | `로그 3개`, `로그 3개 중 1개`                           |

`openLink`는 링크 주소를 받아 메뉴 항목의 텍스트를 반환합니다. <Fw js="(url: string) => string" flutter="String Function(String url)" code /> 형태입니다.

`selectedEntries`는 항목 모드에서 선택한 항목 수를 적은 텍스트를 반환합니다. 이 텍스트는 상태 표시줄에 나오고, 키보드로 선택이 바뀌면 스크린 리더가 읽습니다. <Fw js="(count: number, format: (value: number) => string) => string" flutter="String Function(int count, NumberFormatter format)" code /> 형태입니다.

`searchResults`는 <Fw js="(current: number, total: number, format: (value: number) => string) => string" flutter="String Function(int current, int total, NumberFormatter format)" code /> 형태이고, 현재 결과가 없으면 `current`는 0입니다.

`entries`는 <Fw js="(shown: number, total: number, format: (value: number) => string) => string" flutter="String Function(int shown, int total, NumberFormatter format)" code /> 형태입니다. `format`은 숫자를 읽는 사람의 언어에 맞게 적으며, 이것이 `formatNumber` 옵션입니다.

<Fw flutter="ViewerLabels는 일부가 아니라 한 벌이므로, 몇 개만 바꿀 때는 enLabels나 koLabels에 copyWith를 씁니다." />

### labelsFor {#labelsfor}

```
labelsFor(locale)
```

`ko`와 `ko-KR` 같은 태그에는 한국어 레이블을, 그 밖의 언어에는 영어 레이블을 반환합니다. 두 레이블 묶음의 이름은 <Fw js="EN_LABELS와 KO_LABELS" flutter="enLabels와 koLabels" code />입니다.

## 테마와 글꼴 {#themes-and-fonts}

::: fw js

### ThemeMode {#thememode}

```ts
const BUILT_IN_THEMES = ['light', 'paper', 'dark', 'midnight', 'ember', 'moss'] as const;

type BuiltInTheme = (typeof BUILT_IN_THEMES)[number];
type ThemeMode = 'auto' | BuiltInTheme | (string & {});
```

`'auto'`는 운영체제 설정을 따릅니다. 그 밖의 이름은 뷰어의 `data-theme` 속성에 그대로 들어가므로, 직접 CSS로 정의한 팔레트도 쓸 수 있습니다. [테마](/ko/guide/theming#theme-modes)를 참고하세요.

### ThemeChoice {#themechoice}

```ts
interface ThemeChoice {
	name: ThemeMode;
	label?: string;
}
```

테마 메뉴에 넣을 `themes`의 항목입니다. lognal이 제공하는 테마는 내장 레이블을 쓰고, 그 밖의 이름은 이름 자체가 레이블이 됩니다.

### resolveTheme {#resolvetheme}

```ts
resolveTheme(theme: ThemeMode, prefersDark: boolean): string
```

모드가 실제로 쓰는 팔레트를 돌려줍니다. `'auto'`이면 `'light'`나 `'dark'`이고, 그 밖의 이름은 그대로입니다. 뷰어는 `matchMedia('(prefers-color-scheme: dark)')`의 결과를 넘겨 호출합니다.

### readTheme {#readtheme}

```ts
readTheme(element: Element): RenderTheme
```

요소의 `--lognal-*` 사용자 지정 속성에서 렌더링 색을 읽습니다. 설정되지 않은 속성은 `lognal.css`의 어두운 팔레트와 같은 `DEFAULT_RENDER_THEME`의 값을 씁니다.

### readFont {#readfont}

```ts
readFont(element: Element, overrides: Partial<FontSettings>): FontSettings
```

`--lognal-font-family`, `--lognal-font-size`, `--lognal-font-weight`, `--lognal-line-height` 속성에서 글꼴을 읽고, 그 위에 `overrides`를 적용합니다. 크기는 `px`, `rem`, `em` 단위로 쓸 수 있습니다. 줄 높이는 크기의 배수인 숫자나 `em` 값, 백분율, 크기로 나눌 `px`·`rem` 단위의 길이 가운데 하나로 쓸 수 있습니다. 값이 없거나 올바르지 않으면 `DEFAULT_FONT`의 값을 씁니다.

### DEFAULT_FONT {#default-font}

| 필드         | 값                                                                                                                            |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `family`     | `ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "D2Coding", "Noto Sans Mono CJK KR", "Liberation Mono", monospace` |
| `size`       | `13`                                                                                                                          |
| `weight`     | `400`                                                                                                                         |
| `lineHeight` | `1.6`                                                                                                                         |

:::

::: fw flutter

### LognalTheme {#lognaltheme}

```dart
class LognalTheme {
  const LognalTheme({
    required String name,
    required Brightness brightness,
    required RenderTheme renderer,
    required ChromeTheme chrome,
  });
}
```

팔레트를 두 부분으로 나눠 담습니다. `renderer`는 로그를 그리는 색이고, JavaScript 패키지가 CSS에서 읽어 오는 [`RenderTheme`](/ko/reference/layout#rendertheme)과 같습니다. `chrome`은 그 둘레의 도구 모음, 상태 표시줄, 스크롤바, 팝업입니다. `brightness`는 키보드나 텍스트 선택 손잡이처럼 플랫폼이 그 위에 그리는 것을 정합니다.

### ChromeTheme {#chrometheme}

| 필드                                         | 칠하는 곳                                                          |
| -------------------------------------------- | ------------------------------------------------------------------ |
| `background`                                 | 뷰어 뒤입니다.                                                     |
| `foreground`, `muted`                        | 둘레의 본문과 보조 텍스트입니다.                                   |
| `accent`, `onAccent`                         | 강조색과 그 위의 텍스트입니다.                                     |
| `border`, `surface`                          | 둘레와 로그 사이의 선, 도구 모음과 상태 표시줄의 배경입니다.       |
| `controlHover`, `controlActive`, `focusRing` | 포인터가 올라간 컨트롤, 켜진 컨트롤, 키보드가 남기는 윤곽선입니다. |
| `scrollbarThumb`, `scrollbarThumbHover`      | 스크롤바의 손잡이입니다.                                           |
| `shadow`                                     | 메뉴나 대화 상자 아래의 그림자입니다.                              |

### buildTheme {#buildtheme}

```dart
LognalTheme buildTheme({
  required String name,
  required Brightness brightness,
  required Color background,
  required Color foreground,
  required Color muted,
  required Color accent,
  required Color border,
  required Color surface,
  required Color selection,
  required Color entrySelection,
  required Color controlActive,
  required List<Color> ansi,
})
```

몇 가지 색과 16색 ANSI 램프로 팔레트 한 벌을 만듭니다. `light`와 `dark` 다음의 네 팔레트를 만든 방식이 이것입니다. 로그가 쓰는 토큰은 모두 램프에서 따라 나오므로, 직접 만드는 팔레트도 이 인자만 있으면 됩니다. [테마](/ko/guide/theming#theme-modes)를 참고하세요.

### 팔레트 {#palettes}

`lightTheme`, `paperTheme`, `darkTheme`, `midnightTheme`, `emberTheme`, `mossTheme`가 이 패키지가 제공하는 팔레트입니다. `builtInThemes`는 메뉴에 나오는 순서대로 담은 리스트, `builtInThemeNames`는 그 이름, `builtInTheme(name)`은 하나를 반환하거나 `null`을 반환합니다.

```dart
LognalTheme resolveTheme(String name, Brightness platform)
```

이름이 실제로 가리키는 팔레트입니다. `auto`는 `platform`을 따르고, 그 밖의 이름은 찾아보며, 해당하는 팔레트가 없는 이름도 플랫폼 설정으로 물러납니다. 이 마지막 동작 덕분에 직접 만든 팔레트는 `themeResolver`로 넣습니다.

### FontSettings {#fontsettings}

| 필드               | 타입           | 기본값            | 설명                                                                          |
| ------------------ | -------------- | ----------------- | ----------------------------------------------------------------------------- |
| `family`           | `String?`      | 플랫폼 글꼴       | 글꼴 이름입니다. `null`이면 플랫폼의 고정폭 글꼴을 씁니다.                    |
| `fallbackFamilies` | `List<String>` | `[]`              | 고른 글꼴에 없는 문자를 대신 그릴 글꼴입니다. 한글이 있는 글꼴 같은 것입니다. |
| `size`             | `double`       | `13`              | 논리 픽셀 단위의 글꼴 크기입니다.                                             |
| `weight`           | `FontWeight`   | `FontWeight.w400` | 본문의 굵기입니다.                                                            |
| `lineHeight`       | `double`       | `1.6`             | 글꼴 크기에 대한 행 높이의 배수입니다.                                        |

`family`가 없으면 뷰어가 플랫폼의 고정폭 글꼴을 고릅니다. 애플 플랫폼은 `SF Mono`, 안드로이드는 `Roboto Mono`, 윈도우는 `Consolas`, 리눅스는 `DejaVu Sans Mono`입니다. 웹용 Flutter에는 물러설 시스템 글꼴이 없으므로, 웹 애플리케이션은 고정폭 글꼴을 번들해 여기에 이름을 적어야 합니다. [글꼴](/ko/guide/theming#fonts)을 참고하세요.

:::

## 타임스탬프 {#timestamps}

### TimestampFormat {#timestampformat}

::: fw js

```ts
type TimestampFormat = 'time' | 'datetime' | 'iso' | ((time: number) => string);
```

:::

::: fw flutter

```dart
enum TimestampFormat { time, datetime, iso }
```

직접 정한 형식은 이 enum의 값이 아니라 `formatTimestamp` 옵션입니다. Dart의 enum은 함수를 담지 않습니다.

:::

### formatTimestamp {#formattimestamp}

```
formatTimestamp(time, format)
```

시각을 고른 형식으로 적습니다. <Fw js="밀리초 단위의 에포크 시각" flutter="DateTime" />을 받고, `format`의 기본값은 <Fw js="'time'" flutter="TimestampFormat.time" code />입니다.

| 형식                                                           | 예                         |
| -------------------------------------------------------------- | -------------------------- |
| <Fw js="'time'" flutter="TimestampFormat.time" code />         | `14:03:09.120`             |
| <Fw js="'datetime'" flutter="TimestampFormat.datetime" code /> | `2026-09-13 14:03:09.120`  |
| <Fw js="'iso'" flutter="TimestampFormat.iso" code />           | `2026-09-13T05:03:09.120Z` |

앞의 둘은 현지 시각을, 마지막은 UTC를 씁니다.

::: fw js

## React 컴포넌트 {#react-component}

```tsx
import { LogViewer, type LogViewerProps } from 'lognal/react';
```

`LogViewerProps`는 `LogViewerOptions`에 아래 prop을 더한 타입입니다. 컴포넌트는 ref를 `LogViewer` 인스턴스로 전달합니다. prop 변경이 적용되는 방식은 [프레임워크에서](/ko/guide/framework)를 참고하세요.

| Prop                | 타입                                  | 설명                                                                 |
| ------------------- | ------------------------------------- | -------------------------------------------------------------------- |
| `className`         | `string`                              | 컨테이너의 클래스입니다.                                             |
| `style`             | `CSSProperties`                       | 컨테이너의 스타일입니다. `height: 100%` 위에 적용합니다.             |
| `hookConsole`       | `boolean \| HookConsoleOptions`       | 컴포넌트가 마운트되어 있는 동안 전역 `console`을 뷰어에 기록합니다.  |
| `onReady`           | `(viewer: LogViewer \| null) => void` | 뷰어가 생기면 뷰어를, 뷰어를 정리한 뒤에는 `null`을 넘겨 호출합니다. |
| `onFollowChange`    | `(following: boolean) => void`        | `follow` 이벤트입니다.                                               |
| `onFilterChange`    | `(filter: LogFilter \| null) => void` | `filter` 이벤트입니다.                                               |
| `onSelectionChange` | `(text: string) => void`              | `selection` 이벤트입니다.                                            |

:::

::: fw flutter

## 위젯의 인자 {#widget-arguments}

| 인자         | 타입                   | 기본값               | 설명                                                            |
| ------------ | ---------------------- | -------------------- | --------------------------------------------------------------- |
| `store`      | `LogStore?`            | 새 스토어            | 보여 줄 스토어입니다. 위젯이 그 위에 컨트롤러를 만듭니다.       |
| `controller` | `LogViewerController?` | —                    | 직접 들고 있는 컨트롤러입니다. `store`와 함께 넘길 수 없습니다. |
| `options`    | `LogViewerOptions`     | `LogViewerOptions()` | 옵션입니다. 컨트롤러를 넘겼든 아니든 빌드할 때마다 적용합니다.  |
| `focusNode`  | `FocusNode?`           | 자체 노드            | 로그 영역의 포커스 노드입니다.                                  |
| `autofocus`  | `bool`                 | `false`              | 로그 영역이 나타날 때 포커스를 받을지 정합니다.                 |

위젯이 만든 컨트롤러는 위젯과 함께 정리됩니다. 넘긴 컨트롤러는 넘긴 쪽에서 정리합니다. 어느 쪽을 쓸지는 [프레임워크에서](/ko/guide/framework)를 참고하세요.

:::
