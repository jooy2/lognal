# The gallery's font

`NanumGothicCoding-Regular.ttf`, from
[Google Fonts](https://fonts.google.com/specimen/Nanum+Gothic+Coding), under the
SIL Open Font License 1.1. `OFL.txt` beside it is that license, and the reserved
font name it carries is Nanum.

It is here because of a limitation of Flutter on the web rather than of lognal:
CanvasKit draws with the fonts an application bundles and cannot reach the ones
the system has, so a web build that names `monospace` gets a proportional font
and a grid that does not line up. Every other platform resolves its own
monospace font by name and needs none of this.

This one is monospace for Latin and full-width for Hangul, which is exactly what
the viewer measures text as, so the Korean samples line up as well as the English
ones.
