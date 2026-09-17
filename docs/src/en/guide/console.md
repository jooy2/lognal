---
order: 1
description: Record what your application already prints into a lognal viewer, with the methods, format specifiers and capture limits of each package.
---

# Capturing output

An application already prints. This page is about getting that output into the viewer, and about what happens to the values in it.

## Record what is printed

::: fw js

There are three ways to turn console calls into log entries.

| API                                                | Records calls on                      | The global console                                                 |
| -------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------ |
| `viewer.hookConsole(target?, options?)`            | `console`, or the console you pass    | Wrapped until you call the returned function or dispose the viewer |
| `hookConsole(target, store, options?)`             | The console you pass, into any store  | Wrapped until you call the returned function                       |
| `viewer.console`, `createConsole(store, options?)` | A new object with the console methods | Not touched                                                        |

```ts
import { LogViewer } from 'lognal';

const viewer = new LogViewer(container);

// Mirror the page's console.
const unhook = viewer.hookConsole();

// Write to the viewer only.
viewer.console.log('Only in the viewer');
```

`hookConsole` works without a viewer, so you can start recording before the page has a place to show the log. The store keeps the entries until a viewer is created, up to its `maxEntries` limit.

```ts
import { LogStore, LogViewer, hookConsole } from 'lognal';

const store = new LogStore();

hookConsole(console, store);

// Later:
const viewer = new LogViewer(container, { store });
```

:::

::: fw flutter

Dart prints through three different things, and none of them is one object you can wrap, so there are three hooks and one console of your own.

| API                                  | Records                                                                | The original output                         |
| ------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------- |
| `hookDebugPrint(store, options?)`    | Everything `debugPrint` is given, which is what Flutter prints through | Still runs, unless `passthrough` is off     |
| `runZonedWithLognal(store, body)`    | Everything `print` writes inside `body`                                | Still runs, unless `passthrough` is off     |
| `hookFlutterErrors(store, options?)` | Every error the framework reports, with its stack                      | Still reported, unless `passthrough` is off |
| `LognalConsole(store, options?)`     | Only what you write to it                                              | Not touched                                 |

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

void main() {
  final void Function() unhookPrint = hookDebugPrint(store);
  final void Function() unhookErrors = hookFlutterErrors(store);

  runZonedWithLognal(store, () => runApp(const MyApp()));
}
```

Each hook returns the function that takes it back off.

`print` is the odd one: it is resolved through the current zone rather than through a variable, so it cannot be replaced after the fact. `runZonedWithLognal` runs your code inside a zone whose `print` writes into the store, which is why it wraps `runApp` rather than being installed beside the other two.

None of the three needs a viewer. The store keeps the entries until one is built, up to its `maxEntries` limit, so hooking in `main()` catches everything the application printed while it was starting.

Writing from your own code goes through `LognalConsole`, which touches nothing global:

```dart
final LognalConsole log = LognalConsole(store);

log.info('Connected to %s in %dms', <Object?>['database', 12]);
```

:::

### How a hook behaves

::: fw js

- A call is recorded first, and then the original method runs. Set `passthrough: false` to stop the messages from reaching the browser console.
- An error thrown while recording is caught, so recording never breaks the page.
- A console call made while another call is being recorded, for example from a `toString` method that logs, is not recorded.
- The function returned by `hookConsole` restores the original methods. If another script wrapped a method after lognal did, that script's wrapper stays in place and lognal's wrapper stops recording.
- Each hook, and each object from `createConsole`, has its own counters, timers and group stack.

:::

::: fw flutter

- The call is recorded first, and then the original output runs. Set `passthrough: false` to keep the messages out of the terminal.
- An error thrown while recording is caught, so recording never breaks the code that logged the message.
- A message printed while another is being recorded, for example from a `toString()` that prints, is not recorded.
- The function returned by `hookDebugPrint` puts the original `debugPrint` back. If another package wrapped it after lognal did, that wrapper stays in place and lognal's stops recording.
- Each `LognalConsole` has its own counters, timers and group stack.

:::

### Options

::: fw js

`hookConsole` and `viewer.hookConsole` accept every option below. `createConsole` accepts all of them except `methods` and `passthrough`.

| Option            | Type              | Default                | Description                                                 |
| ----------------- | ----------------- | ---------------------- | ----------------------------------------------------------- |
| `methods`         | `ConsoleMethod[]` | Every supported method | The methods to wrap.                                        |
| `passthrough`     | `boolean`         | `true`                 | Whether the original method still runs.                     |
| `clearStore`      | `boolean`         | `true`                 | Whether `console.clear` removes the entries from the store. |
| `maxDepth`        | `number`          | `5`                    | See [capture limits](#capture-limits).                      |
| `maxProperties`   | `number`          | `100`                  | See [capture limits](#capture-limits).                      |
| `maxStringLength` | `number`          | `10000`                | See [capture limits](#capture-limits).                      |
| `maxNodes`        | `number`          | `2000`                 | See [capture limits](#capture-limits).                      |

```ts
viewer.hookConsole(console, {
	methods: ['log', 'warn', 'error'],
	passthrough: false,
	maxDepth: 3
});
```

:::

::: fw flutter

The three hooks take `HookOptions`, and `LognalConsole` takes `RecorderOptions`.

| Option                 | Type              | Default        | Description                                                             |
| ---------------------- | ----------------- | -------------- | ----------------------------------------------------------------------- |
| `passthrough`          | `bool`            | `true`         | Whether the original output still runs.                                 |
| `level`                | `LogLevel`        | `LogLevel.log` | The level every captured line is given. `hookFlutterErrors` ignores it. |
| `recorder`             | `RecorderOptions` | Defaults       | What a recorded call captures.                                          |
| `clearStore`           | `bool`            | `true`         | Whether `clear()` removes the entries from the store.                   |
| `capture.maxDepth`     | `int`             | `5`            | See [capture limits](#capture-limits).                                  |
| `capture.expandToJson` | `bool`            | `true`         | Whether an object that defines `toJson()` is opened by calling it.      |

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

## The methods

::: fw js

| Method                                  | Entry                                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `log`, `info`, `warn`, `error`, `debug` | A message at the level of the same name.                                                           |
| `dir`                                   | The first argument as a value. A string is shown in quotes.                                        |
| `dirxml`                                | Every argument as a value.                                                                         |
| `trace`                                 | The message, or `console.trace`, followed by the stack trace of the caller.                        |
| `table`                                 | A text table. See [Tables](/guide/values#tables).                                                  |
| `group`, `groupCollapsed`               | A group header. The entries that follow are indented under it until `groupEnd`.                    |
| `groupEnd`                              | Closes the innermost group. It adds no entry.                                                      |
| `count`                                 | `label: 1`, `label: 2` and so on. The label defaults to `default`.                                 |
| `countReset`                            | Resets a counter to 0, or logs a warning when the counter does not exist.                          |
| `time`                                  | Starts a timer, or logs a warning when a timer with that label exists.                             |
| `timeLog`                               | `label: 1.234 ms` followed by the extra arguments, or a warning when the timer does not exist.     |
| `timeEnd`                               | `label: 1.234 ms`, and stops the timer. A warning when the timer does not exist.                   |
| `assert`                                | Nothing when the first argument is truthy. Otherwise an error that starts with `Assertion failed`. |
| `clear`                                 | Removes the entries when `clearStore` is `true`, then adds the notice `Console was cleared`.       |

:::

::: fw flutter

`LognalConsole` has the same set, with Dart's own shapes: the message comes first and the arguments after it follow in a list, because Dart has no variadic call.

| Method                                  | Entry                                                                                          |
| --------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `log`, `info`, `warn`, `error`, `debug` | A message at the level of the same name. `error` also takes a `StackTrace`.                    |
| `dir`                                   | The value, opened rather than described.                                                       |
| `trace`                                 | The message, or `trace`, followed by the stack trace of the caller.                            |
| `table`                                 | A text table. See [Tables](/guide/values#tables).                                              |
| `group`, `groupCollapsed`               | A group header. The entries that follow are indented under it until `groupEnd`.                |
| `groupEnd`                              | Closes the innermost group. It adds no entry.                                                  |
| `count`                                 | `label: 1`, `label: 2` and so on. The label defaults to `default`.                             |
| `countReset`                            | Resets a counter to 0, or logs a warning when the counter does not exist.                      |
| `time`                                  | Starts a timer, or logs a warning when a timer with that label exists.                         |
| `timeLog`                               | `label: 1.234 ms` followed by the extra arguments, or a warning when the timer does not exist. |
| `timeEnd`                               | `label: 1.234 ms`, and stops the timer. A warning when the timer does not exist.               |
| `assertCondition`                       | Nothing when the condition holds. Otherwise an error that starts with `Assertion failed`.      |
| `clear`                                 | Removes the entries when `clearStore` is `true`, then adds the notice `Log was cleared`.       |

`assertCondition` is named for what it does rather than after the console method it mirrors: `assert` is a keyword in Dart and cannot be a method name.

```dart
log
  ..group('Request 4812')
  ..log('Matched route %s', <Object?>['/api/orders/:id'])
  ..groupEnd();
```

:::

The levels follow the severity table in section 2.3.1 of the Console Standard, on purpose:

| Level   | Methods                                                                                     |
| ------- | ------------------------------------------------------------------------------------------- |
| `error` | `error`, <Fw js="assert" flutter="assertCondition" code />                                  |
| `warn`  | `warn`, and the warnings of `countReset`, `time`, `timeLog` and `timeEnd`                   |
| `info`  | `info`, `count`, `timeEnd`                                                                  |
| `log`   | `log`, `dir`, `trace`, `group`, `groupCollapsed`, `timeLog`, `table`, the notice of `clear` |
| `debug` | `debug`                                                                                     |

The Console Standard puts `debug` in the log group, but lognal records it at its own `debug` level, below `log`, so the level menu can hide it on its own. `table` is not in the Standard's table and is recorded at the log level.

## Format specifiers

When the first argument is a string and more arguments follow, lognal applies format specifiers the way the [Console Standard](https://console.spec.whatwg.org/#formatter) describes.

| Specifier  | Result                                                     |
| ---------- | ---------------------------------------------------------- |
| `%s`       | The argument as text.                                      |
| `%d`, `%i` | The argument as an integer.                                |
| `%f`       | The argument as a floating-point number.                   |
| `%o`, `%O` | The argument as a typed value.                             |
| `%c`       | Styles the text that follows with the CSS in the argument. |
| `%%`       | A percent sign.                                            |

A specifier with no argument left stays in the text as written. The arguments the specifiers did not use follow, separated by spaces: strings as plain text, and every other value as a [typed value](/guide/values).

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

### Styles from `%c`

A log message is untrusted content, so `%c` keeps only the styles the viewer can draw and ignores the rest.

| CSS property                              | Effect                                                  |
| ----------------------------------------- | ------------------------------------------------------- |
| `color`                                   | Text color.                                             |
| `background`, `background-color`          | Background color. The first color in the value is used. |
| `font-weight`                             | Bold for `bold`, `bolder` or a number of 600 or more.   |
| `font-style`                              | Italic for `italic` or `oblique`.                       |
| `text-decoration`, `text-decoration-line` | Underline and strikethrough.                            |

<Fw js="A color must be a hex color, a color function such as rgb(), hsl() or oklch(), or a color name." flutter="A color must be a hex color in three, four, six or eight digits, rgb() or rgba() in either syntax, or one of the basic color keywords." /> Anything else is ignored, including `url()`, so a log message cannot make the application load a resource.

## Values are captured at call time

Each argument is copied into plain data when the method is called. Changing an object after logging it does not change the entry, the same way the counter, the timers and the group nesting belong to the moment of the call.

::: fw js

```ts
const user = { name: 'Ada' };

console.log(user);
user.name = 'Grace';
// The entry still shows {name: 'Ada'}.
```

The copy follows these rules:

- Getters defined by the page are never called. An accessor property is shown as `[Getter]`, `[Setter]` or `[Getter/Setter]`.
- Dates, regular expressions, arrays, typed arrays, maps, sets and DOM nodes are recognized with the engine's own methods rather than `instanceof`, and promises also by their `Symbol.toStringTag`. Values from an iframe are recognized too.
- A reference back to an object that contains it is shown as `[Circular]`.
- A promise is shown as `Promise` without its state, and a `WeakMap`, `WeakSet` or `WeakRef` by its name only.
- An error thrown while reading a value, for example by a proxy, is caught.

:::

::: fw flutter

```dart
final Map<String, Object?> user = <String, Object?>{'name': 'Ada'};

log.dir(user);
user['name'] = 'Grace';
// The entry still shows {'name': 'Ada'}.
```

The copy follows these rules:

- A list, set, map, date, regular expression, error, exception, future, closure or type is recognized as what it is and captured.
- An object that is none of those cannot be read: Dart has no way to enumerate the fields of an arbitrary value without reflection, which a Flutter build does not ship. So a class that writes `toJson()` is opened by calling it, one that writes `toString()` shows what it says, and the rest show their type.
- `expandToJson: false` turns the first of those off, for a type whose `toJson()` is expensive or has an effect of its own. The call runs inside a guard either way, so one that throws costs the object's properties and not the log line.
- A reference back to a value that contains it is shown as `[Circular]`, compared by identity, so a collection holding an equal copy of itself is not a cycle.
- A future is shown as `Future` without its state.
- A release build for the web does not keep type names, so a value there shows what it holds and what its `toString()` says rather than the name of its class.

:::

## Capture limits

Four limits bound the work of copying a large or deeply nested value.

| Option            | Default | Description                                                                                                            |
| ----------------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| `maxDepth`        | `5`     | How many levels of nested values are captured. A deeper one is shown by its name and cannot be expanded.               |
| `maxProperties`   | `100`   | The most properties, items or entries captured from one object, list, map or set.                                      |
| `maxStringLength` | `10000` | The longest string captured in full. A longer string is cut and ends with `…`. The limit also applies to stack traces. |
| `maxNodes`        | `2000`  | The most values captured for one argument, counting every nested value.                                                |

What a limit leaves out is counted, and an expanded value ends with a row such as `… 25 more`. A table captures its data with a depth of 2.
