---
order: 2
description: Reference for LogStore, the container that holds log entries, with its options, methods, change notifications and write options.
---

# LogStore

```ts
import { LogStore } from 'lognal';

const store = new LogStore({ maxEntries: 50000 });
```

Holds log entries in the order they were added. The store knows nothing about how entries are displayed, so one store can feed several viewers, or collect messages before any viewer exists.

## Constructor

```ts
new LogStore(options?: Partial<LogStoreOptions>)
```

## LogStoreOptions

| Option         | Type      | Default | Description                                                                                                                                                                                                                    |
| -------------- | --------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `maxEntries`   | `number`  | `10000` | The most entries the store keeps. Once it is full, the oldest entry is dropped for every new one. Use `Infinity` to keep everything.                                                                                           |
| `mergeRepeats` | `boolean` | `true`  | Whether a message identical to the one before it increases that entry's repeat count instead of adding a new entry. Only entries of the `message` kind are merged, and never when they hold an error or a value with children. |

`DEFAULT_STORE_OPTIONS` holds these defaults.

## Properties

| Property  | Type     | Description                                                                           |
| --------- | -------- | ------------------------------------------------------------------------------------- |
| `size`    | `number` | The number of entries held.                                                           |
| `firstId` | `number` | The id of the oldest entry held. When the store is empty, the id the next entry gets. |
| `lastId`  | `number` | The id of the newest entry held, or `firstId - 1` when the store is empty.            |

Ids start at 1 and increase by one for every new entry. They are never reused, even after `clear()`.

## Methods

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
| `setCollapsed(id: number, collapsed: boolean)`          | `void`                      | Collapses or expands a group header, which hides or shows its members.                                                                                                             |
| `subscribe(listener: StoreListener)`                    | `() => void`                | Calls a listener for every change. Returns a function that removes the listener.                                                                                                   |

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

## WriteOptions

The options of `write` and `writeLines`, on the store and on the viewer.

| Option   | Type                    | Default     | Description                                                                                                |
| -------- | ----------------------- | ----------- | ---------------------------------------------------------------------------------------------------------- |
| `level`  | `LogLevel`              | `'log'`     | The level of the entries.                                                                                  |
| `kind`   | `LogKind`               | `'message'` | What the entries represent.                                                                                |
| `time`   | `number`                | Now         | The time of the entries, in epoch milliseconds.                                                            |
| `groups` | `readonly number[]`     | `[]`        | The ids of the open groups the entries belong to, outermost first.                                         |
| `token`  | `StyleToken`            | None        | A semantic color for the text.                                                                             |
| `style`  | `TextStyle`             | None        | Explicit styling for the text. Ignored when `ansi` is set.                                                 |
| `ansi`   | `boolean \| AnsiParser` | `false`     | Whether ANSI escape codes in the text become styles. Pass a parser to keep the style running across calls. |

## StoreChange

The value a store listener receives.

| `type`     | Other fields                   | Sent when                                                |
| ---------- | ------------------------------ | -------------------------------------------------------- |
| `'append'` | `entries: readonly LogEntry[]` | Entries were added.                                      |
| `'update'` | `entry: LogEntry`              | An entry's repeat count or collapsed state changed.      |
| `'trim'`   | `count: number`                | The oldest entries were dropped because of `maxEntries`. |
| `'clear'`  | None                           | Every entry was removed.                                 |

```ts
type StoreListener = (change: StoreChange) => void;
```

An `'append'` change comes before the `'trim'` change it causes.
