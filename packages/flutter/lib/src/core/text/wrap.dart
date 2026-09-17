import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/shape.dart';

/// Returns the index of the first cluster of every row a line wraps into.
///
/// - [WrapMode.none] keeps the line on one row.
/// - [WrapMode.char] fills every row and breaks between any two clusters.
/// - [WrapMode.word] breaks after a space, or on either side of a wide
///   character such as a Han ideograph. Hangul syllables keep words together,
///   so Korean text breaks at spaces. A word longer than the row is broken
///   between characters.
///
/// A space that does not fit at the end of a row hangs past the edge, so a row
/// never starts with the space that ended the word before it.
List<int> wrapLine(ShapedLine line, int columns, WrapMode mode) {
  final int count = line.length;

  if (mode == WrapMode.none || count == 0 || line.cells <= columns) {
    return <int>[0];
  }

  final int width = columns > 1 ? columns : 1;
  final bool isWord = mode == WrapMode.word;

  if (line.simple) {
    return _wrapAscii(line.text, width, isWord);
  }

  final List<int> rows = <int>[0];
  int rowStart = 0;
  int rowCells = 0;
  int breakIndex = -1;

  for (int index = 0; index < count; index++) {
    final int clusterCells = widthAt(line, index);
    final int breakClass = breakAt(line, index);

    if (isWord && index > rowStart) {
      final int previous = breakAt(line, index - 1);

      if ((previous == breakSpace && breakClass != breakSpace) ||
          previous == breakWide ||
          breakClass == breakWide) {
        breakIndex = index;
      }
    }

    if (rowCells > 0 && rowCells + clusterCells > width) {
      if (breakClass == breakSpace) {
        rowCells += clusterCells;
        continue;
      }

      final int start = isWord && breakIndex > rowStart ? breakIndex : index;

      rows.add(start);
      rowStart = start;
      rowCells = 0;
      breakIndex = -1;

      for (int cluster = start; cluster < index; cluster++) {
        rowCells += widthAt(line, cluster);
      }

      // The carried-over part of a word can still leave no room for a wide
      // character.
      if (rowCells > 0 && rowCells + clusterCells > width) {
        rows.add(index);
        rowStart = index;
        rowCells = 0;
      }
    }

    rowCells += clusterCells;
  }

  return rows;
}

/// [wrapLine] for a line where every character is one cell and only spaces allow
/// a break. It follows the same rules without looking up widths and break
/// classes, which makes laying out a large plain-text log several times faster.
List<int> _wrapAscii(String text, int width, bool isWord) {
  final List<int> rows = <int>[0];
  final int count = text.length;
  int rowStart = 0;
  int rowCells = 0;
  int breakIndex = -1;

  for (int index = 0; index < count; index++) {
    final bool isSpace = text.codeUnitAt(index) == 0x20;

    if (isWord && index > rowStart && !isSpace && text.codeUnitAt(index - 1) == 0x20) {
      breakIndex = index;
    }

    if (rowCells > 0 && rowCells + 1 > width) {
      if (isSpace) {
        rowCells++;
        continue;
      }

      final int start = isWord && breakIndex > rowStart ? breakIndex : index;

      rows.add(start);
      rowStart = start;
      rowCells = index - start;
      breakIndex = -1;
    }

    rowCells++;
  }

  return rows;
}
