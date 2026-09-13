---
order: 2
description: Install lognal, add its stylesheet, create a viewer in plain JavaScript or React, and mirror the browser console.
---

# Getting started

## Install

::: warning Not published yet

lognal 0.1.0 is in development and is not on npm yet. The command below works once the first version is released.

:::

```sh
npm install lognal
```

Until then, you can build a package from the repository. `npm pack` runs the build and writes `lognal-0.1.0.tgz`, which another project can install with `npm install ./path/to/lognal-0.1.0.tgz`.

```sh
git clone https://github.com/jooy2/lognal.git
cd lognal
npm install
npm pack
```

## Add the stylesheet

Import `lognal/style.css` once in your application. It holds the layout of the toolbar, the log area, the input line and the status bar, and the colors of the light and dark themes.

```ts
import 'lognal/style.css';
```

## Give the container a height

The viewer fills the element you create it in. Its root element has `height: 100%` and a minimum height of 160 pixels, so the container needs a height of its own, from a fixed size, a flex layout or a grid.

```html
<div id="logs" style="height: 400px"></div>
```

## Create a viewer

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

Every option is described in [The viewer](/guide/viewer).

## Use it with React

```tsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export function Logs() {
	return <LogViewer style={{ height: 400 }} theme="auto" hookConsole />;
}
```

The component takes the viewer options as props. See [React](/guide/react) for the ref, the shared store and server rendering.

## Mirror the browser console

`hookConsole` records every call to the global `console` into the viewer. The messages still reach the browser console.

```ts
const unhook = viewer.hookConsole();

console.warn('Disk usage is at %d%%', 91);
console.error(new Error('Failed to load the user profile'));

// Stop recording. Disposing the viewer also stops it.
unhook();
```

## Next steps

- [Console capture](/guide/console): supported methods, format specifiers and capture limits.
- [Typed values](/guide/values): how objects, errors, tables and groups are shown.
- [Text files](/guide/text-files): reading and following log files.
- [Themes and fonts](/guide/theming): colors, dark mode and monospace fonts.
