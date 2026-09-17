import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/text/width.dart';
import 'package:lognal/src/core/time.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/theme/palettes.dart' as palettes;
import 'package:lognal/src/theme/palettes.dart' show LognalTheme;
import 'package:lognal/src/viewer/labels.dart';

/// Options that belong to the core: what is kept, how it is laid out, and what
/// is shown.
class CoreOptions {
  /// Creates the core options.
  const CoreOptions({
    this.maxEntries = 10000,
    this.mergeRepeats = MergeRepeats.merge,
    this.wrap = WrapMode.word,
    this.tabSize = 8,
    this.ambiguousWidth = 1,
    this.maxClusters = 10000,
    this.links = true,
    this.filter,
  });

  /// The most entries the store keeps.
  final int maxEntries;

  /// What happens to a message identical to the one before it.
  final MergeRepeats mergeRepeats;

  /// How lines longer than the viewer are handled.
  final WrapMode wrap;

  /// Cells between tab stops.
  final int tabSize;

  /// Cells an East Asian Ambiguous character takes.
  final AmbiguousWidth ambiguousWidth;

  /// The most clusters a line keeps.
  final int maxClusters;

  /// Whether `http` and `https` addresses in text become links.
  final bool links;

  /// Which entries the viewer shows.
  final LogFilter? filter;

  /// The store options these carry.
  LogStoreOptions get storeOptions {
    return LogStoreOptions(maxEntries: maxEntries, mergeRepeats: mergeRepeats);
  }

  /// The layout options these carry.
  LayoutOptions get layoutOptions {
    return LayoutOptions(
      tabSize: tabSize,
      ambiguousWidth: ambiguousWidth,
      maxClusters: maxClusters,
      wrap: wrap,
      links: links,
    );
  }

  /// A copy with the fields given here replaced.
  CoreOptions copyWith({
    int? maxEntries,
    MergeRepeats? mergeRepeats,
    WrapMode? wrap,
    int? tabSize,
    AmbiguousWidth? ambiguousWidth,
    int? maxClusters,
    bool? links,
    LogFilter? filter,
    bool clearFilter = false,
  }) {
    return CoreOptions(
      maxEntries: maxEntries ?? this.maxEntries,
      mergeRepeats: mergeRepeats ?? this.mergeRepeats,
      wrap: wrap ?? this.wrap,
      tabSize: tabSize ?? this.tabSize,
      ambiguousWidth: ambiguousWidth ?? this.ambiguousWidth,
      maxClusters: maxClusters ?? this.maxClusters,
      links: links ?? this.links,
      filter: clearFilter ? null : filter ?? this.filter,
    );
  }
}

/// Which controls the toolbar shows.
///
/// Named for the viewer rather than for the toolbar, because `ToolbarOptions` is
/// already a name in `package:flutter/widgets.dart`.
class ViewerToolbarOptions {
  /// Creates the toolbar options.
  const ViewerToolbarOptions({
    this.visible = true,
    this.follow = true,
    this.clear = true,
    this.scroll = true,
    this.wrap = true,
    this.selectionMode = true,
    this.theme = true,
    this.mute = true,
    this.filter = true,
    this.levels = true,
  });

  /// The toolbar with nothing on it, which is how it is hidden.
  static const ViewerToolbarOptions hidden = ViewerToolbarOptions(visible: false);

  /// Whether the toolbar is there at all.
  final bool visible;

  /// The button that follows new logs.
  final bool follow;

  /// The button that removes every entry.
  final bool clear;

  /// The buttons that jump to the oldest and the newest entry.
  final bool scroll;

  /// The button that wraps long lines.
  final bool wrap;

  /// The button that switches between selecting text and selecting whole
  /// entries.
  final bool selectionMode;

  /// The button that opens the theme menu.
  final bool theme;

  /// The button that opens the dialog of hidden messages, with the count of
  /// hidden entries.
  final bool mute;

  /// The text filter field.
  final bool filter;

  /// The level menu.
  final bool levels;
}

/// A theme the toolbar menu offers.
class ThemeChoice {
  /// Creates a choice.
  const ThemeChoice(this.name, {this.label});

  /// What `theme` is set to, such as `dark`, `auto`, or a palette of your own.
  final String name;

  /// The text of the menu item. A built-in palette falls back to its built-in
  /// label.
  final String? label;
}

/// The input line, shown when something can answer the commands typed into it.
class InputOptions {
  /// Creates the input options.
  const InputOptions({
    required this.onSubmit,
    this.prompt = '>',
    this.placeholder,
    this.echo = true,
    this.historySize = 100,
  });

  /// Called with each command.
  ///
  /// A returned value, or the value a returned future completes with, is printed
  /// as the reply. Return `null` to print nothing, for example when the reply
  /// arrives later through `controller.write`.
  final Object? Function(String command) onSubmit;

  /// The prompt shown before the input.
  final String prompt;

  /// The hint inside the field, or `null` for the built-in one.
  final String? placeholder;

  /// Whether the command is added to the log before it runs.
  final bool echo;

  /// How many past commands the arrow keys go through.
  final int historySize;
}

/// An action in the menu of an entry.
class EntryMenuItem {
  /// Creates an item.
  const EntryMenuItem({required this.label, required this.onSelect});

  /// The text of the item.
  final String label;

  /// Called with the entry the menu was opened for, when the item is chosen.
  final void Function(LogEntry entry) onSelect;
}

/// The menu that opens from the button at the end of the entry under the
/// pointer.
class EntryMenuOptions {
  /// Creates the options.
  const EntryMenuOptions({this.visible = true, this.copy = true, this.items});

  /// The menu turned off.
  static const EntryMenuOptions hidden = EntryMenuOptions(visible: false);

  /// Whether the button is there at all.
  final bool visible;

  /// Whether the menu starts with the built-in copy items.
  final bool copy;

  /// Returns the items that follow the built-in ones, for the entry the menu
  /// opens for.
  final List<EntryMenuItem> Function(LogEntry entry)? items;
}

/// How `entryText` and `copyEntry` write an entry.
enum EntryTextFormat {
  /// Every value on one line.
  text,

  /// Values that are too long for one line broken over several lines.
  formatted,

  /// The values of the entry as JSON.
  data,
}

/// Options of `entryText` and `copyEntry`.
class EntryTextOptions {
  /// Creates the options.
  const EntryTextOptions({this.format = EntryTextFormat.text, this.timestamp = false});

  /// How the entry is written.
  final EntryTextFormat format;

  /// Whether the text starts with the time of the entry. Ignored for
  /// [EntryTextFormat.data].
  final bool timestamp;
}

/// What a tap on a link does.
enum LinkClick {
  /// A dialog shows the address and asks before the link opens.
  confirm,

  /// The link opens right away.
  open,

  /// Nothing happens. The link is still drawn as a link.
  ignore,
}

/// How the pointer and the keyboard select in the log.
enum SelectionMode {
  /// A drag selects text across entries, and a double tap selects a word.
  text,

  /// A tap selects a whole entry. The platform's multi-select modifier adds or
  /// removes one, Shift selects a range, and the arrow keys move from entry to
  /// entry.
  entry,
}

/// Everything a viewer can be configured with.
class LogViewerOptions {
  /// Creates the options.
  const LogViewerOptions({
    this.core = const CoreOptions(),
    this.theme = 'auto',
    this.themes,
    this.themeResolver,
    this.font = const FontSettings(),
    this.timestamps = true,
    this.timestampFormat = TimestampFormat.time,
    this.formatTimestamp,
    this.follow = true,
    this.toolbar = const ViewerToolbarOptions(),
    this.statusBar = true,
    this.input,
    this.locale,
    this.labels,
    this.entryMenu = const EntryMenuOptions(),
    this.search = true,
    this.linkClick = LinkClick.confirm,
    this.selectionMode = SelectionMode.text,
    this.tooltips = true,
    this.formatNumber = formatCount,
    this.onOpenLink,
  });

  /// Core options: what is kept, how it is laid out, and what is shown.
  final CoreOptions core;

  /// The palette: `auto`, a palette that ships with lognal, or a name of your
  /// own that [themeResolver] answers to.
  final String theme;

  /// The themes the menu in the toolbar offers. Defaults to `auto` and every
  /// built-in palette.
  final List<ThemeChoice>? themes;

  /// Returns the palette for a name of your own, or `null` to fall back.
  final LognalTheme? Function(String name)? themeResolver;

  /// The font the log is drawn with.
  final FontSettings font;

  /// Whether each entry shows its time.
  final bool timestamps;

  /// How the time is written, unless [formatTimestamp] replaces it.
  final TimestampFormat timestampFormat;

  /// Writes the time of an entry in your own format.
  final String Function(DateTime time)? formatTimestamp;

  /// Whether the view follows new entries at the start.
  final bool follow;

  /// The toolbar, or [ViewerToolbarOptions.hidden] to leave it out.
  final ViewerToolbarOptions toolbar;

  /// Whether the status bar is shown.
  final bool statusBar;

  /// The input line. Leave it out for a read-only viewer.
  final InputOptions? input;

  /// The language of the built-in labels, such as `en` or `ko`.
  final String? locale;

  /// Labels that replace the built-in ones.
  final ViewerLabels? labels;

  /// The menu of actions that opens from a button at the end of the entry under
  /// the pointer.
  final EntryMenuOptions entryMenu;

  /// Whether the find shortcut opens a bar that searches the log and highlights
  /// every match without hiding any entry.
  final bool search;

  /// What a tap on a link does. Links are the `http` and `https` addresses in
  /// the text, while `core.links` is on.
  final LinkClick linkClick;

  /// How the pointer and the keyboard select: text, or whole entries.
  final SelectionMode selectionMode;

  /// Whether a toolbar control shows its name in a label as soon as the pointer
  /// reaches it.
  final bool tooltips;

  /// Formats a count for the reader's language.
  final NumberFormatter formatNumber;

  /// Opens a link.
  ///
  /// Flutter has no way to open a URL without a plugin, and this package takes
  /// no dependencies, so opening one is the application's call — hand it
  /// `url_launcher`, or whatever else you already use. Without this, `linkClick`
  /// still draws links and still asks, and the answer goes nowhere.
  final void Function(String url)? onOpenLink;

  /// The labels in use: the ones passed in, or the built-in ones for [locale].
  ViewerLabels get resolvedLabels => labels ?? labelsFor(locale);

  /// The themes the menu offers.
  List<ThemeChoice> resolvedThemes(ViewerLabels labels) {
    return themes ??
        <ThemeChoice>[
          const ThemeChoice('auto'),
          ...palettes.builtInThemeNames.map(ThemeChoice.new),
        ];
  }

  /// The palette a name ends up meaning.
  LognalTheme resolveTheme(String name, Brightness platform) {
    if (name != 'auto') {
      final LognalTheme? own = themeResolver?.call(name);

      if (own != null) {
        return own;
      }
    }

    return palettes.resolveTheme(name, platform);
  }

  /// A copy with the fields given here replaced.
  LogViewerOptions copyWith({
    CoreOptions? core,
    String? theme,
    List<ThemeChoice>? themes,
    LognalTheme? Function(String name)? themeResolver,
    FontSettings? font,
    bool? timestamps,
    TimestampFormat? timestampFormat,
    String Function(DateTime time)? formatTimestamp,
    bool? follow,
    ViewerToolbarOptions? toolbar,
    bool? statusBar,
    InputOptions? input,
    String? locale,
    ViewerLabels? labels,
    EntryMenuOptions? entryMenu,
    bool? search,
    LinkClick? linkClick,
    SelectionMode? selectionMode,
    bool? tooltips,
    NumberFormatter? formatNumber,
    void Function(String url)? onOpenLink,
  }) {
    return LogViewerOptions(
      core: core ?? this.core,
      theme: theme ?? this.theme,
      themes: themes ?? this.themes,
      themeResolver: themeResolver ?? this.themeResolver,
      font: font ?? this.font,
      timestamps: timestamps ?? this.timestamps,
      timestampFormat: timestampFormat ?? this.timestampFormat,
      formatTimestamp: formatTimestamp ?? this.formatTimestamp,
      follow: follow ?? this.follow,
      toolbar: toolbar ?? this.toolbar,
      statusBar: statusBar ?? this.statusBar,
      input: input ?? this.input,
      locale: locale ?? this.locale,
      labels: labels ?? this.labels,
      entryMenu: entryMenu ?? this.entryMenu,
      search: search ?? this.search,
      linkClick: linkClick ?? this.linkClick,
      selectionMode: selectionMode ?? this.selectionMode,
      tooltips: tooltips ?? this.tooltips,
      formatNumber: formatNumber ?? this.formatNumber,
      onOpenLink: onOpenLink ?? this.onOpenLink,
    );
  }
}
