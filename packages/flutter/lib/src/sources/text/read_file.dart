import 'dart:async';

import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/text/ansi.dart';
import 'package:lognal/src/core/text/line_splitter.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/text/encoding.dart';

/// How a text file is read into a store.
class ReadTextOptions {
  /// Creates the options.
  const ReadTextOptions({
    this.encoding = 'auto',
    this.fallbackEncoding,
    this.level = LogLevel.log,
    this.ansi = true,
    this.onProgress,
  });

  /// The encoding of the file, such as `utf-8`. `auto` reads the byte order
  /// mark, then tries UTF-8, then falls back to [fallbackEncoding].
  final String encoding;

  /// The encoding `auto` uses when the file is not UTF-8. Defaults to the legacy
  /// encoding of the platform's language, such as `euc-kr` for Korean. An
  /// encoding this package cannot decode needs [registerTextDecoder].
  final String? fallbackEncoding;

  /// The level of every line.
  final LogLevel level;

  /// Whether ANSI escape codes become styles.
  final bool ansi;

  /// Called after every chunk with the bytes read so far, and the total when the
  /// size is known.
  final void Function(int loaded, int? total)? onProgress;
}

/// What a read produced.
class ReadTextResult {
  /// Creates the result.
  const ReadTextResult({
    required this.lines,
    required this.bytes,
    required this.encoding,
    required this.decoded,
  });

  /// The number of lines added.
  final int lines;

  /// The number of bytes read.
  final int bytes;

  /// The encoding the file was taken to be in.
  final String encoding;

  /// The encoding the text was actually decoded with.
  ///
  /// It differs from [encoding] when nothing here could decode the one the file
  /// announced, which is how a legacy CJK file reads as mojibake instead of
  /// failing. Compare the two to tell the reader what happened.
  final String decoded;
}

/// The encoding used when the file announces one nothing can decode.
const String _lastResortEncoding = 'windows-1252';

/// The most bytes read before the encoding has to be decided.
const int _detectionBytes = 64 * 1024;

/// Turns decoded text into store entries one line at a time, keeping partial
/// lines and the ANSI style between chunks.
class TextLineWriter {
  /// Creates a writer over a store.
  TextLineWriter(this.store, {this.level = LogLevel.log, bool ansi = true})
    : _parser = ansi ? AnsiParser() : null;

  /// The store the lines go into.
  final LogStore store;

  /// The level of every line.
  final LogLevel level;

  final AnsiParser? _parser;
  final LogLineSplitter _splitter = LogLineSplitter();
  int _count = 0;

  /// The number of lines written.
  int get lines => _count;

  /// Whether an unfinished line is waiting for its line break.
  bool get hasPending => _splitter.hasPending;

  /// Writes a chunk of text, holding back its unfinished last line.
  void write(String text) => _add(_splitter.push(text));

  /// Writes the unfinished last line, if any.
  void flush() => _add(_splitter.flush());

  void _add(List<String> lines) {
    if (lines.isEmpty) {
      return;
    }

    final AnsiParser? parser = _parser;

    store.append(
      lines
          .map(
            (String line) => LogEntryInit(
              level: level,
              parts: parser == null
                  ? <LogPart>[TextPart(line)]
                  : parser.parse(line).cast<LogPart>().toList(),
            ),
          )
          .toList(),
    );
    _count += lines.length;
  }
}

/// Reads a text file from a stream of byte chunks and adds one entry per line.
///
/// Nothing is held in memory but the chunk being decoded and the line being
/// built, so a file larger than memory reads fine. The store's `maxEntries`
/// still decides how many lines are kept.
///
/// `File(path).openRead()` on the platforms that have `dart:io`, and a picked
/// file's own stream on the web, both fit this directly.
Future<ReadTextResult> readTextStream(
  Stream<List<int>> chunks,
  LogStore store, {
  ReadTextOptions options = const ReadTextOptions(),
  int? totalBytes,
  String? locale,
}) async {
  final TextLineWriter writer = TextLineWriter(store, level: options.level, ansi: options.ansi);
  final List<int> head = <int>[];
  final String fallback = options.fallbackEncoding ?? legacyEncodingFor(locale);
  String? encoding = options.encoding == 'auto' ? null : options.encoding;
  TextDecoderSink? decoder;
  String decoded = '';
  int offset = 0;

  void start(List<int> bytes) {
    encoding ??= detectEncoding(bytes, fallback);
    decoder = decoderFor(encoding!);

    if (decoder == null) {
      decoded = _lastResortEncoding;
      decoder = decoderFor(_lastResortEncoding);
    } else {
      decoded = encoding!;
    }
  }

  await for (final List<int> chunk in chunks) {
    offset += chunk.length;

    if (decoder == null) {
      head.addAll(chunk);

      if (head.length < _detectionBytes) {
        options.onProgress?.call(offset, totalBytes);
        continue;
      }

      start(head);
      writer.write(decoder!.add(head));
      head.clear();
      options.onProgress?.call(offset, totalBytes);
      continue;
    }

    writer.write(decoder!.add(chunk));
    options.onProgress?.call(offset, totalBytes);
  }

  if (decoder == null) {
    start(head);
    writer.write(decoder!.add(head));
  }

  writer
    ..write(decoder!.close())
    ..flush();

  return ReadTextResult(
    lines: writer.lines,
    bytes: offset,
    encoding: encoding ?? fallback,
    decoded: decoded,
  );
}

/// Reads a text file already in memory and adds one entry per line.
Future<ReadTextResult> readTextBytes(
  List<int> bytes,
  LogStore store, {
  ReadTextOptions options = const ReadTextOptions(),
  int chunkSize = 256 * 1024,
  String? locale,
}) {
  Stream<List<int>> chunks() async* {
    for (int offset = 0; offset < bytes.length; offset += chunkSize) {
      final int end = offset + chunkSize;

      yield bytes.sublist(offset, end > bytes.length ? bytes.length : end);
    }
  }

  return readTextStream(
    chunks(),
    store,
    options: options,
    totalBytes: bytes.length,
    locale: locale,
  );
}
