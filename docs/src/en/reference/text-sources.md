---
order: 4
description: Reference for lognal text sources and text utilities, including readTextFile, followTextFile, TextLineWriter, detectEncoding, legacyEncodingFor, AnsiParser, LineSplitter and the width functions.
---

# Text sources

See [Text files](/guide/text-files) in the guide for examples.

## readTextFile

```ts
readTextFile(file: Blob, store: LogStore, options?: ReadTextOptions): Promise<ReadTextResult>
```

Reads a text file, such as one picked with `<input type="file">` or dropped on the page, and adds one entry per line. The file is read in chunks, so a large file does not have to fit in memory as one string. The store's `maxEntries` still decides how many lines are kept.

### ReadTextOptions

| Option             | Type                                      | Default                                 | Description                                                                                                            |
| ------------------ | ----------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `encoding`         | `string`                                  | `'auto'`                                | The encoding of the file. `'auto'` reads the byte order mark, then tries UTF-8, then falls back to `fallbackEncoding`. |
| `fallbackEncoding` | `string`                                  | `legacyEncodingFor(navigator.language)` | The encoding `'auto'` uses when the file is not UTF-8.                                                                 |
| `level`            | `LogLevel`                                | `'log'`                                 | The level of every line.                                                                                               |
| `ansi`             | `boolean`                                 | `true`                                  | Whether ANSI escape codes become styles.                                                                               |
| `chunkSize`        | `number`                                  | `262144`                                | Bytes read at a time.                                                                                                  |
| `signal`           | `AbortSignal`                             | None                                    | Stops reading when aborted. The lines read so far stay in the store.                                                   |
| `onProgress`       | `(loaded: number, total: number) => void` | None                                    | Called after every chunk with the bytes read so far and the total size.                                                |

### ReadTextResult

| Field      | Type     | Description                |
| ---------- | -------- | -------------------------- |
| `lines`    | `number` | The number of lines added. |
| `bytes`    | `number` | The number of bytes read.  |
| `encoding` | `string` | The encoding used.         |

## followTextFile

```ts
followTextFile(handle: FileHandleLike, store: LogStore, options?: FollowTextOptions): FollowHandle
```

Reads a file and keeps adding the lines appended to it, like `tail -f`. Every check asks the handle for a fresh copy of the file and reads what was added since the last one. It needs a handle from the File System Access API, which only Chromium-based browsers provide.

When the file gets shorter, or keeps its size but has a new `lastModified` time, it was replaced rather than appended to. It is then read again from the start, and `onReset` is called.

### FileHandleLike

```ts
interface FileHandleLike {
	getFile(): Promise<Blob & { lastModified?: number }>;
}
```

The part of `FileSystemFileHandle` that following a file needs. Any object with a `getFile` method works, which is useful in tests.

### FollowTextOptions

| Option             | Type                       | Default                                 | Description                                                                                  |
| ------------------ | -------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                                  | Milliseconds between checks for new data.                                                    |
| `encoding`         | `string`                   | `'auto'`                                | The encoding, or `'auto'` to detect it from the first bytes.                                 |
| `fallbackEncoding` | `string`                   | `legacyEncodingFor(navigator.language)` | The encoding `'auto'` falls back to when the file is not UTF-8.                              |
| `level`            | `LogLevel`                 | `'log'`                                 | The level of every line.                                                                     |
| `ansi`             | `boolean`                  | `true`                                  | Whether ANSI escape codes become styles.                                                     |
| `onReset`          | `() => void`               | None                                    | Called when the file was replaced and is read again from the start.                          |
| `onError`          | `(error: unknown) => void` | None                                    | Called when a check after the first one fails, for example because permission was withdrawn. |

### FollowHandle

| Member  | Type              | Description                                                                                                                                                                                      |
| ------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ready` | `Promise<number>` | Resolves after the first read with the number of lines it added, or rejects with the error when the first read fails. `onError` is not called for that failure, and checking goes on either way. |
| `stop`  | `() => void`      | Stops checking the file, and writes what the decoder still holds and the unfinished last line.                                                                                                   |

## TextLineWriter

```ts
new TextLineWriter(store: LogStore, options?: { level?: LogLevel; ansi?: boolean })
```

Turns decoded text into store entries one line at a time, keeping partial lines and the ANSI style between chunks. `readTextFile` and `followTextFile` use it. `ansi` is `true` unless you pass `false`, and `level` defaults to `'log'`.

| Member                | Type      | Description                                               |
| --------------------- | --------- | --------------------------------------------------------- |
| `write(text: string)` | `void`    | Adds a chunk of text and writes the lines it completes.   |
| `flush()`             | `void`    | Writes the unfinished last line, if any.                  |
| `lines`               | `number`  | The number of lines written.                              |
| `hasPending`          | `boolean` | Whether an unfinished line is waiting for its line break. |

## Encodings

### detectEncoding

```ts
detectEncoding(bytes: Uint8Array, fallback: string): string
```

Picks the encoding of a file from its first bytes: the byte order mark if there is one (`'utf-8'`, `'utf-16le'` or `'utf-16be'`), then `'utf-8'` if the bytes are valid UTF-8, and otherwise `fallback`. A multi-byte sequence cut off at the end of `bytes` still counts as valid.

### legacyEncodingFor

```ts
legacyEncodingFor(locale: string | undefined): string
```

Returns the legacy encoding a browser assumes for a page in a language, from the suggested default encodings of the HTML Standard, such as `'euc-kr'` for `'ko-KR'`. Returns `'windows-1252'` for languages not in the table and for `undefined`.

```ts
import { detectEncoding, legacyEncodingFor } from 'lognal';

// `file` is a Blob, such as a File from <input type="file">.
const head = new Uint8Array(await file.slice(0, 65536).arrayBuffer());
const encoding = detectEncoding(head, legacyEncodingFor('ko-KR'));
// 'utf-8' or 'euc-kr'
```

## ANSI escape codes

### AnsiParser

```ts
new AnsiParser();
```

Turns text with ANSI escape codes into styled parts. Select Graphic Rendition codes become styles, and every other escape sequence is removed. The style carries over between calls, the way a terminal keeps it from one line to the next.

| Method                | Returns      | Description                               |
| --------------------- | ------------ | ----------------------------------------- |
| `parse(text: string)` | `TextPart[]` | Parses one piece of text, usually a line. |
| `reset()`             | `void`       | Forgets the current style.                |

```ts
import { AnsiParser } from 'lognal';

new AnsiParser().parse('\x1b[1;31mfailed\x1b[0m after 3 tries');
// [{ type: 'text', text: 'failed', style: { bold: true, color: 1 } },
//  { type: 'text', text: ' after 3 tries' }]
```

### stripAnsi

```ts
stripAnsi(text: string): string
```

Removes every ANSI escape sequence from text.

## Lines

### LineSplitter

```ts
new LineSplitter();
```

Splits a stream of text chunks into lines. A line ends at `\n`, `\r\n` or a lone `\r`, and a `\r\n` pair split across two chunks still counts as one line break.

| Member                | Type       | Description                                                        |
| --------------------- | ---------- | ------------------------------------------------------------------ |
| `push(chunk: string)` | `string[]` | Adds a chunk and returns the lines it completed.                   |
| `flush()`             | `string[]` | Returns the unfinished last line, if any, and resets the splitter. |
| `hasPending`          | `boolean`  | Whether text is waiting for a line break.                          |

### splitLines

```ts
splitLines(text: string): string[]
```

Splits a whole string into lines. A trailing line break does not add an empty line.

## Text width

These functions measure text with the rules of the viewer. See [Width on the grid](/guide/cjk#width-on-the-grid).

| Function                                                                         | Returns    | Description                                                                                                                                   |
| -------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `measureCells(text: string, ambiguousWidth?: AmbiguousWidth)`                    | `number`   | How many cells a string takes on one row.                                                                                                     |
| `truncateCells(text: string, maxCells: number, ambiguousWidth?: AmbiguousWidth)` | `string`   | Cuts a string to at most `maxCells` cells, ending it with `…` when anything was cut. A wide character that would cross the limit is left out. |
| `clusterWidth(cluster: string, ambiguousWidth?: AmbiguousWidth)`                 | `number`   | How many cells one grapheme cluster takes.                                                                                                    |
| `codePointWidth(codePoint: number, ambiguousWidth?: AmbiguousWidth)`             | `number`   | How many cells one code point takes: 0, 1 or 2. Control characters return 1.                                                                  |
| `splitGraphemes(text: string)`                                                   | `string[]` | Splits text into grapheme clusters with the active splitter.                                                                                  |
| `setGraphemeSplitter(splitter: GraphemeSplitter \| null)`                        | `void`     | Replaces the grapheme splitter. `null` goes back to the default, which uses `Intl.Segmenter` where it exists.                                 |

`ambiguousWidth` defaults to `1`. `UNICODE_VERSION` is the version of the Unicode data the widths come from, `'17.0.0'`.

```ts
type AmbiguousWidth = 1 | 2;
type GraphemeSplitter = (text: string) => string[];
```
