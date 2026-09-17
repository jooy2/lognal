---
order: 7
description: How lognal handles Korean, Chinese and Japanese text, including character widths, word wrapping that keeps Hangul words together, IME input, decomposed Hangul in filters, and file encodings.
---

# Korean and CJK text

Korean, Chinese and Japanese text is a first-class case in lognal, for output and for input.

::: fw js

<ClientOnly>
  <LiveViewer preset="korean" />
</ClientOnly>

:::

::: fw flutter

<ClientOnly>
  <FlutterDemo demo="wide" :height="360" />
</ClientOnly>

:::

## Width on the grid

The log is a grid of cells. lognal splits text into grapheme clusters, the characters a reader sees, and gives each cluster 0, 1 or 2 cells. The widths come from the East Asian Width data of Unicode 17.0.0.

| Characters                                                                               | Cells                            | Examples                     |
| ---------------------------------------------------------------------------------------- | -------------------------------- | ---------------------------- |
| Wide and fullwidth characters: Hangul, Han ideographs, kana, fullwidth forms, most emoji | 2                                | `한`, `中`, `の`, `Ａ`, `👍` |
| Narrow characters: Latin, digits, halfwidth forms                                        | 1                                | `a`, `1`, `ｱ`                |
| East Asian Ambiguous characters                                                          | 1, or 2 with `ambiguousWidth: 2` | `①`, `○`, `α`                |
| Box-drawing characters from U+2500 to U+259F                                             | 1                                | `─`, `│`, `┼`                |
| Combining marks and invisible format characters                                          | 0                                | U+0301, zero width space     |

- The widest code point decides the width of a cluster, so a Hangul syllable written as separate jamo still takes two cells.
- A cluster with the emoji variation selector U+FE0F, or a flag made of two regional indicators, takes two cells. A cluster with the text variation selector U+FE0E takes one.
- A combining mark with nothing before it takes one cell, so it stays visible.
- Ambiguous characters are one cell wide in most monospace fonts. If your font draws them wide, as many CJK fonts do, set `core: { ambiguousWidth: 2 }`.
- Box-drawing characters are ambiguous in the data but always take one cell, so tables drawn with them line up.

Control characters would be invisible or move the cursor, and bidirectional formatting characters can make a line read differently from what it contains. lognal shows them in the muted color instead: `^A` for U+0001, `^?` for DEL, and `<U+202E>` for others. A tab becomes spaces up to the next tab stop, every 8 cells by default.

`measureCells(text)` returns the width of a string with the same rules, and `truncateCells(text, maxCells)` cuts a string to a width without splitting a wide character.

::: fw js

```ts
import { measureCells, truncateCells } from 'lognal';

measureCells('한글 log'); // 8
truncateCells('안녕하세요', 5); // '안녕…'
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

measureCells('한글 log'); // 8
truncateCells('안녕하세요', 5); // '안녕…'
```

The core needs a grapheme splitter, and Dart has no built-in one, so the viewer installs the splitter of `package:characters` — the same seam `setGraphemeSplitter` is on the JavaScript side, where `Intl.Segmenter` fills it. Using the core without the viewer falls back to a splitter written here, which joins combining marks, variation selectors, emoji modifiers, zero width joiner sequences and regional indicator pairs.

:::

## Word wrapping

With the default `wrap: 'word'`, a line longer than the viewer breaks:

- after a space,
- on either side of a wide character that is not Hangul, so Chinese and Japanese text can break between any two characters,
- nowhere inside a run of Hangul, so Korean breaks at spaces the way English does. A word attached to Latin letters or digits, such as `English가`, stays together too.

A word longer than the whole row is broken between characters. A space that does not fit at the end of a row hangs past the edge, so a row never starts with the space that ended the word before it. At a width of 20 cells, a Korean sentence wraps like this:

```text
한글과 English가
섞인 긴 문장은
공백에서 줄이
바뀝니다.
```

Line breaking rules for punctuation are not applied, so a row can start with `。` or `、`.

The other modes:

- <Fw js="wrap: 'char'" flutter="wrap: WrapMode.char" code /> fills every row and breaks between any two clusters. A wide character is never split.
- <Fw js="wrap: 'none'" flutter="wrap: WrapMode.none" code /> keeps each line on one row, and the log scrolls horizontally.

The **Wrap long lines** button in the toolbar turns wrapping off, and pressing it again restores `'word'` or `'char'`, whichever was in use.

## Selecting Korean text

A double click or double tap selects a word: a run of letters, digits, combining marks, underscores and `$`. Hangul syllables are letters, so a double-click selects the Korean word under the pointer, together with any particle attached to it, up to the next space or punctuation mark.

## Input line and input methods

::: fw js

The input line is a real `<textarea>`, so the operating system's input method works as it does in any text field: the composition is shown in place, and the candidate window follows the caret.

- Pressing Enter while a Korean syllable is still being composed finishes the syllable and submits the command, so one press is enough, as it is for Latin text.
- Pressing Enter to confirm a Japanese or Chinese candidate only confirms it. Press Enter again to submit.
- The input line checks the composition events, `KeyboardEvent.isComposing`, and key code 229, which browsers report for key presses that belong to a composition. Such a key press never submits the command by itself.
- Safari up to version 26 fires `compositionend` before the `keydown` of the key that commits the composition, so that `keydown` reports no composition. The input line keeps treating the composition as open until the task after `compositionend`, so Safari behaves like the other browsers.
- A Korean input method passes the Enter on after finishing the syllable, and the browser goes on to insert a line break. The input line cancels that line break in `beforeinput` and submits instead. With Shift held, the line break stays.
- ArrowUp and ArrowDown are left to the input method during a composition, and go through past commands otherwise.

:::

::: fw flutter

The input line is a real text field rather than something drawn on the canvas, which is the whole reason an input method works here: the composition belongs to the field, so the platform composes into it and shows its candidates over it, exactly as in any other field of the application.

- Enter reaches the command only once the composition is finished, so a Korean syllable is committed by the same press that submits, and a Japanese or Chinese candidate is confirmed by one press and submitted by the next.
- The field handles the composition itself, so there is nothing to configure and nothing that behaves differently per platform.
- The arrow keys go through past commands when the field is not composing.

:::

## Filtering decomposed Hangul

Text can hold the same syllable in two forms: composed, such as `한`, or decomposed into jamo, `ᄒ` + `ᅡ` + `ᆫ`. File names from macOS and text copied from some applications are often decomposed, while what a user types is composed.

The filter and the search convert both the entry text and what you typed to Unicode normalization form C before comparing them, so typing `한글` finds a decomposed `한글`, and the match is highlighted. Selecting and copying return the text as it was logged, without normalizing it.

::: fw flutter

Dart has no `String.normalize`, so this package carries the composition table itself, generated from the Unicode Character Database beside the width table. It is the one place where a seam the JavaScript side takes from the runtime had to be written out.

:::

## File encodings

The file readers detect UTF-8 and fall back to a legacy encoding when a file is not valid UTF-8. For a Korean system, the fallback is `euc-kr`.

::: fw js

Browsers decode `euc-kr` as Windows code page 949, which covers every modern Hangul syllable, so files saved as CP949 decode correctly too. To read Korean legacy files regardless of the browser language, set the fallback:

```ts
await readTextFile(file, viewer.store, { fallbackEncoding: 'euc-kr' });
```

:::

::: fw flutter

Naming the encoding is not the same as decoding it here: `euc-kr` is a table of tens of thousands of characters that a browser already has and Dart does not, so this package takes a decoder from your application through `registerTextDecoder`. Without one, a read says through `result.decoded` that it fell back, rather than failing.

:::

See [Encodings](/guide/text-files#encodings) for the detection order.

## Fonts and labels

- Use a monospace font that includes Hangul, such as D2Coding, so syllables fill their two cells. See [Fonts for Korean text](/guide/theming#fonts-for-korean-text).
- `locale: 'ko'` shows the toolbar, the status bar and the accessible names in Korean.

::: fw js

```ts
new LogViewer(container, {
	locale: 'ko',
	font: { family: "D2Coding, 'Noto Sans Mono CJK KR', monospace" }
});
```

:::

::: fw flutter

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(
    locale: 'ko',
    font: FontSettings(family: 'D2Coding', fallbackFamilies: <String>['Noto Sans Mono CJK KR']),
  ),
);
```

:::
