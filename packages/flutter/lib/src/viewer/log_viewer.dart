import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/dialogs.dart';
import 'package:lognal/src/viewer/icons.dart';
import 'package:lognal/src/viewer/input_line.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/log_surface.dart';
import 'package:lognal/src/viewer/options.dart';
import 'package:lognal/src/viewer/popup.dart';
import 'package:lognal/src/viewer/search_bar.dart';
import 'package:lognal/src/viewer/status_bar.dart';
import 'package:lognal/src/viewer/toolbar.dart';

/// The monospace families to fall back through, per platform.
///
/// Flutter has no generic `monospace` that means the same thing everywhere, so
/// the list is written out: the platform's own first, then the Korean and
/// Japanese monospace faces a CJK log line needs, then whatever else is around.
const List<String> _webFamilies = <String>['monospace', 'Courier New'];

const Map<TargetPlatform, List<String>> _monospaceFamilies = <TargetPlatform, List<String>>{
  TargetPlatform.iOS: <String>['Menlo', 'Courier'],
  TargetPlatform.macOS: <String>['SF Mono', 'Menlo', 'Monaco', 'Courier'],
  TargetPlatform.android: <String>['monospace', 'Roboto Mono', 'Droid Sans Mono'],
  TargetPlatform.windows: <String>['Consolas', 'Cascadia Mono', 'Courier New'],
  TargetPlatform.linux: <String>['DejaVu Sans Mono', 'Liberation Mono', 'monospace'],
  TargetPlatform.fuchsia: <String>['Roboto Mono', 'monospace'],
};

/// The Korean and Japanese monospace faces every platform tries after its own.
const List<String> _cjkFamilies = <String>[
  'D2Coding',
  'NanumGothicCoding',
  'Noto Sans Mono CJK KR',
  'Apple SD Gothic Neo',
  'Malgun Gothic',
];

/// How many viewers are on screen, which is what decides whether the browser
/// draws its own menu on a right click.
///
/// A right click on the log opens the viewer's entry menu, and on the web the
/// browser answers the same click with its own menu on top of it. Flutter can
/// only turn that off for the whole view, so the viewer turns it off while it
/// is on screen and puts it back when the last one goes away. An application
/// that wants the browser's menu back can call
/// `BrowserContextMenu.enableContextMenu()` itself.
int _viewersOnScreen = 0;

void _holdBrowserContextMenu() {
  if (!kIsWeb) {
    return;
  }

  _viewersOnScreen++;

  if (_viewersOnScreen == 1) {
    BrowserContextMenu.disableContextMenu().ignore();
  }
}

void _releaseBrowserContextMenu() {
  if (!kIsWeb) {
    return;
  }

  _viewersOnScreen--;

  if (_viewersOnScreen == 0) {
    BrowserContextMenu.enableContextMenu().ignore();
  }
}

/// A log viewer that looks and behaves like a terminal.
///
/// The widget draws the log on a canvas rather than building a widget for every
/// line, so a fast stream of messages and a history of tens of thousands of
/// entries cost the same frame. Log entries never go through `setState`: write
/// to the [LogViewerController]'s store, or to the store you passed it, and the
/// next frame draws them.
///
/// Give the widget a height, through its parent.
class LogViewer extends StatefulWidget {
  /// Creates a viewer.
  const LogViewer({
    this.controller,
    this.store,
    this.options = const LogViewerOptions(),
    super.key,
  });

  /// The state to show, for an application that holds its own.
  ///
  /// Without it the widget makes one, over [store] when there is one, and
  /// disposes of it with itself. Either way [options] is what configures it: a
  /// controller is the viewer's state, not its settings, so passing one and then
  /// changing an option here changes the viewer.
  final LogViewerController? controller;

  /// A store to show. Several viewers can share one.
  final LogStore? store;

  /// How the viewer looks and what it offers.
  final LogViewerOptions options;

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  /// The layer the viewer's own menus and dialogs are drawn on.
  ///
  /// Held by key rather than looked up, because this state is above the host
  /// rather than inside it.
  final GlobalKey<LognalPopupHostState> _popups = GlobalKey<LognalPopupHostState>();
  LogViewerController? _own;

  LogViewerController get _controller => widget.controller ?? _own!;

  @override
  void initState() {
    super.initState();
    _holdBrowserContextMenu();

    if (widget.controller == null) {
      _own = LogViewerController(store: widget.store, options: widget.options);
    } else {
      widget.controller!.setOptions(widget.options);
    }
  }

  @override
  void didUpdateWidget(LogViewer old) {
    super.didUpdateWidget(old);

    if (widget.controller == null && _own == null) {
      _own = LogViewerController(store: widget.store, options: widget.options);
    }

    if (widget.controller != null && _own != null) {
      _own!.dispose();
      _own = null;
    }

    if (!identical(widget.options, old.options) || widget.controller != old.controller) {
      _controller.setOptions(widget.options);
    }
  }

  @override
  void dispose() {
    _releaseBrowserContextMenu();
    _own?.dispose();
    super.dispose();
  }

  FontSettings _resolveFont(LogViewerOptions options) {
    final FontSettings font = options.font;

    if (font.family != null) {
      return font;
    }

    final List<String> platform = kIsWeb
        ? _webFamilies
        : _monospaceFamilies[defaultTargetPlatform] ?? const <String>['monospace'];

    return font.copyWith(
      family: platform.first,
      fallbackFamilies: font.fallbackFamilies.isNotEmpty
          ? font.fallbackFamilies
          : <String>[...platform.skip(1), ..._cjkFamilies],
    );
  }

  Future<void> _openEntryMenu(int entryId, Offset position) async {
    final LogViewerController controller = _controller;
    final LognalTheme theme = _theme(context, controller);
    final ViewerLabels labels = controller.options.resolvedLabels;
    final LogEntry? entry = controller.store.get(entryId);

    if (entry == null) {
      return;
    }

    controller.setMenuEntry(entryId);
    await showLognalMenu(
      host: _popups.currentState,
      position: position,
      theme: theme.chrome,
      items: _entryMenuItems(controller, entry, labels),
    );

    if (mounted) {
      controller.setMenuEntry(null);
    }
  }

  List<PopupItem> _entryMenuItems(
    LogViewerController controller,
    LogEntry entry,
    ViewerLabels labels,
  ) {
    final EntryMenuOptions menu = controller.options.entryMenu;
    final List<int> ids =
        controller.options.selectionMode == SelectionMode.entry &&
            controller.selectedEntries.contains(entry.id)
        ? controller.selectedEntryIds
        : <int>[entry.id];
    final List<PopupItem> items = <PopupItem>[
      if (menu.copy) ...<PopupItem>[
        PopupItem(
          label: labels.copyEntry,
          icon: LognalIcon.copy,
          onSelect: () => controller.copyEntries(ids).ignore(),
        ),
        PopupItem(
          label: labels.copyEntryWithTime,
          icon: LognalIcon.clock,
          onSelect: () =>
              controller.copyEntries(ids, const EntryTextOptions(timestamp: true)).ignore(),
        ),
        PopupItem(
          label: labels.copyEntryFormatted,
          icon: LognalIcon.code,
          onSelect: () => controller
              .copyEntries(ids, const EntryTextOptions(format: EntryTextFormat.formatted))
              .ignore(),
        ),
        PopupItem(
          label: labels.copyEntryData,
          icon: LognalIcon.braces,
          onSelect: () => controller
              .copyEntries(ids, const EntryTextOptions(format: EntryTextFormat.data))
              .ignore(),
        ),
      ],
      if (controller.layout.hasExpandableValues(entry)) ...<PopupItem>[
        PopupItem(
          label: labels.expandAll,
          icon: LognalIcon.expandAll,
          separatorBefore: menu.copy,
          onSelect: () => controller.expandEntry(entry.id),
        ),
        PopupItem(
          label: labels.collapseAll,
          icon: LognalIcon.collapseAll,
          onSelect: () => controller.collapseEntry(entry.id),
        ),
      ],
      if (controller.store.isRunHead(entry))
        PopupItem(
          label: entry.collapsed ? labels.expandRepeats : labels.collapseRepeats,
          icon: entry.collapsed ? LognalIcon.expandAll : LognalIcon.collapseAll,
          separatorBefore: true,
          onSelect: () => controller.store.setCollapsed(entry.id, !entry.collapsed),
        ),
      ...controller.layout
          .linksOf(entry.id)
          .take(maxMenuLinks)
          .map(
            (String url) => PopupItem(
              label: labels.openLink(url),
              icon: LognalIcon.link,
              separatorBefore: url == controller.layout.linksOf(entry.id).first,
              onSelect: () => _tapLink(url, direct: true),
            ),
          ),
    ];
    final List<EntryMenuItem> Function(LogEntry)? own = menu.items;

    if (own != null) {
      final List<EntryMenuItem> extra = own(entry);

      for (int index = 0; index < extra.length; index++) {
        items.add(
          PopupItem(
            label: extra[index].label,
            separatorBefore: index == 0,
            onSelect: () => extra[index].onSelect(entry),
          ),
        );
      }
    }

    return items;
  }

  Future<void> _tapLink(String url, {required bool direct}) async {
    final LogViewerController controller = _controller;

    if (controller.options.linkClick == LinkClick.ignore) {
      return;
    }

    if (direct || controller.options.linkClick == LinkClick.open) {
      controller.openLink(url);

      return;
    }

    await showLinkDialog(
      host: _popups.currentState,
      theme: _theme(context, controller).chrome,
      labels: controller.options.resolvedLabels,
      url: url,
      onOpen: () => controller.openLink(url),
    );
  }

  Future<void> _openMute() async {
    final LogViewerController controller = _controller;

    await showMuteDialog(
      host: _popups.currentState,
      controller: controller,
      theme: _theme(context, controller).chrome,
      labels: controller.options.resolvedLabels,
    );
  }

  LognalTheme _theme(BuildContext context, LogViewerController controller) {
    return controller.options.resolveTheme(
      controller.themeName,
      MediaQuery.platformBrightnessOf(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) => _getViewerWidget(context),
    );
  }

  Widget _getViewerWidget(BuildContext context) {
    final LogViewerController controller = _controller;
    final LogViewerOptions options = controller.options;
    final LognalTheme theme = _theme(context, controller);
    final ViewerLabels labels = options.resolvedLabels;
    final FontSettings font = _resolveFont(options);
    final InputOptions? input = options.input;

    return Semantics(
      container: true,
      label: labels.viewer,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.chrome.background,
          border: Border.all(color: theme.chrome.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LognalPopupHost(
            key: _popups,
            child: Column(
              children: <Widget>[
                if (options.toolbar.visible)
                  LognalToolbar(
                    controller: controller,
                    theme: theme,
                    labels: labels,
                    onOpenMute: _openMute,
                  ),
                if (controller.isSearchOpen)
                  LognalSearchBar(controller: controller, theme: theme, labels: labels),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: LogSurface(
                          controller: controller,
                          theme: theme,
                          font: font,
                          labels: labels,
                          onEntryMenu: _openEntryMenu,
                          onLinkTap: (String url, {required bool direct}) =>
                              _tapLink(url, direct: direct),
                        ),
                      ),
                      if (controller.hasUnseen)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: _NewLogsButton(
                            theme: theme,
                            label: labels.newLogs,
                            onPressed: controller.scrollToBottom,
                          ),
                        ),
                    ],
                  ),
                ),
                if (input != null)
                  LognalInputLine(
                    controller: controller,
                    options: input,
                    theme: theme,
                    font: font,
                    labels: labels,
                  ),
                if (options.statusBar)
                  LognalStatusBar(controller: controller, theme: theme, labels: labels),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The button that appears when entries arrive while the view is scrolled up.
class _NewLogsButton extends StatelessWidget {
  const _NewLogsButton({required this.theme, required this.label, required this.onPressed});

  final LognalTheme theme;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.chrome.accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(color: theme.chrome.shadow, blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LognalIconView(icon: LognalIcon.bottom, color: theme.chrome.onAccent, size: 14),
              const SizedBox(width: 6),
              LognalText(label, color: theme.chrome.onAccent, weight: FontWeight.w600),
            ],
          ),
        ),
      ),
    );
  }
}
