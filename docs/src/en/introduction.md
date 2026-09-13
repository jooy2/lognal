---
order: 1
description: What lognal is, why it draws logs on a canvas, what it can do, and which browsers it supports.
---

# Introduction

lognal is a log viewer for web pages that looks and works like a terminal. It draws log output on a canvas, so it keeps up with a fast stream of messages and a long history without slowing the page down.

## What it does

- **Mirror the console.** Record `console.log`, `console.warn`, `console.table`, `console.group` and the other console methods, and show them the way browser developer tools do. The original console keeps working. See [Console capture](/guide/console).
- **Show typed values.** Objects, arrays, `Map`, `Set`, errors and DOM elements are captured when they are logged and open and close with a click. See [Typed values](/guide/values).
- **Read text files.** Read a log file in chunks, detect its encoding, and turn ANSI escape codes into colors. In Chromium browsers, lognal can also follow a file that keeps growing. See [Text files](/guide/text-files).
- **Work like a log viewer.** A toolbar follows new logs, clears the log, scrolls to the top or bottom, turns wrapping on and off, and filters by text and level. Ctrl+F searches the log and highlights every match without hiding anything. A status bar counts entries, each entry can show a timestamp, and text can be selected and copied, or copied a whole entry at a time from the menu of that entry. Addresses in the log are links that open in a new tab, after a confirmation by default. In entry mode, whole entries are selected with Ctrl, Cmd and Shift, the way files are, and copied together. See [The viewer](/guide/viewer).
- **Accept commands.** An optional input line passes each command to a function you provide and prints the reply. See [Input line](/guide/viewer#input-line).
- **Follow your theme.** Light, dark and automatic modes are built in, and every color is a CSS custom property. See [Themes and fonts](/guide/theming).
- **Handle Korean and other CJK text.** Wide characters take two cells, Hangul words stay together when a line wraps, the input line works with IME composition, and legacy encodings such as EUC-KR are detected. See [Korean and CJK text](/guide/cjk).

## Why a canvas

A log viewer that creates one DOM element per line gets slower as the history grows. Every element costs memory, style and layout work, and a list of a hundred thousand lines is a large page even when only forty lines are on screen.

lognal keeps entries as plain data and draws only the rows that are visible. The work is split into three parts:

1. A `LogStore` holds the entries in the order they were added, up to a limit of 10,000 by default. The oldest entries are dropped once the limit is reached.
1. A `LogLayout` turns entries into rows for the current width. It caches measured lines, so most frames reuse the work of earlier ones.
1. A renderer draws the visible rows on a `<canvas>` with the 2D context. Any number of new messages between two animation frames costs one draw.

The cost of a frame depends on the number of rows on screen, not on the size of the history.

The browser still does the jobs it does better than a canvas. The log area is a native scroll container, so the mouse wheel, touch and keyboard scrolling work as usual. The input line is a real `<textarea>`, so the browser handles the caret, paste and IME composition. The toolbar is made of real buttons, and a visually hidden list mirrors the visible entries for screen readers.

Text on a canvas is not part of the page text. The viewer provides its own selection, copy and filter instead: drag to select, press Ctrl+C or Cmd+C to copy, and use the filter in the toolbar to search. The text is laid out on a grid of cells, so the log area needs a monospace font.

## Package contents

lognal is one npm package with three entry points. The core has no runtime dependencies. React is an optional peer dependency, needed only for `lognal/react`.

| Entry point        | Contents                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `lognal`           | The viewer, the store and layout, console capture, text sources and the Canvas 2D renderer |
| `lognal/react`     | The `LogViewer` React component, for React 18 or later                                     |
| `lognal/style.css` | The layout of the viewer and the light and dark themes                                     |

## Browser support

lognal targets current versions of Chrome, Edge, Firefox and Safari. The package is compiled to ES2022. A few features depend on newer browser APIs:

- **Grapheme clusters.** lognal splits text into user-perceived characters with `Intl.Segmenter`, available in Chrome 87, Firefox 125 and Safari 14.1. Where it is missing, a built-in fallback joins combining marks, variation selectors, emoji modifiers, zero width joiner sequences and flag pairs to the character before them. `setGraphemeSplitter` replaces the splitter with your own.
- **Following a file.** `followTextFile` needs a file handle from the File System Access API (`showOpenFilePicker`). Only Chromium-based browsers provide it, and only on secure pages served over HTTPS or from `localhost`. `readTextFile` works in every browser.
- **Copying.** `copySelection` uses the asynchronous Clipboard API on secure pages and falls back to `document.execCommand('copy')` elsewhere.
- **IME input on Safari.** Safari up to version 26 fires `compositionend` before the `keydown` of the key that commits a composition. The input line accounts for this, so pressing Enter to confirm a Japanese or Chinese candidate does not submit the command.
