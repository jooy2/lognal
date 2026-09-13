---
order: 2
description: lognal이 객체, 배열, Map, Set, 오류, DOM 요소를 보여 주는 방식과 값을 펼치고 접는 방법, 표와 그룹, 반복 메시지가 표시되는 모습을 설명합니다.
---

# 값 표시

콘솔 메서드에 넘긴 인수 가운데 문자열이 아닌 것은 모두 값으로 표시합니다. 로그를 남긴 순간의 복사본을 타입에 맞는 서식으로 보여 주고, 자식이 있는 값은 펼치거나 접을 수 있습니다.

<ClientOnly>
  <LiveViewer preset="values" />
</ClientOnly>

## 미리 보기 {#previews}

값은 처음에 한 줄짜리 미리 보기로 나타납니다.

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

미리 보기 안에서 중첩된 객체는 `{…}`나 `Array(2)`처럼 이름만 보여 주고, 50자보다 긴 문자열은 자릅니다. 미리 보기가 100자를 넘으면 나머지 자식은 `…`로 대신합니다. 날짜는 ISO 8601 형식의 UTC 시각으로 씁니다.

콘솔 메서드에 직접 넘긴 문자열은 값이 아니라 일반 텍스트이므로 따옴표가 붙지 않습니다. `console.dir('text')`로 남기면 따옴표가 붙습니다.

## 펼치고 접기 {#expand-and-collapse}

자식이 있는 값 앞에는 작은 삼각형이 있습니다. 삼각형이나 미리 보기를 클릭하거나 탭하면 값이 펼쳐지고, 한 번 더 누르면 접힙니다. 자식은 한 행씩 두 칸 들여 씁니다.

- 객체 속성은 `name: value` 형태이고, 심벌 키는 `Symbol(key)`로 보여 줍니다.
- 배열 항목은 `0: value` 형태입니다.
- Map 엔트리는 `key => value` 형태이고, Set 항목에는 키가 없습니다.
- 요소의 자식 뒤에는 `</nav>` 같은 닫는 태그가 붙습니다.
- 오류는 스택 트레이스를 먼저 보여 주고, 그 뒤에 오류 객체의 속성과 `cause`를 보여 줍니다.

`maxDepth` 한도에 닿은 값은 자식을 저장하지 않았으므로 삼각형이 없습니다. 다른 한도로 빠진 부분은 `… 25 more` 같은 마지막 행으로 표시합니다. [캡처 한도](/ko/guide/console#capture-limits)를 참고하세요.

뷰어는 항목마다 어떤 값이 펼쳐져 있는지 기억합니다. 이 상태는 항목이 스토어에서 빠지거나 스토어를 비울 때까지 유지됩니다. 텍스트를 선택하고 복사할 때는 펼친 값의 행도 함께 들어갑니다. [항목 메뉴](/ko/guide/viewer#entry-menu)의 **텍스트로 복사**는 펼쳤는지와 상관없이 값을 모두 복사하고, **모두 펼치기**와 **모두 접기**는 항목의 값을 한 번에 펼치거나 접습니다.

## 오류 {#errors}

`console.error(error)`처럼 콘솔 메서드에 직접 넘긴 오류는 펼친 상태로 추가되므로 스택 트레이스가 바로 보입니다. 다른 값 안에 들어 있는 오류는 접힌 상태로 시작합니다.

```ts
try {
	JSON.parse('{');
} catch (error) {
	console.error('Could not read the settings', error);
}
```

첫 행에는 `SyntaxError: `와 메시지가 나옵니다. 그 아래로 스택 트레이스가 흐린 색으로 나오고, `code`처럼 오류에 따로 붙은 속성과 `Error` 생성자에 넘긴 `cause`가 이어집니다.

error 수준의 항목은 오류 색으로 쓰고 행 배경에 옅은 색을 깔며, 왼쪽 여백에 표시를 붙입니다. warn 수준의 항목도 경고 색으로 같은 방식을 따릅니다. [입력 줄](/ko/guide/viewer#input-line)에 입력한 명령이 오류를 던지면 그 오류도 error 수준의 항목으로 출력합니다.

## 표 {#tables}

`console.table`은 데이터를 상자 그리기 문자로 만든 텍스트 표로 보여 줍니다. 캔버스는 이 문자를 선으로 그리므로 행이 바뀌어도 테두리가 끊기지 않습니다.

```ts
console.table([
	{ name: 'Alice', role: 'admin', active: true },
	{ name: '김철수', role: 'editor', active: false }
]);
```

```text
┌─────────┬──────────┬──────────┬────────┐
│ (index) │ name     │ role     │ active │
├─────────┼──────────┼──────────┼────────┤
│ 0       │ 'Alice'  │ 'admin'  │ true   │
│ 1       │ '김철수' │ 'editor' │ false  │
└─────────┴──────────┴──────────┴────────┘
```

- `(index)` 열에는 각 행의 속성 이름이나 배열 인덱스가 들어갑니다.
- 행 객체의 키마다 열이 하나씩 생깁니다. 두 번째 인수로 키 배열을 넘기면 원하는 열만 고를 수 있습니다.
- 객체가 아닌 행은 `Values` 열에 들어갑니다. 열을 직접 고르면 이 열은 빠집니다.
- 표의 행은 줄 바꿈하지 않습니다. 표가 뷰어보다 넓으면 표를 줄 바꿈하는 대신 로그를 가로로 스크롤합니다.
- 표는 행을 100개, 열을 20개까지 보여 주고, 셀 내용은 너비 40칸에서 자릅니다. 빠진 행의 개수는 표 아래에 표시합니다.
- 객체가 아닌 값은 평소처럼 기록합니다. 행이 없는 객체는 값으로 기록합니다.

## 그룹 {#groups}

`console.group`은 굵은 머리글을 추가하고, 짝이 맞는 `console.groupEnd`까지의 항목을 단계마다 두 칸씩 들여 씁니다. `console.groupCollapsed`는 접힌 상태로 시작하는 머리글을 추가합니다.

```ts
console.group('Request %s', '/api/users');
console.log('Headers', { accept: 'application/json' });
console.groupCollapsed('Response');
console.log('Status', 200);
console.groupEnd();
console.groupEnd();
```

머리글을 클릭하거나 탭하면 그룹 안의 항목을 숨기거나 다시 보여 줍니다. 항목이 숨겨져 있는 동안 상태 표시줄은 `12 of 20 entries`처럼 두 숫자를 함께 보여 줍니다. 코드에서 그룹을 펼치거나 접으려면 머리글 항목의 id로 `store.setCollapsed(id, collapsed)`를 호출합니다.

수준 필터를 걸어도 그룹 머리글은 보이므로, 필터를 통과한 항목이 머리글 아래에 그대로 남습니다. 텍스트 필터는 그룹 머리글도 다른 항목과 똑같이 검사합니다.

## 반복 메시지 {#repeated-messages}

바로 앞 메시지와 똑같은 메시지가 들어오면 스토어는 새 항목을 추가하지 않고 앞 항목의 반복 횟수를 올립니다. 왼쪽 여백에는 횟수가 배지로 표시되고, 99를 넘으면 `99+`로 나옵니다.

수준, 그룹, 텍스트와 스타일, 단순한 값이 모두 같으면 똑같은 메시지로 봅니다. 오류나 자식이 있는 값을 담은 메시지는 합치지 않습니다. 합치기를 끄려면 `mergeRepeats` 옵션을 씁니다.

```ts
const viewer = new LogViewer(container, {
	core: { mergeRepeats: false }
});
```
