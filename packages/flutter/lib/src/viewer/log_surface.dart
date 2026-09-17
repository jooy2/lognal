import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/renderer/canvas_renderer.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/icons.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/log_painter.dart';
import 'package:lognal/src/viewer/options.dart';
import 'package:lognal/src/viewer/scrollbar.dart';

/// How far the pointer may move between a press and a release and still count as
/// a tap rather than a drag.
const double _dragThreshold = 4;

/// How many rows a wheel notch moves.
const double _wheelRows = 3;

/// The log itself: the painted rows, the scrollbars over them, and everything
/// the pointer and the keyboard do to them.
class LogSurface extends StatefulWidget {
  /// Creates the surface.
  const LogSurface({
    required this.controller,
    required this.theme,
    required this.font,
    required this.labels,
    required this.onEntryMenu,
    required this.onLinkTap,
    super.key,
  });

  /// The viewer's state.
  final LogViewerController controller;

  /// The palette to draw with.
  final LognalTheme theme;

  /// The font to draw with.
  final FontSettings font;

  /// The labels of the controls drawn over the log.
  final ViewerLabels labels;

  /// Opens the menu of an entry, at a point on the screen.
  final void Function(int entryId, Offset position) onEntryMenu;

  /// Handles a tap on a link.
  final void Function(String url, {required bool direct}) onLinkTap;

  @override
  State<LogSurface> createState() => _LogSurfaceState();
}

class _LogSurfaceState extends State<LogSurface> {
  final CanvasLogRenderer _renderer = CanvasLogRenderer();
  final FocusNode _focus = FocusNode(debugLabel: 'lognal log');
  int _fontGeneration = 0;
  Offset? _pressAt;
  bool _overAction = false;
  bool _dragging = false;
  bool _selectingEntries = false;
  Set<int> _dragBaseSelection = <int>{};
  int? _dragFromEntry;

  LogViewerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // A font that was not there when a frame was drawn may be there by the next
    // one: on the web the engine fetches a face for a character no bundled font
    // covers, and until it arrives that character is a box. This is the same
    // seam the JavaScript renderer has in `onFontsChanged` — measure again, and
    // draw again.
    PaintingBinding.instance.systemFonts.addListener(_onSystemFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFontsChanged);
    _focus.dispose();
    _renderer.dispose();
    super.dispose();
  }

  void _onSystemFontsChanged() {
    if (mounted) {
      setState(() => _fontGeneration++);
    }
  }

  bool get _isApple {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _multiSelectHeld {
    final Set<LogicalKeyboardKey> keys = HardwareKeyboard.instance.logicalKeysPressed;

    return _isApple
        ? keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight)
        : keys.contains(LogicalKeyboardKey.controlLeft) ||
              keys.contains(LogicalKeyboardKey.controlRight);
  }

  bool get _shiftHeld => HardwareKeyboard.instance.isShiftPressed;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent _) {
      final double rowHeight = _controller.metrics.height;
      final double vertical = event.scrollDelta.dy;
      final double horizontal = event.scrollDelta.dx;

      if (horizontal != 0) {
        _controller.setScrollX(_controller.scrollX + horizontal);
      }

      if (vertical != 0) {
        if (_shiftHeld) {
          _controller.setScrollX(_controller.scrollX + vertical);
        } else {
          _controller.setTopPixels(
            _controller.topPixels +
                vertical.sign * rowHeight * _wheelRows * (vertical.abs() / 100).clamp(0.6, 4),
          );
        }
      }
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _focus.requestFocus();
    _pressAt = event.localPosition;
    _dragging = false;

    if (event.buttons == kSecondaryMouseButton) {
      _pressSecondary(event);

      return;
    }

    if (_controller.options.selectionMode == SelectionMode.entry) {
      _pressEntry(event.localPosition);

      return;
    }

    final LogPosition? position = _controller.positionAt(event.localPosition);

    if (position != null) {
      if (_shiftHeld && _controller.selection != null) {
        _controller.extendSelection(position);
      } else {
        _controller.startSelection(position);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final Offset? pressed = _pressAt;

    if (pressed == null) {
      return;
    }

    if (!_dragging && (event.localPosition - pressed).distance < _dragThreshold) {
      return;
    }

    _dragging = true;
    _autoScroll(event.localPosition);

    if (_selectingEntries) {
      _extendEntryDrag(event.localPosition);

      return;
    }

    final LogPosition? position = _controller.positionAt(event.localPosition);

    if (position != null) {
      _controller.extendSelection(position);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final Offset? pressed = _pressAt;

    _pressAt = null;
    _selectingEntries = false;

    if (pressed == null || _dragging) {
      _dragging = false;

      return;
    }

    if (_controller.options.selectionMode == SelectionMode.entry) {
      return;
    }

    final HitTest hit = _controller.hitTest(event.localPosition);
    final LineAction? action = hit.action;
    final VisualRow? row = hit.visualRow;

    if (action == null || row == null) {
      _controller.clearSelection();

      return;
    }

    if (action is OpenLinkAction) {
      widget.onLinkTap(action.url, direct: _multiSelectHeld);

      return;
    }

    if (_shiftHeld || _multiSelectHeld) {
      return;
    }

    _controller
      ..clearSelection()
      ..runAction(row.entry.id, action);
  }

  /// Opens the menu of the selected entries, in entry mode.
  ///
  /// Only in entry mode, as in the JavaScript viewer: while the log is read
  /// rather than picked through, a right press belongs to whatever the platform
  /// offers over selected text. An entry that is not selected is selected alone
  /// first, the way a file manager does it.
  void _pressSecondary(PointerDownEvent event) {
    if (_controller.options.selectionMode != SelectionMode.entry ||
        !_controller.options.entryMenu.visible) {
      return;
    }

    final HitTest hit = _controller.hitTest(event.localPosition);
    final VisualRow? row = hit.visualRow;

    if (row == null) {
      return;
    }

    if (!_controller.selectedEntries.contains(row.entry.id)) {
      _controller
        ..setSelectedEntries(<int>{row.entry.id})
        ..setEntryAnchor(row.entry.id);
    }

    _controller.setFocusedEntry(row.entry.id, showFocus: false);
    widget.onEntryMenu(row.entry.id, event.position);
  }

  void _pressEntry(Offset position) {
    final HitTest hit = _controller.hitTest(position);
    final VisualRow? row = hit.visualRow;
    final int? entryId = row?.entry.id ?? _edgeEntry(hit.row);

    if (entryId == null) {
      return;
    }

    _selectingEntries = true;
    _dragFromEntry = entryId;

    final Set<int> current = _controller.selectedEntries;

    if (_multiSelectHeld) {
      _dragBaseSelection = <int>{...current};
      _controller.setSelectedEntries(
        current.contains(entryId)
            ? (<int>{...current}..remove(entryId))
            : (<int>{...current}..add(entryId)),
      );
    } else if (_shiftHeld && _controller.entryAnchorId != null) {
      _dragBaseSelection = <int>{...current};
      _selectRange(_controller.entryAnchorId!, entryId, <int>{});
    } else {
      _dragBaseSelection = <int>{};
      _controller
        ..setSelectedEntries(<int>{entryId})
        ..setEntryAnchor(entryId);
    }

    _controller.setFocusedEntry(entryId, showFocus: false);
  }

  void _extendEntryDrag(Offset position) {
    final HitTest hit = _controller.hitTest(position);
    final int? entryId = hit.visualRow?.entry.id ?? _edgeEntry(hit.row);
    final int? from = _dragFromEntry;

    if (entryId == null || from == null) {
      return;
    }

    _selectRange(from, entryId, _dragBaseSelection);
  }

  void _selectRange(int from, int to, Set<int> base) {
    final int first = math.min(from, to);
    final int last = math.max(from, to);
    final Set<int> ids = <int>{...base};

    for (
      int index = _controller.layout.indexFrom(first);
      index < _controller.layout.visibleCount;
      index++
    ) {
      final LogEntry? entry = _controller.layout.entryAt(index);

      if (entry == null || entry.id > last) {
        break;
      }

      ids.add(entry.id);
    }

    _controller.setSelectedEntries(ids);
  }

  /// The entry nearest a row that is past the end of the log, so a drag that
  /// starts on the empty space below still selects something.
  int? _edgeEntry(int row) {
    if (_controller.layout.visibleCount == 0) {
      return null;
    }

    if (row < 0) {
      return _controller.layout.entryAt(0)?.id;
    }

    return _controller.layout.entryAt(_controller.layout.visibleCount - 1)?.id;
  }

  void _autoScroll(Offset position) {
    const double edge = 24;
    final double height = _controller.size.height;

    if (position.dy < edge) {
      _controller.setTopPixels(_controller.topPixels - _controller.metrics.height);
    } else if (position.dy > height - edge) {
      _controller.setTopPixels(_controller.topPixels + _controller.metrics.height);
    }
  }

  void _onHover(PointerHoverEvent event) {
    final HitTest hit = _controller.hitTest(event.localPosition);

    _setOverAction(hit.action != null);
    _controller.setHoverEntry(hit.visualRow?.entry.id);
  }

  void _setOverAction(bool value) {
    if (value != _overAction && mounted) {
      setState(() => _overAction = value);
    }
  }

  /// What the pointer looks like over the log.
  ///
  /// The same three the stylesheet gives the JavaScript viewer: a link or an
  /// expander is something to press, entries are picked out rather than read
  /// from while the selection mode is entry, and the rest of the time the log
  /// is text that can be selected.
  MouseCursor get _cursor {
    if (_overAction) {
      return SystemMouseCursors.click;
    }

    return _controller.options.selectionMode == SelectionMode.entry
        ? SystemMouseCursors.basic
        : SystemMouseCursors.text;
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_controller.options.selectionMode == SelectionMode.entry) {
      return;
    }

    final LogPosition? position = _controller.positionAt(details.localPosition);

    if (position != null) {
      _controller.selectWordAt(position);
    }
  }

  void _onLongPress(LongPressStartDetails details) {
    if (!_controller.options.entryMenu.visible) {
      return;
    }

    final HitTest hit = _controller.hitTest(details.localPosition);
    final VisualRow? row = hit.visualRow;

    if (row != null) {
      widget.onEntryMenu(row.entry.id, details.globalPosition);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    final double rowHeight = _controller.metrics.height;
    final double page = math.max(rowHeight, _controller.size.height - rowHeight);

    if (_multiSelectHeld) {
      if (key == LogicalKeyboardKey.keyA) {
        _controller.selectAll();

        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyC) {
        unawaitedCopy();

        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyF && _controller.options.search) {
        _controller.openSearch(_startingQuery());

        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape) {
      _controller.clearSelection();

      return KeyEventResult.handled;
    }

    if (_controller.options.selectionMode == SelectionMode.entry && _moveEntryFocus(key)) {
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _controller.setTopPixels(_controller.topPixels + rowHeight);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _controller.setTopPixels(_controller.topPixels - rowHeight);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _controller.setScrollX(_controller.scrollX + _controller.metrics.width * 4);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _controller.setScrollX(_controller.scrollX - _controller.metrics.width * 4);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _controller.setTopPixels(_controller.topPixels + page);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _controller.setTopPixels(_controller.topPixels - page);
    } else if (key == LogicalKeyboardKey.home) {
      _controller.scrollToTop();
    } else if (key == LogicalKeyboardKey.end) {
      _controller.scrollToBottom();
    } else {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  /// Copies without waiting for the clipboard, which a key handler cannot do.
  void unawaitedCopy() {
    _controller.copySelection().ignore();
  }

  String? _startingQuery() {
    final String selected = _controller.selectionText();

    if (selected.isEmpty || selected.contains('\n') || selected.length > 200) {
      return null;
    }

    return selected;
  }

  bool _moveEntryFocus(LogicalKeyboardKey key) {
    final int count = _controller.layout.visibleCount;

    if (count == 0) {
      return false;
    }

    final int? focused = _controller.focusedEntryId;
    final int current = focused == null ? -1 : _controller.layout.indexOf(focused);
    final int rows = math.max(1, (_controller.size.height / _controller.metrics.height).floor());
    int next;

    if (key == LogicalKeyboardKey.arrowDown) {
      next = current + 1;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      next = current <= 0 ? 0 : current - 1;
    } else if (key == LogicalKeyboardKey.pageDown) {
      next = current + rows;
    } else if (key == LogicalKeyboardKey.pageUp) {
      next = current - rows;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = count - 1;
    } else if (key == LogicalKeyboardKey.space) {
      if (focused != null) {
        final Set<int> ids = <int>{..._controller.selectedEntries};

        ids.contains(focused) ? ids.remove(focused) : ids.add(focused);
        _controller
          ..setSelectedEntries(ids)
          ..setEntryAnchor(focused);
      }

      return true;
    } else {
      return false;
    }

    final int clamped = next.clamp(0, count - 1);
    final LogEntry? entry = _controller.layout.entryAt(clamped);

    if (entry == null) {
      return false;
    }

    _controller.setFocusedEntry(entry.id);

    if (_shiftHeld && _controller.entryAnchorId != null) {
      _selectRange(_controller.entryAnchorId!, entry.id, <int>{});
    } else if (!_multiSelectHeld) {
      _controller
        ..setSelectedEntries(<int>{entry.id})
        ..setEntryAnchor(entry.id);
    }

    _controller.scrollToEntry(entry.id);

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: MouseRegion(
          cursor: _cursor,
          onHover: _onHover,
          onExit: (PointerExitEvent _) {
            _setOverAction(false);
            _controller.setHoverEntry(null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: _onDoubleTapDown,
            onDoubleTap: () {},
            onLongPressStart: _onLongPress,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return _getSurfaceWidget(context, constraints.biggest);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _getSurfaceWidget(BuildContext context, Size size) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(
            painter: LogPainter(
              controller: _controller,
              renderer: _renderer,
              theme: widget.theme.renderer,
              font: widget.font,
              fontGeneration: _fontGeneration,
            ),
            size: size,
          ),
        ),
        _getSemanticsWidget(),
        ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, Widget? child) => _getOverlayWidget(size),
        ),
      ],
    );
  }

  /// A list of the visible entries for a screen reader.
  ///
  /// The log itself is a picture as far as accessibility is concerned, so what
  /// is on screen is mirrored as text beside it. Only the rows in view are
  /// mirrored, which is what keeps a hundred thousand entries from becoming a
  /// hundred thousand nodes.
  Widget _getSemanticsWidget() {
    return ExcludeSemantics(
      excluding: false,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? child) {
          final List<String> lines = _controller
              .frame()
              .rows
              .where((VisualRow row) => row.first)
              .map((VisualRow row) => _controller.entryText(row.entry.id))
              .toList();

          return Semantics(
            container: true,
            liveRegion: _controller.isFollowing,
            label: widget.labels.entryList,
            value: lines.join('\n'),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  Widget _getOverlayWidget(Size size) {
    final int? hovered = _controller.hoverEntryId ?? _controller.menuEntryId;
    final bool showButton = _controller.options.entryMenu.visible && hovered != null && !_dragging;

    return Stack(
      children: <Widget>[
        if (showButton) _getEntryButtonWidget(hovered, size),
        Positioned(
          right: 0,
          top: 0,
          bottom: LognalScrollbar.thickness,
          width: LognalScrollbar.thickness,
          child: LognalScrollbar(
            theme: widget.theme.chrome,
            axis: Axis.vertical,
            offset: _controller.topPixels,
            viewport: size.height,
            content: _controller.contentHeight,
            onChanged: _controller.setTopPixels,
          ),
        ),
        Positioned(
          left: 0,
          right: LognalScrollbar.thickness,
          bottom: 0,
          height: LognalScrollbar.thickness,
          child: LognalScrollbar(
            theme: widget.theme.chrome,
            axis: Axis.horizontal,
            offset: _controller.scrollX,
            viewport: size.width,
            content: _controller.contentWidth,
            onChanged: _controller.setScrollX,
          ),
        ),
      ],
    );
  }

  Widget _getEntryButtonWidget(int entryId, Size size) {
    final int row = _controller.layout.rowOfEntry(entryId);

    if (row < 0) {
      return const SizedBox.shrink();
    }

    final double top = row * _controller.metrics.height + paddingTop - _controller.topPixels;

    if (top < -_controller.metrics.height || top > size.height) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: LognalScrollbar.thickness + 2,
      top: top,
      height: _controller.metrics.height,
      child: Semantics(
        button: true,
        label: widget.labels.entryActions,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (TapDownDetails details) =>
                widget.onEntryMenu(entryId, details.globalPosition),
            child: Container(
              width: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.theme.chrome.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: LognalIconView(
                icon: LognalIcon.more,
                color: widget.theme.chrome.muted,
                size: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
