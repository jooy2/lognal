import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/console/capture.dart';
import 'package:lognal/src/sources/console/format.dart';
import 'package:lognal/src/sources/console/table.dart';

/// The logging calls lognal records.
enum ConsoleMethod {
  /// An ordinary message.
  log,

  /// A message worth noticing.
  info,

  /// Something that may be a problem.
  warn,

  /// Something that is a problem.
  error,

  /// Detail a developer asked for.
  debug,

  /// A message with the stack trace of its caller under it.
  trace,

  /// One value, opened rather than described.
  dir,

  /// A collection drawn as a table.
  table,

  /// The start of a group.
  group,

  /// The start of a group that begins closed.
  groupCollapsed,

  /// The end of the innermost open group.
  groupEnd,

  /// How many times this label has been counted.
  count,

  /// Sets a label's count back to zero.
  countReset,

  /// Starts a timer.
  time,

  /// Reports how long a timer has been running, without stopping it.
  timeLog,

  /// Reports how long a timer ran and stops it.
  timeEnd,

  /// An error message, unless the condition holds.
  assertCondition,

  /// Removes every entry.
  clear,
}

/// Every method a recorder answers to.
const List<ConsoleMethod> consoleMethods = ConsoleMethod.values;

/// What a recorder captures and what `clear` does.
class RecorderOptions {
  /// Creates the options.
  const RecorderOptions({this.capture = defaultCaptureOptions, this.clearStore = true});

  /// The limits a captured value is taken under.
  final CaptureOptions capture;

  /// Whether [ConsoleMethod.clear] removes the entries from the store.
  final bool clearStore;

  /// A copy with the fields given here replaced.
  RecorderOptions copyWith({CaptureOptions? capture, bool? clearStore}) {
    return RecorderOptions(
      capture: capture ?? this.capture,
      clearStore: clearStore ?? this.clearStore,
    );
  }
}

/// The options a recorder starts with.
const RecorderOptions defaultRecorderOptions = RecorderOptions();

const String _defaultLabel = 'default';

final Stopwatch _clock = Stopwatch()..start();

double _now() => _clock.elapsedMicroseconds / 1000;

String _labelOf(Object? value) => value == null ? _defaultLabel : value.toString();

String _formatDuration(double milliseconds) {
  final String text = milliseconds.toStringAsFixed(3);

  return '${text.contains('.') ? text.replaceAll(RegExp(r'\.?0+$'), '') : text} ms';
}

TextPart _text(String value, {StyleToken? token, LogTextStyle? style, bool wrap = true}) {
  return TextPart(value, token: token, style: style, wrap: wrap);
}

/// Turns logging calls into store entries.
///
/// A recorder keeps the state a console has: the count map, the timer table and
/// the group stack. Everything is captured synchronously, when the method is
/// called.
class ConsoleRecorder {
  /// Creates a recorder that writes into a store.
  ConsoleRecorder(this.store, {this.options = defaultRecorderOptions});

  /// The store the entries go into.
  final LogStore store;

  /// The options in use. Replacing them applies to the next call.
  RecorderOptions options;

  final Map<String, int> _counts = <String, int>{};
  final Map<String, double> _timers = <String, double>{};
  List<int> _groups = <int>[];

  /// Records one call. [stack] is the caller's stack trace, which only
  /// [ConsoleMethod.trace] and an error use.
  void record(ConsoleMethod method, List<Object?> args, {StackTrace? stack}) {
    switch (method) {
      case ConsoleMethod.log:
        _add(LogLevel.log, formatArguments(args, _capture));
      case ConsoleMethod.info:
        _add(LogLevel.info, formatArguments(args, _capture));
      case ConsoleMethod.warn:
        _add(LogLevel.warn, formatArguments(args, _capture));
      case ConsoleMethod.debug:
        _add(LogLevel.debug, formatArguments(args, _capture));
      case ConsoleMethod.error:
        _error(args, stack);
      case ConsoleMethod.dir:
        _add(LogLevel.log, <LogPart>[ValuePart(_capture(args.isEmpty ? null : args.first))]);
      case ConsoleMethod.trace:
        _trace(args, stack);
      case ConsoleMethod.table:
        _table(args);
      case ConsoleMethod.group:
        _group(args, false);
      case ConsoleMethod.groupCollapsed:
        _group(args, true);
      case ConsoleMethod.groupEnd:
        _groups = _groups.isEmpty ? _groups : _groups.sublist(0, _groups.length - 1);
      case ConsoleMethod.count:
        _count(args.isEmpty ? null : args.first);
      case ConsoleMethod.countReset:
        _countReset(args.isEmpty ? null : args.first);
      case ConsoleMethod.time:
        _time(args.isEmpty ? null : args.first);
      case ConsoleMethod.timeLog:
        _timeLog(args.isEmpty ? null : args.first, args.skip(1).toList());
      case ConsoleMethod.timeEnd:
        _timeEnd(args.isEmpty ? null : args.first);
      case ConsoleMethod.assertCondition:
        _assert(args);
      case ConsoleMethod.clear:
        _clear();
    }
  }

  ValueNode _capture(Object? value) => captureValue(value, options.capture);

  void _add(
    LogLevel level,
    List<LogPart> parts, {
    LogKind kind = LogKind.message,
    bool collapsed = false,
  }) {
    store.add(
      LogEntryInit(
        parts: parts,
        level: level,
        kind: kind,
        groups: List<int>.of(_groups),
        collapsed: collapsed,
      ),
    );
  }

  /// An error call, with the stack trace the caller passed or the one the error
  /// carries.
  void _error(List<Object?> args, StackTrace? stack) {
    if (stack == null || args.isEmpty) {
      _add(LogLevel.error, formatArguments(args, _capture));

      return;
    }

    // `error(exception, stackTrace)` is how Dart reports a failure, so the two
    // become one entry whose value carries the trace.
    final ValueNode captured = _capture(args.first);

    if (captured.kind != ValueKind.error) {
      _add(LogLevel.error, <LogPart>[
        ...formatArguments(args, _capture),
        _text('\n${_framesOf(stack)}', token: StyleToken.muted),
      ]);

      return;
    }

    final List<LogPart> rest = formatArguments(args.skip(1).toList(), _capture);
    final List<LogPart> parts = <LogPart>[
      ValuePart(captured.copyWith(stack: captured.stack ?? _framesOf(stack))),
      if (rest.isNotEmpty) _text(' '),
      ...rest,
    ];

    _add(LogLevel.error, parts);
  }

  void _trace(List<Object?> args, StackTrace? stack) {
    final List<LogPart> parts = args.isEmpty
        ? <LogPart>[_text('trace')]
        : formatArguments(args, _capture);
    final String? frames = stack == null ? null : _framesOf(stack);

    if (frames != null && frames.isNotEmpty) {
      parts.add(_text('\n$frames', token: StyleToken.muted));
    }

    _add(LogLevel.log, parts);
  }

  void _table(List<Object?> args) {
    final Object? data = args.isEmpty ? null : args.first;
    final Object? properties = args.length > 1 ? args[1] : null;

    if (data == null || data is String || data is num || data is bool) {
      _add(LogLevel.log, formatArguments(args, _capture));

      return;
    }

    final ValueNode node = captureValue(data, options.capture.copyWith(maxDepth: 2));
    final List<String>? columns = properties is List<Object?>
        ? properties.map((Object? key) => '$key').toList()
        : null;
    final String? table = formatTable(node, columns);

    // A table keeps its rows whole; a table wider than the viewer scrolls
    // sideways.
    _add(
      LogLevel.log,
      table == null ? <LogPart>[ValuePart(node)] : <LogPart>[_text(table, wrap: false)],
    );
  }

  void _group(List<Object?> args, bool collapsed) {
    final List<LogPart> parts = args.isEmpty
        ? <LogPart>[_text(collapsed ? 'group' : 'group', style: const LogTextStyle(bold: true))]
        : formatArguments(args, _capture)
              .map(
                (LogPart part) => part is TextPart
                    ? part.copyWith(
                        style: (part.style ?? const LogTextStyle()).copyWith(bold: true),
                      )
                    : part,
              )
              .toList();
    final LogEntry? entry = store.add(
      LogEntryInit(
        parts: parts,
        kind: LogKind.group,
        groups: List<int>.of(_groups),
        collapsed: collapsed,
      ),
    );

    if (entry != null) {
      _groups = <int>[..._groups, entry.id];
    }
  }

  void _count(Object? label) {
    final String key = _labelOf(label);
    final int count = (_counts[key] ?? 0) + 1;

    _counts[key] = count;
    _add(LogLevel.info, <LogPart>[_text('$key: $count')]);
  }

  void _countReset(Object? label) {
    final String key = _labelOf(label);

    if (_counts.containsKey(key)) {
      _counts[key] = 0;
    } else {
      _add(LogLevel.warn, <LogPart>[_text("Count for '$key' does not exist")]);
    }
  }

  void _time(Object? label) {
    final String key = _labelOf(label);

    if (_timers.containsKey(key)) {
      _add(LogLevel.warn, <LogPart>[_text("Timer '$key' already exists")]);

      return;
    }

    _timers[key] = _now();
  }

  void _timeLog(Object? label, List<Object?> data) {
    final String key = _labelOf(label);
    final double? start = _timers[key];

    if (start == null) {
      _add(LogLevel.warn, <LogPart>[_text("Timer '$key' does not exist")]);

      return;
    }

    final List<LogPart> parts = <LogPart>[_text('$key: ${_formatDuration(_now() - start)}')];

    for (final Object? value in data) {
      parts
        ..add(_text(' '))
        ..add(value is String ? _text(value) : ValuePart(_capture(value)));
    }

    _add(LogLevel.log, parts);
  }

  void _timeEnd(Object? label) {
    final String key = _labelOf(label);
    final double? start = _timers.remove(key);

    if (start == null) {
      _add(LogLevel.warn, <LogPart>[_text("Timer '$key' does not exist")]);

      return;
    }

    _add(LogLevel.info, <LogPart>[_text('$key: ${_formatDuration(_now() - start)}')]);
  }

  void _assert(List<Object?> args) {
    final Object? condition = args.isEmpty ? null : args.first;

    if (condition == true) {
      return;
    }

    final List<Object?> data = args.skip(1).toList();

    if (data.isEmpty) {
      _add(LogLevel.error, <LogPart>[_text('Assertion failed')]);

      return;
    }

    if (data.first is String) {
      data[0] = 'Assertion failed: ${data.first}';
    } else {
      data.insert(0, 'Assertion failed');
    }

    _add(LogLevel.error, formatArguments(data, _capture));
  }

  void _clear() {
    _groups = <int>[];

    if (options.clearStore) {
      store.clear();
    }

    _add(LogLevel.log, <LogPart>[
      _text('Log was cleared', token: StyleToken.muted),
    ], kind: LogKind.system);
  }
}

/// A stack trace indented the way a stack under a message is drawn, with the
/// frames of lognal itself left out.
String _framesOf(StackTrace stack) {
  final List<String> frames = stack
      .toString()
      .split('\n')
      .map((String frame) => frame.trim())
      .where((String frame) => frame.isNotEmpty && !frame.contains('package:lognal/'))
      .map((String frame) => '    $frame')
      .toList();

  return frames.join('\n');
}
