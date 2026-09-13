---
layout: home

title: lognal
titleTemplate: Canvas log viewer for the browser
description: lognal is a terminal-style log viewer for the browser, drawn on a canvas. It mirrors the console, reads log files, and shows typed values that expand and collapse.

hero:
  name: lognal
  text: A terminal-style log viewer for the browser
  tagline: Draw logs on a canvas, mirror the console, read log files, and inspect values that expand and collapse.
  actions:
    - theme: brand
      text: Getting started
      link: /getting-started
    - theme: alt
      text: Guide
      link: /guide/
  image:
    src: /icon.webp
    alt: lognal

features:
  - title: Drawn on a canvas
    details: Log text is painted on one canvas instead of one DOM element per line. The cost of a frame depends on the rows on screen, not on the size of the history.
    link: /introduction
    linkText: Why a canvas
  - title: Mirrors the console
    details: Record console.log, warn, error, table, group, count, time and the other methods, with the format specifiers %s, %d, %o and %c.
    link: /guide/console
    linkText: Console capture
  - title: Values that expand
    details: Objects, arrays, Map, Set, errors and DOM elements are captured when they are logged, and open and close with a click.
    link: /guide/values
    linkText: Typed values
  - title: Reads log files
    details: Read a picked file in chunks, detect UTF-8 or a legacy encoding such as EUC-KR, and follow a growing file in Chromium browsers.
    link: /guide/text-files
    linkText: Text files
  - title: Korean and CJK text
    details: Wide characters take two cells, Hangul words stay together when a line wraps, and the input line waits for IME composition to finish.
    link: /guide/cjk
    linkText: Korean and CJK
  - title: No framework required
    details: The core has no runtime dependencies and no framework code. A React component comes from lognal/react, and every color is a CSS custom property.
    link: /guide/react
    linkText: React
---

## Try it

The viewer below runs the library from this repository. Use the buttons to write logs, then try the toolbar: filter the text, pick a level, turn wrapping off, or scroll up to stop following.

<ClientOnly>
  <LiveViewer preset="console" />
</ClientOnly>

## A short example

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!);

viewer.hookConsole();
console.log('Signed in as %s', 'ada', { id: 42, roles: ['admin'] });
```

The container needs a height, for example `#logs { height: 400px; }`. See [Getting started](/getting-started) for the full setup.
