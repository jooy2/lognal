---
order: 2
description: lognal이 객체, 리스트, 맵, 세트, 오류를 보여 주는 방식과 값을 펼치고 접는 방법, 표와 그룹, 반복 메시지가 표시되는 모습을 설명합니다.
---

# 값 표시

로그에 넘긴 인수 가운데 문자열이 아닌 것은 모두 값으로 표시합니다. 로그를 남긴 순간의 복사본을 타입에 맞는 서식으로 보여 주고, 자식이 있는 값은 펼치거나 접을 수 있습니다.

::: fw js

<ClientOnly>
  <LiveViewer preset="values" />
</ClientOnly>

:::

::: fw flutter

<ClientOnly>
  <FlutterDemo demo="collections" :height="380" />
</ClientOnly>

:::

## 미리 보기 {#previews}

값은 처음에 한 줄짜리 미리 보기로 나타납니다.

::: fw js

| 값                                        | 미리 보기                                            |
| ----------------------------------------- | ---------------------------------------------------- |
| 다른 값 안의 문자열                       | `'text'`                                             |
| 숫자, bigint                              | `42`, `-0`, `NaN`, `10n`                             |
| 불리언, `null`, `undefined`               | `true`, `null`, `undefined`                          |
| 심벌                                      | `Symbol(token)`                                      |
| 함수, 클래스                              | `ƒ handleClick()`, `class User`                      |
| 날짜                                      | `2026-09-13T05:03:09.120Z`                           |
| 정규 표현식                               | `/ab+c/gi`                                           |
| 오류                                      | `TypeError: Expected a string`                       |
| 배열, 형식화 배열                         | `(3) [1, 2, 3]`, `Uint8Array(4) [1, 2, 3, 4]`        |
| 객체, 클래스 인스턴스                     | `{id: 1, name: 'lognal'}`, `User {id: 1}`            |
| Map, Set                                  | `Map(2) {'a' => 1, 'b' => {…}}`, `Set(2) {'x', 'y'}` |
| `WeakMap`, `WeakSet`, `WeakRef`, 프로미스 | `WeakMap`, `Promise`                                 |
| DOM 요소                                  | `<nav class="menu">`                                 |
| 순환 참조, 접근자                         | `[Circular]`, `[Getter]`                             |

:::

::: fw flutter

| 값                         | 미리 보기                                           |
| -------------------------- | --------------------------------------------------- |
| 다른 값 안의 문자열        | `'text'`                                            |
| `int`, `double`, `BigInt`  | `42`, `-0.0`, `NaN`, `10`                           |
| `bool`, `null`             | `true`, `null`                                      |
| `Symbol`                   | `Symbol("token")`                                   |
| 클로저, `Type`             | `ƒ (int) => String`, `class User`                   |
| `DateTime`                 | `2026-09-13T05:03:09.120Z`                          |
| `RegExp`                   | `/ab+c/`                                            |
| 오류, 예외                 | `StateError: The order was already paid`            |
| `List`, `Iterable`         | `(3) [1, 2, 3]`, `Uint8List(4) [1, 2, 3, 4]`        |
| `toJson()`이 있는 클래스   | `Account {id: 1, name: 'lognal'}`                   |
| `toString()`만 있는 클래스 | `Session(9f3a)`                                     |
| `Map`, `Set`               | `Map(2) {'a': 1, 'b': Map(1)}`, `Set(2) {'x', 'y'}` |
| `Future`                   | `Future`                                            |
| 순환 참조                  | `[Circular]`                                        |

:::

미리 보기 안에서 중첩된 값은 <Fw js="{…}나 Array(2)" flutter="Map(1)이나 List(2)" />처럼 이름만 보여 주고, 50자보다 긴 문자열은 자릅니다. 미리 보기가 100자를 넘으면 나머지 자식은 `…`로 대신합니다. 날짜는 ISO 8601 형식으로 씁니다.

메시지로 직접 넘긴 문자열은 값이 아니라 일반 텍스트이므로 따옴표가 붙지 않습니다. <Fw js="console.dir('text')" flutter="log.dir('text')" code />로 남기면 따옴표가 붙습니다.

## 펼치고 접기 {#expand-and-collapse}

자식이 있는 값 앞에는 작은 삼각형이 있습니다. 삼각형이나 미리 보기를 클릭하거나 탭하면 값이 펼쳐지고, 한 번 더 누르면 접힙니다. 자식은 한 행씩 두 칸 들여 씁니다.

- 속성은 `name: value` 형태입니다.
- 리스트 항목은 `0: value` 형태입니다.
- 맵 엔트리는 <Fw js="key => value" flutter="key: value" code /> 형태이고, 세트 항목에는 키가 없습니다.
- 오류는 스택 트레이스를 먼저 보여 주고, 그 뒤에 오류 자신의 속성을 보여 줍니다. ::: fw js
- 요소의 자식 뒤에는 `</nav>` 같은 닫는 태그가 붙습니다. :::

`maxDepth` 한도에 닿은 값은 자식을 저장하지 않았으므로 삼각형이 없습니다. 다른 한도로 빠진 부분은 `… 25 more` 같은 마지막 행으로 표시합니다. [캡처 한도](/ko/guide/console#capture-limits)를 참고하세요.

::: fw flutter

캡처가 열지 못한 객체에도 삼각형이 없습니다. 이유는 다릅니다. Dart는 리플렉션 없이 임의의 값의 필드를 읽지 못합니다. `toJson()`을 쓴 클래스는 펼쳐지고, `toString()`만 쓴 클래스는 그 내용을 한 행으로 보여 줍니다.

:::

뷰어는 항목마다 어떤 값이 펼쳐져 있는지 기억합니다. 이 상태는 항목이 스토어에서 빠지거나 스토어를 비울 때까지 유지됩니다. 텍스트를 선택하고 복사할 때는 펼친 값의 행도 함께 들어갑니다. [항목 메뉴](/ko/guide/viewer#entry-menu)의 **텍스트로 복사**는 펼쳤는지와 상관없이 값을 모두 복사하고, **모두 펼치기**와 **모두 접기**는 항목의 값을 한 번에 펼치거나 접습니다.

## 오류 {#errors}

메시지로 직접 넘긴 오류는 펼친 상태로 추가되므로 스택 트레이스가 바로 보입니다. 다른 값 안에 들어 있는 오류는 접힌 상태로 시작합니다.

::: fw js

```ts
try {
	JSON.parse('{');
} catch (error) {
	console.error('Could not read the settings', error);
}
```

첫 행에는 `SyntaxError: `와 메시지가 나옵니다. 그 아래에는 흐린 색으로 스택 트레이스가 나오고, 이어서 `code` 같은 오류의 추가 속성과 `Error` 생성자에 넘긴 `cause`가 나옵니다.

:::

::: fw flutter

```dart
try {
  jsonDecode('{');
} on FormatException catch (error, stack) {
  log.error(error, const <Object?>[], stack);
}
```

첫 행에는 `FormatException: `과 메시지가 나옵니다. 그 아래에는 흐린 색으로 스택 트레이스가 나옵니다. Dart는 오류의 속성을 읽을 수 없으므로, 그 뒤에 나오는 것은 오류에 `toJson()`이 있을 때 그것이 돌려준 내용입니다.

`hookFlutterErrors`가 잡은 빌드 실패도 여기에 프레임워크가 보고한 스택과 맥락과 함께 나옵니다.

:::

오류 수준의 항목은 오류 색으로 그리고 행에 옅은 배경을 깔며, 여백에 표시를 찍습니다. 경고도 경고 색으로 같은 처리를 합니다. [입력 줄](/ko/guide/viewer#input-line)에 입력한 명령이 예외를 던지면 그 오류도 오류 수준 항목으로 출력합니다.

## 표 {#tables}

<Fw js="console.table" flutter="log.table" code />은 데이터를 괘선 문자로 그린 텍스트 표로 보여 줍니다. 캔버스는 괘선 문자를 선으로 그리므로 행이 바뀌어도 테두리가 이어집니다.

::: fw js

```ts
console.table([
	{ name: 'Alice', role: 'admin', active: true },
	{ name: '김철수', role: 'editor', active: false }
]);
```

:::

::: fw flutter

```dart
log.table(<Map<String, Object?>>[
  <String, Object?>{'name': 'Alice', 'role': 'admin', 'active': true},
  <String, Object?>{'name': '김철수', 'role': 'editor', 'active': false},
]);
```

:::

```text
┌─────────┬──────────┬──────────┬────────┐
│ (index) │ name     │ role     │ active │
├─────────┼──────────┼──────────┼────────┤
│ 0       │ 'Alice'  │ 'admin'  │ true   │
│ 1       │ '김철수' │ 'editor' │ false  │
└─────────┴──────────┴──────────┴────────┘
```

- `(index)` 열에는 각 행의 속성 이름이나 인덱스가 들어갑니다.
- 행 값의 키가 각각 열이 됩니다. 두 번째 인수로 키 목록을 넘기면 열을 고를 수 있습니다.
- 객체가 아닌 행은 `Values` 열에 들어갑니다. 열을 직접 고르면 이 열은 넣지 않습니다.
- 표는 모든 행을 한 줄에 유지합니다. 표가 뷰어보다 넓으면 줄을 바꾸지 않고 로그가 옆으로 스크롤됩니다.
- 표는 행 100개, 열 20개까지 보여 주고, 칸 하나는 40칸에서 자릅니다. 빠진 행 수는 표 아래에 적습니다.
- 컬렉션이 아닌 값은 평소대로 기록합니다. 행이 없는 값은 일반 값으로 기록합니다.

## 그룹 {#groups}

<Fw js="console.group" flutter="log.group" code />은 굵은 머리글을 추가하고, 짝이 되는 <Fw js="console.groupEnd" flutter="log.groupEnd" code />까지의 항목을 단계마다 두 칸씩 들여 씁니다. <Fw js="console.groupCollapsed" flutter="log.groupCollapsed" code />는 접힌 상태로 시작하는 머리글을 추가합니다.

::: fw js

```ts
console.group('Request %s', '/api/users');
console.log('Headers', { accept: 'application/json' });
console.groupCollapsed('Response');
console.log('Status', 200);
console.groupEnd();
console.groupEnd();
```

:::

::: fw flutter

```dart
log
  ..group('Request %s', <Object?>['/api/users'])
  ..log('Headers', <Object?>[
    <String, String>{'accept': 'application/json'},
  ])
  ..groupCollapsed('Response')
  ..log('Status', <Object?>[200])
  ..groupEnd()
  ..groupEnd();
```

:::

머리글을 클릭하거나 탭하면 그룹 안의 항목을 숨기거나 다시 보여 줍니다. 항목이 숨겨져 있으면 상태 표시줄에 `로그 20개 중 12개`처럼 두 숫자가 나옵니다. 코드에서 그룹을 여닫으려면 머리글 항목의 id로 `store.setCollapsed(id, collapsed)`를 호출합니다.

수준 필터는 그룹 머리글을 항상 남겨 두므로, 필터를 통과한 항목이 머리글 아래에 그대로 놓입니다. 텍스트 필터는 그룹 머리글도 다른 항목과 똑같이 검사합니다.

## 반복 메시지 {#repeated-messages}

바로 앞 메시지와 똑같은 메시지가 오면, 스토어는 새 항목을 추가하지 않고 그 항목의 반복 횟수를 올립니다. 여백에 횟수가 배지로 표시되고, 99를 넘으면 `99+`로 보여 줍니다.

수준, 그룹, 텍스트와 스타일, 단순한 값이 모두 같으면 똑같은 메시지로 봅니다. 오류나 자식이 있는 값이 들어 있는 메시지는 절대 합치지 않습니다.

이런 메시지를 어떻게 처리할지는 `mergeRepeats`가 정합니다.

::: fw js

| 값           | 동작                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------- |
| `true`       | 메시지를 버리고 앞 항목의 횟수를 올립니다. 기본값입니다.                                    |
| `'collapse'` | 메시지를 모두 남깁니다. 연속된 묶음은 첫 항목과 횟수로 보이고, 펼치면 각 메시지가 나옵니다. |
| `false`      | 메시지마다 항목을 하나씩 만듭니다.                                                          |

```ts
const viewer = new LogViewer(container, {
	core: { mergeRepeats: 'collapse' }
});
```

:::

::: fw flutter

| 값                      | 동작                                                                                        |
| ----------------------- | ------------------------------------------------------------------------------------------- |
| `MergeRepeats.merge`    | 메시지를 버리고 앞 항목의 횟수를 올립니다. 기본값입니다.                                    |
| `MergeRepeats.collapse` | 메시지를 모두 남깁니다. 연속된 묶음은 첫 항목과 횟수로 보이고, 펼치면 각 메시지가 나옵니다. |
| `MergeRepeats.keep`     | 메시지마다 항목을 하나씩 만듭니다.                                                          |

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(
    core: CoreOptions(mergeRepeats: MergeRepeats.collapse),
  ),
);
```

이름이 `RepeatMode`가 아니라 `MergeRepeats`인 이유는 `RepeatMode`가 `package:flutter/widgets.dart`에 이미 있기 때문입니다.

:::

<Fw js="'collapse'" flutter="MergeRepeats.collapse" code />를 쓰면 묶음이 접힌 상태로 시작해 `a a b a a`가 횟수 2인 `a`, `b`, 횟수 2인 `a`로 보입니다. 횟수 배지를 클릭하면 묶음의 메시지가 모두 나오고, 다시 클릭하면 숨겨집니다. 항목 메뉴의 **반복 펼치기**와 **반복 접기**는 키보드와 터치 화면에서 같은 일을 합니다. 펼쳐 둔 묶음은 같은 메시지가 계속 들어와도 펼쳐진 채로 있습니다.

이 모드에서는 메시지 하나하나가 `maxEntries`에 포함되므로, 같은 메시지가 쏟아지면 다른 메시지가 쏟아질 때와 똑같이 스토어가 찹니다.
