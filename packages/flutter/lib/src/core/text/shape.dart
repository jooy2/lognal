import 'dart:typed_data';

import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/graphemes.dart';
import 'package:lognal/src/core/text/width.dart';
import 'package:lognal/src/core/types.dart';

/// How a logical line is split into clusters and measured.
class ShapeOptions {
  /// Creates the shaping options.
  const ShapeOptions({this.tabSize = 8, this.ambiguousWidth = 1, this.maxClusters = 10000});

  /// Cells between tab stops.
  final int tabSize;

  /// Cells an East Asian Ambiguous character takes.
  final AmbiguousWidth ambiguousWidth;

  /// The most clusters a line keeps. The rest is replaced with `…`.
  final int maxClusters;
}

/// The shaping options a layout starts with.
const ShapeOptions defaultShapeOptions = ShapeOptions();

final RegExp _printableAscii = RegExp(r'^[\x20-\x7e]*$');
final RegExp _specialCharacter = RegExp(
  '[\\x00-\\x1f\\x7f-\\x9f\\u061c\\u200e\\u200f\\u202a-\\u202e\\u2066-\\u2069]',
);
const String _ellipsis = '…';

/// Returns the visible notation for a character that must not be drawn as is: a
/// control character, which would be invisible or move the cursor, or a
/// bidirectional formatting character, which can make a line read differently
/// from what it contains.
String _notationOf(int code) {
  if (code < 0x20) {
    return '^${String.fromCharCode(code + 0x40)}';
  }

  if (code == 0x7f) {
    return '^?';
  }

  return '<U+${code.toRadixString(16).toUpperCase().padLeft(4, '0')}>';
}

class _LineBuilder {
  _LineBuilder(this.options);

  final ShapeOptions options;
  final List<ShapedSpan> spans = <ShapedSpan>[];
  final List<int> spanStarts = <int>[];
  final List<String> clusters = <String>[];
  final List<int> widths = <int>[];
  final List<int> breaks = <int>[];
  int cells = 0;
  bool simple = true;
  bool full = false;

  void openSpan(ShapedSpan span) {
    spans.add(span);
    spanStarts.add(clusters.length);
  }

  void addCluster(String cluster, int width, int breakClass) {
    if (clusters.length >= options.maxClusters) {
      full = true;

      return;
    }

    clusters.add(cluster);
    widths.add(width);
    breaks.add(breakClass);
    cells += width;
  }

  /// Drops clusters past [count], and spans that no longer have a cluster.
  void truncate(int count) {
    clusters.length = count;
    widths.length = count;
    breaks.length = count;
    cells = widths.fold<int>(0, (int sum, int width) => sum + width);
    full = false;

    while (spanStarts.isNotEmpty && spanStarts.last >= count) {
      spanStarts.removeLast();
      spans.removeLast();
    }
  }

  void addText(ShapedSpan source, String text) {
    if (text.isEmpty || full) {
      return;
    }

    openSpan(source.copyWith(text: text));

    if (_printableAscii.hasMatch(text)) {
      for (int index = 0; index < text.length && !full; index++) {
        final String character = text[index];

        addCluster(character, 1, character == ' ' ? breakSpace : breakNormal);
      }

      return;
    }

    simple = false;

    for (final String cluster in splitGraphemes(text)) {
      if (full) {
        return;
      }

      final int width = clusterWidth(cluster, options.ambiguousWidth);
      int breakClass = breakNormal;

      if (cluster == ' ') {
        breakClass = breakSpace;
      } else if (width == 2) {
        breakClass = isHangul(cluster.runes.first) ? breakKeep : breakWide;
      }

      addCluster(cluster, width, breakClass);
    }
  }

  void addSpan(LineSpan span) {
    if (span is LineIconSpan) {
      openSpan(ShapedSpan('', icon: true, expanded: span.expanded, action: span.action));
      simple = false;
      addCluster('', 2, breakNormal);

      return;
    }

    final LineTextSpan text = span as LineTextSpan;
    final ShapedSpan source = ShapedSpan(
      '',
      token: text.token,
      style: text.style,
      action: text.action,
    );

    if (!_specialCharacter.hasMatch(text.text)) {
      addText(source, text.text);

      return;
    }

    int start = 0;

    for (int index = 0; index < text.text.length; index++) {
      if (!_specialCharacter.hasMatch(text.text[index])) {
        continue;
      }

      final int code = text.text.codeUnitAt(index);

      addText(source, text.text.substring(start, index));
      start = index + 1;

      if (code == 0x09) {
        final int size = options.tabSize;

        addText(source, ' ' * (size - (cells % size)));
      } else {
        addText(ShapedSpan('', token: StyleToken.muted, action: source.action), _notationOf(code));
      }
    }

    addText(source, text.text.substring(start));
  }
}

/// Builds a simple line without splitting it, for the common case of one ASCII
/// span.
ShapedLine _shapeSimple(ShapedSpan span, int indent) {
  return ShapedLine(
    indent: indent,
    spans: <ShapedSpan>[span],
    spanStarts: Uint32List.fromList(<int>[0]),
    simple: true,
    text: span.text,
    clusters: null,
    widths: null,
    breaks: null,
    length: span.text.length,
    cells: span.text.length,
  );
}

/// Splits the spans of a logical line into clusters and measures them.
///
/// Tabs become spaces up to the next tab stop, and control and bidirectional
/// formatting characters are replaced with a visible notation in the muted
/// style.
ShapedLine shapeLine(
  List<LineSpan> spans,
  int indent, [
  ShapeOptions options = defaultShapeOptions,
]) {
  if (spans.length == 1) {
    final LineSpan span = spans.first;

    if (span is LineTextSpan &&
        span.text.length <= options.maxClusters &&
        _printableAscii.hasMatch(span.text)) {
      return _shapeSimple(
        ShapedSpan(span.text, token: span.token, style: span.style, action: span.action),
        indent,
      );
    }
  }

  final _LineBuilder builder = _LineBuilder(options);

  for (final LineSpan span in spans) {
    if (builder.full) {
      break;
    }

    builder.addSpan(span);
  }

  if (builder.full) {
    final int keep = builder.clusters.length - 2;

    builder.truncate(keep > 0 ? keep : 0);
    builder.openSpan(const ShapedSpan(' $_ellipsis', token: StyleToken.muted));
    builder.addCluster(' ', 1, breakSpace);
    builder.addCluster(_ellipsis, 1, breakNormal);
    builder.simple = false;
  }

  final String text = builder.clusters.join();
  final Uint32List spanStarts = Uint32List.fromList(builder.spanStarts);

  if (builder.simple) {
    return ShapedLine(
      indent: indent,
      spans: builder.spans,
      spanStarts: spanStarts,
      simple: true,
      text: text,
      clusters: null,
      widths: null,
      breaks: null,
      length: builder.clusters.length,
      cells: builder.cells,
    );
  }

  return ShapedLine(
    indent: indent,
    spans: builder.spans,
    spanStarts: spanStarts,
    simple: false,
    text: text,
    clusters: builder.clusters,
    widths: Uint8List.fromList(builder.widths),
    breaks: Uint8List.fromList(builder.breaks),
    length: builder.clusters.length,
    cells: builder.cells,
  );
}

/// Returns the width of a cluster of a shaped line.
int widthAt(ShapedLine line, int index) {
  final Uint8List? widths = line.widths;

  return widths == null ? 1 : widths[index];
}

/// Returns the break class of a cluster of a shaped line.
int breakAt(ShapedLine line, int index) {
  final Uint8List? breaks = line.breaks;

  if (breaks != null) {
    return breaks[index];
  }

  return line.text.codeUnitAt(index) == 0x20 ? breakSpace : breakNormal;
}

/// Returns the text of the clusters from [start] to [end].
String textBetween(ShapedLine line, int start, int end) {
  final List<String>? clusters = line.clusters;

  return clusters == null ? line.text.substring(start, end) : clusters.sublist(start, end).join();
}
