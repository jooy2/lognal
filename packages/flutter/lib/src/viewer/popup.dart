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

/// Shows a menu at a point on the screen and returns once something is chosen or
/// the menu is dismissed.
///
/// It is the viewer's own menu rather than the framework's for the reason the
/// tooltip is: the palette here is the log's, not the application's, and a dark
/// viewer inside a light application should not open a light menu.
Future<void> showLognalMenu({
  required BuildContext context,
  required Offset position,
  required ChromeTheme theme,
  required List<PopupItem> items,
  double width = 240,
}) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

  return navigator.push<void>(
    _PopupRoute(position: position, theme: theme, items: items, width: width),
  );
}

class _PopupRoute extends PopupRoute<void> {
  _PopupRoute({
    required this.position,
    required this.theme,
    required this.items,
    required this.width,
  });

  final Offset position;
  final ChromeTheme theme;
  final List<PopupItem> items;
  final double width;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 80);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Size screen = MediaQuery.sizeOf(context);
    final double height = items.length * 30.0 + 8;
    final double left = math.min(position.dx, math.max(0, screen.width - width - 8));
    final double top = math.min(position.dy, math.max(0, screen.height - height - 8));

    return Stack(
      children: <Widget>[
        Positioned(
          left: left,
          top: top,
          width: width,
          child: FadeTransition(
            opacity: animation,
            child: _PopupPanel(theme: theme, items: items),
          ),
        ),
      ],
    );
  }
}

class _PopupPanel extends StatelessWidget {
  const _PopupPanel({required this.theme, required this.items});

  final ChromeTheme theme;
  final List<PopupItem> items;

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
          children: items.map((PopupItem item) => _PopupRow(theme: theme, item: item)).toList(),
        ),
      ),
    );
  }
}

class _PopupRow extends StatefulWidget {
  const _PopupRow({required this.theme, required this.item});

  final ChromeTheme theme;
  final PopupItem item;

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
                Navigator.of(context).pop();
                item.onSelect();
              },
              child: Container(
                height: 30,
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
Future<T?> showLognalDialog<T>({
  required BuildContext context,
  required ChromeTheme theme,
  required WidgetBuilder builder,
  double width = 380,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(_DialogRoute<T>(theme: theme, builder: builder, width: width));
}

class _DialogRoute<T> extends PopupRoute<T> {
  _DialogRoute({required this.theme, required this.builder, required this.width});

  final ChromeTheme theme;
  final WidgetBuilder builder;
  final double width;

  @override
  Color get barrierColor => const Color(0x66000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Center(
      child: FadeTransition(
        opacity: animation,
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
            child: Padding(padding: const EdgeInsets.all(16), child: builder(context)),
          ),
        ),
      ),
    );
  }
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
