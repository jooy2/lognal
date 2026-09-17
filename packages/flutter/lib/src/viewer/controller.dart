import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/search.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/text/measure.dart';
import 'package:lognal/src/core/time.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/data.dart';
import 'package:lognal/src/core/value/text.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/sources/console/capture.dart' show captureValue;
import 'package:lognal/src/viewer/options.dart';

/// Padding around the text, in logical pixels.
const double paddingLeft = 8;

/// Space kept on the right of the content.
const double paddingRight = 16;

/// Space above the first row.
const double paddingTop = 4;

/// Space below the last row.
const double paddingBottom = 8;

/// Cells of the column with the level marker.
const int markerCells = 3;

/// How close to the bottom, in logical pixels, still counts as following.
const double followThreshold = 4;

/// The most entries laid out exactly when a frame starts. Past it, row counts
/// are estimated.
const int syncBudget = 2000;

/// Rows laid out exactly above and below the view, so a short scroll finds them
/// ready.
const int measureMarginRows = 50;

/// How long one slice of a search may run, and how many entries it takes at a
/// time.
const Duration searchSlice = Duration(milliseconds: 8);
const int _searchBatch = 200;

/// The same, for laying out entries in the background.
const int _measureBatch = 200;

/// The most links of an entry that its menu offers to open.
const int maxMenuLinks = 5;

/// Where the text selection starts and where it currently reaches.
class TextSelectionRange {
  /// Creates a range.
  const TextSelectionRange(this.anchor, this.head);

  /// Where the selection started.
  final LogPosition anchor;

  /// Where it currently reaches.
  final LogPosition head;
}

/// The row at the top of the view, kept when rows above it change height.
class ViewAnchor {
  /// Creates an anchor.
  const ViewAnchor({required this.entryId, required this.entryRow, required this.offset});

  /// The entry the top row belongs to.
  final int entryId;

  /// The row within that entry.
  final int entryRow;

  /// The distance from the top of the view to the top of the row, zero or
  /// negative.
  final double offset;
}

/// What sits under a point of the log.
class HitTest {
  /// Creates a hit.
  const HitTest({required this.row, required this.column, this.visualRow, this.action});

  /// The row index, counted from the first visible row of the log.
  final int row;

  /// The column, counted from the start of the content area.
  final int column;

  /// The row itself, when the point is on one.
  final VisualRow? visualRow;

  /// What a tap there would do, if anything.
  final LineAction? action;
}

int _comparePositions(LogPosition a, LogPosition b) {
  if (a.entryId != b.entryId) {
    return a.entryId - b.entryId;
  }

  return a.line != b.line ? a.line - b.line : a.cell - b.cell;
}

/// Everything a viewer knows: the log, how it is laid out, what is selected and
/// where the view is.
///
/// It is a [ChangeNotifier] so the widgets that draw the viewer rebuild when it
/// changes, and it can be held by the application, which is how log entries
/// reach the viewer without a rebuild: write to [store], and the next frame
/// draws them.
class LogViewerController extends ChangeNotifier {
  /// Creates a controller, over a store of its own or one you already have.
  LogViewerController({LogStore? store, LogViewerOptions options = const LogViewerOptions()})
    : _options = options,
      _themeName = options.theme,
      _following = options.follow,
      store = store ?? LogStore(options: options.core.storeOptions) {
    this.store.options = options.core.storeOptions;
    layout = LogLayout(this.store, options: options.core.layoutOptions);
    search = LogSearch(layout);
    _filter = options.core.filter;
    layout.setFilter(_filter);
    _unsubscribe = this.store.subscribe(_onStoreChange);
  }

  /// The entries the viewer shows.
  final LogStore store;

  /// How those entries are turned into rows.
  late final LogLayout layout;

  /// The search over the log, which highlights without hiding.
  late final LogSearch search;

  LogViewerOptions _options;
  late final void Function() _unsubscribe;
  bool _following;
  bool _hasUnseen = false;
  double _topPixels = 0;
  double _scrollX = 0;
  CellMetrics _metrics = const CellMetrics(width: 8, height: 20, baseline: 14);
  Size _size = Size.zero;
  int _columns = 1;
  LogFilter? _filter;
  WrapMode _wrapMode = WrapMode.word;
  TextSelectionRange? _selection;
  Set<int> _selectedEntries = <int>{};
  int? _focusedEntryId;
  int? _anchorEntryId;
  bool _showEntryFocus = false;
  int? _hoverEntryId;
  int? _menuEntryId;
  bool _searchOpen = false;
  String _themeName;
  Timer? _searchTimer;
  Timer? _measureTimer;
  bool _disposed = false;

  /// The options in use.
  LogViewerOptions get options => _options;

  /// Whether the view follows new entries.
  bool get isFollowing => _following;

  /// Whether entries arrived while the view was scrolled up.
  bool get hasUnseen => _hasUnseen;

  /// The distance from the top of the log to the top of the view, in pixels.
  double get topPixels => _topPixels;

  /// How far the content is scrolled sideways, in pixels.
  double get scrollX => _scrollX;

  /// The size of one cell of the text grid.
  CellMetrics get metrics => _metrics;

  /// The size of the log area.
  Size get size => _size;

  /// How many columns a row wraps into.
  int get columns => _columns;

  /// The filter in use.
  LogFilter? get filter => _filter;

  /// The selected text, or `null` when nothing is selected.
  TextSelectionRange? get selection => _selection;

  /// The ids of the entries selected in entry mode.
  Set<int> get selectedEntries => _selectedEntries;

  /// The entry the keyboard moves from in entry mode.
  int? get focusedEntryId => _focusedEntryId;

  /// Whether that entry is outlined, which only the keyboard turns on.
  bool get showEntryFocus => _showEntryFocus;

  /// The entry under the pointer.
  int? get hoverEntryId => _hoverEntryId;

  /// The entry whose menu is open.
  int? get menuEntryId => _menuEntryId;

  /// Whether the search bar is open.
  bool get isSearchOpen => _searchOpen;

  /// The name of the palette in use, which may be `auto`.
  String get themeName => _themeName;

  /// The height of the whole log in pixels.
  double get contentHeight {
    return layout.rowCount * _metrics.height + paddingTop + paddingBottom;
  }

  /// The width of the widest row in pixels, including the gutter and padding.
  double get contentWidth {
    return contentLeft + layout.maxCells * _metrics.width + paddingRight;
  }

  /// How far the content can scroll sideways.
  double get maxScrollX => math.max(0, contentWidth - _size.width);

  /// How far the view can scroll down.
  double get maxTopPixels => math.max(0, contentHeight - _size.height);

  /// Cells taken by the timestamp column, or 0 when timestamps are hidden.
  int get timestampCells {
    if (!_options.timestamps) {
      return 0;
    }

    final DateTime sample = DateTime(2026, 12, 31, 23, 59, 59, 999);

    return measureCells(formatTime(sample)) + 1;
  }

  /// Where the content of a row starts, in pixels.
  double get contentLeft {
    return paddingLeft + (timestampCells + markerCells) * _metrics.width;
  }

  /// Writes the time of an entry the way the options ask for.
  String formatTime(DateTime time) {
    final String Function(DateTime)? own = _options.formatTimestamp;

    return own != null ? own(time) : formatTimestamp(time, _options.timestampFormat);
  }

  /// Replaces the options. Only what changed is applied.
  ///
  /// It is called on every rebuild of the widget, so it must not report a change
  /// that did not happen: a listener that redraws on every call would redraw on
  /// every frame.
  void setOptions(LogViewerOptions next) {
    final LogViewerOptions previous = _options;

    if (identical(next, previous)) {
      return;
    }

    _options = next;
    store.options = next.core.storeOptions;
    layout.options = next.core.layoutOptions;

    if (next.core.filter != previous.core.filter) {
      setFilter(next.core.filter);
    }

    // The theme the toolbar chose stays chosen; only a new value in the options
    // replaces it.
    if (next.theme != previous.theme) {
      _themeName = next.theme;
    }

    if (next.selectionMode != previous.selectionMode) {
      clearSelection();
    }

    notifyListeners();
  }

  /// Adds text as one entry.
  void write(String text, [WriteOptions options = const WriteOptions()]) {
    store.write(text, options);
  }

  /// Adds text as one entry per line.
  void writeLines(String text, [WriteOptions options = const WriteOptions()]) {
    store.writeLines(text, options);
  }

  /// Removes every entry.
  void clear() {
    store.clear();
    clearSelection();
    _hasUnseen = false;
    _topPixels = 0;
    notifyListeners();
  }

  /// Sets which entries are shown.
  void setFilter(LogFilter? filter) {
    _filter = filter;
    layout.setFilter(filter);
    clearSelection();
    notifyListeners();
  }

  /// The mute rules in use.
  List<MuteRule> get muteRules => _filter?.mute ?? const <MuteRule>[];

  /// Replaces the mute rules, keeping the rest of the filter.
  void setMuteRules(List<MuteRule> rules) {
    setFilter((_filter ?? const LogFilter()).copyWith(mute: rules));
  }

  /// How many of the entries the store holds the mute rules hide.
  ///
  /// Reading it lays out whatever changed since the last frame, because the
  /// count is drawn in the toolbar during a build and the painting that would
  /// otherwise do the laying out happens after it.
  int get mutedCount {
    layout.sync(budget: syncBudget);

    return layout.mutedCount;
  }

  /// How many entries the viewer shows, of the ones the store holds.
  int get visibleCount {
    layout.sync(budget: syncBudget);

    return layout.visibleCount;
  }

  /// How many entries the store holds.
  int get entryCount => store.size;

  /// Turns following new entries on or off.
  void setFollowing(bool following) {
    if (_following == following) {
      return;
    }

    _following = following;

    if (following) {
      _hasUnseen = false;
      scrollToBottom();
    }

    notifyListeners();
  }

  /// Scrolls to the oldest entry and stops following.
  void scrollToTop() {
    _following = false;
    _topPixels = 0;
    notifyListeners();
  }

  /// Scrolls to the newest entry and starts following.
  void scrollToBottom() {
    layout.sync();
    _following = true;
    _hasUnseen = false;
    _topPixels = maxTopPixels;
    notifyListeners();
  }

  /// Brings an entry into view.
  void scrollToEntry(int entryId, {bool top = false}) {
    layout.sync();

    final int row = layout.rowOfEntry(entryId);

    if (row < 0) {
      return;
    }

    final double rowTop = row * _metrics.height + paddingTop;
    final double rowBottom = rowTop + layout.rowsOf(entryId) * _metrics.height;

    if (top || rowTop < _topPixels) {
      setTopPixels(rowTop - paddingTop);
    } else if (rowBottom > _topPixels + _size.height) {
      setTopPixels(rowBottom - _size.height + paddingBottom);
    }
  }

  /// Moves the view, and stops following once it leaves the bottom.
  void setTopPixels(double value) {
    final double next = value.clamp(0, maxTopPixels);

    if ((next - _topPixels).abs() < 0.01) {
      return;
    }

    _topPixels = next;
    _following = next >= maxTopPixels - followThreshold;

    if (_following) {
      _hasUnseen = false;
    }

    notifyListeners();
  }

  /// Scrolls the content sideways.
  void setScrollX(double value) {
    final double next = value.clamp(0, maxScrollX);

    if ((next - _scrollX).abs() < 0.01) {
      return;
    }

    _scrollX = next;
    notifyListeners();
  }

  /// Tells the controller how large the log area is and how big a cell is.
  ///
  /// Returns whether anything changed, so the widget can skip a repaint.
  bool setViewport(Size size, CellMetrics metrics) {
    if (size == _size && metrics == _metrics) {
      return false;
    }

    final ViewAnchor? anchor = _anchorAt(_topPixels);

    _size = size;
    _metrics = metrics;
    _columns = math.max(1, ((size.width - contentLeft - paddingRight) / metrics.width).floor());
    layout.columns = _columns;
    layout.sync(budget: syncBudget);

    if (_following) {
      _topPixels = maxTopPixels;
    } else if (anchor != null) {
      _restoreAnchor(anchor);
    }

    return true;
  }

  /// Lays out the rows on screen exactly, and returns them with their
  /// decorations.
  RenderFrame frame() {
    layout.sync(budget: syncBudget);
    _settleScroll();

    final double rowHeight = _metrics.height;
    final int total = layout.rowCount;
    final int first = math.max(0, ((_topPixels - paddingTop) / rowHeight).floor());
    final int count = math.min(total - first, (_size.height / rowHeight).ceil() + 2);
    final List<VisualRow> rows = count > 0 ? layout.getRows(first, count) : <VisualRow>[];

    if (rows.isNotEmpty && layout.pendingCount > 0) {
      layout.measureAround(rows.first.entry.id, measureMarginRows, count + measureMarginRows);
    }

    _scheduleMeasure();

    return RenderFrame(
      rows: rows,
      decorations: rows.map(decorationFor).toList(),
      offsetY: paddingTop + first * rowHeight - _topPixels,
      scrollX: _scrollX,
      paddingLeft: paddingLeft,
      timestampCells: timestampCells,
      markerCells: markerCells,
      formatTime: formatTime,
    );
  }

  /// Puts the scroll offset back inside the content, which is the last moment
  /// the height of that content is known.
  ///
  /// Anything that leaves fewer rows behind moves the bottom of the log up: a
  /// filter, a mute rule, a collapsed value, a narrower viewer. None of them
  /// can put the offset right where they happen, because the rows they remove
  /// are laid out later, in slices. So the frame is where it is settled, which
  /// is also where the JavaScript viewer settles it.
  void _settleScroll() {
    final double max = maxTopPixels;

    if (_following) {
      _topPixels = max;
    } else if (_topPixels > max) {
      _topPixels = max;
    }
  }

  /// The highlights on one row.
  RowDecoration decorationFor(VisualRow row) {
    final int entryId = row.entry.id;
    final bool hovered = entryId == _hoverEntryId || entryId == _menuEntryId;
    final bool entrySelected =
        _options.selectionMode == SelectionMode.entry && _selectedEntries.contains(entryId);
    final bool entryFocused =
        _options.selectionMode == SelectionMode.entry &&
        _showEntryFocus &&
        entryId == _focusedEntryId;

    return RowDecoration(
      selection: _selectionOn(row),
      matches: _matchesOn(row, layout.filter.pattern),
      hovered: hovered,
      searchMatches: _searchOn(row, current: false),
      searchCurrent: _searchOn(row, current: true).firstOrNull,
      entrySelected: entrySelected,
      entryFocused: entryFocused,
    );
  }

  /// Where a point of the log area falls.
  HitTest hitTest(Offset point) {
    final double rowHeight = _metrics.height;
    final int row = ((point.dy + _topPixels - paddingTop) / rowHeight).floor();
    final int column = ((point.dx - contentLeft + _scrollX) / _metrics.width).floor();

    if (row < 0 || row >= layout.rowCount) {
      return HitTest(row: row, column: column);
    }

    final List<VisualRow> rows = layout.getRows(row, 1);

    if (rows.isEmpty) {
      return HitTest(row: row, column: column);
    }

    final VisualRow visualRow = rows.first;
    final int cell = column - visualRow.indent;
    LineAction? action;
    int offset = 0;

    for (final RowRun run in visualRow.runs) {
      if (cell >= offset && cell < offset + run.cells) {
        action = run.action;
        break;
      }

      offset += run.cells;
    }

    return HitTest(row: row, column: column, visualRow: visualRow, action: action);
  }

  /// The text position under a point, or `null` when the log is empty.
  LogPosition? positionAt(Offset point) {
    final double rowHeight = _metrics.height;
    final int row = ((point.dy + _topPixels - paddingTop) / rowHeight).floor();
    final int column = ((point.dx - contentLeft + _scrollX) / _metrics.width).round();

    return layout.positionAt(row, column);
  }

  /// Runs what a tap on a span does. Opening a link goes through
  /// [LogViewerOptions.onOpenLink].
  void runAction(int entryId, LineAction action) {
    if (action is OpenLinkAction) {
      openLink(action.url);

      return;
    }

    layout.runAction(entryId, action);
    notifyListeners();
  }

  /// Opens a link, unless the options say not to.
  void openLink(String url) {
    if (_options.linkClick == LinkClick.ignore) {
      return;
    }

    _options.onOpenLink?.call(url);
  }

  /// Expands every value of an entry.
  void expandEntry(int entryId) {
    layout.expandAll(entryId);
    notifyListeners();
  }

  /// Collapses every value of an entry.
  void collapseEntry(int entryId) {
    layout.collapseAll(entryId);
    notifyListeners();
  }

  /// Sets where a text selection starts, and clears it.
  void startSelection(LogPosition position) {
    _selection = TextSelectionRange(position, position);
    notifyListeners();
  }

  /// Moves the end of a text selection.
  void extendSelection(LogPosition position) {
    final TextSelectionRange? current = _selection;

    if (current == null) {
      return;
    }

    _selection = TextSelectionRange(current.anchor, position);
    notifyListeners();
  }

  /// Selects the word at a position.
  void selectWordAt(LogPosition position) {
    final List<LogPosition>? word = layout.wordAt(position);

    if (word == null) {
      return;
    }

    _selection = TextSelectionRange(word[0], word[1]);
    notifyListeners();
  }

  /// Selects everything the viewer shows.
  void selectAll() {
    layout.sync();

    if (_options.selectionMode == SelectionMode.entry) {
      _selectedEntries = <int>{
        for (int index = 0; index < layout.visibleCount; index++) layout.entryAt(index)!.id,
      };
      notifyListeners();

      return;
    }

    final LogEntry? first = layout.entryAt(0);
    final LogEntry? last = layout.entryAt(layout.visibleCount - 1);

    if (first == null || last == null) {
      return;
    }

    _selection = TextSelectionRange(
      LogPosition(entryId: first.id, line: 0, cell: 0),
      LogPosition(entryId: last.id, line: 1 << 30, cell: 1 << 30),
    );
    notifyListeners();
  }

  /// Clears whatever is selected.
  void clearSelection() {
    if (_selection == null && _selectedEntries.isEmpty) {
      return;
    }

    _selection = null;
    _selectedEntries = <int>{};
    notifyListeners();
  }

  /// Replaces the set of selected entries.
  void setSelectedEntries(Set<int> ids) {
    _selectedEntries = ids;
    notifyListeners();
  }

  /// Moves the entry the keyboard works from.
  void setFocusedEntry(int? entryId, {bool showFocus = true}) {
    _focusedEntryId = entryId;
    _showEntryFocus = showFocus;
    notifyListeners();
  }

  /// Sets where a range selection of entries starts.
  void setEntryAnchor(int? entryId) => _anchorEntryId = entryId;

  /// Where a range selection of entries starts.
  int? get entryAnchorId => _anchorEntryId;

  /// Sets the entry under the pointer.
  void setHoverEntry(int? entryId) {
    if (_hoverEntryId == entryId) {
      return;
    }

    _hoverEntryId = entryId;
    notifyListeners();
  }

  /// Sets the entry whose menu is open.
  void setMenuEntry(int? entryId) {
    if (_menuEntryId == entryId) {
      return;
    }

    _menuEntryId = entryId;
    notifyListeners();
  }

  /// The text of whatever is selected.
  String selectionText([EntryTextOptions options = const EntryTextOptions()]) {
    if (_options.selectionMode == SelectionMode.entry) {
      return entriesText(selectedEntryIds, options);
    }

    final TextSelectionRange? range = _selection;

    if (range == null || _comparePositions(range.anchor, range.head) == 0) {
      return '';
    }

    return layout.getText(range.anchor, range.head);
  }

  /// The ids of the selected entries, oldest first.
  List<int> get selectedEntryIds {
    if (_options.selectionMode == SelectionMode.entry) {
      final List<int> ids = _selectedEntries.toList()..sort();

      return ids;
    }

    final TextSelectionRange? range = _selection;

    if (range == null) {
      return <int>[];
    }

    final int from = math.min(range.anchor.entryId, range.head.entryId);
    final int to = math.max(range.anchor.entryId, range.head.entryId);
    final List<int> ids = <int>[];

    for (int index = layout.indexFrom(from); index < layout.visibleCount; index++) {
      final LogEntry? entry = layout.entryAt(index);

      if (entry == null || entry.id > to) {
        break;
      }

      ids.add(entry.id);
    }

    return ids;
  }

  /// The text of one entry.
  String entryText(int entryId, [EntryTextOptions options = const EntryTextOptions()]) {
    final LogEntry? entry = store.get(entryId);

    if (entry == null) {
      return '';
    }

    if (options.format == EntryTextFormat.data) {
      return formatEntryData(entry);
    }

    final String text = formatEntryText(
      entry,
      ValueTextOptions(multiline: options.format == EntryTextFormat.formatted),
    );

    return options.timestamp ? '${formatTime(entry.time)} $text' : text;
  }

  /// The text of several entries, one per line.
  String entriesText(List<int> entryIds, [EntryTextOptions options = const EntryTextOptions()]) {
    if (options.format == EntryTextFormat.data) {
      final List<LogEntry> entries = entryIds.map(store.get).whereType<LogEntry>().toList();

      return formatEntriesData(entries);
    }

    return entryIds.map((int id) => entryText(id, options)).join('\n');
  }

  /// Puts the selection on the clipboard. Returns whether anything was copied.
  Future<bool> copySelection([EntryTextOptions options = const EntryTextOptions()]) {
    return _copy(selectionText(options));
  }

  /// Puts one entry on the clipboard.
  Future<bool> copyEntry(int entryId, [EntryTextOptions options = const EntryTextOptions()]) {
    return _copy(entryText(entryId, options));
  }

  /// Puts several entries on the clipboard.
  Future<bool> copyEntries(
    List<int> entryIds, [
    EntryTextOptions options = const EntryTextOptions(),
  ]) {
    return _copy(entriesText(entryIds, options));
  }

  Future<bool> _copy(String text) async {
    if (text.isEmpty) {
      return false;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));

      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the search bar, with a query to start from.
  void openSearch([String? query, SearchOptions options = const SearchOptions()]) {
    _searchOpen = true;

    if (query != null) {
      search.setQuery(query, options);
      _scheduleSearch();
    }

    notifyListeners();
  }

  /// Closes the search bar and forgets the matches.
  void closeSearch() {
    if (!_searchOpen) {
      return;
    }

    _searchOpen = false;
    search.setQuery('');
    _searchTimer?.cancel();
    notifyListeners();
  }

  /// Changes what the search looks for.
  void setSearchQuery(String query, [SearchOptions options = const SearchOptions()]) {
    if (search.setQuery(query, options)) {
      _scheduleSearch();
      notifyListeners();
    }
  }

  /// Moves to the next match and brings it into view.
  void findNext() => _reveal(search.next());

  /// Moves to the previous match and brings it into view.
  void findPrevious() => _reveal(search.previous());

  /// Captures a value the way a logged one is captured, under the options in
  /// use. The input line prints a reply through this.
  ValueNode capture(Object? value) => captureValue(value);

  /// Draws the viewer again, for a change the controller cannot see.
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _measureTimer?.cancel();
    _unsubscribe();
    layout.dispose();
    super.dispose();
  }

  void _reveal(TextMatch? match) {
    if (match == null) {
      return;
    }

    scrollToEntry(match.entryId);

    final PositionLocation? location = layout.locatePosition(
      LogPosition(entryId: match.entryId, line: match.line, cell: match.from),
    );

    if (location != null) {
      final int row = layout.rowOfEntry(match.entryId) + location.entryRow;
      final double rowTop = row * _metrics.height + paddingTop;

      if (rowTop < _topPixels || rowTop + _metrics.height > _topPixels + _size.height) {
        setTopPixels(rowTop - _size.height / 3);
      }
    }

    notifyListeners();
  }

  void _onStoreChange(StoreChange change) {
    if (_disposed) {
      return;
    }

    if (change is StoreAppend && !_following) {
      _hasUnseen = true;
    }

    if (_searchOpen) {
      _scheduleSearch();
    }

    notifyListeners();
  }

  void _scheduleSearch() {
    if (_searchTimer != null || _disposed) {
      return;
    }

    _searchTimer = Timer(Duration.zero, () {
      _searchTimer = null;

      if (_disposed) {
        return;
      }

      final Stopwatch clock = Stopwatch()..start();
      bool changed = false;

      layout.sync(budget: syncBudget);

      while (search.pending && clock.elapsed < searchSlice) {
        changed = search.scan(_searchBatch) || changed;
      }

      if (changed) {
        notifyListeners();
      }

      if (search.pending) {
        _scheduleSearch();
      }
    });
  }

  void _scheduleMeasure() {
    if (_measureTimer != null || layout.pendingCount == 0 || _disposed) {
      return;
    }

    _measureTimer = Timer(const Duration(milliseconds: 16), () {
      _measureTimer = null;

      if (_disposed) {
        return;
      }

      final LogEntry? top = layout.entryAt(0);
      final bool moved = layout.measurePending(_measureBatch, top?.id);

      if (moved && _following) {
        _topPixels = maxTopPixels;
      }

      if (moved) {
        notifyListeners();
      }

      _scheduleMeasure();
    });
  }

  ViewAnchor? _anchorAt(double topPixels) {
    final int row = ((topPixels - paddingTop) / _metrics.height).floor();
    final RowLocation? location = layout.locateRow(math.max(0, row));

    if (location == null) {
      return null;
    }

    return ViewAnchor(
      entryId: location.entry.id,
      entryRow: location.entryRow,
      offset: topPixels - (row * _metrics.height + paddingTop),
    );
  }

  void _restoreAnchor(ViewAnchor anchor) {
    final int row = layout.rowOfEntry(anchor.entryId);

    if (row < 0) {
      return;
    }

    _topPixels = ((row + anchor.entryRow) * _metrics.height + paddingTop + anchor.offset).clamp(
      0,
      maxTopPixels,
    );
  }

  List<int>? _selectionOn(VisualRow row) {
    final TextSelectionRange? range = _selection;

    if (range == null || _options.selectionMode == SelectionMode.entry) {
      return null;
    }

    final bool inOrder = _comparePositions(range.anchor, range.head) <= 0;
    final LogPosition start = inOrder ? range.anchor : range.head;
    final LogPosition end = inOrder ? range.head : range.anchor;

    if (row.entry.id < start.entryId || row.entry.id > end.entryId) {
      return null;
    }

    if (row.entry.id == start.entryId && row.line < start.line) {
      return null;
    }

    if (row.entry.id == end.entryId && row.line > end.line) {
      return null;
    }

    final int rowStart = row.startCell;
    final int rowEnd = row.startCell + row.cells;
    final bool isStartLine = row.entry.id == start.entryId && row.line == start.line;
    final bool isEndLine = row.entry.id == end.entryId && row.line == end.line;
    final int from = isStartLine ? math.max(rowStart, start.cell) : rowStart;
    final int to = isEndLine ? math.min(rowEnd, end.cell) : rowEnd;

    if (to <= from) {
      return null;
    }

    return <int>[row.indent + from - rowStart, row.indent + to - rowStart];
  }

  List<List<int>> _matchesOn(VisualRow row, RegExp? pattern) {
    if (pattern == null) {
      return const <List<int>>[];
    }

    return _rangesOn(row, layout.findInEntry(row.entry, pattern, 200));
  }

  List<List<int>> _searchOn(VisualRow row, {required bool current}) {
    final List<TextMatch>? matches = search.matchesOf(row.entry.id);

    if (matches == null) {
      return const <List<int>>[];
    }

    final TextMatch? active = search.getMatch(search.current);
    final List<TextMatch> wanted = matches.where((TextMatch match) {
      final bool isCurrent =
          active != null &&
          active.entryId == match.entryId &&
          active.line == match.line &&
          active.from == match.from;

      return isCurrent == current;
    }).toList();

    return _rangesOn(row, wanted);
  }

  List<List<int>> _rangesOn(VisualRow row, List<TextMatch> matches) {
    final List<List<int>> ranges = <List<int>>[];
    final int rowStart = row.startCell;
    final int rowEnd = row.startCell + row.cells;

    for (final TextMatch match in matches) {
      if (match.line != row.line || match.to <= rowStart || match.from >= rowEnd) {
        continue;
      }

      final int from = math.max(match.from, rowStart);
      final int to = math.min(match.to, rowEnd);

      ranges.add(<int>[row.indent + from - rowStart, row.indent + to - rowStart]);
    }

    return ranges;
  }

  /// The wrap mode the wrap button goes back to when it is turned on again.
  WrapMode get lastWrapMode => _wrapMode;

  /// Turns line wrapping on or off from the toolbar.
  void toggleWrap() {
    final WrapMode current = layout.options.wrap;

    if (current != WrapMode.none) {
      _wrapMode = current;
    }

    layout.options = layout.options.copyWith(
      wrap: current == WrapMode.none ? _wrapMode : WrapMode.none,
    );
    notifyListeners();
  }

  /// Picks a palette by name, or `auto` to follow the platform.
  void setTheme(String name) {
    if (_themeName == name) {
      return;
    }

    _themeName = name;
    notifyListeners();
  }
}
