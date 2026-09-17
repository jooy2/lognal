import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/links.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/preview.dart';

/// Cells of indentation for every level of nesting.
const int indentCells = 2;

/// Decides whether the value at a path is shown expanded.
typedef ExpansionLookup = bool Function(String path);

/// Splits the text spans of a line around the addresses they hold, and gives
/// every address an action that opens it. A span that already has an action,
/// such as the preview of a value that opens, is left as it is.
List<LineSpan> _splitLinks(List<LineSpan> spans) {
  List<LineSpan>? result;

  for (int index = 0; index < spans.length; index++) {
    final LineSpan span = spans[index];

    if (span is! LineTextSpan || span.action != null || !span.text.contains('://')) {
      result?.add(span);
      continue;
    }

    final List<TextLink> links = findLinks(span.text);

    if (links.isEmpty) {
      result?.add(span);
      continue;
    }

    result ??= spans.sublist(0, index);

    int cursor = 0;

    for (final TextLink link in links) {
      if (link.start > cursor) {
        result.add(span.copyWith(text: span.text.substring(cursor, link.start)));
      }

      result.add(span.copyWith(text: link.url, action: OpenLinkAction(link.url)));
      cursor = link.end;
    }

    if (cursor < span.text.length) {
      result.add(span.copyWith(text: span.text.substring(cursor)));
    }
  }

  return result ?? spans;
}

/// Returns whether a value path is expanded when the user has not toggled it:
/// errors logged directly are open, so their stack trace is visible, and
/// everything else is closed.
bool isExpandedByDefault(LogEntry entry, String path) {
  if (path.contains('.')) {
    return false;
  }

  final int? index = int.tryParse(path);

  if (index == null || index < 0 || index >= entry.parts.length) {
    return false;
  }

  final LogPart part = entry.parts[index];

  return part is ValuePart && part.value.kind == ValueKind.error;
}

List<LineTextSpan> _errorSpans(ValueNode node) {
  return <LineTextSpan>[LineTextSpan(errorTitle(node), token: StyleToken.error)];
}

LineSpan _expanderSpan(String path, bool expanded) {
  return LineIconSpan(expanded: expanded, action: ToggleValueAction(path));
}

void _childLines(
  ValueNode node,
  String path,
  int indent,
  ExpansionLookup isExpanded,
  List<LogicalLine> lines,
) {
  // Rows without an expander start two cells in, so their text lines up with
  // the text of the rows that have one.
  final int textIndent = indent + indentCells;
  final String? stack = node.stack;

  if (node.kind == ValueKind.error && stack != null && stack.isNotEmpty) {
    for (final String stackLine in stack.split('\n')) {
      lines.add(
        LogicalLine(
          indent: textIndent,
          spans: <LineSpan>[LineTextSpan(stackLine.trim(), token: StyleToken.muted)],
        ),
      );
    }
  }

  final List<ValueEntry> children = node.children ?? <ValueEntry>[];

  for (int index = 0; index < children.length; index++) {
    _childLine(node, children[index], '$path.$index', indent, isExpanded, lines);
  }

  if (node.omitted > 0) {
    lines.add(
      LogicalLine(
        indent: textIndent,
        spans: <LineSpan>[LineTextSpan('… ${node.omitted} more', token: StyleToken.muted)],
      ),
    );
  }

  if (node.kind == ValueKind.element && node.value != null) {
    lines.add(
      LogicalLine(
        indent: indent,
        spans: <LineSpan>[LineTextSpan('</${node.value}>', token: StyleToken.tag)],
      ),
    );
  }
}

void _childLine(
  ValueNode parent,
  ValueEntry child,
  String path,
  int indent,
  ExpansionLookup isExpanded,
  List<LogicalLine> lines,
) {
  final bool expandable = isExpandable(child.value);
  final bool expanded = expandable && isExpanded(path);
  final List<LineSpan> spans = <LineSpan>[];

  if (expandable) {
    spans.add(_expanderSpan(path, expanded));
  }

  final ValueNode? keyValue = child.keyValue;

  if (parent.kind == ValueKind.map && keyValue != null) {
    spans
      ..addAll(previewValue(keyValue, true))
      ..add(const LineTextSpan(': ', token: StyleToken.defaultToken));
  } else if (child.key != null &&
      parent.kind != ValueKind.set &&
      parent.kind != ValueKind.element) {
    spans
      ..add(formatKey(child))
      ..add(const LineTextSpan(': ', token: StyleToken.defaultToken));
  }

  final LineAction action = ToggleValueAction(path);
  final List<LineTextSpan> valueSpans = child.value.kind == ValueKind.error
      ? _errorSpans(child.value)
      : previewValue(child.value);

  spans.addAll(
    valueSpans.map((LineTextSpan span) => expandable ? span.copyWith(action: action) : span),
  );
  lines.add(LogicalLine(indent: expandable ? indent : indent + indentCells, spans: spans));

  if (expanded) {
    _childLines(child.value, path, indent + indentCells, isExpanded, lines);
  }
}

/// Builds the logical lines of an entry: one for every line of its text,
/// followed by the rows of every expanded value in the order the values appear.
List<LogicalLine> buildEntryLines(
  LogEntry entry,
  ExpansionLookup isExpanded, {
  bool links = false,
}) {
  final int baseIndent = entry.groups.length * indentCells;
  final List<LogicalLine> lines = <LogicalLine>[];
  final List<_ExpandedPart> expandedParts = <_ExpandedPart>[];
  List<LineSpan> current = <LineSpan>[];
  bool currentWraps = true;

  if (entry.kind == LogKind.group) {
    current.add(LineIconSpan(expanded: !entry.collapsed, action: const ToggleGroupAction()));
  }

  for (int index = 0; index < entry.parts.length; index++) {
    final LogPart part = entry.parts[index];

    if (part is TextPart) {
      final List<String> pieces = part.text.split('\n');

      for (int pieceIndex = 0; pieceIndex < pieces.length; pieceIndex++) {
        if (pieceIndex > 0) {
          lines.add(LogicalLine(indent: baseIndent, spans: current, wrap: currentWraps));
          current = <LineSpan>[];
          currentWraps = true;
        }

        if (!part.wrap) {
          currentWraps = false;
        }

        if (pieces[pieceIndex].isNotEmpty) {
          current.add(
            LineTextSpan(
              pieces[pieceIndex],
              token: part.token,
              style: part.style,
              action: entry.kind == LogKind.group ? const ToggleGroupAction() : null,
            ),
          );
        }
      }

      continue;
    }

    final ValueNode node = (part as ValuePart).value;
    final String path = '$index';

    if (!isExpandable(node)) {
      current.addAll(previewValue(node));
      continue;
    }

    final bool expanded = isExpanded(path);
    final LineAction action = ToggleValueAction(path);
    final List<LineTextSpan> title = node.kind == ValueKind.error
        ? _errorSpans(node)
        : previewValue(node);

    current
      ..add(_expanderSpan(path, expanded))
      ..addAll(title.map((LineTextSpan span) => span.copyWith(action: action)));

    if (expanded) {
      expandedParts.add(_ExpandedPart(node, path));
    }
  }

  lines.add(LogicalLine(indent: baseIndent, spans: current, wrap: currentWraps));

  for (final _ExpandedPart part in expandedParts) {
    _childLines(part.node, part.path, baseIndent + indentCells, isExpanded, lines);
  }

  if (links) {
    for (final LogicalLine line in lines) {
      line.spans = _splitLinks(line.spans);
    }
  }

  return lines;
}

class _ExpandedPart {
  const _ExpandedPart(this.node, this.path);

  final ValueNode node;
  final String path;
}
