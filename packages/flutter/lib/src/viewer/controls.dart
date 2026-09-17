import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/icons.dart';

/// The corner radius of a control.
const double controlRadius = 6;

/// The size of a square icon button.
const double controlSize = 28;

/// The space between two controls of a bar.
///
/// Small, because the buttons of a bar belong together, but not nothing: two
/// toggles that are both on would otherwise read as one wide button.
const double controlGap = 2;

/// A square icon button, the shape every control in the chrome takes.
class LognalButton extends StatefulWidget {
  /// Creates a button.
  const LognalButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onPressed,
    this.pressed = false,
    this.tooltips = true,
    this.badge,
    super.key,
  });

  /// The icon drawn in it.
  final LognalIcon icon;

  /// The name the button carries, which is also what the tooltip says.
  final String label;

  /// The palette it is drawn from.
  final ChromeTheme theme;

  /// What it does.
  final VoidCallback onPressed;

  /// Whether it is on, which colors it in.
  final bool pressed;

  /// Whether the name appears as a label as soon as the pointer reaches it.
  final bool tooltips;

  /// A count drawn over the corner, such as the number of hidden entries.
  final String? badge;

  @override
  State<LognalButton> createState() => _LognalButtonState();
}

class _LognalButtonState extends State<LognalButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ChromeTheme theme = widget.theme;
    final Color background = widget.pressed
        ? theme.controlActive
        : _hovered
        ? theme.controlHover
        : const Color(0x00000000);
    final Color color = widget.pressed ? theme.accent : theme.muted;
    final String? badge = widget.badge;
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (PointerEnterEvent _) => setState(() => _hovered = true),
      onExit: (PointerExitEvent _) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: controlSize,
          height: controlSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          child: badge == null
              ? LognalIconView(icon: widget.icon, color: color)
              : Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    LognalIconView(icon: widget.icon, color: color),
                    Positioned(
                      right: -4,
                      top: -2,
                      child: _Badge(text: badge, theme: theme),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Semantics(
      button: true,
      toggled: widget.pressed,
      label: widget.label,
      child: widget.tooltips
          ? LognalTooltip(message: widget.label, theme: theme, child: button)
          : button,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.theme});

  final String text;
  final ChromeTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(color: theme.onAccent, fontSize: 9, height: 1.2),
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

/// The label that appears while the pointer rests on a control.
///
/// It is the viewer's own rather than the framework's so that it takes the
/// viewer's palette: a dark log inside a light application would otherwise put a
/// light tooltip over a dark toolbar. It is also the reason this package draws
/// its own menus and dialogs.
class LognalTooltip extends StatefulWidget {
  /// Creates a tooltip.
  const LognalTooltip({required this.message, required this.theme, required this.child, super.key});

  /// What it says.
  final String message;

  /// The palette it is drawn from.
  final ChromeTheme theme;

  /// The control it belongs to.
  final Widget child;

  @override
  State<LognalTooltip> createState() => _LognalTooltipState();
}

class _LognalTooltipState extends State<LognalTooltip> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _show() {
    if (_entry != null || !mounted) {
      return;
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final OverlayState? overlay = Overlay.maybeOf(context);

    if (box == null || overlay == null) {
      return;
    }

    final Offset origin = box.localToGlobal(Offset.zero);
    final ChromeTheme theme = widget.theme;

    _entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        left: origin.dx,
        top: origin.dy + box.size.height + 6,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.foreground,
              borderRadius: BorderRadius.circular(controlRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: LognalText(widget.message, color: theme.background, size: 11),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (PointerEnterEvent _) => _show(),
      onExit: (PointerExitEvent _) => _hide(),
      child: widget.child,
    );
  }
}

/// A text field in the chrome: the filter, the search and the input line all
/// wear this.
class LognalField extends StatefulWidget {
  /// Creates a field.
  const LognalField({
    required this.controller,
    required this.theme,
    required this.hint,
    this.focusNode,
    this.icon,
    this.onChanged,
    this.onSubmitted,
    this.invalid = false,
    this.autofocus = false,
    this.style,
    super.key,
  });

  /// What holds the text.
  final TextEditingController controller;

  /// The palette it is drawn from.
  final ChromeTheme theme;

  /// What the field says while it is empty.
  final String hint;

  /// Where the keyboard is. Without one the field keeps its own.
  final FocusNode? focusNode;

  /// An icon before the text.
  final LognalIcon? icon;

  /// Called on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Called when the field is submitted.
  final ValueChanged<String>? onSubmitted;

  /// Whether the text is not a valid pattern, which colors the border.
  final bool invalid;

  /// Whether the keyboard goes here as soon as the field appears.
  final bool autofocus;

  /// The style of the text, for a field that shows code rather than words.
  final TextStyle? style;

  @override
  State<LognalField> createState() => _LognalFieldState();
}

class _LognalFieldState extends State<LognalField> {
  FocusNode? _own;

  @override
  void initState() {
    super.initState();

    if (widget.focusNode == null) {
      _own = FocusNode(debugLabel: 'lognal field');
    }

    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _own?.dispose();
    super.dispose();
  }

  /// The hint appears and disappears with the text, and nothing else here does,
  /// so the field listens rather than the whole toolbar rebuilding.
  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChromeTheme theme = widget.theme;
    final TextStyle text =
        widget.style ?? TextStyle(color: theme.foreground, fontSize: 12, height: 1.3);
    final LognalIcon? leading = widget.icon;

    return Container(
      height: controlSize,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border.all(color: widget.invalid ? theme.error : theme.border),
        borderRadius: BorderRadius.circular(controlRadius),
      ),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            LognalIconView(icon: leading, color: theme.muted, size: 14),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                if (widget.controller.text.isEmpty)
                  IgnorePointer(
                    child: Text(
                      widget.hint,
                      style: text.copyWith(color: theme.muted),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                EditableText(
                  controller: widget.controller,
                  focusNode: widget.focusNode ?? _own!,
                  style: text,
                  cursorColor: theme.accent,
                  backgroundCursorColor: theme.border,
                  selectionColor: theme.controlActive,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  autofocus: widget.autofocus,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  // The field carries code as often as words, and a keyboard
                  // that corrects it is a keyboard fighting the reader.
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The text of a menu item or a status line, in the chrome's own font.
class LognalText extends StatelessWidget {
  /// Creates the text.
  const LognalText(
    this.text, {
    required this.color,
    this.size = 12,
    this.weight = FontWeight.w400,
    this.wrap = false,
    super.key,
  });

  /// What it says.
  final String text;

  /// The color it is drawn in.
  final Color color;

  /// How big it is.
  final double size;

  /// How heavy it is.
  final FontWeight weight;

  /// Whether a long line runs on rather than ending in an ellipsis.
  ///
  /// A label on a control keeps its one line, which is why this is off by
  /// default. A sentence in a dialog is read rather than glanced at, so it wraps
  /// instead of losing its end.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.4),
      textDirection: TextDirection.ltr,
      // An ellipsis with no line count of its own is one line, so this is what
      // decides whether the text wraps at all.
      overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}
