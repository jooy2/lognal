---
order: 2
description: Reference for LogStore, the container that holds log entries, with its options, methods, change notifications and write options.
---

# LogStore

::: fw js

```ts
import { LogStore } from 'lognal';

const store = new LogStore({ maxEntries: 50000 });
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore(
  options: const LogStoreOptions(maxEntries: 50000),
);
```

:::

Holds log entries in the order they were added. The store knows nothing about how entries are displayed, so one store can feed several viewers, or collect messages before any viewer exists.

## Constructor

```
new LogStore(options)
```

<Fw js="Every option left out keeps its default." flutter="LogStoreOptions is a value with defaults of its own, so a store with no arguments is a store with the defaults." />

## LogStoreOptions

::: fw js

| Option         | Type         | Default | Description                                                                                                                          |
| -------------- | ------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `maxEntries`   | `number`     | `10000` | The most entries the store keeps. Once it is full, the oldest entry is dropped for every new one. Use `Infinity` to keep everything. |
| `mergeRepeats` | `RepeatMode` | `true`  | What happens to a message identical to the one before it. See [`RepeatMode`](#repeatmode).                                           |

`DEFAULT_STORE_OPTIONS` holds these defaults.

:::

::: fw flutter

| Option         | Type           | Default              | Description                                                                                       |
| -------------- | -------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| `maxEntries`   | `int`          | `10000`              | The most entries the store keeps. Once it is full, the oldest entry is dropped for every new one. |
| `mergeRepeats` | `MergeRepeats` | `MergeRepeats.merge` | What happens to a message identical to the one before it. See [`MergeRepeats`](#repeatmode).      |

`defaultStoreOptions` holds these defaults, and `copyWith` returns a copy with one of them replaced.

:::

## Properties

| Property  | Type                                  | Description                                                                           |
| --------- | ------------------------------------- | ------------------------------------------------------------------------------------- |
| `size`    | <Fw js="number" flutter="int" code /> | The number of entries held.                                                           |
| `firstId` | <Fw js="number" flutter="int" code /> | The id of the oldest entry held. When the store is empty, the id the next entry gets. |
| `lastId`  | <Fw js="number" flutter="int" code /> | The id of the newest entry held, or `firstId - 1` when the store is empty.            |

Ids start at 1 and increase by one for every new entry. They are never reused, even after `clear()`.

## Methods

::: fw js

| Method                                                  | Returns                     | Description                                                                                                                                                                        |
| ------------------------------------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `getOptions()`                                          | `Readonly<LogStoreOptions>` | Returns the options.                                                                                                                                                               |
| `setOptions(options: Partial<LogStoreOptions>)`         | `void`                      | Changes options. Lowering `maxEntries` drops the oldest entries right away.                                                                                                        |
| `at(index: number)`                                     | `LogEntry \| undefined`     | Returns the entry at a position, where 0 is the oldest entry held.                                                                                                                 |
| `get(id: number)`                                       | `LogEntry \| undefined`     | Returns the entry with an id, if the store still holds it.                                                                                                                         |
| `toArray()`                                             | `LogEntry[]`                | Returns every entry, oldest first.                                                                                                                                                 |
| `[Symbol.iterator]()`                                   | `Iterator<LogEntry>`        | Iterates over the entries, oldest first.                                                                                                                                           |
| `append(init: LogEntryInit \| readonly LogEntryInit[])` | `LogEntry[]`                | Adds one entry or several, and returns only the entries it created. A message merged into the entry before it raises that entry's `repeat` count and is not in the returned array. |
| `write(text: string, options?: WriteOptions)`           | `LogEntry \| undefined`     | Adds text as one entry. Line breaks stay inside the entry. Returns the new entry, or the entry the text was merged into.                                                           |
| `writeLines(text: string, options?: WriteOptions)`      | `LogEntry[]`                | Adds text as one entry per line. Returns the entries that were created.                                                                                                            |
| `clear()`                                               | `void`                      | Removes every entry.                                                                                                                                                               |
| `setCollapsed(id: number, collapsed: boolean)`          | `void`                      | Collapses or expands a group header, or the first entry of a run of identical messages, which hides or shows its members.                                                          |
| `isRunHead(entry: LogEntry)`                            | `boolean`                   | Whether the entry is the first of a run of identical messages the store still holds, so the run can be opened.                                                                     |
| `subscribe(listener: StoreListener)`                    | `() => void`                | Calls a listener for every change. Returns a function that removes the listener.                                                                                                   |

:::

::: fw flutter

| Method                                            | Returns           | Description                                                                                                                                             |
| ------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `options`                                         | `LogStoreOptions` | The options. Assigning to it changes them, and a lower `maxEntries` drops the oldest entries right away.                                                |
| `at(int index)`                                   | `LogEntry?`       | The entry at a position, where 0 is the oldest entry held.                                                                                              |
| `get(int id)`                                     | `LogEntry?`       | The entry with an id, if the store still holds it.                                                                                                      |
| `toList()`                                        | `List<LogEntry>`  | Every entry, oldest first.                                                                                                                              |
| `append(List<LogEntryInit> inits)`                | `List<LogEntry>`  | Adds entries and returns only the ones it created. A message merged into the entry before it raises that entry's `repeat` count and is not in the list. |
| `add(LogEntryInit init)`                          | `LogEntry?`       | Adds one entry and returns it, or the entry it was merged into.                                                                                         |
| `write(String text, [WriteOptions options])`      | `LogEntry?`       | Adds text as one entry. Line breaks stay inside the entry.                                                                                              |
| `writeLines(String text, [WriteOptions options])` | `List<LogEntry>`  | Adds text as one entry per line. Returns the entries that were created.                                                                                 |
| `clear()`                                         | `void`            | Removes every entry.                                                                                                                                    |
| `setCollapsed(int id, bool collapsed)`            | `void`            | Collapses or expands a group header, or the first entry of a run of identical messages, which hides or shows its members.                               |
| `isRunHead(LogEntry entry)`                       | `bool`            | Whether the entry is the first of a run of identical messages the store still holds, so the run can be opened.                                          |
| `subscribe(StoreListener listener)`               | `void Function()` | Calls a listener for every change. Returns a function that removes the listener.                                                                        |

There is no iterator and no `getOptions`. `toList()` gives a list to walk, and `options` is a property.

:::

::: fw js

```ts
import { LogStore } from 'lognal';

const store = new LogStore();

store.append({
	level: 'warn',
	parts: [
		{ type: 'text', text: 'Slow query ' },
		{ type: 'text', text: '1.8s', token: 'number' }
	]
});

const stop = store.subscribe((change) => {
	if (change.type === 'append') {
		document.title = `${store.size} log entries`;
	}
});
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

store.add(
  const LogEntryInit(
    level: LogLevel.warn,
    parts: <LogPart>[
      TextPart('Slow query '),
      TextPart('1.8s', token: StyleToken.number),
    ],
  ),
);

final void Function() stop = store.subscribe((StoreChange change) {
  if (change is StoreAppend) {
    debugPrint('${store.size} log entries');
  }
});
```

:::

## WriteOptions

The options of `write` and `writeLines`, on the store and on the viewer.

::: fw js

| Option   | Type                    | Default     | Description                                                                                                        |
| -------- | ----------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------ |
| `level`  | `LogLevel`              | `'log'`     | The level of the entries.                                                                                          |
| `kind`   | `LogKind`               | `'message'` | What the entries represent.                                                                                        |
| `time`   | `number`                | Now         | The time of the entries, in epoch milliseconds.                                                                    |
| `groups` | `readonly number[]`     | `[]`        | The ids of the open groups the entries belong to, outermost first.                                                 |
| `token`  | `StyleToken`            | None        | A semantic color for the text.                                                                                     |
| `style`  | `TextStyle`             | None        | Explicit styling for the text. Ignored when `ansi` is set.                                                         |
| `ansi`   | `boolean \| AnsiParser` | `false`     | Whether ANSI escape codes in the text become styles. Pass a parser to keep the style running across calls.         |
| `wrap`   | `boolean`               | `true`      | Set to `false` to keep every line of the text on one row, for text such as a table. A wider line scrolls sideways. |

:::

::: fw flutter

| Option   | Type            | Default           | Description                                                                                                        |
| -------- | --------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| `level`  | `LogLevel`      | `LogLevel.log`    | The level of the entries.                                                                                          |
| `kind`   | `LogKind`       | `LogKind.message` | What the entries represent.                                                                                        |
| `time`   | `DateTime?`     | Now               | The time of the entries.                                                                                           |
| `groups` | `List<int>`     | `[]`              | The ids of the open groups the entries belong to, outermost first.                                                 |
| `token`  | `StyleToken?`   | `null`            | A semantic color for the text.                                                                                     |
| `style`  | `LogTextStyle?` | `null`            | Explicit styling for the text. Ignored when `ansi` is on.                                                          |
| `ansi`   | `bool`          | `false`           | Whether ANSI escape codes in the text become styles.                                                               |
| `parser` | `AnsiParser?`   | `null`            | A parser of your own, to keep the style running across calls. Setting it turns `ansi` on.                          |
| `wrap`   | `bool`          | `true`            | Set to `false` to keep every line of the text on one row, for text such as a table. A wider line scrolls sideways. |

`ansi` and `parser` are two fields here where the npm package has one, because a Dart field holds one type.

:::

## RepeatMode

::: fw js

```ts
type RepeatMode = boolean | 'collapse';
```

What happens to a message identical to the one before it. `true` drops the message and raises the repeat count of the entry before it, `'collapse'` keeps every message and shows the run as one collapsed entry with its count, and `false` gives every message an entry of its own.

:::

::: fw flutter

```dart
enum MergeRepeats { merge, collapse, keep }
```

What happens to a message identical to the one before it. `merge` drops the message and raises the repeat count of the entry before it, `collapse` keeps every message and shows the run as one collapsed entry with its count, and `keep` gives every message an entry of its own.

The enum is `MergeRepeats` rather than `RepeatMode`, because `RepeatMode` is already a name in `package:flutter/widgets.dart`.

:::

Only entries of the message kind join a run, and never when they hold an error or a value with children. See [Repeated messages](/guide/values#repeated-messages).

## StoreChange

The value a store listener receives.

::: fw js

| `type`     | Other fields                              | Sent when                                                                                                               |
| ---------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `'append'` | `entries: readonly LogEntry[]`            | Entries were added.                                                                                                     |
| `'update'` | `entry: LogEntry`, `visibility?: boolean` | An entry's repeat count or collapsed state changed. `visibility` marks a change that also hides or shows other entries. |
| `'trim'`   | `count: number`                           | The oldest entries were dropped because of `maxEntries`.                                                                |
| `'clear'`  | None                                      | Every entry was removed.                                                                                                |

```ts
type StoreListener = (change: StoreChange) => void;
```

:::

::: fw flutter

`StoreChange` is a sealed class, so a `switch` over it is checked for completeness.

| Class         | Fields                              | Sent when                                                                                                               |
| ------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `StoreAppend` | `List<LogEntry> entries`            | Entries were added.                                                                                                     |
| `StoreUpdate` | `LogEntry entry`, `bool visibility` | An entry's repeat count or collapsed state changed. `visibility` marks a change that also hides or shows other entries. |
| `StoreTrim`   | `int count`                         | The oldest entries were dropped because of `maxEntries`.                                                                |
| `StoreClear`  | None                                | Every entry was removed.                                                                                                |

```dart
typedef StoreListener = void Function(StoreChange change);
```

:::

An append change comes before the trim change it causes.
