import 'dart:async';

import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/text/encoding.dart';
import 'package:lognal/src/sources/text/file_source.dart';
import 'package:lognal/src/sources/text/read_file.dart';

/// How a growing file is followed.
class FollowTextOptions {
  /// Creates the options.
  const FollowTextOptions({
    this.interval = const Duration(seconds: 1),
    this.encoding = 'auto',
    this.fallbackEncoding,
    this.level = LogLevel.log,
    this.ansi = true,
    this.onReset,
    this.onError,
  });

  /// How long to wait between checks for new data.
  final Duration interval;

  /// The encoding, or `auto` to detect it from the first bytes.
  final String encoding;

  /// The encoding `auto` falls back to when the file is not UTF-8.
  final String? fallbackEncoding;

  /// The level of every line.
  final LogLevel level;

  /// Whether ANSI escape codes become styles.
  final bool ansi;

  /// Called when the file was replaced rather than appended to: it got shorter,
  /// or it kept its size but was modified. The file is then read again from the
  /// start.
  final void Function()? onReset;

  /// Called when reading fails, for example because the file was removed.
  final void Function(Object error)? onError;
}

/// Controls a followed file.
class FollowHandle {
  FollowHandle._(this._stop, this.ready);

  final void Function() _stop;

  /// Completes after the first read with the number of lines it added, or with
  /// an error when that read fails. Checking goes on either way; later failures
  /// go to [FollowTextOptions.onError].
  final Future<int> ready;

  /// Stops checking the file and writes any unfinished last line.
  void stop() => _stop();
}

/// Reads a file and keeps adding the lines appended to it, like `tail -f`.
///
/// Every check asks the source for its size and reads what was added since the
/// last one. When the file gets shorter, or keeps its size but changes, it was
/// replaced rather than appended to, so it is read again from the start and
/// [FollowTextOptions.onReset] is called.
FollowHandle followTextFile(
  TextFileSource file,
  LogStore store, {
  FollowTextOptions options = const FollowTextOptions(),
  String? locale,
}) {
  final Completer<int> ready = Completer<int>();
  final String fallback = options.fallbackEncoding ?? legacyEncodingFor(locale);
  TextLineWriter writer = TextLineWriter(store, level: options.level, ansi: options.ansi);
  TextDecoderSink? decoder;
  Timer? timer;
  int offset = 0;
  DateTime? lastModified;
  bool stopped = false;

  void reset() {
    final TextDecoderSink? sink = decoder;

    if (sink != null) {
      writer.write(sink.close());
    }

    writer.flush();
    writer = TextLineWriter(store, level: options.level, ansi: options.ansi);
    decoder = null;
    offset = 0;
    options.onReset?.call();
  }

  Future<void> check() async {
    final int size = await file.length();

    if (stopped) {
      return;
    }

    final DateTime? modified = await file.lastModified();
    final bool replaced =
        size < offset ||
        (size == offset &&
            offset > 0 &&
            modified != null &&
            lastModified != null &&
            modified != lastModified);

    lastModified = modified;

    if (replaced) {
      reset();
    }

    if (size == offset) {
      return;
    }

    final List<int> bytes = <int>[];

    await for (final List<int> chunk in file.openRead(offset)) {
      if (stopped) {
        return;
      }

      bytes.addAll(chunk);
    }

    if (bytes.isEmpty) {
      return;
    }

    decoder ??=
        decoderFor(
          options.encoding == 'auto' ? detectEncoding(bytes, fallback) : options.encoding,
        ) ??
        decoderFor('windows-1252');
    writer.write(decoder!.add(bytes));
    offset += bytes.length;
  }

  Future<void> loop() async {
    if (stopped) {
      return;
    }

    try {
      await check();

      if (!ready.isCompleted) {
        ready.complete(writer.lines);
      }
    } catch (error) {
      if (!ready.isCompleted) {
        ready.completeError(error);
      } else {
        options.onError?.call(error);
      }
    }

    if (!stopped) {
      timer = Timer(options.interval, loop);
    }
  }

  unawaited(loop());

  // A caller that never awaits `ready` should not see an unhandled error.
  unawaited(ready.future.catchError((Object _) => 0));

  return FollowHandle._(() {
    if (stopped) {
      return;
    }

    stopped = true;
    timer?.cancel();

    final TextDecoderSink? sink = decoder;

    if (sink != null) {
      writer.write(sink.close());
    }

    writer.flush();
  }, ready.future);
}
