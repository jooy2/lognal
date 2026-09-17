import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/src/theme/palettes.dart';

/// The viewer's own scrollbar, drawn over the log rather than beside it.
///
/// It is written here rather than taken from the framework because the log does
/// not scroll through a [ScrollView]: the rows are painted straight onto a
/// canvas from an offset the controller holds, so there is no scroll position
/// for a [Scrollbar] to attach to.
class LognalScrollbar extends StatefulWidget {
  /// Creates a scrollbar.
  const LognalScrollbar({
    required this.theme,
    required this.axis,
    required this.offset,
    required this.viewport,
    required this.content,
    required this.onChanged,
    super.key,
  });

  /// The palette the handle is drawn from.
  final ChromeTheme theme;

  /// Which way the content scrolls.
  final Axis axis;

  /// How far it is scrolled, in pixels.
  final double offset;

  /// How much of it is on screen, in pixels.
  final double viewport;

  /// How long it is in total, in pixels.
  final double content;

  /// Called with the new offset while the handle is dragged.
  final ValueChanged<double> onChanged;

  /// How thick the bar is.
  static const double thickness = 10;

  /// The shortest the handle gets, however long the log is.
  static const double minimumThumb = 24;

  @override
  State<LognalScrollbar> createState() => _LognalScrollbarState();
}

class _LognalScrollbarState extends State<LognalScrollbar> {
  bool _hovered = false;
  bool _dragging = false;
  double _grabOffset = 0;

  double get _maxOffset => math.max(0, widget.content - widget.viewport);

  double get _thumbLength {
    final double ratio = widget.viewport / widget.content;

    return math.max(LognalScrollbar.minimumThumb, widget.viewport * ratio);
  }

  double get _thumbStart {
    final double travel = widget.viewport - _thumbLength;

    return _maxOffset <= 0 ? 0 : travel * (widget.offset / _maxOffset);
  }

  void _moveTo(double position) {
    final double travel = widget.viewport - _thumbLength;

    if (travel <= 0) {
      return;
    }

    widget.onChanged(((position - _grabOffset) / travel * _maxOffset).clamp(0, _maxOffset));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content <= widget.viewport + 1) {
      return const SizedBox.shrink();
    }

    final bool horizontal = widget.axis == Axis.horizontal;
    final Color color = _hovered || _dragging
        ? widget.theme.scrollbarThumbHover
        : widget.theme.scrollbarThumb;
    final Widget thumb = Positioned(
      left: horizontal ? _thumbStart : 2,
      top: horizontal ? 2 : _thumbStart,
      width: horizontal ? _thumbLength : LognalScrollbar.thickness - 4,
      height: horizontal ? LognalScrollbar.thickness - 4 : _thumbLength,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(LognalScrollbar.thickness),
        ),
      ),
    );

    return MouseRegion(
      // The log under it reads as text; the bar over it does not.
      cursor: SystemMouseCursors.basic,
      onEnter: (PointerEnterEvent _) => setState(() => _hovered = true),
      onExit: (PointerExitEvent _) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails details) {
          final double position = horizontal ? details.localPosition.dx : details.localPosition.dy;

          if (position >= _thumbStart && position <= _thumbStart + _thumbLength) {
            _grabOffset = position - _thumbStart;

            return;
          }

          _grabOffset = _thumbLength / 2;
          _moveTo(position);
        },
        onHorizontalDragStart: horizontal ? (DragStartDetails _) => _startDrag() : null,
        onHorizontalDragUpdate: horizontal
            ? (DragUpdateDetails details) => _moveTo(details.localPosition.dx)
            : null,
        onHorizontalDragEnd: horizontal ? (DragEndDetails _) => _endDrag() : null,
        onVerticalDragStart: horizontal ? null : (DragStartDetails _) => _startDrag(),
        onVerticalDragUpdate: horizontal
            ? null
            : (DragUpdateDetails details) => _moveTo(details.localPosition.dy),
        onVerticalDragEnd: horizontal ? null : (DragEndDetails _) => _endDrag(),
        child: Stack(children: <Widget>[thumb]),
      ),
    );
  }

  void _startDrag() => setState(() => _dragging = true);

  void _endDrag() => setState(() => _dragging = false);
}
