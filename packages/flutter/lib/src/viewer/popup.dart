import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/icons.dart';

/// One row of a popup menu.
class PopupItem {
  /// Creates an item.
  const PopupItem({
    required this.label,
    required this.onSelect,
    this.icon,
    this.checked = false,
    this.separatorBefore = false,
  });

  /// What the row says.
  final String label;

  /// What choosing it does.
  final VoidCallback onSelect;

  /// An icon before the label.
  final LognalIcon? icon;

  /// Whether a tick is drawn beside it.
  final bool checked;

  /// Whether a line is drawn above it.
  final bool separatorBefore;
}

/// The corner radius of a popup.
const double _popupRadius = 10;

/// The height of one row of a menu.
const double _popupRowHeight = 30;

/// How long a popup takes to appear.
const Duration _popupFade = Duration(milliseconds: 80);

/// Lays out what is drawn over the viewer, told how much room there is and how
/// to close itself.
typedef PopupLayout = Widget Function(BuildContext context, Size area, VoidCallback close);

/// Builds the body of a dialog, told how to close itself.
typedef PopupContent = Widget Function(BuildContext context, VoidCallback close);

/// Holds the menus and dialogs the viewer draws over itself.
///
/// A menu is not a widget under the control that opened it: it is drawn over
/// everything else and it closes when something outside it is pressed. In an
/// application that is a job for the navigator's overlay, and this widget is
/// here because the viewer cannot count on there being one. A `WidgetsApp` with
/// nothing but a `builder` has no navigator at all, and a viewer whose menus
/// only worked inside a `MaterialApp` would not be the self-contained widget
/// this package promises.
class LognalPopupHost extends StatefulWidget {
  /// Creates a host around the viewer.
  const LognalPopupHost({required this.child, super.key});

  /// The viewer, which the popups are drawn over.
  final Widget child;

  /// The host above [context], or `null` when there is none.
  ///
  /// The viewer itself holds a key to its own host instead: its state sits
  /// above the host rather than inside it, and this looks upwards only.
  static LognalPopupHostState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<LognalPopupHostState>();
  }

  @override
  State<LognalPopupHost> createState() => LognalPopupHostState();
}

/// The state of a [LognalPopupHost], which is what opens and closes a popup.
class LognalPopupHostState extends State<LognalPopupHost> {
  final List<_Popup> _popups = <_Popup>[];

  @override
  void dispose() {
    for (final _Popup popup in _popups) {
      popup.close();
    }

    _popups.clear();
    super.dispose();
  }

  /// Draws [layout] over the viewer until it closes itself, and returns then.
  Future<void> show(PopupLayout layout, {Color? barrierColor}) {
    final _Popup popup = _Popup(layout: layout, barrierColor: barrierColor);

    setState(() => _popups.add(popup));

    return popup.closed;
  }

  /// Turns a point on the screen into one inside the viewer.
  Offset toLocal(Offset position) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize) {
      return position;
    }

    return box.globalToLocal(position);
  }

  void _dismiss(_Popup popup) {
    if (!_popups.contains(popup)) {
      return;
    }

    setState(() => _popups.remove(popup));
    popup.close();
  }

  @override
  Widget build(BuildContext context) {
    // The viewer is the child that gives the stack its size, so the popups over
    // it are the ones that fill what is left.
    return Stack(
      children: <Widget>[
        widget.child,
        for (final _Popup popup in _popups)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              key: ObjectKey(popup),
              tween: Tween<double>(begin: 0, end: 1),
              duration: _popupFade,
              builder: (BuildContext context, double value, Widget? child) =>
                  Opacity(opacity: value, child: child),
              child: _PopupLayer(popup: popup, onDismiss: () => _dismiss(popup)),
            ),
          ),
      ],
    );
  }
}

/// One thing drawn over the viewer, and the future of whoever opened it.
class _Popup {
  _Popup({required this.layout, required this.barrierColor});

  final PopupLayout layout;
  final Color? barrierColor;
  final Completer<void> _closed = Completer<void>();

  Future<void> get closed => _closed.future;

  void close() {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}

/// What a press outside a popup lands on, with the popup itself over it.
class _PopupLayer extends StatelessWidget {
  const _PopupLayer({required this.popup, required this.onDismiss});

  final _Popup popup;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color? barrier = popup.barrierColor;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Dismiss',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: barrier == null ? const SizedBox.expand() : ColoredBox(color: barrier),
              ),
            ),
          ),
          popup.layout(context, constraints.biggest, onDismiss),
        ],
      ),
    );
  }
}

/// Shows a menu at a point on the screen and returns once something is chosen or
/// the menu is dismissed.
///
/// It is the viewer's own menu rather than the framework's for the reason the
/// tooltip is: the palette here is the log's, not the application's, and a dark
/// viewer inside a light application should not open a light menu.
Future<void> showLognalMenu({
  required LognalPopupHostState? host,
  required Offset position,
  required ChromeTheme theme,
  required List<PopupItem> items,
  double width = 240,
}) {
  // A menu with nothing in it does not open, the way the JavaScript viewer's
  // entry menu does not when every item has been turned off.
  if (host == null || items.isEmpty) {
    return Future<void>.value();
  }

  final Offset origin = host.toLocal(position);

  return host.show((BuildContext context, Size area, VoidCallback close) {
    final double height = items.length * _popupRowHeight + 8;
    final double left = math.min(origin.dx, math.max(0, area.width - width - 8));
    final double top = math.min(origin.dy, math.max(0, area.height - height - 8));

    return Positioned(
      left: math.max(0, left),
      top: math.max(0, top),
      width: width,
      child: _PopupPanel(theme: theme, items: items, onDismiss: close),
    );
  });
}

class _PopupPanel extends StatelessWidget {
  const _PopupPanel({required this.theme, required this.items, required this.onDismiss});

  final ChromeTheme theme;
  final List<PopupItem> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(_popupRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(color: theme.shadow, blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items
              .map((PopupItem item) => _PopupRow(theme: theme, item: item, onDismiss: onDismiss))
              .toList(),
        ),
      ),
    );
  }
}

class _PopupRow extends StatefulWidget {
  const _PopupRow({required this.theme, required this.item, required this.onDismiss});

  final ChromeTheme theme;
  final PopupItem item;
  final VoidCallback onDismiss;

  @override
  State<_PopupRow> createState() => _PopupRowState();
}

class _PopupRowState extends State<_PopupRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ChromeTheme theme = widget.theme;
    final PopupItem item = widget.item;
    final LognalIcon? icon = item.icon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (item.separatorBefore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(height: 1, child: ColoredBox(color: theme.border)),
          ),
        Semantics(
          button: true,
          selected: item.checked,
          label: item.label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (PointerEnterEvent _) => setState(() => _hovered = true),
            onExit: (PointerExitEvent _) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.onDismiss();
                item.onSelect();
              },
              child: Container(
                height: _popupRowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: _hovered ? theme.controlHover : const Color(0x00000000),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      child: item.checked
                          ? LognalIconView(icon: LognalIcon.check, color: theme.accent, size: 14)
                          : icon == null
                          ? null
                          : LognalIconView(icon: icon, color: theme.muted, size: 14),
                    ),
                    Expanded(child: LognalText(item.label, color: theme.foreground)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows a panel in the middle of the viewer, for the link and mute dialogs.
Future<void> showLognalDialog({
  required LognalPopupHostState? host,
  required ChromeTheme theme,
  required PopupContent builder,
  double width = 380,
}) {
  if (host == null) {
    return Future<void>.value();
  }

  return host.show(
    (BuildContext context, Size area, VoidCallback close) => Positioned.fill(
      child: Center(
        // The viewer is what a dialog is centred in, and a viewer is often
        // shorter than a screen, so the panel scrolls rather than run past the
        // bottom of it.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(_popupRadius),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: theme.shadow, blurRadius: 32, offset: const Offset(0, 12)),
                ],
              ),
              child: Padding(padding: const EdgeInsets.all(16), child: builder(context, close)),
            ),
          ),
        ),
      ),
    ),
    barrierColor: const Color(0x66000000),
  );
}

/// A button with a word on it, for the dialogs.
class LognalTextButton extends StatefulWidget {
  /// Creates a button.
  const LognalTextButton({
    required this.label,
    required this.theme,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  /// What it says.
  final String label;

  /// The palette it is drawn from.
  final ChromeTheme theme;

  /// What it does.
  final VoidCallback onPressed;

  /// Whether it is the one the dialog is about.
  final bool primary;

  @override
  State<LognalTextButton> createState() => _LognalTextButtonState();
}

class _LognalTextButtonState extends State<LognalTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ChromeTheme theme = widget.theme;
    final Color background = widget.primary
        ? theme.accent
        : _hovered
        ? theme.controlHover
        : const Color(0x00000000);
    final Color color = widget.primary ? theme.onAccent : theme.foreground;

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent _) => setState(() => _hovered = true),
        onExit: (PointerExitEvent _) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            height: controlSize,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: widget.primary ? theme.accent : theme.border),
              borderRadius: BorderRadius.circular(controlRadius),
            ),
            child: LognalText(widget.label, color: color, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
