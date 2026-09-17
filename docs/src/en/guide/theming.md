---
order: 5
description: Switch lognal between its built-in palettes, write a theme of your own, and pick a monospace font that suits Korean text.
---

# Themes and fonts

## Themes

`theme` takes `'auto'`, the name of a palette that ships with lognal, or a name of your own. <Fw js="BUILT_IN_THEMES" flutter="builtInThemes" code /> lists the palettes in the order the theme menu shows them.

| `theme`      | Colors                                                      |
| ------------ | ----------------------------------------------------------- |
| `'auto'`     | The system setting: `light` or `dark`. This is the default. |
| `'light'`    | A plain light palette.                                      |
| `'paper'`    | A warm light palette on an off-white background.            |
| `'dark'`     | A plain dark palette.                                       |
| `'midnight'` | A dark palette on deep blue, with cool colors.              |
| `'ember'`    | A dark palette on warm brown, with an amber accent.         |
| `'moss'`     | A dark palette on deep green.                               |

::: fw js

```ts
const viewer = new LogViewer(container, { theme: 'auto' });
const darkModeSwitch = document.querySelector<HTMLInputElement>('#dark-mode')!;

darkModeSwitch.addEventListener('change', () => {
	viewer.setOptions({ theme: darkModeSwitch.checked ? 'midnight' : 'paper' });
});
```

The **Theme** button in the toolbar opens a menu of the same themes, and choosing one is the same as calling `setOptions({ theme })`. `themes` decides which ones the menu offers, and gives a theme a label of its own:

```ts
new LogViewer(container, {
	theme: 'brand',
	themes: ['auto', 'light', 'dark', { name: 'brand', label: 'Our colors' }]
});
```

`toolbar: { theme: false }` hides the button, and the option still works from code.

:::

::: fw flutter

```dart
LogViewer(store: store, options: LogViewerOptions(theme: isDark ? 'midnight' : 'paper'));
```

The **Theme** button in the toolbar opens a menu of the same themes, and choosing one sets it on the controller. A theme the reader picked stays picked; only a new value in `options.theme` replaces it. `themes` decides which ones the menu offers, and gives a theme a label of its own:

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(
    theme: 'brand',
    themes: <ThemeChoice>[
      ThemeChoice('auto'),
      ThemeChoice('light'),
      ThemeChoice('dark'),
      ThemeChoice('brand', label: 'Our colors'),
    ],
  ),
);
```

`toolbar: ViewerToolbarOptions(theme: false)` hides the button, and `controller.setTheme(name)` still works from code.

:::

::: fw js

The viewer writes the palette to the `data-theme` attribute of its root element, `.lognal`, and the stylesheet picks the colors from it. `'auto'` is resolved before it is written, so `data-theme` is always the name of a palette.

## How colors reach the canvas

Every color and size of the viewer is a `--lognal-*` CSS custom property on `.lognal`. The canvas cannot use CSS directly, so the viewer reads the computed values and passes them to the renderer. It reads them when the viewer is created, when the theme changes, and when the operating system switches between light and dark in `'auto'` mode.

If you change the properties at another time, for example by toggling a class on a parent element, call `viewer.refresh()` so the canvas picks up the new values.

The light colors are set on `.lognal` itself, and every other palette overrides them under its own `data-theme`. To change a color in the light and the dark theme, override it in both places:

```css
.build-log .lognal {
	--lognal-background: #fbfaf7;
	--lognal-accent: #7a3cff;
}

.build-log .lognal[data-theme='dark'] {
	--lognal-background: #0d1117;
	--lognal-accent: #b18cff;
}
```

Any color the canvas accepts works, including `rgb()`, `hsl()` and `oklch()`.

### A theme of your own

A theme is one block of CSS and the name you pass to `theme`. Nothing else is registered, and the viewer reads the colors from the computed style as it does for the built-in palettes.

```css
.lognal[data-theme='brand'] {
	--lognal-background: #101417;
	--lognal-foreground: #e6edf3;
	--lognal-accent: #ffb454;
	--lognal-ansi-2: #8ddb8c;
	--lognal-token-string: var(--lognal-ansi-2);

	color-scheme: dark;
}
```

Set the colors that differ from the light palette of `.lognal`, since every color that is not overridden keeps its light value. `paper`, `midnight`, `ember` and `moss` in `lognal.css` are written this way and are a good starting point: each one sets its base colors, its accent and its sixteen ANSI colors, and its token colors follow the ANSI colors through `var()`.

:::

::: fw flutter

## How colors reach the canvas

A palette is a value rather than a stylesheet. A `LognalTheme` holds two of them:

- `renderer`, a `RenderTheme`, is what the log is drawn with: the text, the markers, the highlights, the sixteen ANSI colors and the token colors.
- `chrome`, a `ChromeTheme`, is what everything around the log is drawn with: the toolbar, the status bar, the scrollbar, the menus and the dialogs.

The viewer resolves the name to one of those when it builds, and the painter takes its colors from it. Nothing is read from the application's own `Theme`, on purpose: a dark log inside a light application should look like a dark log, and should not open a light menu over itself.

### A theme of your own

Most palettes are a background, a foreground, an accent and a sixteen-colour ramp, and everything else follows. `buildTheme` is that rule written down, and it is how `paper`, `midnight`, `ember` and `moss` are made:

```dart
final LognalTheme brand = buildTheme(
  name: 'brand',
  brightness: Brightness.dark,
  background: const Color(0xff101417),
  foreground: const Color(0xffe6edf3),
  muted: const Color(0xff8b949e),
  accent: const Color(0xffffb454),
  border: const Color(0xff222a31),
  surface: const Color(0xff161b21),
  selection: const Color(0x47ffb454),
  entrySelection: const Color(0x1fffb454),
  controlActive: const Color(0x33ffb454),
  ansi: <Color>[/* sixteen colors */],
);

LogViewer(
  store: store,
  options: LogViewerOptions(
    theme: 'brand',
    themeResolver: (String name) => name == 'brand' ? brand : null,
    themes: const <ThemeChoice>[
      ThemeChoice('auto'),
      ThemeChoice('brand', label: 'Our colors'),
    ],
  ),
);
```

`themeResolver` is asked for any name that is not `auto`, and returns `null` for the ones it does not know, which fall back to the platform's light or dark. For a palette that does not follow the rule, build the `RenderTheme` and the `ChromeTheme` yourself and put them in a `LognalTheme`.

:::

## The colors

::: fw js

### Text grid

These set the font of the log and of the input line. For the log, the `font` option takes precedence over them. The input line always uses the properties.

| Property               | Default                                                                                                                       | Description                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `--lognal-font-family` | `ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'D2Coding', 'Noto Sans Mono CJK KR', 'Liberation Mono', monospace` | A list of monospace font families.                                                                          |
| `--lognal-font-size`   | `13px`                                                                                                                        | The font size, in `px`, `rem` or `em`.                                                                      |
| `--lognal-font-weight` | `400`                                                                                                                         | The weight of regular text. Bold text uses at least `700`.                                                  |
| `--lognal-line-height` | `1.6`                                                                                                                         | The row height: a multiple of the font size (a number or `em`), a percentage, or a length in `px` or `rem`. |

The viewer converts both values to pixels for the canvas:

- A line height without a unit, such as `1.6`, or in `em`, such as `1.6em`, is a multiple of the font size. A percentage such as `150%` is `1.5`, and a length such as `20px` is divided by the font size.
- A font size in `rem` is measured against the font size of the root element, and one in `em` against the font size of the `.lognal` element, which the stylesheet sets to `--lognal-ui-font-size`.
- A value the viewer cannot read, such as a `calc()` expression, falls back to the default.

The input line reads the same properties through CSS, so the log and the input line get the same row height.

The viewer also sets `--lognal-cell-height` on its root element to the height of one row in pixels. It is an output you can use in your own CSS, not a setting.

### Toolbar and status bar

These style the parts of the viewer that are regular HTML.

| Property                    | Default                                                                                    | Description                                      |
| --------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| `--lognal-ui-font-family`   | `system-ui, -apple-system, 'Segoe UI', 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif` | The font of the toolbar and the status bar.      |
| `--lognal-ui-font-size`     | `12px`                                                                                     | The font size of the toolbar and the status bar. |
| `--lognal-radius`           | `10px`                                                                                     | The corner radius of the viewer.                 |
| `--lognal-control-radius`   | `6px`                                                                                      | The corner radius of buttons and fields.         |
| `--lognal-toolbar-height`   | `40px`                                                                                     | The minimum height of the toolbar.               |
| `--lognal-statusbar-height` | `26px`                                                                                     | The minimum height of the status bar.            |

| Property                         | Light                                                                 | Dark                                                           | Description                                                                                                                                                                 |
| -------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--lognal-border`                | `#e3e6eb`                                                             | `#2a2e37`                                                      | The outline of the viewer, fields and separators.                                                                                                                           |
| `--lognal-surface`               | `#f6f7f9`                                                             | `#1c1f25`                                                      | The background of the toolbar and the status bar.                                                                                                                           |
| `--lognal-control-hover`         | `rgba(29, 33, 41, 0.07)`                                              | `rgba(227, 229, 234, 0.08)`                                    | A button under the pointer.                                                                                                                                                 |
| `--lognal-control-active`        | `rgba(31, 111, 214, 0.12)`                                            | `rgba(90, 162, 255, 0.18)`                                     | A pressed button, such as follow.                                                                                                                                           |
| `--lognal-focus-ring`            | `#1f6fd6`                                                             | `#5aa2ff`                                                      | The focus outline of the toolbar buttons, the level menu, the **New logs** button and the entry menu button, and in entry mode the outline of the entry the keyboard is on. |
| `--lognal-scrollbar-thumb`       | `rgba(29, 33, 41, 0.28)`                                              | `rgba(227, 229, 234, 0.25)`                                    | The scrollbar thumb.                                                                                                                                                        |
| `--lognal-scrollbar-thumb-hover` | `rgba(29, 33, 41, 0.45)`                                              | `rgba(227, 229, 234, 0.42)`                                    | The scrollbar thumb under the pointer.                                                                                                                                      |
| `--lognal-popup-shadow`          | `0 8px 24px rgba(29, 33, 41, 0.14), 0 1px 3px rgba(29, 33, 41, 0.08)` | `0 8px 24px rgba(0, 0, 0, 0.45), 0 1px 3px rgba(0, 0, 0, 0.3)` | The shadow of the level menu and the entry menu.                                                                                                                            |

:::

::: fw flutter

### The chrome

`ChromeTheme` holds these.

| Field                 | Light        | Dark         | Description                                        |
| --------------------- | ------------ | ------------ | -------------------------------------------------- |
| `background`          | `0xffffffff` | `0xff16181d` | The color behind the viewer.                       |
| `foreground`          | `0xff1d2129` | `0xffe3e5ea` | Ordinary text in the chrome.                       |
| `muted`               | `0xff646a78` | `0xff8f94a1` | A control that is not pressed, and secondary text. |
| `accent`              | `0xff1f6fd6` | `0xff5aa2ff` | The accent color.                                  |
| `border`              | `0xffe3e6eb` | `0xff2a2e37` | The outline of the viewer, fields and separators.  |
| `surface`             | `0xfff6f7f9` | `0xff1c1f25` | The background of the toolbar and the status bar.  |
| `controlHover`        | `0x121d2129` | `0x14e3e5ea` | A button under the pointer.                        |
| `controlActive`       | `0x1f1f6fd6` | `0x2e5aa2ff` | A pressed button, such as follow.                  |
| `focusRing`           | `0xff1f6fd6` | `0xff5aa2ff` | The ring around the control the keyboard is on.    |
| `onAccent`            | `0xffffffff` | `0xff0b1220` | Text on `accent`.                                  |
| `scrollbarThumb`      | `0x471d2129` | `0x40e3e5ea` | The scrollbar's handle.                            |
| `scrollbarThumbHover` | `0x731d2129` | `0x6be3e5ea` | The handle under the pointer.                      |
| `shadow`              | `0x241d2129` | `0x73000000` | The shadow under a menu or a dialog.               |

:::

### Log colors

<Fw js="The canvas draws with these. `background`, `foreground`, `muted` and `accent` also color the toolbar, the input line and the status bar." flutter="`RenderTheme` holds these, and the canvas draws with them." />

::: fw js

| Property                    | Light                      | Dark                        | Description                                                                                  |
| --------------------------- | -------------------------- | --------------------------- | -------------------------------------------------------------------------------------------- |
| `--lognal-background`       | `#ffffff`                  | `#16181d`                   | The background of the log and the input line.                                                |
| `--lognal-foreground`       | `#1d2129`                  | `#e3e5ea`                   | Regular text.                                                                                |
| `--lognal-muted`            | `#646a78`                  | `#8f94a1`                   | Timestamps, notices, expander triangles and the output marker.                               |
| `--lognal-accent`           | `#1f6fd6`                  | `#5aa2ff`                   | The input marker, the prompt, pressed buttons and the **New logs** button.                   |
| `--lognal-selection`        | `rgba(31, 111, 214, 0.22)` | `rgba(90, 162, 255, 0.3)`   | Selected text.                                                                               |
| `--lognal-match`            | `rgba(240, 173, 0, 0.3)`   | `rgba(252, 191, 50, 0.3)`   | Filter matches.                                                                              |
| `--lognal-separator`        | `rgba(29, 33, 41, 0.06)`   | `rgba(227, 229, 234, 0.05)` | The line between entries.                                                                    |
| `--lognal-hover`            | `rgba(29, 33, 41, 0.04)`   | `rgba(227, 229, 234, 0.06)` | The background of the rows of the entry under the pointer. Use `transparent` to turn it off. |
| `--lognal-search-match`     | `rgba(255, 200, 0, 0.4)`   | `rgba(255, 200, 0, 0.28)`   | Every match of a search.                                                                     |
| `--lognal-search-current`   | `rgba(255, 140, 0, 0.7)`   | `rgba(255, 140, 0, 0.6)`    | The current match of a search.                                                               |
| `--lognal-link`             | `#1f6fd6`                  | `#5aa2ff`                   | The text and the underline of a link.                                                        |
| `--lognal-entry-selection`  | `rgba(31, 111, 214, 0.1)`  | `rgba(90, 162, 255, 0.14)`  | The background of the rows of a selected entry in entry mode.                                |
| `--lognal-error`            | `#c4262c`                  | `#ff8a8d`                   | Error text, marker and repeat badge.                                                         |
| `--lognal-error-background` | `rgba(222, 53, 58, 0.07)`  | `rgba(252, 79, 83, 0.1)`    | The row background of errors.                                                                |
| `--lognal-warn`             | `#8a5a00`                  | `#fcc549`                   | Warning text, marker and repeat badge.                                                       |
| `--lognal-warn-background`  | `rgba(240, 173, 0, 0.1)`   | `rgba(252, 191, 50, 0.08)`  | The row background of warnings.                                                              |
| `--lognal-info`             | `#1f6fd6`                  | `#5aa2ff`                   | The marker of info entries.                                                                  |
| `--lognal-debug`            | `#646a78`                  | `#8f94a1`                   | The text of debug entries.                                                                   |

:::

::: fw flutter

| Field             | Light        | Dark         | Description                                                    |
| ----------------- | ------------ | ------------ | -------------------------------------------------------------- |
| `background`      | `0xffffffff` | `0xff16181d` | The background of the log.                                     |
| `foreground`      | `0xff1d2129` | `0xffe3e5ea` | Regular text.                                                  |
| `muted`           | `0xff646a78` | `0xff8f94a1` | Timestamps, notices, expander triangles and the output marker. |
| `accent`          | `0xff1f6fd6` | `0xff5aa2ff` | The input marker and the **New logs** button.                  |
| `selection`       | `0x381f6fd6` | `0x4d5aa2ff` | Selected text.                                                 |
| `match`           | `0x4df0ad00` | `0x4dfcbf32` | Filter matches.                                                |
| `separator`       | `0x0f1d2129` | `0x0de3e5ea` | The line between entries.                                      |
| `hover`           | `0x0a1d2129` | `0x0fe3e5ea` | The rows of the entry under the pointer.                       |
| `searchMatch`     | `0x66ffc800` | `0x47ffc800` | Every match of a search.                                       |
| `searchCurrent`   | `0xb2ff8c00` | `0x99ff8c00` | The current match of a search.                                 |
| `link`            | `0xff1f6fd6` | `0xff5aa2ff` | The text and the underline of a link.                          |
| `entrySelection`  | `0x1a1f6fd6` | `0x245aa2ff` | The rows of a selected entry in entry mode.                    |
| `focusRing`       | `0xff1f6fd6` | `0xff5aa2ff` | The outline of the entry the keyboard is on.                   |
| `error`           | `0xffc4262c` | `0xffff8a8d` | Error text, marker and repeat badge.                           |
| `errorBackground` | `0x12de353a` | `0x1afc4f53` | The row background of errors.                                  |
| `warn`            | `0xff8a5a00` | `0xfffcc549` | Warning text, marker and repeat badge.                         |
| `warnBackground`  | `0x1af0ad00` | `0x14fcbf32` | The row background of warnings.                                |
| `info`            | `0xff1f6fd6` | `0xff5aa2ff` | The marker of info entries.                                    |
| `debug`           | `0xff646a78` | `0xff8f94a1` | The text of debug entries.                                     |

:::

### Value colors

Typed values and styled text use these token colors. <Fw js="`warn`, `info`, `accent` and `attribute` are available for the `token` option of `write` and `writeLines`." flutter="They are the `tokens` map of a `RenderTheme`, keyed by `StyleToken`, and `warn`, `info`, `accent` and `attribute` are also what the `token` option of `write` and `writeLines` names." />

| <Fw js="Property" flutter="Token" />                                     | Light     | Dark      | Used for                                                 |
| ------------------------------------------------------------------------ | --------- | --------- | -------------------------------------------------------- |
| <Fw js="--lognal-token-string" flutter="StyleToken.string" code />       | `#1f7a47` | `#7fd6a4` | Strings.                                                 |
| <Fw js="--lognal-token-number" flutter="StyleToken.number" code />       | `#6f42c1` | `#b9a8ff` | Numbers.                                                 |
| <Fw js="--lognal-token-boolean" flutter="StyleToken.boolean" code />     | `#6f42c1` | `#b9a8ff` | `true` and `false`.                                      |
| <Fw js="--lognal-token-null" flutter="StyleToken.nullValue" code />      | `#646a78` | `#8f94a1` | `null`.                                                  |
| <Fw js="--lognal-token-key" flutter="StyleToken.key" code />             | `#1a5fb4` | `#82bdff` | Property names and indexes.                              |
| <Fw js="--lognal-token-symbol" flutter="StyleToken.symbol" code />       | `#a3316f` | `#f5a3d7` | Symbols.                                                 |
| <Fw js="--lognal-token-function" flutter="StyleToken.function" code />   | `#1a5fb4` | `#82bdff` | The `ƒ` and `class` before a name.                       |
| <Fw js="--lognal-token-regexp" flutter="StyleToken.regexp" code />       | `#b1361e` | `#ffa585` | Regular expressions.                                     |
| <Fw js="--lognal-token-date" flutter="StyleToken.date" code />           | `#1f7a47` | `#7fd6a4` | Dates.                                                   |
| <Fw js="--lognal-token-tag" flutter="StyleToken.tag" code />             | `#1a5fb4` | `#82bdff` | Element tags.                                            |
| <Fw js="--lognal-token-error" flutter="StyleToken.error" code />         | `#c4262c` | `#ff8a8d` | Error titles.                                            |
| <Fw js="--lognal-token-muted" flutter="StyleToken.muted" code />         | `#646a78` | `#8f94a1` | Stack traces, `… more` rows, accessors and `[Circular]`. |
| <Fw js="--lognal-token-warn" flutter="StyleToken.warn" code />           | `#8a5a00` | `#fcc549` | The `warn` token.                                        |
| <Fw js="--lognal-token-info" flutter="StyleToken.info" code />           | `#1f6fd6` | `#5aa2ff` | The `info` token.                                        |
| <Fw js="--lognal-token-accent" flutter="StyleToken.accent" code />       | `#1f6fd6` | `#5aa2ff` | The `accent` token.                                      |
| <Fw js="--lognal-token-attribute" flutter="StyleToken.attribute" code /> | `#8a5a00` | `#fcc549` | The `attribute` token.                                   |

### ANSI colors

<Fw js="--lognal-ansi-0 to --lognal-ansi-15" flutter="RenderTheme.ansi, sixteen colors" /> are what ANSI escape codes 30 to 37 and 90 to 97 select: black, red, green, yellow, blue, magenta, cyan and white, then the bright version of each.

| Index | Light     | Dark      | Index | Light     | Dark      |
| ----- | --------- | --------- | ----- | --------- | --------- |
| 0     | `#1d2129` | `#3b3f4a` | 8     | `#4b515e` | `#6b7080` |
| 1     | `#c4262c` | `#fc5c60` | 9     | `#de353a` | `#ff8a8d` |
| 2     | `#1f7a47` | `#43d786` | 10    | `#238b50` | `#7ee3a8` |
| 3     | `#8a5a00` | `#fcbf32` | 11    | `#9c6a00` | `#ffd466` |
| 4     | `#1f6fd6` | `#5aa2ff` | 12    | `#2f7fe6` | `#82bdff` |
| 5     | `#8f3aa8` | `#c792ea` | 13    | `#a34bbd` | `#ddb6f2` |
| 6     | `#0e7c86` | `#56d4dd` | 14    | `#10909b` | `#8ae6ec` |
| 7     | `#646a78` | `#d0d3db` | 15    | `#1d2129` | `#ffffff` |

## Fonts

The log is laid out on a grid of cells: a narrow character takes one cell and a wide character, such as a Hangul syllable, takes two. Only monospace fonts line up on that grid. A proportional font draws, but its characters do not match the cells, so selection and highlights land in the wrong places.

::: fw js

Set the font with CSS or with the `font` option. The option takes precedence for the log, and CSS also styles the input line, so CSS is usually the better place.

```css
.lognal {
	--lognal-font-family: 'JetBrains Mono', D2Coding, monospace;
	--lognal-font-size: 14px;
	--lognal-line-height: 1.5;
}
```

```ts
new LogViewer(container, {
	font: { family: "'JetBrains Mono', D2Coding, monospace", size: 14, lineHeight: 1.5 }
});
```

The viewer measures the width of a cell from the first font in the list that the browser can use. When that font has no glyph for a character, the browser draws it with a fallback font.

:::

::: fw flutter

`FontSettings` is the whole of it.

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(
    font: FontSettings(
      family: 'JetBrainsMono',
      fallbackFamilies: <String>['D2Coding', 'Noto Sans Mono CJK KR'],
      size: 14,
      lineHeight: 1.5,
    ),
  ),
);
```

Leave `family` out and the viewer names the platform's own monospace font — Menlo, Consolas, `monospace` — and falls back through the Korean and Japanese monospace faces after it. That is the right answer everywhere except the web.

### On the web

Flutter draws with the fonts an application bundles and cannot reach the ones the system has, so a web build that names `monospace` gets a proportional font and a grid that does not line up. Bundle a monospace font and name it:

```yaml
flutter:
  fonts:
    - family: JetBrainsMono
      fonts:
        - asset: fonts/JetBrainsMono-Regular.ttf
```

```dart
const FontSettings(family: 'JetBrainsMono');
```

The gallery under `packages/flutter/example` does exactly this, and its `fonts/README.md` says which font and why.

The engine still fetches a face for a character no bundled font covers, and the viewer measures again and redraws when one arrives, so Korean and emoji appear a moment after the rest rather than staying as boxes.

:::

lognal draws text that is not plain ASCII one character at a time at its grid position, so a fallback glyph cannot shift the rest of the line. A glyph wider than its cells is squeezed to fit, and a narrower wide glyph is centered in its two cells.

### Fonts for Korean text

Most Latin monospace fonts have no Hangul, and the fallback Hangul glyph is often narrower than two cells, which leaves gaps between syllables. For logs with Korean text, use a monospace font that includes Hangul drawn at twice the width of a Latin letter, such as [D2Coding](https://github.com/naver/d2codingfont), Nanum Gothic Coding or Noto Sans Mono CJK KR. The syllables then fill their two cells exactly.

::: fw js

```css
@font-face {
	font-family: 'D2Coding';
	src: url('/fonts/D2Coding.woff2') format('woff2');
	font-display: swap;
}

.lognal {
	--lognal-font-family: 'D2Coding', monospace;
}
```

### Web fonts

The viewer measures the font again when `document.fonts.ready` resolves, and when a web font that covers characters on screen finishes loading. If you change the font properties in CSS after the viewer exists, call `viewer.refresh()`.

:::

::: fw flutter

```yaml
flutter:
  fonts:
    - family: D2Coding
      fonts:
        - asset: fonts/D2Coding.ttf
```

```dart
const FontSettings(family: 'D2Coding');
```

:::
