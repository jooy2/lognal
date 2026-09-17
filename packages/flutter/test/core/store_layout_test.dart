import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/time.dart';
import 'package:lognal/src/core/types.dart';

import '../support/text.dart';

LogEntryInit text(String value) => LogEntryInit(parts: <LogPart>[TextPart(value)]);

const ValueNode object = ValueNode(
  kind: ValueKind.object,
  children: <ValueEntry>[
    ValueEntry(
      key: 'id',
      keyKind: ValueKeyKind.property,
      value: ValueNode(kind: ValueKind.number, value: '1'),
    ),
    ValueEntry(
      key: 'tags',
      keyKind: ValueKeyKind.property,
      value: ValueNode(kind: ValueKind.list, size: 2, children: <ValueEntry>[]),
    ),
  ],
);

List<String> rowTexts(LogLayout layout) {
  layout.sync();

  return layout
      .getRows(0, layout.rowCount)
      .map((VisualRow row) => row.runs.map((RowRun run) => run.text).join())
      .toList();
}

void main() {
  group('LogStore', () {
    test('gives entries consecutive ids and looks them up by id', () {
      final LogStore store = LogStore();
      final List<LogEntry> entries = store.append(<LogEntryInit>[text('a'), text('b')]);

      expect(entries[1].id, entries[0].id + 1);
      expect(store.get(entries[1].id), same(entries[1]));
      expect(store.size, 2);
    });

    test('merges identical consecutive messages into a repeat count', () {
      final LogStore store = LogStore();
      final List<StoreChange> changes = <StoreChange>[];

      store.subscribe(changes.add);
      store.add(text('same'));
      store.add(text('same'));
      store.add(text('other'));

      expect(store.size, 2);
      expect(store.at(0)?.repeat, 2);
      expect(changes.whereType<StoreUpdate>(), isNotEmpty);
    });

    test('keeps a run of identical messages and collapses it with MergeRepeats.collapse', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.collapse),
      );
      final LogLayout layout = LogLayout(store);

      store.append(<LogEntryInit>[
        text('a'),
        text('a'),
        text('a'),
        text('b'),
        text('a'),
        text('a'),
      ]);

      final List<LogEntry> entries = store.toList();
      final LogEntry first = entries.first;
      final LogEntry fifth = entries[4];

      expect(store.size, 6);
      expect(first.repeat, 3);
      expect(first.collapsed, isTrue);
      expect(store.isRunHead(first), isTrue);
      expect(fifth.repeat, 2);
      expect(rowTexts(layout), <String>['a', 'b', 'a']);

      // Opening the run shows every message it stands for.
      store.setCollapsed(first.id, false);
      expect(rowTexts(layout), <String>['a', 'a', 'a', 'b', 'a']);

      // A later message joins the run at the end, and the open run stays open.
      store.add(text('a'));
      expect(store.isRunHead(fifth), isTrue);
      expect(fifth.repeat, 3);
      expect(rowTexts(layout), <String>['a', 'a', 'a', 'b', 'a']);

      store.setCollapsed(first.id, true);
      expect(rowTexts(layout), <String>['a', 'b', 'a']);
    });

    test('does not merge messages that hold expandable values', () {
      final LogStore store = LogStore();

      store.add(const LogEntryInit(parts: <LogPart>[ValuePart(object)]));
      store.add(const LogEntryInit(parts: <LogPart>[ValuePart(object)]));

      expect(store.size, 2);
    });

    test('drops the oldest entries past maxEntries', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(maxEntries: 3, mergeRepeats: MergeRepeats.keep),
      );

      for (int index = 0; index < 5; index++) {
        store.add(text('$index'));
      }

      expect(store.size, 3);
      expect(store.firstId, 3);
      expect(store.get(2), isNull);
      expect(
        store.toList().map((LogEntry entry) => (entry.parts.first as TextPart).text).toList(),
        <String>['2', '3', '4'],
      );
    });

    test('writes one entry per line, with ANSI styles when asked', () {
      final LogStore store = LogStore();
      final List<LogEntry> entries = store.writeLines(
        '\x1b[31mred\nnext',
        const WriteOptions(ansi: true, level: LogLevel.warn),
      );

      expect(entries, hasLength(2));
      expect((entries[1].parts.first as TextPart).text, 'next');
      expect((entries[1].parts.first as TextPart).style?.color, const AnsiTextColor(1));
      expect(entries.first.level, LogLevel.warn);
    });

    test('keeps counting ids after clear', () {
      final LogStore store = LogStore();

      store.add(text('a'));
      store.clear();

      final LogEntry entry = store.add(text('b'))!;

      expect(store.size, 1);
      expect(entry.id, 2);
      expect(store.firstId, 2);
    });
  });

  group('filters', () {
    test('matches by minimum level and by text', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final List<LogEntry> entries = store.append(<LogEntryInit>[
        LogEntryInit(parts: text('cache miss').parts, level: LogLevel.debug),
        LogEntryInit(parts: text('disk almost full').parts, level: LogLevel.warn),
      ]);
      final CompiledFilter byLevel = compileFilter(const LogFilter(minLevel: LogLevel.info));
      final CompiledFilter byText = compileFilter(const LogFilter(text: 'CACHE'));

      expect(byLevel.matches?.call(entries[0]), isFalse);
      expect(byLevel.matches?.call(entries[1]), isTrue);
      expect(byText.matches?.call(entries[0]), isTrue);
      expect(byText.matches?.call(entries[1]), isFalse);
    });

    test('reports an invalid regular expression', () {
      expect(compileFilter(const LogFilter(text: '(', regex: true)).error, isNotNull);
    });

    test('hides the entries a mute rule matches and counts them', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);

      store.append(<LogEntryInit>[text('GET /health'), text('boot done'), text('GET /health')]);
      layout.setFilter(const LogFilter(mute: <MuteRule>[MuteRule(text: '/HEALTH')]));

      expect(rowTexts(layout), <String>['boot done']);
      expect(layout.mutedCount, 2);

      // An entry that arrives while the rule applies is hidden and counted as well.
      store.add(text('GET /health'));

      expect(rowTexts(layout), <String>['boot done']);
      expect(layout.mutedCount, 3);

      // A rule that is off hides nothing, and neither does one that matches no entry.
      layout.setFilter(
        const LogFilter(mute: <MuteRule>[MuteRule(text: '/health', enabled: false)]),
      );

      expect(rowTexts(layout), hasLength(4));
      expect(layout.mutedCount, 0);

      layout.setFilter(const LogFilter(mute: <MuteRule>[MuteRule(text: '^get /h', regex: true)]));

      expect(rowTexts(layout), <String>['boot done']);

      layout.setFilter(
        const LogFilter(
          mute: <MuteRule>[MuteRule(text: '^get /h', regex: true, caseSensitive: true)],
        ),
      );

      expect(rowTexts(layout), hasLength(4));

      // A rule that is not a valid pattern hides nothing.
      layout.setFilter(const LogFilter(mute: <MuteRule>[MuteRule(text: '(', regex: true)]));

      expect(rowTexts(layout), hasLength(4));
    });

    test('hides muted entries whatever the rest of the filter says', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final List<LogEntry> entries = store.append(<LogEntryInit>[
        LogEntryInit(parts: text('noise').parts, level: LogLevel.error),
        text('signal'),
        LogEntryInit(parts: text('noise').parts, kind: LogKind.input),
      ]);
      final CompiledFilter filter = compileFilter(
        const LogFilter(
          minLevel: LogLevel.error,
          mute: <MuteRule>[MuteRule(text: 'noise')],
        ),
      );

      expect(filter.muted?.call(entries[0]), isTrue);
      expect(filter.muted?.call(entries[1]), isFalse);
      // A command the user typed is never hidden.
      expect(filter.muted?.call(entries[2]), isFalse);
    });

    test('matches composed text against decomposed Hangul', () {
      final LogStore store = LogStore();
      final LogEntry entry = store.add(text('파일 이름: $decomposedHangul'))!;

      expect(compileFilter(const LogFilter(text: '한글')).matches?.call(entry), isTrue);
      expect(entrySearchText(entry), contains('한글'));
    });
  });

  group('LogLayout', () {
    test('wraps entries to the column count and follows appends and trims', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(maxEntries: 2, mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);

      layout.columns = 20;
      store.add(text('short'));
      store.add(text('a longer line that has to wrap onto more rows'));

      expect(layout.sync(), isTrue);
      expect(layout.rowCount, 4);

      store.add(text('third'));
      layout.sync();

      expect(layout.visibleCount, 2);
      expect(rowTexts(layout).first, 'a longer line that ');
    });

    test('counts the same rows for plain entries as for the general layout', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);
      const String sample =
          'The quick brown fox jumps over the lazy dog, then naps in the sun for a while.';

      layout.columns = 17;
      store.add(text(sample));
      store.add(const LogEntryInit(parts: <LogPart>[TextPart(sample), TextPart('')]));
      layout.sync();

      final List<VisualRow> rows = layout.getRows(0, layout.rowCount);
      final int first = rows.where((VisualRow row) => row.entry.id == 1).length;
      final int second = rows.where((VisualRow row) => row.entry.id == 2).length;

      expect(first, second);
    });

    test('hides filtered entries and members of a collapsed group', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);
      final LogEntry group = store.add(
        const LogEntryInit(kind: LogKind.group, parts: <LogPart>[TextPart('group')]),
      )!;

      store.add(LogEntryInit(parts: text('inside').parts, groups: <int>[group.id]));
      store.add(LogEntryInit(parts: text('outside error').parts, level: LogLevel.error));
      layout.sync();
      expect(layout.visibleCount, 3);

      layout.runAction(group.id, const ToggleGroupAction());
      layout.sync();
      expect(layout.visibleCount, 2);

      layout.setFilter(const LogFilter(minLevel: LogLevel.error));
      layout.sync();
      expect(rowTexts(layout), <String>['group', 'outside error']);
    });

    test('adds rows when a value is expanded', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store);
      final LogEntry entry = store.add(
        const LogEntryInit(parts: <LogPart>[TextPart('user '), ValuePart(object)]),
      )!;

      layout.sync();
      expect(layout.rowCount, 1);

      layout.runAction(entry.id, const ToggleValueAction('1'));
      expect(layout.rowCount, 3);
      expect(rowTexts(layout).sublist(1), <String>['id: 1', 'tags: (2) []']);
    });

    test('expands and collapses every value of an entry at once', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store);
      const ValueNode nested = ValueNode(
        kind: ValueKind.object,
        children: <ValueEntry>[
          ValueEntry(
            key: 'id',
            keyKind: ValueKeyKind.property,
            value: ValueNode(kind: ValueKind.number, value: '1'),
          ),
          ValueEntry(key: 'profile', keyKind: ValueKeyKind.property, value: object),
        ],
      );
      final LogEntry entry = store.add(const LogEntryInit(parts: <LogPart>[ValuePart(nested)]))!;
      final LogEntry plain = store.add(text('plain'))!;

      layout.sync();
      expect(layout.hasExpandableValues(entry), isTrue);
      expect(layout.hasExpandableValues(plain), isFalse);

      layout.expandAll(entry.id);
      // The object, its two properties, the nested object's two properties.
      expect(layout.rowsOf(entry.id), 5);
      expect(rowTexts(layout).sublist(1, 5), <String>[
        'id: 1',
        'profile: {id: 1, tags: List(2)}',
        'id: 1',
        'tags: (2) []',
      ]);

      layout.collapseAll(entry.id);
      expect(layout.rowsOf(entry.id), 1);

      final LogEntry error = store.add(
        const LogEntryInit(
          parts: <LogPart>[
            ValuePart(
              ValueNode(
                kind: ValueKind.error,
                className: 'StateError',
                value: 'bad',
                stack: 'at a',
              ),
            ),
          ],
        ),
      )!;

      layout.sync();
      expect(layout.rowsOf(error.id), 2);
      layout.collapseAll(error.id);
      expect(layout.rowsOf(error.id), 1);
    });

    test('opens logged errors by default so the stack is visible', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store);

      store.add(
        const LogEntryInit(
          parts: <LogPart>[
            ValuePart(
              ValueNode(
                kind: ValueKind.error,
                className: 'TypeError',
                value: 'bad',
                stack: 'at a\nat b',
              ),
            ),
          ],
        ),
      );

      expect(rowTexts(layout), <String>['TypeError: bad', 'at a', 'at b']);
    });

    test('maps screen positions to text positions and copies text', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);

      layout.columns = 40;
      store.add(text('first line'));
      store.add(text('한글 two'));
      layout.sync();

      final LogPosition start = layout.positionAt(0, 6)!;
      // Column 1 is the right half of the first Hangul syllable, which snaps to
      // its end.
      final LogPosition end = layout.positionAt(1, 1)!;

      expect(<int>[start.entryId, start.line, start.cell], <int>[1, 0, 6]);
      expect(<int>[end.entryId, end.line, end.cell], <int>[2, 0, 2]);
      expect(layout.getText(start, end), 'line\n한');
      expect(layout.getAllText(), 'first line\n한글 two');
    });

    test('finds the word at a position', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store);

      store.add(text('request_id=42 failed'));
      layout.sync();

      final List<LogPosition>? range = layout.wordAt(
        const LogPosition(entryId: 1, line: 0, cell: 3),
      );

      expect(range, isNotNull);
      expect(layout.getText(range![0], range[1]), 'request_id');
    });
  });

  group('timestamps', () {
    test('formats local times', () {
      final DateTime time = DateTime(2026, 9, 13, 4, 5, 6, 7);

      expect(formatTimestamp(time), '04:05:06.007');
      expect(formatTimestamp(time, TimestampFormat.datetime), '2026-09-13 04:05:06.007');
      expect(formatTimestamp(time.toUtc(), TimestampFormat.iso), endsWith('Z'));
    });
  });
}
