---
order: 3
description: 출력을 기록하는 훅과 LognalConsole, ConsoleRecorder, 값 저장, formatArguments, applyFormat, previewValue의 레퍼런스입니다.
---

# 콘솔 기록

이 API들이 어떻게 함께 쓰이는지는 가이드의 [출력 기록](/ko/guide/console)에서 설명합니다.

::: fw js

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

:::

::: fw flutter

## 훅 {#hooks}

Dart에는 바꿔 끼울 콘솔이 하나로 있지 않으므로, 애플리케이션이 출력한 것은 세 가지 훅을 거쳐 스토어에 닿습니다. 저마다 멈추는 함수를 반환하고, 기록하다 난 오류는 메시지를 출력한 코드로 전달하지 않습니다.

```dart
void Function() hookDebugPrint(LogStore store, {HookOptions options})
R runZonedWithLognal<R>(LogStore store, R Function() body, {HookOptions options})
void Function() hookFlutterErrors(LogStore store, {HookOptions options})
```

| 함수                 | 기록하는 것                                                                                                                 |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `hookDebugPrint`     | `debugPrint`가 쓰는 모든 것입니다. Flutter 자신이 이걸로 출력하고, 함수를 담은 변수이므로 바꿔 끼웠다가 되돌릴 수 있습니다. |
| `runZonedWithLognal` | `body` 안에서 `print`가 쓰는 모든 것입니다. `print`는 변수가 아니라 존에 속하므로, 바꿔 끼우는 대신 존이 받아 냅니다.       |
| `hookFlutterErrors`  | `FlutterError.onError`가 알리는 모든 것입니다. 빌드 중에 던진 위젯, 넘친 레이아웃, 실패한 이미지가 여기로 옵니다.           |

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final void Function() unhook = hookDebugPrint(store);

runZonedWithLognal(store, () {
  runApp(const MyApp());
});
```

### HookOptions {#hookoptions}

| 옵션          | 타입              | 기본값                   | 설명                                                                                                                                  |
| ------------- | ----------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `recorder`    | `RecorderOptions` | `defaultRecorderOptions` | 기록한 호출이 무엇을 저장할지 정합니다. 값을 저장하는 것은 `hookFlutterErrors`뿐이고, 나머지 둘은 이미 서식이 끝난 텍스트를 받습니다. |
| `passthrough` | `bool`            | `true`                   | 원래 출력을 계속 실행해서 메시지가 터미널과 IDE에도 나오게 할지 정합니다.                                                             |
| `level`       | `LogLevel`        | `LogLevel.log`           | 기록한 줄에 부여할 수준입니다. `hookFlutterErrors`는 오류를 기록하므로 이 값을 무시합니다.                                            |

## LognalConsole {#lognalconsole-flutter}

```dart
LognalConsole(LogStore store, {RecorderOptions options})
LognalConsole.of(ConsoleRecorder recorder)
```

애플리케이션이 이미 출력하는 것을 건드리지 않고 스토어에 기록하는, 로그 메서드를 갖춘 객체입니다. npm 패키지가 가로채는 그 콘솔을 Dart식으로 쓴 것입니다. 바꿔 끼우는 전역이 아니라 직접 들고 있는 값입니다.

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final LognalConsole log = LognalConsole(store);

log.info('Loaded %d items', <Object?>[12]);
```

Dart에는 나머지 매개변수가 없으므로 메서드마다 메시지를 먼저 받고 나머지 인수는 리스트로 받습니다. `log(message, [args])`, `info`, `warn`, `debug`, `error(message, [args, stack])`, `trace([message, args])`, `dir(value)`, `table(data, [columns])`, `group(label, [args])`, `groupCollapsed`, `groupEnd()`, `count([label])`, `countReset([label])`, `time([label])`, `timeLog([label, args])`, `timeEnd([label])`, `assertCondition(condition, [message, args])`, `clear()`가 있습니다.

`recorder`는 그 뒤의 기록기이고, 저장 옵션을 바꿀 때 씁니다.

:::

## ConsoleMethod와 CONSOLE_METHODS {#consolemethod-and-console-methods}

::: fw js

`ConsoleMethod`의 값은 `'log'`, `'info'`, `'warn'`, `'error'`, `'debug'`, `'trace'`, `'dir'`, `'dirxml'`, `'table'`, `'group'`, `'groupCollapsed'`, `'groupEnd'`, `'count'`, `'countReset'`, `'time'`, `'timeLog'`, `'timeEnd'`, `'assert'`, `'clear'` 가운데 하나입니다.

`CONSOLE_METHODS`는 모든 `ConsoleMethod`를 위 순서대로 담은 읽기 전용 배열입니다.

:::

::: fw flutter

`ConsoleMethod`는 enum입니다. `log`, `info`, `warn`, `error`, `debug`, `trace`, `dir`, `table`, `group`, `groupCollapsed`, `groupEnd`, `count`, `countReset`, `time`, `timeLog`, `timeEnd`, `assertCondition`, `clear`가 있습니다.

`consoleMethods`는 이를 그 순서대로 담은 `ConsoleMethod.values`입니다. `dirxml`은 없습니다. 트리로 그릴 DOM이 없기 때문입니다. `assert`에 접미사가 붙은 것은 Dart의 키워드이기 때문입니다.

:::

## ConsoleRecorder {#consolerecorder}

```
new ConsoleRecorder(store, options)
```

콘솔 호출을 스토어 항목으로 바꿉니다. 기록기는 Console Standard가 콘솔에 부여하는 상태인 카운터 맵, 타이머 표, 그룹 스택을 유지합니다. <Fw js="hookConsole과 createConsole도 기록기를 하나씩 만듭니다." flutter="훅과 LognalConsole도 저마다 기록기를 하나씩 만듭니다." /> <Fw js="워커" flutter="아이솔레이트" />에서 넘어온 메시지처럼 다른 경로로 들어오는 호출을 기록할 때 직접 쓰세요.

::: fw js

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

:::

::: fw flutter

| 멤버                                                                    | 설명                                                                              |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `record(ConsoleMethod method, List<Object?> args, {StackTrace? stack})` | 호출 하나를 기록합니다. `stack`은 호출한 쪽의 스택 트레이스이며 `trace`만 씁니다. |
| `options`                                                               | 옵션입니다. 대입하면 이후에 기록하는 호출에 적용됩니다.                           |
| `store`                                                                 | 호출이 들어가는 스토어입니다.                                                     |

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final ConsoleRecorder recorder = ConsoleRecorder(store);

receivePort.listen((Object? message) {
  final Map<String, Object?> data = message! as Map<String, Object?>;

  recorder.record(
    ConsoleMethod.values.byName(data['method']! as String),
    data['args']! as List<Object?>,
  );
});
```

### RecorderOptions {#recorderoptions-flutter}

| 옵션         | 타입             | 기본값                  | 설명                                                                                   |
| ------------ | ---------------- | ----------------------- | -------------------------------------------------------------------------------------- |
| `capture`    | `CaptureOptions` | `defaultCaptureOptions` | 값을 저장할 때 무엇을 남길지 정합니다. [CaptureOptions](#captureoptions)를 참고하세요. |
| `clearStore` | `bool`           | `true`                  | `clear`가 스토어의 항목을 지울지 정합니다.                                             |

`defaultRecorderOptions`에 이 기본값이 들어 있습니다. 저장 옵션이 평평하게 펼쳐지지 않고 안에 들어 있는 것은, Dart의 클래스가 다른 클래스의 필드를 펼쳐 담을 수 없기 때문입니다.

:::

## snapshotValue {#snapshotvalue}

::: fw js

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

:::

::: fw flutter

함수 이름은 `captureValue`입니다.

```dart
ValueNode captureValue(Object? value, {CaptureOptions options = defaultCaptureOptions})
```

호출한 순간의 값을 순수한 데이터로 저장합니다. 결과에는 원래 값의 참조가 없으므로 다른 아이솔레이트로 넘기거나 JSON으로 저장할 수 있습니다.

Dart는 리플렉션 없이 값을 읽으므로, 값이 내어 주는 만큼만 펼칩니다. `List`, `Map`, `Set`, `Iterable`은 항목으로 펼치고, 클래스는 `toJson()`이 있을 때 펼칩니다. `toString()`만 있는 클래스는 그 설명을 보여 줍니다. 한도 때문에 빠진 부분은 노드의 `omitted` 필드에 개수로 남깁니다. 자세한 내용은 [타입에 맞게 표시하는 값](/ko/guide/values)에 있습니다.

```dart
import 'package:lognal/lognal.dart';

captureValue(<String, Object?>{'id': 1, 'tags': <String>['a', 'b']});
// ValueNode(kind: ValueKind.map, size: 2, children: [...])
```

:::

### CaptureOptions {#captureoptions}

<Fw js="DEFAULT_CAPTURE_OPTIONS" flutter="defaultCaptureOptions" code />에 기본값이 들어 있습니다.

| 옵션              | 타입                                  | 기본값  | 설명                                                                            |
| ----------------- | ------------------------------------- | ------- | ------------------------------------------------------------------------------- |
| `maxDepth`        | <Fw js="number" flutter="int" code /> | `5`     | 중첩된 객체를 몇 단계까지 저장할지 정합니다. 더 깊은 객체는 이름만 보여 줍니다. |
| `maxProperties`   | <Fw js="number" flutter="int" code /> | `100`   | 객체, 리스트, Map, Set 하나에서 저장하는 속성, 항목, 엔트리의 최대 개수입니다.  |
| `maxStringLength` | <Fw js="number" flutter="int" code /> | `10000` | 끝까지 저장하는 문자열의 최대 길이입니다.                                       |
| `maxNodes`        | <Fw js="number" flutter="int" code /> | `2000`  | 인수 하나에서 저장하는 값의 최대 개수입니다. 중첩된 값도 모두 셉니다.           |

<Fw flutter="기본값이 true인 bool 필드 expandToJson은 toJson()이 있는 클래스를 그 결과로 펼칠지 정합니다. 끄면 그런 클래스도 타입 이름만 보여 줍니다." />

## formatArguments {#formatarguments}

```
formatArguments(args, capture)
```

콘솔 호출의 인수를 항목의 파트로 바꿉니다. 인수가 둘 이상이고 첫 번째가 문자열이면 `applyFormat`으로 서식 지정자를 적용합니다. 남은 인수는 공백으로 구분해 뒤에 붙이는데, 문자열은 일반 텍스트로 붙이고 그 밖의 값은 `capture`를 거쳐 붙입니다.

::: fw js

```ts
import { formatArguments, snapshotValue } from 'lognal';

const parts = formatArguments(['%s joined', 'Ada', { id: 7 }], (value) => snapshotValue(value));
// [{ type: 'text', text: 'Ada joined' }, { type: 'text', text: ' ' }, { type: 'value', value: {...} }]
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final List<LogPart> parts = formatArguments(
  <Object?>['%s joined', 'Ada', <String, Object?>{'id': 7}],
  captureValue,
);
// [TextPart('Ada joined'), TextPart(' '), ValuePart(...)]
```

:::

## applyFormat {#applyformat}

::: fw js

```ts
applyFormat(args: readonly unknown[], capture: ValueCapture): { parts: LogPart[]; rest: unknown[] }
```

:::

::: fw flutter

```dart
FormattedMessage applyFormat(List<Object?> args, ValueCapture capture)
```

TypeScript 쪽이 객체 리터럴로 돌려주는 것을 여기서는 `parts`와 `rest`를 담은 `FormattedMessage`로 돌려줍니다.

:::

Console Standard의 Formatter 동작을 따라 첫 번째 인수의 서식 지정자를 적용합니다. 메시지의 파트와, 지정자가 쓰지 않은 인수를 반환합니다. `%s`는 텍스트로, `%d`와 `%i`는 정수로, `%f`는 부동소수점 수로 바꿉니다. `%o`와 `%O`는 값을 `capture`에 넘겨 넣고, `%c`는 뒤따르는 텍스트에 스타일을 입히고, `%%`는 퍼센트 기호를 씁니다. 남은 인수가 없는 지정자는 적힌 그대로 텍스트에 남습니다.

첫 번째 인수가 문자열이 아니면 `parts`는 비어 있고 `rest`에 모든 인수가 들어갑니다. `formatArguments`와 달리 문자열 하나만 넘겨도 서식을 적용하므로, 다른 인수가 없어도 `%%`는 `%`가 됩니다.

::: fw js

```ts
import { applyFormat, snapshotValue } from 'lognal';

applyFormat(['%s has %d items', 'cart', 3, 'extra'], (value) => snapshotValue(value));
// { parts: [{ type: 'text', text: 'cart has 3 items' }], rest: ['extra'] }
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

applyFormat(<Object?>['%s has %d items', 'cart', 3, 'extra'], captureValue);
// FormattedMessage([TextPart('cart has 3 items')], ['extra'])
```

:::

## ValueCapture {#valuecapture}

::: fw js

```ts
type ValueCapture = (value: unknown) => ValueNode;
```

`formatArguments`와 `applyFormat`이 값을 `ValueNode`로 바꿀 때 쓰는 함수입니다. 보통은 원하는 옵션을 넣은 `snapshotValue`를 씁니다.

:::

::: fw flutter

```dart
typedef ValueCapture = ValueNode Function(Object? value);
```

`formatArguments`와 `applyFormat`이 값을 `ValueNode`로 바꿀 때 쓰는 함수입니다. 보통은 `captureValue`를 쓰고, 옵션이 필요하면 그것을 감싼 클로저를 넘깁니다.

:::

## parseConsoleCss {#parseconsolecss}

```
parseConsoleCss(css)
```

`%c`에 넘긴 CSS를 읽고, 뷰어가 그릴 수 있는 `color`, `background`, `background-color`, `font-weight`, `font-style`, `text-decoration`, `text-decoration-line`만 남깁니다. 색은 16진수 색, 색 함수, 색 이름 가운데 하나여야 합니다. 쓸 수 있는 값이 하나도 없으면 아무것도 반환하지 않습니다.

::: fw js

```ts
import { parseConsoleCss } from 'lognal';

parseConsoleCss('color: tomato; font-weight: bold; background: url(x.png)');
// { color: 'tomato', bold: true }
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

parseConsoleCss('color: tomato; font-weight: bold; background: url(x.png)');
// LogTextStyle(color: RgbTextColor(0xffff6347), bold: true)
```

색을 나중이 아니라 여기서 값으로 바꿉니다. 나중에 대조할 스타일시트가 없기 때문입니다. 그 일을 하는 `parseCssColor`도 같은 이유로 공개되어 있습니다.

:::

## previewValue {#previewvalue}

```
previewValue(node, nested)
```

저장한 값의 한 줄 미리 보기를 `{id: 1, name: 'lognal'}`, `(3) [1, 2, 3]` 같은 스타일 조각 배열로 반환합니다. 각 조각은 [`LineTextSpan`](/ko/reference/layout#linetextspan)입니다. `nested`를 켜면 다른 미리 보기 안에 들어갈 때처럼 컨테이너를 이름만 보여 줍니다.

::: fw js

```ts
import { previewValue, snapshotValue } from 'lognal';

const text = previewValue(snapshotValue(new Map([['a', 1]])))
	.map((span) => span.text)
	.join('');
// "Map(1) {'a' => 1}"
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final String text = previewValue(captureValue(<String, int>{'a': 1}))
    .map((LineTextSpan span) => span.text)
    .join();
// "Map(1) {'a': 1}"
```

`isExpandable(node)`는 값에 펼칠 것이 있는지 알려 주며, 삼각형을 그릴지 정하는 것이 이 함수입니다.

:::
