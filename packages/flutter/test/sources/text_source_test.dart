import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/text/encoding.dart';
import 'package:lognal/src/sources/text/file_source.dart';
import 'package:lognal/src/sources/text/follow_file.dart';
import 'package:lognal/src/sources/text/read_file.dart';

List<String> lines(LogStore store) {
  return store
      .toList()
      .map(
        (LogEntry entry) =>
            entry.parts.map((LogPart part) => part is TextPart ? part.text : '').join(),
      )
      .toList();
}

/// `안녕` followed by a line feed and `하세요`, in EUC-KR.
final Uint8List eucKrBytes = Uint8List.fromList(<int>[
  0xbe,
  0xc8,
  0xb3,
  0xe7,
  0x0a,
  0xc7,
  0xcf,
  0xbc,
  0xbc,
  0xbf,
  0xe4,
]);

/// A decoder that knows just enough EUC-KR for the bytes above, standing in for
/// the one an application registers.
class _TinyEucKrSink extends TextDecoderSink {
  static const Map<int, String> _pairs = <int, String>{
    0xbec8: '안',
    0xb3e7: '녕',
    0xc7cf: '하',
    0xbcbc: '세',
    0xbfe4: '요',
  };

  final List<int> _pending = <int>[];

  @override
  String add(List<int> bytes) {
    _pending.addAll(bytes);

    final StringBuffer text = StringBuffer();

    while (_pending.isNotEmpty) {
      final int byte = _pending.first;

      if (byte < 0x80) {
        text.write(String.fromCharCode(byte));
        _pending.removeAt(0);
        continue;
      }

      if (_pending.length < 2) {
        break;
      }

      text.write(_pairs[(byte << 8) | _pending[1]] ?? '?');
      _pending.removeRange(0, 2);
    }

    return text.toString();
  }

  @override
  String close() {
    _pending.clear();

    return '';
  }
}

class _MemoryFile extends TextFileSource {
  _MemoryFile(this.content, {this.modified});

  String content;
  DateTime? modified;

  @override
  Future<int> length() async => utf8.encode(content).length;

  @override
  Future<DateTime?> lastModified() async => modified;

  @override
  Stream<List<int>> openRead([int start = 0]) {
    final List<int> bytes = utf8.encode(content);

    return Stream<List<int>>.value(bytes.sublist(start));
  }
}

void main() {
  group('encoding detection', () {
    test('reads byte order marks and valid UTF-8', () {
      expect(detectEncoding(<int>[0xff, 0xfe, 0x41, 0x00], 'windows-1252'), 'utf-16le');
      expect(detectEncoding(utf8.encode('한글'), 'euc-kr'), 'utf-8');
      expect(detectEncoding(eucKrBytes, 'euc-kr'), 'euc-kr');
    });

    test('picks the legacy encoding for the language', () {
      expect(legacyEncodingFor('ko-KR'), 'euc-kr');
      expect(legacyEncodingFor('zh-TW'), 'big5');
      expect(legacyEncodingFor('zh-CN'), 'gbk');
      expect(legacyEncodingFor('en-US'), 'windows-1252');
    });

    test('decodes the encodings it ships and takes the rest from a factory', () {
      expect(decoderFor('utf-8'), isNotNull);
      expect(decoderFor('utf-16be'), isNotNull);
      expect(decoderFor('windows-1252')?.add(<int>[0x93, 0x94]), '“”');
      expect(decoderFor('euc-kr'), isNull);

      final void Function() remove = registerTextDecoder(
        (String encoding) => encoding == 'euc-kr' ? _TinyEucKrSink() : null,
      );

      expect(decoderFor('euc-kr'), isNotNull);
      remove();
      expect(decoderFor('euc-kr'), isNull);
    });
  });

  group('readTextBytes', () {
    test('adds one entry per line and handles CRLF split across chunks', () async {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final ReadTextResult result = await readTextBytes(
        utf8.encode('first\r\nsecond\r\nthird'),
        store,
        chunkSize: 6,
      );

      expect(lines(store), <String>['first', 'second', 'third']);
      expect(result.lines, 3);
      expect(result.encoding, 'utf-8');
    });

    test('keeps multi-byte characters that a chunk boundary cuts', () async {
      final LogStore store = LogStore();

      await readTextBytes(utf8.encode('한글 로그\n두 번째 줄'), store, chunkSize: 1);

      expect(lines(store), <String>['한글 로그', '두 번째 줄']);
    });

    test('decodes a Korean legacy file with a registered decoder', () async {
      final void Function() remove = registerTextDecoder(
        (String encoding) => encoding == 'euc-kr' ? _TinyEucKrSink() : null,
      );
      final LogStore store = LogStore();
      final ReadTextResult result = await readTextBytes(
        eucKrBytes,
        store,
        options: const ReadTextOptions(fallbackEncoding: 'euc-kr'),
      );

      expect(result.encoding, 'euc-kr');
      expect(result.decoded, 'euc-kr');
      expect(lines(store), <String>['안녕', '하세요']);
      remove();
    });

    test('says so when nothing can decode the encoding it detected', () async {
      final LogStore store = LogStore();
      final ReadTextResult result = await readTextBytes(
        eucKrBytes,
        store,
        options: const ReadTextOptions(fallbackEncoding: 'euc-kr'),
      );

      expect(result.encoding, 'euc-kr');
      expect(result.decoded, 'windows-1252');
      expect(lines(store), hasLength(2));
    });

    test('turns ANSI colors into styles unless turned off', () async {
      final LogStore styled = LogStore();
      final LogStore plain = LogStore();

      await readTextBytes(utf8.encode('\x1b[32mok\x1b[0m'), styled);
      await readTextBytes(
        utf8.encode('\x1b[32mok\x1b[0m'),
        plain,
        options: const ReadTextOptions(ansi: false),
      );

      expect((styled.at(0)!.parts.first as TextPart).text, 'ok');
      expect((styled.at(0)!.parts.first as TextPart).style?.color, const AnsiTextColor(2));
      expect((plain.at(0)!.parts.first as TextPart).text, contains('\x1b[32m'));
    });
  });

  group('followTextFile', () {
    test('adds the lines appended to a file and starts over when it shrinks', () async {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final _MemoryFile file = _MemoryFile('one\ntw');
      int resets = 0;
      final FollowHandle follow = followTextFile(
        file,
        store,
        options: FollowTextOptions(
          interval: const Duration(milliseconds: 10),
          onReset: () => resets++,
        ),
      );

      await follow.ready;
      expect(lines(store), <String>['one']);

      file.content = 'one\ntwo\nthree\n';
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(lines(store), <String>['one', 'two', 'three']);

      file.content = 'new\n';
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(resets, 1);
      expect(lines(store), <String>['one', 'two', 'three', 'new']);

      follow.stop();
    });

    test('reads the file again when it keeps its size but changes', () async {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final _MemoryFile file = _MemoryFile('aaa\n', modified: DateTime(2026));
      final FollowHandle follow = followTextFile(
        file,
        store,
        options: const FollowTextOptions(interval: Duration(milliseconds: 10)),
      );

      await follow.ready;
      file
        ..content = 'bbb\n'
        ..modified = DateTime(2026, 1, 2);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(lines(store), <String>['aaa', 'bbb']);
      follow.stop();
    });

    test('reports a first read that fails through ready', () async {
      final FollowHandle follow = followTextFile(
        CallbackTextFile(
          length: () => throw const FileSystemExceptionStub(),
          read: (int start) => const Stream<List<int>>.empty(),
        ),
        LogStore(),
        options: const FollowTextOptions(interval: Duration(milliseconds: 10)),
      );

      await expectLater(follow.ready, throwsA(isA<FileSystemExceptionStub>()));
      follow.stop();
    });
  });
}

/// Stands in for whatever the platform throws when a file is gone.
class FileSystemExceptionStub implements Exception {
  /// Creates the failure.
  const FileSystemExceptionStub();
}
