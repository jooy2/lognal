/// The named colors a styled message may use.
///
/// The basic CSS keywords and nothing else. A longer list would be a longer
/// list; these are the ones a log line actually reaches for, and a name that is
/// not here is ignored rather than guessed at.
const Map<String, int> _namedColors = <String, int>{
  'black': 0xff000000,
  'silver': 0xffc0c0c0,
  'gray': 0xff808080,
  'grey': 0xff808080,
  'white': 0xffffffff,
  'maroon': 0xff800000,
  'red': 0xffff0000,
  'purple': 0xff800080,
  'fuchsia': 0xffff00ff,
  'magenta': 0xffff00ff,
  'green': 0xff008000,
  'lime': 0xff00ff00,
  'olive': 0xff808000,
  'yellow': 0xffffff00,
  'navy': 0xff000080,
  'blue': 0xff0000ff,
  'teal': 0xff008080,
  'aqua': 0xff00ffff,
  'cyan': 0xff00ffff,
  'orange': 0xffffa500,
  'pink': 0xffffc0cb,
  'brown': 0xffa52a2a,
  'transparent': 0x00000000,
};

final RegExp _hex = RegExp(r'^#([0-9a-f]{3,8})$', caseSensitive: false);
final RegExp _rgb = RegExp(
  r'^rgba?\(\s*([\d.]+%?)[\s,]+([\d.]+%?)[\s,]+([\d.]+%?)(?:[\s,/]+([\d.]+%?))?\s*\)$',
  caseSensitive: false,
);

int _clampByte(num value) {
  final int rounded = value.round();

  return rounded < 0
      ? 0
      : rounded > 255
      ? 255
      : rounded;
}

int? _channel(String text, {required bool alpha}) {
  final bool percent = text.endsWith('%');
  final double? amount = double.tryParse(percent ? text.substring(0, text.length - 1) : text);

  if (amount == null) {
    return null;
  }

  if (percent) {
    return _clampByte(amount * 255 / 100);
  }

  return alpha ? _clampByte(amount * 255) : _clampByte(amount);
}

/// Reads a CSS color into the `0xAARRGGBB` value a [RgbTextColor] holds, or
/// returns `null` when the text is not a color this package draws.
///
/// Hex in three, four, six or eight digits, `rgb()` and `rgba()` in either
/// syntax, and the basic color keywords. Anything else — a gradient, a variable,
/// a function that could fetch something — is not a color here, which is what
/// keeps a log message from making the application load anything.
int? parseCssColor(String value) {
  final String color = value.trim().toLowerCase();
  final int? named = _namedColors[color];

  if (named != null) {
    return named;
  }

  final RegExpMatch? hex = _hex.firstMatch(color);

  if (hex != null) {
    final String digits = hex.group(1)!;

    if (digits.length == 3 || digits.length == 4) {
      final String expanded = digits.split('').map((String digit) => '$digit$digit').join();

      return _fromHex(expanded);
    }

    if (digits.length == 6 || digits.length == 8) {
      return _fromHex(digits);
    }

    return null;
  }

  final RegExpMatch? rgb = _rgb.firstMatch(color);

  if (rgb == null) {
    return null;
  }

  final int? red = _channel(rgb.group(1)!, alpha: false);
  final int? green = _channel(rgb.group(2)!, alpha: false);
  final int? blue = _channel(rgb.group(3)!, alpha: false);
  final String? fourth = rgb.group(4);
  final int alpha = fourth == null ? 255 : (_channel(fourth, alpha: true) ?? 255);

  if (red == null || green == null || blue == null) {
    return null;
  }

  return (alpha << 24) | (red << 16) | (green << 8) | blue;
}

int? _fromHex(String digits) {
  final int? value = int.tryParse(digits, radix: 16);

  if (value == null) {
    return null;
  }

  if (digits.length == 6) {
    return 0xff000000 | value;
  }

  // `#rrggbbaa` puts the alpha last, and the value this package holds puts it
  // first.
  return ((value & 0xff) << 24) | (value >> 8);
}
