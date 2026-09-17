<img src="https://raw.githubusercontent.com/jooy2/lognal/refs/heads/main/.github/resources/lognal-logo.webp" width="96" height="96" alt="lognal logo" />

# lognal for Flutter

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jooy2/lognal/blob/main/LICENSE) [![pub latest package](https://img.shields.io/pub/v/lognal.svg)](https://pub.dev/packages/lognal) [![pub points](https://img.shields.io/pub/points/lognal.svg)](https://pub.dev/packages/lognal/score) [![run-test-flutter](https://github.com/jooy2/lognal/actions/workflows/run-test-flutter.yml/badge.svg)](https://github.com/jooy2/lognal/actions/workflows/run-test-flutter.yml)

**lognal** is a log viewer widget that looks and behaves like a terminal. It draws log output on a canvas instead of building a widget for every line, so a fast stream of messages and a history of tens of thousands of entries cost the same frame.

This is the pub.dev package. The npm package lives in [`packages/js`](../js), and the documentation for both is at [lognal.cdget.com](https://lognal.cdget.com).

## What it does

- **Shows what the application already prints.** `debugPrint` is hooked and put back, `print` is caught by running your app in a zone, and `FlutterError.onError` puts a failed build in the log with its stack.
- **Reads log files.** One entry per line, from a file on disk or the bytes a browser handed you. The encoding is detected from the byte order mark and from the bytes themselves.
- **Displays values by type.** Lists, maps, sets and errors expand and collapse, a class that writes `toJson()` opens into its properties, and a collection is drawn as a table.
- **Accepts commands.** Connect a handler, and the viewer shows an input line and prints the replies.
- **Handles Korean and other CJK text.** Wide characters stay on the grid, Korean wraps at spaces, and the input line is a real text field, so an input method composes into it and Enter reaches the command only once the composition is finished.

The viewer has a toolbar (follow new logs, clear, scroll to top and bottom, line wrapping, entry selection, themes, hidden messages, text filter and level filter), a status bar, a search bar that highlights every match without hiding an entry, timestamps, links that open after a confirmation, a menu on each entry for copying and expanding it, a mode that selects whole entries the way a file manager selects files, six color palettes that follow the system by default, and its own scrollbars. Every part can be turned off, and the whole palette is a value you can replace.

## Quick start

```bash
flutter pub add lognal
```

```dart
import 'package:flutter/material.dart';
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

void main() {
  // Everything the app prints from here on reaches the viewer, and the terminal.
  hookDebugPrint(store);
  hookFlutterErrors(store);

  runZonedWithLognal(store, () => runApp(const MyApp()));
}

// Wherever the log belongs on screen. Give it a height.
class LogPanel extends StatelessWidget {
  const LogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 400, child: LogViewer(store: store));
  }
}
```

Writing to it from your own code:

```dart
final LognalConsole log = LognalConsole(store);

log.info('Connected to %s in %fms', <Object?>['database', 12.5]);
log.warn('Retrying the connection');
log.error(error, const <Object?>[], stackTrace);
log.table(<Map<String, Object?>>[
  <String, Object?>{'name': '김철수', 'orders': 12},
]);
```

Reading a log file:

```dart
final ReadTextResult result = await readTextStream(
  localTextFile('/var/log/app.log').openRead(),
  store,
);
```

Following one as it grows:

```dart
final FollowHandle follow = followTextFile(localTextFile('/var/log/app.log'), store);

await follow.ready;
// … later
follow.stop();
```

## Options

Everything is on `LogViewerOptions`, and a `LogViewerController` holds the state when you want to drive the viewer from your own code:

```dart
LogViewer(
  store: store,
  options: LogViewerOptions(
    theme: 'midnight',
    locale: 'ko',
    timestampFormat: TimestampFormat.datetime,
    core: const CoreOptions(maxEntries: 50000, wrap: WrapMode.char),
    input: InputOptions(onSubmit: runCommand),
    onOpenLink: (String url) => launchUrl(Uri.parse(url)),
  ),
);
```

`onOpenLink` is yours to answer because opening a URL needs a plugin, and which plugin is your application's decision. Without it, links are still drawn and still confirmed; the answer simply goes nowhere.

## What differs from the JavaScript package

The two are the same library, and the core is translated file for file. Three things are different because the runtimes are:

| Case                      | What Flutter does                                                                                                                                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Opening an object         | Dart cannot read the fields of an arbitrary value without reflection, so a class that writes `toJson()` opens into its properties, one that writes `toString()` shows what it says, and the rest show their type. |
| A legacy CJK file         | UTF-8, UTF-16, Latin-1 and Windows-1252 decode here. `euc-kr`, `shift_jis`, `big5` and `gbk` are tables of tens of thousands of characters that a browser already has and Dart does not, so `registerTextDecoder` takes one from you. |
| A monospace font on the web | Flutter draws with the fonts an application bundles and cannot reach the ones the system has, so a web build needs one of its own: bundle a monospace font and name it in `FontSettings`. Every other platform resolves its own by name. |

## Development

```bash
flutter pub get
flutter test
dart analyze
dart format lib test example/lib
cd example && flutter run   # the gallery
```

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for the project layout and the workflow.

## License

[MIT](LICENSE) © [CDGet](https://cdget.com). The character width and composition tables are generated from the Unicode Character Database, whose license is included beside each generated file.
