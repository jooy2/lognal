---
order: 4
description: Reference for the text sources and text utilities, including reading and following a file, the encodings, AnsiParser, the line splitter and the width functions.
---

# Text sources

See [Text files](/guide/text-files) in the guide for examples.

::: fw js

## readTextFile

```ts
readTextFile(file: Blob, store: LogStore, options?: ReadTextOptions): Promise<ReadTextResult>
```

Reads a text file, such as one picked with `<input type="file">` or dropped on the page, and adds one entry per line. The file is read in chunks, so a large file does not have to fit in memory as one string. The store's `maxEntries` still decides how many lines are kept.

:::

::: fw flutter

## readTextStream and readTextBytes {#read-text}

```dart
Future<ReadTextResult> readTextStream(
  Stream<List<int>> chunks,
  LogStore store, {
  ReadTextOptions options = const ReadTextOptions(),
  int? totalBytes,
  String? locale,
})

Future<ReadTextResult> readTextBytes(
  List<int> bytes,
  LogStore store, {
  ReadTextOptions options = const ReadTextOptions(),
  int chunkSize = 256 * 1024,
  String? locale,
})
```

Reads a text file and adds one entry per line. The reader takes a stream of bytes rather than a file, because what a file is differs by platform: `File(path).openRead()` where `dart:io` exists, and a picked file's own stream on the web. Nothing is built as one string, so a file larger than memory reads fine. The store's `maxEntries` still decides how many lines are kept.

`readTextBytes` is for a file already in memory, and cuts it into chunks itself.

To stop reading, stop listening to the stream. There is no `signal` argument, because a Dart stream is already cancellable.

:::

### ReadTextOptions

::: fw js

| Option             | Type                                      | Default                                 | Description                                                                                                            |
| ------------------ | ----------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `encoding`         | `string`                                  | `'auto'`                                | The encoding of the file. `'auto'` reads the byte order mark, then tries UTF-8, then falls back to `fallbackEncoding`. |
| `fallbackEncoding` | `string`                                  | `legacyEncodingFor(navigator.language)` | The encoding `'auto'` uses when the file is not UTF-8.                                                                 |
| `level`            | `LogLevel`                                | `'log'`                                 | The level of every line.                                                                                               |
| `ansi`             | `boolean`                                 | `true`                                  | Whether ANSI escape codes become styles.                                                                               |
| `chunkSize`        | `number`                                  | `262144`                                | Bytes read at a time.                                                                                                  |
| `signal`           | `AbortSignal`                             | None                                    | Stops reading when aborted. The lines read so far stay in the store.                                                   |
| `onProgress`       | `(loaded: number, total: number) => void` | None                                    | Called after every chunk with the bytes read so far and the total size.                                                |

:::

::: fw flutter

| Option             | Type                       | Default           | Description                                                                                                          |
| ------------------ | -------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------- |
| `encoding`         | `String`                   | `'auto'`          | The encoding of the file. `auto` reads the byte order mark, then tries UTF-8, then falls back to `fallbackEncoding`. |
| `fallbackEncoding` | `String?`                  | From the `locale` | The encoding `auto` uses when the file is not UTF-8.                                                                 |
| `level`            | `LogLevel`                 | `LogLevel.log`    | The level of every line.                                                                                             |
| `ansi`             | `bool`                     | `true`            | Whether ANSI escape codes become styles.                                                                             |
| `onProgress`       | `void Function(int, int)?` | `null`            | Called after every chunk with the bytes read so far and the total size, which is 0 without `totalBytes`.             |

`chunkSize` is an argument of `readTextBytes` rather than an option, because it means nothing to a stream somebody else already cut into chunks.

:::

### ReadTextResult

::: fw js

| Field      | Type     | Description                |
| ---------- | -------- | -------------------------- |
| `lines`    | `number` | The number of lines added. |
| `bytes`    | `number` | The number of bytes read.  |
| `encoding` | `string` | The encoding used.         |

:::

::: fw flutter

| Field      | Type     | Description                                                                                  |
| ---------- | -------- | -------------------------------------------------------------------------------------------- |
| `lines`    | `int`    | The number of lines added.                                                                   |
| `bytes`    | `int`    | The number of bytes read.                                                                    |
| `encoding` | `String` | The encoding used.                                                                           |
| `decoded`  | `bool`   | Whether a decoder for that encoding was found. `false` means the bytes were read as Latin-1. |

:::

## followTextFile

::: fw js

```ts
followTextFile(handle: FileHandleLike, store: LogStore, options?: FollowTextOptions): FollowHandle
```

Reads a file and keeps adding the lines appended to it, like `tail -f`. Every check asks the handle for a fresh copy of the file and reads what was added since the last one. It needs a handle from the File System Access API, which only Chromium-based browsers provide.

:::

::: fw flutter

```dart
FollowHandle followTextFile(
  TextFileSource file,
  LogStore store, {
  FollowTextOptions options = const FollowTextOptions(),
  String? locale,
})
```

Reads a file and keeps adding the lines appended to it, like `tail -f`. Every check asks the source for its size and reads what was added since the last one.

:::

When the file gets shorter, or keeps its size but was modified, it was replaced rather than appended to. It is then read again from the start, and `onReset` is called.

::: fw js

### FileHandleLike

```ts
interface FileHandleLike {
	getFile(): Promise<Blob & { lastModified?: number }>;
}
```

The part of `FileSystemFileHandle` that following a file needs. Any object with a `getFile` method works, which is useful in tests.

:::

::: fw flutter

### TextFileSource {#textfilesource}

```dart
abstract class TextFileSource {
  Future<int> length();
  Future<DateTime?> lastModified();
  Stream<List<int>> openRead([int start = 0]);
}
```

Everything following a file needs, and nothing about where the file lives. `localTextFile(path)` returns one for a file on the local file system, where the platform has one. `CallbackTextFile` builds one from three functions, which is what a picked file on the web and a test both use.

Importing `dart:io` does not compile for the web, so `localTextFile` is chosen when the application is built rather than when it runs. On the web it throws, and a picked file goes through `CallbackTextFile` instead.

:::

### FollowTextOptions

::: fw js

| Option             | Type                       | Default                                 | Description                                                                                  |
| ------------------ | -------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                                  | Milliseconds between checks for new data.                                                    |
| `encoding`         | `string`                   | `'auto'`                                | The encoding, or `'auto'` to detect it from the first bytes.                                 |
| `fallbackEncoding` | `string`                   | `legacyEncodingFor(navigator.language)` | The encoding `'auto'` falls back to when the file is not UTF-8.                              |
| `level`            | `LogLevel`                 | `'log'`                                 | The level of every line.                                                                     |
| `ansi`             | `boolean`                  | `true`                                  | Whether ANSI escape codes become styles.                                                     |
| `onReset`          | `() => void`               | None                                    | Called when the file was replaced and is read again from the start.                          |
| `onError`          | `(error: unknown) => void` | None                                    | Called when a check after the first one fails, for example because permission was withdrawn. |

:::

::: fw flutter

| Option             | Type                     | Default                | Description                                                                            |
| ------------------ | ------------------------ | ---------------------- | -------------------------------------------------------------------------------------- |
| `interval`         | `Duration`               | `Duration(seconds: 1)` | Time between checks for new data.                                                      |
| `encoding`         | `String`                 | `'auto'`               | The encoding, or `auto` to detect it from the first bytes.                             |
| `fallbackEncoding` | `String?`                | From the `locale`      | The encoding `auto` falls back to when the file is not UTF-8.                          |
| `level`            | `LogLevel`               | `LogLevel.log`         | The level of every line.                                                               |
| `ansi`             | `bool`                   | `true`                 | Whether ANSI escape codes become styles.                                               |
| `onReset`          | `void Function()?`       | `null`                 | Called when the file was replaced and is read again from the start.                    |
| `onError`          | `void Function(Object)?` | `null`                 | Called when a check after the first one fails, for example because the file went away. |

:::

### FollowHandle

| Member  | Type                                                   | Description                                                                                                                                                                               |
| ------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ready` | <Fw js="Promise<number>" flutter="Future<int>" code /> | Completes after the first read with the number of lines it added, or with the error when the first read fails. `onError` is not called for that failure, and checking goes on either way. |
| `stop`  | <Fw js="() => void" flutter="void Function()" code />  | Stops checking the file, and writes what the decoder still holds and the unfinished last line.                                                                                            |

## TextLineWriter

::: fw js

```ts
new TextLineWriter(store: LogStore, options?: { level?: LogLevel; ansi?: boolean })
```

:::

::: fw flutter

```dart
TextLineWriter(LogStore store, {LogLevel level = LogLevel.log, bool ansi = true})
```

:::

Turns decoded text into store entries one line at a time, keeping partial lines and the ANSI style between chunks. The readers on this page use it.

| Member                                                            | Type                                    | Description                                               |
| ----------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| <Fw js="write(text: string)" flutter="write(String text)" code /> | `void`                                  | Adds a chunk of text and writes the lines it completes.   |
| `flush()`                                                         | `void`                                  | Writes the unfinished last line, if any.                  |
| `lines`                                                           | <Fw js="number" flutter="int" code />   | The number of lines written.                              |
| `hasPending`                                                      | <Fw js="boolean" flutter="bool" code /> | Whether an unfinished line is waiting for its line break. |

## Encodings

::: fw flutter

This package decodes UTF-8, UTF-16, Windows-1252 and Latin-1 on its own, which is `builtInEncodings`. A legacy CJK encoding needs a table of tens of thousands of characters, which a browser already has and Dart does not, so the package takes a decoder from you instead of shipping four more tables.

```dart
abstract class TextDecoderSink {
  String add(List<int> bytes);
  String close();
}

typedef TextDecoderFactory = TextDecoderSink? Function(String encoding);

void registerTextDecoder(TextDecoderFactory factory)
TextDecoderSink? decoderFor(String encoding)
```

A factory is asked for every encoding the reader meets, newest first, and returns `null` for the ones it does not handle. Without one, a file in an encoding nothing decodes is read as Latin-1, and `ReadTextResult.decoded` is `false`. See [File encodings](/guide/cjk#file-encodings).

:::

### detectEncoding

::: fw js

```ts
detectEncoding(bytes: Uint8Array, fallback: string): string
```

:::

::: fw flutter

```dart
String detectEncoding(List<int> bytes, String fallback)
```

:::

Picks the encoding of a file from its first bytes: the byte order mark if there is one (`utf-8`, `utf-16le` or `utf-16be`), then `utf-8` if the bytes are valid UTF-8, and otherwise `fallback`. A multi-byte sequence cut off at the end of `bytes` still counts as valid.

<Fw flutter="encodingFromBom(bytes) and isValidUtf8(bytes) are the two halves of it, public because a reader of your own would want them." />

### legacyEncodingFor

```
legacyEncodingFor(locale)
```

Returns the legacy encoding a browser assumes for a page in a language, from the suggested default encodings of the HTML Standard, such as `euc-kr` for `ko-KR`. Returns `windows-1252` for languages not in the table and for a missing locale.

::: fw js

```ts
import { detectEncoding, legacyEncodingFor } from 'lognal';

// `file` is a Blob, such as a File from <input type="file">.
const head = new Uint8Array(await file.slice(0, 65536).arrayBuffer());
const encoding = detectEncoding(head, legacyEncodingFor('ko-KR'));
// 'utf-8' or 'euc-kr'
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final List<int> head = await File(path).openRead(0, 65536).expand((List<int> c) => c).toList();
final String encoding = detectEncoding(head, legacyEncodingFor('ko-KR'));
// 'utf-8' or 'euc-kr'
```

:::

## ANSI escape codes

### AnsiParser

```
new AnsiParser()
```

Turns text with ANSI escape codes into styled parts. Select Graphic Rendition codes become styles, and every other escape sequence is removed. The style carries over between calls, the way a terminal keeps it from one line to the next.

| Method                                                            | Returns                                              | Description                               |
| ----------------------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------- |
| <Fw js="parse(text: string)" flutter="parse(String text)" code /> | <Fw js="TextPart[]" flutter="List<TextPart>" code /> | Parses one piece of text, usually a line. |
| `reset()`                                                         | `void`                                               | Forgets the current style.                |

::: fw js

```ts
import { AnsiParser } from 'lognal';

new AnsiParser().parse('\x1b[1;31mfailed\x1b[0m after 3 tries');
// [{ type: 'text', text: 'failed', style: { bold: true, color: 1 } },
//  { type: 'text', text: ' after 3 tries' }]
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

AnsiParser().parse('\x1b[1;31mfailed\x1b[0m after 3 tries');
// [TextPart('failed', style: LogTextStyle(bold: true, color: AnsiTextColor(1))),
//  TextPart(' after 3 tries')]
```

:::

### stripAnsi

```
stripAnsi(text)
```

Removes every ANSI escape sequence from text.

## Lines

### LineSplitter

::: fw js

```ts
new LineSplitter();
```

:::

::: fw flutter

```dart
LogLineSplitter()
```

The class is `LogLineSplitter`, because `LineSplitter` is already a name in `dart:convert`.

:::

Splits a stream of text chunks into lines. A line ends at `\n`, `\r\n` or a lone `\r`, and a `\r\n` pair split across two chunks still counts as one line break.

| Member                                                            | Type                                             | Description                                                        |
| ----------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------ |
| <Fw js="push(chunk: string)" flutter="push(String chunk)" code /> | <Fw js="string[]" flutter="List<String>" code /> | Adds a chunk and returns the lines it completed.                   |
| `flush()`                                                         | <Fw js="string[]" flutter="List<String>" code /> | Returns the unfinished last line, if any, and resets the splitter. |
| `hasPending`                                                      | <Fw js="boolean" flutter="bool" code />          | Whether text is waiting for a line break.                          |

### splitLines

```
splitLines(text)
```

Splits a whole string into lines. A trailing line break does not add an empty line.

## Text width

These functions measure text with the rules of the viewer. See [Width on the grid](/guide/cjk#width-on-the-grid).

::: fw js

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

:::

::: fw flutter

| Function                                                            | Returns        | Description                                                                                                                                   |
| ------------------------------------------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `measureCells(String text, [AmbiguousWidth ambiguousWidth])`        | `int`          | How many cells a string takes on one row.                                                                                                     |
| `truncateCells(String text, int maxCells, [AmbiguousWidth aw])`     | `String`       | Cuts a string to at most `maxCells` cells, ending it with `…` when anything was cut. A wide character that would cross the limit is left out. |
| `padCells(String text, int cells, [AmbiguousWidth ambiguousWidth])` | `String`       | Pads a string with spaces to a width in cells, which is what the table builder aligns with.                                                   |
| `clusterWidth(String cluster, [AmbiguousWidth ambiguousWidth])`     | `int`          | How many cells one grapheme cluster takes.                                                                                                    |
| `codePointWidth(int codePoint, [AmbiguousWidth ambiguousWidth])`    | `int`          | How many cells one code point takes: 0, 1 or 2. Control characters return 1.                                                                  |
| `splitGraphemes(String text)`                                       | `List<String>` | Splits text into grapheme clusters with the active splitter.                                                                                  |
| `setGraphemeSplitter(GraphemeSplitter? splitter)`                   | `void`         | Replaces the grapheme splitter. `null` goes back to the default, which uses `package:characters`.                                             |
| `normalizeNfc(String text)`                                         | `String`       | Composes text into Unicode normalization form C, which is what the filter and the search compare with. Dart has no `String.normalize`.        |

`ambiguousWidth` defaults to `1`. `unicodeVersion` is the version of the Unicode data the widths come from, `'17.0.0'`.

```dart
typedef AmbiguousWidth = int;
typedef GraphemeSplitter = List<String> Function(String text);
```

`splitGraphemesFallback` is the splitter used where `package:characters` is not wired up, and it is public so a test can compare the two.

:::
