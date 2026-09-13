---
order: 7
description: How lognal handles Korean, Chinese and Japanese text, including character widths, word wrapping that keeps Hangul words together, IME input, decomposed Hangul in filters, and file encodings.
---

# Korean and CJK text

Korean, Chinese and Japanese text is a first-class case in lognal, for output and for input.

<ClientOnly>
  <LiveViewer preset="korean" />
</ClientOnly>

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

```ts
import { measureCells, truncateCells } from 'lognal';

measureCells('한글 log'); // 8
truncateCells('안녕하세요', 5); // '안녕…'
```

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

- `wrap: 'char'` fills every row and breaks between any two clusters. A wide character is never split.
- `wrap: 'none'` keeps each line on one row, and the log scrolls horizontally.

The **Wrap long lines** button in the toolbar turns wrapping off, and pressing it again restores `'word'` or `'char'`, whichever was in use.

## Selecting Korean text

A double-click selects a word: a run of letters, digits, combining marks, underscores and `$`. Hangul syllables are letters, so a double-click selects the Korean word under the pointer, together with any particle attached to it, up to the next space or punctuation mark.

## Input line and IME

The input line is a real `<textarea>`, so the operating system's input method works as it does in any text field: the composition is shown in place, and the candidate window follows the caret.

- Pressing Enter while a syllable is still being composed finishes the composition and does not submit the command. A second Enter submits it.
- The input line checks the composition events, `KeyboardEvent.isComposing`, and key code 229, which browsers report for key presses that belong to a composition.
- Safari up to version 26 fires `compositionend` before the `keydown` of the key that commits the composition, so that `keydown` reports no composition. The input line keeps treating the composition as open until the task after `compositionend`, so Safari behaves like the other browsers.
- ArrowUp and ArrowDown are left to the input method during a composition, and go through past commands otherwise.

## Filtering decomposed Hangul

Text can hold the same syllable in two forms: composed, such as `한`, or decomposed into jamo, `ᄒ` + `ᅡ` + `ᆫ`. File names from macOS and text copied from some applications are often decomposed, while what a user types is composed.

The filter converts both the entry text and the filter text to Unicode normalization form C before comparing them, so typing `한글` finds a decomposed `한글`, and the match is highlighted. Selecting and copying return the text as it was logged, without normalizing it.

## File encodings

`readTextFile` and `followTextFile` detect UTF-8 and fall back to a legacy encoding when a file is not valid UTF-8. For a browser set to Korean, the fallback is `euc-kr`. Browsers decode `euc-kr` as Windows code page 949, which covers every modern Hangul syllable, so files saved as CP949 decode correctly too.

To read Korean legacy files regardless of the browser language, set the fallback:

```ts
await readTextFile(file, viewer.store, { fallbackEncoding: 'euc-kr' });
```

See [Encodings](/guide/text-files#encodings) for the detection order.

## Fonts and labels

- Use a monospace font that includes Hangul, such as D2Coding, so syllables fill their two cells. See [Fonts for Korean text](/guide/theming#fonts-for-korean-text).
- `locale: 'ko'` shows the toolbar, the status bar and the accessible names in Korean.

```ts
new LogViewer(container, {
	locale: 'ko',
	font: { family: "D2Coding, 'Noto Sans Mono CJK KR', monospace" }
});
```
