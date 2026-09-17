/// Splits a stream of text chunks into lines.
///
/// A line ends at `\n`, `\r\n` or a lone `\r`. A `\r\n` pair split across two
/// chunks still counts as one line break.
class LogLineSplitter {
  String _pending = '';
  bool _skipLineFeed = false;

  /// Whether text is waiting for a line break.
  bool get hasPending => _pending.isNotEmpty;

  /// Adds a chunk and returns the lines it completed.
  List<String> push(String chunk) {
    final List<String> lines = <String>[];
    int start = 0;
    int index = 0;

    if (_skipLineFeed && chunk.isNotEmpty && chunk.codeUnitAt(0) == 0x0a) {
      start = 1;
      index = 1;
    }

    _skipLineFeed = false;

    for (; index < chunk.length; index++) {
      final int code = chunk.codeUnitAt(index);

      if (code != 0x0a && code != 0x0d) {
        continue;
      }

      lines.add(_pending + chunk.substring(start, index));
      _pending = '';

      if (code == 0x0d) {
        if (index + 1 == chunk.length) {
          _skipLineFeed = true;
        } else if (chunk.codeUnitAt(index + 1) == 0x0a) {
          index++;
        }
      }

      start = index + 1;
    }

    _pending += chunk.substring(start);

    return lines;
  }

  /// Returns the unfinished last line, if any, and resets the splitter.
  List<String> flush() {
    final String rest = _pending;

    _pending = '';
    _skipLineFeed = false;

    return rest.isEmpty ? <String>[] : <String>[rest];
  }
}

/// Splits a whole string into lines. A trailing line break does not add an
/// empty line.
List<String> splitLines(String text) {
  final LogLineSplitter splitter = LogLineSplitter();

  return <String>[...splitter.push(text), ...splitter.flush()];
}
