---
order: 5
description: LogLayout, 필터 함수, 줄과 행 타입, 그리고 lognal 렌더러를 직접 만들 때 쓰는 Renderer 인터페이스의 레퍼런스입니다.
---

# 레이아웃과 렌더러

뷰어는 항목을 화면에 보이기 전에 두 단계를 거칩니다. `LogLayout`이 보여 줄 항목을 정해서 행으로 나누고, `Renderer`가 그 행을 그립니다. 두 부분 모두 바꿔 끼울 수 있으며, 렌더러를 직접 만드는 것처럼 그 위에 무언가를 만들 때만 이 페이지가 필요합니다.

## LogLayout {#loglayout}

```ts
new LogLayout(store: LogStore, options?: Partial<LayoutOptions>)
```

스토어의 항목을 주어진 너비의 뷰어에 맞는 행으로 바꿉니다. 레이아웃은 필터와 접힌 그룹을 반영해 보여 줄 항목을 정하고, 항목을 줄과 행으로 나누고, 어떤 값이 펼쳐져 있는지 관리합니다. 스토어의 변경을 듣고 있다가 `sync`를 호출할 때 밀린 작업을 처리하므로, 두 프레임 사이에 메시지가 몇 개 들어오든 갱신은 한 번입니다.

뷰어는 자기 레이아웃을 만들고 `viewer.layout`으로 공개합니다.

### LayoutOptions {#layoutoptions}

`DEFAULT_LAYOUT_OPTIONS`에 기본값이 들어 있습니다.

| 옵션             | 타입             | 기본값   | 설명                                                                                 |
| ---------------- | ---------------- | -------- | ------------------------------------------------------------------------------------ |
| `wrap`           | `WrapMode`       | `'word'` | 뷰어보다 긴 줄을 처리하는 방식입니다.                                                |
| `tabSize`        | `number`         | `8`      | 탭 위치 사이의 칸 수입니다.                                                          |
| `ambiguousWidth` | `AmbiguousWidth` | `1`      | 동아시아 모호 폭 문자가 차지하는 칸 수입니다.                                        |
| `maxClusters`    | `number`         | `10000`  | 한 줄에 남기는 최대 클러스터 수입니다. 나머지는 `…`로 대신합니다.                    |
| `links`          | `boolean`        | `true`   | 텍스트 안의 `http`, `https` 주소를 `open-link` 동작이 붙은 조각으로 만들지 정합니다. |

```ts
type WrapMode = 'word' | 'char' | 'none';
```

### 속성 {#properties}

`rowCount`와 `visibleCount`를 읽기 전에 `sync()`를 호출하세요.

| 속성               | 타입      | 설명                                                                                                  |
| ------------------ | --------- | ----------------------------------------------------------------------------------------------------- |
| `rowCount`         | `number`  | 보이는 항목 전체의 행 수입니다.                                                                       |
| `visibleCount`     | `number`  | 보이는 항목 수입니다.                                                                                 |
| `maxCells`         | `number`  | 지금까지 본 가장 넓은 행의 칸 수로, 들여쓰기를 포함합니다.                                            |
| `isDirty`          | `boolean` | 마지막 `sync` 이후 스토어가 바뀌었는지 나타냅니다.                                                    |
| `pendingCount`     | `number`  | 행 수가 아직 추정값인 보이는 항목의 수입니다.                                                         |
| `mutedCount`       | `number`  | 숨김 규칙이 가리는 항목 수입니다.                                                                     |
| `positionsVersion` | `number`  | 이미 보이던 항목의 첫 행이 움직였을 수 있을 때마다 커집니다. 끝에 항목을 추가할 때는 바뀌지 않습니다. |

### 메서드 {#methods}

| 메서드                                                                          | 반환값                                          | 설명                                                                                                                                                                               |
| ------------------------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `getOptions()`                                                                  | `Readonly<LayoutOptions>`                       | 옵션을 반환합니다.                                                                                                                                                                 |
| `setOptions(options: Partial<LayoutOptions>)`                                   | `void`                                          | 옵션을 바꿉니다.                                                                                                                                                                   |
| `setColumns(columns: number)`                                                   | `void`                                          | 행을 나눌 열 수를 정합니다.                                                                                                                                                        |
| `setFilter(filter: LogFilter \| null)`                                          | `CompiledFilter`                                | 보여 줄 항목을 정합니다. 결과에 컴파일되지 않는 패턴이 표시됩니다.                                                                                                                 |
| `getFilter()`                                                                   | `CompiledFilter`                                | 사용 중인 컴파일된 필터를 반환합니다.                                                                                                                                              |
| `sync(budget?: number)`                                                         | `boolean`                                       | 밀린 스토어 변경을 적용합니다. 바뀐 것이 있었는지 반환합니다. [추정 행 수](#estimated-row-counts)를 참고하세요.                                                                    |
| `measureAround(entryId: number \| null, rowsBefore: number, rowsAfter: number)` | `boolean`                                       | 한 항목 주변의 항목을 정확히 배치합니다. `null`이면 마지막 항목 주변을 배치합니다. 행 수가 바뀌었는지 반환합니다.                                                                  |
| `measurePending(budget: number, entryId?: number \| null)`                      | `boolean`                                       | 추정값이 남은 항목을 최대 `budget`개까지 정확히 배치합니다. 지정한 항목에 가까운 것부터 처리하고, 행 수가 바뀌었는지 반환합니다.                                                   |
| `locateRow(row: number)`                                                        | `{ entry: LogEntry; entryRow: number } \| null` | 행이 속한 항목과, 그 항목 안에서 몇 번째 행인지 반환합니다.                                                                                                                        |
| `rowsOf(entryId: number)`                                                       | `number`                                        | 보이는 항목의 행 수를 반환합니다. 보이지 않으면 0입니다.                                                                                                                           |
| `getRows(start: number, count: number)`                                         | `VisualRow[]`                                   | `start`번째 행부터 최대 `count`개의 행을 반환합니다.                                                                                                                               |
| `entryAt(index: number)`                                                        | `LogEntry \| undefined`                         | 보이는 위치에 있는 항목을 반환합니다. 0이 보이는 항목 가운데 가장 오래된 항목입니다.                                                                                               |
| `indexOf(entryId: number)`                                                      | `number`                                        | 항목의 보이는 위치를 반환합니다. 없으면 -1입니다.                                                                                                                                  |
| `rowOfEntry(entryId: number)`                                                   | `number`                                        | 항목의 첫 행을 반환합니다. 보이지 않으면 -1입니다.                                                                                                                                 |
| `isExpanded(entry: LogEntry, path: string)`                                     | `boolean`                                       | 항목의 경로에 있는 값이 펼쳐져 있는지 반환합니다.                                                                                                                                  |
| `setExpanded(entry: LogEntry, path: string, expanded: boolean)`                 | `void`                                          | 항목의 경로에 있는 값을 펼치거나 접습니다.                                                                                                                                         |
| `expandAll(entryId: number)`                                                    | `void`                                          | 항목의 값과 그 안의 값을 캡처된 만큼 모두 펼칩니다.                                                                                                                                |
| `collapseAll(entryId: number)`                                                  | `void`                                          | 따로 로그를 남긴 오류까지 포함해 항목의 값을 모두 접습니다.                                                                                                                        |
| `hasExpandableValues(entry: LogEntry)`                                          | `boolean`                                       | 항목에 펼칠 수 있는 값이 있는지 반환합니다.                                                                                                                                        |
| `linksOf(entryId: number)`                                                      | `string[]`                                      | 펼친 값의 행까지, 화면에 보이는 대로 항목의 링크 주소를 순서대로 반환합니다. 같은 주소는 한 번만 넣습니다.                                                                         |
| `indexFrom(entryId: number)`                                                    | `number`                                        | id가 `entryId` 이상인 첫 보이는 항목의 보이는 위치를 반환합니다.                                                                                                                   |
| `findInEntry(entry: LogEntry, pattern: RegExp, limit?: number)`                 | `TextMatch[]`                                   | 전역 패턴이 항목의 보이는 줄에서 일치하는 곳을 유니코드 정규화 형식 C로 비교해 찾습니다. `TextMatch`는 `{ entryId, line, from, to }`이고, `from`과 `to`는 논리 줄의 칸 위치입니다. |
| `locatePosition(position: TextPosition)`                                        | `{ entryRow: number; indent: number } \| null`  | 텍스트 위치를 보여 주는 항목 안의 행과 그 행의 들여쓰기를 반환합니다.                                                                                                              |
| `runAction(entryId: number, action: LineAction)`                                | `void`                                          | 클릭한 조각의 동작을 실행합니다. 링크를 여는 일은 뷰어가 맡습니다.                                                                                                                 |
| `positionAt(row: number, column: number)`                                       | `TextPosition \| null`                          | 콘텐츠 영역의 행과 열에 있는 텍스트 위치를 반환합니다.                                                                                                                             |
| `wordAt(position: TextPosition)`                                                | `[TextPosition, TextPosition] \| null`          | 위치에 있는 낱말의 시작과 끝을 반환합니다.                                                                                                                                         |
| `getText(from: TextPosition, to: TextPosition)`                                 | `string`                                        | 두 위치 사이의 텍스트를 논리 줄마다 한 줄씩 반환합니다.                                                                                                                            |
| `getAllText()`                                                                  | `string`                                        | 보이는 모든 항목의 텍스트를 반환합니다.                                                                                                                                            |
| `dispose()`                                                                     | `void`                                          | 스토어의 변경을 더 듣지 않습니다.                                                                                                                                                  |

### 추정 행 수 {#estimated-row-counts}

큰 로그를 새 폭에 맞춰 배치하는 시간은 로그 크기에 비례합니다. `sync(budget)`은 최대 `budget`개의 항목만 정확히 배치하고, 나머지에는 추정값을 줍니다. 추정값은 이전 행 수를 폭이 바뀐 비율만큼 조정한 값이고, 항목의 줄 수보다 작아지지 않습니다. 기본 예산에는 한도가 없으므로, 레이아웃을 따로 쓰면 항상 정확합니다.

뷰어는 예산을 정해 `sync`를 호출하고, 그리기 전에 `measureAround`로 화면에 보이는 항목을 배치한 다음, `pendingCount`가 0이 될 때까지 프레임 사이에 `measurePending`을 짧게 나눠 호출합니다. 프레임마다 `positionsVersion`을 비교해서 화면 맨 위의 항목을 제자리에 둡니다.

```ts
layout.setColumns(60);
layout.sync(500);
layout.measureAround(topEntryId, 50, 100);

while (layout.pendingCount > 0) {
	layout.measurePending(200, topEntryId);
}
```

값 경로는 항목 안 파트의 인덱스 뒤에 자식의 인덱스를 점으로 이어 붙인 문자열입니다. `'1'`은 항목의 두 번째 파트이고, `'1.0'`은 그 값의 첫 번째 자식입니다.

`setExpanded`는 뷰어에 다시 그리라고 요청하지 않습니다. `viewer.layout`에서 호출하면 다음 항목이 들어오거나 스크롤할 때처럼 뷰어가 다음에 프레임을 그릴 때 변경이 보입니다.

```ts
// 보이는 항목을 모두 텍스트로 복사합니다.
viewer.layout.sync();
await navigator.clipboard.writeText(viewer.layout.getAllText());
```

## 필터 {#filters}

### LogFilter {#logfilter}

| 필드            | 타입                  | 설명                                                                                          |
| --------------- | --------------------- | --------------------------------------------------------------------------------------------- |
| `text`          | `string`              | 항목에 들어 있어야 하는 텍스트입니다. 비어 있으면 모든 항목이 통과합니다.                     |
| `regex`         | `boolean`             | `text`를 정규 표현식으로 볼지 정합니다.                                                       |
| `caseSensitive` | `boolean`             | 대소문자를 구분할지 정합니다.                                                                 |
| `minLevel`      | `LogLevel`            | 보여 줄 가장 낮은 수준입니다.                                                                 |
| `levels`        | `readonly LogLevel[]` | 보여 줄 수준입니다. 이 값이 있으면 `minLevel`은 무시합니다.                                   |
| `mute`          | `readonly MuteRule[]` | 필터의 나머지 조건과 상관없이 항목을 숨기는 규칙입니다. [`MuteRule`](#muterule)을 참고하세요. |

### MuteRule {#muterule}

```ts
interface MuteRule {
	text: string;
	regex?: boolean;
	caseSensitive?: boolean;
	enabled?: boolean;
}
```

텍스트가 걸리는 항목을 숨기는 규칙입니다. `regex`를 켜지 않으면 `text`는 일반 텍스트이고, `caseSensitive`를 켜지 않으면 대소문자를 가리지 않으며, `enabled: false`이면 규칙을 지우지 않은 채 적용만 멈춥니다. 비어 있거나 꺼져 있거나 올바른 패턴이 아닌 규칙은 아무것도 숨기지 않고, 입력 줄에 친 명령과 뷰어가 남긴 안내는 절대 숨기지 않습니다. [숨긴 메시지](/ko/guide/viewer#hidden-messages)를 참고하세요.

### compileFilter {#compilefilter}

```ts
compileFilter(filter: LogFilter | null | undefined): CompiledFilter
```

필터를 항목 검사 함수로 바꿉니다.

| `CompiledFilter` 필드 | 타입                                     | 설명                                                                       |
| --------------------- | ---------------------------------------- | -------------------------------------------------------------------------- |
| `matches`             | `((entry: LogEntry) => boolean) \| null` | 항목을 검사합니다. 모든 항목이 통과하는 필터이면 `null`입니다.             |
| `muted`               | `((entry: LogEntry) => boolean) \| null` | 항목이 숨김 규칙에 걸리는지 검사합니다. 적용할 규칙이 없으면 `null`입니다. |
| `pattern`             | `RegExp \| null`                         | 강조할 부분을 찾는 정규 표현식입니다. 텍스트 필터가 없으면 `null`입니다.   |
| `error`               | `string \| null`                         | `text`가 올바른 정규 표현식이 아닐 때의 오류 메시지입니다.                 |

```ts
import { compileFilter } from 'lognal';

const filter = compileFilter({ text: 'timeout', minLevel: 'warn' });
const matching = viewer.store.toArray().filter((entry) => filter.matches?.(entry) ?? true);
```

### entrySearchText {#entrysearchtext}

```ts
entrySearchText(entry: LogEntry): string
```

필터가 보는 항목의 텍스트를 반환합니다. 텍스트 파트와 값마다의 한 줄 미리 보기를 이어 붙여 유니코드 정규화 형식 C로 바꾸고, 20,000자에서 자릅니다.

## 행 {#rows}

### VisualRow {#visualrow}

화면의 한 행입니다.

| 필드        | 타입       | 설명                                                                     |
| ----------- | ---------- | ------------------------------------------------------------------------ |
| `entry`     | `LogEntry` | 행이 속한 항목입니다.                                                    |
| `line`      | `number`   | 항목 안에서 논리 줄의 인덱스입니다.                                      |
| `lineRow`   | `number`   | 논리 줄 안에서 행의 인덱스입니다.                                        |
| `entryRow`  | `number`   | 항목 안에서 행의 인덱스입니다.                                           |
| `first`     | `boolean`  | 항목의 첫 행인지 나타냅니다.                                             |
| `last`      | `boolean`  | 항목의 마지막 행인지 나타냅니다.                                         |
| `indent`    | `number`   | 첫 런 앞의 들여쓰기 칸 수입니다.                                         |
| `startCell` | `number`   | 들여쓰기를 뺀, 논리 줄 안에서 행의 첫 클러스터가 시작하는 칸 위치입니다. |
| `cells`     | `number`   | 들여쓰기를 뺀 행 내용의 칸 수입니다.                                     |
| `runs`      | `RowRun[]` | 행을 이루는 런입니다.                                                    |

항목에는 텍스트의 줄마다 논리 줄이 하나씩 있고, 펼친 값의 행마다 논리 줄이 하나씩 더 있습니다.

### RowRun {#rowrun}

한 행에서 스타일이 같은 클러스터가 이어진 구간입니다.

| 필드       | 타입         | 설명                                                                                   |
| ---------- | ------------ | -------------------------------------------------------------------------------------- |
| `column`   | `number`     | 콘텐츠 영역의 시작부터 센, 런이 시작하는 열입니다. 들여쓰기를 포함합니다.              |
| `cells`    | `number`     | 칸 수입니다.                                                                           |
| `text`     | `string`     | 런의 텍스트입니다.                                                                     |
| `simple`   | `boolean`    | 한 번에 그릴 수 있는 순수 ASCII 런인지 나타냅니다.                                     |
| `clusters` | `string[]`   | 순수 ASCII가 아닌 런의 클러스터입니다. 순수 ASCII 런에서는 빈 배열입니다.              |
| `widths`   | `number[]`   | `clusters`에 있는 클러스터마다의 폭입니다.                                             |
| `token`    | `StyleToken` | 의미 색이 있으면 그 값입니다.                                                          |
| `style`    | `TextStyle`  | 직접 지정한 스타일이 있으면 그 값입니다.                                               |
| `action`   | `LineAction` | 런을 클릭했을 때의 동작이 있으면 그 값입니다.                                          |
| `icon`     | `'expander'` | 값이나 그룹을 펼치는 삼각형일 때 설정합니다. 이 런은 텍스트가 없고 두 칸을 차지합니다. |
| `expanded` | `boolean`    | 펼침 삼각형이 열려 있는지 나타냅니다.                                                  |

### TextPosition {#textposition}

```ts
interface TextPosition {
	entryId: number;
	/** 항목 안에서 논리 줄의 인덱스입니다. */
	line: number;
	/** 들여쓰기를 뺀, 논리 줄 안의 칸 위치입니다. */
	cell: number;
}
```

항목 텍스트 안의 위치입니다. 행이 다르게 나뉘어도 바뀌지 않습니다.

### LineAction {#lineaction}

```ts
type LineAction = { type: 'toggle-value'; path: string } | { type: 'toggle-group' } | { type: 'toggle-repeat' } | { type: 'open-link'; url: string };
```

조각을 클릭했을 때의 동작입니다. `toggle-value`는 `path`에 있는 값을 펼치거나 접고, `toggle-group`은 항목이 시작하는 그룹을 접거나 펼치며, `toggle-repeat`은 반복 묶음의 첫 항목이 대신하는 메시지를 보여 주거나 숨깁니다. `open-link`는 `url`을 여는 동작이며, 뷰어가 `linkClick` 옵션에 따라 처리합니다.

### findLinks {#findlinks}

```ts
findLinks(text: string): TextLink[]
```

`links`가 켜져 있을 때 레이아웃이 찾는 방식 그대로 문자열에서 `http`, `https` 주소를 찾습니다. `TextLink`는 `{ start, end, url }`입니다. `start`와 `end`는 UTF-16 코드 단위로 센 위치이고, `url`은 그 사이의 텍스트입니다.

```ts
findLinks('Docs: https://lognal.cdget.com/guide/viewer.');
// [{ start: 6, end: 43, url: 'https://lognal.cdget.com/guide/viewer' }]
```

### 줄 조각 {#line-spans}

항목은 클러스터로 나뉘고 행으로 줄 바꿈되기 전에 먼저 조각으로 이루어진 논리 줄로 만들어집니다. `previewValue`도 같은 종류의 조각을 반환합니다.

```ts
type LineSpan = LineTextSpan | LineIconSpan;
```

#### LineTextSpan {#linetextspan}

논리 줄 위의 텍스트 구간입니다.

| 필드     | 타입         | 설명                                              |
| -------- | ------------ | ------------------------------------------------- |
| `text`   | `string`     | 텍스트입니다.                                     |
| `token`  | `StyleToken` | 의미 색이 있으면 그 값입니다.                     |
| `style`  | `TextStyle`  | 직접 지정한 스타일이 있으면 그 값입니다.          |
| `action` | `LineAction` | 텍스트를 클릭했을 때의 동작이 있으면 그 값입니다. |

#### LineIconSpan {#lineiconspan}

값을 펼치는 삼각형처럼 두 칸을 차지하는 작은 기호입니다.

| 필드       | 타입         | 설명                                  |
| ---------- | ------------ | ------------------------------------- |
| `icon`     | `'expander'` | 기호의 종류입니다.                    |
| `expanded` | `boolean`    | 펼침 삼각형이 열려 있는지 나타냅니다. |
| `action`   | `LineAction` | 기호를 클릭했을 때의 동작입니다.      |

#### LogicalLine {#logicalline}

줄 바꿈하기 전의 항목 한 줄입니다. 항목에는 텍스트의 줄마다 논리 줄이 하나씩 있고, 펼친 값의 행마다 논리 줄이 하나씩 더 있습니다.

| 필드     | 타입         | 설명                                                                                               |
| -------- | ------------ | -------------------------------------------------------------------------------------------------- |
| `indent` | `number`     | 내용 앞의 들여쓰기 칸 수입니다. 줄 바꿈된 행마다 반복합니다.                                       |
| `spans`  | `LineSpan[]` | 줄을 이루는 조각을 순서대로 담은 배열입니다.                                                       |
| `wrap`   | `boolean`    | `wrap: false`인 텍스트 파트가 들어 있어 줄을 바꾸지 않는 줄이면 `false`입니다. 생략할 수 있습니다. |

## Renderer {#renderer}

```ts
interface Renderer {
	readonly element: HTMLElement;
	setTheme(theme: RenderTheme): void;
	setFont(font: FontSettings): CellMetrics;
	getMetrics(): CellMetrics;
	resize(width: number, height: number, pixelRatio: number): void;
	render(frame: RenderFrame): void;
	onFontsChanged(listener: () => void): void;
	dispose(): void;
}
```

레이아웃, 스크롤, 입력은 뷰어가 맡습니다. 렌더러는 프레임을 픽셀로 바꾸는 일만 하므로, 다른 그리기 기술로 바꿔 끼울 수 있습니다.

| 멤버                                | 설명                                                                                                  |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `element`                           | 렌더러가 그리는 요소입니다. 뷰어는 이 요소를 로그의 스크롤 영역 아래에 놓습니다.                      |
| `setTheme(theme)`                   | 색을 정합니다. 뷰어를 만들 때와 테마가 바뀔 때마다 호출합니다.                                        |
| `setFont(font)`                     | 글꼴을 정하고 한 칸의 크기를 반환합니다. 뷰어는 이 크기로 텍스트를 배치하고 포인터 위치를 계산합니다. |
| `getMetrics()`                      | 한 칸의 크기를 반환합니다.                                                                            |
| `resize(width, height, pixelRatio)` | CSS 픽셀 단위의 그리기 크기와 기기 픽셀 비율을 정합니다.                                              |
| `render(frame)`                     | 프레임 하나를 그립니다. 뷰어는 애니메이션 프레임마다 많아야 한 번 호출합니다.                         |
| `onFontsChanged(listener)`          | 글꼴이 필요한 글리프를 다 불러왔을 때 호출할 함수를 등록합니다. 뷰어는 이때 다시 잽니다.              |
| `dispose()`                         | 자원을 해제하고 요소를 없앱니다.                                                                      |

### RenderFrame {#renderframe}

| 필드             | 타입                       | 설명                                                           |
| ---------------- | -------------------------- | -------------------------------------------------------------- |
| `rows`           | `VisualRow[]`              | 위에서부터 그릴 행입니다.                                      |
| `decorations`    | `RowDecoration[]`          | 각 행의 강조입니다. `rows`와 인덱스가 같습니다.                |
| `offsetY`        | `number`                   | 첫 행의 세로 오프셋으로, CSS 픽셀 단위이며 0이거나 음수입니다. |
| `scrollX`        | `number`                   | 콘텐츠 영역의 가로 스크롤 위치로, CSS 픽셀 단위입니다.         |
| `paddingLeft`    | `number`                   | 여백 열 앞의 공간으로, CSS 픽셀 단위입니다.                    |
| `timestampCells` | `number`                   | 타임스탬프 열의 칸 수입니다. 타임스탬프를 숨기면 0입니다.      |
| `markerCells`    | `number`                   | 수준 표시 열의 칸 수입니다.                                    |
| `formatTime`     | `(time: number) => string` | 타임스탬프 열에 쓸 항목의 시각을 서식화합니다.                 |

콘텐츠 영역은 `paddingLeft + (timestampCells + markerCells) * cellWidth`에서 시작합니다.

### RowDecoration {#rowdecoration}

| 필드            | 타입                 | 설명                                                                                           |
| --------------- | -------------------- | ---------------------------------------------------------------------------------------------- |
| `selection`     | `[number, number]`   | 콘텐츠 영역에서 선택된 열 범위가 있으면 그 값입니다.                                           |
| `matches`       | `[number, number][]` | 필터와 일치한 열 범위가 있으면 그 값입니다.                                                    |
| `hovered`       | `boolean`            | 행이 포인터가 올라간 항목이나 메뉴가 열린 항목에 속하는지 나타냅니다.                          |
| `searchMatches` | `[number, number][]` | 현재 결과를 뺀 검색 결과의 열 범위가 있으면 그 값입니다.                                       |
| `searchCurrent` | `[number, number]`   | 행이 현재 검색 결과를 보여 주면 그 열 범위입니다.                                              |
| `entrySelected` | `boolean`            | 행이 항목 모드에서 선택한 항목에 속하는지 나타냅니다.                                          |
| `entryFocused`  | `boolean`            | 로그 영역에 포커스가 있을 때, 행이 항목 모드에서 키보드가 가리키는 항목에 속하는지 나타냅니다. |

### CellMetrics와 FontSettings {#cellmetrics-and-fontsettings}

| `CellMetrics` 필드 | 타입     | 설명                                        |
| ------------------ | -------- | ------------------------------------------- |
| `width`            | `number` | 한 칸의 너비로, CSS 픽셀 단위입니다.        |
| `height`           | `number` | 한 행의 높이로, CSS 픽셀 단위입니다.        |
| `baseline`         | `number` | 행 위쪽에서 텍스트 기준선까지의 거리입니다. |

| `FontSettings` 필드 | 타입     | 설명                                                              |
| ------------------- | -------- | ----------------------------------------------------------------- |
| `family`            | `string` | `"JetBrains Mono", D2Coding, monospace` 같은 CSS 글꼴 목록입니다. |
| `size`              | `number` | 글꼴 크기로, CSS 픽셀 단위입니다.                                 |
| `weight`            | `number` | 일반 텍스트의 굵기로, 예를 들면 `400`입니다.                      |
| `lineHeight`        | `number` | 행 높이를 글꼴 크기의 배수로 나타낸 값입니다.                     |

### RenderTheme {#rendertheme}

렌더러가 그릴 때 쓰는 색입니다. `readTheme`이 `--lognal-*` 사용자 지정 속성으로 만들며, CSS 색이면 무엇이든 쓸 수 있습니다.

| 필드                                                                                                              | 타입                                             | CSS 속성                                         |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------ |
| `background`, `foreground`, `muted`, `accent`                                                                     | `string`                                         | `--lognal-background` 등                         |
| `selection`, `match`, `separator`, `hover`, `searchMatch`, `searchCurrent`, `link`, `entrySelection`, `focusRing` | `string`                                         | `--lognal-selection` 등                          |
| `error`, `errorBackground`, `warn`, `warnBackground`, `info`, `debug`                                             | `string`                                         | `--lognal-error`, `--lognal-error-background` 등 |
| `tokens`                                                                                                          | `Record<Exclude<StyleToken, 'default'>, string>` | `--lognal-token-*`                               |
| `ansi`                                                                                                            | `string[]`                                       | `--lognal-ansi-0`부터 `--lognal-ansi-15`까지     |

`DEFAULT_RENDER_THEME`에는 CSS에서 테마를 읽기 전까지 쓰는 색이 들어 있습니다. 이 색은 `lognal.css`의 어두운 팔레트와 같고, 단위 테스트가 두 값이 같은지 확인합니다.

### CanvasRenderer {#canvasrenderer}

```ts
new CanvasRenderer(ownerDocument?: Document)
```

내장 렌더러입니다. `<canvas>`의 2D 컨텍스트로 그리고, 프레임마다 보이는 행을 다시 그립니다. 스타일이 하나인 순수 ASCII 텍스트는 `fillText` 한 번으로 그리고, 그 밖의 텍스트는 그래핌 클러스터마다 격자 위치에 맞춰 따로 그립니다. 그래서 전각 문자와 대체 글꼴의 문자도 격자에서 벗어나지 않습니다. 상자 그리기 문자는 선으로 그려서 표 테두리가 행 사이에서 끊기지 않습니다.

### 렌더러 직접 만들기 {#a-custom-renderer}

아래 예제는 행을 `<pre>` 요소에 일반 텍스트로 그립니다. 프레임의 각 부분이 어떻게 맞물리는지 보여 주려는 예제라서 타임스탬프, 표시, 색, 강조는 그리지 않고, `<pre>`는 전각 문자를 격자에 맞추지 못합니다.

```ts
import { LogViewer, type CellMetrics, type FontSettings, type RenderFrame, type RenderTheme, type Renderer } from 'lognal';

class PreRenderer implements Renderer {
	readonly element: HTMLPreElement;
	private readonly measure: CanvasRenderingContext2D | null;
	private metrics: CellMetrics = { width: 8, height: 20, baseline: 14 };

	constructor(ownerDocument: Document) {
		this.element = ownerDocument.createElement('pre');
		// 내장 캔버스의 클래스를 붙이면 요소가 스크롤 영역 아래에 놓입니다.
		this.element.className = 'lognal-canvas';
		this.element.style.margin = '0';
		this.element.style.overflow = 'hidden';
		this.measure = ownerDocument.createElement('canvas').getContext('2d');
	}

	setTheme(theme: RenderTheme): void {
		this.element.style.color = theme.foreground;
		this.element.style.backgroundColor = theme.background;
	}

	setFont(font: FontSettings): CellMetrics {
		const css = `${font.weight} ${font.size}px ${font.family}`;
		const height = Math.round(font.size * font.lineHeight);

		this.element.style.font = css;
		this.element.style.lineHeight = `${height}px`;

		if (this.measure) {
			this.measure.font = css;
		}

		const width = this.measure?.measureText('M').width || font.size * 0.6;

		this.metrics = { width, height, baseline: Math.round(height * 0.75) };

		return this.metrics;
	}

	getMetrics(): CellMetrics {
		return this.metrics;
	}

	resize(): void {}

	render(frame: RenderFrame): void {
		const gutterCells = frame.timestampCells + frame.markerCells;

		this.element.style.top = `${frame.offsetY}px`;
		this.element.style.paddingLeft = `${frame.paddingLeft + gutterCells * this.metrics.width}px`;
		this.element.textContent = frame.rows
			.map((row) => {
				let line = '';
				let column = 0;

				for (const run of row.runs) {
					line += ' '.repeat(Math.max(0, run.column - column));
					line += run.icon ? (run.expanded ? '- ' : '+ ') : run.text;
					column = run.column + run.cells;
				}

				return line;
			})
			.join('\n');
		this.element.scrollLeft = frame.scrollX;
	}

	onFontsChanged(): void {}

	dispose(): void {
		this.element.remove();
	}
}

const viewer = new LogViewer(document.getElementById('logs')!, {
	renderer: (ownerDocument) => new PreRenderer(ownerDocument)
});
```
