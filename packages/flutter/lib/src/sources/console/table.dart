import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/measure.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/preview.dart';

/// The most rows and columns a table shows, and the widest cell.
const int _maxRows = 100;
const int _maxColumns = 20;
const int _maxCellCells = 40;

const String _indexColumn = '(index)';
const String _valuesColumn = 'Values';

String _cellText(ValueNode node) {
  return previewValue(node, true).map((LineTextSpan span) => span.text).join();
}

String _keyText(ValueEntry entry) {
  final ValueNode? keyValue = entry.keyValue;

  return keyValue != null ? _cellText(keyValue) : entry.key ?? '';
}

bool _isRowObject(ValueNode node) {
  return (node.kind == ValueKind.object || node.kind == ValueKind.list) && node.children != null;
}

/// Draws a captured value as a text table with box-drawing characters: one row
/// per property or item, one column per key of the row values, and a `Values`
/// column for rows that are not objects.
///
/// Returns `null` when the value has no rows, in which case the caller logs it
/// as usual.
String? formatTable(ValueNode node, [List<String>? properties]) {
  final List<ValueEntry>? children = node.children;

  if (children == null || children.isEmpty) {
    return null;
  }

  final List<ValueEntry> rows = children.take(_maxRows).toList();
  final List<String> columns = <String>[];
  bool hasValues = false;

  for (final ValueEntry row in rows) {
    if (_isRowObject(row.value)) {
      for (final ValueEntry child in row.value.children ?? <ValueEntry>[]) {
        final String key = child.key ?? '';

        if (!columns.contains(key) && columns.length < _maxColumns) {
          columns.add(key);
        }
      }
    } else {
      hasValues = true;
    }
  }

  final List<String> shownColumns = properties == null
      ? columns
      : properties.where(columns.contains).toList();
  final List<String> header = <String>[
    _indexColumn,
    ...shownColumns,
    if (hasValues && properties == null) _valuesColumn,
  ];
  final List<List<String>> body = rows.map((ValueEntry row) {
    final List<String> cells = <String>[_keyText(row)];
    final List<ValueEntry> children = _isRowObject(row.value)
        ? row.value.children ?? <ValueEntry>[]
        : <ValueEntry>[];

    for (final String key in shownColumns) {
      final Iterable<ValueEntry> found = children.where((ValueEntry item) => item.key == key);

      cells.add(found.isEmpty ? '' : _cellText(found.first.value));
    }

    if (hasValues && properties == null) {
      cells.add(_isRowObject(row.value) ? '' : _cellText(row.value));
    }

    return cells.map((String cell) => truncateCells(cell, _maxCellCells)).toList();
  }).toList();
  final List<int> widths = List<int>.generate(header.length, (int column) {
    int width = measureCells(header[column]);

    for (final List<String> cells in body) {
      final int cellWidth = measureCells(cells[column]);

      if (cellWidth > width) {
        width = cellWidth;
      }
    }

    return width;
  });

  String line(String left, String middle, String right) {
    final String body = widths.map((int width) => '─' * (width + 2)).join(middle);

    return '$left$body$right';
  }

  String row(List<String> cells) {
    final String body = List<String>.generate(
      cells.length,
      (int column) => ' ${padCells(cells[column], widths[column])} ',
    ).join('│');

    return '│$body│';
  }

  final List<String> lines = <String>[
    line('┌', '┬', '┐'),
    row(header),
    line('├', '┼', '┤'),
    ...body.map(row),
    line('└', '┴', '┘'),
  ];
  final int hidden = children.length - rows.length + node.omitted;

  if (hidden > 0) {
    lines.add('… $hidden more');
  }

  return lines.join('\n');
}
