import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/entry_lines.dart';
import 'package:lognal/src/core/layout/row_index.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/text/normalize.dart';
import 'package:lognal/src/core/text/shape.dart';
import 'package:lognal/src/core/text/width.dart';
import 'package:lognal/src/core/text/wrap.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/preview.dart';

/// How a layout shapes text and breaks it into rows.
class LayoutOptions extends ShapeOptions {
  /// Creates the layout options.
  const LayoutOptions({
    super.tabSize,
    super.ambiguousWidth,
    super.maxClusters,
    this.wrap = WrapMode.word,
    this.links = true,
  });

  /// How lines longer than the viewer are handled.
  final WrapMode wrap;

  /// Whether `http` and `https` addresses in text become links: spans with an
  /// [OpenLinkAction]. A value that opens keeps its preview as one span, so an
  /// address inside it is not a link.
  final bool links;

  /// A copy with the fields given here replaced.
  LayoutOptions copyWith({
    int? tabSize,
    AmbiguousWidth? ambiguousWidth,
    int? maxClusters,
    WrapMode? wrap,
    bool? links,
  }) {
    return LayoutOptions(
      tabSize: tabSize ?? this.tabSize,
      ambiguousWidth: ambiguousWidth ?? this.ambiguousWidth,
      maxClusters: maxClusters ?? this.maxClusters,
      wrap: wrap ?? this.wrap,
      links: links ?? this.links,
    );
  }
}

/// The options a layout starts with.
const LayoutOptions defaultLayoutOptions = LayoutOptions();

/// The fewest columns a line wraps into, however deeply it is indented.
const int _minWrapColumns = 16;

/// How many entries keep their shaped lines in memory.
const int _layoutCacheSize = 4000;

/// A cell offset past the end of any line, used where a range has no end.
const int _unboundedCell = 1 << 52;

final RegExp _printableAscii = RegExp(r'^[\x20-\x7e]*$');
final RegExp _wordCharacter = RegExp(r'^[\p{L}\p{N}\p{M}_$]', unicode: true);

/// The text of a shaped line as a search sees it, with the cell where every
/// character starts.
class _SearchableText {
  const _SearchableText(this.text, this.cells);

  final String text;
  final List<int> cells;
}

_SearchableText _searchableText(ShapedLine line) {
  final List<String>? clusters = line.clusters;
  final List<int>? widths = line.widths;

  if (clusters == null || widths == null) {
    return _SearchableText(
      line.text,
      List<int>.generate(line.text.length + 1, (int index) => index),
    );
  }

  final List<int> cells = <int>[];
  final StringBuffer text = StringBuffer();
  int cell = 0;

  for (int index = 0; index < clusters.length; index++) {
    // Icons, such as the expander triangle, take cells but have no text.
    final String composed = normalizeNfc(clusters[index]);

    for (int unit = 0; unit < composed.length; unit++) {
      cells.add(cell);
    }

    text.write(composed);
    cell += widths[index];
  }

  cells.add(cell);

  return _SearchableText(text.toString(), cells);
}

class _EntryLayout {
  _EntryLayout({required this.stateKey, required this.optionsVersion, required this.lines});

  final int stateKey;
  final int optionsVersion;
  final List<ShapedLine> lines;
  String wrapKey = '';
  List<List<int>> wraps = const <List<int>>[];
  int rows = 0;
  int cells = 0;
}

class _RowCount {
  const _RowCount({
    required this.stateKey,
    required this.layoutVersion,
    required this.rows,
    required this.lines,
    required this.columns,
    required this.wrap,
  });

  final int stateKey;
  final int layoutVersion;
  final int rows;

  /// The number of logical lines, the fewest rows the entry can take.
  final int lines;
  final int columns;
  final WrapMode wrap;
}

/// How many more entries a call may measure exactly before it estimates the rest.
class _MeasureBudget {
  _MeasureBudget(this.remaining);

  int? remaining;

  bool get hasRoom => remaining == null || remaining! > 0;

  void spend() {
    final int? left = remaining;

    if (left != null) {
      remaining = left - 1;
    }
  }
}

class _Expansion {
  _Expansion(this.version, this.paths);

  int version;
  Map<String, bool> paths;
}

/// Where a text position sits within its entry.
class PositionLocation {
  /// Creates the location.
  const PositionLocation({required this.entryRow, required this.indent});

  /// The row within the entry that shows the position.
  final int entryRow;

  /// Cells of indentation on that row.
  final int indent;
}

/// The entry a row belongs to and the row's index within it.
class RowLocation {
  /// Creates the location.
  const RowLocation({required this.entry, required this.entryRow});

  /// The entry the row belongs to.
  final LogEntry entry;

  /// The index of the row within that entry.
  final int entryRow;
}

int _cellsBetween(ShapedLine line, int start, int end) {
  final List<int>? widths = line.widths;

  if (widths == null) {
    return end - start;
  }

  int cells = 0;

  for (int index = start; index < end; index++) {
    cells += widths[index];
  }

  return cells;
}

/// Returns the index of the span that holds a cluster.
int _spanAt(ShapedLine line, int cluster) {
  int low = 0;
  int high = line.spanStarts.length - 1;

  while (low < high) {
    final int middle = (low + high + 1) >> 1;

    if (line.spanStarts[middle] <= cluster) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }

  return low;
}

int _comparePositions(LogPosition a, LogPosition b) {
  if (a.entryId != b.entryId) {
    return a.entryId - b.entryId;
  }

  return a.line != b.line ? a.line - b.line : a.cell - b.cell;
}

/// Turns the entries of a store into rows for a viewer of a given width.
///
/// The layout decides which entries are visible (the filter and collapsed
/// groups), how each entry breaks into lines and rows, and which values are
/// expanded. It works from the store's change notifications, and does the
/// pending work when [sync] is called, so any number of messages between two
/// frames costs one update.
class LogLayout {
  /// Creates a layout over a store and starts listening to it.
  LogLayout(this.store, {LayoutOptions options = defaultLayoutOptions}) : _options = options {
    _unsubscribe = store.subscribe(_onStoreChange);
  }

  /// The store the layout reads.
  final LogStore store;

  LayoutOptions _options;
  int _optionsVersion = 0;
  int _layoutVersion = 0;
  int _columns = 80;
  CompiledFilter _filter = compileFilter(null);
  List<LogEntry> _visible = <LogEntry>[];
  int _visibleStart = 0;
  final RowIndex _rowIndex = RowIndex();
  final Map<int, _EntryLayout> _layouts = <int, _EntryLayout>{};
  final Map<int, _RowCount> _rowCounts = <int, _RowCount>{};
  final Map<int, _Expansion> _expansions = <int, _Expansion>{};

  /// The ids of the entries the mute rules hide, oldest first, and how many were
  /// dropped.
  List<int> _muted = <int>[];
  int _mutedStart = 0;

  /// `true` where the row count of the visible entry at the same position is
  /// only an estimate.
  List<bool> _stale = <bool>[];
  int _staleCount = 0;
  int _positions = 0;
  int _lastSyncedId = 0;
  bool _needsRebuild = true;
  bool _dirty = true;
  int _widest = 0;
  int _version = 0;
  late final void Function() _unsubscribe;

  /// The number of rows of all visible entries. Call [sync] first.
  int get rowCount => _rowIndex.total;

  /// The number of visible entries. Call [sync] first.
  int get visibleCount => _visible.length - _visibleStart;

  /// The widest row seen, in cells, including indentation.
  int get maxCells => _widest;

  /// The number of visible entries whose row count is an estimate. See
  /// [measurePending].
  int get pendingCount => _staleCount;

  /// How many of the entries the store holds the mute rules hide. Call [sync]
  /// first.
  int get mutedCount => _muted.length - _mutedStart;

  /// Changes whenever the text of the visible entries changes in another way
  /// than entries added at the end or dropped from the front: a new filter, a
  /// collapsed group, an expanded value, a cleared store, or options that change
  /// how text is shaped.
  int get textVersion => _version;

  /// Increases whenever the first row of an entry that was already visible may
  /// have moved: after a rebuild, when entries are dropped from the front, and
  /// when a row count changes. Appending entries at the end does not change it.
  /// A viewer compares it between frames to keep the same entry in view.
  int get positionsVersion => _positions;

  /// Whether the store changed since the last [sync].
  bool get isDirty => _dirty;

  /// The options in use.
  LayoutOptions get options => _options;

  /// Replaces the options.
  set options(LayoutOptions next) {
    final bool shapeChanged =
        next.tabSize != _options.tabSize ||
        next.ambiguousWidth != _options.ambiguousWidth ||
        next.maxClusters != _options.maxClusters;
    final bool wrapChanged = next.wrap != _options.wrap;
    final bool linksChanged = next.links != _options.links;

    if (!shapeChanged && !wrapChanged && !linksChanged) {
      return;
    }

    _options = next;

    if (shapeChanged || linksChanged) {
      _optionsVersion++;
      _layouts.clear();
    }

    if (shapeChanged) {
      _version++;
    }

    // Links change the spans of a line, not its text, so the rows stay as they
    // are.
    if (shapeChanged || wrapChanged) {
      _invalidateRows();
    }
  }

  /// The number of columns rows wrap into.
  int get columns => _columns;

  /// Sets the number of columns rows wrap into.
  set columns(int columns) {
    final int next = columns < 1 ? 1 : columns.floor();

    if (next == _columns) {
      return;
    }

    _columns = next;

    if (_options.wrap != WrapMode.none) {
      _invalidateRows();
    }
  }

  /// The compiled filter in use.
  CompiledFilter get filter => _filter;

  /// Sets which entries are visible. Returns the compiled filter, which reports
  /// a bad pattern.
  CompiledFilter setFilter(LogFilter? filter) {
    _filter = compileFilter(filter);
    _version++;
    _needsRebuild = true;
    _dirty = true;

    return _filter;
  }

  /// Applies pending store changes. Returns whether anything changed.
  ///
  /// [budget] limits how many entries are laid out exactly. Past it, an entry
  /// gets an estimated row count, based on its previous layout when it had one,
  /// and is left for [measureAround] and [measurePending]. Leaving it out lays
  /// out every entry exactly.
  bool sync({int? budget}) {
    if (!_dirty) {
      return false;
    }

    _dirty = false;

    final _MeasureBudget measureBudget = _MeasureBudget(budget);

    if (_needsRebuild) {
      _rebuild(measureBudget);

      return true;
    }

    final int firstId = store.firstId;
    int trimmed = 0;

    while (_visibleStart + trimmed < _visible.length &&
        _visible[_visibleStart + trimmed].id < firstId) {
      final int position = _visibleStart + trimmed;

      _forget(_visible[position].id);

      if (_stale[position]) {
        _staleCount--;
      }

      trimmed++;
    }

    if (trimmed > 0) {
      _visibleStart += trimmed;
      _rowIndex.shift(trimmed);
      _positions++;
      _compactVisible();
    }

    while (_mutedStart < _muted.length && _muted[_mutedStart] < firstId) {
      _mutedStart++;
    }

    if (_mutedStart > 4096 && _mutedStart > _muted.length / 2) {
      _muted = _muted.sublist(_mutedStart);
      _mutedStart = 0;
    }

    final int lastId = store.lastId;
    final int from = _lastSyncedId + 1 > firstId ? _lastSyncedId + 1 : firstId;

    for (int id = from; id <= lastId; id++) {
      final LogEntry? entry = store.get(id);

      if (entry != null && _isVisible(entry)) {
        _pushVisible(entry, measureBudget);
      }
    }

    _lastSyncedId = lastId;

    return true;
  }

  /// Lays out exactly the entries around one entry: [rowsBefore] rows of the
  /// entries before it, and [rowsAfter] rows starting with it. Pass `null` to
  /// start from the last visible entry. Call it for the part of the log on
  /// screen before reading its rows. Returns whether a row count changed.
  bool measureAround(int? entryId, int rowsBefore, int rowsAfter) {
    if (_staleCount == 0 || visibleCount == 0) {
      return false;
    }

    final int index = entryId == null ? visibleCount - 1 : indexOf(entryId);

    if (index < 0) {
      return false;
    }

    final int positions = _positions;
    int rows = 0;

    for (int current = index; current < visibleCount && rows < rowsAfter; current++) {
      rows += _measureIndex(current);
    }

    rows = 0;

    for (int current = index - 1; current >= 0 && rows < rowsBefore; current--) {
      rows += _measureIndex(current);
    }

    return _positions != positions;
  }

  /// Lays out exactly up to [budget] entries whose row count is still an
  /// estimate, nearest to an entry first, or to the end of the log when
  /// [entryId] is `null`. Call it in small pieces of work until [pendingCount]
  /// is 0. Returns whether a row count changed.
  bool measurePending(int budget, [int? entryId]) {
    if (_staleCount == 0) {
      return false;
    }

    final int count = visibleCount;
    final int found = entryId == null ? count - 1 : _firstIndexFrom(entryId);
    final int clamped = found < 0 ? 0 : found;
    final int focus = clamped > count - 1 ? count - 1 : clamped;
    final int positions = _positions;
    int remaining = budget;

    for (int distance = 0; remaining > 0 && _staleCount > 0; distance++) {
      final int after = focus + distance;
      final int before = focus - distance - 1;

      if (after >= count && before < 0) {
        break;
      }

      for (final int index in <int>[after, before]) {
        if (index >= 0 && index < count && _stale[_visibleStart + index]) {
          _measureIndex(index);
          remaining--;
        }
      }
    }

    return _positions != positions;
  }

  /// Returns rows starting at a row index. Call [sync] first.
  List<VisualRow> getRows(int start, int count) {
    final List<VisualRow> rows = <VisualRow>[];
    int index = _rowIndex.find(start < 0 ? 0 : start);

    if (index < 0) {
      return rows;
    }

    int skip = start - _rowIndex.rowOf(index);

    while (rows.length < count && index < visibleCount) {
      final LogEntry entry = _visible[_visibleStart + index];
      final _EntryLayout layout = _layoutOf(entry);
      int entryRow = 0;

      for (int lineIndex = 0; lineIndex < layout.lines.length; lineIndex++) {
        final ShapedLine line = layout.lines[lineIndex];
        final List<int> wraps = layout.wraps[lineIndex];
        int startCell = 0;

        for (int lineRow = 0; lineRow < wraps.length; lineRow++) {
          final int from = wraps[lineRow];
          final int to = lineRow + 1 < wraps.length ? wraps[lineRow + 1] : line.length;
          final int cells = _cellsBetween(line, from, to);

          if (entryRow >= skip && rows.length < count) {
            rows.add(
              VisualRow(
                entry: entry,
                line: lineIndex,
                lineRow: lineRow,
                entryRow: entryRow,
                first: entryRow == 0,
                last: entryRow == layout.rows - 1,
                indent: line.indent,
                startCell: startCell,
                cells: cells,
                runs: _buildRuns(line, from, to),
              ),
            );
          }

          startCell += cells;
          entryRow++;
        }
      }

      skip = 0;
      index++;
    }

    return rows;
  }

  /// Returns the entry that holds a row and the row's index within that entry.
  RowLocation? locateRow(int row) {
    final int index = _rowIndex.find(row);

    if (index < 0) {
      return null;
    }

    return RowLocation(
      entry: _visible[_visibleStart + index],
      entryRow: row - _rowIndex.rowOf(index),
    );
  }

  /// Returns the number of rows of a visible entry, or 0 when it is not visible.
  int rowsOf(int entryId) {
    final int index = indexOf(entryId);

    return index < 0 ? 0 : _rowIndex.get(index);
  }

  /// Returns the entry at a visible position, where 0 is the oldest visible
  /// entry.
  LogEntry? entryAt(int index) {
    return index >= 0 && index < visibleCount ? _visible[_visibleStart + index] : null;
  }

  /// Returns the visible position of an entry, or -1 when it is not visible.
  int indexOf(int entryId) {
    int low = _visibleStart;
    int high = _visible.length - 1;

    while (low <= high) {
      final int middle = (low + high) >> 1;
      final int id = _visible[middle].id;

      if (id == entryId) {
        return middle - _visibleStart;
      }

      if (id < entryId) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    return -1;
  }

  /// Returns the first row of an entry, or -1 when it is not visible.
  int rowOfEntry(int entryId) {
    final int index = indexOf(entryId);

    return index < 0 ? -1 : _rowIndex.rowOf(index);
  }

  /// Returns whether the value at a path of an entry is expanded.
  bool isExpanded(LogEntry entry, String path) {
    return _expansions[entry.id]?.paths[path] ?? isExpandedByDefault(entry, path);
  }

  /// Runs the action of a clicked span. Opening a link is left to the viewer.
  void runAction(int entryId, LineAction action) {
    final LogEntry? entry = store.get(entryId);

    if (entry == null) {
      return;
    }

    if (action is ToggleGroupAction || action is ToggleRepeatAction) {
      store.setCollapsed(entryId, !entry.collapsed);

      return;
    }

    if (action is ToggleValueAction) {
      setExpanded(entry, action.path, !isExpanded(entry, action.path));
    }
  }

  /// Expands or collapses the value at a path of an entry.
  void setExpanded(LogEntry entry, String path, bool expanded) {
    final _Expansion expansion = _expansions[entry.id] ?? _Expansion(0, <String, bool>{});

    expansion.paths[path] = expanded;
    expansion.version++;
    _expansions[entry.id] = expansion;
    _onExpansionChange(entry);
  }

  /// Returns whether an entry holds a value that can be expanded.
  bool hasExpandableValues(LogEntry entry) {
    return entry.parts.any((LogPart part) => part is ValuePart && isExpandable(part.value));
  }

  /// Returns the addresses of the links of an entry as shown, with the rows of
  /// open values, each address once and in order. Returns an empty list while
  /// [LayoutOptions.links] is off.
  List<String> linksOf(int entryId) {
    final LogEntry? entry = store.get(entryId);

    if (entry == null || !_options.links) {
      return <String>[];
    }

    final Set<String> urls = <String>{};

    for (final ShapedLine line in _shapedLinesOf(entry)) {
      for (final ShapedSpan span in line.spans) {
        final LineAction? action = span.action;

        if (action is OpenLinkAction) {
          urls.add(action.url);
        }
      }
    }

    return urls.toList();
  }

  /// Expands every value of an entry, and every value inside them, as far as
  /// they were captured.
  void expandAll(int entryId) => _setAllExpanded(entryId, true);

  /// Collapses every value of an entry, including errors, which are open until
  /// closed.
  void collapseAll(int entryId) => _setAllExpanded(entryId, false);

  /// Returns the visible position of the first visible entry whose id is at
  /// least [entryId].
  int indexFrom(int entryId) => _firstIndexFrom(entryId);

  /// Finds the matches of a pattern in the lines of an entry, as shown: with the
  /// rows of open values, and with control characters and tabs replaced. The
  /// text is compared in Unicode normalization form C, so decomposed Hangul
  /// matches what the user types. Returns at most [limit] matches.
  List<TextMatch> findInEntry(LogEntry entry, RegExp pattern, [int? limit]) {
    final List<TextMatch> matches = <TextMatch>[];
    final List<ShapedLine> lines = _shapedLinesOf(entry);

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      if (limit != null && matches.length >= limit) {
        break;
      }

      final _SearchableText searchable = _searchableText(lines[lineIndex]);

      for (final RegExpMatch match in pattern.allMatches(searchable.text)) {
        if (match.end == match.start) {
          continue;
        }

        matches.add(
          TextMatch(
            entryId: entry.id,
            line: lineIndex,
            from: searchable.cells[match.start],
            to: searchable.cells[match.end],
          ),
        );

        if (limit != null && matches.length >= limit) {
          break;
        }
      }
    }

    return matches;
  }

  /// Returns the row within its entry that shows a text position, and the indent
  /// of that row, or `null` when the entry is not visible.
  PositionLocation? locatePosition(LogPosition position) {
    final LogEntry? entry = store.get(position.entryId);

    if (entry == null || indexOf(entry.id) < 0) {
      return null;
    }

    final _EntryLayout layout = _layoutOf(entry);
    final int clamped = position.line < 0 ? 0 : position.line;
    final int lineIndex = clamped > layout.lines.length - 1 ? layout.lines.length - 1 : clamped;
    int entryRow = 0;

    for (int index = 0; index < lineIndex; index++) {
      entryRow += layout.wraps[index].length;
    }

    final ShapedLine line = layout.lines[lineIndex];
    final List<int> wraps = layout.wraps[lineIndex];
    int startCell = 0;

    for (int lineRow = 0; lineRow < wraps.length; lineRow++) {
      final int to = lineRow + 1 < wraps.length ? wraps[lineRow + 1] : line.length;
      final int cells = _cellsBetween(line, wraps[lineRow], to);

      if (position.cell < startCell + cells || lineRow == wraps.length - 1) {
        return PositionLocation(entryRow: entryRow + lineRow, indent: line.indent);
      }

      startCell += cells;
    }

    return PositionLocation(entryRow: entryRow, indent: line.indent);
  }

  /// Returns the text position under a row and a column of the content area. The
  /// position snaps to the nearest boundary between clusters.
  LogPosition? positionAt(int row, int column) {
    final int total = rowCount;

    if (total == 0) {
      return null;
    }

    final int clamped = row < 0 ? 0 : (row > total - 1 ? total - 1 : row);
    final List<VisualRow> found = getRows(clamped, 1);

    if (found.isEmpty) {
      return null;
    }

    final VisualRow visualRow = found.first;

    if (row >= total) {
      return LogPosition(
        entryId: visualRow.entry.id,
        line: visualRow.line,
        cell: visualRow.startCell + visualRow.cells,
      );
    }

    final int target = column - visualRow.indent < 0 ? 0 : column - visualRow.indent;
    int offset = 0;
    int cell = visualRow.cells;

    for (final RowRun run in visualRow.runs) {
      if (target >= offset + run.cells) {
        offset += run.cells;
        continue;
      }

      if (run.simple) {
        cell = target;
      } else {
        cell = offset;

        for (final int width in run.widths) {
          if (target < cell + width) {
            cell = target - cell < width / 2 ? cell : cell + width;
            break;
          }

          cell += width;
        }
      }

      break;
    }

    return LogPosition(
      entryId: visualRow.entry.id,
      line: visualRow.line,
      cell: visualRow.startCell + cell,
    );
  }

  /// Returns the start and end of the word at a position: a run of letters,
  /// digits, marks and underscores. On any other character, the range covers
  /// that character alone.
  List<LogPosition>? wordAt(LogPosition position) {
    final int index = indexOf(position.entryId);

    if (index < 0) {
      return null;
    }

    final LogEntry entry = _visible[_visibleStart + index];
    final List<ShapedLine> lines = _layoutOf(entry).lines;

    if (position.line < 0 || position.line >= lines.length) {
      return null;
    }

    final ShapedLine line = lines[position.line];

    if (line.length == 0) {
      return null;
    }

    final List<int> starts = <int>[];
    int cell = 0;
    int target = line.length - 1;

    for (int cluster = 0; cluster < line.length; cluster++) {
      starts.add(cell);

      if (target == line.length - 1 && cell + widthAt(line, cluster) > position.cell) {
        target = cluster;
      }

      cell += widthAt(line, cluster);
    }

    starts.add(cell);

    bool isWord(int cluster) {
      return _wordCharacter.hasMatch(textBetween(line, cluster, cluster + 1));
    }

    int first = target;
    int last = target;

    if (isWord(target)) {
      while (first > 0 && isWord(first - 1)) {
        first--;
      }

      while (last < line.length - 1 && isWord(last + 1)) {
        last++;
      }
    }

    return <LogPosition>[
      LogPosition(entryId: entry.id, line: position.line, cell: starts[first]),
      LogPosition(entryId: entry.id, line: position.line, cell: starts[last + 1]),
    ];
  }

  /// Returns the text between two positions, one line of the output per logical
  /// line.
  String getText(LogPosition from, LogPosition to) {
    final bool inOrder = _comparePositions(from, to) <= 0;
    final LogPosition start = inOrder ? from : to;
    final LogPosition end = inOrder ? to : from;
    final List<String> lines = <String>[];

    for (int index = _firstIndexFrom(start.entryId); index < visibleCount; index++) {
      final LogEntry entry = _visible[_visibleStart + index];

      if (entry.id > end.entryId) {
        break;
      }

      final _EntryLayout layout = _layoutOf(entry);
      final int baseIndent = entry.groups.length * indentCells;

      for (int lineIndex = 0; lineIndex < layout.lines.length; lineIndex++) {
        if (entry.id == start.entryId && lineIndex < start.line) {
          continue;
        }

        if (entry.id == end.entryId && lineIndex > end.line) {
          break;
        }

        final ShapedLine line = layout.lines[lineIndex];
        final int fromCell = entry.id == start.entryId && lineIndex == start.line ? start.cell : 0;
        final int toCell = entry.id == end.entryId && lineIndex == end.line
            ? end.cell
            : _unboundedCell;
        final int pad = line.indent - baseIndent;
        final String indent = fromCell == 0 && pad > 0 ? ' ' * pad : '';

        lines.add(indent + _textInCells(line, fromCell, toCell));
      }
    }

    return lines.join('\n');
  }

  /// Returns the whole text of the visible entries.
  String getAllText() {
    final LogEntry? first = entryAt(0);
    final LogEntry? last = entryAt(visibleCount - 1);

    if (first == null || last == null) {
      return '';
    }

    return getText(
      LogPosition(entryId: first.id, line: 0, cell: 0),
      LogPosition(entryId: last.id, line: _unboundedCell, cell: _unboundedCell),
    );
  }

  /// Stops listening to the store.
  void dispose() {
    _unsubscribe();
    _layouts.clear();
    _rowCounts.clear();
    _expansions.clear();
  }

  void _setAllExpanded(int entryId, bool expanded) {
    final LogEntry? entry = store.get(entryId);

    if (entry == null) {
      return;
    }

    final Map<String, bool> paths = <String, bool>{};

    void visit(ValueNode node, String path) {
      if (!isExpandable(node)) {
        return;
      }

      paths[path] = expanded;

      final List<ValueEntry> children = node.children ?? <ValueEntry>[];

      for (int index = 0; index < children.length; index++) {
        visit(children[index].value, '$path.$index');
      }
    }

    for (int index = 0; index < entry.parts.length; index++) {
      final LogPart part = entry.parts[index];

      if (part is ValuePart) {
        visit(part.value, '$index');
      }
    }

    if (paths.isEmpty) {
      return;
    }

    _expansions[entry.id] = _Expansion((_expansions[entry.id]?.version ?? 0) + 1, paths);
    _onExpansionChange(entry);
  }

  /// Counts the rows of an entry again after its expanded values changed.
  void _onExpansionChange(LogEntry entry) {
    final int index = indexOf(entry.id);

    _version++;

    if (index < 0) {
      return;
    }

    final int position = _visibleStart + index;
    final int rows = _countRows(entry);

    if (_stale[position]) {
      _staleCount--;
      _stale[position] = false;
    }

    if (rows != _rowIndex.get(index)) {
      _rowIndex.set(index, rows);
      _positions++;
    }
  }

  void _onStoreChange(StoreChange change) {
    _dirty = true;

    if (change is StoreClear) {
      _version++;
      _needsRebuild = true;
      _layouts.clear();
      _rowCounts.clear();
      _expansions.clear();
    } else if (change is StoreUpdate && change.visibility) {
      _version++;
      _needsRebuild = true;
    }
  }

  void _invalidateRows() {
    _layoutVersion++;
    _needsRebuild = true;
    _dirty = true;
  }

  void _rebuild(_MeasureBudget budget) {
    _needsRebuild = false;
    _visible = <LogEntry>[];
    _muted = <int>[];
    _mutedStart = 0;
    _stale = <bool>[];
    _staleCount = 0;
    _visibleStart = 0;
    _rowIndex.clear();
    _widest = 0;
    _positions++;

    for (int index = 0; index < store.size; index++) {
      final LogEntry entry = store.at(index)!;

      if (_isVisible(entry)) {
        _pushVisible(entry, budget);
      }
    }

    _lastSyncedId = store.lastId;
    _pruneCaches();
  }

  /// Adds a visible entry with its exact row count, or an estimate once the
  /// budget is spent.
  void _pushVisible(LogEntry entry, _MeasureBudget budget) {
    final _RowCount? cached = _rowCounts[entry.id];
    int rows;
    bool stale = false;

    if (cached != null &&
        cached.stateKey == _stateKeyOf(entry) &&
        cached.layoutVersion == _layoutVersion) {
      rows = cached.rows;
    } else if (budget.hasRoom) {
      budget.spend();
      rows = _countRows(entry);
    } else {
      rows = _estimateRows(cached);
      stale = true;
      _staleCount++;
    }

    _visible.add(entry);
    _stale.add(stale);
    _rowIndex.push(rows);
  }

  /// Guesses the row count of an entry that was not laid out at the current
  /// width: its previous row count scaled by the change in width, and never
  /// fewer rows than it has lines.
  int _estimateRows(_RowCount? previous) {
    if (previous == null) {
      return 1;
    }

    if (_options.wrap == WrapMode.none || previous.wrap == WrapMode.none) {
      return previous.lines;
    }

    final int scaled = (previous.rows * previous.columns / _columns).round();

    return scaled > previous.lines ? scaled : previous.lines;
  }

  /// Lays out the visible entry at an index exactly, if it is not already.
  /// Returns its rows.
  int _measureIndex(int index) {
    final int position = _visibleStart + index;

    if (!_stale[position]) {
      return _rowIndex.get(index);
    }

    final int rows = _countRows(_visible[position]);

    _stale[position] = false;
    _staleCount--;

    if (rows != _rowIndex.get(index)) {
      _rowIndex.set(index, rows);
      _positions++;
    }

    return rows;
  }

  bool _isVisible(LogEntry entry) {
    // Muted entries are counted whatever the rest of the filter says, so the
    // count of hidden entries does not change while the user types in the
    // filter field.
    if (_filter.muted?.call(entry) ?? false) {
      _muted.add(entry.id);

      return false;
    }

    final bool Function(LogEntry)? matches = _filter.matches;

    if (matches != null && !matches(entry)) {
      return false;
    }

    // An entry that repeats the one that starts its run is hidden while that run
    // is collapsed.
    final int? runHead = entry.runHead;

    if (runHead != null && (store.get(runHead)?.collapsed ?? false)) {
      return false;
    }

    for (final int groupId in entry.groups) {
      if (store.get(groupId)?.collapsed ?? false) {
        return false;
      }
    }

    return true;
  }

  int _stateKeyOf(LogEntry entry) {
    return (_expansions[entry.id]?.version ?? 0) * 2 + (entry.collapsed ? 1 : 0);
  }

  int _countRows(LogEntry entry) {
    final int stateKey = _stateKeyOf(entry);
    final _RowCount? cached = _rowCounts[entry.id];

    if (cached != null && cached.stateKey == stateKey && cached.layoutVersion == _layoutVersion) {
      return cached.rows;
    }

    final int? plainRows = _countPlainRows(entry);
    final _EntryLayout? layout = plainRows == null ? _layoutOf(entry) : null;
    final int rows = plainRows ?? layout!.rows;

    _rowCounts[entry.id] = _RowCount(
      stateKey: stateKey,
      layoutVersion: _layoutVersion,
      rows: rows,
      lines: layout == null ? 1 : layout.lines.length,
      columns: _columns,
      wrap: _options.wrap,
    );

    return rows;
  }

  /// Counts the rows of the most common entry, one line of plain ASCII text,
  /// without building and caching its layout. Returns `null` for any other
  /// entry.
  int? _countPlainRows(LogEntry entry) {
    if (entry.kind != LogKind.message || entry.groups.isNotEmpty || entry.parts.length != 1) {
      return null;
    }

    final LogPart part = entry.parts.first;

    if (part is! TextPart ||
        !part.wrap ||
        part.text.length > _options.maxClusters ||
        !_printableAscii.hasMatch(part.text)) {
      return null;
    }

    final ShapedLine line = shapeLine(<LineSpan>[LineTextSpan(part.text)], 0, _options);
    final int width = _columns > _minWrapColumns ? _columns : _minWrapColumns;
    final int rows = wrapLine(line, width, _options.wrap).length;
    final int widest = rows > 1 ? (line.cells < width ? line.cells : width) : line.cells;

    if (widest > _widest) {
      _widest = widest;
    }

    return rows;
  }

  /// The shaped lines of an entry: the cached ones when it was laid out, new
  /// ones otherwise.
  List<ShapedLine> _shapedLinesOf(LogEntry entry) {
    final _EntryLayout? cached = _layouts[entry.id];

    if (cached != null &&
        cached.stateKey == _stateKeyOf(entry) &&
        cached.optionsVersion == _optionsVersion) {
      return cached.lines;
    }

    return buildEntryLines(
      entry,
      (String path) => isExpanded(entry, path),
      links: _options.links,
    ).map((LogicalLine logical) => shapeLine(logical.spans, logical.indent, _options)).toList();
  }

  _EntryLayout _layoutOf(LogEntry entry) {
    final int stateKey = _stateKeyOf(entry);
    _EntryLayout? layout = _layouts[entry.id];

    if (layout == null || layout.stateKey != stateKey || layout.optionsVersion != _optionsVersion) {
      final List<ShapedLine> lines =
          buildEntryLines(
            entry,
            (String path) => isExpanded(entry, path),
            links: _options.links,
          ).map((LogicalLine logical) {
            final ShapedLine shaped = shapeLine(logical.spans, logical.indent, _options);

            shaped.wrap = logical.wrap;

            return shaped;
          }).toList();

      layout = _EntryLayout(stateKey: stateKey, optionsVersion: _optionsVersion, lines: lines);
    }

    final String wrapKey = '${_options.wrap.name}:$_columns';

    if (layout.wrapKey != wrapKey) {
      int rows = 0;
      int cells = 0;

      layout.wraps = layout.lines.map((ShapedLine line) {
        final int available = _columns - line.indent;
        final int width = available > _minWrapColumns ? available : _minWrapColumns;
        final List<int> wraps = wrapLine(line, width, line.wrap ? _options.wrap : WrapMode.none);
        final int widest = wraps.length > 1
            ? (line.cells < width ? line.cells : width)
            : line.cells;

        rows += wraps.length;

        if (line.indent + widest > cells) {
          cells = line.indent + widest;
        }

        return wraps;
      }).toList();
      layout.rows = rows;
      layout.cells = cells;
      layout.wrapKey = wrapKey;
    }

    if (layout.cells > _widest) {
      _widest = layout.cells;
    }

    _layouts
      ..remove(entry.id)
      ..[entry.id] = layout;

    if (_layouts.length > _layoutCacheSize) {
      _layouts.remove(_layouts.keys.first);
    }

    return layout;
  }

  List<RowRun> _buildRuns(ShapedLine line, int from, int to) {
    final List<RowRun> runs = <RowRun>[];
    int spanIndex = _spanAt(line, from);
    int cursor = from;
    int column = line.indent;

    while (cursor < to && spanIndex < line.spans.length) {
      final int spanEnd = spanIndex + 1 < line.spans.length
          ? line.spanStarts[spanIndex + 1]
          : line.length;
      final int end = to < spanEnd ? to : spanEnd;

      if (end > cursor) {
        final ShapedSpan span = line.spans[spanIndex];
        final String text = textBetween(line, cursor, end);
        int cells = end - cursor;
        List<String> clusters = const <String>[];
        List<int> widths = const <int>[];
        bool simple = true;

        if (line.clusters != null && line.widths != null) {
          final List<int> spanWidths = line.widths!.sublist(cursor, end);

          cells = spanWidths.fold<int>(0, (int sum, int width) => sum + width);
          simple = !span.icon && cells == end - cursor && _printableAscii.hasMatch(text);

          if (!simple) {
            clusters = line.clusters!.sublist(cursor, end);
            widths = spanWidths;
          }
        }

        runs.add(
          RowRun(
            column: column,
            cells: cells,
            text: text,
            clusters: clusters,
            widths: widths,
            simple: simple,
            token: span.token,
            style: span.style,
            action: span.action,
            icon: span.icon,
            expanded: span.expanded,
          ),
        );
        column += cells;
      }

      cursor = end;
      spanIndex++;
    }

    return runs;
  }

  String _textInCells(ShapedLine line, int fromCell, int toCell) {
    final StringBuffer text = StringBuffer();
    int cell = 0;

    for (int index = 0; index < line.length; index++) {
      final int width = widthAt(line, index);

      if (cell >= toCell) {
        break;
      }

      if (cell >= fromCell) {
        final bool isIcon = line.clusters != null && line.clusters![index].isEmpty && width == 2;

        if (!isIcon) {
          text.write(textBetween(line, index, index + 1));
        }
      }

      cell += width;
    }

    return text.toString();
  }

  int _firstIndexFrom(int entryId) {
    int low = _visibleStart;
    int high = _visible.length;

    while (low < high) {
      final int middle = (low + high) >> 1;

      if (_visible[middle].id < entryId) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }

    return low - _visibleStart;
  }

  void _forget(int entryId) {
    _layouts.remove(entryId);
    _rowCounts.remove(entryId);
    _expansions.remove(entryId);
  }

  void _compactVisible() {
    if (_visibleStart > 4096 && _visibleStart > _visible.length / 2) {
      _visible = _visible.sublist(_visibleStart);
      _stale = _stale.sublist(_visibleStart);
      _visibleStart = 0;
    }
  }

  void _pruneCaches() {
    final int firstId = store.firstId;

    for (final Map<int, Object> map in <Map<int, Object>>[_layouts, _rowCounts, _expansions]) {
      map.removeWhere((int id, Object value) => id < firstId);
    }
  }
}
