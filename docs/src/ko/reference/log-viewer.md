---
order: 1
description: LogViewer 클래스와 옵션, 메서드, 이벤트, 레이블, 테마와 글꼴을 읽는 함수, formatTimestamp, React LogViewer 컴포넌트의 레퍼런스입니다.
---

# LogViewer

```ts
import { LogViewer } from 'lognal';

const viewer = new LogViewer(container, options);
```

도구 모음, 렌더러가 그리는 로그, 선택적인 입력 줄, 상태 표시줄로 이루어진 로그 뷰어입니다. 뷰어는 스크롤, 선택, 키보드, 접근성을 처리하고 프레임마다 렌더러에 그리기를 맡깁니다. 레이아웃과 테마를 위해 `lognal/style.css`를 한 번 가져오세요.

## 생성자 {#constructor}

```ts
new LogViewer(container: HTMLElement, options?: LogViewerOptions)
```

뷰어를 만들고 루트 요소를 `container`에 추가합니다.

## 속성 {#properties}

| 속성          | 타입             | 설명                                                                                         |
| ------------- | ---------------- | -------------------------------------------------------------------------------------------- |
| `store`       | `LogStore`       | 뷰어가 보여 주는 스토어입니다. 읽기 전용입니다.                                              |
| `layout`      | `LogLayout`      | 뷰어의 레이아웃입니다. 읽기 전용입니다.                                                      |
| `element`     | `HTMLDivElement` | `lognal` 클래스가 붙은 루트 요소입니다. 읽기 전용입니다.                                     |
| `console`     | `LognalConsole`  | 스토어에 쓰는, 콘솔 메서드를 갖춘 객체입니다. 처음 쓸 때 만들고 이후에는 같은 객체를 씁니다. |
| `isFollowing` | `boolean`        | 새 항목을 따라가는 중인지 나타냅니다.                                                        |

## 메서드 {#methods}

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

## 이벤트 {#events}

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

## LogViewerOptions {#logvieweroptions}

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

## CoreOptions {#coreoptions}

`CoreOptions`는 `LogStoreOptions`, `LayoutOptions`, 필터를 합친 타입입니다.

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

## ToolbarOptions {#toolbaroptions}

모든 컨트롤의 기본값은 `true`입니다.

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

## InputOptions {#inputoptions}

| 옵션          | 타입                                              | 기본값                    | 설명                                                                                                                                       |
| ------------- | ------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `onSubmit`    | `(command: string, viewer: LogViewer) => unknown` | 필수                      | 명령마다 호출합니다. 반환한 값이나 반환한 프로미스가 이행한 값을 응답으로 출력합니다. 아무것도 출력하지 않으려면 `undefined`를 반환합니다. |
| `prompt`      | `string`                                          | `'>'`                     | 입력 앞에 보이는 프롬프트입니다.                                                                                                           |
| `placeholder` | `string`                                          | `labels.inputPlaceholder` | 입력란의 자리 표시 텍스트입니다.                                                                                                           |
| `echo`        | `boolean`                                         | `true`                    | 명령을 실행하기 전에 로그에 추가할지 정합니다.                                                                                             |
| `historySize` | `number`                                          | `100`                     | 화살표 키로 오갈 수 있는 이전 명령 수입니다.                                                                                               |

## EntryMenuOptions {#entrymenuoptions}

| 옵션    | 타입                                                      | 기본값 | 설명                                                                                                                                                                                   |
| ------- | --------------------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `copy`  | `boolean`                                                 | `true` | 메뉴를 복사 항목으로 시작할지 정합니다. 복사 항목은 **텍스트로 복사**, **타임스탬프와 함께 복사**, **서식 있는 텍스트로 복사**이고, 값이 있는 항목에는 **데이터로 복사**가 더해집니다. |
| `items` | `(entry: LogEntry, viewer: LogViewer) => EntryMenuItem[]` | 없음   | 메뉴가 열릴 때마다 호출합니다. 반환한 메뉴 항목은 구분선 아래, 내장 항목 다음에 나옵니다.                                                                                              |

`copy: false`이면서 `items`가 없으면 메뉴가 꺼집니다. 메뉴 항목이 하나도 없는 메뉴는 열리지 않습니다.

### EntryMenuItem {#entrymenuitem}

| 필드       | 타입                                           | 설명                                                 |
| ---------- | ---------------------------------------------- | ---------------------------------------------------- |
| `label`    | `string`                                       | 메뉴 항목의 텍스트입니다.                            |
| `onSelect` | `(entry: LogEntry, viewer: LogViewer) => void` | 고르면 메뉴를 연 로그 항목을 인자로 받아 호출합니다. |

### EntryTextOptions {#entrytextoptions}

| 옵션        | 타입              | 기본값   | 설명                                                                                                                                      |
| ----------- | ----------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `format`    | `EntryTextFormat` | `'text'` | 항목을 적는 형식입니다.                                                                                                                   |
| `timestamp` | `boolean`         | `false`  | 텍스트 앞에 항목의 시각을 붙일지 정합니다. 시각은 `timestamps`의 형식을 따르고, 꺼져 있으면 `'time'`을 씁니다. `'data'`에서는 무시합니다. |

| `EntryTextFormat` | 결과                                                                                                                                                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`          | 서식 없는 텍스트입니다. 값은 모두 한 줄에 적습니다.                                                                                                                                                                                                                                   |
| `'formatted'`     | 한 줄에 다 들어가지 않는 값을 들여쓴 여러 줄로 나눕니다. `copyEntry`는 테마 색을 입힌 HTML도 함께 복사합니다.                                                                                                                                                                         |
| `'data'`          | 값을 JSON으로 적습니다. 값이 하나면 그 값, 여러 개면 값의 배열, 값이 없으면 항목의 텍스트입니다. `undefined`는 `null`, Set은 배열, 텍스트 키를 쓰는 Map은 객체, 오류는 `name`, `message`, `stack`이 든 객체가 되고, `10n`이나 `Symbol(token)`처럼 JSON에 없는 타입은 텍스트가 됩니다. |

### SearchOptions {#searchoptions}

| 옵션            | 타입      | 기본값  | 설명                                                           |
| --------------- | --------- | ------- | -------------------------------------------------------------- |
| `caseSensitive` | `boolean` | `false` | 대소문자가 맞아야 하는지 정합니다.                             |
| `regex`         | `boolean` | `false` | 텍스트를 글자 그대로가 아니라 정규 표현식으로 읽을지 정합니다. |

### SelectionMode {#selectionmode}

```ts
type SelectionMode = 'text' | 'entry';
```

| 값        | 포인터와 키보드로 선택하는 방식                                                                                                                       |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'text'`  | 드래그하면 여러 항목에 걸쳐 텍스트를 선택하고, 더블클릭하면 낱말 하나를 선택합니다.                                                                   |
| `'entry'` | 클릭하면 항목을 통째로 선택합니다. Ctrl이나 Cmd를 누르면 항목을 더하거나 빼고, Shift를 누르면 범위를 선택하며, 화살표 키로 항목 사이를 옮겨 다닙니다. |

모든 키의 동작은 [선택과 복사](/ko/guide/viewer#selection-and-copy)에 있습니다.

### LinkClick {#linkclick}

```ts
type LinkClick = 'confirm' | 'open' | 'ignore';
```

| 값          | 링크를 클릭하거나 탭했을 때                                      |
| ----------- | ---------------------------------------------------------------- |
| `'confirm'` | 주소를 보여 주는 대화 상자를 열고, 새 탭에서 열기 전에 묻습니다. |
| `'open'`    | 새 탭에서 바로 엽니다.                                           |
| `'ignore'`  | 아무것도 하지 않습니다. 주소는 링크 모양 그대로 보입니다.        |

`http`, `https` 주소만 열고, 열 때는 `noopener`와 `noreferrer`를 붙입니다. 텍스트 모드에서 Ctrl+클릭(macOS에서는 Cmd+클릭)은 값이 `'ignore'`가 아니면 링크를 바로 엽니다.

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

`openLink`는 링크 주소를 받는 `(url: string) => string` 함수입니다.

`selectedEntries`는 `(count: number, format: (value: number) => string) => string` 함수이고, 항목 모드에서 선택한 항목 수를 적은 텍스트를 반환합니다. 이 텍스트는 상태 표시줄에 나오고, 키보드로 선택이 바뀌면 스크린 리더가 읽습니다.

`searchResults`는 `(current: number, total: number, format: (value: number) => string) => string` 함수이고, 현재 결과가 없으면 `current`는 0입니다.

`entries`는 `(shown: number, total: number, format: (value: number) => string) => string` 형태의 함수입니다. `format`은 숫자를 로케일에 맞게 서식화합니다.

### labelsFor {#labelsfor}

```ts
labelsFor(locale: string | undefined): ViewerLabels
```

`ko`와 `ko-KR` 같은 태그에는 `KO_LABELS`를, 그 밖의 언어에는 `EN_LABELS`를 반환합니다.

## 테마와 글꼴 {#themes-and-fonts}

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

## 타임스탬프 {#timestamps}

### TimestampFormat {#timestampformat}

```ts
type TimestampFormat = 'time' | 'datetime' | 'iso' | ((time: number) => string);
```

### formatTimestamp {#formattimestamp}

```ts
formatTimestamp(time: number, format?: TimestampFormat): string
```

밀리초 단위의 에포크 시각을 서식화합니다. `format`의 기본값은 `'time'`입니다.

| 형식         | 예                         |
| ------------ | -------------------------- |
| `'time'`     | `14:03:09.120`             |
| `'datetime'` | `2026-09-13 14:03:09.120`  |
| `'iso'`      | `2026-09-13T05:03:09.120Z` |

`'time'`과 `'datetime'`은 현지 시각을, `'iso'`는 UTC를 씁니다.

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
