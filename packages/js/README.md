<img src="https://raw.githubusercontent.com/jooy2/lognal/refs/heads/main/.github/resources/lognal-logo.webp" width="96" height="96" alt="lognal logo" />

# lognal for JavaScript

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jooy2/lognal/blob/main/LICENSE) [![npm latest package](https://img.shields.io/npm/v/lognal/latest.svg)](https://www.npmjs.com/package/lognal) [![npm downloads](https://img.shields.io/npm/dm/lognal.svg)](https://www.npmjs.com/package/lognal) [![run-test-js](https://github.com/jooy2/lognal/actions/workflows/run-test-js.yml/badge.svg)](https://github.com/jooy2/lognal/actions/workflows/run-test-js.yml)

**lognal** is a log viewer for web pages that looks and behaves like a terminal. It draws log output on a canvas instead of creating a DOM element for every line, so a fast stream of messages and a long history do not slow the page down.

This is the npm package. The Flutter package lives in [`packages/flutter`](../flutter), and the documentation for both is at [lognal.cdget.com](https://lognal.cdget.com).

## What it does

- **Shows the browser console inside your page.** Hook `console.log`, `console.warn`, `console.table`, `console.group` and the rest. Arguments are captured at the moment of the call, and the original console keeps working.
- **Reads log files.** Open a text file and read it line by line. The encoding is detected, including legacy encodings such as EUC-KR. In Chromium-based browsers, a file picked with the File System Access API can be followed as it grows.
- **Displays values by type.** Objects, arrays, maps, sets, errors and DOM elements expand and collapse, and `console.table` draws a table.
- **Accepts commands.** Connect a handler, and the viewer shows an input line and prints the replies.
- **Handles Korean and other CJK text.** Wide characters stay on the grid, Korean text wraps at spaces, and Enter waits for IME composition to finish.

The viewer has a toolbar (follow new logs, clear, scroll to top and bottom, line wrapping, themes, hidden messages, text filter and level filter), a status bar, a search bar (Ctrl+F) that highlights matches without hiding entries, timestamps, links that open in a new tab after a confirmation, a menu on each entry for copying and expanding it, a mode that selects whole entries the way a file manager selects files, six color palettes that follow the operating system by default, and a custom scrollbar. Every part can be turned off or restyled with CSS custom properties.

## Quick start

```bash
npm install lognal
```

```javascript
import { LogViewer } from 'lognal';
import 'lognal/style.css';

// The container needs a height.
const viewer = new LogViewer(document.getElementById('logs'), {
	timestamps: true,
	core: { maxEntries: 20000 }
});

viewer.hookConsole();
console.log('Hello %s', 'lognal', { id: 1, tags: ['canvas', 'logs'] });
```

With React:

```jsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export const Logs = () => <LogViewer hookConsole style={{ height: 400 }} />;
```

Reading a file:

```javascript
import { readTextFile } from 'lognal';

input.addEventListener('change', async () => {
	await readTextFile(input.files[0], viewer.store);
});
```

## Entry points

| Specifier          | What it is                                                     |
| ------------------ | -------------------------------------------------------------- |
| `lognal`           | The viewer, the store, the layout and the sources.             |
| `lognal/react`     | The `LogViewer` React component. `react` is a peer dependency. |
| `lognal/style.css` | The stylesheet, required for the viewer to look like itself.   |

## Browser support

lognal targets current versions of Chrome, Edge, Firefox and Safari. A few features depend on newer platform APIs:

| Feature                                | Requirement                                                                    |
| -------------------------------------- | ------------------------------------------------------------------------------ |
| Grapheme clusters for emoji and Hangul | `Intl.Segmenter`: Chrome 87, Firefox 125, Safari 14.1. A fallback is built in. |
| Following a growing file               | File System Access API, Chromium-based browsers only                           |

## Development

```bash
npm install
npm run dev          # playground at http://localhost:5173
npm test             # unit tests in Node.js and browser tests in Playwright
npm run lint
npm run build
```

`LOGNAL_TEST_BROWSERS=chromium` runs the browser suite in one browser instead of three. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for the project layout and the workflow.

## License

[MIT](LICENSE) © [CDGet](https://cdget.com). The character width tables are generated from the Unicode Character Database, whose license is included in `src/core/text/unicode-width-data.ts`.
