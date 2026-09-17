---
order: 2
description: 로그 항목을 보관하는 LogStore의 옵션, 메서드, 변경 알림, 쓰기 옵션을 정리한 레퍼런스입니다.
---

# LogStore

::: fw js

```ts
import { LogStore } from 'lognal';

const store = new LogStore({ maxEntries: 50000 });
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore(
  options: const LogStoreOptions(maxEntries: 50000),
);
```

:::

로그 항목을 추가된 순서대로 보관합니다. 스토어는 항목을 어떻게 보여 줄지 모르므로, 스토어 하나를 여러 뷰어가 함께 보여 주거나 뷰어가 생기기 전부터 메시지를 모아 둘 수 있습니다.

## 생성자 {#constructor}

```
new LogStore(options)
```

<Fw js="넘기지 않은 옵션은 기본값을 씁니다." flutter="LogStoreOptions 자체가 기본값을 가진 값이므로, 인자 없이 만든 스토어가 곧 기본값을 쓰는 스토어입니다." />

## LogStoreOptions {#logstoreoptions}

::: fw js

| 옵션           | 타입         | 기본값  | 설명                                                                                                                                      |
| -------------- | ------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`   | `number`     | `10000` | 스토어가 보관하는 최대 항목 수입니다. 가득 차면 새 항목이 들어올 때마다 가장 오래된 항목을 버립니다. 모두 보관하려면 `Infinity`를 씁니다. |
| `mergeRepeats` | `RepeatMode` | `true`  | 바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. [`RepeatMode`](#repeatmode)를 참고하세요.                                             |

`DEFAULT_STORE_OPTIONS`에 이 기본값이 들어 있습니다.

:::

::: fw flutter

| 옵션           | 타입           | 기본값               | 설명                                                                                                 |
| -------------- | -------------- | -------------------- | ---------------------------------------------------------------------------------------------------- |
| `maxEntries`   | `int`          | `10000`              | 스토어가 보관하는 최대 항목 수입니다. 가득 차면 새 항목이 들어올 때마다 가장 오래된 항목을 버립니다. |
| `mergeRepeats` | `MergeRepeats` | `MergeRepeats.merge` | 바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. [`MergeRepeats`](#repeatmode)를 참고하세요.      |

`defaultStoreOptions`에 이 기본값이 들어 있고, `copyWith`로 하나만 바꾼 사본을 얻습니다.

:::

## 속성 {#properties}

| 속성      | 타입                                  | 설명                                                                                   |
| --------- | ------------------------------------- | -------------------------------------------------------------------------------------- |
| `size`    | <Fw js="number" flutter="int" code /> | 보관 중인 항목 수입니다.                                                               |
| `firstId` | <Fw js="number" flutter="int" code /> | 보관 중인 가장 오래된 항목의 id입니다. 스토어가 비어 있으면 다음 항목이 받을 id입니다. |
| `lastId`  | <Fw js="number" flutter="int" code /> | 보관 중인 가장 새 항목의 id입니다. 스토어가 비어 있으면 `firstId - 1`입니다.           |

id는 1부터 시작해 새 항목마다 1씩 늘어납니다. `clear()`를 호출한 뒤에도 같은 id를 다시 쓰지 않습니다.

## 메서드 {#methods}

::: fw js

| 메서드                                                  | 반환값                      | 설명                                                                                                                                                   |
| ------------------------------------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `getOptions()`                                          | `Readonly<LogStoreOptions>` | 옵션을 반환합니다.                                                                                                                                     |
| `setOptions(options: Partial<LogStoreOptions>)`         | `void`                      | 옵션을 바꿉니다. `maxEntries`를 줄이면 오래된 항목을 바로 버립니다.                                                                                    |
| `at(index: number)`                                     | `LogEntry \| undefined`     | 위치에 있는 항목을 반환합니다. 0이 보관 중인 가장 오래된 항목입니다.                                                                                   |
| `get(id: number)`                                       | `LogEntry \| undefined`     | 아직 보관 중이라면 id에 해당하는 항목을 반환합니다.                                                                                                    |
| `toArray()`                                             | `LogEntry[]`                | 모든 항목을 오래된 순서로 반환합니다.                                                                                                                  |
| `[Symbol.iterator]()`                                   | `Iterator<LogEntry>`        | 항목을 오래된 순서로 순회합니다.                                                                                                                       |
| `append(init: LogEntryInit \| readonly LogEntryInit[])` | `LogEntry[]`                | 항목을 하나 또는 여러 개 추가하고, 새로 만든 항목만 반환합니다. 앞 항목에 합쳐진 메시지는 그 항목의 `repeat`만 올리고 반환 배열에는 들어가지 않습니다. |
| `write(text: string, options?: WriteOptions)`           | `LogEntry \| undefined`     | 텍스트를 항목 하나로 추가합니다. 줄 바꿈은 항목 안에 그대로 둡니다. 새 항목이나, 텍스트가 합쳐진 항목을 반환합니다.                                    |
| `writeLines(text: string, options?: WriteOptions)`      | `LogEntry[]`                | 텍스트를 줄마다 항목 하나씩 추가하고, 새로 만든 항목을 반환합니다.                                                                                     |
| `clear()`                                               | `void`                      | 항목을 모두 지웁니다.                                                                                                                                  |
| `setCollapsed(id: number, collapsed: boolean)`          | `void`                      | 그룹 머리글이나 반복 묶음의 첫 항목을 접거나 펼쳐서, 그 안의 항목을 숨기거나 보여 줍니다.                                                              |
| `isRunHead(entry: LogEntry)`                            | `boolean`                   | 스토어가 아직 들고 있는 반복 묶음의 첫 항목인지, 곧 그 묶음을 펼칠 수 있는지 알려 줍니다.                                                              |
| `subscribe(listener: StoreListener)`                    | `() => void`                | 바뀔 때마다 리스너를 호출합니다. 리스너를 떼는 함수를 반환합니다.                                                                                      |

:::

::: fw flutter

| 메서드                                            | 반환값            | 설명                                                                                                                           |
| ------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `options`                                         | `LogStoreOptions` | 옵션입니다. 대입하면 바뀌고, `maxEntries`를 줄이면 오래된 항목을 바로 버립니다.                                                |
| `at(int index)`                                   | `LogEntry?`       | 위치에 있는 항목입니다. 0이 보관 중인 가장 오래된 항목입니다.                                                                  |
| `get(int id)`                                     | `LogEntry?`       | 아직 보관 중이라면 id에 해당하는 항목입니다.                                                                                   |
| `toList()`                                        | `List<LogEntry>`  | 모든 항목을 오래된 순서로 반환합니다.                                                                                          |
| `append(List<LogEntryInit> inits)`                | `List<LogEntry>`  | 항목을 추가하고 새로 만든 항목만 반환합니다. 앞 항목에 합쳐진 메시지는 그 항목의 `repeat`만 올리고 리스트에 들어가지 않습니다. |
| `add(LogEntryInit init)`                          | `LogEntry?`       | 항목 하나를 추가하고 그 항목이나 합쳐진 항목을 반환합니다.                                                                     |
| `write(String text, [WriteOptions options])`      | `LogEntry?`       | 텍스트를 항목 하나로 추가합니다. 줄 바꿈은 항목 안에 그대로 둡니다.                                                            |
| `writeLines(String text, [WriteOptions options])` | `List<LogEntry>`  | 텍스트를 줄마다 항목 하나씩 추가하고, 새로 만든 항목을 반환합니다.                                                             |
| `clear()`                                         | `void`            | 항목을 모두 지웁니다.                                                                                                          |
| `setCollapsed(int id, bool collapsed)`            | `void`            | 그룹 머리글이나 반복 묶음의 첫 항목을 접거나 펼쳐서, 그 안의 항목을 숨기거나 보여 줍니다.                                      |
| `isRunHead(LogEntry entry)`                       | `bool`            | 스토어가 아직 들고 있는 반복 묶음의 첫 항목인지, 곧 그 묶음을 펼칠 수 있는지 알려 줍니다.                                      |
| `subscribe(StoreListener listener)`               | `void Function()` | 바뀔 때마다 리스너를 호출합니다. 리스너를 떼는 함수를 반환합니다.                                                              |

이터레이터도 `getOptions`도 없습니다. 순회할 리스트는 `toList()`가 주고, 옵션은 속성입니다.

:::

::: fw js

```ts
import { LogStore } from 'lognal';

const store = new LogStore();

store.append({
	level: 'warn',
	parts: [
		{ type: 'text', text: 'Slow query ' },
		{ type: 'text', text: '1.8s', token: 'number' }
	]
});

const stop = store.subscribe((change) => {
	if (change.type === 'append') {
		document.title = `${store.size} log entries`;
	}
});
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

store.add(
  const LogEntryInit(
    level: LogLevel.warn,
    parts: <LogPart>[
      TextPart('Slow query '),
      TextPart('1.8s', token: StyleToken.number),
    ],
  ),
);

final void Function() stop = store.subscribe((StoreChange change) {
  if (change is StoreAppend) {
    debugPrint('${store.size} log entries');
  }
});
```

:::

## WriteOptions {#writeoptions}

스토어와 뷰어의 `write`, `writeLines`가 받는 옵션입니다.

::: fw js

| 옵션     | 타입                    | 기본값      | 설명                                                                                                                           |
| -------- | ----------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `level`  | `LogLevel`              | `'log'`     | 항목의 수준입니다.                                                                                                             |
| `kind`   | `LogKind`               | `'message'` | 항목의 종류입니다.                                                                                                             |
| `time`   | `number`                | 현재 시각   | 항목의 시각으로, 밀리초 단위의 에포크 시각입니다.                                                                              |
| `groups` | `readonly number[]`     | `[]`        | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다.                                                                |
| `token`  | `StyleToken`            | 없음        | 텍스트의 의미 색입니다.                                                                                                        |
| `style`  | `TextStyle`             | 없음        | 텍스트에 직접 지정하는 스타일입니다. `ansi`를 지정하면 무시합니다.                                                             |
| `ansi`   | `boolean \| AnsiParser` | `false`     | 텍스트의 ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다. 파서를 넘기면 여러 번 호출해도 스타일이 이어집니다.                  |
| `wrap`   | `boolean`               | `true`      | `false`이면 텍스트의 줄마다 한 행에 둡니다. 표처럼 모양을 지켜야 하는 텍스트에 씁니다. 뷰어보다 넓은 줄은 가로로 스크롤합니다. |

:::

::: fw flutter

| 옵션     | 타입            | 기본값            | 설명                                                                                                                           |
| -------- | --------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `level`  | `LogLevel`      | `LogLevel.log`    | 항목의 수준입니다.                                                                                                             |
| `kind`   | `LogKind`       | `LogKind.message` | 항목의 종류입니다.                                                                                                             |
| `time`   | `DateTime?`     | 현재 시각         | 항목의 시각입니다.                                                                                                             |
| `groups` | `List<int>`     | `[]`              | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다.                                                                |
| `token`  | `StyleToken?`   | `null`            | 텍스트의 의미 색입니다.                                                                                                        |
| `style`  | `LogTextStyle?` | `null`            | 텍스트에 직접 지정하는 스타일입니다. `ansi`가 켜져 있으면 무시합니다.                                                          |
| `ansi`   | `bool`          | `false`           | 텍스트의 ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                                                                      |
| `parser` | `AnsiParser?`   | `null`            | 직접 만든 파서입니다. 여러 번 호출해도 스타일이 이어지며, 넘기면 `ansi`도 켜집니다.                                            |
| `wrap`   | `bool`          | `true`            | `false`이면 텍스트의 줄마다 한 행에 둡니다. 표처럼 모양을 지켜야 하는 텍스트에 씁니다. 뷰어보다 넓은 줄은 가로로 스크롤합니다. |

npm 패키지에서 하나인 필드가 여기서는 `ansi`와 `parser` 둘입니다. Dart의 필드는 타입 하나만 담습니다.

:::

## RepeatMode {#repeatmode}

::: fw js

```ts
type RepeatMode = boolean | 'collapse';
```

바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. `true`는 메시지를 버리고 앞 항목의 반복 횟수를 올리며, `'collapse'`는 메시지를 모두 보관하고 연속된 메시지를 횟수와 함께 접힌 항목 하나로 보여 주고, `false`는 메시지마다 항목을 따로 만듭니다.

:::

::: fw flutter

```dart
enum MergeRepeats { merge, collapse, keep }
```

바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. `merge`는 메시지를 버리고 앞 항목의 반복 횟수를 올리며, `collapse`는 메시지를 모두 보관하고 연속된 메시지를 횟수와 함께 접힌 항목 하나로 보여 주고, `keep`은 메시지마다 항목을 따로 만듭니다.

이름이 `RepeatMode`가 아니라 `MergeRepeats`인 것은 `RepeatMode`를 `package:flutter/widgets.dart`가 먼저 쓰고 있기 때문입니다.

:::

메시지 종류의 항목만 묶이고, 오류나 자식이 있는 값을 담은 항목은 묶이지 않습니다. [반복 메시지](/ko/guide/values#repeated-messages)를 참고하세요.

## StoreChange {#storechange}

스토어 리스너가 받는 값입니다.

::: fw js

| `type`     | 다른 필드                                 | 보내는 때                                                                                                       |
| ---------- | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `'append'` | `entries: readonly LogEntry[]`            | 항목이 추가됐을 때입니다.                                                                                       |
| `'update'` | `entry: LogEntry`, `visibility?: boolean` | 항목의 반복 횟수나 접힘 상태가 바뀌었습니다. `visibility`는 다른 항목까지 숨기거나 보여 주는 변경임을 뜻합니다. |
| `'trim'`   | `count: number`                           | `maxEntries` 때문에 오래된 항목을 버렸을 때입니다.                                                              |
| `'clear'`  | 없음                                      | 항목을 모두 지웠을 때입니다.                                                                                    |

```ts
type StoreListener = (change: StoreChange) => void;
```

:::

::: fw flutter

`StoreChange`는 sealed 클래스이므로, `switch`로 모두 다뤘는지 컴파일러가 확인해 줍니다.

| 클래스        | 필드                                | 보내는 때                                                                                                       |
| ------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `StoreAppend` | `List<LogEntry> entries`            | 항목이 추가됐을 때입니다.                                                                                       |
| `StoreUpdate` | `LogEntry entry`, `bool visibility` | 항목의 반복 횟수나 접힘 상태가 바뀌었습니다. `visibility`는 다른 항목까지 숨기거나 보여 주는 변경임을 뜻합니다. |
| `StoreTrim`   | `int count`                         | `maxEntries` 때문에 오래된 항목을 버렸을 때입니다.                                                              |
| `StoreClear`  | 없음                                | 항목을 모두 지웠을 때입니다.                                                                                    |

```dart
typedef StoreListener = void Function(StoreChange change);
```

:::

추가 변경이 먼저 오고, 그 추가 때문에 생긴 버림 변경이 뒤따릅니다.
