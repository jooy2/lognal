import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/row_index.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';

const String longLine =
    'The quick brown fox jumps over the lazy dog while the logs keep coming in.';

LogStore fillStore(int count) {
  final LogStore store = LogStore(
    options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep, maxEntries: 1 << 30),
  );

  for (int index = 0; index < count; index++) {
    store.write('$index: ${longLine * (index % 3 + 1)}');
  }

  return store;
}

List<String> rowTexts(LogLayout layout, int start, int count) {
  return layout
      .getRows(start, count)
      .map((VisualRow row) => row.runs.map((RowRun run) => run.text).join())
      .toList();
}

void main() {
  group('RowIndex', () {
    test('keeps positions right after many changes in the middle', () {
      final RowIndex index = RowIndex();
      final List<int> counts = <int>[];

      for (int item = 0; item < 200; item++) {
        final int rows = item % 4 + 1;

        index.push(rows);
        counts.add(rows);
      }

      for (int step = 0; step < 300; step++) {
        final int item = step * 37 % counts.length;
        final int rows = step % 5 + 1;

        index.set(item, rows);
        counts[item] = rows;

        if (step % 7 == 0) {
          index.shift(1);
          counts.removeAt(0);
          index.push(2);
          counts.add(2);
        }
      }

      int row = 0;

      for (int item = 0; item < counts.length; item++) {
        expect(index.rowOf(item), row);
        expect(index.find(row), item);
        row += counts[item];
      }

      expect(index.total, row);
    });
  });

  group('estimated row counts', () {
    test('estimates past the budget and measures the rest to the exact result', () {
      final LogStore store = fillStore(300);
      final LogLayout layout = LogLayout(store);
      final LogLayout reference = LogLayout(store);

      layout.columns = 120;
      layout.sync();
      reference.columns = 30;
      reference.sync();

      final int before = layout.positionsVersion;

      layout.columns = 30;
      layout.sync(budget: 10);

      expect(layout.pendingCount, 290);
      expect(layout.positionsVersion, greaterThan(before));

      // The estimate scales the previous row count, so it is close before any
      // measuring.
      expect((layout.rowCount - reference.rowCount).abs(), lessThan(reference.rowCount * 0.2));

      expect(layout.measureAround(150, 5, 10), isTrue);
      expect(layout.rowsOf(150), reference.rowsOf(150));

      while (layout.pendingCount > 0) {
        layout.measurePending(40, 150);
      }

      expect(layout.rowCount, reference.rowCount);
      expect(layout.rowOfEntry(299), reference.rowOfEntry(299));
      expect(rowTexts(layout, 400, 5), rowTexts(reference, 400, 5));
    });

    test('measures the entries nearest to the focus first', () {
      final LogStore store = fillStore(100);
      final LogLayout layout = LogLayout(store);

      layout.columns = 40;
      layout.sync(budget: 0);
      layout.measurePending(10, 50);

      const List<int> measured = <int>[45, 46, 47, 48, 49, 50, 51, 52, 53, 54];
      final LogLayout reference = LogLayout(store);

      reference.columns = 40;
      reference.sync();

      for (final int entryId in measured) {
        expect(layout.rowsOf(entryId), reference.rowsOf(entryId));
      }

      expect(layout.pendingCount, 90);
    });

    test('changes the positions version when entries are dropped from the front', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(maxEntries: 3, mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);

      store.write('a');
      layout.sync();

      final int before = layout.positionsVersion;

      store.write('b');
      layout.sync();
      expect(layout.positionsVersion, before);

      store.write('c');
      store.write('d');
      layout.sync();
      expect(layout.positionsVersion, greaterThan(before));
    });

    test('locates a row within its entry', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: MergeRepeats.keep),
      );
      final LogLayout layout = LogLayout(store);

      layout.columns = 20;
      store.write('short');
      store.write(longLine);
      layout.sync();

      final RowLocation? location = layout.locateRow(2);

      expect(location?.entry.id, 2);
      expect(location?.entryRow, 1);
      expect(layout.locateRow(layout.rowCount), isNull);
    });
  });
}
