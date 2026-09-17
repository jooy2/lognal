/// How many removed items the index tolerates at the front before it compacts
/// its lists.
const int _compactThreshold = 4096;

/// Keeps the number of rows of every visible entry, and answers which entry a
/// row belongs to.
///
/// Appending an entry and dropping entries from the front are cheap, which is
/// what a log does almost all the time. Changing row counts in the middle marks
/// the running totals after the first change as stale, and they are recomputed
/// once, the next time a position is read, so many changes in a row cost one
/// pass.
class RowIndex {
  List<int> _counts = <int>[];

  /// `_sums[i]` is the number of rows before item `i`. It has one more element
  /// than `_counts`.
  List<int> _sums = <int>[0];
  int _start = 0;

  /// The first element of `_sums` that is out of date, or `null` when all are
  /// current.
  int? _staleFrom;

  /// The number of items.
  int get length => _counts.length - _start;

  /// The number of rows of all items.
  int get total {
    _refresh();

    return _sums[_counts.length] - _sums[_start];
  }

  /// Adds an item with a row count at the end.
  void push(int rows) {
    _refresh();
    _counts.add(rows);
    _sums.add(_sums.last + rows);
  }

  /// Removes items from the front.
  void shift(int count) {
    _refresh();
    _start = _start + count > _counts.length ? _counts.length : _start + count;

    if (_start > _compactThreshold && _start > _counts.length / 2) {
      final int base = _sums[_start];

      _counts = _counts.sublist(_start);
      _sums = _sums.sublist(_start).map((int sum) => sum - base).toList();
      _start = 0;
    }
  }

  /// Removes every item.
  void clear() {
    _counts = <int>[];
    _sums = <int>[0];
    _start = 0;
    _staleFrom = null;
  }

  /// Returns the number of rows of an item.
  int get(int index) {
    final int position = _start + index;

    return position >= 0 && position < _counts.length ? _counts[position] : 0;
  }

  /// Changes the number of rows of an item.
  void set(int index, int rows) {
    final int position = _start + index;

    if (_counts[position] == rows) {
      return;
    }

    _counts[position] = rows;

    final int? stale = _staleFrom;

    _staleFrom = stale == null || position + 1 < stale ? position + 1 : stale;
  }

  /// Returns the first row of an item.
  int rowOf(int index) {
    _refresh();

    return _sums[_start + index] - _sums[_start];
  }

  /// Returns the item that holds a row, or -1 when the row is past the end.
  int find(int row) {
    if (row < 0 || row >= total) {
      return -1;
    }

    final int target = row + _sums[_start];
    int low = _start;
    int high = _counts.length - 1;

    while (low < high) {
      final int middle = (low + high + 1) >> 1;

      if (_sums[middle] <= target) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }

    // Skip items with no rows, which share their first row with the next item.
    while (low < _counts.length - 1 && _counts[low] == 0) {
      low++;
    }

    return low - _start;
  }

  void _refresh() {
    final int? staleFrom = _staleFrom;

    if (staleFrom == null) {
      return;
    }

    for (int index = staleFrom; index < _sums.length; index++) {
      _sums[index] = _sums[index - 1] + _counts[index - 1];
    }

    _staleFrom = null;
  }
}
