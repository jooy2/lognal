import 'dart:typed_data';

// `package:flutter/widgets.dart` re-exports `package:characters`, which is how
// the viewer reaches the splitter without a dependency of its own.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/ansi.dart';
import 'package:lognal/src/core/text/graphemes.dart';
import 'package:lognal/src/core/text/line_splitter.dart';
import 'package:lognal/src/core/text/measure.dart';
import 'package:lognal/src/core/text/normalize.dart';
import 'package:lognal/src/core/text/shape.dart';
import 'package:lognal/src/core/text/width.dart';
import 'package:lognal/src/core/text/wrap.dart';
import 'package:lognal/src/core/types.dart';

import '../support/text.dart';

List<String> rowsOf(String text, int columns, [WrapMode mode = WrapMode.word]) {
  final ShapedLine line = shapeLine(<LineSpan>[LineTextSpan(text)], 0);
  final List<int> starts = wrapLine(line, columns, mode);

  return List<String>.generate(starts.length, (int index) {
    final int end = index + 1 < starts.length ? starts[index + 1] : line.length;

    return textBetween(line, starts[index], end);
  });
}

/// The same ASCII line in the general form, so both wrapping paths can be
/// compared.
ShapedLine generalLine(String text) {
  final List<String> characters = text.split('');

  return ShapedLine(
    indent: 0,
    spans: <ShapedSpan>[ShapedSpan(text)],
    spanStarts: Uint32List.fromList(<int>[0]),
    simple: false,
    text: text,
    clusters: characters,
    widths: Uint8List.fromList(characters.map((String _) => 1).toList()),
    breaks: Uint8List.fromList(
      characters.map((String character) => character == ' ' ? breakSpace : breakNormal).toList(),
    ),
    length: text.length,
    cells: text.length,
  );
}

void main() {
  group('character width', () {
    test('gives ASCII and Latin-1 letters one cell', () {
      expect(codePointWidth(0x41), 1);
      expect(clusterWidth('é'), 1);
    });

    test('gives Hangul, Han, kana and fullwidth forms two cells', () {
      expect(clusterWidth('한'), 2);
      expect(clusterWidth('中'), 2);
      expect(clusterWidth('カ'), 2);
      expect(clusterWidth('Ａ'), 2);
    });

    test('gives emoji sequences two cells', () {
      expect(clusterWidth('👍'), 2);
      expect(clusterWidth('👩‍💻'), 2);
      expect(clusterWidth('🇰🇷'), 2);
      expect(clusterWidth('❤️'), 2);
    });

    test('treats combining marks and Hangul vowel jamo as zero width inside a cluster', () {
      expect(clusterWidth(decomposedAcute), 1);
      expect(clusterWidth(decomposedHangul.substring(0, 3)), 2);
      expect(codePointWidth(0x0301), 0);
    });

    test('uses the ambiguous width option, except for box drawing', () {
      expect(clusterWidth('①', 1), 1);
      expect(clusterWidth('①', 2), 2);
      expect(clusterWidth('─', 2), 1);
    });

    test('measures and truncates strings in cells', () {
      expect(measureCells('ab한글'), 6);
      expect(truncateCells('한글입니다', 5), '한글…');
    });
  });

  group('grapheme splitting', () {
    tearDown(() => setGraphemeSplitter(null));

    test('keeps decomposed Hangul syllables together', () {
      expect(splitGraphemesFallback(decomposedHangul), hasLength(2));

      setGraphemeSplitter((String text) => text.characters.toList());
      expect(splitGraphemes(decomposedHangul), hasLength(2));
    });

    test('keeps emoji sequences and flags together in the fallback splitter', () {
      expect(splitGraphemesFallback('a👩‍💻🇰🇷🇯🇵👍🏽b'), <String>[
        'a',
        '👩‍💻',
        '🇰🇷',
        '🇯🇵',
        '👍🏽',
        'b',
      ]);
    });
  });

  group('normalization', () {
    test('composes Hangul jamo and combining marks', () {
      expect(normalizeNfc(decomposedHangul), '한글');
      expect(normalizeNfc(decomposedAcute), 'é');
      expect(normalizeNfc('already composed 한글'), 'already composed 한글');
    });
  });

  group('shaping', () {
    test('keeps plain ASCII in the compact form', () {
      final ShapedLine line = shapeLine(<LineSpan>[const LineTextSpan('hello world')], 2);

      expect(line.simple, isTrue);
      expect(line.clusters, isNull);
      expect(line.cells, 11);
      expect(line.indent, 2);
    });

    test('expands tabs to the next tab stop', () {
      final ShapedLine line = shapeLine(
        <LineSpan>[const LineTextSpan('ab\tc')],
        0,
        const ShapeOptions(tabSize: 4, maxClusters: 100),
      );

      expect(line.text, 'ab  c');
    });

    test('shows control and bidirectional formatting characters as visible notation', () {
      final ShapedLine line = shapeLine(<LineSpan>[
        LineTextSpan('a${String.fromCharCode(0x1b)}b${String.fromCharCode(0x202e)}c'),
      ], 0);

      expect(line.text, 'a^[b<U+202E>c');
      expect(
        line.spans.any((ShapedSpan span) => span.token == StyleToken.muted && span.text == '^['),
        isTrue,
      );
    });

    test('marks Hangul as keeping words together', () {
      final ShapedLine line = shapeLine(<LineSpan>[const LineTextSpan('한 글')], 0);

      expect(line.breaks?.toList(), <int>[breakKeep, breakSpace, breakKeep]);
    });

    test('cuts a line past the cluster limit', () {
      final ShapedLine line = shapeLine(
        <LineSpan>[LineTextSpan('x' * 50), const LineTextSpan('가')],
        0,
        const ShapeOptions(maxClusters: 10),
      );

      expect(line.length, 10);
      expect(line.text.endsWith(' …'), isTrue);
    });
  });

  group('wrapping', () {
    test('breaks at spaces and lets the space hang', () {
      expect(rowsOf('hello brave new world', 11), <String>['hello brave ', 'new world']);
    });

    test('breaks a word longer than the row between characters', () {
      expect(rowsOf('abcdefghij', 4), <String>['abcd', 'efgh', 'ij']);
    });

    test('fills rows in char mode and keeps one row in none mode', () {
      expect(rowsOf('hello world', 4, WrapMode.char), <String>['hell', 'o wo', 'rld']);
      expect(rowsOf('hello world', 4, WrapMode.none), <String>['hello world']);
    });

    test('breaks Korean at spaces and Chinese between characters', () {
      expect(rowsOf('안녕하세요 반갑습니다', 12), <String>['안녕하세요 ', '반갑습니다']);
      expect(rowsOf('服务器已经启动了', 6), <String>['服务器', '已经启', '动了']);
    });

    test('never splits a wide character across rows', () {
      for (final String row in rowsOf('a한글한글한글', 4, WrapMode.char)) {
        expect(measureCells(row), lessThanOrEqualTo(4));
      }
    });

    test('wraps plain ASCII the same way on the fast path and the general path', () {
      const List<String> samples = <String>[
        'one two three four five six',
        'aaaaaaaaaaaaa b c',
        '  leading spaces and    gaps  ',
        'x',
      ];

      for (final String text in samples) {
        for (int columns = 1; columns < 16; columns++) {
          for (final WrapMode mode in <WrapMode>[WrapMode.word, WrapMode.char]) {
            expect(
              wrapLine(shapeLine(<LineSpan>[LineTextSpan(text)], 0), columns, mode),
              wrapLine(generalLine(text), columns, mode),
              reason: '"$text" at $columns columns in ${mode.name}',
            );
          }
        }
      }
    });
  });

  group('ANSI escape codes', () {
    test('turns colors and weights into styles and resets them', () {
      final List<TextPart> parts = AnsiParser().parse('\x1b[31;1mred\x1b[0m plain');

      expect(parts.map((TextPart part) => part.text).toList(), <String>['red', ' plain']);
      expect(parts.first.style?.color, const AnsiTextColor(1));
      expect(parts.first.style?.bold, isTrue);
      expect(parts[1].style, isNull);
    });

    test('reads 256-color and true-color codes', () {
      final List<TextPart> parts = AnsiParser().parse('\x1b[38;5;208ma\x1b[48;2;1;2;255mb');

      expect(parts.first.style?.color, const AnsiTextColor(208));
      expect(parts[1].style?.background, const RgbTextColor(0xff0102ff));
    });

    test('keeps the style across calls and removes other sequences', () {
      final AnsiParser parser = AnsiParser();

      parser.parse('\x1b[32mstart');
      expect(parser.parse('next').first.style?.color, const AnsiTextColor(2));
      expect(stripAnsi('\x1b[2J\x1b]8;;https://example.com\x07link\x1b]8;;\x07 done'), 'link done');
    });
  });

  group('line splitting', () {
    test('handles CRLF split across chunks and a lone CR', () {
      final LogLineSplitter splitter = LogLineSplitter();

      expect(splitter.push('a\r'), <String>['a']);
      expect(splitter.push('\nb\rc'), <String>['b']);
      expect(splitter.flush(), <String>['c']);
      expect(splitLines('x\ny\n'), <String>['x', 'y']);
    });
  });
}
