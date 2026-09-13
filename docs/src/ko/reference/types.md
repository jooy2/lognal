---
order: 6
description: LogEntry, LogPart, ValueNode, LogLevel, TextStyle, StyleToken처럼 lognal 전체에서 함께 쓰는 데이터 타입의 레퍼런스입니다.
---

# 타입

이 페이지의 타입은 모두 순수한 데이터입니다. 항목과 값은 로그를 남긴 객체의 참조를 들고 있지 않으므로 `postMessage`로 넘기거나 JSON으로 저장할 수 있습니다.

## LogLevel {#loglevel}

```ts
type LogLevel = 'debug' | 'log' | 'info' | 'warn' | 'error';
```

항목의 심각도입니다. `LOG_LEVELS`는 모든 수준을 낮은 것부터 높은 것 순서로 담은 읽기 전용 배열입니다.

## LogKind {#logkind}

```ts
type LogKind = 'message' | 'input' | 'output' | 'group' | 'system';
```

항목의 종류입니다. 뷰어는 종류마다 다른 표시를 붙입니다.

| 종류        | 항목                                                   |
| ----------- | ------------------------------------------------------ |
| `'message'` | 일반 로그 메시지입니다.                                |
| `'input'`   | 사용자가 입력 줄에 입력한 명령입니다.                  |
| `'output'`  | 명령의 응답입니다.                                     |
| `'group'`   | `console.group`으로 시작한 그룹의 머리글입니다.        |
| `'system'`  | `Console was cleared`처럼 뷰어가 직접 남긴 알림입니다. |

## LogEntry {#logentry}

스토어가 보관하는 항목입니다.

| 필드        | 타입                 | 설명                                                                                       |
| ----------- | -------------------- | ------------------------------------------------------------------------------------------ |
| `id`        | `number`             | 스토어 안에서 항목을 식별하는 번호입니다. 읽기 전용입니다.                                 |
| `time`      | `number`             | 항목이 추가된 시각으로, 밀리초 단위의 에포크 시각입니다. 읽기 전용입니다.                  |
| `level`     | `LogLevel`           | 심각도입니다. 읽기 전용입니다.                                                             |
| `kind`      | `LogKind`            | 항목의 종류입니다. 읽기 전용입니다.                                                        |
| `parts`     | `readonly LogPart[]` | 차례대로 표시하는 내용입니다. 읽기 전용입니다.                                             |
| `groups`    | `readonly number[]`  | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다. 읽기 전용입니다.           |
| `collapsed` | `boolean`            | 그룹 머리글이면 그룹 안의 항목을 숨겼는지 나타냅니다.                                      |
| `repeat`    | `number`             | 이 항목이 대신하는 연속된 똑같은 메시지의 수입니다.                                        |
| `version`   | `number`             | `collapsed`나 `repeat`가 바뀔 때마다 늘어나서, 캐시된 레이아웃을 새로 고칠 수 있게 합니다. |

## LogEntryInit {#logentryinit}

`store.append`에 넘기는 필드입니다.

| 필드        | 타입                | 기본값      | 설명                                                            |
| ----------- | ------------------- | ----------- | --------------------------------------------------------------- |
| `parts`     | `LogPart[]`         | 필수        | 항목의 내용입니다.                                              |
| `level`     | `LogLevel`          | `'log'`     | 심각도입니다.                                                   |
| `kind`      | `LogKind`           | `'message'` | 항목의 종류입니다.                                              |
| `time`      | `number`            | 추가한 시각 | 밀리초 단위의 에포크 시각입니다.                                |
| `groups`    | `readonly number[]` | `[]`        | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다. |
| `collapsed` | `boolean`           | `false`     | 그룹 머리글이면 접힌 상태로 시작할지 정합니다.                  |

## LogPart {#logpart}

```ts
type LogPart = TextPart | ValuePart;
```

### TextPart {#textpart}

| 필드    | 타입         | 설명                                          |
| ------- | ------------ | --------------------------------------------- |
| `type`  | `'text'`     | 텍스트 파트임을 나타냅니다.                   |
| `text`  | `string`     | 텍스트입니다. 줄 바꿈이 들어갈 수 있습니다.   |
| `token` | `StyleToken` | 의미 색입니다. 생략할 수 있습니다.            |
| `style` | `TextStyle`  | 직접 지정한 스타일입니다. 생략할 수 있습니다. |

### ValuePart {#valuepart}

| 필드    | 타입        | 설명                               |
| ------- | ----------- | ---------------------------------- |
| `type`  | `'value'`   | 값 파트임을 나타냅니다.            |
| `value` | `ValueNode` | `snapshotValue`로 저장한 값입니다. |

## StyleToken {#styletoken}

`StyleToken`의 값은 `'default'`, `'muted'`, `'string'`, `'number'`, `'boolean'`, `'null'`, `'key'`, `'symbol'`, `'function'`, `'regexp'`, `'date'`, `'tag'`, `'attribute'`, `'error'`, `'warn'`, `'info'`, `'accent'` 가운데 하나입니다.

렌더러가 테마에서 찾아 쓰는 의미 색입니다. `default`를 뺀 토큰마다 `--lognal-token-*` 속성이 있고, `default`는 항목 수준에 맞는 색을 씁니다.

## TextStyle {#textstyle}

콘솔 메시지의 `%c`나 ANSI 이스케이프 코드로 지정한 스타일입니다.

| 필드            | 타입        | 설명                        |
| --------------- | ----------- | --------------------------- |
| `color`         | `TextColor` | 글자 색입니다.              |
| `background`    | `TextColor` | 배경색입니다.               |
| `bold`          | `boolean`   | 굵은 텍스트입니다.          |
| `dim`           | `boolean`   | 흐리게 그린 텍스트입니다.   |
| `italic`        | `boolean`   | 기울인 텍스트입니다.        |
| `underline`     | `boolean`   | 밑줄 친 텍스트입니다.       |
| `strikethrough` | `boolean`   | 취소선을 그은 텍스트입니다. |

```ts
type TextColor = number | string;
```

0부터 255까지의 숫자는 ANSI 팔레트의 번호이고, 0~15번은 테마를 따릅니다. 문자열은 `#ff0000`, `rgb(255 0 0)` 같은 CSS 색입니다.

## ValueNode {#valuenode}

로그를 남긴 순간에 저장한 값입니다.

| 필드         | 타입                          | 설명                                                                                                                                                    |
| ------------ | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind`       | `ValueKind`                   | 값의 종류입니다.                                                                                                                                        |
| `value`      | `string`                      | 단일 값의 텍스트입니다. 문자열 자체, 텍스트로 쓴 숫자, 함수 이름, ISO 형식의 날짜, 정규 표현식 리터럴, 오류 메시지, 요소의 태그 이름 가운데 하나입니다. |
| `className`  | `string`                      | `Map`, `User` 같은 객체의 생성자 이름입니다.                                                                                                            |
| `size`       | `number`                      | 배열이나 문자열의 길이, Map이나 Set의 크기입니다.                                                                                                       |
| `children`   | `ValueEntry[]`                | 객체, 배열, Map, Set, 오류, 요소에서 저장한 자식입니다. 깊이 한도에 닿았으면 `undefined`입니다.                                                         |
| `omitted`    | `number`                      | 있지만 한도 때문에 빠진 자식의 수입니다.                                                                                                                |
| `truncated`  | `number`                      | 긴 문자열에서 잘라 낸 글자 수입니다.                                                                                                                    |
| `stack`      | `string`                      | 첫 줄을 뺀 오류의 스택 트레이스입니다.                                                                                                                  |
| `attributes` | `[string, string][]`          | 요소의 속성을 이름과 값의 쌍으로 담은 배열입니다.                                                                                                       |
| `accessor`   | `'get' \| 'set' \| 'get-set'` | 접근자 속성이면 정의된 부분을 나타냅니다.                                                                                                               |

`kind`를 뺀 필드는 모두 선택 사항입니다.

### ValueKind {#valuekind}

`ValueKind`의 값은 `'undefined'`, `'null'`, `'boolean'`, `'number'`, `'bigint'`, `'string'`, `'symbol'`, `'function'`, `'class'`, `'date'`, `'regexp'`, `'error'`, `'array'`, `'object'`, `'map'`, `'set'`, `'weak'`, `'promise'`, `'element'`, `'text'`, `'circular'`, `'accessor'` 가운데 하나입니다.

형식화 배열은 클래스 이름이 붙은 `'array'`이고, `WeakMap`, `WeakSet`, `WeakRef`는 `'weak'`, DOM 텍스트 노드는 `'text'`입니다.

### ValueEntry {#valueentry}

값의 자식입니다. 속성, 배열 항목, Map 엔트리, 자식 노드가 여기에 해당합니다.

| 필드       | 타입                                              | 설명                                                           |
| ---------- | ------------------------------------------------- | -------------------------------------------------------------- |
| `key`      | `string`                                          | 속성 이름이나 인덱스입니다. Set 항목과 자식 노드에는 없습니다. |
| `keyKind`  | `'property' \| 'index' \| 'symbol' \| 'internal'` | 키를 표시하는 방식입니다.                                      |
| `keyValue` | `ValueNode`                                       | Map 엔트리의 키입니다.                                         |
| `value`    | `ValueNode`                                       | 자식 값입니다.                                                 |
