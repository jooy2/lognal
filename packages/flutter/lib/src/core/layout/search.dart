import 'package:lognal/src/core/filter.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/normalize.dart';
import 'package:lognal/src/core/types.dart';

/// The most matches a search keeps. Past it, the rest of the log is not
/// searched.
const int maxSearchMatches = 100000;

/// How a search compares text.
class SearchOptions {
  /// Creates the options.
  const SearchOptions({this.caseSensitive = false, this.regex = false});

  /// Whether letter case must match.
  final bool caseSensitive;

  /// Whether the text is a regular expression rather than text to find as typed.
  final bool regex;

  @override
  bool operator ==(Object other) {
    return other is SearchOptions && other.caseSensitive == caseSensitive && other.regex == regex;
  }

  @override
  int get hashCode => Object.hash(caseSensitive, regex);
}

/// The result of compiling a search.
class CompiledSearch {
  /// Creates the result.
  const CompiledSearch({this.pattern, this.error});

  /// The pattern, or `null` for empty text and for a regular expression that
  /// does not compile.
  final RegExp? pattern;

  /// Why a regular expression does not compile, or `null`.
  final String? error;
}

/// Builds the pattern of a search. The text is taken in Unicode normalization
/// form C, as typed unless [SearchOptions.regex] is on, and ignoring letter case
/// unless [SearchOptions.caseSensitive] is on.
CompiledSearch compileSearch(String query, [SearchOptions options = const SearchOptions()]) {
  final String text = normalizeNfc(query);

  if (text.isEmpty) {
    return const CompiledSearch();
  }

  try {
    return CompiledSearch(
      pattern: RegExp(
        options.regex ? text : escapeRegExp(text),
        caseSensitive: options.caseSensitive,
      ),
    );
  } on FormatException catch (caught) {
    return CompiledSearch(error: caught.message);
  }
}

bool _sameMatch(TextMatch a, TextMatch b) {
  return a.entryId == b.entryId && a.line == b.line && a.from == b.from;
}

/// Finds text in the visible entries of a layout without hiding any of them, and
/// keeps track of the current match.
///
/// The log is searched a slice at a time with [scan], so a long log never blocks
/// a frame. Entries added at the end are searched as they arrive, matches in
/// entries dropped from the front are forgotten, and any other change to the
/// text, such as a new filter or an expanded value, starts the search again. The
/// current match stays current as long as it still exists.
class LogSearch {
  /// Creates a search over a layout.
  LogSearch(this._layout);

  final LogLayout _layout;
  RegExp? _pattern;
  String _text = '';
  bool _caseSensitive = false;
  bool _regex = false;
  String? _compileError;
  List<TextMatch> _matches = <TextMatch>[];
  final Map<int, List<TextMatch>> _byEntry = <int, List<TextMatch>>{};
  int _scannedVersion = -1;

  /// The id of the last entry searched. Visible entries after it are still to be
  /// searched.
  int _scannedId = 0;
  int _currentIndex = -1;
  TextMatch? _currentMatch;

  /// The text searched for.
  String get query => _text;

  /// How the text is compared.
  SearchOptions get options => SearchOptions(caseSensitive: _caseSensitive, regex: _regex);

  /// Why the regular expression does not compile, or `null`.
  String? get error => _compileError;

  /// How many matches were found.
  int get count => _matches.length;

  /// The index of the current match, or -1 when there is none.
  int get current => _currentIndex;

  /// Whether part of the log still has to be searched.
  bool get pending {
    if (_pattern == null || _matches.length >= maxSearchMatches) {
      return false;
    }

    final LogEntry? last = _layout.entryAt(_layout.visibleCount - 1);

    return _scannedVersion != _layout.textVersion || (last?.id ?? 0) > _scannedId;
  }

  /// Sets the text to search for and how it is compared. Returns whether either
  /// changed.
  bool setQuery(String query, [SearchOptions options = const SearchOptions()]) {
    if (query == _text && options.caseSensitive == _caseSensitive && options.regex == _regex) {
      return false;
    }

    final CompiledSearch compiled = compileSearch(query, options);

    _text = query;
    _caseSensitive = options.caseSensitive;
    _regex = options.regex;
    _pattern = compiled.pattern;
    _compileError = compiled.error;
    _currentMatch = null;
    _restart();

    return true;
  }

  /// Returns the matches in an entry, if it has any.
  List<TextMatch>? matchesOf(int entryId) => _byEntry[entryId];

  /// Returns the match at an index, if there is one.
  TextMatch? getMatch(int index) {
    return index >= 0 && index < _matches.length ? _matches[index] : null;
  }

  /// Returns the index of the first match in the entry with the given id or a
  /// later one.
  int firstMatchFrom(int entryId) {
    int low = 0;
    int high = _matches.length;

    while (low < high) {
      final int middle = (low + high) >> 1;

      if (_matches[middle].entryId < entryId) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }

    return low < _matches.length ? low : -1;
  }

  /// Makes a match the current one. An index out of range clears the current
  /// match.
  TextMatch? select(int index) {
    final TextMatch? match = getMatch(index);

    _currentIndex = match == null ? -1 : index;
    _currentMatch = match;

    return match;
  }

  /// Moves to the next match, or back to the first one after the last.
  TextMatch? next() => count == 0 ? null : select((_currentIndex + 1) % count);

  /// Moves to the previous match, or on to the last one before the first.
  TextMatch? previous() {
    if (count == 0) {
      return null;
    }

    return select(_currentIndex <= 0 ? count - 1 : _currentIndex - 1);
  }

  /// Searches up to [entries] more visible entries. Call `layout.sync()` first.
  /// Returns whether the matches changed.
  bool scan(int entries) {
    final RegExp? pattern = _pattern;

    if (pattern == null) {
      return false;
    }

    bool changed = false;

    if (_scannedVersion != _layout.textVersion) {
      changed = _matches.isNotEmpty;
      _restart();
    }

    changed = _forgetDropped() || changed;

    int index = _layout.indexFrom(_scannedId + 1);
    final int limit = index + entries;
    final int end = _layout.visibleCount < limit ? _layout.visibleCount : limit;

    for (; index < end && _matches.length < maxSearchMatches; index++) {
      final LogEntry? entry = _layout.entryAt(index);

      if (entry == null) {
        break;
      }

      final List<TextMatch> found = _layout.findInEntry(
        entry,
        pattern,
        maxSearchMatches - _matches.length,
      );

      _scannedId = entry.id;

      if (found.isEmpty) {
        continue;
      }

      for (final TextMatch match in found) {
        final TextMatch? current = _currentMatch;

        if (current != null && _currentIndex < 0 && _sameMatch(match, current)) {
          _currentIndex = _matches.length;
          _currentMatch = match;
        }

        _matches.add(match);
      }

      _byEntry[entry.id] = found;
      changed = true;
    }

    return changed;
  }

  void _restart() {
    _matches = <TextMatch>[];
    _byEntry.clear();
    _scannedVersion = _layout.textVersion;
    _scannedId = 0;
    _currentIndex = -1;
  }

  /// Forgets the matches in entries that were dropped from the front of the log.
  bool _forgetDropped() {
    final int firstId = _layout.entryAt(0)?.id ?? _unbounded;
    int dropped = 0;

    while (dropped < _matches.length && _matches[dropped].entryId < firstId) {
      _byEntry.remove(_matches[dropped].entryId);
      dropped++;
    }

    if (dropped == 0) {
      return false;
    }

    _matches.removeRange(0, dropped);

    if (_currentIndex >= dropped) {
      _currentIndex -= dropped;
    } else if (_currentIndex >= 0) {
      _currentIndex = -1;
      _currentMatch = null;
    }

    return true;
  }
}

/// An id past any entry, used when the log holds none.
const int _unbounded = 1 << 52;
