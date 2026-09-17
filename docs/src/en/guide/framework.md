---
order: 6
description: Use lognal in React with the component from lognal/react, or in Flutter with the LogViewer widget and its controller.
---

# In a framework

The core knows nothing about any framework. What sits on top of it is one component in React and one widget in Flutter, and this page is about whichever one the switch above the menu says.

::: fw js

`lognal/react` exports a `LogViewer` component. It renders a container and creates the viewer in it after mounting. It needs React 18 or later.

```tsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export function Logs() {
	return <LogViewer style={{ height: 400 }} theme="auto" timestamps="datetime" />;
}
```

The container has `height: 100%`, and your `style` is applied on top. Give the component a height through `style`, `className` or its parent.

## Props

Every [viewer option](/guide/viewer#options) is also a prop: `store`, `core`, `theme`, `themes`, `font`, `timestamps`, `follow`, `toolbar`, `statusBar`, `input`, `locale`, `labels`, `entryMenu`, `search`, `linkClick`, `selectionMode`, `tooltips` and `renderer`. The component adds these:

| Prop                | Type                                  | Description                                                                  |
| ------------------- | ------------------------------------- | ---------------------------------------------------------------------------- |
| `className`         | `string`                              | The class of the container.                                                  |
| `style`             | `CSSProperties`                       | The style of the container.                                                  |
| `hookConsole`       | `boolean \| HookConsoleOptions`       | Records the global `console` into the viewer while the component is mounted. |
| `onReady`           | `(viewer: LogViewer \| null) => void` | Called with the viewer once it exists, and with `null` after it is disposed. |
| `onFollowChange`    | `(following: boolean) => void`        | Called when following turns on or off.                                       |
| `onFilterChange`    | `(filter: LogFilter \| null) => void` | Called when the filter changes.                                              |
| `onSelectionChange` | `(text: string) => void`              | Called when the selected text changes.                                       |

### How prop changes are applied

- Option props are compared by their data. Writing an object inline, such as a `toolbar` object that is new on every render, costs nothing as long as its contents stay the same.
- Only the props whose data changed are passed to `viewer.setOptions`, and each key of `core` is compared on its own. A new viewer is not created.
- A change to one prop leaves the others alone. When `theme` changes, `follow`, `core.filter` and `core.wrap` are not applied again, so following, the filter and the wrapping the user changed in the toolbar stay as they are. A prop overrides the user's choice only when its own data changes.
- Functions inside options, such as `input.onSubmit`, a `timestamps` function, a label function such as `labels.entries`, or `entryMenu.items`, always call the function from the latest render. Passing a new function does not count as a change.
- Changing `store` or `renderer` disposes the viewer and creates a new one.

A prop that you remove goes back to its default:

| Removed prop                                                                                                           | Value applied                                                                             |
| ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `theme`, `font`, `timestamps`, `toolbar`, `statusBar`, `entryMenu`, `search`, `linkClick`, `selectionMode`, `tooltips` | `'auto'`, `{}`, `true`, `true`, `true`, `true`, `true`, `'confirm'`, `'text'`, `true`     |
| `themes`                                                                                                               | `undefined`, which offers every built-in theme                                            |
| `input`, `labels`, `locale`                                                                                            | `null`, `{}`, `undefined`, which shows the English labels                                 |
| A key of `core`, or `core` itself                                                                                      | The value in `DEFAULT_STORE_OPTIONS` or `DEFAULT_LAYOUT_OPTIONS`, and `null` for `filter` |
| `follow`                                                                                                               | Nothing is applied. The view keeps following, or stays paused, as it is.                  |

## Write logs {#write-logs}

Log entries never go through React state, so a new message never renders a component again. Write to the viewer through the ref, through `onReady`, or through a store.

The ref holds the `LogViewer` instance from `lognal`, and `null` before mounting and after unmounting.

```tsx
import { useRef } from 'react';
import type { LogViewer as Viewer } from 'lognal';
import { LogViewer } from 'lognal/react';

export function DeployLog() {
	const viewer = useRef<Viewer>(null);

	return (
		<>
			<button type="button" onClick={() => viewer.current?.console.info('Deploy started')}>
				Deploy
			</button>
			<LogViewer ref={viewer} style={{ height: 320 }} />
		</>
	);
}
```

## Share a store

A `LogStore` created outside the component collects entries whether or not the component is mounted, and several components can show the same store.

```tsx
import { LogStore } from 'lognal';
import { LogViewer } from 'lognal/react';

const store = new LogStore({ maxEntries: 50000 });
const socket = new WebSocket('wss://example.com/logs');

socket.addEventListener('message', (event) => {
	store.write(String(event.data));
});

export function ServerLog() {
	return <LogViewer store={store} style={{ height: 400 }} />;
}
```

To create the store inside a component, keep it stable across renders with `useState(() => new LogStore())`. A new store on every render creates a new viewer every time.

## Hook the console

`hookConsole` records the global `console` while the component is mounted and restores it on unmount. Pass options to choose the methods and the capture limits.

```tsx
import { LogViewer } from 'lognal/react';

export function ProblemLog() {
	return <LogViewer hookConsole={{ methods: ['warn', 'error'], maxDepth: 3 }} style={{ height: 400 }} />;
}
```

`hookConsole={true}` records every supported method. The console is hooked again only when the data of the prop changes, and the hook works under `StrictMode`, which mounts components twice during development.

## Server rendering

The component file starts with `'use client'`, so frameworks with React Server Components, such as the Next.js App Router, treat it as a client component. On the server it renders an empty container, and the viewer is created in the browser after hydration.

- Import `lognal/style.css` once, for example in the root layout.
- Importing `lognal` on the server is safe. Creating a `LogViewer` needs a browser, so do it in an effect or an event handler, the way the component does.
- `hookConsole` only records calls made in the browser.

```tsx
// app/layout.tsx
import 'lognal/style.css';
```

```tsx
// app/logs/page.tsx
import { LogViewer } from 'lognal/react';

export default function LogsPage() {
	return <LogViewer hookConsole style={{ height: '80vh' }} />;
}
```

:::

::: fw flutter

`LogViewer` is the whole viewer. There is no adapter to install and no separate package: the widget is the library's own, and everything below it is the same core the npm package ships.

```dart
import 'package:flutter/widgets.dart';
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

class Logs extends StatelessWidget {
  const Logs({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: LogViewer(
        store: store,
        options: const LogViewerOptions(theme: 'auto', timestampFormat: TimestampFormat.datetime),
      ),
    );
  }
}
```

The widget fills what it is put in, so give it a height through its parent.

## What the widget takes

| Property     | Type                   | What it is                                                                                                                |
| ------------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `store`      | `LogStore?`            | The entries to show. Without one the controller makes its own.                                                            |
| `controller` | `LogViewerController?` | The state to show, for an application that holds its own. Without one the widget makes it and disposes of it with itself. |
| `options`    | `LogViewerOptions`     | Everything else. See [The viewer](/guide/viewer#options).                                                                 |

`options` is what configures the viewer whether or not you passed a controller: a controller is the viewer's state, not its settings, so changing an option here changes the viewer.

## Write logs {#write-logs-flutter}

Log entries never go through `setState`, so a new message never rebuilds a widget. Write to the store, or to the controller, from anywhere.

```dart
final LognalConsole log = LognalConsole(store);

ElevatedButton(
  onPressed: () => log.info('Deploy started'),
  child: const Text('Deploy'),
);
```

The store collects entries whether or not a viewer is on screen, and several viewers can show the same store.

```dart
final LogStore store = LogStore(options: const LogStoreOptions(maxEntries: 50000));
final WebSocketChannel socket = WebSocketChannel.connect(uri);

socket.stream.listen((Object? message) => store.write('$message'));
```

## Hold the state yourself

A `LogViewerController` is what the viewer keeps: the scroll position, what is selected, the filter, the search and the palette. Hold one when you want to drive the viewer from outside it, and dispose of it with whatever holds it.

```dart
class _LogPanelState extends State<LogPanel> {
  late final LogViewerController _controller = LogViewerController(store: store);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            TextButton(
              onPressed: _controller.scrollToBottom,
              child: const Text('Latest'),
            ),
            TextButton(
              onPressed: () => _controller.openSearch('error'),
              child: const Text('Find errors'),
            ),
          ],
        ),
        Expanded(child: LogViewer(controller: _controller)),
      ],
    );
  }
}
```

The controller is a `ChangeNotifier`, so anything of yours can listen to it the way the viewer does.

## Hook the output

The three hooks are described in [Capturing output](/guide/console). Each one returns the function that takes it off again, so a widget that installs one puts it back in `dispose`.

```dart
class _LogPanelState extends State<LogPanel> {
  late final void Function() _unhook = hookDebugPrint(store);

  @override
  void dispose() {
    _unhook();
    super.dispose();
  }
}
```

## On the web

Flutter draws with the fonts an application bundles and cannot reach the ones the system has, so a web build has to carry a monospace font of its own and name it:

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(font: FontSettings(family: 'JetBrainsMono')),
);
```

Every other platform resolves its own monospace font by name and needs nothing. [Themes and fonts](/guide/theming#fonts) has the rest.

A release build for the web also does not keep type names, so a value shows what it holds and what its `toString()` says rather than the name of its class. Nothing is lost that was not already gone.

:::
