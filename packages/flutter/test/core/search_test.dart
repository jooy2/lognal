import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/search.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';

import '../support/text.dart';

LogEntryInit text(String value) => LogEntryInit(parts: <LogPart>[TextPart(value)]);

/// A store, a layout over it and a search over that, as one value.
class SearchContext {
  /// Creates the trio.
  const SearchContext(this.store, this.layout, this.search);

  /// The store the entries went into.
  final LogStore store;

  /// The layout over that store.
  final LogLayout layout;

  /// The search over that layout.
  final LogSearch search;
}

SearchContext setup(List<String> lines, [int maxEntries = 1000]) {
  final LogStore store = LogStore(
    options: LogStoreOptions(maxEntries: maxEntries, mergeRepeats: RepeatMode.keep),
  );
  final LogLayout layout = LogLayout(store);
  final LogSearch search = LogSearch(layout);

  store.append(lines.map(text).toList());
  layout.sync();

  return SearchContext(store, layout, search);
}

void scanAll(LogLayout layout, LogSearch search) {
  layout.sync();

  while (search.pending) {
    search.scan(2);
  }
}

void main() {
  group('compileSearch', () {
    test('matches the text as typed, ignoring case and special characters', () {
      final RegExp pattern = compileSearch('a.b(').pattern!;

      expect(
        pattern.allMatches('A.B( axb(').map((RegExpMatch match) => match.group(0)).toList(),
        <String>['A.B('],
      );
      expect(compileSearch('').pattern, isNull);
      expect(compileSearch('').error, isNull);
    });

    test('matches case and regular expressions when asked, and reports a bad pattern', () {
      expect(
        compileSearch(
          'error',
          const SearchOptions(caseSensitive: true),
        ).pattern!.allMatches('Error error').map((RegExpMatch match) => match.group(0)).toList(),
        <String>['error'],
      );
      expect(
        compileSearch(
          r'id=\d+',
          const SearchOptions(regex: true),
        ).pattern!.allMatches('id=12 id=345').map((RegExpMatch match) => match.group(0)).toList(),
        <String>['id=12', 'id=345'],
      );

      final CompiledSearch broken = compileSearch('(', const SearchOptions(regex: true));

      expect(broken.pattern, isNull);
      expect(broken.error, isA<String>());
    });
  });

  group('LogSearch', () {
    test('finds every match as cell ranges, in order, a slice at a time', () {
      final SearchContext context = setup(<String>[
        'error one',
        'nothing',
        'Error two, error three',
      ]);

      context.search.setQuery('error');
      expect(context.search.pending, isTrue);
      context.search.scan(1);
      expect(context.search.count, 1);
      expect(context.search.pending, isTrue);
      scanAll(context.layout, context.search);

      expect(context.search.count, 3);
      expect(context.search.getMatch(1)?.line, 0);
      expect(context.search.getMatch(1)?.from, 0);
      expect(context.search.getMatch(1)?.to, 5);
      expect(context.search.getMatch(2)?.from, 11);
      expect(context.search.getMatch(2)?.to, 16);
      expect(context.search.pending, isFalse);
    });

    test('counts wide characters as two cells and matches decomposed Hangul', () {
      final SearchContext context = setup(<String>['파일 $decomposedHangul.txt']);

      context.search.setQuery('한글');
      scanAll(context.layout, context.search);

      // `파일 ` takes five cells, and each Hangul syllable two.
      expect(context.search.getMatch(0)?.from, 5);
      expect(context.search.getMatch(0)?.to, 9);
    });

    test('searches again when only the options change, and finds nothing for a bad pattern', () {
      final SearchContext context = setup(<String>['Error 1', 'error 22']);

      context.search.setQuery('error');
      scanAll(context.layout, context.search);
      expect(context.search.count, 2);

      expect(context.search.setQuery('error', const SearchOptions(caseSensitive: true)), isTrue);
      scanAll(context.layout, context.search);
      expect(context.search.count, 1);

      context.search.setQuery(r'\d{2}', const SearchOptions(regex: true));
      scanAll(context.layout, context.search);
      expect(context.search.count, 1);
      expect(context.search.getMatch(0)?.entryId, 2);
      expect(context.search.getMatch(0)?.from, 6);
      expect(context.search.getMatch(0)?.to, 8);

      context.search.setQuery('[', const SearchOptions(regex: true));
      expect(context.search.error, isA<String>());
      expect(context.search.pending, isFalse);
      expect(context.search.count, 0);
    });

    test('moves through the matches and wraps around', () {
      final SearchContext context = setup(<String>['a', 'a', 'a']);

      context.search.setQuery('a');
      scanAll(context.layout, context.search);

      expect(context.search.next()?.entryId, 1);
      expect(context.search.next()?.entryId, 2);
      expect(context.search.previous()?.entryId, 1);
      expect(context.search.previous()?.entryId, 3);
      expect(context.search.next()?.entryId, 1);
    });

    test('searches new entries, forgets dropped ones and keeps the current match', () {
      final SearchContext context = setup(<String>['hit 1', 'hit 2', 'hit 3'], 3);

      context.search.setQuery('hit');
      scanAll(context.layout, context.search);
      context.search.select(2);

      context.store.add(text('hit 4'));
      scanAll(context.layout, context.search);

      expect(context.search.count, 3);
      expect(context.search.getMatch(0)?.entryId, 2);
      expect(context.search.current, 1);
      expect(context.search.getMatch(context.search.current)?.entryId, 3);
    });

    test('starts again when the filter changes and finds the current match again', () {
      final SearchContext context = setup(<String>['hit one', 'skip', 'hit two']);

      context.search.setQuery('hit');
      scanAll(context.layout, context.search);
      context.search.select(1);

      context.layout.setFilter(const LogFilter(text: 'two'));
      scanAll(context.layout, context.search);

      expect(context.search.count, 1);
      expect(context.search.current, 0);
      expect(context.search.matchesOf(3), hasLength(1));
      expect(context.search.matchesOf(1), isNull);
    });
  });

  group('LogLayout.locatePosition', () {
    test('returns the wrapped row that shows a cell', () {
      // Lines never wrap narrower than 16 columns.
      final SearchContext context = setup(<String>['first', 'aaaa bbbb cccc dddd eeee']);

      context.layout.columns = 16;
      context.layout.sync();

      final PositionLocation? start = context.layout.locatePosition(
        const TextPosition(entryId: 2, line: 0, cell: 0),
      );

      expect(start?.entryRow, 0);
      expect(start?.indent, 0);
      expect(
        context.layout.locatePosition(const TextPosition(entryId: 2, line: 0, cell: 12))?.entryRow,
        0,
      );
      expect(
        context.layout.locatePosition(const TextPosition(entryId: 2, line: 0, cell: 20))?.entryRow,
        1,
      );
      expect(
        context.layout.locatePosition(const TextPosition(entryId: 9, line: 0, cell: 0)),
        isNull,
      );
    });
  });
}
