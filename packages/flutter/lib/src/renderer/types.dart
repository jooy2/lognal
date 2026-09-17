import 'dart:ui';

import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/types.dart';

/// The font the log text is drawn with. Only monospace fonts line up on the
/// grid.
class FontSettings {
  /// Creates the font settings.
  const FontSettings({
    this.family,
    this.fallbackFamilies = const <String>[],
    this.size = 13,
    this.weight = FontWeight.w400,
    this.lineHeight = 1.6,
  });

  /// The font family, or `null` for the platform's own monospace font.
  final String? family;

  /// The families a character the chosen font lacks falls back to, such as a
  /// Korean monospace face for Hangul.
  final List<String> fallbackFamilies;

  /// Font size in logical pixels.
  final double size;

  /// Font weight of regular text.
  final FontWeight weight;

  /// Row height as a multiple of the font size.
  final double lineHeight;

  /// A copy with the fields given here replaced.
  FontSettings copyWith({
    String? family,
    List<String>? fallbackFamilies,
    double? size,
    FontWeight? weight,
    double? lineHeight,
  }) {
    return FontSettings(
      family: family ?? this.family,
      fallbackFamilies: fallbackFamilies ?? this.fallbackFamilies,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FontSettings &&
        other.family == family &&
        other.size == size &&
        other.weight == weight &&
        other.lineHeight == lineHeight &&
        other.fallbackFamilies.length == fallbackFamilies.length &&
        other.fallbackFamilies.every(fallbackFamilies.contains);
  }

  @override
  int get hashCode {
    return Object.hash(family, size, weight, lineHeight, Object.hashAll(fallbackFamilies));
  }
}

/// The size of one cell of the text grid, in logical pixels.
class CellMetrics {
  /// Creates the metrics.
  const CellMetrics({required this.width, required this.height, required this.baseline});

  /// The width of one cell.
  final double width;

  /// The height of one row.
  final double height;

  /// Distance from the top of a row to the text baseline.
  final double baseline;

  @override
  bool operator ==(Object other) {
    return other is CellMetrics &&
        other.width == width &&
        other.height == height &&
        other.baseline == baseline;
  }

  @override
  int get hashCode => Object.hash(width, height, baseline);
}

/// Colors the renderer draws with.
class RenderTheme {
  /// Creates a palette.
  const RenderTheme({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.accent,
    required this.selection,
    required this.match,
    required this.separator,
    required this.hover,
    required this.searchMatch,
    required this.searchCurrent,
    required this.link,
    required this.entrySelection,
    required this.focusRing,
    required this.error,
    required this.errorBackground,
    required this.warn,
    required this.warnBackground,
    required this.info,
    required this.debug,
    required this.tokens,
    required this.ansi,
  });

  /// The color behind the log.
  final Color background;

  /// The color of ordinary text.
  final Color foreground;

  /// Text that is there but is not the point.
  final Color muted;

  /// The viewer's accent color.
  final Color accent;

  /// The highlight of selected text.
  final Color selection;

  /// The highlight of every match of the text filter.
  final Color match;

  /// The line between two entries.
  final Color separator;

  /// The background of the rows of the entry under the pointer.
  final Color hover;

  /// The highlight of every match of a search.
  final Color searchMatch;

  /// The highlight of the current match of a search.
  final Color searchCurrent;

  /// The text of a link, unless the text has a color of its own.
  final Color link;

  /// The background of the rows of an entry selected in entry mode.
  final Color entrySelection;

  /// The outline of the entry the keyboard moves from in entry mode.
  final Color focusRing;

  /// The color of an error.
  final Color error;

  /// The background of the rows of an error.
  final Color errorBackground;

  /// The color of a warning.
  final Color warn;

  /// The background of the rows of a warning.
  final Color warnBackground;

  /// The color of a notice.
  final Color info;

  /// The color of a debug message.
  final Color debug;

  /// The color of every semantic token.
  final Map<StyleToken, Color> tokens;

  /// The 16 ANSI colors: black, red, green, yellow, blue, magenta, cyan, white,
  /// then bright.
  final List<Color> ansi;

  /// The color of a token, or [foreground] where the palette names none.
  Color tokenColor(StyleToken token) => tokens[token] ?? foreground;
}

/// Highlights on one row, as ranges of columns of the content area.
class RowDecoration {
  /// Creates the decorations of one row.
  const RowDecoration({
    this.selection,
    this.matches = const <List<int>>[],
    this.hovered = false,
    this.searchMatches = const <List<int>>[],
    this.searchCurrent,
    this.entrySelected = false,
    this.entryFocused = false,
  });

  /// The columns of the selected text on this row.
  final List<int>? selection;

  /// The columns of the matches of the text filter.
  final List<List<int>> matches;

  /// Whether the row belongs to the entry under the pointer, or to the entry
  /// whose menu is open.
  final bool hovered;

  /// The columns of the matches of a search, other than the current match.
  final List<List<int>> searchMatches;

  /// The columns of the current match of a search, on the rows that show it.
  final List<int>? searchCurrent;

  /// Whether the row belongs to an entry selected in entry mode.
  final bool entrySelected;

  /// Whether the row belongs to the entry the keyboard moves from in entry mode.
  final bool entryFocused;
}

/// Everything needed to draw one frame.
class RenderFrame {
  /// Creates a frame.
  const RenderFrame({
    required this.rows,
    required this.decorations,
    required this.offsetY,
    required this.scrollX,
    required this.paddingLeft,
    required this.timestampCells,
    required this.markerCells,
    required this.formatTime,
  });

  /// The rows on screen, top first.
  final List<VisualRow> rows;

  /// One entry per row of [rows].
  final List<RowDecoration> decorations;

  /// Vertical offset of the first row in logical pixels, zero or negative.
  final double offsetY;

  /// Horizontal scroll of the content area in logical pixels.
  final double scrollX;

  /// Space before the gutter in logical pixels.
  final double paddingLeft;

  /// Cells taken by the timestamp column, or 0 when timestamps are hidden.
  final int timestampCells;

  /// Cells taken by the level marker column.
  final int markerCells;

  /// Formats the time of an entry for the timestamp column.
  final String Function(DateTime time) formatTime;
}

/// Draws frames of the log.
///
/// The viewer owns the layout, scrolling and input; a renderer only turns a
/// frame into pixels, so a different drawing technology can take its place.
abstract class LogRenderer {
  /// Lets a subclass declare a `const` constructor.
  const LogRenderer();

  /// The palette to draw with.
  set theme(RenderTheme theme);

  /// Sets the font and returns the size of a cell.
  CellMetrics setFont(FontSettings font);

  /// The size of a cell with the current font.
  CellMetrics get metrics;

  /// Draws a frame onto a canvas of the given size.
  void paint(Canvas canvas, Size size, RenderFrame frame);

  /// Releases what the renderer cached.
  void dispose();
}
