---
order: 3
description: Reference for capturing output, including the hooks, LognalConsole, ConsoleRecorder, the value capture, formatArguments, applyFormat and previewValue.
---

# Console capture

See [Capturing output](/guide/console) in the guide for how these fit together.

::: fw js

## hookConsole

```ts
hookConsole(target: Console, store: LogStore, options?: HookConsoleOptions): () => void
```

Replaces the methods of a console so every call is also recorded in a store. Returns a function that restores the original methods. If another script wrapped a method after lognal did, that method is left in place and lognal's wrapper stops recording.

A call is recorded before the original method runs, and an error while recording never reaches the page.

```ts
import { LogStore, hookConsole } from 'lognal';

const store = new LogStore();
const unhook = hookConsole(console, store, { methods: ['warn', 'error'] });
```

### HookConsoleOptions

`HookConsoleOptions` extends `Partial<RecorderOptions>`.

| Option                                                                   | Type                       | Default           | Description                                                                            |
| ------------------------------------------------------------------------ | -------------------------- | ----------------- | -------------------------------------------------------------------------------------- |
| `methods`                                                                | `readonly ConsoleMethod[]` | `CONSOLE_METHODS` | The methods to hook.                                                                   |
| `passthrough`                                                            | `boolean`                  | `true`            | Whether the original method still runs, so messages keep reaching the browser console. |
| `clearStore`, `maxDepth`, `maxProperties`, `maxStringLength`, `maxNodes` |                            |                   | See [RecorderOptions](#recorderoptions).                                               |

## createConsole

```ts
createConsole(store: LogStore, options?: Partial<RecorderOptions>): LognalConsole
```

Creates an object with the console methods that records into a store without touching the global console. `viewer.console` is such an object, created with the default options.

```ts
import { LogStore, createConsole } from 'lognal';

const store = new LogStore();
const log = createConsole(store, { maxDepth: 2 });

log.info('Loaded %d items', 12);
```

### LognalConsole

```ts
type LognalConsole = { [Method in ConsoleMethod]: (...args: unknown[]) => void };
```

:::

::: fw flutter

## The hooks {#hooks}

Dart has no one console to replace, so what an application prints reaches a store through three of them. Each returns a function that stops it, and an error while recording never reaches the code that printed the message.

```dart
void Function() hookDebugPrint(LogStore store, {HookOptions options})
R runZonedWithLognal<R>(LogStore store, R Function() body, {HookOptions options})
void Function() hookFlutterErrors(LogStore store, {HookOptions options})
```

| Function             | What it records                                                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hookDebugPrint`     | Everything `debugPrint` writes, which is what Flutter itself prints through. It is a variable holding a function, so it can be replaced and put back.      |
| `runZonedWithLognal` | Everything `print` writes inside `body`. `print` belongs to the zone rather than to a variable, so it is a zone that catches it rather than a replacement. |
| `hookFlutterErrors`  | Everything `FlutterError.onError` reports: a widget that threw during a build, a layout that overflowed, an image that failed to load.                     |

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final void Function() unhook = hookDebugPrint(store);

runZonedWithLognal(store, () {
  runApp(const MyApp());
});
```

### HookOptions {#hookoptions}

| Option        | Type              | Default                  | Description                                                                                                    |
| ------------- | ----------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------- |
| `recorder`    | `RecorderOptions` | `defaultRecorderOptions` | What a recorded call captures. Only `hookFlutterErrors` captures values; the other two receive formatted text. |
| `passthrough` | `bool`            | `true`                   | Whether the original output still runs, so messages keep reaching the terminal and the IDE.                    |
| `level`       | `LogLevel`        | `LogLevel.log`           | The level every captured line is given. `hookFlutterErrors` ignores it, because what it captures is an error.  |

## LognalConsole {#lognalconsole-flutter}

```dart
LognalConsole(LogStore store, {RecorderOptions options})
LognalConsole.of(ConsoleRecorder recorder)
```

An object with the logging methods, written into a store without touching anything the application already prints. It is the console the npm package hooks, in the shape Dart writes one: a value you hold rather than a global you replace.

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final LognalConsole log = LognalConsole(store);

log.info('Loaded %d items', <Object?>[12]);
```

Each method takes the message first and the rest of the arguments as a list, because Dart has no rest parameters: `log(message, [args])`, `info`, `warn`, `debug`, `error(message, [args, stack])`, `trace([message, args])`, `dir(value)`, `table(data, [columns])`, `group(label, [args])`, `groupCollapsed`, `groupEnd()`, `count([label])`, `countReset([label])`, `time([label])`, `timeLog([label, args])`, `timeEnd([label])`, `assertCondition(condition, [message, args])` and `clear()`.

`recorder` is the recorder behind it, for changing the options it captures with.

:::

## ConsoleMethod and CONSOLE_METHODS

::: fw js

`ConsoleMethod` is one of these strings: `'log'`, `'info'`, `'warn'`, `'error'`, `'debug'`, `'trace'`, `'dir'`, `'dirxml'`, `'table'`, `'group'`, `'groupCollapsed'`, `'groupEnd'`, `'count'`, `'countReset'`, `'time'`, `'timeLog'`, `'timeEnd'`, `'assert'`, `'clear'`.

`CONSOLE_METHODS` is a read-only array with every `ConsoleMethod`, in the order above.

:::

::: fw flutter

`ConsoleMethod` is an enum: `log`, `info`, `warn`, `error`, `debug`, `trace`, `dir`, `table`, `group`, `groupCollapsed`, `groupEnd`, `count`, `countReset`, `time`, `timeLog`, `timeEnd`, `assertCondition`, `clear`.

`consoleMethods` is every one of them in that order, which is `ConsoleMethod.values`. There is no `dirxml`, because there is no DOM to draw as a tree, and `assert` carries a suffix because it is a Dart keyword.

:::

## ConsoleRecorder

```
new ConsoleRecorder(store, options)
```

Turns console calls into store entries. A recorder keeps the state the Console Standard gives a console: the count map, the timer table and the group stack. <Fw js="hookConsole and createConsole each create one." flutter="Every hook and every LognalConsole creates one." /> Use a recorder directly to record calls that arrive another way, such as messages forwarded from <Fw js="a worker" flutter="an isolate" />.

::: fw js

| Method                                                                    | Description                                                                     |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `record(method: ConsoleMethod, args: readonly unknown[], stack?: string)` | Records one call. `stack` is the caller's stack trace, which only `trace` uses. |
| `setOptions(options: Partial<RecorderOptions>)`                           | Changes options for the calls recorded after it.                                |

```ts
import { ConsoleRecorder, LogStore, type ConsoleMethod } from 'lognal';

const store = new LogStore();
const recorder = new ConsoleRecorder(store);
const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });

worker.addEventListener('message', (event: MessageEvent<{ method: ConsoleMethod; args: unknown[] }>) => {
	recorder.record(event.data.method, event.data.args);
});
```

### RecorderOptions

`RecorderOptions` extends `CaptureOptions`.

| Option            | Type      | Default | Description                                                 |
| ----------------- | --------- | ------- | ----------------------------------------------------------- |
| `clearStore`      | `boolean` | `true`  | Whether `console.clear` removes the entries from the store. |
| `maxDepth`        | `number`  | `5`     | See [CaptureOptions](#captureoptions).                      |
| `maxProperties`   | `number`  | `100`   | See [CaptureOptions](#captureoptions).                      |
| `maxStringLength` | `number`  | `10000` | See [CaptureOptions](#captureoptions).                      |
| `maxNodes`        | `number`  | `2000`  | See [CaptureOptions](#captureoptions).                      |

:::

::: fw flutter

| Member                                                                  | Description                                                                     |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `record(ConsoleMethod method, List<Object?> args, {StackTrace? stack})` | Records one call. `stack` is the caller's stack trace, which only `trace` uses. |
| `options`                                                               | The options. Assigning to it changes them for the calls recorded after it.      |
| `store`                                                                 | The store the calls go into.                                                    |

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

### RecorderOptions

| Option       | Type             | Default                 | Description                                                        |
| ------------ | ---------------- | ----------------------- | ------------------------------------------------------------------ |
| `capture`    | `CaptureOptions` | `defaultCaptureOptions` | What a value capture keeps. See [CaptureOptions](#captureoptions). |
| `clearStore` | `bool`           | `true`                  | Whether `clear` removes the entries from the store.                |

`defaultRecorderOptions` holds these defaults. The capture options are nested here rather than flattened, because a Dart class cannot spread another one's fields.

:::

## snapshotValue

::: fw js

```ts
snapshotValue(value: unknown, options?: Partial<CaptureOptions>): ValueNode
```

Captures a value as plain data at the moment of the call. The result holds no reference to the original value, so it can be passed through `postMessage` or saved as JSON.

Getters defined by the page are never run: an accessor property is recorded as an accessor. Dates, regular expressions, arrays, typed arrays, maps, sets and DOM nodes are recognized with the engine's own methods rather than `instanceof`, and promises also by their `Symbol.toStringTag`, so those values are recognized when they come from another frame too. What a limit cuts is counted in the node's `omitted` field.

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

The function is `captureValue`.

```dart
ValueNode captureValue(Object? value, {CaptureOptions options = defaultCaptureOptions})
```

Captures a value as plain data at the moment of the call. The result holds no reference to the original value, so it can be sent to another isolate or saved as JSON.

Dart reads a value without reflection, so what opens is what the value offers: a `List`, `Map`, `Set` or `Iterable` opens into its items, and a class opens when it has a `toJson()`. A class with only a `toString()` is shown as what it says. What a limit cuts is counted in the node's `omitted` field. See [Typed values](/guide/values) for the whole of it.

```dart
import 'package:lognal/lognal.dart';

captureValue(<String, Object?>{'id': 1, 'tags': <String>['a', 'b']});
// ValueNode(kind: ValueKind.map, size: 2, children: [...])
```

:::

### CaptureOptions

<Fw js="DEFAULT_CAPTURE_OPTIONS" flutter="defaultCaptureOptions" code /> holds the defaults.

| Option            | Type                                  | Default | Description                                                                            |
| ----------------- | ------------------------------------- | ------- | -------------------------------------------------------------------------------------- |
| `maxDepth`        | <Fw js="number" flutter="int" code /> | `5`     | How many levels of nested objects are captured. Deeper objects are shown by name only. |
| `maxProperties`   | <Fw js="number" flutter="int" code /> | `100`   | The most properties, items or entries captured from one object, list, map or set.      |
| `maxStringLength` | <Fw js="number" flutter="int" code /> | `10000` | The longest string captured in full.                                                   |
| `maxNodes`        | <Fw js="number" flutter="int" code /> | `2000`  | The most values captured for one argument, counting every nested value.                |

<Fw flutter="expandToJson, a bool that defaults to true, decides whether a class with a toJson() is opened into what it returns. Turning it off shows every such class by its type name." />

## formatArguments

```
formatArguments(args, capture)
```

Turns the arguments of a console call into the parts of an entry. With more than one argument and a string first, the format specifiers are applied with `applyFormat`. The remaining arguments follow, separated by spaces: strings as plain text, and everything else through `capture`.

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

## applyFormat

::: fw js

```ts
applyFormat(args: readonly unknown[], capture: ValueCapture): { parts: LogPart[]; rest: unknown[] }
```

:::

::: fw flutter

```dart
FormattedMessage applyFormat(List<Object?> args, ValueCapture capture)
```

`FormattedMessage` holds `parts` and `rest`, where a TypeScript function returns an object literal.

:::

Applies the format specifiers in the first argument, following the Formatter operation of the Console Standard. Returns the parts of the message and the arguments the specifiers did not use. `%s` converts to text, `%d` and `%i` to an integer, `%f` to a floating-point number, `%o` and `%O` insert the value through `capture`, `%c` styles the text that follows it, and `%%` writes a percent sign. A specifier with no argument left stays in the text as written.

When the first argument is not a string, `parts` is empty and `rest` holds every argument. Unlike `formatArguments`, `applyFormat` also formats a single string, so `%%` becomes `%` even without other arguments.

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

## ValueCapture

::: fw js

```ts
type ValueCapture = (value: unknown) => ValueNode;
```

The function `formatArguments` and `applyFormat` use to turn a value into a `ValueNode`. `snapshotValue` with the options you want is the usual choice.

:::

::: fw flutter

```dart
typedef ValueCapture = ValueNode Function(Object? value);
```

The function `formatArguments` and `applyFormat` use to turn a value into a `ValueNode`. `captureValue` is the usual choice, and a closure over it carries the options you want.

:::

## parseConsoleCss

```
parseConsoleCss(css)
```

Reads the CSS given to `%c` and keeps what the viewer can draw: `color`, `background` and `background-color`, `font-weight`, `font-style`, `text-decoration` and `text-decoration-line`. A color must be a hex color, a color function or a color name. Returns nothing when nothing usable is left.

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

A color is resolved here rather than later, because there is no stylesheet to resolve it against. `parseCssColor` is the part that does it, and it is public for the same reason.

:::

## previewValue

```
previewValue(node, nested)
```

Returns the one-line preview of a captured value as styled spans, such as `{id: 1, name: 'lognal'}` or `(3) [1, 2, 3]`. Each span is a [`LineTextSpan`](/reference/layout#linetextspan). With `nested` set, containers are shown by name only, the way they appear inside another preview.

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

`isExpandable(node)` tells whether a value has anything to open, which is what draws the triangle.

:::
