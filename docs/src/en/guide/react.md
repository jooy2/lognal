---
order: 6
description: Use lognal in React with the LogViewer component from lognal/react, its props and ref, a shared store, the hookConsole prop and server rendering.
---

# React

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

Every [viewer option](/guide/viewer#options) is also a prop: `store`, `core`, `theme`, `font`, `timestamps`, `follow`, `toolbar`, `statusBar`, `input`, `locale`, `labels`, `entryMenu`, `search` and `renderer`. The component adds these:

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
- Functions inside options, such as `input.onSubmit`, a `timestamps` function, `labels.entries`, `labels.searchResults` or `entryMenu.items`, always call the function from the latest render. Passing a new function does not count as a change.
- Changing `store` or `renderer` disposes the viewer and creates a new one.

A prop that you remove goes back to its default:

| Removed prop                                                                 | Value applied                                                                             |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `theme`, `font`, `timestamps`, `toolbar`, `statusBar`, `entryMenu`, `search` | `'auto'`, `{}`, `true`, `true`, `true`, `true`, `true`                                    |
| `input`, `labels`, `locale`                                                  | `null`, `{}`, `undefined`, which shows the English labels                                 |
| A key of `core`, or `core` itself                                            | The value in `DEFAULT_STORE_OPTIONS` or `DEFAULT_LAYOUT_OPTIONS`, and `null` for `filter` |
| `follow`                                                                     | Nothing is applied. The view keeps following, or stays paused, as it is.                  |

## Write logs

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
