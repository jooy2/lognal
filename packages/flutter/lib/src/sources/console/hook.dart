import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/console/recorder.dart';

/// How much of what the application already prints reaches the viewer.
class HookOptions {
  /// Creates the options.
  const HookOptions({
    this.recorder = defaultRecorderOptions,
    this.passthrough = true,
    this.level = LogLevel.log,
  });

  /// What a recorded call captures. Only [hookFlutterErrors] captures values;
  /// the other two hooks receive text that is already formatted.
  final RecorderOptions recorder;

  /// Whether the original output still runs, so messages keep reaching the
  /// terminal and the IDE.
  final bool passthrough;

  /// The level every captured line is given. [hookFlutterErrors] ignores it,
  /// because what it captures is an error.
  final LogLevel level;
}

/// Records everything `debugPrint` writes into a store, for as long as the
/// returned function has not been called.
///
/// This is Dart's answer to hooking the console: `debugPrint` is a variable
/// holding a function, so it can be replaced and put back, and it is what
/// Flutter itself prints through. If another package wrapped it after lognal
/// did, that wrapper is left in place and lognal's stops recording, the same way
/// the JavaScript package leaves a console method somebody else replaced.
///
/// `print` cannot be replaced like this, because it belongs to the zone rather
/// than to a variable. Use [runZonedWithLognal] for that.
void Function() hookDebugPrint(LogStore store, {HookOptions options = const HookOptions()}) {
  final DebugPrintCallback original = debugPrint;
  bool active = true;
  bool recording = false;

  void wrapper(String? message, {int? wrapWidth}) {
    if (active && !recording && message != null) {
      recording = true;

      try {
        store.writeLines(message, WriteOptions(level: options.level));
      } catch (_) {
        // Recording must never break the code that logged the message.
      } finally {
        recording = false;
      }
    }

    if (options.passthrough) {
      original(message, wrapWidth: wrapWidth);
    }
  }

  debugPrint = wrapper;

  return () {
    if (!active) {
      return;
    }

    active = false;

    if (debugPrint == wrapper) {
      debugPrint = original;
    }
  };
}

/// Runs [body] in a zone whose `print` writes into a store.
///
/// `print` is resolved through the current zone rather than through a variable,
/// so it is captured by running the code inside a zone rather than by replacing
/// anything. Wrap `runApp` in this to catch what the application prints.
R runZonedWithLognal<R>(
  LogStore store,
  R Function() body, {
  HookOptions options = const HookOptions(),
}) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
        try {
          store.writeLines(message, WriteOptions(level: options.level));
        } catch (_) {
          // Recording must never break the code that printed the message.
        }

        if (options.passthrough) {
          parent.print(zone, message);
        }
      },
    ),
  );
}

/// Records the errors the framework reports into a store, for as long as the
/// returned function has not been called.
///
/// A widget that throws during a build, a layout that overflows and a failed
/// image load all arrive here, which is the part of a Flutter application's
/// output a developer most wants in front of them.
void Function() hookFlutterErrors(LogStore store, {HookOptions options = const HookOptions()}) {
  final ConsoleRecorder recorder = ConsoleRecorder(store, options: options.recorder);
  final FlutterExceptionHandler? original = FlutterError.onError;
  bool active = true;

  void wrapper(FlutterErrorDetails details) {
    if (active) {
      try {
        recorder.record(ConsoleMethod.error, <Object?>[
          details.exception,
          if (details.context != null) '${details.context}',
        ], stack: details.stack);
      } catch (_) {
        // Recording must never swallow the error it was reporting.
      }
    }

    if (options.passthrough) {
      (original ?? FlutterError.presentError)(details);
    }
  }

  FlutterError.onError = wrapper;

  return () {
    if (!active) {
      return;
    }

    active = false;

    if (FlutterError.onError == wrapper) {
      FlutterError.onError = original;
    }
  };
}
