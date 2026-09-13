# CLAUDE.md

Guidance for AI agents and people working in this repository. Read it before starting any task, and update it when a decision listed under "Open decisions" is made.

## What lognal is

lognal is a JavaScript log viewer library that looks like a terminal. It displays a fast stream of log messages and a long history, and it can also take input when something is connected to answer it. The core is plain JavaScript with no framework dependency. React is the first framework it will be adapted to, and other frameworks are meant to follow.

The repository currently holds only the GitHub skeleton: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, and `.github`. There is no source code, package manifest, or toolchain yet.

## Use cases

These come from the project owner and define the scope of the library.

1. **Console mirror.** Hook the `console` methods, the way Chrome DevTools shows console output, and display the messages in the viewer instead of, or as well as, the browser console.
1. **Text file viewer.** Read a plain text file, such as a log file, and display it. True tailing is hard in a browser, so reading the file is the baseline and following a growing file is a possible extension.
1. **Typed values.** Display arrays, JSON, objects, numbers and other data types in a form that is easy to read, with nested values that expand and collapse.
1. **Viewer features.** Timestamps, filtering, search, dark mode, and font customization, with room for more.
1. **Input.** The viewer accepts input only when a responder is connected, such as a command handler, a WebSocket, or a worker. Without one, it is read-only.

## Decisions already made

- **Render on a canvas, not with one DOM element per line.** The owner chose this for throughput and long histories.
- **Prefer the simplest renderer that meets the performance goal.** The owner asked for an approach that is easy to build and maintain but still efficient, not the fastest renderer at any cost.
- **Build renderers one at a time.** More renderers may come later, but each one is finished and measured before the next starts, beginning with the one that is most practical to build.
- **Keep the core independent of React.** The core has no framework dependency. A framework adapter mounts the core and passes options to it, and adding an adapter must not require a change in the core.
- **One npm package with a separated structure.** Everything ships in the single `lognal` package. Inside it, the core, the renderers, and the framework adapters are separate modules, and an adapter has its own entry point so that users of other frameworks never load it.
- **Snapshot values at call time.** A hooked console call captures its arguments synchronously, together with the timestamp, the counter and timer state, and the group nesting. Only the delivery to the viewer is deferred. See "Value capture" below.
- **Monospace fonts only, several of them.** The viewer supports a choice of monospace font families and falls back per glyph for characters the chosen font lacks, such as Hangul. Proportional fonts are not a goal.
- **Korean and other CJK text must work for both output and input.** Width, wrapping, selection, search, file encodings, and IME composition in the input line are part of the requirements.
- **Name.** The project and the planned npm package are `lognal`. The name was not registered on npm as of 2026-09-13.

## References

Two projects are the main references. Study how they work; do not copy their code, file layout, or naming. Every idea taken from them is rebuilt in this project's own terms.

- [xterm.js](https://github.com/xtermjs/xterm.js) (MIT) for the rendering architecture: the DOM and WebGL2 renderers, glyph caching, render scheduling, selection on a canvas, IME input, and the accessibility mirror. Its Canvas 2D renderer was removed in 6.0.0.
- [console-feed](https://github.com/samdenty/console-feed) (MIT) for the feature set: console hooking, value serialization, format specifiers such as `%s` and `%c`, and the display of typed values. It is the closest existing product to what lognal does. Parts of it come from other projects under their own licenses, such as a port of `replicator` and a format parser from Chromium DevTools, which is one more reason not to copy from it.

The [WHATWG Console Standard](https://console.spec.whatwg.org/) is the primary source for how console methods and format specifiers behave.

## Open decisions

Do not pick one of these on your own; ask the owner.

- The first renderer. Canvas 2D was recommended because a later WebGL2 renderer can reuse its layout, and it is not subject to the browser limit on active WebGL contexts. The owner has not confirmed it yet.
- Whether the first release ships the React adapter next to the plain JavaScript API, or the plain API only.
- Build, lint, and test toolchain.
- How much history is retained by default, and what happens when the limit is reached.
- License. `LICENSE` is MIT with copyright CDGet, carried over from the owner's `qsu` skeleton. Confirm it before the first release.

## Value capture

The Console Standard leaves the display of logged values to the implementation, so a snapshot does not conflict with it. The Formatter conversions (`%s`, `%d`, `%i`, `%f`) and the count, timer, and group state are defined at call time, and capturing synchronously follows that. The rules for the snapshot:

- Do not invoke getters. Show an accessor as an accessor, the way Node.js `util.inspect` does by default.
- Bound the work: depth, entries per collection, total nodes, and string length each have a limit, and the output marks what was cut.
- Track visited objects with a `WeakMap`, and catch errors thrown while reading a value.
- Decode only a closed list of type tags. Never look up a constructor by name.
- Values a snapshot cannot capture are shown as such: a promise's state, a live DOM element, and anything past the limits.
- Keep messages that arrive before a viewer is attached, up to a limit. The standard suggests buffering at least 100.

## Working principles

These follow from the use cases and apply to whatever stack is chosen.

- A new log message must not re-render a React component. Messages go to the core directly, and the core batches them into at most one draw per animation frame.
- The cost of a frame depends on the number of visible rows, not on the size of the history.
- Memory is bounded. The viewer drops the oldest entries past a configured limit.
- The browser keeps the jobs it does better than a canvas: focus, text input with IME composition, and screen reader output stay in the DOM.
- Wide characters, such as Korean, Chinese, Japanese, and emoji, and IME composition in the input line are first-class cases, not edge cases. Test the input line on Safari, which fires `compositionend` before the committing `keydown` up to version 26.
- Content from logs and files is untrusted. It is drawn as text and never inserted as HTML. Control characters and bidirectional overrides are made visible, links open only for `http` and `https`, and `%c` styles are limited to an allow list.
- Measure before optimizing. Performance claims need a benchmark, not an estimate.
