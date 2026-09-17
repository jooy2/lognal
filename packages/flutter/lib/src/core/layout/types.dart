import 'dart:typed_data';

import 'package:lognal/src/core/types.dart';

/// What happens when a span is clicked.
sealed class LineAction {
  /// Lets a subclass declare a `const` constructor.
  const LineAction();
}

/// Opens or closes the captured value at a path of an entry.
class ToggleValueAction extends LineAction {
  /// Creates the action of the expander beside a value.
  const ToggleValueAction(this.path);

  /// Which value, as the index of the part and then of every child.
  final String path;
}

/// Opens or closes a group and the entries inside it.
class ToggleGroupAction extends LineAction {
  /// Creates the action of a group header.
  const ToggleGroupAction();
}

/// Shows or hides the messages that repeat the first entry of a run.
class ToggleRepeatAction extends LineAction {
  /// Creates the action of the count badge of a run.
  const ToggleRepeatAction();
}

/// Opens a web address found in the text.
class OpenLinkAction extends LineAction {
  /// Creates the action of a link.
  const OpenLinkAction(this.url);

  /// The address the link opens.
  final String url;
}

/// One run of a logical line: text, or a drawn symbol.
sealed class LineSpan {
  /// Lets a subclass declare a `const` constructor.
  const LineSpan();

  /// What a click on the span does, if anything.
  LineAction? get action;
}

/// A run of text on a logical line.
class LineTextSpan extends LineSpan {
  /// Creates a run of text.
  const LineTextSpan(this.text, {this.token, this.style, this.action});

  /// The text of the run.
  final String text;

  /// The semantic color of the text.
  final StyleToken? token;

  /// Explicit styling, which wins over [token].
  final LogTextStyle? style;

  @override
  final LineAction? action;

  /// A copy with the fields given here replaced.
  LineTextSpan copyWith({
    String? text,
    StyleToken? token,
    LogTextStyle? style,
    LineAction? action,
  }) {
    return LineTextSpan(
      text ?? this.text,
      token: token ?? this.token,
      style: style ?? this.style,
      action: action ?? this.action,
    );
  }
}

/// A small drawn symbol that takes two cells, such as the triangle that expands
/// a value.
class LineIconSpan extends LineSpan {
  /// Creates the expander triangle.
  const LineIconSpan({required this.expanded, required this.action});

  /// Whether the triangle points down rather than right.
  final bool expanded;

  @override
  final LineAction action;
}

/// One line of an entry before wrapping. An entry has one logical line per line
/// of text, plus one for every visible row of an expanded value.
class LogicalLine {
  /// Creates a logical line.
  LogicalLine({required this.indent, required this.spans, this.wrap = true});

  /// Cells of indentation before the content, repeated on every wrapped row.
  final int indent;

  /// The runs of the line, in order.
  List<LineSpan> spans;

  /// `false` when the line holds a text part that must not wrap.
  final bool wrap;
}

/// How a cluster lets a wrapped row break next to it: no opinion.
const int breakNormal = 0;

/// A space: a row may break after it.
const int breakSpace = 1;

/// A wide character that allows breaks on both sides, such as a Han ideograph.
const int breakWide = 2;

/// A wide character that keeps words together, such as a Hangul syllable.
const int breakKeep = 3;

/// A span after control characters and tabs were replaced for display.
class ShapedSpan {
  /// Creates a shaped run.
  const ShapedSpan(
    this.text, {
    this.token,
    this.style,
    this.action,
    this.icon = false,
    this.expanded = false,
  });

  /// The text of the run, empty for an icon.
  final String text;

  /// The semantic color of the text.
  final StyleToken? token;

  /// Explicit styling, which wins over [token].
  final LogTextStyle? style;

  /// What a click on the run does, if anything.
  final LineAction? action;

  /// Whether the run is the expander triangle rather than text.
  final bool icon;

  /// For an expander, whether it points down rather than right.
  final bool expanded;

  /// A copy with the fields given here replaced.
  ShapedSpan copyWith({String? text, StyleToken? token, LogTextStyle? style}) {
    return ShapedSpan(
      text ?? this.text,
      token: token ?? this.token,
      style: style ?? this.style,
      action: action,
      icon: icon,
      expanded: expanded,
    );
  }
}

/// A logical line split into grapheme clusters, each with its width in cells.
///
/// Most log lines are plain ASCII. Such a line is kept as [text], where every
/// character is one cluster one cell wide, and the per-cluster lists are left
/// out to save memory.
class ShapedLine {
  /// Creates a shaped line. Only the shaper does this.
  ShapedLine({
    required this.indent,
    required this.spans,
    required this.spanStarts,
    required this.simple,
    required this.text,
    required this.clusters,
    required this.widths,
    required this.breaks,
    required this.length,
    required this.cells,
    this.wrap = true,
  });

  /// Cells of indentation before the content.
  final int indent;

  /// The runs of the line, in order.
  final List<ShapedSpan> spans;

  /// The index of the first cluster of every span.
  final Uint32List spanStarts;

  /// Whether every cluster is a single printable ASCII character.
  final bool simple;

  /// The whole line. For a simple line, character `i` is cluster `i`.
  final String text;

  /// The clusters of a line that is not simple.
  final List<String>? clusters;

  /// The width of every cluster of a line that is not simple.
  final Uint8List? widths;

  /// One of the `break*` values for every cluster of a line that is not simple.
  final Uint8List? breaks;

  /// The number of clusters.
  final int length;

  /// Total width in cells, without the indentation.
  final int cells;

  /// Whether the line may wrap. A line that holds a part with `wrap: false`
  /// never does.
  bool wrap;
}

/// How long lines are handled.
enum WrapMode {
  /// Break after a space, or on either side of a wide character.
  word,

  /// Fill every row and break between any two clusters.
  char,

  /// Keep every line on one row and scroll sideways.
  none,
}

/// A run of clusters on one visual row that share a span.
class RowRun {
  /// Creates a run of one row.
  const RowRun({
    required this.column,
    required this.cells,
    required this.text,
    required this.clusters,
    required this.widths,
    required this.simple,
    this.token,
    this.style,
    this.action,
    this.icon = false,
    this.expanded = false,
  });

  /// Column where the run starts, counted from the start of the content area.
  final int column;

  /// Width in cells.
  final int cells;

  /// The text of the run.
  final String text;

  /// The clusters of the run, for runs that must be drawn one cluster at a time.
  final List<String> clusters;

  /// The width of every cluster in [clusters].
  final List<int> widths;

  /// Whether the run is plain ASCII that can be drawn in one call.
  final bool simple;

  /// The semantic color of the text.
  final StyleToken? token;

  /// Explicit styling, which wins over [token].
  final LogTextStyle? style;

  /// What a click on the run does, if anything.
  final LineAction? action;

  /// Whether the run is the expander triangle rather than text.
  final bool icon;

  /// For an expander, whether it points down rather than right.
  final bool expanded;
}

/// One row of the screen.
class VisualRow {
  /// Creates a row. Only the layout does this.
  const VisualRow({
    required this.entry,
    required this.line,
    required this.lineRow,
    required this.entryRow,
    required this.first,
    required this.last,
    required this.indent,
    required this.startCell,
    required this.cells,
    required this.runs,
  });

  /// The entry the row belongs to.
  final LogEntry entry;

  /// Index of the logical line within the entry.
  final int line;

  /// Index of the row within the logical line.
  final int lineRow;

  /// Index of the row within the entry.
  final int entryRow;

  /// Whether this is the first row of the entry.
  final bool first;

  /// Whether this is the last row of the entry.
  final bool last;

  /// Cells of indentation before the first run.
  final int indent;

  /// Cell offset of the row's first cluster within the logical line, without
  /// indentation.
  final int startCell;

  /// Width of the row's content in cells, without indentation.
  final int cells;

  /// The runs of the row, in order.
  final List<RowRun> runs;
}

/// A match of a search in an entry, as a range of cells of a logical line.
class TextMatch {
  /// Creates a match.
  const TextMatch({
    required this.entryId,
    required this.line,
    required this.from,
    required this.to,
  });

  /// The entry the match is in.
  final int entryId;

  /// The logical line the match is on.
  final int line;

  /// The first cell of the match, without indentation.
  final int from;

  /// The cell after the match.
  final int to;
}

/// A position in the text of an entry, stable across wrapping.
///
/// Named for the log rather than for the text, because `TextPosition` is already
/// a name in `dart:ui` and an application that imports both should not have to
/// write a prefix to say which one it means.
class LogPosition {
  /// Creates a position.
  const LogPosition({required this.entryId, required this.line, required this.cell});

  /// The entry the position is in.
  final int entryId;

  /// The logical line the position is on.
  final int line;

  /// Cell offset within the logical line, without indentation.
  final int cell;
}
