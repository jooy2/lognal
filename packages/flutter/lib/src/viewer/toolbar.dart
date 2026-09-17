import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/icons.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/options.dart';
import 'package:lognal/src/viewer/popup.dart';

/// How long the viewer waits after a keystroke before it applies the filter.
const Duration filterDelay = Duration(milliseconds: 120);

/// The row of controls above the log.
class LognalToolbar extends StatefulWidget {
  /// Creates the toolbar.
  const LognalToolbar({
    required this.controller,
    required this.theme,
    required this.labels,
    required this.onOpenMute,
    super.key,
  });

  /// The viewer's state.
  final LogViewerController controller;

  /// The palette it is drawn from.
  final LognalTheme theme;

  /// The text of its controls.
  final ViewerLabels labels;

  /// Opens the dialog of hidden messages.
  final VoidCallback onOpenMute;

  @override
  State<LognalToolbar> createState() => _LognalToolbarState();
}

class _LognalToolbarState extends State<LognalToolbar> {
  final TextEditingController _filterText = TextEditingController();
  final FocusNode _filterFocus = FocusNode(debugLabel: 'lognal filter');
  Object? _filterTimer;

  LogViewerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _filterText.text = _controller.filter?.text ?? '';
  }

  @override
  void dispose() {
    _filterText.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  void _onFilterChanged(String text) {
    final Object token = Object();

    _filterTimer = token;
    Future<void>.delayed(filterDelay, () {
      if (!mounted || _filterTimer != token) {
        return;
      }

      _controller.setFilter((_controller.filter ?? const LogFilter()).copyWith(text: text));
    });
  }

  List<LogLevel> get _shownLevels {
    final LogFilter? filter = _controller.filter;
    final List<LogLevel>? levels = filter?.levels;

    if (levels != null) {
      return levels;
    }

    final LogLevel? minLevel = filter?.minLevel;

    return minLevel == null ? logLevels : logLevels.sublist(minLevel.index);
  }

  String _levelLabel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => widget.labels.levelDebug,
      LogLevel.log => widget.labels.levelLog,
      LogLevel.info => widget.labels.levelInfo,
      LogLevel.warn => widget.labels.levelWarn,
      LogLevel.error => widget.labels.levelError,
    };
  }

  String _levelsText() {
    final List<LogLevel> shown = _shownLevels;

    if (shown.length == logLevels.length) {
      return widget.labels.levelAll;
    }

    if (shown.length == 1) {
      return _levelLabel(shown.first);
    }

    return widget.labels.levelSome(shown.length, _controller.options.formatNumber);
  }

  void _setLevels(List<LogLevel> levels) {
    _controller.setFilter(
      (_controller.filter ?? const LogFilter()).copyWith(
        levels: levels.length == logLevels.length ? null : levels,
        clearLevels: levels.length == logLevels.length,
        clearMinLevel: true,
      ),
    );
  }

  Future<void> _openLevelMenu(Offset position) async {
    final List<LogLevel> shown = _shownLevels;
    final bool all = shown.length == logLevels.length;

    await showLognalMenu(
      context: context,
      position: position,
      theme: widget.theme.chrome,
      items: <PopupItem>[
        PopupItem(
          label: widget.labels.levelAll,
          checked: all,
          onSelect: () => _setLevels(logLevels),
        ),
        for (final LogLevel level in logLevels)
          PopupItem(
            label: _levelLabel(level),
            checked: shown.contains(level),
            separatorBefore: level == logLevels.first,
            onSelect: () {
              // While every level is shown, choosing one shows that level alone;
              // after that, choosing a level adds it or takes it away.
              if (all) {
                _setLevels(<LogLevel>[level]);

                return;
              }

              final List<LogLevel> next = shown.contains(level)
                  ? (List<LogLevel>.of(shown)..remove(level))
                  : (List<LogLevel>.of(shown)..add(level));

              _setLevels(next.isEmpty ? logLevels : (next..sort(_bySeverity)));
            },
          ),
      ],
      width: 180,
    );
  }

  static int _bySeverity(LogLevel a, LogLevel b) => a.index - b.index;

  Future<void> _openThemeMenu(Offset position) async {
    final List<ThemeChoice> choices = _controller.options.resolvedThemes(widget.labels);

    await showLognalMenu(
      context: context,
      position: position,
      theme: widget.theme.chrome,
      items: choices.map((ThemeChoice choice) {
        return PopupItem(
          label: choice.label ?? _themeLabel(choice.name),
          checked: _controller.themeName == choice.name,
          onSelect: () => _controller.setTheme(choice.name),
        );
      }).toList(),
      width: 180,
    );
  }

  String _themeLabel(String name) {
    return switch (name) {
      'auto' => widget.labels.themeAuto,
      'light' => widget.labels.themeLight,
      'paper' => widget.labels.themePaper,
      'dark' => widget.labels.themeDark,
      'midnight' => widget.labels.themeMidnight,
      'ember' => widget.labels.themeEmber,
      'moss' => widget.labels.themeMoss,
      _ => name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ViewerToolbarOptions toolbar = _controller.options.toolbar;
    final ChromeTheme theme = widget.theme.chrome;
    final ViewerLabels labels = widget.labels;
    final bool tooltips = _controller.options.tooltips;
    final int muted = _controller.mutedCount;
    final List<Widget> start = <Widget>[
      if (toolbar.follow)
        LognalButton(
          icon: LognalIcon.follow,
          label: labels.follow,
          theme: theme,
          tooltips: tooltips,
          pressed: _controller.isFollowing,
          onPressed: () => _controller.setFollowing(!_controller.isFollowing),
        ),
      if (toolbar.clear)
        LognalButton(
          icon: LognalIcon.clear,
          label: labels.clear,
          theme: theme,
          tooltips: tooltips,
          onPressed: _controller.clear,
        ),
      if (toolbar.scroll) ...<Widget>[
        _separator(theme),
        LognalButton(
          icon: LognalIcon.top,
          label: labels.scrollToTop,
          theme: theme,
          tooltips: tooltips,
          onPressed: _controller.scrollToTop,
        ),
        LognalButton(
          icon: LognalIcon.bottom,
          label: labels.scrollToBottom,
          theme: theme,
          tooltips: tooltips,
          onPressed: _controller.scrollToBottom,
        ),
      ],
      if (toolbar.wrap) ...<Widget>[
        _separator(theme),
        LognalButton(
          icon: LognalIcon.wrap,
          label: labels.wrap,
          theme: theme,
          tooltips: tooltips,
          pressed: _controller.layout.options.wrap != WrapMode.none,
          onPressed: _controller.toggleWrap,
        ),
      ],
      if (toolbar.selectionMode) ...<Widget>[
        if (!toolbar.wrap) _separator(theme),
        LognalButton(
          icon: LognalIcon.selectEntries,
          label: labels.selectEntries,
          theme: theme,
          tooltips: tooltips,
          pressed: _controller.options.selectionMode == SelectionMode.entry,
          onPressed: () => _controller.setOptions(
            _controller.options.copyWith(
              selectionMode: _controller.options.selectionMode == SelectionMode.entry
                  ? SelectionMode.text
                  : SelectionMode.entry,
            ),
          ),
        ),
      ],
      if (toolbar.theme) ...<Widget>[
        _separator(theme),
        _MenuButton(
          icon: LognalIcon.theme,
          label: labels.theme,
          theme: theme,
          tooltips: tooltips,
          onOpen: _openThemeMenu,
        ),
      ],
      if (toolbar.mute) ...<Widget>[
        _separator(theme),
        LognalButton(
          icon: LognalIcon.mute,
          label: muted > 0
              ? '${labels.mute}, ${labels.muteCount(muted, _controller.options.formatNumber)}'
              : labels.mute,
          theme: theme,
          tooltips: tooltips,
          badge: muted > 99
              ? '99+'
              : muted > 0
              ? _controller.options.formatNumber(muted)
              : null,
          onPressed: widget.onOpenMute,
        ),
      ],
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Semantics(
        container: true,
        label: labels.toolbar,
        child: Row(
          children: <Widget>[
            ...start,
            const Spacer(),
            if (toolbar.filter)
              SizedBox(
                width: 180,
                child: LognalField(
                  controller: _filterText,
                  focusNode: _filterFocus,
                  theme: theme,
                  hint: labels.filter,
                  icon: LognalIcon.search,
                  invalid: _controller.layout.filter.error != null,
                  onChanged: _onFilterChanged,
                ),
              ),
            if (toolbar.levels) ...<Widget>[
              const SizedBox(width: 6),
              _LevelsButton(
                theme: theme,
                label: labels.levels,
                value: _levelsText(),
                tooltips: tooltips,
                onOpen: _openLevelMenu,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _separator(ChromeTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(width: 1, height: 16, child: ColoredBox(color: theme.border)),
    );
  }
}

/// A button that opens a menu under itself.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.tooltips,
    required this.onOpen,
  });

  final LognalIcon icon;
  final String label;
  final ChromeTheme theme;
  final bool tooltips;
  final Future<void> Function(Offset position) onOpen;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) => LognalButton(
        icon: icon,
        label: label,
        theme: theme,
        tooltips: tooltips,
        onPressed: () => onOpen(_menuOrigin(context)),
      ),
    );
  }
}

/// The level menu's trigger, which shows what is chosen rather than an icon.
class _LevelsButton extends StatelessWidget {
  const _LevelsButton({
    required this.theme,
    required this.label,
    required this.value,
    required this.tooltips,
    required this.onOpen,
  });

  final ChromeTheme theme;
  final String label;
  final String value;
  final bool tooltips;
  final Future<void> Function(Offset position) onOpen;

  @override
  Widget build(BuildContext context) {
    final Widget button = Builder(
      builder: (BuildContext context) => GestureDetector(
        onTap: () => onOpen(_menuOrigin(context)),
        child: Container(
          height: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.background,
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LognalText(value, color: theme.foreground),
              const SizedBox(width: 4),
              LognalIconView(icon: LognalIcon.chevronDown, color: theme.muted, size: 14),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '$label, $value',
      child: MouseRegion(cursor: SystemMouseCursors.click, child: button),
    );
  }
}

/// Where a menu opens: under the control that asked for it.
Offset _menuOrigin(BuildContext context) {
  final RenderBox? box = context.findRenderObject() as RenderBox?;

  if (box == null) {
    return Offset.zero;
  }

  return box.localToGlobal(Offset(0, box.size.height + 4));
}
