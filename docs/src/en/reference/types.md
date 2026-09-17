---
order: 6
description: Reference for the data types shared by every part of lognal, including LogEntry, LogPart, ValueNode, LogLevel, TextStyle and StyleToken.
---

# Types

Everything on this page is plain data. An entry and its values hold no reference to the objects that were logged, so they can be sent to another isolate or thread, or saved as JSON.

<Fw js="A union of string literals here is an enum in the Dart package, and a discriminated union is a sealed class." flutter="Each enum here is a union of string literals in the npm package, and each sealed class is a discriminated union." />

## LogLevel

::: fw js

```ts
type LogLevel = 'debug' | 'log' | 'info' | 'warn' | 'error';
```

The severity of an entry. `LOG_LEVELS` is a read-only array of every level, ordered from least to most severe.

:::

::: fw flutter

```dart
enum LogLevel { debug, log, info, warn, error }
```

The severity of an entry. `logLevels` is every level, ordered from least to most severe, which is `LogLevel.values`.

:::

## LogKind

::: fw js

```ts
type LogKind = 'message' | 'input' | 'output' | 'group' | 'system';
```

:::

::: fw flutter

```dart
enum LogKind { message, input, output, group, system }
```

:::

What an entry represents. The viewer marks each kind differently.

| Kind      | Entry                                                                                  |
| --------- | -------------------------------------------------------------------------------------- |
| `message` | A regular log message.                                                                 |
| `input`   | A command the user typed into the input line.                                          |
| `output`  | The reply to a command.                                                                |
| `group`   | The header of a group started with <Fw js="console.group" flutter="log.group" code />. |
| `system`  | A notice from the viewer itself, such as `Console was cleared`.                        |

## LogEntry

An entry held by a store.

| Field       | Type                                                        | Description                                                                                                               |
| ----------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `id`        | <Fw js="number" flutter="int" code />                       | A number that identifies the entry in its store. Read-only.                                                               |
| `time`      | <Fw js="number" flutter="DateTime" code />                  | When the entry was added. <Fw js="Epoch milliseconds." /> Read-only.                                                      |
| `level`     | `LogLevel`                                                  | The severity. Read-only.                                                                                                  |
| `kind`      | `LogKind`                                                   | What the entry represents. Read-only.                                                                                     |
| `parts`     | <Fw js="readonly LogPart[]" flutter="List<LogPart>" code /> | The content, displayed one part after another. Read-only.                                                                 |
| `groups`    | <Fw js="readonly number[]" flutter="List<int>" code />      | The ids of the open groups the entry belongs to, outermost first. Read-only.                                              |
| `runHead`   | <Fw js="number" flutter="int?" code />                      | The id of the first entry of the run of identical messages this one repeats, set only when runs are collapsed. Read-only. |
| `collapsed` | <Fw js="boolean" flutter="bool" code />                     | For a group header, or for the first entry of a run of identical messages, whether its members are hidden.                |
| `repeat`    | <Fw js="number" flutter="int" code />                       | How many identical consecutive messages the entry stands for.                                                             |
| `version`   | <Fw js="number" flutter="int" code />                       | Increases whenever `collapsed` or `repeat` changes, so cached layouts can be refreshed.                                   |

## LogEntryInit

The fields you provide to <Fw js="store.append" flutter="store.append or store.add" code />.

| Field       | Type                                                   | Default                                              | Description                                                        |
| ----------- | ------------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------ |
| `parts`     | <Fw js="LogPart[]" flutter="List<LogPart>" code />     | Required                                             | The content of the entry.                                          |
| `level`     | `LogLevel`                                             | <Fw js="'log'" flutter="LogLevel.log" code />        | The severity.                                                      |
| `kind`      | `LogKind`                                              | <Fw js="'message'" flutter="LogKind.message" code /> | What the entry represents.                                         |
| `time`      | <Fw js="number" flutter="DateTime?" code />            | The time it is added                                 | <Fw js="Epoch milliseconds." flutter="When the entry happened." /> |
| `groups`    | <Fw js="readonly number[]" flutter="List<int>" code /> | `[]`                                                 | Ids of the open groups this entry belongs to, outermost first.     |
| `collapsed` | <Fw js="boolean" flutter="bool" code />                | `false`                                              | For a group header, whether the group starts collapsed.            |

## LogPart

::: fw js

```ts
type LogPart = TextPart | ValuePart;
```

:::

::: fw flutter

```dart
sealed class LogPart {}
```

`TextPart` and `ValuePart` extend it, so a `switch` over a part is checked for completeness. There is no `type` field: the class is the discriminator.

:::

### TextPart

::: fw js

| Field   | Type         | Description                                                                                                 |
| ------- | ------------ | ----------------------------------------------------------------------------------------------------------- |
| `type`  | `'text'`     | Marks a text part.                                                                                          |
| `text`  | `string`     | The text. It can contain line breaks.                                                                       |
| `token` | `StyleToken` | A semantic color, optional.                                                                                 |
| `style` | `TextStyle`  | Explicit styling, optional.                                                                                 |
| `wrap`  | `boolean`    | `false` keeps every line of the part on one row, for text such as a table. Optional; parts wrap by default. |

:::

::: fw flutter

```dart
TextPart('Ready', token: StyleToken.info)
```

| Field   | Type            | Description                                                                                       |
| ------- | --------------- | ------------------------------------------------------------------------------------------------- |
| `text`  | `String`        | The text, and the first positional argument. It can contain line breaks.                          |
| `token` | `StyleToken?`   | A semantic color.                                                                                 |
| `style` | `LogTextStyle?` | Explicit styling.                                                                                 |
| `wrap`  | `bool`          | `false` keeps every line of the part on one row, for text such as a table. Parts wrap by default. |

:::

### ValuePart

::: fw js

| Field   | Type        | Description                             |
| ------- | ----------- | --------------------------------------- |
| `type`  | `'value'`   | Marks a value part.                     |
| `value` | `ValueNode` | A captured value, from `snapshotValue`. |

:::

::: fw flutter

| Field   | Type        | Description                            |
| ------- | ----------- | -------------------------------------- |
| `value` | `ValueNode` | A captured value, from `captureValue`. |

:::

## StyleToken

::: fw js

`StyleToken` is one of these strings: `'default'`, `'muted'`, `'string'`, `'number'`, `'boolean'`, `'null'`, `'key'`, `'symbol'`, `'function'`, `'regexp'`, `'date'`, `'tag'`, `'attribute'`, `'error'`, `'warn'`, `'info'`, `'accent'`.

A semantic color that the renderer resolves from the theme. Every token except `default` has a `--lognal-token-*` property. `default` uses the color of the entry's level.

:::

::: fw flutter

`StyleToken` is an enum: `defaultToken`, `muted`, `string`, `number`, `boolean`, `nullValue`, `key`, `symbol`, `function`, `regexp`, `date`, `tag`, `attribute`, `error`, `warn`, `info`, `accent`.

A semantic color the painter looks up in the palette's `renderer.tokens`. `defaultToken` uses the color of the entry's level. Two values carry a suffix because `default` and `null` are Dart keywords.

:::

## TextStyle

Explicit styling, from `%c` in a console message or from ANSI escape codes. <Fw flutter="The class is LogTextStyle, because TextStyle is already a name in dart:ui." />

| Field           | Type                                            | Description            |
| --------------- | ----------------------------------------------- | ---------------------- |
| `color`         | <Fw js="TextColor" flutter="TextColor?" code /> | The text color.        |
| `background`    | <Fw js="TextColor" flutter="TextColor?" code /> | The background color.  |
| `bold`          | <Fw js="boolean" flutter="bool" code />         | Bold text.             |
| `dim`           | <Fw js="boolean" flutter="bool" code />         | Text at lower opacity. |
| `italic`        | <Fw js="boolean" flutter="bool" code />         | Italic text.           |
| `underline`     | <Fw js="boolean" flutter="bool" code />         | Underlined text.       |
| `strikethrough` | <Fw js="boolean" flutter="bool" code />         | Struck-through text.   |

::: fw js

```ts
type TextColor = number | string;
```

A number from 0 to 255 is an index into the ANSI palette, where 0 to 15 follow the theme. A string is a CSS color such as `#ff0000` or `rgb(255 0 0)`.

:::

::: fw flutter

```dart
sealed class TextColor {}
```

`AnsiTextColor(index)` is an index from 0 to 255 into the ANSI palette, where 0 to 15 follow the theme. `RgbTextColor(value)` is an ARGB value, such as `RgbTextColor(0xffff0000)`. `resolveTextColor` turns either one into a `Color` against a palette.

:::

## ValueNode

A snapshot of a value, taken when it was logged.

| Field        | Type                                                                          | Description                                                                                                                                                             |
| ------------ | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind`       | `ValueKind`                                                                   | The kind of value.                                                                                                                                                      |
| `value`      | <Fw js="string" flutter="String?" code />                                     | The text of a leaf value: the string itself, a number as text, a function name, a date in ISO format, a regular expression literal, an error message, or a description. |
| `className`  | <Fw js="string" flutter="String?" code />                                     | The <Fw js="constructor name" flutter="type name" /> of an object, such as `Map` or `User`.                                                                             |
| `size`       | <Fw js="number" flutter="int?" code />                                        | The length of a list or string, or the size of a map or set.                                                                                                            |
| `children`   | <Fw js="ValueEntry[]" flutter="List<ValueEntry>?" code />                     | The captured children of an object, list, map, set or error. Absent when the depth limit was reached, or when nothing could be read.                                    |
| `omitted`    | <Fw js="number" flutter="int" code />                                         | How many children exist but were left out because of a limit.                                                                                                           |
| `truncated`  | <Fw js="number" flutter="int" code />                                         | How many characters were cut from a long string.                                                                                                                        |
| `stack`      | <Fw js="string" flutter="String?" code />                                     | The stack trace of an error, without its first line.                                                                                                                    |
| `attributes` | <Fw js="[string, string][]" flutter="List<MapEntry<String, String>>?" code /> | The attributes of an element, as name and value pairs.                                                                                                                  |
| `accessor`   | <Fw js="'get' \| 'set' \| 'get-set'" flutter="AccessorKind?" code />          | For an accessor property, which parts are defined.                                                                                                                      |

<Fw js="Every field except kind is optional." flutter="Every field except kind is optional, and copyWith returns a copy with some of them replaced." />

### ValueKind

::: fw js

`ValueKind` is one of these strings: `'undefined'`, `'null'`, `'boolean'`, `'number'`, `'bigint'`, `'string'`, `'symbol'`, `'function'`, `'class'`, `'date'`, `'regexp'`, `'error'`, `'array'`, `'object'`, `'map'`, `'set'`, `'weak'`, `'promise'`, `'element'`, `'text'`, `'circular'`, `'accessor'`.

Typed arrays are `'array'` with their class name, `WeakMap`, `WeakSet` and `WeakRef` are `'weak'`, and DOM text nodes are `'text'`.

:::

::: fw flutter

`ValueKind` is an enum: `nullValue`, `boolean`, `number`, `bigint`, `string`, `symbol`, `function`, `classValue`, `date`, `regexp`, `error`, `list`, `object`, `map`, `set`, `future`, `element`, `text`, `circular`, `accessor`.

Three names differ from the npm package. `nullValue` and `classValue` carry a suffix because `null` and `class` are Dart keywords, `list` is `array` there, and `future` is `promise`. A typed list such as `Uint8List` is `list` with its type name.

There is no `undefined`, because Dart has one empty value rather than two. There is no `weak` either: a `WeakReference` is captured as the object it points at, or as `nullValue` once it is gone.

:::

### ValueEntry

A child of a value: a property, a list item, a map entry or a child node.

| Field      | Type                                                                                     | Description                                                       |
| ---------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `key`      | <Fw js="string" flutter="String?" code />                                                | The property name or index. Absent for set items and child nodes. |
| `keyKind`  | <Fw js="'property' \| 'index' \| 'symbol' \| 'internal'" flutter="ValueKeyKind?" code /> | How the key is displayed.                                         |
| `keyValue` | <Fw js="ValueNode" flutter="ValueNode?" code />                                          | The key of a map entry.                                           |
| `value`    | `ValueNode`                                                                              | The child value.                                                  |

<Fw flutter="ValueKeyKind is property, indexed, symbol or internal. The second one is indexed rather than index, because index is already a member of every Dart enum." />
