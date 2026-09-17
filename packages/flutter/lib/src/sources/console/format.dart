import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/console/css_color.dart';

/// Captures a value for display.
typedef ValueCapture = ValueNode Function(Object? value);

final RegExp _specifier = RegExp('%([sdifoOc%])');

/// Splits a CSS value on spaces that are not inside parentheses.
List<String> _splitCssValue(String value) {
  final List<String> tokens = <String>[];
  final StringBuffer current = StringBuffer();
  int depth = 0;

  for (final String character in value.split('')) {
    if (character == '(') {
      depth++;
    } else if (character == ')') {
      depth = depth > 0 ? depth - 1 : 0;
    }

    if (character.trim().isEmpty && depth == 0) {
      if (current.isNotEmpty) {
        tokens.add(current.toString());
        current.clear();
      }
    } else {
      current.write(character);
    }
  }

  if (current.isNotEmpty) {
    tokens.add(current.toString());
  }

  return tokens;
}

/// Reads the CSS given to `%c` and keeps only what the viewer can draw: text and
/// background color, weight, style and decoration. Everything else is ignored,
/// including any value that refers to a URL, so a log message cannot make the
/// application load anything.
LogTextStyle? parseConsoleCss(String css) {
  int? color;
  int? background;
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strikethrough = false;

  for (final String declaration in css.split(';')) {
    final int separator = declaration.indexOf(':');

    if (separator < 0) {
      continue;
    }

    final String property = declaration.substring(0, separator).trim().toLowerCase();
    final String value = declaration.substring(separator + 1).trim();

    if (property == 'color') {
      color = parseCssColor(value);
    } else if (property == 'background' || property == 'background-color') {
      for (final String token in _splitCssValue(value)) {
        final int? parsed = parseCssColor(token);

        if (parsed != null) {
          background = parsed;
          break;
        }
      }
    } else if (property == 'font-weight') {
      final double? weight = double.tryParse(value);

      if (value == 'bold' || value == 'bolder' || (weight != null && weight >= 600)) {
        bold = true;
      }
    } else if (property == 'font-style' && RegExp('^(italic|oblique)').hasMatch(value)) {
      italic = true;
    } else if (property == 'text-decoration' || property == 'text-decoration-line') {
      if (value.contains('underline')) {
        underline = true;
      }

      if (value.contains('line-through')) {
        strikethrough = true;
      }
    }
  }

  final LogTextStyle style = LogTextStyle(
    color: color == null ? null : RgbTextColor(color),
    background: background == null ? null : RgbTextColor(background),
    bold: bold,
    italic: italic,
    underline: underline,
    strikethrough: strikethrough,
  );

  return style.isEmpty ? null : style;
}

String _toText(Object? value) => value == null ? 'null' : value.toString();

String _toInteger(Object? value) {
  if (value is num) {
    return '${value.truncate()}';
  }

  final String text = _toText(value);
  final RegExpMatch? digits = RegExp(r'^\s*[+-]?\d+').firstMatch(text);

  return digits == null ? 'NaN' : '${int.parse(digits.group(0)!.trim())}';
}

String _toFloat(Object? value) {
  if (value is num) {
    return '${value.toDouble()}';
  }

  final String text = _toText(value);
  final RegExpMatch? number = RegExp(r'^\s*[+-]?\d*\.?\d+(?:[eE][+-]?\d+)?').firstMatch(text);

  return number == null ? 'NaN' : '${double.parse(number.group(0)!.trim())}';
}

/// The parts of a formatted message, and the arguments no specifier consumed.
class FormattedMessage {
  /// Creates the result.
  const FormattedMessage(this.parts, this.rest);

  /// The parts the format string produced.
  final List<LogPart> parts;

  /// The arguments the specifiers did not consume.
  final List<Object?> rest;
}

/// Applies the format specifiers in the first argument, and returns the parts of
/// the message together with the arguments the specifiers did not consume.
///
/// `%s` converts with `toString`, `%d` and `%i` to an integer, `%f` to a double,
/// `%o` and `%O` insert the value itself, and `%c` styles the text that follows
/// it. `%%` writes a percent sign. A specifier with no argument left stays in
/// the text as written.
FormattedMessage applyFormat(List<Object?> args, ValueCapture capture) {
  final List<LogPart> parts = <LogPart>[];

  if (args.isEmpty || args.first is! String) {
    return FormattedMessage(parts, List<Object?>.of(args));
  }

  final String format = args.first as String;
  final List<Object?> values = args.sublist(1);
  LogTextStyle? style;
  StringBuffer text = StringBuffer();
  int last = 0;
  int consumed = 0;

  void flush() {
    if (text.isNotEmpty) {
      parts.add(TextPart(text.toString(), style: style));
      text = StringBuffer();
    }
  }

  for (final RegExpMatch match in _specifier.allMatches(format)) {
    final String specifier = match.group(1)!;

    text.write(format.substring(last, match.start));
    last = match.end;

    if (specifier == '%') {
      text.write('%');
      continue;
    }

    if (consumed >= values.length) {
      text.write(match.group(0));
      continue;
    }

    final Object? value = values[consumed++];

    switch (specifier) {
      case 's':
        text.write(_toText(value));
      case 'd':
      case 'i':
        text.write(_toInteger(value));
      case 'f':
        text.write(_toFloat(value));
      case 'c':
        flush();
        style = parseConsoleCss(_toText(value));
      default:
        flush();
        parts.add(ValuePart(capture(value)));
    }
  }

  text.write(format.substring(last));
  flush();

  return FormattedMessage(parts, values.sublist(consumed));
}

/// Turns the arguments of a logging call into the parts of an entry.
///
/// With more than one argument and a string first, the format specifiers are
/// applied. The remaining arguments follow, separated by spaces: strings as
/// plain text and everything else as a captured value.
List<LogPart> formatArguments(List<Object?> args, ValueCapture capture) {
  List<LogPart> parts = <LogPart>[];
  List<Object?> rest = List<Object?>.of(args);

  if (args.length > 1 && args.first is String) {
    final FormattedMessage formatted = applyFormat(args, capture);

    parts = formatted.parts;
    rest = formatted.rest;
  }

  for (final Object? value in rest) {
    if (parts.isNotEmpty) {
      parts.add(const TextPart(' '));
    }

    parts.add(value is String ? TextPart(value) : ValuePart(capture(value)));
  }

  return parts;
}
