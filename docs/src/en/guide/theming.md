---
order: 5
description: Switch lognal between light, dark and automatic themes, restyle it with --lognal-* CSS custom properties, and pick a monospace font that suits Korean text.
---

# Themes and fonts

## Theme modes

| `theme`   | Colors                                                                                                      |
| --------- | ----------------------------------------------------------------------------------------------------------- |
| `'auto'`  | Follows `prefers-color-scheme`, and changes when the operating system setting changes. This is the default. |
| `'light'` | Always light.                                                                                               |
| `'dark'`  | Always dark.                                                                                                |

```ts
const viewer = new LogViewer(container, { theme: 'auto' });
const darkModeSwitch = document.querySelector<HTMLInputElement>('#dark-mode')!;

darkModeSwitch.addEventListener('change', () => {
	viewer.setOptions({ theme: darkModeSwitch.checked ? 'dark' : 'light' });
});
```

The viewer writes the mode to the `data-theme` attribute of its root element, `.lognal`, and the stylesheet picks the colors from it.

## How colors reach the canvas

Every color and size of the viewer is a `--lognal-*` CSS custom property on `.lognal`. The canvas cannot use CSS directly, so the viewer reads the computed values and passes them to the renderer. It reads them when the viewer is created, when the theme changes, and when the operating system switches between light and dark in `'auto'` mode.

If you change the properties at another time, for example by toggling a class on a parent element, call `viewer.refresh()` so the canvas picks up the new values.

The dark colors are set for `.lognal[data-theme='dark']`, and again for `.lognal[data-theme='auto']` inside a `prefers-color-scheme: dark` media query. To change a color in both themes, override it in all three places:

```css
.build-log .lognal {
	--lognal-background: #fbfaf7;
	--lognal-accent: #7a3cff;
}

.build-log .lognal[data-theme='dark'] {
	--lognal-background: #0d1117;
	--lognal-accent: #b18cff;
}

@media (prefers-color-scheme: dark) {
	.build-log .lognal[data-theme='auto'] {
		--lognal-background: #0d1117;
		--lognal-accent: #b18cff;
	}
}
```

Any color the canvas accepts works, including `rgb()`, `hsl()` and `oklch()`.

## Custom properties

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

| Property                         | Light                                                                 | Dark                                                           | Description                                                                                   |
| -------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `--lognal-border`                | `#e3e6eb`                                                             | `#2a2e37`                                                      | The outline of the viewer, fields and separators.                                             |
| `--lognal-surface`               | `#f6f7f9`                                                             | `#1c1f25`                                                      | The background of the toolbar and the status bar.                                             |
| `--lognal-control-hover`         | `rgba(29, 33, 41, 0.07)`                                              | `rgba(227, 229, 234, 0.08)`                                    | A button under the pointer.                                                                   |
| `--lognal-control-active`        | `rgba(31, 111, 214, 0.12)`                                            | `rgba(90, 162, 255, 0.18)`                                     | A pressed button, such as follow.                                                             |
| `--lognal-focus-ring`            | `#1f6fd6`                                                             | `#5aa2ff`                                                      | The focus outline of the toolbar controls, the **New logs** button and the entry menu button. |
| `--lognal-scrollbar-thumb`       | `rgba(29, 33, 41, 0.28)`                                              | `rgba(227, 229, 234, 0.25)`                                    | The scrollbar thumb.                                                                          |
| `--lognal-scrollbar-thumb-hover` | `rgba(29, 33, 41, 0.45)`                                              | `rgba(227, 229, 234, 0.42)`                                    | The scrollbar thumb under the pointer.                                                        |
| `--lognal-popup-shadow`          | `0 8px 24px rgba(29, 33, 41, 0.14), 0 1px 3px rgba(29, 33, 41, 0.08)` | `0 8px 24px rgba(0, 0, 0, 0.45), 0 1px 3px rgba(0, 0, 0, 0.3)` | The shadow of the level menu and the entry menu.                                              |

### Log colors

The canvas draws with these. `background`, `foreground`, `muted` and `accent` also color the toolbar, the input line and the status bar.

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
| `--lognal-error`            | `#c4262c`                  | `#ff8a8d`                   | Error text, marker and repeat badge.                                                         |
| `--lognal-error-background` | `rgba(222, 53, 58, 0.07)`  | `rgba(252, 79, 83, 0.1)`    | The row background of errors.                                                                |
| `--lognal-warn`             | `#8a5a00`                  | `#fcc549`                   | Warning text, marker and repeat badge.                                                       |
| `--lognal-warn-background`  | `rgba(240, 173, 0, 0.1)`   | `rgba(252, 191, 50, 0.08)`  | The row background of warnings.                                                              |
| `--lognal-info`             | `#1f6fd6`                  | `#5aa2ff`                   | The marker of info entries.                                                                  |
| `--lognal-debug`            | `#646a78`                  | `#8f94a1`                   | The text of debug entries.                                                                   |

### Value colors

Typed values and styled text use these token colors. The first twelve are used by the built-in value formatting. `warn`, `info`, `accent` and `attribute` are available for the `token` option of `write` and `writeLines`.

| Property                   | Light     | Dark      | Used for                                                 |
| -------------------------- | --------- | --------- | -------------------------------------------------------- |
| `--lognal-token-string`    | `#1f7a47` | `#7fd6a4` | Strings.                                                 |
| `--lognal-token-number`    | `#6f42c1` | `#b9a8ff` | Numbers and bigints.                                     |
| `--lognal-token-boolean`   | `#6f42c1` | `#b9a8ff` | `true` and `false`.                                      |
| `--lognal-token-null`      | `#646a78` | `#8f94a1` | `null` and `undefined`.                                  |
| `--lognal-token-key`       | `#1a5fb4` | `#82bdff` | Property names and array indexes.                        |
| `--lognal-token-symbol`    | `#a3316f` | `#f5a3d7` | Symbols and symbol keys.                                 |
| `--lognal-token-function`  | `#1a5fb4` | `#82bdff` | The `ƒ` and `class` before a function name.              |
| `--lognal-token-regexp`    | `#b1361e` | `#ffa585` | Regular expressions.                                     |
| `--lognal-token-date`      | `#1f7a47` | `#7fd6a4` | Dates.                                                   |
| `--lognal-token-tag`       | `#1a5fb4` | `#82bdff` | DOM elements.                                            |
| `--lognal-token-error`     | `#c4262c` | `#ff8a8d` | Error titles.                                            |
| `--lognal-token-muted`     | `#646a78` | `#8f94a1` | Stack traces, `… more` rows, accessors and `[Circular]`. |
| `--lognal-token-warn`      | `#8a5a00` | `#fcc549` | The `warn` token.                                        |
| `--lognal-token-info`      | `#1f6fd6` | `#5aa2ff` | The `info` token.                                        |
| `--lognal-token-accent`    | `#1f6fd6` | `#5aa2ff` | The `accent` token.                                      |
| `--lognal-token-attribute` | `#8a5a00` | `#fcc549` | The `attribute` token.                                   |

### ANSI colors

`--lognal-ansi-0` to `--lognal-ansi-15` are the 16 colors that ANSI escape codes 30 to 37 and 90 to 97 select: black, red, green, yellow, blue, magenta, cyan and white, then the bright version of each.

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

The viewer measures the width of a cell from the first font in the list that the browser can use. When that font has no glyph for a character, the browser draws it with a fallback font. lognal draws text that is not plain ASCII one character at a time at its grid position, so a fallback glyph cannot shift the rest of the line. A glyph wider than its cells is squeezed to fit, and a narrower wide glyph is centered in its two cells.

### Fonts for Korean text

Most Latin monospace fonts have no Hangul, and the fallback Hangul glyph is often narrower than two cells, which leaves gaps between syllables. For logs with Korean text, use a monospace font that includes Hangul drawn at twice the width of a Latin letter, such as [D2Coding](https://github.com/naver/d2codingfont) or Noto Sans Mono CJK KR. The syllables then fill their two cells exactly.

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
