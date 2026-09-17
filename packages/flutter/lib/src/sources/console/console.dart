import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/sources/console/recorder.dart';

/// An object with the logging methods lognal records, written into a store
/// without touching anything the application already prints.
///
/// It is the console the JavaScript package hooks, in the shape Dart writes one:
/// a value you hold rather than a global you replace. Every call captures its
/// arguments synchronously, so what the viewer shows is what the value was when
/// the line was logged.
class LognalConsole {
  /// Creates a console over a store.
  LognalConsole(LogStore store, {RecorderOptions options = defaultRecorderOptions})
    : _recorder = ConsoleRecorder(store, options: options);

  /// Creates a console over a recorder that already exists.
  LognalConsole.of(this._recorder);

  final ConsoleRecorder _recorder;

  /// The recorder behind the console, for changing the options it captures with.
  ConsoleRecorder get recorder => _recorder;

  /// Logs a message.
  void log(Object? message, [List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.log, <Object?>[message, ...args]);
  }

  /// Logs a message worth noticing.
  void info(Object? message, [List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.info, <Object?>[message, ...args]);
  }

  /// Logs something that may be a problem.
  void warn(Object? message, [List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.warn, <Object?>[message, ...args]);
  }

  /// Logs something that is a problem, with the stack trace when one is given.
  void error(Object? message, [List<Object?> args = const <Object?>[], StackTrace? stack]) {
    _recorder.record(ConsoleMethod.error, <Object?>[message, ...args], stack: stack);
  }

  /// Logs detail a developer asked for.
  void debug(Object? message, [List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.debug, <Object?>[message, ...args]);
  }

  /// Logs a message with the stack trace of the caller under it.
  void trace([Object? message, List<Object?> args = const <Object?>[]]) {
    _recorder.record(
      ConsoleMethod.trace,
      message == null ? <Object?>[] : <Object?>[message, ...args],
      stack: StackTrace.current,
    );
  }

  /// Logs one value, opened rather than described.
  void dir(Object? value) => _recorder.record(ConsoleMethod.dir, <Object?>[value]);

  /// Draws a collection as a table. [columns] names the columns to show.
  void table(Object? data, [List<String>? columns]) {
    _recorder.record(ConsoleMethod.table, <Object?>[data, columns]);
  }

  /// Starts a group. Everything logged until [groupEnd] sits inside it.
  void group([Object? label, List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.group, label == null ? <Object?>[] : <Object?>[label, ...args]);
  }

  /// Starts a group that begins closed.
  void groupCollapsed([Object? label, List<Object?> args = const <Object?>[]]) {
    _recorder.record(
      ConsoleMethod.groupCollapsed,
      label == null ? <Object?>[] : <Object?>[label, ...args],
    );
  }

  /// Ends the innermost open group.
  void groupEnd() => _recorder.record(ConsoleMethod.groupEnd, const <Object?>[]);

  /// Logs how many times this label has been counted.
  void count([String? label]) => _recorder.record(ConsoleMethod.count, <Object?>[label]);

  /// Sets a label's count back to zero.
  void countReset([String? label]) => _recorder.record(ConsoleMethod.countReset, <Object?>[label]);

  /// Starts a timer.
  void time([String? label]) => _recorder.record(ConsoleMethod.time, <Object?>[label]);

  /// Logs how long a timer has been running, without stopping it.
  void timeLog([String? label, List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.timeLog, <Object?>[label, ...args]);
  }

  /// Logs how long a timer ran and stops it.
  void timeEnd([String? label]) => _recorder.record(ConsoleMethod.timeEnd, <Object?>[label]);

  /// Logs an error unless [condition] holds.
  ///
  /// Named for what it does rather than after the console method it mirrors:
  /// `assert` is a keyword in Dart and cannot be a method name.
  void assertCondition(bool condition, [List<Object?> args = const <Object?>[]]) {
    _recorder.record(ConsoleMethod.assertCondition, <Object?>[condition, ...args]);
  }

  /// Removes every entry and says so.
  void clear() => _recorder.record(ConsoleMethod.clear, const <Object?>[]);
}
