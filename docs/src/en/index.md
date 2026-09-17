---
layout: home

title: lognal
titleTemplate: Canvas log viewer for the web and Flutter
description: lognal is a terminal-style log viewer drawn on a canvas, for the browser and for Flutter. It mirrors what the application prints, reads log files, and shows typed values that expand and collapse.

hero:
  name: lognal
  text: A terminal-style log viewer, twice
  tagline: One core, on npm and on pub.dev. Draw logs on a canvas, mirror what the application prints, read log files, and inspect values that expand and collapse.
  actions:
    - theme: brand
      text: Getting started
      link: /getting-started
    - theme: alt
      text: Guide
      link: /guide/
    - theme: alt
      text: Demo
      link: /demo
  image:
    src: /icon.webp
    alt: lognal

features:
  - title: Drawn on a canvas
    details: Log text is painted on one canvas instead of one DOM element per line. The cost of a frame depends on the rows on screen, not on the size of the history.
    link: /introduction
    linkText: Why a canvas
  - title: Mirrors what you print
    details: console.log, warn, error, table and group in a browser; debugPrint, print and a failed build in Flutter. Captured when the call is made, with the format specifiers %s, %d, %o and %c.
    link: /guide/console
    linkText: Capturing output
  - title: Values that expand
    details: Objects, lists, maps, sets and errors are captured when they are logged, and open and close with a click.
    link: /guide/values
    linkText: Typed values
  - title: Reads log files
    details: Read a file a chunk at a time, detect the encoding from its own bytes, and keep reading one as it grows.
    link: /guide/text-files
    linkText: Text files
  - title: Korean and CJK text
    details: Wide characters take two cells, Hangul words stay together when a line wraps, and the input line waits for IME composition to finish.
    link: /guide/cjk
    linkText: Korean and CJK
  - title: One library, two languages
    details: The core is written twice, file for file, in TypeScript and in Dart, and the tests of both say the same things. A log line means the same in a browser and in an app.
    link: /guide/framework
    linkText: In a framework
---

## Try it

The viewer below runs the library from this repository. Use the buttons to write logs, then try the toolbar: filter the text, pick a level, turn wrapping off, or scroll up to stop following. Every other option and feature is on the [demo page](/demo).

<ClientOnly>
  <LiveViewer preset="console" />
</ClientOnly>

## A short example

There is a switch above the menu on every other page of this site. It decides which package the examples are written for; this page has no menu, so both are here.

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!);

viewer.hookConsole();
console.log('Signed in as %s', 'ada', { id: 42, roles: ['admin'] });
```

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

hookDebugPrint(store);
debugPrint('Signed in as ada');

// … and wherever the log belongs on screen.
SizedBox(height: 400, child: LogViewer(store: store));
```

Whatever it is put in needs a height. See [Getting started](/getting-started) for the full setup.
