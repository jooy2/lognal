---
order: 3
description: Reference for console capture in lognal, including hookConsole, createConsole, ConsoleRecorder, snapshotValue, formatArguments, applyFormat, parseConsoleCss and previewValue.
---

# Console capture

See [Console capture](/guide/console) in the guide for how these fit together.

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

## ConsoleMethod and CONSOLE_METHODS

`ConsoleMethod` is one of these strings: `'log'`, `'info'`, `'warn'`, `'error'`, `'debug'`, `'trace'`, `'dir'`, `'dirxml'`, `'table'`, `'group'`, `'groupCollapsed'`, `'groupEnd'`, `'count'`, `'countReset'`, `'time'`, `'timeLog'`, `'timeEnd'`, `'assert'`, `'clear'`.

`CONSOLE_METHODS` is a read-only array with every `ConsoleMethod`, in the order above.

## ConsoleRecorder

```ts
new ConsoleRecorder(store: LogStore, options?: Partial<RecorderOptions>)
```

Turns console calls into store entries. A recorder keeps the state the Console Standard gives a console: the count map, the timer table and the group stack. `hookConsole` and `createConsole` each create one. Use a recorder directly to record calls that arrive another way, such as console messages forwarded from a worker.

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

## snapshotValue

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

### CaptureOptions

`DEFAULT_CAPTURE_OPTIONS` holds the defaults.

| Option            | Type     | Default | Description                                                                            |
| ----------------- | -------- | ------- | -------------------------------------------------------------------------------------- |
| `maxDepth`        | `number` | `5`     | How many levels of nested objects are captured. Deeper objects are shown by name only. |
| `maxProperties`   | `number` | `100`   | The most properties, items or entries captured from one object, array, map or set.     |
| `maxStringLength` | `number` | `10000` | The longest string captured in full.                                                   |
| `maxNodes`        | `number` | `2000`  | The most values captured for one argument, counting every nested value.                |

## formatArguments

```ts
formatArguments(args: readonly unknown[], capture: ValueCapture): LogPart[]
```

Turns the arguments of a console call into the parts of an entry. With more than one argument and a string first, the format specifiers are applied with `applyFormat`. The remaining arguments follow, separated by spaces: strings as plain text, and everything else through `capture`.

```ts
import { formatArguments, snapshotValue } from 'lognal';

const parts = formatArguments(['%s joined', 'Ada', { id: 7 }], (value) => snapshotValue(value));
// [{ type: 'text', text: 'Ada joined' }, { type: 'text', text: ' ' }, { type: 'value', value: {...} }]
```

## applyFormat

```ts
applyFormat(args: readonly unknown[], capture: ValueCapture): { parts: LogPart[]; rest: unknown[] }
```

Applies the format specifiers in the first argument, following the Formatter operation of the Console Standard. Returns the parts of the message and the arguments the specifiers did not use. `%s` converts with `String`, `%d` and `%i` with `parseInt`, `%f` with `parseFloat`, `%o` and `%O` insert the value through `capture`, `%c` styles the text that follows it, and `%%` writes a percent sign. A specifier with no argument left stays in the text as written.

When the first argument is not a string, `parts` is empty and `rest` holds every argument. Unlike `formatArguments`, `applyFormat` also formats a single string, so `%%` becomes `%` even without other arguments.

```ts
import { applyFormat, snapshotValue } from 'lognal';

applyFormat(['%s has %d items', 'cart', 3, 'extra'], (value) => snapshotValue(value));
// { parts: [{ type: 'text', text: 'cart has 3 items' }], rest: ['extra'] }
```

## ValueCapture

```ts
type ValueCapture = (value: unknown) => ValueNode;
```

The function `formatArguments` and `applyFormat` use to turn a value into a `ValueNode`. `snapshotValue` with the options you want is the usual choice.

## parseConsoleCss

```ts
parseConsoleCss(css: string): TextStyle | undefined
```

Reads the CSS given to `%c` and keeps what the viewer can draw: `color`, `background` and `background-color`, `font-weight`, `font-style`, `text-decoration` and `text-decoration-line`. A color must be a hex color, a color function or a color name. Returns `undefined` when nothing usable is left.

```ts
import { parseConsoleCss } from 'lognal';

parseConsoleCss('color: tomato; font-weight: bold; background: url(x.png)');
// { color: 'tomato', bold: true }
```

## previewValue

```ts
previewValue(node: ValueNode, nested?: boolean): LineTextSpan[]
```

Returns the one-line preview of a captured value as styled spans, such as `{id: 1, name: 'lognal'}` or `(3) [1, 2, 3]`. Each span is a [`LineTextSpan`](/reference/layout#linetextspan). With `nested: true`, containers are shown by name only, the way they appear inside another preview.

```ts
import { previewValue, snapshotValue } from 'lognal';

const text = previewValue(snapshotValue(new Map([['a', 1]])))
	.map((span) => span.text)
	.join('');
// "Map(1) {'a' => 1}"
```
