---
order: 6
description: LogEntry, LogPart, ValueNode, LogLevel, TextStyle, StyleToken처럼 lognal 전체에서 함께 쓰는 데이터 타입의 레퍼런스입니다.
---

# 타입

이 페이지의 타입은 모두 순수한 데이터입니다. 항목과 값은 로그를 남긴 객체의 참조를 들고 있지 않으므로 다른 아이솔레이트나 스레드로 넘기거나 JSON으로 저장할 수 있습니다.

<Fw js="여기의 문자열 리터럴 유니온은 Dart 패키지에서 enum이고, 구별 유니온은 sealed 클래스입니다." flutter="여기의 enum은 npm 패키지에서 문자열 리터럴 유니온이고, sealed 클래스는 구별 유니온입니다." />

## LogLevel {#loglevel}

::: fw js

```ts
type LogLevel = 'debug' | 'log' | 'info' | 'warn' | 'error';
```

항목의 심각도입니다. `LOG_LEVELS`는 모든 수준을 낮은 것부터 높은 것 순서로 담은 읽기 전용 배열입니다.

:::

::: fw flutter

```dart
enum LogLevel { debug, log, info, warn, error }
```

항목의 심각도입니다. `logLevels`는 모든 수준을 낮은 것부터 높은 것 순서로 담은 `LogLevel.values`입니다.

:::

## LogKind {#logkind}

::: fw js

```ts
type LogKind = 'message' | 'input' | 'output' | 'group' | 'system';
```

:::

::: fw flutter

```dart
enum LogKind { message, input, output, group, system }
```

:::

항목의 종류입니다. 뷰어는 종류마다 다른 표시를 붙입니다.

| 종류      | 항목                                                                               |
| --------- | ---------------------------------------------------------------------------------- |
| `message` | 일반 로그 메시지입니다.                                                            |
| `input`   | 사용자가 입력 줄에 입력한 명령입니다.                                              |
| `output`  | 명령의 응답입니다.                                                                 |
| `group`   | <Fw js="console.group" flutter="log.group" code />으로 시작한 그룹의 머리글입니다. |
| `system`  | `Console was cleared`처럼 뷰어가 직접 남긴 알림입니다.                             |

## LogEntry {#logentry}

스토어가 보관하는 항목입니다.

| 필드        | 타입                                                        | 설명                                                                                       |
| ----------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `id`        | <Fw js="number" flutter="int" code />                       | 스토어 안에서 항목을 식별하는 번호입니다. 읽기 전용입니다.                                 |
| `time`      | <Fw js="number" flutter="DateTime" code />                  | 항목이 추가된 시각입니다.<Fw js=" 밀리초 단위의 에포크 시각입니다." /> 읽기 전용입니다.    |
| `level`     | `LogLevel`                                                  | 심각도입니다. 읽기 전용입니다.                                                             |
| `kind`      | `LogKind`                                                   | 항목의 종류입니다. 읽기 전용입니다.                                                        |
| `parts`     | <Fw js="readonly LogPart[]" flutter="List<LogPart>" code /> | 차례대로 표시하는 내용입니다. 읽기 전용입니다.                                             |
| `groups`    | <Fw js="readonly number[]" flutter="List<int>" code />      | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다. 읽기 전용입니다.           |
| `runHead`   | <Fw js="number" flutter="int?" code />                      | 반복 묶음을 접어 둘 때, 이 항목이 반복하는 묶음의 첫 항목 id입니다. 읽기 전용입니다.       |
| `collapsed` | <Fw js="boolean" flutter="bool" code />                     | 그룹 머리글이나 반복 묶음의 첫 항목이면, 그 안의 항목을 숨겼는지 나타냅니다.               |
| `repeat`    | <Fw js="number" flutter="int" code />                       | 이 항목이 대신하는 연속된 똑같은 메시지의 수입니다.                                        |
| `version`   | <Fw js="number" flutter="int" code />                       | `collapsed`나 `repeat`가 바뀔 때마다 늘어나서, 캐시된 레이아웃을 새로 고칠 수 있게 합니다. |

## LogEntryInit {#logentryinit}

<Fw js="store.append" flutter="store.append나 store.add" code />에 넘기는 필드입니다.

| 필드        | 타입                                                   | 기본값                                               | 설명                                                                             |
| ----------- | ------------------------------------------------------ | ---------------------------------------------------- | -------------------------------------------------------------------------------- |
| `parts`     | <Fw js="LogPart[]" flutter="List<LogPart>" code />     | 필수                                                 | 항목의 내용입니다.                                                               |
| `level`     | `LogLevel`                                             | <Fw js="'log'" flutter="LogLevel.log" code />        | 심각도입니다.                                                                    |
| `kind`      | `LogKind`                                              | <Fw js="'message'" flutter="LogKind.message" code /> | 항목의 종류입니다.                                                               |
| `time`      | <Fw js="number" flutter="DateTime?" code />            | 추가한 시각                                          | <Fw js="밀리초 단위의 에포크 시각입니다." flutter="항목이 일어난 시각입니다." /> |
| `groups`    | <Fw js="readonly number[]" flutter="List<int>" code /> | `[]`                                                 | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다.                  |
| `collapsed` | <Fw js="boolean" flutter="bool" code />                | `false`                                              | 그룹 머리글이면 접힌 상태로 시작할지 정합니다.                                   |

## LogPart {#logpart}

::: fw js

```ts
type LogPart = TextPart | ValuePart;
```

:::

::: fw flutter

```dart
sealed class LogPart {}
```

`TextPart`와 `ValuePart`가 이를 상속하므로, `switch`로 모두 다뤘는지 컴파일러가 확인해 줍니다. `type` 필드는 없습니다. 클래스 자체가 구분입니다.

:::

### TextPart {#textpart}

::: fw js

| 필드    | 타입         | 설명                                                                                                         |
| ------- | ------------ | ------------------------------------------------------------------------------------------------------------ |
| `type`  | `'text'`     | 텍스트 파트임을 나타냅니다.                                                                                  |
| `text`  | `string`     | 텍스트입니다. 줄 바꿈이 들어갈 수 있습니다.                                                                  |
| `token` | `StyleToken` | 의미 색입니다. 생략할 수 있습니다.                                                                           |
| `style` | `TextStyle`  | 직접 지정한 스타일입니다. 생략할 수 있습니다.                                                                |
| `wrap`  | `boolean`    | `false`이면 파트의 줄마다 한 행에 둡니다. 표처럼 모양을 지켜야 하는 텍스트에 씁니다. 생략하면 줄 바꿈합니다. |

:::

::: fw flutter

```dart
TextPart('Ready', token: StyleToken.info)
```

| 필드    | 타입            | 설명                                                                                 |
| ------- | --------------- | ------------------------------------------------------------------------------------ |
| `text`  | `String`        | 텍스트이자 첫 위치 인자입니다. 줄 바꿈이 들어갈 수 있습니다.                         |
| `token` | `StyleToken?`   | 의미 색입니다.                                                                       |
| `style` | `LogTextStyle?` | 직접 지정한 스타일입니다.                                                            |
| `wrap`  | `bool`          | `false`이면 파트의 줄마다 한 행에 둡니다. 표처럼 모양을 지켜야 하는 텍스트에 씁니다. |

:::

### ValuePart {#valuepart}

::: fw js

| 필드    | 타입        | 설명                               |
| ------- | ----------- | ---------------------------------- |
| `type`  | `'value'`   | 값 파트임을 나타냅니다.            |
| `value` | `ValueNode` | `snapshotValue`로 저장한 값입니다. |

:::

::: fw flutter

| 필드    | 타입        | 설명                              |
| ------- | ----------- | --------------------------------- |
| `value` | `ValueNode` | `captureValue`로 저장한 값입니다. |

:::

## StyleToken {#styletoken}

::: fw js

`StyleToken`의 값은 `'default'`, `'muted'`, `'string'`, `'number'`, `'boolean'`, `'null'`, `'key'`, `'symbol'`, `'function'`, `'regexp'`, `'date'`, `'tag'`, `'attribute'`, `'error'`, `'warn'`, `'info'`, `'accent'` 가운데 하나입니다.

렌더러가 테마에서 찾아 쓰는 의미 색입니다. `default`를 뺀 토큰마다 `--lognal-token-*` 속성이 있고, `default`는 항목 수준에 맞는 색을 씁니다.

:::

::: fw flutter

`StyleToken`은 enum입니다. `defaultToken`, `muted`, `string`, `number`, `boolean`, `nullValue`, `key`, `symbol`, `function`, `regexp`, `date`, `tag`, `attribute`, `error`, `warn`, `info`, `accent`가 있습니다.

페인터가 팔레트의 `renderer.tokens`에서 찾아 쓰는 의미 색입니다. `defaultToken`은 항목 수준에 맞는 색을 씁니다. 값 두 개에 접미사가 붙은 것은 `default`와 `null`이 Dart의 키워드이기 때문입니다.

:::

## TextStyle {#textstyle}

콘솔 메시지의 `%c`나 ANSI 이스케이프 코드로 지정한 스타일입니다. <Fw flutter="클래스 이름은 LogTextStyle입니다. TextStyle은 dart:ui가 먼저 쓰고 있습니다." />

| 필드            | 타입                                            | 설명                        |
| --------------- | ----------------------------------------------- | --------------------------- |
| `color`         | <Fw js="TextColor" flutter="TextColor?" code /> | 글자 색입니다.              |
| `background`    | <Fw js="TextColor" flutter="TextColor?" code /> | 배경색입니다.               |
| `bold`          | <Fw js="boolean" flutter="bool" code />         | 굵은 텍스트입니다.          |
| `dim`           | <Fw js="boolean" flutter="bool" code />         | 흐리게 그린 텍스트입니다.   |
| `italic`        | <Fw js="boolean" flutter="bool" code />         | 기울인 텍스트입니다.        |
| `underline`     | <Fw js="boolean" flutter="bool" code />         | 밑줄 친 텍스트입니다.       |
| `strikethrough` | <Fw js="boolean" flutter="bool" code />         | 취소선을 그은 텍스트입니다. |

::: fw js

```ts
type TextColor = number | string;
```

0부터 255까지의 숫자는 ANSI 팔레트의 번호이고, 0~15번은 테마를 따릅니다. 문자열은 `#ff0000`, `rgb(255 0 0)` 같은 CSS 색입니다.

:::

::: fw flutter

```dart
sealed class TextColor {}
```

`AnsiTextColor(index)`는 0부터 255까지의 ANSI 팔레트 번호이고, 0~15번은 테마를 따릅니다. `RgbTextColor(value)`는 `RgbTextColor(0xffff0000)`처럼 ARGB 값입니다. 둘 다 `resolveTextColor`가 팔레트에 맞춰 `Color`로 바꿉니다.

:::

## ValueNode {#valuenode}

로그를 남긴 순간에 저장한 값입니다.

| 필드         | 타입                                                                          | 설명                                                                                                                                        |
| ------------ | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind`       | `ValueKind`                                                                   | 값의 종류입니다.                                                                                                                            |
| `value`      | <Fw js="string" flutter="String?" code />                                     | 단일 값의 텍스트입니다. 문자열 자체, 텍스트로 쓴 숫자, 함수 이름, ISO 형식의 날짜, 정규 표현식 리터럴, 오류 메시지, 설명 가운데 하나입니다. |
| `className`  | <Fw js="string" flutter="String?" code />                                     | `Map`, `User` 같은 객체의 <Fw js="생성자 이름" flutter="타입 이름" />입니다.                                                                |
| `size`       | <Fw js="number" flutter="int?" code />                                        | 리스트나 문자열의 길이, Map이나 Set의 크기입니다.                                                                                           |
| `children`   | <Fw js="ValueEntry[]" flutter="List<ValueEntry>?" code />                     | 객체, 리스트, Map, Set, 오류에서 저장한 자식입니다. 깊이 한도에 닿았거나 아무것도 읽을 수 없었으면 없습니다.                                |
| `omitted`    | <Fw js="number" flutter="int" code />                                         | 있지만 한도 때문에 빠진 자식의 수입니다.                                                                                                    |
| `truncated`  | <Fw js="number" flutter="int" code />                                         | 긴 문자열에서 잘라 낸 글자 수입니다.                                                                                                        |
| `stack`      | <Fw js="string" flutter="String?" code />                                     | 첫 줄을 뺀 오류의 스택 트레이스입니다.                                                                                                      |
| `attributes` | <Fw js="[string, string][]" flutter="List<MapEntry<String, String>>?" code /> | 요소의 속성을 이름과 값의 쌍으로 담은 배열입니다.                                                                                           |
| `accessor`   | <Fw js="'get' \| 'set' \| 'get-set'" flutter="AccessorKind?" code />          | 접근자 속성이면 정의된 부분을 나타냅니다.                                                                                                   |

<Fw js="kind를 뺀 필드는 모두 선택 사항입니다." flutter="kind를 뺀 필드는 모두 선택 사항이고, copyWith로 일부만 바꾼 사본을 얻습니다." />

### ValueKind {#valuekind}

::: fw js

`ValueKind`의 값은 `'undefined'`, `'null'`, `'boolean'`, `'number'`, `'bigint'`, `'string'`, `'symbol'`, `'function'`, `'class'`, `'date'`, `'regexp'`, `'error'`, `'array'`, `'object'`, `'map'`, `'set'`, `'weak'`, `'promise'`, `'element'`, `'text'`, `'circular'`, `'accessor'` 가운데 하나입니다.

형식화 배열은 클래스 이름이 붙은 `'array'`이고, `WeakMap`, `WeakSet`, `WeakRef`는 `'weak'`, DOM 텍스트 노드는 `'text'`입니다.

:::

::: fw flutter

`ValueKind`는 enum입니다. `nullValue`, `boolean`, `number`, `bigint`, `string`, `symbol`, `function`, `classValue`, `date`, `regexp`, `error`, `list`, `object`, `map`, `set`, `future`, `element`, `text`, `circular`, `accessor`가 있습니다.

npm 패키지와 이름이 다른 것이 셋입니다. `nullValue`와 `classValue`는 `null`과 `class`가 Dart의 키워드라 접미사가 붙었고, `list`는 그쪽의 `array`, `future`는 그쪽의 `promise`입니다. `Uint8List` 같은 형식화 리스트는 타입 이름이 붙은 `list`입니다.

`undefined`는 없습니다. Dart에는 빈 값이 둘이 아니라 하나이기 때문입니다. `weak`도 없습니다. `WeakReference`는 가리키는 객체로, 이미 사라졌으면 `nullValue`로 저장합니다.

:::

### ValueEntry {#valueentry}

값의 자식입니다. 속성, 리스트 항목, Map 엔트리, 자식 노드가 여기에 해당합니다.

| 필드       | 타입                                                                                     | 설명                                                           |
| ---------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `key`      | <Fw js="string" flutter="String?" code />                                                | 속성 이름이나 인덱스입니다. Set 항목과 자식 노드에는 없습니다. |
| `keyKind`  | <Fw js="'property' \| 'index' \| 'symbol' \| 'internal'" flutter="ValueKeyKind?" code /> | 키를 표시하는 방식입니다.                                      |
| `keyValue` | <Fw js="ValueNode" flutter="ValueNode?" code />                                          | Map 엔트리의 키입니다.                                         |
| `value`    | `ValueNode`                                                                              | 자식 값입니다.                                                 |

<Fw flutter="ValueKeyKind의 값은 property, indexed, symbol, internal입니다. 두 번째가 index가 아니라 indexed인 것은 index가 이미 모든 Dart enum의 멤버이기 때문입니다." />
