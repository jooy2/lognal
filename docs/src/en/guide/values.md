---
order: 2
description: How lognal shows objects, arrays, maps, sets, errors and DOM elements, how values expand and collapse, and how tables, groups and repeated messages look.
---

# Typed values

Every console argument that is not a string becomes a typed value: a copy of the value taken when it was logged, shown with formatting for its type. Values with children expand and collapse.

<ClientOnly>
  <LiveViewer preset="values" />
</ClientOnly>

## Previews

A value first appears as a one-line preview.

| Value                                    | Preview                                              |
| ---------------------------------------- | ---------------------------------------------------- |
| String inside another value              | `'text'`                                             |
| Number, bigint                           | `42`, `-0`, `NaN`, `10n`                             |
| Boolean, `null`, `undefined`             | `true`, `null`, `undefined`                          |
| Symbol                                   | `Symbol(token)`                                      |
| Function, class                          | `ƒ handleClick()`, `class User`                      |
| Date                                     | `2026-09-13T05:03:09.120Z`                           |
| Regular expression                       | `/ab+c/gi`                                           |
| Error                                    | `TypeError: Expected a string`                       |
| Array, typed array                       | `(3) [1, 2, 3]`, `Uint8Array(4) [1, 2, 3, 4]`        |
| Object, class instance                   | `{id: 1, name: 'lognal'}`, `User {id: 1}`            |
| Map, Set                                 | `Map(2) {'a' => 1, 'b' => {…}}`, `Set(2) {'x', 'y'}` |
| `WeakMap`, `WeakSet`, `WeakRef`, promise | `WeakMap`, `Promise`                                 |
| DOM element                              | `<nav class="menu">`                                 |
| Circular reference, accessor             | `[Circular]`, `[Getter]`                             |

Inside a preview, nested objects are shown by name, such as `{…}` or `Array(2)`, and strings longer than 50 characters are cut. Once a preview passes 100 characters, the remaining children are replaced with `…`. Dates are written in ISO 8601 format, in UTC.

A string passed directly to a console method is plain text, not a value, so it has no quotes. `console.dir('text')` shows the quotes.

## Expand and collapse

A value that has children starts with a small triangle. Click the triangle or the preview to open the value, and click again to close it. Each child takes its own row, indented by two cells:

- Object properties as `name: value`, with symbol keys shown as `Symbol(key)`.
- Array items as `0: value`.
- Map entries as `key => value`, and set items without a key.
- Element children, followed by the closing tag, such as `</nav>`.
- The stack trace of an error, followed by its own properties and its `cause`.

A value that reached the `maxDepth` limit has no captured children, so it has no triangle. What the other limits leave out is shown as a last row such as `… 25 more`. See [Capture limits](/guide/console#capture-limits).

The viewer remembers which values are open for each entry, until the entry leaves the store or the store is cleared. Selecting and copying text includes the rows of open values.

## Errors

An error passed directly to a console method, such as `console.error(error)`, is open when it is added, so its stack trace is visible right away. An error nested inside another value starts closed.

```ts
try {
	JSON.parse('{');
} catch (error) {
	console.error('Could not read the settings', error);
}
```

The first row shows `SyntaxError: ` and the message. The rows below show the stack trace in the muted color, then any extra properties the error has, such as `code`, and the `cause` passed to the `Error` constructor.

Entries at the error level are drawn in the error color on a tinted row, with a marker in the gutter. Warnings get the same treatment in the warning color. When a command typed into the [input line](/guide/viewer#input-line) throws, its error is printed as an error-level entry too.

## Tables

`console.table` draws its data as a text table with box-drawing characters. The canvas draws those characters as lines, so the borders join across rows.

```ts
console.table([
	{ name: 'Alice', role: 'admin', active: true },
	{ name: '김철수', role: 'editor', active: false }
]);
```

```text
┌─────────┬──────────┬──────────┬────────┐
│ (index) │ name     │ role     │ active │
├─────────┼──────────┼──────────┼────────┤
│ 0       │ 'Alice'  │ 'admin'  │ true   │
│ 1       │ '김철수' │ 'editor' │ false  │
└─────────┴──────────┴──────────┴────────┘
```

- The `(index)` column holds the property name or the array index of each row.
- Every key of the row objects becomes a column. Pass an array of keys as the second argument to choose the columns.
- Rows that are not objects go into a `Values` column. The column is left out when you choose the columns.
- A table shows at most 100 rows and 20 columns, and a cell is cut at 40 cells. The rows left out are counted below the table.
- A value that is not an object is logged the usual way. An object with no rows is logged as a typed value.

## Groups

`console.group` adds a bold header, and every entry until the matching `console.groupEnd` is indented under it by two cells for each level. `console.groupCollapsed` adds a header that starts closed.

```ts
console.group('Request %s', '/api/users');
console.log('Headers', { accept: 'application/json' });
console.groupCollapsed('Response');
console.log('Status', 200);
console.groupEnd();
console.groupEnd();
```

Click a header to hide or show the entries inside the group. While entries are hidden, the status bar shows both numbers, such as `12 of 20 entries`. To open or close a group from code, call `store.setCollapsed(id, collapsed)` with the id of the header entry.

The level filter keeps group headers visible, so the entries that pass the filter stay under their header. A text filter tests group headers the same way as other entries.

## Repeated messages

When a message is identical to the one before it, the store increases a repeat count on that entry instead of adding a new one. The gutter shows the count as a badge, and `99+` above 99.

Two messages are identical when they have the same level, the same group, the same text and styles, and the same simple values. A message with an error or a value that has children is never merged. Turn merging off with the `mergeRepeats` option:

```ts
const viewer = new LogViewer(container, {
	core: { mergeRepeats: false }
});
```
