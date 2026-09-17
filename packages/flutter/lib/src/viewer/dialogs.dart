import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/icons.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/popup.dart';

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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply(List<MuteRule> rules) {
    setState(() => _rules = rules);
    widget.controller.setMuteRules(rules);
  }

  void _add() {
    final String text = _text.text.trim();

    if (text.isEmpty) {
      return;
    }

    _text.clear();
    _apply(<MuteRule>[..._rules, MuteRule(text: text)]);
  }

  @override
  Widget build(BuildContext context) {
    final ChromeTheme theme = widget.theme;
    final ViewerLabels labels = widget.labels;

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

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Row(
                        children: <Widget>[
                          _Toggle(
                            theme: theme,
                            label: labels.muteEnabled,
                            value: rule.enabled,
                            onChanged: (bool value) {
                              final List<MuteRule> next = List<MuteRule>.of(_rules);

                              next[index] = rule.copyWith(enabled: value);
                              _apply(next);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: LognalText(rule.text, color: theme.foreground)),
                          LognalButton(
                            icon: LognalIcon.close,
                            label: labels.muteRemove,
                            theme: theme,
                            onPressed: () {
                              final List<MuteRule> next = List<MuteRule>.of(_rules)
                                ..removeAt(index);

                              _apply(next);
                            },
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
