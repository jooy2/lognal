import 'package:flutter/widgets.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/options.dart';

/// The line under the log: whether the view is following, how many entries
/// there are, and how many of them are selected.
class LognalStatusBar extends StatelessWidget {
  /// Creates the status bar.
  const LognalStatusBar({
    required this.controller,
    required this.theme,
    required this.labels,
    super.key,
  });

  /// The viewer's state.
  final LogViewerController controller;

  /// The palette it is drawn from.
  final LognalTheme theme;

  /// The text of its parts.
  final ViewerLabels labels;

  @override
  Widget build(BuildContext context) {
    final ChromeTheme chrome = theme.chrome;
    final NumberFormatter format = controller.options.formatNumber;
    final int shown = controller.visibleCount;
    final int total = controller.entryCount;
    final int selected = controller.options.selectionMode == SelectionMode.entry
        ? controller.selectedEntries.length
        : 0;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: chrome.surface,
        border: Border(top: BorderSide(color: chrome.border)),
      ),
      child: Row(
        children: <Widget>[
          _Dot(color: controller.isFollowing ? chrome.accent : chrome.muted),
          const SizedBox(width: 6),
          LognalText(
            controller.isFollowing ? labels.following : labels.paused,
            color: chrome.muted,
            size: 11,
          ),
          const Spacer(),
          if (selected > 0) ...<Widget>[
            LognalText(labels.selectedEntries(selected, format), color: chrome.muted, size: 11),
            const SizedBox(width: 10),
          ],
          LognalText(labels.entries(shown, total, format), color: chrome.muted, size: 11),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
