import 'package:lognal/src/core/types.dart';

const String _escape = '\x1b';
const String _bell = '\x07';

/// Turns text with ANSI escape codes into styled parts.
///
/// Select Graphic Rendition codes (colors, bold, italic, underline and so on)
/// become styles. Every other escape sequence, such as cursor movement or an
/// OSC hyperlink wrapper, is removed so it cannot show up as stray characters.
/// The style carries over between calls, the way a terminal keeps it from one
/// line to the next.
class AnsiParser {
  LogTextStyle _style = const LogTextStyle();

  /// Parses one piece of text, usually a line.
  List<TextPart> parse(String text) {
    if (!text.contains(_escape)) {
      return <TextPart>[_createPart(text)];
    }

    final List<TextPart> parts = <TextPart>[];
    final StringBuffer buffer = StringBuffer();
    int index = 0;

    void flush() {
      if (buffer.isNotEmpty) {
        parts.add(_createPart(buffer.toString()));
        buffer.clear();
      }
    }

    while (index < text.length) {
      final String character = text[index];

      if (character != _escape) {
        buffer.write(character);
        index++;
        continue;
      }

      final String? next = index + 1 < text.length ? text[index + 1] : null;

      if (next == '[') {
        final int end = _findCsiEnd(text, index + 2);

        if (end < 0) {
          break;
        }

        if (text[end] == 'm') {
          flush();
          _applySgr(text.substring(index + 2, end));
        }

        index = end + 1;
      } else if (next == ']') {
        index = _findOscEnd(text, index + 2);
      } else {
        // A two-character escape such as `ESC c`, or a lone escape at the end.
        index += next == null ? 1 : 2;
      }
    }

    flush();

    return parts.isEmpty ? <TextPart>[_createPart('')] : parts;
  }

  /// Forgets the current style.
  void reset() {
    _style = const LogTextStyle();
  }

  TextPart _createPart(String text) {
    return TextPart(text, style: _style.isEmpty ? null : _style);
  }

  void _applySgr(String sequence) {
    final List<int> codes = sequence.isEmpty
        ? <int>[0]
        : sequence.split(RegExp('[;:]')).map((String code) => int.tryParse(code) ?? 0).toList();
    LogTextStyle style = _style;

    for (int index = 0; index < codes.length; index++) {
      final int code = codes[index];

      if (code == 0) {
        style = const LogTextStyle();
      } else if (code == 1) {
        style = style.copyWith(bold: true);
      } else if (code == 2) {
        style = style.copyWith(dim: true);
      } else if (code == 3) {
        style = style.copyWith(italic: true);
      } else if (code == 4) {
        style = style.copyWith(underline: true);
      } else if (code == 9) {
        style = style.copyWith(strikethrough: true);
      } else if (code == 22) {
        style = style.copyWith(bold: false, dim: false);
      } else if (code == 23) {
        style = style.copyWith(italic: false);
      } else if (code == 24) {
        style = style.copyWith(underline: false);
      } else if (code == 29) {
        style = style.copyWith(strikethrough: false);
      } else if (code >= 30 && code <= 37) {
        style = style.copyWith(color: AnsiTextColor(code - 30));
      } else if (code >= 90 && code <= 97) {
        style = style.copyWith(color: AnsiTextColor(code - 90 + 8));
      } else if (code >= 40 && code <= 47) {
        style = style.copyWith(background: AnsiTextColor(code - 40));
      } else if (code >= 100 && code <= 107) {
        style = style.copyWith(background: AnsiTextColor(code - 100 + 8));
      } else if (code == 39) {
        style = style.copyWith(clearColor: true);
      } else if (code == 49) {
        style = style.copyWith(clearBackground: true);
      } else if (code == 38 || code == 48) {
        final _ExtendedColor extended = _readExtendedColor(codes, index + 1);

        if (extended.color != null) {
          style = code == 38
              ? style.copyWith(color: extended.color)
              : style.copyWith(background: extended.color);
        }

        index += extended.used;
      }
    }

    _style = style;
  }
}

class _ExtendedColor {
  const _ExtendedColor(this.color, this.used);

  final TextColor? color;
  final int used;
}

int _clampByte(int? value) {
  final int amount = value ?? 0;

  return amount < 0
      ? 0
      : amount > 255
      ? 255
      : amount;
}

/// Reads a `5;n` or `2;r;g;b` color after code 38 or 48. Returns the color and
/// how many codes it consumed.
_ExtendedColor _readExtendedColor(List<int> codes, int start) {
  final int? mode = start < codes.length ? codes[start] : null;

  if (mode == 5) {
    final int index = start + 1 < codes.length ? codes[start + 1] : -1;

    return _ExtendedColor(index >= 0 && index <= 255 ? AnsiTextColor(index) : null, 2);
  }

  if (mode == 2) {
    final int red = _clampByte(start + 1 < codes.length ? codes[start + 1] : 0);
    final int green = _clampByte(start + 2 < codes.length ? codes[start + 2] : 0);
    final int blue = _clampByte(start + 3 < codes.length ? codes[start + 3] : 0);

    return _ExtendedColor(RgbTextColor(0xff000000 | (red << 16) | (green << 8) | blue), 4);
  }

  return const _ExtendedColor(null, 0);
}

/// Returns the index of the final byte of a CSI sequence, or -1 if the text ends
/// first.
int _findCsiEnd(String text, int start) {
  for (int index = start; index < text.length; index++) {
    final int code = text.codeUnitAt(index);

    if (code >= 0x40 && code <= 0x7e) {
      return index;
    }
  }

  return -1;
}

/// Returns the index just after an OSC sequence, which ends with BEL or `ESC \`.
int _findOscEnd(String text, int start) {
  for (int index = start; index < text.length; index++) {
    if (text[index] == _bell) {
      return index + 1;
    }

    if (text[index] == _escape && index + 1 < text.length && text[index + 1] == r'\') {
      return index + 2;
    }
  }

  return text.length;
}

/// Removes every ANSI escape sequence from text.
String stripAnsi(String text) {
  return AnsiParser().parse(text).map((TextPart part) => part.text).join();
}
