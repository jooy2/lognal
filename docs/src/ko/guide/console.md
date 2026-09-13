---
order: 1
description: hookConsole과 createConsole로 콘솔 호출을 lognal 뷰어에 기록하는 방법과 지원하는 메서드, 서식 지정자, 캡처 한도를 설명합니다.
---

# 콘솔 기록

## 콘솔 호출 기록하기 {#record-console-calls}

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

### 가로챈 콘솔의 동작 {#how-a-hooked-console-behaves}

- 호출을 먼저 기록하고 그다음 원래 메서드를 실행합니다. 메시지를 브라우저 콘솔에 보내지 않으려면 `passthrough: false`를 지정합니다.
- 기록하다 오류가 나도 lognal이 잡아내므로 페이지가 멈추지 않습니다.
- 한 호출을 기록하는 도중에 일어난 콘솔 호출은 기록하지 않습니다. 로그를 남기는 `toString` 메서드가 그런 예입니다.
- `hookConsole`이 반환한 함수는 원래 메서드를 되돌려 놓습니다. lognal보다 나중에 다른 스크립트가 메서드를 감쌌다면 그 스크립트의 래퍼는 그대로 두고, lognal의 래퍼만 기록을 멈춥니다.
- 훅마다, 그리고 `createConsole`로 만든 객체마다 카운터, 타이머, 그룹 스택이 따로 있습니다.

### 옵션 {#options}

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

## 지원하는 메서드 {#supported-methods}

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

수준은 Console Standard 2.3.1절의 심각도 표를 일부러 그대로 따릅니다.

| 수준    | 메서드                                                                                         |
| ------- | ---------------------------------------------------------------------------------------------- |
| `error` | `error`, `assert`                                                                              |
| `warn`  | `warn`, 그리고 `countReset`, `time`, `timeLog`, `timeEnd`가 남기는 경고                        |
| `info`  | `info`, `count`, `timeEnd`                                                                     |
| `log`   | `log`, `dir`, `dirxml`, `trace`, `group`, `groupCollapsed`, `timeLog`, `table`, `clear`의 알림 |
| `debug` | `debug`                                                                                        |

Console Standard는 `debug`를 log 묶음에 넣지만, lognal은 `log`보다 낮은 별도의 `debug` 수준으로 기록합니다. 그래서 수준 메뉴에서 **로그 이상**을 고르면 debug 항목이 숨겨집니다. `table`은 표준의 표에 없으며 log 수준으로 기록합니다. `console.profile` 같은 다른 콘솔 메서드는 건드리지 않습니다.

## 서식 지정자 {#format-specifiers}

첫 번째 인수가 문자열이고 인수가 더 있으면, lognal은 [Console Standard](https://console.spec.whatwg.org/#formatter)에 정의된 방식대로 서식 지정자를 적용합니다.

| 지정자     | 결과                                              |
| ---------- | ------------------------------------------------- |
| `%s`       | 인수를 `String`으로 바꿉니다.                     |
| `%d`, `%i` | 인수를 `parseInt`로 바꿉니다.                     |
| `%f`       | 인수를 `parseFloat`로 바꿉니다.                   |
| `%o`, `%O` | 인수를 타입에 맞게 표시하는 값으로 넣습니다.      |
| `%c`       | 인수의 CSS로 뒤따르는 텍스트에 스타일을 입힙니다. |
| `%%`       | 퍼센트 기호를 씁니다.                             |

남은 인수가 없는 지정자는 적힌 그대로 텍스트에 남습니다. 지정자가 쓰지 않은 인수는 공백으로 구분해 뒤에 붙습니다. 문자열은 일반 텍스트로, 그 밖의 값은 [타입에 맞게 표시하는 값](/ko/guide/values)으로 붙습니다.

```ts
console.log('%s requests in %fs', 128, '2.5');
// 128 requests in 2.5s

console.log('User %o signed in', { id: 42 });
// User {id: 42} signed in

console.log('%cOK%c done', 'color: #43d786; font-weight: bold', '');
```

### `%c` 스타일 {#styles-from-c}

로그 메시지는 믿을 수 없는 콘텐츠이므로, `%c`는 뷰어가 그릴 수 있는 스타일만 남기고 나머지는 무시합니다.

| CSS 속성                                  | 효과                                               |
| ----------------------------------------- | -------------------------------------------------- |
| `color`                                   | 글자 색입니다.                                     |
| `background`, `background-color`          | 배경색입니다. 값에서 처음 나오는 색을 씁니다.      |
| `font-weight`                             | `bold`, `bolder`, 600 이상의 숫자이면 굵게 씁니다. |
| `font-style`                              | `italic`이나 `oblique`이면 기울여 씁니다.          |
| `text-decoration`, `text-decoration-line` | 밑줄과 취소선입니다.                               |

색은 16진수 색, `rgb()`, `hsl()`, `oklch()` 같은 색 함수, 색 이름 가운데 하나여야 합니다. `url()`을 비롯한 다른 값은 무시하므로, 로그 메시지가 페이지에 리소스를 불러오게 만들 수 없습니다.

## 값은 호출한 순간에 저장합니다 {#values-are-captured-at-call-time}

메서드를 호출하는 순간 인수마다 순수한 데이터로 복사합니다. 로그를 남긴 뒤 객체를 바꿔도 항목은 바뀌지 않습니다. 카운터, 타이머, 그룹 중첩이 호출 시점의 상태를 따르는 것과 같습니다.

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

## 캡처 한도 {#capture-limits}

크거나 깊이 중첩된 값을 복사하는 작업량은 네 가지 한도로 제한합니다.

| 옵션              | 기본값  | 설명                                                                                                                      |
| ----------------- | ------- | ------------------------------------------------------------------------------------------------------------------------- |
| `maxDepth`        | `5`     | 중첩된 객체를 몇 단계까지 저장할지 정합니다. 더 깊은 객체는 `{…}`나 `Array(3)`처럼 이름만 표시하고 펼칠 수 없습니다.      |
| `maxProperties`   | `100`   | 객체, 배열, Map, Set 하나에서 저장하는 속성, 항목, 엔트리의 최대 개수이자 요소 하나의 자식 노드 최대 개수입니다.          |
| `maxStringLength` | `10000` | 끝까지 저장하는 문자열의 최대 길이입니다. 더 긴 문자열은 잘라서 `…`로 끝냅니다. 스택 트레이스에도 같은 한도를 적용합니다. |
| `maxNodes`        | `2000`  | 인수 하나에서 저장하는 값의 최대 개수입니다. 중첩된 값도 모두 셉니다.                                                     |

한도 때문에 빠진 부분은 개수를 세어 두고, 펼친 값의 마지막 행에 `… 25 more`처럼 표시합니다. 요소는 속성을 20개까지 저장하고, 속성값은 200자에서 자릅니다. `console.table`은 깊이 2까지만 데이터를 저장합니다.
