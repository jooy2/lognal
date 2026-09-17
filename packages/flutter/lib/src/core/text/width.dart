import 'dart:typed_data';

import 'package:lognal/src/core/text/unicode_width_data.dart';

/// How many cells an East Asian Ambiguous character takes: 1 or 2.
///
/// A terminal that draws Greek, Cyrillic and box-drawing characters one cell
/// wide picks 1, and one that follows an East Asian font picks 2.
typedef AmbiguousWidth = int;

const int _bmpSize = 0x10000;

// Values stored in `_bmpCache`. Zero means the code point has not been looked
// up yet.
const int _cacheZero = 1;
const int _cacheNarrow = 2;
const int _cacheWide = 3;
const int _cacheAmbiguous = 4;

const int _regionalIndicatorFirst = 0x1f1e6;
const int _regionalIndicatorLast = 0x1f1ff;
const int _variationSelectorText = 0xfe0e;
const int _variationSelectorEmoji = 0xfe0f;

final Uint8List _bmpCache = Uint8List(_bmpSize);

bool _isInRanges(List<int> ranges, int codePoint) {
  int low = 0;
  int high = ranges.length ~/ 2 - 1;

  if (high < 0 || codePoint < ranges[0] || codePoint > ranges[ranges.length - 1]) {
    return false;
  }

  while (low <= high) {
    final int middle = (low + high) >> 1;
    final int start = ranges[middle * 2];
    final int end = ranges[middle * 2 + 1];

    if (codePoint < start) {
      high = middle - 1;
    } else if (codePoint > end) {
      low = middle + 1;
    } else {
      return true;
    }
  }

  return false;
}

int _classify(int codePoint) {
  // Box drawing and block elements are ambiguous in the data, but monospace
  // fonts draw them one cell wide, and tables drawn with them only line up
  // that way.
  if (codePoint >= 0x2500 && codePoint <= 0x259f) {
    return _cacheNarrow;
  }

  if (_isInRanges(zeroWidthRanges, codePoint)) {
    return _cacheZero;
  }

  if (_isInRanges(wideRanges, codePoint)) {
    return _cacheWide;
  }

  if (_isInRanges(ambiguousRanges, codePoint)) {
    return _cacheAmbiguous;
  }

  return _cacheNarrow;
}

/// Returns how many cells a single code point takes: 0 for combining marks and
/// format characters, 2 for wide characters, and 1 otherwise.
///
/// Control characters return 1. Callers are expected to replace them with a
/// visible notation before measuring.
int codePointWidth(int codePoint, [AmbiguousWidth ambiguousWidth = 1]) {
  // Printable ASCII and the Latin-1 range before the first ambiguous character.
  if (codePoint < 0xa1) {
    return 1;
  }

  int kind;

  if (codePoint < _bmpSize) {
    kind = _bmpCache[codePoint];

    if (kind == 0) {
      kind = _classify(codePoint);
      _bmpCache[codePoint] = kind;
    }
  } else {
    kind = _classify(codePoint);
  }

  if (kind == _cacheZero) {
    return 0;
  }

  if (kind == _cacheWide) {
    return 2;
  }

  if (kind == _cacheAmbiguous) {
    return ambiguousWidth;
  }

  return 1;
}

/// Returns whether a code point is a Hangul syllable or jamo, where words break
/// at spaces only.
bool isHangul(int codePoint) {
  return (codePoint >= 0xac00 && codePoint <= 0xd7a3) ||
      (codePoint >= 0x1100 && codePoint <= 0x11ff) ||
      (codePoint >= 0x3130 && codePoint <= 0x318f) ||
      (codePoint >= 0xa960 && codePoint <= 0xa97f) ||
      (codePoint >= 0xd7b0 && codePoint <= 0xd7ff);
}

/// Invisible format characters, such as the zero width space, that take no cell
/// even when they stand alone. A combining mark on its own still takes one cell
/// so it stays visible.
bool _isZeroOnly(int codePoint) {
  return codePoint == 0x200b ||
      codePoint == 0x200c ||
      codePoint == 0x200d ||
      codePoint == 0x2060 ||
      codePoint == 0xfeff ||
      codePoint == 0x00ad;
}

/// Returns how many cells a grapheme cluster takes.
///
/// The widest code point decides, with the rules emoji add on top: a cluster
/// with the emoji variation selector or a pair of regional indicators (a flag)
/// is two cells, and one with the text variation selector is one cell.
int clusterWidth(String cluster, [AmbiguousWidth ambiguousWidth = 1]) {
  if (cluster.length == 1) {
    final int code = cluster.codeUnitAt(0);

    if (code < 0xa1) {
      return 1;
    }

    final int width = codePointWidth(code, ambiguousWidth);
    final int floor = _isZeroOnly(code) ? 0 : 1;

    return width > floor ? width : floor;
  }

  int width = 0;
  bool hasEmojiSelector = false;
  bool hasTextSelector = false;
  bool hasRegionalIndicator = false;
  bool hasVisible = false;

  for (final int codePoint in cluster.runes) {
    if (codePoint == _variationSelectorEmoji) {
      hasEmojiSelector = true;
      continue;
    }

    if (codePoint == _variationSelectorText) {
      hasTextSelector = true;
      continue;
    }

    if (codePoint >= _regionalIndicatorFirst && codePoint <= _regionalIndicatorLast) {
      hasRegionalIndicator = true;
    }

    final int codeWidth = codePointWidth(codePoint, ambiguousWidth);

    if (codeWidth > 0 || !_isZeroOnly(codePoint)) {
      hasVisible = true;
    }

    if (codeWidth > width) {
      width = codeWidth;
    }
  }

  if (hasEmojiSelector || hasRegionalIndicator) {
    return 2;
  }

  if (hasTextSelector) {
    return 1;
  }

  if (width == 0) {
    return hasVisible ? 1 : 0;
  }

  return width;
}
