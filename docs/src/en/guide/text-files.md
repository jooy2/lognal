---
order: 3
description: Read log files into lognal with readTextFile, detect UTF-8 or legacy encodings such as EUC-KR, follow a growing file with followTextFile, and write text with ANSI colors.
---

# Text files

## Read a file

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

The file is read in chunks of 256 KiB, so a large file never has to fit in memory as one string. A line ends at `\n`, `\r\n` or a lone `\r`, and a line break at the end of the file does not add an empty line.

Two store options matter for files:

- `maxEntries` decides how many lines are kept. The default is 10,000, and the oldest lines are dropped past it. Use `Infinity` to keep every line.
- `mergeRepeats` is on by default, so identical lines that follow each other become one entry with a repeat count. Turn it off to keep every line as its own entry.

### Options

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

## Encodings

With `encoding: 'auto'`, lognal picks the encoding in this order:

1. A byte order mark at the start of the file: UTF-8, UTF-16LE or UTF-16BE.
1. UTF-8, when the first 64 KiB of the file are valid UTF-8.
1. `fallbackEncoding`.

The default fallback is the encoding browsers assume for pages in the user's language, taken from `navigator.language` and the table of suggested default encodings in the HTML Standard.

| Language                                                   | Fallback       |
| ---------------------------------------------------------- | -------------- |
| Korean (`ko`)                                              | `euc-kr`       |
| Japanese (`ja`)                                            | `shift_jis`    |
| Traditional Chinese (`zh-TW`, `zh-HK`, `zh-MO`, `zh-Hant`) | `big5`         |
| Other Chinese (`zh`)                                       | `gbk`          |
| Russian, Ukrainian and other Cyrillic languages            | `windows-1251` |
| Every language not in the table                            | `windows-1252` |

The table also covers Central European, Greek, Baltic, Arabic, Hebrew, Turkish, Thai and Vietnamese. `legacyEncodingFor(locale)` returns the fallback for any language tag.

A file saved by an older Korean Windows program is usually EUC-KR. If your users read such files whatever their browser language is, set the fallback yourself:

```ts
await readTextFile(file, viewer.store, { fallbackEncoding: 'euc-kr' });
```

The encoding name goes to `TextDecoder`, so any label it accepts works. An unknown label makes `readTextFile` reject with a `RangeError`. To detect the encoding of bytes you already have, call `detectEncoding(bytes, fallback)`.

## Follow a growing file

`followTextFile` reads a file and keeps adding the lines appended to it, like `tail -f`.

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

`followTextFile` returns a handle right away:

- `ready` is a promise that resolves after the first read, with the number of lines it added. When the first read fails, for example because of a permission error, `ready` rejects with that error instead, and `onError` is not called for it. Handle the rejection, as the example does.
- `stop()` stops checking the file. It writes what the decoder still holds and the unfinished last line, if there is one.

Every check asks the handle for a fresh copy of the file and reads the bytes after the last position. A line without a line break at its end waits for the next check. Checking continues after a failed check, including a failed first read.

lognal treats the file as replaced when it is shorter than the last position, or when it has the same size as before but a new `lastModified` time. Then what the decoder still holds and the unfinished line are written, reading starts again from the beginning, and `onReset` is called. Saving the file without changing its size, or only touching it, counts as a replacement too. A replacement that is larger than the part already read looks like appended data and is not detected.

## Write text with ANSI colors

`viewer.write` and `viewer.writeLines` add text directly. `write` adds one entry and keeps line breaks inside it, and `writeLines` adds one entry for each line. Unlike the file readers, they leave ANSI escape codes alone unless you pass `ansi: true`.

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

`writeLines` treats the end of every call as the end of a line. When a chunk can stop in the middle of a line, write it with a `TextLineWriter` instead. It keeps the unfinished line until its line break arrives, and parses ANSI codes unless you pass `ansi: false`.

```ts
import { TextLineWriter } from 'lognal';

const writer = new TextLineWriter(viewer.store);

socket.addEventListener('message', (event) => writer.write(String(event.data)));
socket.addEventListener('close', () => writer.flush());
```

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

Colors 0 to 15 come from the `--lognal-ansi-*` properties of the theme, 16 to 231 from the 6 × 6 × 6 color cube, and 232 to 255 from the gray ramp. Other codes, such as inverse, are ignored. `stripAnsi(text)` removes every escape sequence from a string.

`write` and `writeLines` also accept `level`, `kind`, `time`, `groups`, `token` and `style`. See [`WriteOptions`](/reference/log-store#writeoptions).
