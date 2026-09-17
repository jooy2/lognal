import 'package:lognal/src/core/text/ansi.dart';
import 'package:lognal/src/core/text/line_splitter.dart';
import 'package:lognal/src/core/types.dart';

/// What happens to a message identical to the one before it.
///
/// Named for the option it is the value of rather than for what a run is,
/// because `RepeatMode` is already a name in `package:flutter/widgets.dart` and
/// two of them in one file is a prefix nobody wants to write.
enum MergeRepeats {
  /// The earlier entry's repeat count rises and the message is not added.
  merge,

  /// Every message is kept. The run shows as the first entry with its count,
  /// which opens to show the whole run, and starts collapsed.
  collapse,

  /// Every message gets an entry of its own.
  keep,
}

/// What a store keeps and how it merges repeats.
class LogStoreOptions {
  /// Creates the store options.
  const LogStoreOptions({this.maxEntries = 10000, this.mergeRepeats = MergeRepeats.merge});

  /// The most entries the store keeps. Once it is full, the oldest entry is
  /// dropped for every new one. Use a very large number to keep everything.
  final int maxEntries;

  /// What happens to a message identical to the one before it.
  final MergeRepeats mergeRepeats;

  /// A copy with the fields given here replaced.
  LogStoreOptions copyWith({int? maxEntries, MergeRepeats? mergeRepeats}) {
    return LogStoreOptions(
      maxEntries: maxEntries ?? this.maxEntries,
      mergeRepeats: mergeRepeats ?? this.mergeRepeats,
    );
  }
}

/// The options a store starts with.
const LogStoreOptions defaultStoreOptions = LogStoreOptions();

/// A change to the contents of a store.
sealed class StoreChange {
  /// Lets a subclass declare a `const` constructor.
  const StoreChange();
}

/// Entries were added at the end.
class StoreAppend extends StoreChange {
  /// Creates the change.
  const StoreAppend(this.entries);

  /// The entries that were created, oldest first.
  final List<LogEntry> entries;
}

/// One entry changed in place.
class StoreUpdate extends StoreChange {
  /// Creates the change.
  const StoreUpdate(this.entry, {this.visibility = false});

  /// The entry that changed.
  final LogEntry entry;

  /// Whether the change also hides or shows other entries.
  final bool visibility;
}

/// Entries were dropped from the front.
class StoreTrim extends StoreChange {
  /// Creates the change.
  const StoreTrim(this.count);

  /// How many entries were dropped.
  final int count;
}

/// Every entry was removed.
class StoreClear extends StoreChange {
  /// Creates the change.
  const StoreClear();
}

/// Called for every change to a store.
typedef StoreListener = void Function(StoreChange change);

/// Options for adding plain text.
class WriteOptions {
  /// Creates the options.
  const WriteOptions({
    this.level = LogLevel.log,
    this.kind = LogKind.message,
    this.time,
    this.groups = const <int>[],
    this.token,
    this.style,
    this.wrap = true,
    this.ansi = false,
    this.parser,
  });

  /// How severe the entry is.
  final LogLevel level;

  /// What the entry represents.
  final LogKind kind;

  /// When the entry happened. Defaults to the time it is added.
  final DateTime? time;

  /// Ids of the open groups the entry belongs to, outermost first.
  final List<int> groups;

  /// The semantic color of the text.
  final StyleToken? token;

  /// Explicit styling, which wins over [token].
  final LogTextStyle? style;

  /// Set to `false` to keep every line on one row, for text such as a table.
  final bool wrap;

  /// Whether ANSI escape codes in the text are turned into styles.
  final bool ansi;

  /// A parser to keep the ANSI style running across several calls. Passing one
  /// turns [ansi] on.
  final AnsiParser? parser;
}

/// How many dropped slots the store tolerates before it compacts its list.
const int _compactThreshold = 4096;

const String _mergeSeparator = '\x00';

/// Returns a string that is equal for two messages that should be merged, or
/// `null`.
String? _signatureOf(LogEntryInit init, LogLevel level, LogKind kind) {
  if (kind != LogKind.message) {
    return null;
  }

  final List<String> pieces = <String>[level.name, init.groups.join(',')];

  for (final LogPart part in init.parts) {
    if (part is TextPart) {
      pieces.add(
        't${part.wrap ? '' : 'n'}${part.text}${part.token?.name ?? ''}'
        '${part.style?.signature ?? ''}',
      );
      continue;
    }

    final ValueNode value = (part as ValuePart).value;

    if (value.children != null || value.kind == ValueKind.error) {
      return null;
    }

    pieces.add('v${value.kind.name}:${value.value ?? ''}:${value.className ?? ''}');
  }

  return pieces.join(_mergeSeparator);
}

/// Holds log entries in the order they were added.
///
/// The store knows nothing about how entries are displayed, so one store can
/// feed several viewers, or collect messages before any viewer exists.
class LogStore {
  /// Creates a store.
  LogStore({LogStoreOptions options = defaultStoreOptions}) : _options = options;

  LogStoreOptions _options;
  List<LogEntry> _items = <LogEntry>[];
  int _start = 0;
  int _nextId = 1;
  int _oldestId = 1;
  String? _lastSignature;

  /// The first entry of the run the next identical message joins, while a run is
  /// collapsed.
  LogEntry? _runHead;
  final Set<StoreListener> _listeners = <StoreListener>{};

  /// The number of entries held.
  int get size => _items.length - _start;

  /// The id of the oldest entry held. When the store is empty, the id the next
  /// entry gets.
  int get firstId => _oldestId;

  /// The id of the newest entry held, or `firstId - 1` when the store is empty.
  int get lastId => _nextId - 1;

  /// The options in use.
  LogStoreOptions get options => _options;

  /// Replaces the options.
  set options(LogStoreOptions options) {
    _options = options;
    _trimToLimit();
  }

  /// Returns the entry at a position, where 0 is the oldest entry held.
  LogEntry? at(int index) {
    if (index < 0 || index >= size) {
      return null;
    }

    return _items[_start + index];
  }

  /// Returns the entry with an id, if the store still holds it.
  LogEntry? get(int id) => at(id - _oldestId);

  /// Returns every entry, oldest first.
  List<LogEntry> toList() => _items.sublist(_start);

  /// Adds one entry or several, and returns the entries that were created. A
  /// message merged into the entry before it only raises that entry's `repeat`
  /// count and is not returned.
  List<LogEntry> append(List<LogEntryInit> inits) {
    final List<LogEntry> created = <LogEntry>[];
    final bool collapse = _options.mergeRepeats == MergeRepeats.collapse;

    for (final LogEntryInit item in inits) {
      final LogLevel level = item.level;
      final LogKind kind = item.kind;
      final String? signature = _options.mergeRepeats == MergeRepeats.keep
          ? null
          : _signatureOf(item, level, kind);
      final LogEntry? last = at(size - 1);
      final LogEntry? head = collapse ? _runHead : last;
      final bool repeats = signature != null && head != null && signature == _lastSignature;

      if (repeats && !collapse) {
        head.repeat++;
        head.version++;
        _emit(StoreUpdate(head));
        continue;
      }

      final LogEntry entry = LogEntry(
        id: _nextId++,
        time: item.time ?? DateTime.now(),
        level: level,
        kind: kind,
        parts: item.parts,
        groups: item.groups,
        runHead: repeats ? head.id : null,
        collapsed: item.collapsed,
      );

      _items.add(entry);
      _lastSignature = signature;
      created.add(entry);

      if (!repeats) {
        _runHead = signature == null ? null : entry;
        continue;
      }

      // A run starts collapsed, so a burst of the same message stays one row
      // until it is opened. A run that was opened while the message repeats
      // stays open.
      if (head.repeat == 1) {
        head.collapsed = true;
      }

      head.repeat++;
      head.version++;
      _emit(StoreUpdate(head, visibility: true));
    }

    if (created.isNotEmpty) {
      _emit(StoreAppend(created));
      _trimToLimit();
    }

    return created;
  }

  /// Adds one entry.
  LogEntry? add(LogEntryInit init) {
    final List<LogEntry> created = append(<LogEntryInit>[init]);

    return created.isEmpty ? at(size - 1) : created.first;
  }

  /// Adds text as one entry. Line breaks stay inside the entry.
  LogEntry? write(String text, [WriteOptions options = const WriteOptions()]) {
    return add(_initOf(options, _textParts(text, options, options.parser)));
  }

  /// Adds text as one entry per line.
  List<LogEntry> writeLines(String text, [WriteOptions options = const WriteOptions()]) {
    final AnsiParser? parser = options.parser ?? (options.ansi ? AnsiParser() : null);

    return append(
      splitLines(
        text,
      ).map((String line) => _initOf(options, _textParts(line, options, parser))).toList(),
    );
  }

  /// Removes every entry.
  void clear() {
    _items = <LogEntry>[];
    _start = 0;
    _oldestId = _nextId;
    _lastSignature = null;
    _runHead = null;
    _emit(const StoreClear());
  }

  /// Whether an entry is the first of a run of identical messages that the store
  /// still holds, so the run can be opened and collapsed. Only
  /// [MergeRepeats.collapse] creates such a run.
  bool isRunHead(LogEntry entry) => get(entry.id + 1)?.runHead == entry.id;

  /// Collapses or expands a group header, or the first entry of a run of
  /// identical messages, and hides or shows its members.
  void setCollapsed(int id, bool collapsed) {
    final LogEntry? entry = get(id);

    if (entry == null || entry.collapsed == collapsed) {
      return;
    }

    entry.collapsed = collapsed;
    entry.version++;
    _emit(StoreUpdate(entry, visibility: true));
  }

  /// Calls a listener for every change. Returns a function that removes the
  /// listener.
  void Function() subscribe(StoreListener listener) {
    _listeners.add(listener);

    return () => _listeners.remove(listener);
  }

  LogEntryInit _initOf(WriteOptions options, List<LogPart> parts) {
    return LogEntryInit(
      parts: parts,
      level: options.level,
      kind: options.kind,
      time: options.time,
      groups: options.groups,
    );
  }

  List<LogPart> _textParts(String text, WriteOptions options, AnsiParser? parser) {
    if (options.ansi || parser != null) {
      final AnsiParser active = parser ?? AnsiParser();

      return active
          .parse(text)
          .map<LogPart>(
            (TextPart part) =>
                part.copyWith(token: part.token ?? options.token, wrap: options.wrap),
          )
          .toList();
    }

    return <LogPart>[
      TextPart(text, token: options.token, style: options.style, wrap: options.wrap),
    ];
  }

  void _trimToLimit() {
    final int excess = size - _options.maxEntries;

    if (excess <= 0) {
      return;
    }

    _start += excess;
    _oldestId += excess;

    if (_start > _compactThreshold && _start > _items.length / 2) {
      _items = _items.sublist(_start);
      _start = 0;
    }

    // A run whose first entry was dropped can no longer be collapsed, so the
    // next identical message starts a run of its own.
    final LogEntry? head = _runHead;

    if (size == 0 || (head != null && get(head.id) == null)) {
      _lastSignature = null;
      _runHead = null;
    }

    _emit(StoreTrim(excess));
  }

  void _emit(StoreChange change) {
    for (final StoreListener listener in _listeners.toList()) {
      listener(change);
    }
  }
}
