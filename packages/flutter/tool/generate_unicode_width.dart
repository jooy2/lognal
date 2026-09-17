/// Generates `lib/src/core/text/unicode_width_data.dart` from the Unicode
/// Character Database.
///
/// The viewer lays text out on a grid of cells, so every code point needs a
/// width: zero for combining marks and format characters, two for East Asian
/// wide and fullwidth characters, and one for the rest. Ambiguous characters
/// are listed separately because their width depends on an option.
///
/// Run it with `dart run tool/generate_unicode_width.dart` after changing
/// [unicodeVersion], and commit the result. The build never downloads anything.
///
/// It is the same generator as `packages/js/scripts/generate-unicode-width.mjs`,
/// reading the same two files and collapsing them the same way, so the two
/// packages measure a character identically. A change here is a change there.
library;

import 'dart:convert';
import 'dart:io';

const String unicodeVersion = '17.0.0';
const String baseUrl = 'https://www.unicode.org/Public/$unicodeVersion/ucd';
const int maxCodePoint = 0x10ffff;
const String outputPath = 'lib/src/core/text/unicode_width_data.dart';

const int widthNarrow = 0;
const int widthWide = 1;
const int widthAmbiguous = 2;

Future<String> download(String url) async {
  final HttpClient client = HttpClient();

  try {
    final HttpClientRequest request = await client.getUrl(Uri.parse(url));
    final HttpClientResponse response = await request.close();

    if (response.statusCode != 200) {
      throw StateError('Could not download $url: ${response.statusCode}');
    }

    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

/// Calls [onRange] for every `start..end ; value` line, `@missing` defaults first.
void forEachRange(String text, void Function(int start, int end, String value) onRange) {
  final List<List<Object>> defaults = <List<Object>>[];
  final List<List<Object>> explicit = <List<Object>>[];
  final RegExp missingPattern = RegExp(r'^#\s*@missing:\s*([0-9A-F]+)\.\.([0-9A-F]+)\s*;\s*(\w+)');

  for (final String rawLine in text.split('\n')) {
    final RegExpMatch? missing = missingPattern.firstMatch(rawLine);

    if (missing != null) {
      defaults.add(<Object>[
        int.parse(missing.group(1)!, radix: 16),
        int.parse(missing.group(2)!, radix: 16),
        missing.group(3)!,
      ]);
      continue;
    }

    final String line = rawLine.split('#').first.trim();

    if (line.isEmpty) {
      continue;
    }

    final List<String> parts = line.split(';').map((String part) => part.trim()).toList();
    final List<String> range = parts.first.split('..');
    final int start = int.parse(range.first, radix: 16);
    final int end = range.length > 1 ? int.parse(range[1], radix: 16) : start;

    explicit.add(<Object>[start, end, parts.length > 1 ? parts[1] : '']);
  }

  for (final List<Object> entry in <List<Object>>[...defaults, ...explicit]) {
    onRange(entry[0] as int, entry[1] as int, entry[2] as String);
  }
}

/// Collapses a per-code-point table into a flat `[start, end, start, end, …]` list.
List<int> toRanges(List<int> table, bool Function(int value, int codePoint) wanted) {
  final List<int> ranges = <int>[];
  int start = -1;

  for (int codePoint = 0; codePoint <= maxCodePoint + 1; codePoint++) {
    final bool matches = codePoint <= maxCodePoint && wanted(table[codePoint], codePoint);

    if (matches && start < 0) {
      start = codePoint;
    } else if (!matches && start >= 0) {
      ranges
        ..add(start)
        ..add(codePoint - 1);
      start = -1;
    }
  }

  return ranges;
}

String formatRanges(String name, String description, List<int> ranges) {
  final List<String> lines = <String>[];

  for (int index = 0; index < ranges.length; index += 8) {
    final Iterable<String> chunk = ranges
        .sublist(index, index + 8 > ranges.length ? ranges.length : index + 8)
        .map((int value) => '0x${value.toRadixString(16)}');

    lines.add('  ${chunk.join(', ')},');
  }

  return '/// $description\nconst List<int> $name = <int>[\n${lines.join('\n')}\n];\n';
}

Future<void> main() async {
  final List<String> files = await Future.wait(<Future<String>>[
    download('$baseUrl/EastAsianWidth.txt'),
    download('$baseUrl/extracted/DerivedGeneralCategory.txt'),
    download('https://www.unicode.org/license.txt'),
  ]);
  final List<int> widths = List<int>.filled(maxCodePoint + 1, widthNarrow);
  final List<int> zeroWidth = List<int>.filled(maxCodePoint + 1, 0);

  forEachRange(files[0], (int start, int end, String value) {
    final int width = value == 'W' || value == 'F'
        ? widthWide
        : value == 'A'
        ? widthAmbiguous
        : widthNarrow;

    widths.fillRange(start, end + 1, width);
  });

  forEachRange(files[1], (int start, int end, String value) {
    if (value == 'Mn' || value == 'Me' || value == 'Cf') {
      zeroWidth.fillRange(start, end + 1, 1);
    }
  });

  // Hangul medial vowels and final consonants join the leading consonant before
  // them into one syllable, so they take no cell of their own.
  zeroWidth.fillRange(0x1160, 0x11ff + 1, 1);
  zeroWidth.fillRange(0xd7b0, 0xd7ff + 1, 1);

  final List<int> wide = toRanges(
    widths,
    (int width, int codePoint) => width == widthWide && zeroWidth[codePoint] == 0,
  );
  final List<int> ambiguous = toRanges(
    widths,
    (int width, int codePoint) => width == widthAmbiguous && zeroWidth[codePoint] == 0,
  );
  final List<int> zero = toRanges(zeroWidth, (int value, int _) => value == 1);
  final String licenseComment = files[2]
      .trim()
      .split('\n')
      .map((String line) => line.isEmpty ? '///' : '/// $line')
      .join('\n');
  final String output = <String>[
    '/// Character width data generated from the Unicode Character Database $unicodeVersion',
    '/// (EastAsianWidth.txt and DerivedGeneralCategory.txt) by',
    '/// `tool/generate_unicode_width.dart`. Do not edit this file by hand.',
    '///',
    '/// Every list holds inclusive `[start, end]` pairs, flattened and sorted.',
    '///',
    licenseComment,
    'library;',
    '',
    '/// The version of the Unicode Character Database the width data comes from.',
    "const String unicodeVersion = '$unicodeVersion';",
    '',
    formatRanges(
      'wideRanges',
      'East Asian Wide and Fullwidth code points, drawn two cells wide.',
      wide,
    ),
    formatRanges(
      'ambiguousRanges',
      'East Asian Ambiguous code points, one or two cells wide depending on the option.',
      ambiguous,
    ),
    formatRanges(
      'zeroWidthRanges',
      'Combining marks, format characters and Hangul jamo that attach to the previous character.',
      zero,
    ),
  ].join('\n');

  File(outputPath).writeAsStringSync(output);
  stdout.writeln(
    'Wrote $outputPath: ${wide.length ~/ 2} wide, ${ambiguous.length ~/ 2} ambiguous, '
    '${zero.length ~/ 2} zero-width ranges.',
  );
}
