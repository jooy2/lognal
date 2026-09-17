---
order: 1
description: 애플리케이션이 이미 출력하는 내용을 lognal 뷰어에 기록하는 방법과 패키지별 메서드, 서식 지정자, 캡처 한도를 설명합니다.
---

# 출력 기록

애플리케이션은 이미 무언가를 출력합니다. 이 페이지는 그 출력을 뷰어로 가져오는 방법과, 그 안의 값이 어떻게 저장되는지를 다룹니다.

## 출력 기록하기 {#record-what-is-printed}

::: fw js

콘솔 호출을 로그 항목으로 바꾸는 방법은 세 가지입니다.

| API                                                | 기록하는 호출                      | 전역 콘솔                                                  |
| -------------------------------------------------- | ---------------------------------- | ---------------------------------------------------------- |
| `viewer.hookConsole(target?, options?)`            | `console`이나 넘긴 콘솔의 호출     | 반환된 함수를 호출하거나 뷰어를 dispose할 때까지 감쌉니다. |
| `hookConsole(target, store, options?)`             | 넘긴 콘솔의 호출을 원하는 스토어에 | 반환된 함수를 호출할 때까지 감쌉니다.                      |
| `viewer.console`, `createConsole(store, options?)` | 콘솔 메서드를 갖춘 새 객체의 호출  | 건드리지 않습니다.                                         |

```ts
import { LogViewer } from 'lognal';

const viewer = new LogViewer(container);

// 페이지의 콘솔을 옮겨 보여 줍니다.
const unhook = viewer.hookConsole();

// 뷰어에만 씁니다.
viewer.console.log('Only in the viewer');
```

`hookConsole`은 뷰어 없이도 동작하므로, 로그를 보여 줄 자리가 생기기 전부터 기록을 시작할 수 있습니다. 스토어는 뷰어가 만들어질 때까지 `maxEntries` 한도 안에서 항목을 보관합니다.

```ts
import { LogStore, LogViewer, hookConsole } from 'lognal';

const store = new LogStore();

hookConsole(console, store);

// 나중에:
const viewer = new LogViewer(container, { store });
```

:::

::: fw flutter

Dart는 세 가지 경로로 출력하고 그중 무엇도 감쌀 수 있는 객체 하나가 아니므로, 후크가 셋이고 직접 쓰는 콘솔이 하나 있습니다.

| API                                  | 기록하는 것                                                    | 원래 출력                               |
| ------------------------------------ | -------------------------------------------------------------- | --------------------------------------- |
| `hookDebugPrint(store, options?)`    | `debugPrint`에 넘어간 모든 것. Flutter는 이 경로로 출력합니다. | `passthrough`를 끄지 않으면 그대로 실행 |
| `runZonedWithLognal(store, body)`    | `body` 안에서 `print`가 쓴 모든 것                             | `passthrough`를 끄지 않으면 그대로 실행 |
| `hookFlutterErrors(store, options?)` | 프레임워크가 보고하는 모든 오류와 그 스택                      | `passthrough`를 끄지 않으면 그대로 보고 |
| `LognalConsole(store, options?)`     | 여러분이 직접 쓴 것만                                          | 건드리지 않습니다.                      |

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

void main() {
  final void Function() unhookPrint = hookDebugPrint(store);
  final void Function() unhookErrors = hookFlutterErrors(store);

  runZonedWithLognal(store, () => runApp(const MyApp()));
}
```

후크마다 자신을 떼는 함수를 돌려줍니다.

`print`만 사정이 다릅니다. 변수가 아니라 현재 존을 통해 결정되므로 나중에 바꿔치기할 수 없습니다. `runZonedWithLognal`은 `print`가 스토어에 쓰는 존 안에서 코드를 실행합니다. 나머지 둘처럼 설치하지 않고 `runApp`을 감싸는 이유입니다.

셋 다 뷰어가 없어도 동작합니다. 스토어는 뷰어가 만들어질 때까지 `maxEntries` 한도 안에서 항목을 보관하므로, `main()`에서 후크를 걸면 애플리케이션이 시작하며 출력한 것까지 모두 잡습니다.

직접 쓰는 것은 `LognalConsole`이 맡고, 전역은 아무것도 건드리지 않습니다.

```dart
final LognalConsole log = LognalConsole(store);

log.info('Connected to %s in %dms', <Object?>['database', 12]);
```

:::

### 후크의 동작 {#how-a-hook-behaves}

::: fw js

- 호출을 먼저 기록하고 그다음 원래 메서드를 실행합니다. 메시지를 브라우저 콘솔에 보내지 않으려면 `passthrough: false`를 지정합니다.
- 기록하다 오류가 나도 lognal이 잡아내므로 페이지가 멈추지 않습니다.
- 한 호출을 기록하는 도중에 일어난 콘솔 호출은 기록하지 않습니다. 로그를 남기는 `toString` 메서드가 그런 예입니다.
- `hookConsole`이 반환한 함수는 원래 메서드를 되돌려 놓습니다. lognal보다 나중에 다른 스크립트가 메서드를 감쌌다면 그 스크립트의 래퍼는 그대로 두고, lognal의 래퍼만 기록을 멈춥니다.
- 훅마다, 그리고 `createConsole`로 만든 객체마다 카운터, 타이머, 그룹 스택이 따로 있습니다.

:::

::: fw flutter

- 호출을 먼저 기록하고 그다음 원래 출력을 실행합니다. 메시지를 터미널에 보내지 않으려면 `passthrough: false`를 지정합니다.
- 기록하다 오류가 나도 lognal이 잡아내므로 로그를 남긴 코드가 멈추지 않습니다.
- 한 메시지를 기록하는 도중에 나온 출력은 기록하지 않습니다. 출력하는 `toString()`이 그런 예입니다.
- `hookDebugPrint`가 반환한 함수는 원래 `debugPrint`를 되돌려 놓습니다. lognal보다 나중에 다른 패키지가 감쌌다면 그 래퍼는 그대로 두고, lognal의 것만 기록을 멈춥니다.
- `LognalConsole`마다 카운터, 타이머, 그룹 스택이 따로 있습니다.

:::

### 옵션 {#options}

::: fw js

`hookConsole`과 `viewer.hookConsole`은 아래 옵션을 모두 받습니다. `createConsole`은 `methods`와 `passthrough`를 뺀 나머지를 받습니다.

| 옵션              | 타입              | 기본값               | 설명                                               |
| ----------------- | ----------------- | -------------------- | -------------------------------------------------- |
| `methods`         | `ConsoleMethod[]` | 지원하는 모든 메서드 | 감쌀 메서드입니다.                                 |
| `passthrough`     | `boolean`         | `true`               | 원래 메서드를 계속 실행할지 정합니다.              |
| `clearStore`      | `boolean`         | `true`               | `console.clear`가 스토어의 항목을 지울지 정합니다. |
| `maxDepth`        | `number`          | `5`                  | [캡처 한도](#capture-limits)를 참고하세요.         |
| `maxProperties`   | `number`          | `100`                | [캡처 한도](#capture-limits)를 참고하세요.         |
| `maxStringLength` | `number`          | `10000`              | [캡처 한도](#capture-limits)를 참고하세요.         |
| `maxNodes`        | `number`          | `2000`               | [캡처 한도](#capture-limits)를 참고하세요.         |

```ts
viewer.hookConsole(console, {
	methods: ['log', 'warn', 'error'],
	passthrough: false,
	maxDepth: 3
});
```

:::

::: fw flutter

후크 셋은 `HookOptions`를, `LognalConsole`은 `RecorderOptions`를 받습니다.

| 옵션                   | 타입              | 기본값         | 설명                                                        |
| ---------------------- | ----------------- | -------------- | ----------------------------------------------------------- |
| `passthrough`          | `bool`            | `true`         | 원래 출력을 계속 실행할지 정합니다.                         |
| `level`                | `LogLevel`        | `LogLevel.log` | 기록하는 줄의 수준입니다. `hookFlutterErrors`는 무시합니다. |
| `recorder`             | `RecorderOptions` | 기본값         | 기록한 호출이 무엇을 저장할지 정합니다.                     |
| `clearStore`           | `bool`            | `true`         | `clear()`가 스토어의 항목을 지울지 정합니다.                |
| `capture.maxDepth`     | `int`             | `5`            | [캡처 한도](#capture-limits)를 참고하세요.                  |
| `capture.expandToJson` | `bool`            | `true`         | `toJson()`을 정의한 객체를 호출해서 펼칠지 정합니다.        |

```dart
hookDebugPrint(
  store,
  options: const HookOptions(passthrough: false, level: LogLevel.debug),
);

final LognalConsole log = LognalConsole(
  store,
  options: const RecorderOptions(capture: CaptureOptions(maxDepth: 3)),
);
```

:::

## 메서드 {#the-methods}

::: fw js

| 메서드                                  | 항목                                                                                                |
| --------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `log`, `info`, `warn`, `error`, `debug` | 같은 이름의 수준으로 메시지를 남깁니다.                                                             |
| `dir`                                   | 첫 번째 인수를 값으로 남깁니다. 문자열은 따옴표로 감싸 보여 줍니다.                                 |
| `dirxml`                                | 모든 인수를 값으로 남깁니다.                                                                        |
| `trace`                                 | 메시지나 `console.trace` 뒤에 호출한 쪽의 스택 트레이스를 붙입니다.                                 |
| `table`                                 | 텍스트 표를 남깁니다. [표](/ko/guide/values#tables)를 참고하세요.                                   |
| `group`, `groupCollapsed`               | 그룹 머리글을 남깁니다. 뒤따르는 항목은 `groupEnd`까지 그 아래로 들여 씁니다.                       |
| `groupEnd`                              | 가장 안쪽 그룹을 닫습니다. 항목은 추가하지 않습니다.                                                |
| `count`                                 | `label: 1`, `label: 2`처럼 남깁니다. 레이블 기본값은 `default`입니다.                               |
| `countReset`                            | 카운터를 0으로 되돌립니다. 카운터가 없으면 경고를 남깁니다.                                         |
| `time`                                  | 타이머를 시작합니다. 같은 레이블의 타이머가 있으면 경고를 남깁니다.                                 |
| `timeLog`                               | `label: 1.234 ms`와 나머지 인수를 남깁니다. 타이머가 없으면 경고를 남깁니다.                        |
| `timeEnd`                               | `label: 1.234 ms`를 남기고 타이머를 멈춥니다. 타이머가 없으면 경고를 남깁니다.                      |
| `assert`                                | 첫 번째 인수가 참이면 아무것도 남기지 않고, 거짓이면 `Assertion failed`로 시작하는 오류를 남깁니다. |
| `clear`                                 | `clearStore`가 `true`이면 항목을 지우고, `Console was cleared` 알림을 추가합니다.                   |

:::

::: fw flutter

`LognalConsole`에도 같은 메서드가 있습니다. 다만 Dart에는 가변 인수가 없으므로 메시지를 먼저 받고 나머지 인수는 리스트로 받습니다.

| 메서드                                  | 항목                                                                                        |
| --------------------------------------- | ------------------------------------------------------------------------------------------- |
| `log`, `info`, `warn`, `error`, `debug` | 같은 이름의 수준으로 메시지를 남깁니다. `error`는 `StackTrace`도 받습니다.                  |
| `dir`                                   | 값을 설명 대신 펼쳐서 남깁니다.                                                             |
| `trace`                                 | 메시지나 `trace` 뒤에 호출한 쪽의 스택 트레이스를 붙입니다.                                 |
| `table`                                 | 텍스트 표를 남깁니다. [표](/ko/guide/values#tables)를 참고하세요.                           |
| `group`, `groupCollapsed`               | 그룹 머리글을 남깁니다. 뒤따르는 항목은 `groupEnd`까지 그 아래로 들여 씁니다.               |
| `groupEnd`                              | 가장 안쪽 그룹을 닫습니다. 항목은 추가하지 않습니다.                                        |
| `count`                                 | `label: 1`, `label: 2`처럼 남깁니다. 레이블 기본값은 `default`입니다.                       |
| `countReset`                            | 카운터를 0으로 되돌립니다. 카운터가 없으면 경고를 남깁니다.                                 |
| `time`                                  | 타이머를 시작합니다. 같은 레이블의 타이머가 있으면 경고를 남깁니다.                         |
| `timeLog`                               | `label: 1.234 ms`와 나머지 인수를 남깁니다. 타이머가 없으면 경고를 남깁니다.                |
| `timeEnd`                               | `label: 1.234 ms`를 남기고 타이머를 멈춥니다. 타이머가 없으면 경고를 남깁니다.              |
| `assertCondition`                       | 조건이 참이면 아무것도 남기지 않고, 거짓이면 `Assertion failed`로 시작하는 오류를 남깁니다. |
| `clear`                                 | `clearStore`가 `true`이면 항목을 지우고, `Log was cleared` 알림을 추가합니다.               |

`assertCondition`이라는 이름은 흉내 낸 콘솔 메서드가 아니라 하는 일을 따릅니다. `assert`는 Dart의 예약어라서 메서드 이름으로 쓸 수 없습니다.

```dart
log
  ..group('Request 4812')
  ..log('Matched route %s', <Object?>['/api/orders/:id'])
  ..groupEnd();
```

:::

수준은 Console Standard 2.3.1절의 심각도 표를 일부러 그대로 따릅니다.

| 수준    | 메서드                                                                               |
| ------- | ------------------------------------------------------------------------------------ |
| `error` | `error`, <Fw js="assert" flutter="assertCondition" code />                           |
| `warn`  | `warn`, 그리고 `countReset`, `time`, `timeLog`, `timeEnd`가 남기는 경고              |
| `info`  | `info`, `count`, `timeEnd`                                                           |
| `log`   | `log`, `dir`, `trace`, `group`, `groupCollapsed`, `timeLog`, `table`, `clear`의 알림 |
| `debug` | `debug`                                                                              |

Console Standard는 `debug`를 log 묶음에 넣지만, lognal은 `log`보다 낮은 별도의 `debug` 수준으로 기록합니다. 그래서 수준 메뉴에서 debug 항목만 따로 숨길 수 있습니다. `table`은 표준의 표에 없으며 log 수준으로 기록합니다.

## 서식 지정자 {#format-specifiers}

첫 번째 인수가 문자열이고 인수가 더 있으면, lognal은 [Console Standard](https://console.spec.whatwg.org/#formatter)에 정의된 방식대로 서식 지정자를 적용합니다.

| 지정자     | 결과                                              |
| ---------- | ------------------------------------------------- |
| `%s`       | 인수를 텍스트로 바꿉니다.                         |
| `%d`, `%i` | 인수를 정수로 바꿉니다.                           |
| `%f`       | 인수를 실수로 바꿉니다.                           |
| `%o`, `%O` | 인수를 타입에 맞게 표시하는 값으로 넣습니다.      |
| `%c`       | 인수의 CSS로 뒤따르는 텍스트에 스타일을 입힙니다. |
| `%%`       | 퍼센트 기호를 씁니다.                             |

남은 인수가 없는 지정자는 적힌 그대로 텍스트에 남습니다. 지정자가 쓰지 않은 인수는 공백으로 구분해 뒤에 붙습니다. 문자열은 일반 텍스트로, 그 밖의 값은 [타입에 맞게 표시하는 값](/ko/guide/values)으로 붙습니다.

::: fw js

```ts
console.log('%s requests in %fs', 128, '2.5');
// 128 requests in 2.5s

console.log('User %o signed in', { id: 42 });
// User {id: 42} signed in

console.log('%cOK%c done', 'color: #43d786; font-weight: bold', '');
```

:::

::: fw flutter

```dart
log.log('%s requests in %fs', <Object?>[128, '2.5']);
// 128 requests in 2.5s

log.log('User %o signed in', <Object?>[<String, int>{'id': 42}]);
// User Map(1) {'id': 42} signed in

log.log('%cOK%c done', <Object?>['color: #43d786; font-weight: bold', '']);
```

:::

### `%c` 스타일 {#styles-from-c}

로그 메시지는 믿을 수 없는 콘텐츠이므로, `%c`는 뷰어가 그릴 수 있는 스타일만 남기고 나머지는 무시합니다.

| CSS 속성                                  | 효과                                               |
| ----------------------------------------- | -------------------------------------------------- |
| `color`                                   | 글자 색입니다.                                     |
| `background`, `background-color`          | 배경색입니다. 값에서 처음 나오는 색을 씁니다.      |
| `font-weight`                             | `bold`, `bolder`, 600 이상의 숫자이면 굵게 씁니다. |
| `font-style`                              | `italic`이나 `oblique`이면 기울여 씁니다.          |
| `text-decoration`, `text-decoration-line` | 밑줄과 취소선입니다.                               |

<Fw js="색은 16진수 색, rgb(), hsl(), oklch() 같은 색 함수, 색 이름 가운데 하나여야 합니다." flutter="색은 3, 4, 6, 8자리 16진수, 두 가지 문법의 rgb()와 rgba(), 기본 색 키워드 가운데 하나여야 합니다." /> `url()`을 비롯한 다른 값은 무시하므로, 로그 메시지가 애플리케이션에 리소스를 불러오게 만들 수 없습니다.

## 값은 호출한 순간에 저장합니다 {#values-are-captured-at-call-time}

메서드를 호출하는 순간 인수마다 순수한 데이터로 복사합니다. 로그를 남긴 뒤 객체를 바꿔도 항목은 바뀌지 않습니다. 카운터, 타이머, 그룹 중첩이 호출 시점의 상태를 따르는 것과 같습니다.

::: fw js

```ts
const user = { name: 'Ada' };

console.log(user);
user.name = 'Grace';
// 항목에는 여전히 {name: 'Ada'}가 보입니다.
```

복사는 다음 규칙을 따릅니다.

- 페이지가 정의한 getter는 호출하지 않습니다. 접근자 속성은 `[Getter]`, `[Setter]`, `[Getter/Setter]`로 표시합니다.
- 날짜, 정규 표현식, 배열, 형식화 배열, Map, Set, DOM 노드는 `instanceof`가 아니라 엔진의 내장 메서드로 알아보고, 프로미스는 `Symbol.toStringTag`로도 알아봅니다. 그래서 iframe에서 온 값도 알아봅니다.
- 자신을 담고 있는 객체를 다시 가리키는 참조는 `[Circular]`로 표시합니다.
- 프로미스는 상태 없이 `Promise`로, `WeakMap`, `WeakSet`, `WeakRef`는 이름만 표시합니다.
- 프록시처럼 읽는 도중 오류를 던지는 값이 있어도 그 오류를 잡아냅니다.

:::

::: fw flutter

```dart
final Map<String, Object?> user = <String, Object?>{'name': 'Ada'};

log.dir(user);
user['name'] = 'Grace';
// 항목에는 여전히 {'name': 'Ada'}가 보입니다.
```

복사는 다음 규칙을 따릅니다.

- 리스트, 세트, 맵, 날짜, 정규 표현식, 오류, 예외, 퓨처, 클로저, 타입은 있는 그대로 알아보고 저장합니다.
- 그 밖의 객체는 읽을 수 없습니다. Dart에서 임의의 값의 필드를 훑으려면 리플렉션이 필요한데 Flutter 빌드에는 들어 있지 않습니다. 그래서 `toJson()`을 쓴 클래스는 그것을 호출해 펼치고, `toString()`을 쓴 클래스는 그 내용을 보여 주고, 나머지는 타입만 보여 줍니다.
- `expandToJson: false`는 그중 첫 번째를 끕니다. `toJson()`이 비싸거나 부수 효과가 있는 타입에 씁니다. 어느 쪽이든 호출은 보호 구간 안에서 일어나므로, 예외가 나도 잃는 것은 그 객체의 속성이지 로그 줄이 아닙니다.
- 자신을 담고 있는 값을 다시 가리키는 참조는 `[Circular]`로 표시합니다. 같음이 아니라 동일성으로 비교하므로, 자신과 같은 사본을 담은 컬렉션은 순환이 아닙니다.
- 퓨처는 상태 없이 `Future`로 표시합니다.
- 웹 릴리스 빌드는 타입 이름을 남기지 않습니다. 그래서 값은 클래스 이름 대신 내용과 `toString()`이 말하는 것을 보여 줍니다.

:::

## 캡처 한도 {#capture-limits}

크거나 깊이 중첩된 값을 복사하는 작업량은 네 가지 한도로 제한합니다.

| 옵션              | 기본값  | 설명                                                                                                                      |
| ----------------- | ------- | ------------------------------------------------------------------------------------------------------------------------- |
| `maxDepth`        | `5`     | 중첩된 값을 몇 단계까지 저장할지 정합니다. 더 깊은 값은 이름만 표시하고 펼칠 수 없습니다.                                 |
| `maxProperties`   | `100`   | 객체, 리스트, 맵, 세트 하나에서 저장하는 속성, 항목, 엔트리의 최대 개수입니다.                                            |
| `maxStringLength` | `10000` | 끝까지 저장하는 문자열의 최대 길이입니다. 더 긴 문자열은 잘라서 `…`로 끝냅니다. 스택 트레이스에도 같은 한도를 적용합니다. |
| `maxNodes`        | `2000`  | 인수 하나에서 저장하는 값의 최대 개수입니다. 중첩된 값도 모두 셉니다.                                                     |

한도 때문에 빠진 부분은 개수를 세어 두고, 펼친 값의 마지막 행에 `… 25 more`처럼 표시합니다. 표는 깊이 2까지만 데이터를 저장합니다.
