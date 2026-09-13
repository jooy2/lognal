---
order: 6
description: Reference for the data types shared by every part of lognal, including LogEntry, LogPart, ValueNode, LogLevel, TextStyle and StyleToken.
---

# Types

Everything in this page is plain data. An entry and its values hold no reference to the objects that were logged, so they can be passed through `postMessage` or saved as JSON.

## LogLevel

```ts
type LogLevel = 'debug' | 'log' | 'info' | 'warn' | 'error';
```

The severity of an entry. `LOG_LEVELS` is a read-only array of every level, ordered from least to most severe.

## LogKind

```ts
type LogKind = 'message' | 'input' | 'output' | 'group' | 'system';
```

What an entry represents. The viewer marks each kind differently.

| Kind        | Entry                                                           |
| ----------- | --------------------------------------------------------------- |
| `'message'` | A regular log message.                                          |
| `'input'`   | A command the user typed into the input line.                   |
| `'output'`  | The reply to a command.                                         |
| `'group'`   | The header of a group started with `console.group`.             |
| `'system'`  | A notice from the viewer itself, such as `Console was cleared`. |

## LogEntry

An entry held by a store.

| Field       | Type                 | Description                                                                             |
| ----------- | -------------------- | --------------------------------------------------------------------------------------- |
| `id`        | `number`             | A number that identifies the entry in its store. Read-only.                             |
| `time`      | `number`             | When the entry was added, in epoch milliseconds. Read-only.                             |
| `level`     | `LogLevel`           | The severity. Read-only.                                                                |
| `kind`      | `LogKind`            | What the entry represents. Read-only.                                                   |
| `parts`     | `readonly LogPart[]` | The content, displayed one part after another. Read-only.                               |
| `groups`    | `readonly number[]`  | The ids of the open groups the entry belongs to, outermost first. Read-only.            |
| `collapsed` | `boolean`            | For a group header, whether its members are hidden.                                     |
| `repeat`    | `number`             | How many identical consecutive messages the entry stands for.                           |
| `version`   | `number`             | Increases whenever `collapsed` or `repeat` changes, so cached layouts can be refreshed. |

## LogEntryInit

The fields you provide to `store.append`.

| Field       | Type                | Default              | Description                                                    |
| ----------- | ------------------- | -------------------- | -------------------------------------------------------------- |
| `parts`     | `LogPart[]`         | Required             | The content of the entry.                                      |
| `level`     | `LogLevel`          | `'log'`              | The severity.                                                  |
| `kind`      | `LogKind`           | `'message'`          | What the entry represents.                                     |
| `time`      | `number`            | The time it is added | Epoch milliseconds.                                            |
| `groups`    | `readonly number[]` | `[]`                 | Ids of the open groups this entry belongs to, outermost first. |
| `collapsed` | `boolean`           | `false`              | For a group header, whether the group starts collapsed.        |

## LogPart

```ts
type LogPart = TextPart | ValuePart;
```

### TextPart

| Field   | Type         | Description                                                                                                 |
| ------- | ------------ | ----------------------------------------------------------------------------------------------------------- |
| `type`  | `'text'`     | Marks a text part.                                                                                          |
| `text`  | `string`     | The text. It can contain line breaks.                                                                       |
| `token` | `StyleToken` | A semantic color, optional.                                                                                 |
| `style` | `TextStyle`  | Explicit styling, optional.                                                                                 |
| `wrap`  | `boolean`    | `false` keeps every line of the part on one row, for text such as a table. Optional; parts wrap by default. |

### ValuePart

| Field   | Type        | Description                             |
| ------- | ----------- | --------------------------------------- |
| `type`  | `'value'`   | Marks a value part.                     |
| `value` | `ValueNode` | A captured value, from `snapshotValue`. |

## StyleToken

`StyleToken` is one of these strings: `'default'`, `'muted'`, `'string'`, `'number'`, `'boolean'`, `'null'`, `'key'`, `'symbol'`, `'function'`, `'regexp'`, `'date'`, `'tag'`, `'attribute'`, `'error'`, `'warn'`, `'info'`, `'accent'`.

A semantic color that the renderer resolves from the theme. Every token except `default` has a `--lognal-token-*` property. `default` uses the color of the entry's level.

## TextStyle

Explicit styling, from `%c` in a console message or from ANSI escape codes.

| Field           | Type        | Description            |
| --------------- | ----------- | ---------------------- |
| `color`         | `TextColor` | The text color.        |
| `background`    | `TextColor` | The background color.  |
| `bold`          | `boolean`   | Bold text.             |
| `dim`           | `boolean`   | Text at lower opacity. |
| `italic`        | `boolean`   | Italic text.           |
| `underline`     | `boolean`   | Underlined text.       |
| `strikethrough` | `boolean`   | Struck-through text.   |

```ts
type TextColor = number | string;
```

A number from 0 to 255 is an index into the ANSI palette, where 0 to 15 follow the theme. A string is a CSS color such as `#ff0000` or `rgb(255 0 0)`.

## ValueNode

A snapshot of a value, taken when it was logged.

| Field        | Type                          | Description                                                                                                                                                                     |
| ------------ | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind`       | `ValueKind`                   | The kind of value.                                                                                                                                                              |
| `value`      | `string`                      | The text of a leaf value: the string itself, a number as text, a function name, a date in ISO format, a regular expression literal, an error message, or an element's tag name. |
| `className`  | `string`                      | The constructor name of an object, such as `Map` or `User`.                                                                                                                     |
| `size`       | `number`                      | The length of an array or string, or the size of a map or set.                                                                                                                  |
| `children`   | `ValueEntry[]`                | The captured children of an object, array, map, set, error or element. `undefined` when the depth limit was reached.                                                            |
| `omitted`    | `number`                      | How many children exist but were left out because of a limit.                                                                                                                   |
| `truncated`  | `number`                      | How many characters were cut from a long string.                                                                                                                                |
| `stack`      | `string`                      | The stack trace of an error, without its first line.                                                                                                                            |
| `attributes` | `[string, string][]`          | The attributes of an element, as name and value pairs.                                                                                                                          |
| `accessor`   | `'get' \| 'set' \| 'get-set'` | For an accessor property, which parts are defined.                                                                                                                              |

Every field except `kind` is optional.

### ValueKind

`ValueKind` is one of these strings: `'undefined'`, `'null'`, `'boolean'`, `'number'`, `'bigint'`, `'string'`, `'symbol'`, `'function'`, `'class'`, `'date'`, `'regexp'`, `'error'`, `'array'`, `'object'`, `'map'`, `'set'`, `'weak'`, `'promise'`, `'element'`, `'text'`, `'circular'`, `'accessor'`.

Typed arrays are `'array'` with their class name, `WeakMap`, `WeakSet` and `WeakRef` are `'weak'`, and DOM text nodes are `'text'`.

### ValueEntry

A child of a value: a property, an array item, a map entry or a child node.

| Field      | Type                                              | Description                                                       |
| ---------- | ------------------------------------------------- | ----------------------------------------------------------------- |
| `key`      | `string`                                          | The property name or index. Absent for set items and child nodes. |
| `keyKind`  | `'property' \| 'index' \| 'symbol' \| 'internal'` | How the key is displayed.                                         |
| `keyValue` | `ValueNode`                                       | The key of a map entry.                                           |
| `value`    | `ValueNode`                                       | The child value.                                                  |
