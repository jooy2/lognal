<img src="https://raw.githubusercontent.com/jooy2/lognal/refs/heads/main/.github/resources/lognal-logo.webp" width="96" height="96" alt="lognal logo" />

# lognal

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jooy2/lognal/blob/main/LICENSE) [![npm latest package](https://img.shields.io/npm/v/lognal/latest.svg)](https://www.npmjs.com/package/lognal) [![pub latest package](https://img.shields.io/pub/v/lognal.svg)](https://pub.dev/packages/lognal) [![run-test-js](https://github.com/jooy2/lognal/actions/workflows/run-test-js.yml/badge.svg)](https://github.com/jooy2/lognal/actions/workflows/run-test-js.yml) [![run-test-flutter](https://github.com/jooy2/lognal/actions/workflows/run-test-flutter.yml/badge.svg)](https://github.com/jooy2/lognal/actions/workflows/run-test-flutter.yml)

### [**lognal.cdget.com**](https://lognal.cdget.com)

Guides and the full reference, in English and Korean. This README covers the essentials, and each package has a quick start of its own.

---

**A log viewer that looks and behaves like a terminal.**

lognal draws log output on a canvas instead of creating an element or a widget for every line, so a fast stream of messages and a history of tens of thousands of entries cost the same frame. Under that canvas sits a core that knows nothing about the screen: a store, a filter, a text shaper and a layout, all plain data and plain logic. The canvas only turns a frame of rows into pixels.

That core is written twice, once in TypeScript and once in Dart, file for file. A log line means the same thing in a browser and in an app: the same wrapping, the same widths for Korean and emoji, the same search, the same values expanding and collapsing.

## What it does

- **Mirrors the runtime's own logging.** `console.log`, `console.table` and `console.group` in a browser; `print`, `debugPrint` and `dart:developer` in Flutter. Arguments are captured at the moment of the call, and the original output keeps working.
- **Reads log files.** One entry per line, with the encoding detected, including legacy encodings such as EUC-KR. A file that keeps growing can be followed.
- **Displays values by type.** Objects, lists, maps, sets and errors expand and collapse, and a table is drawn as a table.
- **Accepts commands.** Connect a handler, and the viewer shows an input line and prints the replies.
- **Handles Korean and other CJK text.** Wide characters stay on the grid, Korean wraps at spaces, and the input line waits for IME composition to finish.

Both packages ship the same toolbar (follow new logs, clear, scroll to top and bottom, line wrapping, entry selection, themes, hidden messages, a text filter and a level filter), the same status bar, the same search that highlights matches without hiding entries, the same entry menu, the same six palettes, and the same custom scrollbar. Every part can be turned off or restyled.

## Packages

| Package                                | Registry                                              | Requires                       | Quick start                          |
| -------------------------------------- | ----------------------------------------------------- | ------------------------------ | ------------------------------------ |
| [`packages/js`](packages/js)           | [npm: `lognal`](https://www.npmjs.com/package/lognal) | Node.js 22.12 or later         | [README](packages/js/README.md)      |
| [`packages/flutter`](packages/flutter) | [pub.dev: `lognal`](https://pub.dev/packages/lognal)  | Flutter 3.32 or later, Dart 3.8 | [README](packages/flutter/README.md) |

The JavaScript package ships the viewer for plain JavaScript and a React component under `lognal/react`. The Flutter package ships the viewer as a widget.

Each language's package **versions independently and keeps its own changelog** beside its own manifest: [`packages/js/CHANGELOG.md`](packages/js/CHANGELOG.md) and [`packages/flutter/CHANGELOG.md`](packages/flutter/CHANGELOG.md). A release on one side is not a release on the other, so the numbers will not always agree.

## Install

```bash
npm install lognal
```

`react` is an optional peer dependency, needed only for `lognal/react`. Nothing else is.

```bash
flutter pub add lognal
```

Nothing beyond the Flutter SDK.

## Repository layout

| Path               | What it is                                       | How it is run                                                                 |
| ------------------ | ------------------------------------------------ | ----------------------------------------------------------------------------- |
| `packages/js`      | The npm package, `lognal`                        | `cd packages/js && npm install`, then `npm test`, `npm run lint`, `npm run build` |
| `packages/flutter` | The pub.dev package, `lognal`                    | `cd packages/flutter && flutter pub get`, then `flutter test`, `dart analyze` |
| `docs`             | The documentation site, shared by both packages  | `cd docs && npm install`, then `npm run dev`                                  |

There is no install at the repository root and no root manifest. Each folder is entered and run on its own. [CONTRIBUTING.md](CONTRIBUTING.md) has the rest.

## Documentation

The site is written once for both packages: a switch above the sidebar picks the language, and every example, option name and install line on the page follows it.

| Page                                                            | What you will find                                        |
| --------------------------------------------------------------- | --------------------------------------------------------- |
| [**Getting started**](https://lognal.cdget.com/getting-started) | Install and setup, end to end.                            |
| [**Guide**](https://lognal.cdget.com/guide/)                    | The console, log files, values, theming, CJK text.        |
| [**Reference**](https://lognal.cdget.com/reference/)            | Every option, type and function, one page each.           |
| [**Demo**](https://lognal.cdget.com/demo)                       | The whole viewer, running, in whichever package you pick. |

## Contributing

Anyone can contribute to the project by reporting new issues or submitting a pull request. For more information, please see [CONTRIBUTING.md](CONTRIBUTING.md). Participation is subject to the [Code of Conduct](CODE_OF_CONDUCT.md).

To report a security issue, please follow the process described in [SECURITY.md](SECURITY.md).

For anything that does not belong in a public issue, write to CDGet at [cdget.com/contact](https://cdget.com/contact).

## Sponsor

lognal is free to use and maintained in the open. If it saves you time, you can support the work at [cdget.com/donate](https://cdget.com/donate) or through the Sponsor button on GitHub.

## License

[MIT](LICENSE) © [CDGet](https://cdget.com). The character width tables are generated from the Unicode Character Database, whose license is included beside the generated file in each package.
