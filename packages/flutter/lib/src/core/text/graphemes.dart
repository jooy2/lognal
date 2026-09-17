import 'package:lognal/src/core/text/width.dart';

/// Splits text into user-perceived characters (grapheme clusters).
typedef GraphemeSplitter = List<String> Function(String text);

const int _zeroWidthJoiner = 0x200d;
const int _regionalIndicatorFirst = 0x1f1e6;
const int _regionalIndicatorLast = 0x1f1ff;

bool _isRegionalIndicator(int codePoint) {
  return codePoint >= _regionalIndicatorFirst && codePoint <= _regionalIndicatorLast;
}

bool _isEmojiModifier(int codePoint) {
  return codePoint >= 0x1f3fb && codePoint <= 0x1f3ff;
}

/// A grapheme splitter that needs no platform support.
///
/// It joins combining marks, variation selectors, emoji modifiers, zero width
/// joiner sequences and regional indicator pairs to the character before them.
/// That covers the cases a log line meets in practice; the viewer installs the
/// splitter of `package:characters` over it, which follows the full Unicode
/// text segmentation rules.
List<String> splitGraphemesFallback(String text) {
  final List<String> clusters = <String>[];
  bool joinNext = false;
  int regionalCount = 0;

  for (final int codePoint in text.runes) {
    final String character = String.fromCharCode(codePoint);
    final int last = clusters.length - 1;
    final bool attaches =
        last >= 0 &&
        (joinNext ||
            codePointWidth(codePoint) == 0 ||
            _isEmojiModifier(codePoint) ||
            (_isRegionalIndicator(codePoint) && regionalCount.isOdd));

    if (attaches) {
      clusters[last] += character;
    } else {
      clusters.add(character);
    }

    regionalCount = _isRegionalIndicator(codePoint) ? regionalCount + 1 : 0;
    joinNext = codePoint == _zeroWidthJoiner;
  }

  return clusters;
}

GraphemeSplitter _activeSplitter = splitGraphemesFallback;

/// Replaces the grapheme splitter used by the text layout. Pass `null` to go
/// back to the built-in fallback.
void setGraphemeSplitter(GraphemeSplitter? splitter) {
  _activeSplitter = splitter ?? splitGraphemesFallback;
}

/// Splits text into grapheme clusters with the active splitter.
List<String> splitGraphemes(String text) => _activeSplitter(text);
