import 'dart:ui';

import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/renderer/types.dart';

/// The colors of the viewer's own chrome: the toolbar, the status bar, the
/// scrollbar and the popups.
///
/// The log itself is drawn from a [RenderTheme]; this is everything around it.
/// The two are written together as a [LognalTheme], which is what the stylesheet
/// holds on the JavaScript side.
class ChromeTheme {
  /// Creates the chrome colors.
  const ChromeTheme({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.accent,
    required this.border,
    required this.surface,
    required this.controlHover,
    required this.controlActive,
    required this.focusRing,
    required this.onAccent,
    required this.scrollbarThumb,
    required this.scrollbarThumbHover,
    required this.shadow,
  });

  /// The color behind the viewer.
  final Color background;

  /// The color of ordinary text in the chrome.
  final Color foreground;

  /// The color of a control that is not pressed, and of secondary text.
  final Color muted;

  /// The viewer's accent color.
  final Color accent;

  /// The line between the chrome and the log.
  final Color border;

  /// The background of the toolbar and the status bar.
  final Color surface;

  /// The background of a control under the pointer.
  final Color controlHover;

  /// The background of a control that is on.
  final Color controlActive;

  /// The ring around the control the keyboard is on.
  final Color focusRing;

  /// The color of text on [accent].
  final Color onAccent;

  /// The scrollbar's handle.
  final Color scrollbarThumb;

  /// The scrollbar's handle under the pointer.
  final Color scrollbarThumbHover;

  /// The shadow under a menu or a dialog.
  final Color shadow;
}

/// A palette, as the log and as the chrome around it.
class LognalTheme {
  /// Creates a palette.
  const LognalTheme({
    required this.name,
    required this.brightness,
    required this.renderer,
    required this.chrome,
  });

  /// The name the theme is chosen by, such as `dark`.
  final String name;

  /// Whether the palette is a light one or a dark one, which decides the
  /// keyboard and the text selection handles the platform draws over it.
  final Brightness brightness;

  /// The colors the log is drawn with.
  final RenderTheme renderer;

  /// The colors the chrome is drawn with.
  final ChromeTheme chrome;
}

Color _color(int value) => Color(value);

/// Builds the tokens of a palette from its muted color and its 16-color ramp,
/// the way the stylesheet builds them for every palette but the first two.
Map<StyleToken, Color> _tokensFromRamp({
  required Color muted,
  required List<Color> ansi,
  required Color error,
  required Color warn,
  required Color info,
  required Color accent,
}) {
  return <StyleToken, Color>{
    StyleToken.muted: muted,
    StyleToken.nullValue: muted,
    StyleToken.string: ansi[2],
    StyleToken.date: ansi[2],
    StyleToken.number: ansi[5],
    StyleToken.boolean: ansi[5],
    StyleToken.symbol: ansi[13],
    StyleToken.key: ansi[4],
    StyleToken.function: ansi[4],
    StyleToken.tag: ansi[4],
    StyleToken.regexp: ansi[1],
    StyleToken.attribute: ansi[3],
    StyleToken.error: error,
    StyleToken.warn: warn,
    StyleToken.info: info,
    StyleToken.accent: accent,
  };
}

/// Builds a palette from a base color, an accent and a ramp.
///
/// The four palettes after `light` and `dark` are written this way in the
/// stylesheet too: each one sets its own background, text, accent, border,
/// surface and sixteen ANSI colors, and everything else follows from those. A
/// palette of your own is the same handful of values.
LognalTheme buildTheme({
  required String name,
  required Brightness brightness,
  required Color background,
  required Color foreground,
  required Color muted,
  required Color accent,
  required Color border,
  required Color surface,
  required Color selection,
  required Color entrySelection,
  required Color controlActive,
  required List<Color> ansi,
}) {
  final bool isDark = brightness == Brightness.dark;
  final Color error = isDark ? ansi[9] : ansi[1];
  final Color warn = isDark ? ansi[11] : ansi[3];

  return LognalTheme(
    name: name,
    brightness: brightness,
    renderer: RenderTheme(
      background: background,
      foreground: foreground,
      muted: muted,
      accent: accent,
      selection: selection,
      match: _color(0x52f0ad00),
      separator: _color(isDark ? 0x0fffffff : 0x0f000000),
      hover: _color(isDark ? 0x0dffffff : 0x0a000000),
      searchMatch: _color(0x57ffc800),
      searchCurrent: _color(0xa6ff8c00),
      link: accent,
      entrySelection: entrySelection,
      focusRing: accent,
      error: error,
      errorBackground: _color(isDark ? 0x1aff5a5a : 0x14c83c32),
      warn: warn,
      warnBackground: _color(isDark ? 0x14ffbe3c : 0x1fc89600),
      info: accent,
      debug: muted,
      tokens: _tokensFromRamp(
        muted: muted,
        ansi: ansi,
        error: error,
        warn: warn,
        info: accent,
        accent: accent,
      ),
      ansi: ansi,
    ),
    chrome: ChromeTheme(
      background: background,
      foreground: foreground,
      muted: muted,
      accent: accent,
      border: border,
      surface: surface,
      controlHover: _color(isDark ? 0x14ffffff : 0x0f000000),
      controlActive: controlActive,
      focusRing: accent,
      onAccent: _color(isDark ? 0xff0b1220 : 0xffffffff),
      scrollbarThumb: _color(isDark ? 0x3dffffff : 0x40000000),
      scrollbarThumbHover: _color(isDark ? 0x66ffffff : 0x6b000000),
      shadow: _color(isDark ? 0x73000000 : 0x24281e14),
    ),
  );
}

/// The light palette, and the one `auto` picks on a light system.
final LognalTheme lightTheme = LognalTheme(
  name: 'light',
  brightness: Brightness.light,
  renderer: RenderTheme(
    background: _color(0xffffffff),
    foreground: _color(0xff1d2129),
    muted: _color(0xff646a78),
    accent: _color(0xff1f6fd6),
    selection: _color(0x381f6fd6),
    match: _color(0x4df0ad00),
    separator: _color(0x0f1d2129),
    hover: _color(0x0a1d2129),
    searchMatch: _color(0x66ffc800),
    searchCurrent: _color(0xb2ff8c00),
    link: _color(0xff1f6fd6),
    entrySelection: _color(0x1a1f6fd6),
    focusRing: _color(0xff1f6fd6),
    error: _color(0xffc4262c),
    errorBackground: _color(0x12de353a),
    warn: _color(0xff8a5a00),
    warnBackground: _color(0x1af0ad00),
    info: _color(0xff1f6fd6),
    debug: _color(0xff646a78),
    tokens: <StyleToken, Color>{
      StyleToken.muted: _color(0xff646a78),
      StyleToken.string: _color(0xff1f7a47),
      StyleToken.number: _color(0xff6f42c1),
      StyleToken.boolean: _color(0xff6f42c1),
      StyleToken.nullValue: _color(0xff646a78),
      StyleToken.key: _color(0xff1a5fb4),
      StyleToken.symbol: _color(0xffa3316f),
      StyleToken.function: _color(0xff1a5fb4),
      StyleToken.regexp: _color(0xffb1361e),
      StyleToken.date: _color(0xff1f7a47),
      StyleToken.tag: _color(0xff1a5fb4),
      StyleToken.attribute: _color(0xff8a5a00),
      StyleToken.error: _color(0xffc4262c),
      StyleToken.warn: _color(0xff8a5a00),
      StyleToken.info: _color(0xff1f6fd6),
      StyleToken.accent: _color(0xff1f6fd6),
    },
    ansi: <Color>[
      _color(0xff1d2129),
      _color(0xffc4262c),
      _color(0xff1f7a47),
      _color(0xff8a5a00),
      _color(0xff1f6fd6),
      _color(0xff8f3aa8),
      _color(0xff0e7c86),
      _color(0xff646a78),
      _color(0xff4b515e),
      _color(0xffde353a),
      _color(0xff238b50),
      _color(0xff9c6a00),
      _color(0xff2f7fe6),
      _color(0xffa34bbd),
      _color(0xff10909b),
      _color(0xff1d2129),
    ],
  ),
  chrome: ChromeTheme(
    background: _color(0xffffffff),
    foreground: _color(0xff1d2129),
    muted: _color(0xff646a78),
    accent: _color(0xff1f6fd6),
    border: _color(0xffe3e6eb),
    surface: _color(0xfff6f7f9),
    controlHover: _color(0x121d2129),
    controlActive: _color(0x1f1f6fd6),
    focusRing: _color(0xff1f6fd6),
    onAccent: _color(0xffffffff),
    scrollbarThumb: _color(0x471d2129),
    scrollbarThumbHover: _color(0x731d2129),
    shadow: _color(0x241d2129),
  ),
);

/// The dark palette, and the one `auto` picks on a dark system.
final LognalTheme darkTheme = LognalTheme(
  name: 'dark',
  brightness: Brightness.dark,
  renderer: RenderTheme(
    background: _color(0xff16181d),
    foreground: _color(0xffe3e5ea),
    muted: _color(0xff8f94a1),
    accent: _color(0xff5aa2ff),
    selection: _color(0x4d5aa2ff),
    match: _color(0x4dfcbf32),
    separator: _color(0x0de3e5ea),
    hover: _color(0x0fe3e5ea),
    searchMatch: _color(0x47ffc800),
    searchCurrent: _color(0x99ff8c00),
    link: _color(0xff5aa2ff),
    entrySelection: _color(0x245aa2ff),
    focusRing: _color(0xff5aa2ff),
    error: _color(0xffff8a8d),
    errorBackground: _color(0x1afc4f53),
    warn: _color(0xfffcc549),
    warnBackground: _color(0x14fcbf32),
    info: _color(0xff5aa2ff),
    debug: _color(0xff8f94a1),
    tokens: <StyleToken, Color>{
      StyleToken.muted: _color(0xff8f94a1),
      StyleToken.string: _color(0xff7fd6a4),
      StyleToken.number: _color(0xffb9a8ff),
      StyleToken.boolean: _color(0xffb9a8ff),
      StyleToken.nullValue: _color(0xff8f94a1),
      StyleToken.key: _color(0xff82bdff),
      StyleToken.symbol: _color(0xfff5a3d7),
      StyleToken.function: _color(0xff82bdff),
      StyleToken.regexp: _color(0xffffa585),
      StyleToken.date: _color(0xff7fd6a4),
      StyleToken.tag: _color(0xff82bdff),
      StyleToken.attribute: _color(0xfffcc549),
      StyleToken.error: _color(0xffff8a8d),
      StyleToken.warn: _color(0xfffcc549),
      StyleToken.info: _color(0xff5aa2ff),
      StyleToken.accent: _color(0xff5aa2ff),
    },
    ansi: <Color>[
      _color(0xff3b3f4a),
      _color(0xfffc5c60),
      _color(0xff43d786),
      _color(0xfffcbf32),
      _color(0xff5aa2ff),
      _color(0xffc792ea),
      _color(0xff56d4dd),
      _color(0xffd0d3db),
      _color(0xff6b7080),
      _color(0xffff8a8d),
      _color(0xff7ee3a8),
      _color(0xffffd466),
      _color(0xff82bdff),
      _color(0xffddb6f2),
      _color(0xff8ae6ec),
      _color(0xffffffff),
    ],
  ),
  chrome: ChromeTheme(
    background: _color(0xff16181d),
    foreground: _color(0xffe3e5ea),
    muted: _color(0xff8f94a1),
    accent: _color(0xff5aa2ff),
    border: _color(0xff2a2e37),
    surface: _color(0xff1c1f25),
    controlHover: _color(0x14e3e5ea),
    controlActive: _color(0x2e5aa2ff),
    focusRing: _color(0xff5aa2ff),
    onAccent: _color(0xff0b1220),
    scrollbarThumb: _color(0x40e3e5ea),
    scrollbarThumbHover: _color(0x6be3e5ea),
    shadow: _color(0x73000000),
  ),
);

/// Paper: a warm light palette.
final LognalTheme paperTheme = buildTheme(
  name: 'paper',
  brightness: Brightness.light,
  background: _color(0xfffbf7ef),
  foreground: _color(0xff3a332a),
  muted: _color(0xff7b7061),
  accent: _color(0xffa8571a),
  border: _color(0xffe6dccb),
  surface: _color(0xfff3ecdf),
  selection: _color(0x33a8571a),
  entrySelection: _color(0x1aa8571a),
  controlActive: _color(0x24a8571a),
  ansi: <Color>[
    _color(0xff3a332a),
    _color(0xffb3372c),
    _color(0xff4c7a2e),
    _color(0xff96660b),
    _color(0xff2f6ca8),
    _color(0xff8b4a95),
    _color(0xff2c7b7b),
    _color(0xff7b7061),
    _color(0xff5b5245),
    _color(0xffc8503f),
    _color(0xff5c8f38),
    _color(0xffab7a12),
    _color(0xff3b7fbd),
    _color(0xffa05ba8),
    _color(0xff35908e),
    _color(0xff3a332a),
  ],
);

/// Midnight: a cool dark palette.
final LognalTheme midnightTheme = buildTheme(
  name: 'midnight',
  brightness: Brightness.dark,
  background: _color(0xff0f1226),
  foreground: _color(0xffdcdff5),
  muted: _color(0xff8b90b8),
  accent: _color(0xff7aa2ff),
  border: _color(0xff232744),
  surface: _color(0xff171b33),
  selection: _color(0x4d7aa2ff),
  entrySelection: _color(0x247aa2ff),
  controlActive: _color(0x337aa2ff),
  ansi: <Color>[
    _color(0xff2a2f52),
    _color(0xffff6b7f),
    _color(0xff57d6a0),
    _color(0xffffc46b),
    _color(0xff7aa2ff),
    _color(0xffc39bff),
    _color(0xff63d6e0),
    _color(0xffc7cbe8),
    _color(0xff4a5080),
    _color(0xffff97a6),
    _color(0xff86e6bd),
    _color(0xffffd694),
    _color(0xffa3c0ff),
    _color(0xffd9bcff),
    _color(0xff93e6ec),
    _color(0xffffffff),
  ],
);

/// Ember: a warm dark palette.
final LognalTheme emberTheme = buildTheme(
  name: 'ember',
  brightness: Brightness.dark,
  background: _color(0xff1b1512),
  foreground: _color(0xfff0e3d8),
  muted: _color(0xffa3907f),
  accent: _color(0xffff9d4d),
  border: _color(0xff332720),
  surface: _color(0xff221a16),
  selection: _color(0x47ff9d4d),
  entrySelection: _color(0x1fff9d4d),
  controlActive: _color(0x33ff9d4d),
  ansi: <Color>[
    _color(0xff3a2c24),
    _color(0xfff4645f),
    _color(0xffb5c95f),
    _color(0xffffb545),
    _color(0xff6fb3c8),
    _color(0xffd98ab0),
    _color(0xff77c9b4),
    _color(0xffe0d0c2),
    _color(0xff5c483c),
    _color(0xffff8a85),
    _color(0xffcfe07a),
    _color(0xffffcd78),
    _color(0xff93cbdd),
    _color(0xffeaa9c8),
    _color(0xff9adccb),
    _color(0xfffff6ec),
  ],
);

/// Moss: a green dark palette.
final LognalTheme mossTheme = buildTheme(
  name: 'moss',
  brightness: Brightness.dark,
  background: _color(0xff121914),
  foreground: _color(0xffdbe7dc),
  muted: _color(0xff8aa08d),
  accent: _color(0xff7fd08a),
  border: _color(0xff223024),
  surface: _color(0xff18211a),
  selection: _color(0x427fd08a),
  entrySelection: _color(0x1f7fd08a),
  controlActive: _color(0x2e7fd08a),
  ansi: <Color>[
    _color(0xff243126),
    _color(0xffe8746b),
    _color(0xff7fd08a),
    _color(0xffd9be63),
    _color(0xff6fb6c4),
    _color(0xffb79ad6),
    _color(0xff74cbb8),
    _color(0xffc6d4c7),
    _color(0xff465a49),
    _color(0xfff2958c),
    _color(0xffa1e0a8),
    _color(0xffe8d189),
    _color(0xff95cdd8),
    _color(0xffcdb6e6),
    _color(0xff99dccd),
    _color(0xfff2f7f2),
  ],
);

/// The palettes this package ships, in the order the theme menu lists them.
final List<LognalTheme> builtInThemes = <LognalTheme>[
  lightTheme,
  paperTheme,
  darkTheme,
  midnightTheme,
  emberTheme,
  mossTheme,
];

/// The names of the palettes this package ships.
final List<String> builtInThemeNames = builtInThemes
    .map((LognalTheme theme) => theme.name)
    .toList();

/// Returns the palette with a name, or `null` when nothing ships under it.
LognalTheme? builtInTheme(String name) {
  for (final LognalTheme theme in builtInThemes) {
    if (theme.name == name) {
      return theme;
    }
  }

  return null;
}

/// The palette a choice ends up using.
///
/// `auto` follows the platform, anything else is looked up by name, and a name
/// nothing ships under falls back to the platform as well — which is what makes
/// `theme: 'mine'` with a [LognalTheme] of your own the only way to add one.
LognalTheme resolveTheme(String name, Brightness platform) {
  if (name == 'auto') {
    return platform == Brightness.dark ? darkTheme : lightTheme;
  }

  return builtInTheme(name) ?? (platform == Brightness.dark ? darkTheme : lightTheme);
}
