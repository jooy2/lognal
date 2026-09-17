/// Composes text into Unicode normalization form C.
///
/// The filter and the search compare text this way, so that decomposed Hangul —
/// what a macOS file name carries, and what some keyboards produce — matches
/// what a reader types. On the JavaScript side the runtime's own
/// `String.normalize` does this; Dart has no such call, so the composition step
/// is written here over the table `normalize_data.dart` carries.
///
/// Only the composition step runs. Text that is already composed comes back
/// unchanged, and text that is decomposed is composed. A singleton or a
/// compatibility mapping is left alone, which is the difference between this and
/// a complete normalizer, and it is not a difference any log line has.
library;

import 'package:lognal/src/core/text/normalize_data.dart';

const int _hangulSBase = 0xac00;
const int _hangulLBase = 0x1100;
const int _hangulVBase = 0x1161;
const int _hangulTBase = 0x11a7;
const int _hangulLCount = 19;
const int _hangulVCount = 21;
const int _hangulTCount = 28;
const int _hangulNCount = _hangulVCount * _hangulTCount;
const int _hangulSCount = _hangulLCount * _hangulNCount;

/// The lowest code point that can carry a canonical combining class, so text
/// below it is composed already.
const int _firstCombining = 0x0300;

/// Returns the canonical combining class of a code point, or 0.
int combiningClassOf(int codePoint) {
  if (codePoint < _firstCombining) {
    return 0;
  }

  int low = 0;
  int high = combiningClassRanges.length ~/ 3 - 1;

  while (low <= high) {
    final int middle = (low + high) >> 1;
    final int start = combiningClassRanges[middle * 3];
    final int end = combiningClassRanges[middle * 3 + 1];

    if (codePoint < start) {
      high = middle - 1;
    } else if (codePoint > end) {
      low = middle + 1;
    } else {
      return combiningClassRanges[middle * 3 + 2];
    }
  }

  return 0;
}

/// Composes a Hangul pair by the algorithm in the standard, which needs no data.
int? _composeHangul(int starter, int mark) {
  final int leading = starter - _hangulLBase;

  if (leading >= 0 && leading < _hangulLCount) {
    final int vowel = mark - _hangulVBase;

    if (vowel >= 0 && vowel < _hangulVCount) {
      return _hangulSBase + (leading * _hangulVCount + vowel) * _hangulTCount;
    }
  }

  final int syllable = starter - _hangulSBase;

  if (syllable >= 0 && syllable < _hangulSCount && syllable % _hangulTCount == 0) {
    final int trailing = mark - _hangulTBase;

    if (trailing > 0 && trailing < _hangulTCount) {
      return starter + trailing;
    }
  }

  return null;
}

/// Returns the primary composite of a starter and the character after it, or
/// `null` when the pair does not compose.
int? composePair(int starter, int mark) {
  final int? hangul = _composeHangul(starter, mark);

  if (hangul != null) {
    return hangul;
  }

  int low = 0;
  int high = compositionPairs.length ~/ 3 - 1;

  while (low <= high) {
    final int middle = (low + high) >> 1;
    final int first = compositionPairs[middle * 3];
    final int second = compositionPairs[middle * 3 + 1];

    if (first < starter || (first == starter && second < mark)) {
      low = middle + 1;
    } else if (first > starter || second > mark) {
      high = middle - 1;
    } else {
      return compositionPairs[middle * 3 + 2];
    }
  }

  return null;
}

/// Whether text can hold anything that composes: a combining mark, or a Hangul
/// jamo. Log text is usually neither, and the walk below is skipped for it.
bool _mayCompose(String text) {
  for (int index = 0; index < text.length; index++) {
    if (text.codeUnitAt(index) >= _firstCombining) {
      return true;
    }
  }

  return false;
}

/// Returns [text] in Unicode normalization form C.
String normalizeNfc(String text) {
  if (!_mayCompose(text)) {
    return text;
  }

  final List<int> result = <int>[];
  int starterIndex = -1;

  // The combining class of the last code point appended after the starter, and
  // -1 while nothing stands between the starter and the next code point.
  int lastClass = -1;

  for (final int codePoint in text.runes) {
    final int combiningClass = combiningClassOf(codePoint);

    if (starterIndex >= 0 && lastClass < combiningClass) {
      final int? composite = composePair(result[starterIndex], codePoint);

      if (composite != null) {
        result[starterIndex] = composite;
        continue;
      }
    }

    if (combiningClass == 0) {
      starterIndex = result.length;
      lastClass = -1;
    } else {
      lastClass = combiningClass;
    }

    result.add(codePoint);
  }

  return String.fromCharCodes(result);
}
