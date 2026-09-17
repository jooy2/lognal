import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/renderer/palette.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/theme/palettes.dart';

/// How many laid-out pieces of text stay cached.
const int _paragraphCacheSize = 4096;

final RegExp _whitespace = RegExp(r'^\s*$');

/// Box-drawing characters drawn as lines, as bits for the arms that leave the
/// cell center: up, right, down and left.
///
/// Drawing them lets table borders join across rows, which a font glyph does not
/// do once rows are taller than the font.
const int _armUp = 1;
const int _armRight = 2;
const int _armDown = 4;
const int _armLeft = 8;
const Map<String, int> _boxArms = <String, int>{
  '─': _armLeft | _armRight,
  '│': _armUp | _armDown,
  '┌': _armRight | _armDown,
  '┐': _armLeft | _armDown,
  '└': _armUp | _armRight,
  '┘': _armUp | _armLeft,
  '├': _armUp | _armDown | _armRight,
  '┤': _armUp | _armDown | _armLeft,
  '┬': _armLeft | _armRight | _armDown,
  '┴': _armLeft | _armRight | _armUp,
  '┼': _armUp | _armRight | _armDown | _armLeft,
  '╭': _armRight | _armDown,
  '╮': _armLeft | _armDown,
  '╯': _armUp | _armLeft,
  '╰': _armUp | _armRight,
};

class _ParagraphKey {
  const _ParagraphKey(this.text, this.color, this.bold, this.italic, this.size);

  final String text;
  final int color;
  final bool bold;
  final bool italic;
  final double size;

  @override
  bool operator ==(Object other) {
    return other is _ParagraphKey &&
        other.text == text &&
        other.color == color &&
        other.bold == bold &&
        other.italic == italic &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(text, color, bold, italic, size);
}

/// Draws the log onto a canvas.
///
/// Every frame repaints the visible rows. Text that is plain ASCII in one style
/// is laid out and drawn as one piece; other text is drawn one grapheme cluster
/// at a time at its grid position, so wide characters and characters from a
/// fallback font stay aligned. A cluster wider than its cells is squeezed into
/// them instead of overlapping the next one.
class CanvasLogRenderer extends LogRenderer {
  /// Creates a renderer.
  CanvasLogRenderer();

  RenderTheme _theme = darkTheme.renderer;
  FontSettings _font = const FontSettings();
  CellMetrics _metrics = const CellMetrics(width: 8, height: 20, baseline: 14);
  final LinkedHashMap<_ParagraphKey, ui.Paragraph> _paragraphs =
      LinkedHashMap<_ParagraphKey, ui.Paragraph>();

  @override
  set theme(RenderTheme theme) {
    if (theme != _theme) {
      _theme = theme;
      _paragraphs.clear();
    }
  }

  /// The palette in use.
  RenderTheme get theme => _theme;

  /// The font in use.
  FontSettings get font => _font;

  @override
  CellMetrics get metrics => _metrics;

  @override
  CellMetrics setFont(FontSettings font) {
    _font = font;
    _paragraphs.clear();

    // Twenty of the widest ASCII letter, divided again: one character is too
    // small a distance to measure a fractional advance from.
    final ui.Paragraph sample = _layout('M' * 20, const Color(0xffffffff), false, false);
    final double width = sample.maxIntrinsicWidth / 20;
    final double height = math.max(1, (font.size * font.lineHeight).roundToDouble());

    _metrics = CellMetrics(
      width: width > 0 ? width : font.size * 0.6,
      height: height,
      baseline: ((height - sample.height) / 2 + sample.alphabeticBaseline).roundToDouble(),
    );

    return _metrics;
  }

  @override
  void paint(Canvas canvas, Size size, RenderFrame frame) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;
    final double gutterWidth = (frame.timestampCells + frame.markerCells) * cellWidth;
    final double contentLeft = frame.paddingLeft + gutterWidth;

    // The first row on screen usually starts above the top of it, because the
    // log scrolls by the pixel rather than by the row, and the last one runs
    // past the bottom. A canvas in a browser is a box of its own and cuts them
    // off; this canvas is the application's, and a row drawn past the edge
    // lands on whatever the viewer put there — the toolbar above, the input
    // line below. So the renderer cuts them off itself.
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _theme.background,
    );

    for (int index = 0; index < frame.rows.length; index++) {
      _drawRowBackground(
        canvas,
        size,
        frame.rows[index],
        frame.decorations[index],
        frame.offsetY + index * rowHeight,
      );
    }

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(contentLeft, 0, math.max(0, size.width - contentLeft), size.height));

    for (int index = 0; index < frame.rows.length; index++) {
      final double top = frame.offsetY + index * rowHeight;
      final double left = contentLeft - frame.scrollX;

      _drawDecoration(canvas, frame.decorations[index], left, top);
      _drawRuns(canvas, size, frame.rows[index], left, top);
    }

    canvas.restore();

    for (int index = 0; index < frame.rows.length; index++) {
      final VisualRow row = frame.rows[index];
      final double top = frame.offsetY + index * rowHeight;

      if (row.last) {
        canvas.drawRect(
          Rect.fromLTWH(0, top + rowHeight - 1, size.width, 1),
          Paint()..color = _theme.separator,
        );
      }

      if (row.first) {
        _drawGutter(canvas, row.entry, frame, top);
      }

      if (frame.decorations[index].entryFocused) {
        _drawEntryFocus(canvas, size, row, top);
      }
    }

    canvas.restore();
  }

  @override
  void dispose() => _paragraphs.clear();

  ui.Paragraph _layout(String text, Color color, bool bold, bool italic) {
    final _ParagraphKey key = _ParagraphKey(text, color.toARGB32(), bold, italic, _font.size);
    final ui.Paragraph? cached = _paragraphs[key];

    if (cached != null) {
      _paragraphs
        ..remove(key)
        ..[key] = cached;

      return cached;
    }

    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: _font.family,
            fontSize: _font.size,
            fontWeight: bold ? _boldWeight(_font.weight) : _font.weight,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            textAlign: TextAlign.left,
            maxLines: 1,
          ),
        )..pushStyle(
          ui.TextStyle(
            color: color,
            fontFamily: _font.family,
            fontFamilyFallback: _font.fallbackFamilies,
            fontSize: _font.size,
            fontWeight: bold ? _boldWeight(_font.weight) : _font.weight,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        );

    builder.addText(text);

    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    if (_paragraphs.length >= _paragraphCacheSize) {
      _paragraphs.remove(_paragraphs.keys.first);
    }

    _paragraphs[key] = paragraph;

    return paragraph;
  }

  static FontWeight _boldWeight(FontWeight weight) {
    return weight.value >= FontWeight.w700.value ? weight : FontWeight.w700;
  }

  void _drawRowBackground(
    Canvas canvas,
    Size size,
    VisualRow row,
    RowDecoration decoration,
    double top,
  ) {
    final Rect rect = Rect.fromLTWH(0, top, size.width, _metrics.height);

    if (row.entry.level == LogLevel.error) {
      canvas.drawRect(rect, Paint()..color = _theme.errorBackground);
    } else if (row.entry.level == LogLevel.warn) {
      canvas.drawRect(rect, Paint()..color = _theme.warnBackground);
    }

    if (decoration.entrySelected) {
      canvas.drawRect(rect, Paint()..color = _theme.entrySelection);
    }

    // The hover color is translucent, so it also shows on the background of a
    // warning or an error.
    if (decoration.hovered) {
      canvas.drawRect(rect, Paint()..color = _theme.hover);
    }
  }

  /// Draws the part of the outline of the focused entry that falls on one of its
  /// rows.
  void _drawEntryFocus(Canvas canvas, Size size, VisualRow row, double top) {
    final double height = _metrics.height;
    const double thickness = 2;
    final Paint paint = Paint()..color = _theme.focusRing;

    canvas
      ..drawRect(Rect.fromLTWH(0, top, thickness, height), paint)
      ..drawRect(Rect.fromLTWH(size.width - thickness, top, thickness, height), paint);

    if (row.first) {
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, thickness), paint);
    }

    if (row.last) {
      canvas.drawRect(Rect.fromLTWH(0, top + height - thickness, size.width, thickness), paint);
    }
  }

  void _drawDecoration(Canvas canvas, RowDecoration decoration, double left, double top) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;

    void band(List<int> range, Color color) {
      final double from = range[0] * cellWidth;
      final double width = math.max(0, range[1] - range[0]) * cellWidth;

      canvas.drawRect(Rect.fromLTWH(left + from, top, width, rowHeight), Paint()..color = color);
    }

    for (final List<int> range in decoration.matches) {
      band(range, _theme.match);
    }

    for (final List<int> range in decoration.searchMatches) {
      band(range, _theme.searchMatch);
    }

    final List<int>? current = decoration.searchCurrent;

    if (current != null) {
      band(current, _theme.searchCurrent);
    }

    final List<int>? selection = decoration.selection;

    if (selection != null) {
      band(selection, _theme.selection);
    }
  }

  Color _colorOf(RowRun run, LogEntry entry) {
    final TextColor? color = run.style?.color;

    if (color != null) {
      return resolveTextColor(color, _theme.ansi);
    }

    final StyleToken? token = run.token;

    if (token != null && token != StyleToken.defaultToken) {
      return _theme.tokenColor(token);
    }

    if (entry.kind == LogKind.system) {
      return _theme.muted;
    }

    return switch (entry.level) {
      LogLevel.debug => _theme.debug,
      LogLevel.error => _theme.error,
      LogLevel.warn => _theme.warn,
      _ => _theme.foreground,
    };
  }

  void _drawRuns(Canvas canvas, Size size, VisualRow row, double left, double top) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;

    for (final RowRun run in row.runs) {
      final double x = left + run.column * cellWidth;
      final double runWidth = run.cells * cellWidth;

      if (x > size.width || x + runWidth < 0) {
        continue;
      }

      final LogTextStyle? style = run.style;
      final TextColor? background = style?.background;

      if (background != null) {
        canvas.drawRect(
          Rect.fromLTWH(x, top, runWidth, rowHeight),
          Paint()..color = resolveTextColor(background, _theme.ansi),
        );
      }

      if (run.icon) {
        _drawExpander(canvas, x, top, run.expanded);
        continue;
      }

      if (_whitespace.hasMatch(run.text)) {
        continue;
      }

      // A link takes the link color, unless its text was given a color of its
      // own.
      final bool isLink = run.action is OpenLinkAction;
      final Color color = isLink && style?.color == null ? _theme.link : _colorOf(run, row.entry);
      final Color drawn = (style?.dim ?? false) ? color.withValues(alpha: 0.6) : color;
      final bool bold = style?.bold ?? false;
      final bool italic = style?.italic ?? false;

      if (run.simple) {
        canvas.drawParagraph(_layout(run.text, drawn, bold, italic), Offset(x, top));
      } else {
        double clusterLeft = x;

        for (int index = 0; index < run.clusters.length; index++) {
          final String cluster = run.clusters[index];
          final int cells = index < run.widths.length ? run.widths[index] : 1;
          final double slot = cells * cellWidth;
          final int? arms = _boxArms[cluster];

          if (arms != null) {
            _drawBox(canvas, arms, clusterLeft, top, drawn);
          } else if (cluster.isNotEmpty && !_whitespace.hasMatch(cluster)) {
            final ui.Paragraph paragraph = _layout(cluster, drawn, bold, italic);
            final double natural = paragraph.maxIntrinsicWidth;
            final double offset = cells > 1 && natural < slot ? (slot - natural) / 2 : 0;

            canvas.drawParagraph(paragraph, Offset(clusterLeft + offset, top));
          }

          clusterLeft += slot;
        }
      }

      if ((style?.underline ?? false) || isLink) {
        canvas.drawRect(
          Rect.fromLTWH(x, top + _metrics.baseline + 2, runWidth, 1),
          Paint()..color = drawn,
        );
      }

      if (style?.strikethrough ?? false) {
        canvas.drawRect(
          Rect.fromLTWH(x, top + (rowHeight / 2).roundToDouble(), runWidth, 1),
          Paint()..color = drawn,
        );
      }
    }
  }

  void _drawBox(Canvas canvas, int arms, double left, double top, Color color) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;
    final double thickness = math.max(1, (_font.size / 13).roundToDouble());
    final double centerX = (left + cellWidth / 2 - thickness / 2).roundToDouble();
    final double centerY = (top + rowHeight / 2 - thickness / 2).roundToDouble();
    final double right = left + cellWidth;
    final double bottom = top + rowHeight;
    final Paint paint = Paint()..color = color;

    if (arms & _armLeft != 0) {
      canvas.drawRect(Rect.fromLTWH(left, centerY, centerX + thickness - left, thickness), paint);
    }

    if (arms & _armRight != 0) {
      canvas.drawRect(Rect.fromLTWH(centerX, centerY, right - centerX, thickness), paint);
    }

    if (arms & _armUp != 0) {
      canvas.drawRect(Rect.fromLTWH(centerX, top, thickness, centerY + thickness - top), paint);
    }

    if (arms & _armDown != 0) {
      canvas.drawRect(Rect.fromLTWH(centerX, centerY, thickness, bottom - centerY), paint);
    }
  }

  void _drawExpander(Canvas canvas, double x, double top, bool expanded) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;
    final double size = math.max(4, (_font.size * 0.36).roundToDouble());
    final double centerX = x + cellWidth * 0.9;
    final double centerY = top + rowHeight / 2;
    final Path path = Path();

    if (expanded) {
      path
        ..moveTo(centerX - size / 2, centerY - size / 4)
        ..lineTo(centerX + size / 2, centerY - size / 4)
        ..lineTo(centerX, centerY + size / 3);
    } else {
      path
        ..moveTo(centerX - size / 4, centerY - size / 2)
        ..lineTo(centerX + size / 3, centerY)
        ..lineTo(centerX - size / 4, centerY + size / 2);
    }

    path.close();
    canvas.drawPath(path, Paint()..color = _theme.muted);
  }

  void _drawGutter(Canvas canvas, LogEntry entry, RenderFrame frame, double top) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;
    double x = frame.paddingLeft;

    if (frame.timestampCells > 0) {
      canvas.drawParagraph(
        _layout(frame.formatTime(entry.time), _theme.muted, false, false),
        Offset(x, top),
      );
      x += frame.timestampCells * cellWidth;
    }

    // The marker sits in the first two cells of its column; the last cell is a
    // gap.
    final double centerX = x + cellWidth;
    final double centerY = top + rowHeight / 2;
    final double radius = math.max(3, _font.size * 0.32);

    if (entry.repeat > 1) {
      _drawRepeatBadge(canvas, entry, x, top);

      return;
    }

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, _font.size / 12)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (entry.kind == LogKind.input) {
      canvas.drawPath(
        Path()
          ..moveTo(centerX - radius * 0.45, centerY - radius * 0.8)
          ..lineTo(centerX + radius * 0.45, centerY)
          ..lineTo(centerX - radius * 0.45, centerY + radius * 0.8),
        stroke..color = _theme.accent,
      );

      return;
    }

    if (entry.kind == LogKind.output) {
      canvas.drawPath(
        Path()
          ..moveTo(centerX + radius * 0.45, centerY - radius * 0.8)
          ..lineTo(centerX - radius * 0.45, centerY)
          ..lineTo(centerX + radius * 0.45, centerY + radius * 0.8),
        stroke..color = _theme.muted,
      );

      return;
    }

    if (entry.level == LogLevel.error) {
      canvas
        ..drawCircle(Offset(centerX, centerY), radius, Paint()..color = _theme.error)
        ..drawPath(
          Path()
            ..moveTo(centerX - radius * 0.4, centerY - radius * 0.4)
            ..lineTo(centerX + radius * 0.4, centerY + radius * 0.4)
            ..moveTo(centerX + radius * 0.4, centerY - radius * 0.4)
            ..lineTo(centerX - radius * 0.4, centerY + radius * 0.4),
          stroke..color = _theme.background,
        );
    } else if (entry.level == LogLevel.warn) {
      final double bar = stroke.strokeWidth;

      canvas
        ..drawPath(
          Path()
            ..moveTo(centerX, centerY - radius * 1.05)
            ..lineTo(centerX + radius * 1.1, centerY + radius * 0.85)
            ..lineTo(centerX - radius * 1.1, centerY + radius * 0.85)
            ..close(),
          Paint()..color = _theme.warn,
        )
        ..drawRect(
          Rect.fromLTWH(centerX - bar / 2, centerY - radius * 0.45, bar, radius * 0.7),
          Paint()..color = _theme.background,
        )
        ..drawRect(
          Rect.fromLTWH(centerX - bar / 2, centerY + radius * 0.4, bar, bar),
          Paint()..color = _theme.background,
        );
    } else if (entry.level == LogLevel.info) {
      canvas.drawCircle(Offset(centerX, centerY), radius * 0.55, Paint()..color = _theme.info);
    }
  }

  void _drawRepeatBadge(Canvas canvas, LogEntry entry, double x, double top) {
    final double cellWidth = _metrics.width;
    final double rowHeight = _metrics.height;
    final String label = entry.repeat > 99 ? '99+' : '${entry.repeat}';
    final double fontSize = math.max(8, (_font.size * 0.75).roundToDouble());
    final double badgeHeight = math.min(rowHeight - 4, fontSize + 4);
    final Color color = switch (entry.level) {
      LogLevel.error => _theme.error,
      LogLevel.warn => _theme.warn,
      _ => _theme.muted,
    };
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: _font.family,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        )..pushStyle(
          ui.TextStyle(
            color: _theme.background,
            fontFamily: _font.family,
            fontFamilyFallback: _font.fallbackFamilies,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        );

    builder.addText(label);

    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    final double badgeWidth = math.max(badgeHeight, paragraph.maxIntrinsicWidth + 8);
    final double left = x + math.max(0, cellWidth - badgeWidth / 2);
    final double badgeTop = top + (rowHeight - badgeHeight) / 2;

    paragraph.layout(ui.ParagraphConstraints(width: badgeWidth));
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, badgeTop, badgeWidth, badgeHeight),
          Radius.circular(badgeHeight / 2),
        ),
        Paint()..color = color,
      )
      ..drawParagraph(paragraph, Offset(left, badgeTop + (badgeHeight - paragraph.height) / 2));
  }
}
