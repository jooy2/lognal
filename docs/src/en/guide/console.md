---
order: 1
description: Record console calls into a lognal viewer with hookConsole or createConsole, with the supported methods, format specifiers and capture limits.
---

# Console capture

## Record console calls

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

### How a hooked console behaves

- A call is recorded first, and then the original method runs. Set `passthrough: false` to stop the messages from reaching the browser console.
- An error thrown while recording is caught, so recording never breaks the page.
- A console call made while another call is being recorded, for example from a `toString` method that logs, is not recorded.
- The function returned by `hookConsole` restores the original methods. If another script wrapped a method after lognal did, that script's wrapper stays in place and lognal's wrapper stops recording.
- Each hook, and each object from `createConsole`, has its own counters, timers and group stack.

### Options

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

## Supported methods

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

The levels follow the severity table in section 2.3.1 of the Console Standard, on purpose:

| Level   | Methods                                                                                               |
| ------- | ----------------------------------------------------------------------------------------------------- |
| `error` | `error`, `assert`                                                                                     |
| `warn`  | `warn`, and the warnings of `countReset`, `time`, `timeLog` and `timeEnd`                             |
| `info`  | `info`, `count`, `timeEnd`                                                                            |
| `log`   | `log`, `dir`, `dirxml`, `trace`, `group`, `groupCollapsed`, `timeLog`, `table`, the notice of `clear` |
| `debug` | `debug`                                                                                               |

The Console Standard puts `debug` in the log group, but lognal records it at its own `debug` level, below `log`, so the **Log and above** choice in the level menu hides it. `table` is not in the Standard's table and is recorded at the log level. Other console methods, such as `console.profile`, are left alone.

## Format specifiers

When the first argument is a string and more arguments follow, lognal applies format specifiers the way the [Console Standard](https://console.spec.whatwg.org/#formatter) describes.

| Specifier  | Result                                                     |
| ---------- | ---------------------------------------------------------- |
| `%s`       | The argument converted with `String`.                      |
| `%d`, `%i` | The argument converted with `parseInt`.                    |
| `%f`       | The argument converted with `parseFloat`.                  |
| `%o`, `%O` | The argument as a typed value.                             |
| `%c`       | Styles the text that follows with the CSS in the argument. |
| `%%`       | A percent sign.                                            |

A specifier with no argument left stays in the text as written. The arguments the specifiers did not use follow, separated by spaces: strings as plain text, and every other value as a [typed value](/guide/values).

```ts
console.log('%s requests in %fs', 128, '2.5');
// 128 requests in 2.5s

console.log('User %o signed in', { id: 42 });
// User {id: 42} signed in

console.log('%cOK%c done', 'color: #43d786; font-weight: bold', '');
```

### Styles from `%c`

A log message is untrusted content, so `%c` keeps only the styles the viewer can draw and ignores the rest.

| CSS property                              | Effect                                                  |
| ----------------------------------------- | ------------------------------------------------------- |
| `color`                                   | Text color.                                             |
| `background`, `background-color`          | Background color. The first color in the value is used. |
| `font-weight`                             | Bold for `bold`, `bolder` or a number of 600 or more.   |
| `font-style`                              | Italic for `italic` or `oblique`.                       |
| `text-decoration`, `text-decoration-line` | Underline and strikethrough.                            |

A color must be a hex color, a color function such as `rgb()`, `hsl()` or `oklch()`, or a color name. Anything else is ignored, including `url()`, so a log message cannot make the page load a resource.

## Values are captured at call time

Each argument is copied into plain data when the method is called. Changing an object after logging it does not change the entry, the same way the counter, the timers and the group nesting belong to the moment of the call.

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

## Capture limits

Four limits bound the work of copying a large or deeply nested value.

| Option            | Default | Description                                                                                                                                |
| ----------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `maxDepth`        | `5`     | How many levels of nested objects are captured. A deeper object is shown by its name, such as `{…}` or `Array(3)`, and cannot be expanded. |
| `maxProperties`   | `100`   | The most properties, items or entries captured from one object, array, map or set, and the most child nodes of an element.                 |
| `maxStringLength` | `10000` | The longest string captured in full. A longer string is cut and ends with `…`. The limit also applies to stack traces.                     |
| `maxNodes`        | `2000`  | The most values captured for one argument, counting every nested value.                                                                    |

What a limit leaves out is counted, and an expanded value ends with a row such as `… 25 more`. An element keeps at most 20 attributes, each cut to 200 characters. `console.table` captures its data with a depth of 2.
