---
order: 2
description: Install lognal, create a viewer in plain JavaScript, React or Flutter, and mirror what your application already prints.
---

# Getting started

lognal ships as two packages, one per language, from one core. Pick yours with the switch above the menu; every example on this site follows it.

## Install

::: fw js

```sh
npm install lognal
```

:::

::: fw flutter

```sh
flutter pub add lognal
```

:::

::: fw js

## Add the stylesheet

Import `lognal/style.css` once in your application. It holds the layout of the toolbar, the log area, the input line and the status bar, and the colors of every theme.

```ts
import 'lognal/style.css';
```

:::

::: fw flutter

## Nothing else to add

The package has no dependencies and no stylesheet: the palettes are values, and the widget draws everything itself. On the web there is one thing to supply, a monospace font, because Flutter draws with the fonts an application bundles and cannot reach the ones the system has. See [Themes and fonts](/guide/theming).

:::

## Give it a height

The viewer fills what it is put in, so that has to have a height of its own.

::: fw js

Its root element has `height: 100%` and a minimum height of 160 pixels, so the container needs a height from a fixed size, a flex layout or a grid.

```html
<div id="logs" style="height: 400px"></div>
```

:::

::: fw flutter

```dart
SizedBox(height: 400, child: LogViewer(store: store));
```

:::

## Create a viewer

::: fw js

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!, {
	theme: 'auto',
	timestamps: 'time'
});

viewer.write('Server started');
viewer.console.info('Connected to %s in %dms', 'database', 12);
viewer.console.log('Current user', { id: 42, name: 'Ada', roles: ['admin'] });
```

- `viewer.write` adds a line of plain text.
- `viewer.console` is an object with the console methods. It writes to this viewer and leaves the browser console alone.
- `viewer.dispose()` removes the viewer from the page and stops everything it started.

:::

::: fw flutter

The entries live in a `LogStore`, which the widget shows. Keeping the store outside the widget is the point: log entries never go through `setState`, so a message costs a repaint rather than a rebuild.

```dart
import 'package:flutter/widgets.dart';
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final LognalConsole log = LognalConsole(store);

class LogPanel extends StatelessWidget {
  const LogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: LogViewer(
        store: store,
        options: const LogViewerOptions(theme: 'auto'),
      ),
    );
  }
}
```

```dart
store.write('Server started');
log.info('Connected to %s in %dms', <Object?>['database', 12]);
log.log('Current user', <Object?>[
  <String, Object?>{'id': 42, 'name': 'Ada', 'roles': <String>['admin']},
]);
```

- `store.write` adds a line of plain text.
- `LognalConsole` is an object with the logging methods. It writes into the store and leaves `print` alone.
- A `LogViewerController` holds the rest of the state — the scroll position, the selection, the search — and lets you drive the viewer from your own code. Without one the widget makes its own.

:::

Every option is described in [The viewer](/guide/viewer).

::: fw js

## Use it with React

```tsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export function Logs() {
	return <LogViewer style={{ height: 400 }} theme="auto" hookConsole />;
}
```

The component takes the viewer options as props. See [In a framework](/guide/framework) for the ref, the shared store and server rendering.

:::

::: fw flutter

## Drive it from your own code

```dart
final LogViewerController controller = LogViewerController(store: store);

// … in build
LogViewer(controller: controller, options: const LogViewerOptions(theme: 'auto'));

// … from anywhere
controller.scrollToBottom();
await controller.copySelection();
```

See [In a framework](/guide/framework) for what the controller offers and when the widget makes its own.

:::

## Mirror what the application prints

::: fw js

`hookConsole` records every call to the global `console` into the viewer. The messages still reach the browser console.

```ts
const unhook = viewer.hookConsole();

console.warn('Disk usage is at %d%%', 91);
console.error(new Error('Failed to load the user profile'));

// Stop recording. Disposing the viewer also stops it.
unhook();
```

:::

::: fw flutter

Dart prints through three different things, so there are three hooks. Each one returns the function that takes it back off.

```dart
void main() {
  // What Flutter itself prints, and what `debugPrint` is given.
  final void Function() unhookPrint = hookDebugPrint(store);
  // A widget that threw during a build, with its stack.
  final void Function() unhookErrors = hookFlutterErrors(store);

  // `print` belongs to the zone rather than to a variable, so it is caught by
  // running the application inside one.
  runZonedWithLognal(store, () => runApp(const MyApp()));
}
```

All three keep the original output running, so messages still reach the terminal and the IDE. See [Capturing output](/guide/console) for why there are three.

:::

## Next steps

- [Capturing output](/guide/console): what is recorded, the format specifiers and the capture limits.
- [Typed values](/guide/values): how objects, errors, tables and groups are shown.
- [Text files](/guide/text-files): reading and following log files.
- [Themes and fonts](/guide/theming): colors, dark mode and monospace fonts.
