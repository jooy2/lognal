---
order: 3
description: lognal의 콘솔 기록 API인 hookConsole, createConsole, ConsoleRecorder, snapshotValue, formatArguments, applyFormat, parseConsoleCss, previewValue의 레퍼런스입니다.
---

# 콘솔 기록

이 API들이 어떻게 함께 쓰이는지는 가이드의 [콘솔 기록](/ko/guide/console)에서 설명합니다.

## hookConsole {#hookconsole}

```ts
hookConsole(target: Console, store: LogStore, options?: HookConsoleOptions): () => void
```

콘솔의 메서드를 바꿔서 모든 호출을 스토어에도 기록합니다. 원래 메서드를 되돌려 놓는 함수를 반환합니다. lognal보다 나중에 다른 스크립트가 메서드를 감쌌다면 그 메서드는 그대로 두고, lognal의 래퍼만 기록을 멈춥니다.

호출은 원래 메서드를 실행하기 전에 기록하고, 기록하다 난 오류는 페이지로 전달하지 않습니다.

```ts
import { LogStore, hookConsole } from 'lognal';

const store = new LogStore();
const unhook = hookConsole(console, store, { methods: ['warn', 'error'] });
```

### HookConsoleOptions {#hookconsoleoptions}

`HookConsoleOptions`는 `Partial<RecorderOptions>`를 확장합니다.

| 옵션                                                                     | 타입                       | 기본값            | 설명                                                                         |
| ------------------------------------------------------------------------ | -------------------------- | ----------------- | ---------------------------------------------------------------------------- |
| `methods`                                                                | `readonly ConsoleMethod[]` | `CONSOLE_METHODS` | 가로챌 메서드입니다.                                                         |
| `passthrough`                                                            | `boolean`                  | `true`            | 원래 메서드를 계속 실행해서 메시지가 브라우저 콘솔에도 나오게 할지 정합니다. |
| `clearStore`, `maxDepth`, `maxProperties`, `maxStringLength`, `maxNodes` |                            |                   | [RecorderOptions](#recorderoptions)를 참고하세요.                            |

## createConsole {#createconsole}

```ts
createConsole(store: LogStore, options?: Partial<RecorderOptions>): LognalConsole
```

전역 콘솔을 건드리지 않고 스토어에 기록하는, 콘솔 메서드를 갖춘 객체를 만듭니다. `viewer.console`도 기본 옵션으로 만든 이런 객체입니다.

```ts
import { LogStore, createConsole } from 'lognal';

const store = new LogStore();
const log = createConsole(store, { maxDepth: 2 });

log.info('Loaded %d items', 12);
```

### LognalConsole {#lognalconsole}

```ts
type LognalConsole = { [Method in ConsoleMethod]: (...args: unknown[]) => void };
```

## ConsoleMethod와 CONSOLE_METHODS {#consolemethod-and-console-methods}

`ConsoleMethod`의 값은 `'log'`, `'info'`, `'warn'`, `'error'`, `'debug'`, `'trace'`, `'dir'`, `'dirxml'`, `'table'`, `'group'`, `'groupCollapsed'`, `'groupEnd'`, `'count'`, `'countReset'`, `'time'`, `'timeLog'`, `'timeEnd'`, `'assert'`, `'clear'` 가운데 하나입니다.

`CONSOLE_METHODS`는 모든 `ConsoleMethod`를 위 순서대로 담은 읽기 전용 배열입니다.

## ConsoleRecorder {#consolerecorder}

```ts
new ConsoleRecorder(store: LogStore, options?: Partial<RecorderOptions>)
```

콘솔 호출을 스토어 항목으로 바꿉니다. 기록기는 Console Standard가 콘솔에 부여하는 상태인 카운터 맵, 타이머 표, 그룹 스택을 유지합니다. `hookConsole`과 `createConsole`도 기록기를 하나씩 만듭니다. 워커에서 넘어온 콘솔 메시지처럼 다른 경로로 들어오는 호출을 기록할 때 직접 쓰세요.

| 메서드                                                                    | 설명                                                                              |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `record(method: ConsoleMethod, args: readonly unknown[], stack?: string)` | 호출 하나를 기록합니다. `stack`은 호출한 쪽의 스택 트레이스이며 `trace`만 씁니다. |
| `setOptions(options: Partial<RecorderOptions>)`                           | 이후에 기록하는 호출의 옵션을 바꿉니다.                                           |

```ts
import { ConsoleRecorder, LogStore, type ConsoleMethod } from 'lognal';

const store = new LogStore();
const recorder = new ConsoleRecorder(store);
const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });

worker.addEventListener('message', (event: MessageEvent<{ method: ConsoleMethod; args: unknown[] }>) => {
	recorder.record(event.data.method, event.data.args);
});
```

### RecorderOptions {#recorderoptions}

`RecorderOptions`는 `CaptureOptions`를 확장합니다.

| 옵션              | 타입      | 기본값  | 설명                                               |
| ----------------- | --------- | ------- | -------------------------------------------------- |
| `clearStore`      | `boolean` | `true`  | `console.clear`가 스토어의 항목을 지울지 정합니다. |
| `maxDepth`        | `number`  | `5`     | [CaptureOptions](#captureoptions)를 참고하세요.    |
| `maxProperties`   | `number`  | `100`   | [CaptureOptions](#captureoptions)를 참고하세요.    |
| `maxStringLength` | `number`  | `10000` | [CaptureOptions](#captureoptions)를 참고하세요.    |
| `maxNodes`        | `number`  | `2000`  | [CaptureOptions](#captureoptions)를 참고하세요.    |

## snapshotValue {#snapshotvalue}

```ts
snapshotValue(value: unknown, options?: Partial<CaptureOptions>): ValueNode
```

호출한 순간의 값을 순수한 데이터로 저장합니다. 결과에는 원래 값의 참조가 없으므로 `postMessage`로 넘기거나 JSON으로 저장할 수 있습니다.

페이지가 정의한 getter는 실행하지 않고, 접근자 속성은 접근자로 기록합니다. 날짜, 정규 표현식, 배열, 형식화 배열, Map, Set, DOM 노드는 `instanceof`가 아니라 엔진의 내장 메서드로 알아보고, 프로미스는 `Symbol.toStringTag`로도 알아보므로, 다른 프레임에서 온 값도 알아봅니다. 한도 때문에 빠진 부분은 노드의 `omitted` 필드에 개수로 남깁니다.

```ts
import { snapshotValue } from 'lognal';

snapshotValue({ id: 1, tags: ['a', 'b'] });
// { kind: 'object', className: 'Object', children: [
//   { key: 'id', keyKind: 'property', value: { kind: 'number', value: '1' } },
//   { key: 'tags', keyKind: 'property', value: { kind: 'array', className: 'Array', size: 2, children: [...] } }
// ] }
```

### CaptureOptions {#captureoptions}

`DEFAULT_CAPTURE_OPTIONS`에 기본값이 들어 있습니다.

| 옵션              | 타입     | 기본값  | 설명                                                                            |
| ----------------- | -------- | ------- | ------------------------------------------------------------------------------- |
| `maxDepth`        | `number` | `5`     | 중첩된 객체를 몇 단계까지 저장할지 정합니다. 더 깊은 객체는 이름만 보여 줍니다. |
| `maxProperties`   | `number` | `100`   | 객체, 배열, Map, Set 하나에서 저장하는 속성, 항목, 엔트리의 최대 개수입니다.    |
| `maxStringLength` | `number` | `10000` | 끝까지 저장하는 문자열의 최대 길이입니다.                                       |
| `maxNodes`        | `number` | `2000`  | 인수 하나에서 저장하는 값의 최대 개수입니다. 중첩된 값도 모두 셉니다.           |

## formatArguments {#formatarguments}

```ts
formatArguments(args: readonly unknown[], capture: ValueCapture): LogPart[]
```

콘솔 호출의 인수를 항목의 파트로 바꿉니다. 인수가 둘 이상이고 첫 번째가 문자열이면 `applyFormat`으로 서식 지정자를 적용합니다. 남은 인수는 공백으로 구분해 뒤에 붙이는데, 문자열은 일반 텍스트로 붙이고 그 밖의 값은 `capture`를 거쳐 붙입니다.

```ts
import { formatArguments, snapshotValue } from 'lognal';

const parts = formatArguments(['%s joined', 'Ada', { id: 7 }], (value) => snapshotValue(value));
// [{ type: 'text', text: 'Ada joined' }, { type: 'text', text: ' ' }, { type: 'value', value: {...} }]
```

## applyFormat {#applyformat}

```ts
applyFormat(args: readonly unknown[], capture: ValueCapture): { parts: LogPart[]; rest: unknown[] }
```

Console Standard의 Formatter 동작을 따라 첫 번째 인수의 서식 지정자를 적용합니다. 메시지의 파트와, 지정자가 쓰지 않은 인수를 반환합니다. `%s`는 `String`으로, `%d`와 `%i`는 `parseInt`로, `%f`는 `parseFloat`로 바꿉니다. `%o`와 `%O`는 값을 `capture`에 넘겨 넣고, `%c`는 뒤따르는 텍스트에 스타일을 입히고, `%%`는 퍼센트 기호를 씁니다. 남은 인수가 없는 지정자는 적힌 그대로 텍스트에 남습니다.

첫 번째 인수가 문자열이 아니면 `parts`는 빈 배열이고 `rest`에 모든 인수가 들어갑니다. `formatArguments`와 달리 문자열 하나만 넘겨도 서식을 적용하므로, 다른 인수가 없어도 `%%`는 `%`가 됩니다.

```ts
import { applyFormat, snapshotValue } from 'lognal';

applyFormat(['%s has %d items', 'cart', 3, 'extra'], (value) => snapshotValue(value));
// { parts: [{ type: 'text', text: 'cart has 3 items' }], rest: ['extra'] }
```

## ValueCapture {#valuecapture}

```ts
type ValueCapture = (value: unknown) => ValueNode;
```

`formatArguments`와 `applyFormat`이 값을 `ValueNode`로 바꿀 때 쓰는 함수입니다. 보통은 원하는 옵션을 넣은 `snapshotValue`를 씁니다.

## parseConsoleCss {#parseconsolecss}

```ts
parseConsoleCss(css: string): TextStyle | undefined
```

`%c`에 넘긴 CSS를 읽고, 뷰어가 그릴 수 있는 `color`, `background`, `background-color`, `font-weight`, `font-style`, `text-decoration`, `text-decoration-line`만 남깁니다. 색은 16진수 색, 색 함수, 색 이름 가운데 하나여야 합니다. 쓸 수 있는 값이 하나도 없으면 `undefined`를 반환합니다.

```ts
import { parseConsoleCss } from 'lognal';

parseConsoleCss('color: tomato; font-weight: bold; background: url(x.png)');
// { color: 'tomato', bold: true }
```

## previewValue {#previewvalue}

```ts
previewValue(node: ValueNode, nested?: boolean): LineTextSpan[]
```

저장한 값의 한 줄 미리 보기를 `{id: 1, name: 'lognal'}`, `(3) [1, 2, 3]` 같은 스타일 조각 배열로 반환합니다. 각 조각은 [`LineTextSpan`](/ko/reference/layout#linetextspan)입니다. `nested: true`이면 다른 미리 보기 안에 들어갈 때처럼 컨테이너를 이름만 보여 줍니다.

```ts
import { previewValue, snapshotValue } from 'lognal';

const text = previewValue(snapshotValue(new Map([['a', 1]])))
	.map((span) => span.text)
	.join('');
// "Map(1) {'a' => 1}"
```
