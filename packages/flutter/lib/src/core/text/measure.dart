import 'package:lognal/src/core/text/graphemes.dart';
import 'package:lognal/src/core/text/width.dart';

final RegExp _printableAscii = RegExp(r'^[\x20-\x7e]*$');

/// Returns how many cells a string takes on one row.
int measureCells(String text, [AmbiguousWidth ambiguousWidth = 1]) {
  if (_printableAscii.hasMatch(text)) {
    return text.length;
  }

  int cells = 0;

  for (final String cluster in splitGraphemes(text)) {
    cells += clusterWidth(cluster, ambiguousWidth);
  }

  return cells;
}

/// Cuts a string to at most [maxCells] cells, ending it with `…` when anything
/// was cut. A wide character that would cross the limit is left out rather than
/// split.
String truncateCells(String text, int maxCells, [AmbiguousWidth ambiguousWidth = 1]) {
  if (measureCells(text, ambiguousWidth) <= maxCells) {
    return text;
  }

  final StringBuffer result = StringBuffer();
  int cells = 0;

  for (final String cluster in splitGraphemes(text)) {
    final int width = clusterWidth(cluster, ambiguousWidth);

    if (cells + width > maxCells - 1) {
      break;
    }

    result.write(cluster);
    cells += width;
  }

  return '$result…';
}

/// Pads a string with spaces on the right to [cells] cells.
String padCells(String text, int cells, [AmbiguousWidth ambiguousWidth = 1]) {
  final int missing = cells - measureCells(text, ambiguousWidth);

  return missing > 0 ? text + ' ' * missing : text;
}
