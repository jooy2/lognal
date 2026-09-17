/// Generates `lib/src/core/text/normalize_data.dart` from the Unicode Character
/// Database.
///
/// Dart has no `String.normalize`, and the JavaScript package gets one from the
/// runtime. The filter and the search compare text in normalization form C, so
/// that decomposed Hangul copied out of a macOS file name matches what the user
/// typed, which leaves this side carrying the table the runtime would have held.
///
/// Only the composition step is needed: a canonical combining class for every
/// mark that has one, and every primary composite that is not excluded. Hangul
/// is composed by the algorithm in the standard and takes no data at all.
///
/// Run it with `dart run tool/generate_normalization.dart`, and commit the
/// result. The build never downloads anything.
library;

import 'dart:convert';
import 'dart:io';

const String unicodeVersion = '17.0.0';
const String baseUrl = 'https://www.unicode.org/Public/$unicodeVersion/ucd';
const String outputPath = 'lib/src/core/text/normalize_data.dart';

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

/// Collapses `code point -> value` pairs into flat `[start, end, value]` triples.
List<int> toRanges(Map<int, int> values) {
  final List<int> codePoints = values.keys.toList()..sort();
  final List<int> ranges = <int>[];
  int start = -1;
  int previous = -1;
  int current = -1;

  void flush() {
    if (start >= 0) {
      ranges
        ..add(start)
        ..add(previous)
        ..add(current);
    }
  }

  for (final int codePoint in codePoints) {
    final int value = values[codePoint]!;

    if (start >= 0 && codePoint == previous + 1 && value == current) {
      previous = codePoint;
      continue;
    }

    flush();
    start = codePoint;
    previous = codePoint;
    current = value;
  }

  flush();

  return ranges;
}

String formatList(String name, String description, List<int> values, int perLine) {
  final List<String> lines = <String>[];

  for (int index = 0; index < values.length; index += perLine) {
    final int end = index + perLine > values.length ? values.length : index + perLine;
    final Iterable<String> chunk = values
        .sublist(index, end)
        .map((int value) => '0x${value.toRadixString(16)}');

    lines.add('  ${chunk.join(', ')},');
  }

  return '/// $description\nconst List<int> $name = <int>[\n${lines.join('\n')}\n];\n';
}

Future<void> main() async {
  final List<String> files = await Future.wait(<Future<String>>[
    download('$baseUrl/UnicodeData.txt'),
    download('$baseUrl/CompositionExclusions.txt'),
  ]);
  final Set<int> excluded = <int>{};

  for (final String rawLine in files[1].split('\n')) {
    final String line = rawLine.split('#').first.trim();

    if (line.isNotEmpty) {
      excluded.add(int.parse(line.split('..').first.trim(), radix: 16));
    }
  }

  final Map<int, int> combiningClasses = <int, int>{};
  final List<List<int>> compositions = <List<int>>[];

  for (final String rawLine in files[0].split('\n')) {
    if (rawLine.trim().isEmpty) {
      continue;
    }

    final List<String> fields = rawLine.split(';');
    final int codePoint = int.parse(fields[0], radix: 16);
    final int combiningClass = int.parse(fields[3]);
    final String decomposition = fields[5].trim();

    if (combiningClass != 0) {
      combiningClasses[codePoint] = combiningClass;
    }

    // A canonical decomposition has no `<tag>`, and only a pair composes.
    if (decomposition.isEmpty || decomposition.startsWith('<') || excluded.contains(codePoint)) {
      continue;
    }

    final List<String> parts = decomposition.split(' ');

    if (parts.length != 2) {
      continue;
    }

    compositions.add(<int>[
      int.parse(parts[0], radix: 16),
      int.parse(parts[1], radix: 16),
      codePoint,
    ]);
  }

  // A starter that is itself a mark cannot begin a composition here, and neither
  // can a pair whose second code point has no combining class: those compose
  // only through a full decomposition, which this table does not carry.
  compositions.removeWhere((List<int> pair) {
    return combiningClasses.containsKey(pair[0]) || !combiningClasses.containsKey(pair[1]);
  });
  compositions.sort((List<int> a, List<int> b) {
    return a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]);
  });

  final List<int> classRanges = toRanges(combiningClasses);
  final List<int> pairs = compositions.expand((List<int> pair) => pair).toList();
  final String output = <String>[
    '/// Canonical composition data generated from the Unicode Character Database',
    '/// $unicodeVersion (UnicodeData.txt and CompositionExclusions.txt) by',
    '/// `tool/generate_normalization.dart`. Do not edit this file by hand.',
    '///',
    '/// See `normalize.dart` for what the two lists are and why this package',
    '/// carries them at all.',
    'library;',
    '',
    formatList(
      'combiningClassRanges',
      'Inclusive `[start, end, class]` triples for every code point whose canonical combining class is not zero.',
      classRanges,
      9,
    ),
    formatList(
      'compositionPairs',
      '`[starter, mark, composite]` triples for every primary composite that is not excluded, sorted by starter and then by mark.',
      pairs,
      9,
    ),
  ].join('\n');

  File(outputPath).writeAsStringSync(output);
  stdout.writeln(
    'Wrote $outputPath: ${classRanges.length ~/ 3} combining class ranges, '
    '${pairs.length ~/ 3} composition pairs.',
  );
}
