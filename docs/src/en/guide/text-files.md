---
order: 3
description: Read log files into lognal, detect UTF-8 or a legacy encoding such as EUC-KR, follow a growing file, and write text with ANSI colors.
---

# Text files

## Read a file

::: fw js

`readTextFile` reads a `Blob`, such as a file picked with `<input type="file">` or dropped on the page, and adds one entry for each line.

```ts
import { LogViewer, readTextFile } from 'lognal';

const viewer = new LogViewer(container, {
	core: { maxEntries: 200000, mergeRepeats: false }
});
const picker = document.querySelector<HTMLInputElement>('#log-file')!;

picker.addEventListener('change', async () => {
	const file = picker.files?.[0];

	if (!file) {
		return;
	}

	const result = await readTextFile(file, viewer.store);

	viewer.console.info(`Read ${result.lines} lines from ${file.name} as ${result.encoding}`);
});
```

The file is read in chunks of 256 KiB, so a large file never has to fit in memory as one string.

:::

::: fw flutter

`readTextStream` reads a stream of byte chunks and adds one entry for each line. Nothing is held in memory but the chunk being decoded and the line being built, so a file larger than memory reads fine.

```dart
import 'package:lognal/lognal.dart';

final ReadTextResult result = await readTextStream(
  localTextFile('/var/log/app.log').openRead(),
  store,
);

log.info('Read %d lines as %s', <Object?>[result.lines, result.decoded]);
```

`localTextFile(path)` opens a file on the platforms that have a file system. On the web there is none, so hand `readTextBytes` the bytes the browser gave the page:

```dart
final XFile? picked = await openFile();

if (picked != null) {
  await readTextBytes(await picked.readAsBytes(), store);
}
```

Picking the file is the application's job: reading a file the reader chose needs a plugin, and which plugin is your decision, the same way opening a link is.

:::

A line ends at `\n`, `\r\n` or a lone `\r`, and a line break at the end of the file does not add an empty line.

Two store options matter for files:

- `maxEntries` decides how many lines are kept. The default is 10,000, and the oldest lines are dropped past it.
- `mergeRepeats` is on by default, so identical lines that follow each other become one entry with a repeat count. Turn it off to keep every line as its own entry.

### Options

::: fw js

| Option             | Type                                      | Default                                     | Description                                                                                   |
| ------------------ | ----------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `encoding`         | `string`                                  | `'auto'`                                    | The encoding, such as `'utf-8'` or `'euc-kr'`. `'auto'` detects it.                           |
| `fallbackEncoding` | `string`                                  | The legacy encoding of the browser language | The encoding `'auto'` uses when the file is not UTF-8.                                        |
| `level`            | `LogLevel`                                | `'log'`                                     | The level of every line.                                                                      |
| `ansi`             | `boolean`                                 | `true`                                      | Whether ANSI escape codes become styles. With `false`, the escape character is shown as `^[`. |
| `chunkSize`        | `number`                                  | `262144`                                    | Bytes read at a time.                                                                         |
| `signal`           | `AbortSignal`                             | None                                        | Stops reading when aborted. The lines read so far stay in the store.                          |
| `onProgress`       | `(loaded: number, total: number) => void` | None                                        | Called after every chunk with the bytes read so far and the size of the file.                 |

The returned promise resolves to `{ lines, bytes, encoding }`: the number of lines added, the number of bytes read, and the encoding used. When the signal is aborted, the promise still resolves, with the counts up to that point.

:::

::: fw flutter

| Option             | Type                                    | Default                         | Description                                                                                   |
| ------------------ | --------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------- |
| `encoding`         | `String`                                | `'auto'`                        | The encoding, such as `'utf-8'`. `'auto'` detects it.                                         |
| `fallbackEncoding` | `String?`                               | The legacy encoding of `locale` | The encoding `'auto'` uses when the file is not UTF-8.                                        |
| `level`            | `LogLevel`                              | `LogLevel.log`                  | The level of every line.                                                                      |
| `ansi`             | `bool`                                  | `true`                          | Whether ANSI escape codes become styles. With `false`, the escape character is shown as `^[`. |
| `onProgress`       | `void Function(int loaded, int? total)` | None                            | Called after every chunk with the bytes read so far, and the total when the size is known.    |

The future completes with a `ReadTextResult`: `lines`, `bytes`, the `encoding` the file was taken to be in, and the encoding it was actually `decoded` with. Compare the last two to tell the reader when nothing could decode what the file announced.

:::

## Encodings

With <Fw js="encoding: 'auto'" flutter="encoding: 'auto'" code />, lognal picks the encoding in this order:

1. A byte order mark at the start of the file: UTF-8, UTF-16LE or UTF-16BE.
1. UTF-8, when the first 64 KiB of the file are valid UTF-8.
1. `fallbackEncoding`.

The default fallback is the encoding a system assumes for text in the reader's language, from the table of suggested default encodings in the HTML Standard.

| Language                                                   | Fallback       |
| ---------------------------------------------------------- | -------------- |
| Korean (`ko`)                                              | `euc-kr`       |
| Japanese (`ja`)                                            | `shift_jis`    |
| Traditional Chinese (`zh-TW`, `zh-HK`, `zh-MO`, `zh-Hant`) | `big5`         |
| Other Chinese (`zh`)                                       | `gbk`          |
| Russian, Ukrainian and other Cyrillic languages            | `windows-1251` |
| Every language not in the table                            | `windows-1252` |

The table also covers Central European, Greek, Baltic, Arabic, Hebrew, Turkish, Thai and Vietnamese. `legacyEncodingFor(locale)` returns the fallback for any language tag, and `detectEncoding(bytes, fallback)` names the encoding of bytes you already have.

::: fw js

A file saved by an older Korean Windows program is usually EUC-KR. If your users read such files whatever their browser language is, set the fallback yourself:

```ts
await readTextFile(file, viewer.store, { fallbackEncoding: 'euc-kr' });
```

The encoding name goes to `TextDecoder`, so any label it accepts works. An unknown label makes `readTextFile` reject with a `RangeError`.

:::

::: fw flutter

### What this package decodes

UTF-8, UTF-16 in both byte orders, Latin-1 and Windows-1252 decode here. A legacy CJK encoding — `euc-kr`, `shift_jis`, `big5`, `gbk` — is a table of tens of thousands of characters each, which a browser already has and Dart does not, so rather than carry four of them the package takes one from you:

```dart
final void Function() remove = registerTextDecoder((String encoding) {
  return encoding == 'euc-kr' ? MyEucKrSink() : null;
});
```

A factory is asked for every encoding the reader meets, newest first, and returns `null` for the ones it does not handle, so it can also replace a built-in one. `decoderFor(name)` answers whether anything knows a name.

Without a decoder for the encoding it detected, a read falls back to Windows-1252 and says so through `result.decoded`, which is how a legacy file reads as mojibake rather than failing. Tell the reader what happened:

```dart
if (result.encoding != result.decoded) {
  log.warn('%s could not be decoded, so it was read as %s', <Object?>[
    result.encoding,
    result.decoded,
  ]);
}
```

:::

## Follow a growing file

`followTextFile` reads a file and keeps adding the lines appended to it, like `tail -f`.

::: fw js

```js
import { followTextFile } from 'lognal';

button.addEventListener('click', async () => {
	const [handle] = await window.showOpenFilePicker();
	const follow = followTextFile(handle, viewer.store, {
		interval: 1000,
		onError: (error) => viewer.console.warn('Could not read the file', error)
	});

	try {
		const lines = await follow.ready;

		viewer.console.info(`Read ${lines} lines, now following`);
	} catch (error) {
		viewer.console.error('Could not read the file', error);
	}
});
```

It needs a file handle from the File System Access API, which only Chromium-based browsers provide on secure pages. The picker must be opened from a user action, such as a click. A file from `<input type="file">` is a snapshot that cannot be followed; read it once with `readTextFile`.

| Option             | Type                       | Default                                     | Description                                                                                  |
| ------------------ | -------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                                      | Milliseconds between checks for new data.                                                    |
| `encoding`         | `string`                   | `'auto'`                                    | The encoding, or `'auto'` to detect it from the first read.                                  |
| `fallbackEncoding` | `string`                   | The legacy encoding of the browser language | The encoding `'auto'` uses when the file is not UTF-8.                                       |
| `level`            | `LogLevel`                 | `'log'`                                     | The level of every line.                                                                     |
| `ansi`             | `boolean`                  | `true`                                      | Whether ANSI escape codes become styles.                                                     |
| `onReset`          | `() => void`               | None                                        | Called when the file was replaced, rotated or truncated, and is read from the start.         |
| `onError`          | `(error: unknown) => void` | None                                        | Called when a check after the first one fails, for example because permission was withdrawn. |

:::

::: fw flutter

```dart
final FollowHandle follow = followTextFile(
  localTextFile('/var/log/app.log'),
  store,
  options: FollowTextOptions(
    interval: const Duration(seconds: 1),
    onError: (Object error) => log.warn('Could not read the file', <Object?>[error]),
  ),
);

try {
  final int lines = await follow.ready;

  log.info('Read %d lines, now following', <Object?>[lines]);
} catch (error) {
  log.error(error);
}
```

It takes a `TextFileSource` rather than a path, so that the package compiles for the web, where there is no file system. `localTextFile` is one; `CallbackTextFile` wraps whatever else the platform gives you:

```dart
final TextFileSource source = CallbackTextFile(
  length: () async => bytes.length,
  read: (int start) => Stream<List<int>>.value(bytes.sublist(start)),
  lastModified: () async => modified,
);
```

| Option             | Type                    | Default                         | Description                                                                          |
| ------------------ | ----------------------- | ------------------------------- | ------------------------------------------------------------------------------------ |
| `interval`         | `Duration`              | `Duration(seconds: 1)`          | How long to wait between checks for new data.                                        |
| `encoding`         | `String`                | `'auto'`                        | The encoding, or `'auto'` to detect it from the first read.                          |
| `fallbackEncoding` | `String?`               | The legacy encoding of `locale` | The encoding `'auto'` uses when the file is not UTF-8.                               |
| `level`            | `LogLevel`              | `LogLevel.log`                  | The level of every line.                                                             |
| `ansi`             | `bool`                  | `true`                          | Whether ANSI escape codes become styles.                                             |
| `onReset`          | `void Function()`       | None                            | Called when the file was replaced, rotated or truncated, and is read from the start. |
| `onError`          | `void Function(Object)` | None                            | Called when a check after the first one fails, for example because the file is gone. |

:::

`followTextFile` returns a handle right away:

- `ready` <Fw js="is a promise that resolves" flutter="is a future that completes" /> after the first read, with the number of lines it added. When the first read fails, `ready` <Fw js="rejects" flutter="completes" /> with that error instead, and `onError` is not called for it. Handle it, as the example does.
- `stop()` stops checking the file. It writes what the decoder still holds and the unfinished last line, if there is one.

Every check asks the source for its size and reads the bytes after the last position. A line without a line break at its end waits for the next check. Checking continues after a failed check, including a failed first read.

lognal treats the file as replaced when it is shorter than the last position, or when it has the same size as before but a new modification time. Then what the decoder still holds and the unfinished line are written, reading starts again from the beginning, and `onReset` is called. Saving the file without changing its size, or only touching it, counts as a replacement too. A replacement that is larger than the part already read looks like appended data and is not detected.

## Write text with ANSI colors

<Fw js="viewer.write and viewer.writeLines" flutter="store.write and store.writeLines" /> add text directly. `write` adds one entry and keeps line breaks inside it, and `writeLines` adds one entry for each line. Unlike the file readers, they leave ANSI escape codes alone unless you ask for them.

::: fw js

```ts
viewer.writeLines('\x1b[32m✔\x1b[0m build finished in \x1b[1m1.2s\x1b[0m', { ansi: true });
viewer.write('Deploy started', { level: 'info' });
```

A style can continue from one chunk of output to the next, the way a terminal keeps it from line to line. To keep it across calls, pass the same `AnsiParser` every time:

```ts
import { AnsiParser } from 'lognal';

const parser = new AnsiParser();
const socket = new WebSocket('wss://example.com/build-log');

socket.addEventListener('message', (event) => {
	viewer.writeLines(String(event.data), { ansi: parser });
});
```

:::

::: fw flutter

```dart
store
  ..writeLines(
    '\x1b[32m✔\x1b[0m build finished in \x1b[1m1.2s\x1b[0m',
    const WriteOptions(ansi: true),
  )
  ..write('Deploy started', const WriteOptions(level: LogLevel.info));
```

A style can continue from one chunk of output to the next, the way a terminal keeps it from line to line. To keep it across calls, pass the same `AnsiParser` every time:

```dart
final AnsiParser parser = AnsiParser();

socket.stream.listen((Object? message) {
  store.writeLines('$message', WriteOptions(parser: parser));
});
```

:::

`writeLines` treats the end of every call as the end of a line. When a chunk can stop in the middle of a line, write it with a `TextLineWriter` instead. It keeps the unfinished line until its line break arrives, and parses ANSI codes unless you turn them off.

::: fw js

```ts
import { TextLineWriter } from 'lognal';

const writer = new TextLineWriter(viewer.store);

socket.addEventListener('message', (event) => writer.write(String(event.data)));
socket.addEventListener('close', () => writer.flush());
```

:::

::: fw flutter

```dart
final TextLineWriter writer = TextLineWriter(store);

socket.stream.listen(
  (Object? message) => writer.write('$message'),
  onDone: writer.flush,
);
```

:::

The parser turns Select Graphic Rendition codes into styles and removes every other escape sequence, such as cursor movement or an OSC hyperlink wrapper, so they do not show up as stray characters.

| Codes                        | Style                                                    |
| ---------------------------- | -------------------------------------------------------- |
| `0`                          | Reset every style.                                       |
| `1`, `2`, `3`, `4`, `9`      | Bold, dim, italic, underline, strikethrough.             |
| `22`, `23`, `24`, `29`       | Turn off bold and dim, italic, underline, strikethrough. |
| `30` to `37`, `90` to `97`   | Text color from the 16 theme colors.                     |
| `40` to `47`, `100` to `107` | Background color from the 16 theme colors.               |
| `38;5;n`, `48;5;n`           | Text or background color from the 256-color palette.     |
| `38;2;r;g;b`, `48;2;r;g;b`   | Text or background color as RGB.                         |
| `39`, `49`                   | Default text or background color.                        |

Colors 0 to 15 come from the theme's own sixteen, 16 to 231 from the 6 × 6 × 6 color cube, and 232 to 255 from the gray ramp. Other codes, such as inverse, are ignored. `stripAnsi(text)` removes every escape sequence from a string.

`write` and `writeLines` also accept `level`, `kind`, `time`, `groups`, `token` and `style`. See [`WriteOptions`](/reference/log-store#writeoptions).
