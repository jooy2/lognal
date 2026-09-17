# CLAUDE.md

Guidance for AI agents and people working in this repository. Read it before starting any task, and update it when a decision listed under "Open decisions" is made.

## What lognal is

lognal is a log viewer library that looks like a terminal. It displays a fast stream of log messages and a long history, and it can also take input when something is connected to answer it. It ships as two packages built from the same library: `lognal` on npm, whose core is plain TypeScript with a React adapter, and `lognal` on pub.dev, one Flutter widget. The Dart core is a translation of the TypeScript one, file for file.

The npm package started with 0.1.0 on 2026-09-13. Both packages are at 1.0.0 as of 2026-09-17, and the owner publishes them. The documentation site is `docs/`, published to https://lognal.cdget.com, covers both packages behind a language switch, and its demo page at `/demo` runs every feature of the viewer.

## Use cases

These come from the project owner and define the scope of the library.

1. **Console mirror.** Hook the `console` methods, the way Chrome DevTools shows console output, and display the messages in the viewer instead of, or as well as, the browser console.
1. **Text file viewer.** Read a plain text file, such as a log file, and display it. True tailing is hard in a browser, so reading the file is the baseline and following a growing file is an extension for Chromium.
1. **Typed values.** Display arrays, JSON, objects, numbers and other data types in a form that is easy to read, with nested values that expand and collapse.
1. **Viewer features.** Timestamps, filtering, search, dark mode, and font customization, with room for more.
1. **Input.** The viewer accepts input only when a responder is connected, such as a command handler, a WebSocket, or a worker. Without one, it is read-only.

## Decisions already made

- **Render with Canvas 2D first.** The owner chose a canvas over one DOM element per line, and confirmed Canvas 2D as the first renderer. Renderers are built one at a time; a WebGL2 renderer may follow once Canvas 2D is finished and measured. Keep everything a renderer needs behind the `Renderer` interface in `src/renderer/types.ts`.
- **Core first, renderer last.** Capture, storage, filtering and layout are finished and correct before drawing. The renderer only turns a frame of rows into pixels.
- **Keep the core independent of any framework.** A framework adapter mounts the viewer and passes options to it, and adding an adapter must not require a change in the core. React is the only adapter on the JavaScript side, published as `lognal/react`.
- **The Dart port is done, and the two cores stay in step.** `packages/flutter` holds the whole library, not only the core, and it draws with Flutter's own canvas. Keep both cores free of the DOM, of framework code and of platform-only APIs; pass a platform feature in, the way `setGraphemeSplitter` does. A change to one core is a change to both, and the tests of both must agree about what it does.
- **One package per language, with a separated structure.** The npm package has the entry points `lognal`, `lognal/react` and `lognal/style.css`. The pub.dev package has one import, `package:lognal/lognal.dart`, and takes no dependency beyond `package:flutter`.
- **Snapshot values at call time.** A hooked console call captures its arguments synchronously, together with the timestamp, the counter and timer state, and the group nesting. See "Value capture" below.
- **Monospace fonts only, several of them.** The viewer supports a choice of monospace font families and falls back per glyph for characters the chosen font lacks, such as Hangul. Proportional fonts are not a goal.
- **Korean and other CJK text must work for both output and input.** Width, wrapping, selection, search, file encodings, and IME composition in the input line are part of the requirements.
- **Options are grouped by layer.** Core options (`maxEntries`, `mergeRepeats`, `wrap`, `tabSize`, `ambiguousWidth`, `maxClusters`, `filter`) go in `core`, and viewer options (theme, font, timestamps, toolbar, status bar, input, labels, locale, entry menu, search) sit at the top level of `LogViewerOptions`. Every part of the viewer can be configured or turned off.
- **Modern, simple design.** A toolbar at the top, the log in the middle, an optional input line and status bar at the bottom, and a custom overlay scrollbar. Lines wrap by default; wrapping can be turned off. Styles ship as a separate CSS file, and every color and size is a `--lognal-*` custom property that the canvas also reads.
- **Toolchain.** TypeScript compiled with `tsc`, ESLint and Prettier, Vitest for unit tests in Node.js and Vitest Browser Mode with Playwright for Chromium, Firefox and WebKit. On the Dart side, `flutter_lints` with `public_member_api_docs`, `dart format` and `flutter_test`. VitePress with `vitepress-sidebar` and `vitepress-i18n` for the English and Korean documentation, with a `::: fw` container and an `<Fw>` component for the language switch, and GitHub Actions for both test suites and for publishing the documentation.
- **Name.** The project and both packages are `lognal`.
- **License.** MIT, with copyright CDGet, as in `LICENSE`. The owner confirmed it after 0.1.0 was published with it.
- **First release.** 0.1.0 was published to npm on 2026-09-13. Later changes go under `vNext` in `CHANGELOG.md` until the owner names the next version.

## References

Two projects are the main references. Study how they work; do not copy their code, file layout, or naming. Every idea taken from them is rebuilt in this project's own terms.

- [xterm.js](https://github.com/xtermjs/xterm.js) (MIT) for the rendering architecture: the DOM and WebGL2 renderers, glyph caching, render scheduling, selection on a canvas, IME input, and the accessibility mirror. Its Canvas 2D renderer was removed in 6.0.0.
- [console-feed](https://github.com/samdenty/console-feed) (MIT) for the feature set: console hooking, value serialization, format specifiers such as `%s` and `%c`, and the display of typed values. Parts of it come from other projects under their own licenses, such as a port of `replicator` and a format parser from Chromium DevTools, which is one more reason not to copy from it.

The [WHATWG Console Standard](https://console.spec.whatwg.org/) is the primary source for how console methods and format specifiers behave.

## Open decisions

Do not pick one of these on your own; ask the owner.

- Whether to add a WebGL2 renderer, and when.

## Repository layout

One package per language, plus the documentation site they share. There is no install and no manifest at the root; every folder is entered and run on its own.

```text
packages/js/       the npm package, `lognal`
packages/flutter/  the pub.dev package, `lognal`
docs/              the VitePress site, a separate npm package, for both packages
```

`packages/js`:

```text
src/core/       store, filters, text width and wrapping, layout, value previews (portable)
src/sources/    console capture (hook, recorder, snapshot, format, table) and text files
src/renderer/   the Renderer interface, the default theme and the Canvas 2D renderer
src/viewer/     the DOM viewer, toolbar, scrollbar, input line, labels and theme reading
src/react/      the React component
src/styles/     lognal.css
test/unit/      Vitest in Node.js
test/browser/   Vitest Browser Mode
playground/     a Vite page for manual checks (npm run dev)
scripts/        build.mjs and generate-unicode-width.mjs
```

`packages/flutter` holds the same library, folder for folder, with the parts a browser has and Flutter does not left out and the parts Flutter has and a browser does not put in their place:

```text
lib/src/core/      the same core, translated: store, filters, text, layout, value previews
lib/src/sources/   `debugPrint`, `print` and `FlutterError` capture, and text files
lib/src/renderer/  the Renderer interface, the default theme and the CustomPainter renderer
lib/src/viewer/    the widget: toolbar, scrollbar, input line, labels
lib/src/theme/     the palettes, which the stylesheet holds on the JavaScript side
test/             flutter_test, mirroring test/unit and the widget tests
example/          a Flutter app for manual checks, and the gallery the site frames
tool/             the width table generator
```

The two cores are written against each other. A change to one is a change to both, and the tests of both must agree about what the change does.

`packages/js/src/core/text/unicode-width-data.ts` and `packages/flutter/lib/src/core/text/unicode_width_data.dart` are generated from the Unicode Character Database, by `npm run generate:unicode` and `dart run tool/generate_unicode_width.dart`. Do not edit either by hand.

## Working in this repository

- JavaScript commands, from `packages/js`: `npm run dev`, `npm test`, `npm run test:unit`, `npm run test:browser`, `npm run lint`, `npm run format`, `npm run typecheck`, `npm run build`. Set `LOGNAL_TEST_BROWSERS=chromium` to run one browser.
- Flutter commands, from `packages/flutter`: `flutter pub get`, `flutter test`, `dart analyze`, `dart format lib test example/lib`.
- Import source files with a `.js` extension (`./store.js`). The build emits declaration files with the same paths.
- Follow the common JavaScript conventions: blocks on every control statement, blank lines around statements, arrow functions, `SCREAMING_SNAKE_CASE` constants.
- Write code that does not depend on a global `document` at import time, so the package can be imported during server rendering.
- Record user-visible changes in the `CHANGELOG.md` of the package they change, under `vNext`, and update both `docs/src/en` and `docs/src/ko` when a public API changes. A page that says something only one language's readers need says it inside a `::: fw js` or `::: fw flutter` block.
- When writing a file through a tool, do not put `\u` escapes in the content: they can be decoded into the real character. Write `\x` escapes or `String.fromCharCode` instead, and check that no invisible character ends up in the source.

## Value capture

The Console Standard leaves the display of logged values to the implementation, so a snapshot does not conflict with it. The Formatter conversions (`%s`, `%d`, `%i`, `%f`) and the count, timer, and group state are defined at call time, and capturing synchronously follows that. The rules for the snapshot:

- Do not invoke getters defined by the page. Show an accessor as an accessor, the way Node.js `util.inspect` does by default. Built-in types are recognized with the engine's own methods, not `instanceof`.
- Bound the work: depth, entries per collection, total nodes, and string length each have a limit, and the output marks what was cut.
- Track the objects on the current path, so a circular reference is marked instead of followed, and catch errors thrown while reading a value.
- A snapshot is plain data with a closed set of kinds. Never look up a constructor by name.
- Values a snapshot cannot capture are shown as such: a promise's state, a live DOM element, and anything past the limits.
- A store collects messages before any viewer is attached, up to `maxEntries`.

## Working principles

- A new log message must not re-render a React component. Messages go to the store directly, and the viewer draws at most once per animation frame.
- The cost of a frame depends on the number of visible rows, not on the size of the history. Work that grows with the history, such as laying out every entry after a width change, runs for the rows on screen first and in small slices between frames for the rest.
- Memory is bounded. The store drops the oldest entries past `maxEntries`.
- The browser keeps the jobs it does better than a canvas: focus, text input with IME composition, and screen reader output stay in the DOM.
- Wide characters, such as Korean, Chinese, Japanese, and emoji, and IME composition in the input line are first-class cases, not edge cases. Test the input line on Safari, which fires `compositionend` before the committing `keydown` up to version 26, and with both a Korean and a Japanese input method: a Korean one passes the Enter that finishes a syllable on to the field, and a Japanese one keeps the Enter that confirms a candidate.
- Content from logs and files is untrusted. It is drawn as text and never inserted as HTML. Control characters and bidirectional overrides are made visible, and `%c` styles are limited to an allow list. Links, when they are added, open only for `http` and `https`.
- Measure before optimizing. Performance claims need a benchmark, not an estimate.
