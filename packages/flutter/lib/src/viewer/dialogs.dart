import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/icons.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/popup.dart';
import 'package:lognal/src/viewer/toolbar.dart' show filterDelay;

/// Asks before a link opens, and shows the address it would open.
Future<void> showLinkDialog({
  required LognalPopupHostState? host,
  required ChromeTheme theme,
  required ViewerLabels labels,
  required String url,
  required VoidCallback onOpen,
}) {
  return showLognalDialog(
    host: host,
    theme: theme,
    builder: (BuildContext context, VoidCallback close) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LognalText(
          labels.linkDialogTitle,
          color: theme.foreground,
          size: 14,
          weight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        LognalText(labels.linkDialogMessage, color: theme.muted, wrap: true),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.background,
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          child: Text(
            url,
            style: TextStyle(color: theme.accent, fontSize: 12, height: 1.4),
            textDirection: TextDirection.ltr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            LognalTextButton(label: labels.linkDialogCancel, theme: theme, onPressed: close),
            const SizedBox(width: 8),
            LognalTextButton(
              label: labels.linkDialogOpen,
              theme: theme,
              primary: true,
              onPressed: () {
                close();
                onOpen();
              },
            ),
          ],
        ),
      ],
    ),
  );
}

/// Manages the rules that keep noise out of the log.
Future<void> showMuteDialog({
  required LognalPopupHostState? host,
  required LogViewerController controller,
  required ChromeTheme theme,
  required ViewerLabels labels,
}) {
  return showLognalDialog(
    host: host,
    theme: theme,
    width: 420,
    builder: (BuildContext context, VoidCallback close) =>
        _MuteDialog(controller: controller, theme: theme, labels: labels, onClose: close),
  );
}

class _MuteDialog extends StatefulWidget {
  const _MuteDialog({
    required this.controller,
    required this.theme,
    required this.labels,
    required this.onClose,
  });

  final LogViewerController controller;
  final ChromeTheme theme;
  final ViewerLabels labels;
  final VoidCallback onClose;

  @override
  State<_MuteDialog> createState() => _MuteDialogState();
}

class _MuteDialogState extends State<_MuteDialog> {
  final TextEditingController _text = TextEditingController();
  late List<MuteRule> _rules = List<MuteRule>.of(widget.controller.muteRules);
  late final List<TextEditingController> _fields = _rules
      .map((MuteRule rule) => TextEditingController(text: rule.text))
      .toList();
  Object? _typingTimer;

  @override
  void dispose() {
    _text.dispose();

    for (final TextEditingController field in _fields) {
      field.dispose();
    }

    super.dispose();
  }

  void _apply(List<MuteRule> rules) {
    setState(() => _rules = rules);
    widget.controller.setMuteRules(rules);
  }

  /// Applies an edited rule once typing stops, the way the toolbar filter does.
  ///
  /// Every keystroke would lay the whole log out again, which is a long wait on
  /// a log of any size for a rule that is half written.
  void _applyLater(int index, MuteRule rule) {
    final Object token = Object();

    _typingTimer = token;
    setState(() => _rules[index] = rule);
    Future<void>.delayed(filterDelay, () {
      if (!mounted || _typingTimer != token) {
        return;
      }

      widget.controller.setMuteRules(List<MuteRule>.of(_rules));
    });
  }

  void _add() {
    final String text = _text.text.trim();

    if (text.isEmpty) {
      return;
    }

    _text.clear();
    _fields.add(TextEditingController(text: text));
    _apply(<MuteRule>[..._rules, MuteRule(text: text)]);
  }

  void _remove(int index) {
    _fields.removeAt(index).dispose();
    _apply(List<MuteRule>.of(_rules)..removeAt(index));
  }

  /// Whether a rule compiles, which only a regular expression can fail to do.
  bool _valid(MuteRule rule) {
    if (!rule.regex) {
      return true;
    }

    try {
      RegExp(rule.text);

      return true;
    } on FormatException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChromeTheme theme = widget.theme;
    final ViewerLabels labels = widget.labels;
    final bool tooltips = widget.controller.options.tooltips;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LognalText(labels.mute, color: theme.foreground, size: 14, weight: FontWeight.w600),
        const SizedBox(height: 8),
        LognalText(labels.muteMessage, color: theme.muted, wrap: true),
        const SizedBox(height: 12),
        // A box of a fixed height that scrolls, so adding or removing a rule
        // leaves the dialog where it is.
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: theme.background,
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          child: _rules.isEmpty
              ? Center(child: LognalText(labels.muteEmpty, color: theme.muted))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _rules.length,
                  itemBuilder: (BuildContext context, int index) {
                    final MuteRule rule = _rules[index];

                    void replace(MuteRule next) {
                      final List<MuteRule> rules = List<MuteRule>.of(_rules);

                      rules[index] = next;
                      _apply(rules);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Row(
                        spacing: controlGap,
                        children: <Widget>[
                          _Toggle(
                            theme: theme,
                            label: labels.muteEnabled,
                            value: rule.enabled,
                            onChanged: (bool value) => replace(rule.copyWith(enabled: value)),
                          ),
                          const SizedBox(width: 8 - controlGap),
                          Expanded(
                            child: LognalField(
                              controller: _fields[index],
                              theme: theme,
                              hint: labels.muteText,
                              invalid: !_valid(rule),
                              onChanged: (String text) =>
                                  _applyLater(index, rule.copyWith(text: text)),
                            ),
                          ),
                          LognalButton(
                            icon: LognalIcon.matchCase,
                            label: labels.searchCase,
                            theme: theme,
                            tooltips: tooltips,
                            pressed: rule.caseSensitive,
                            onPressed: () =>
                                replace(rule.copyWith(caseSensitive: !rule.caseSensitive)),
                          ),
                          LognalButton(
                            icon: LognalIcon.regex,
                            label: labels.searchRegex,
                            theme: theme,
                            tooltips: tooltips,
                            pressed: rule.regex,
                            onPressed: () => replace(rule.copyWith(regex: !rule.regex)),
                          ),
                          LognalButton(
                            icon: LognalIcon.close,
                            label: labels.muteRemove,
                            theme: theme,
                            tooltips: tooltips,
                            onPressed: () => _remove(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: LognalField(
                controller: _text,
                theme: theme,
                hint: labels.muteText,
                onSubmitted: (String _) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            LognalTextButton(label: labels.muteAdd, theme: theme, onPressed: _add),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            LognalTextButton(
              label: labels.muteClose,
              theme: theme,
              primary: true,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ],
    );
  }
}

/// The switch that applies a rule or leaves it out without removing it.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final ChromeTheme theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? theme.accent : theme.background,
            border: Border.all(color: value ? theme.accent : theme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: value
              ? LognalIconView(icon: LognalIcon.check, color: theme.onAccent, size: 12)
              : null,
        ),
      ),
    );
  }
}
