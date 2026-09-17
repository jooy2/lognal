import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/types.dart';

/// The most cells a one-line preview of an object, list, map or set takes before
/// it is cut.
const int previewCells = 100;

final RegExp _identifier = RegExp(r'^[A-Za-z_$][\w$]*$');

/// Returns whether a value can be expanded to show its children.
bool isExpandable(ValueNode node) {
  if (node.kind == ValueKind.error) {
    final String? stack = node.stack;

    return (stack != null && stack.isNotEmpty) || (node.children?.length ?? 0) > 0;
  }

  if (node.kind != ValueKind.object &&
      node.kind != ValueKind.list &&
      node.kind != ValueKind.map &&
      node.kind != ValueKind.set &&
      node.kind != ValueKind.element) {
    return false;
  }

  final List<ValueEntry>? children = node.children;

  return children != null && (children.isNotEmpty || node.omitted > 0);
}

String _quote(String text) {
  final String escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');

  return "'$escaped'";
}

/// The longest string shown in full inside another value's preview.
const int _nestedStringLength = 50;

String _stringText(ValueNode node, [bool nested = false]) {
  final String value = node.value ?? '';

  if (nested && value.length > _nestedStringLength) {
    return '${_quote(value.substring(0, _nestedStringLength))}…';
  }

  return '${_quote(value)}${node.truncated > 0 ? '…' : ''}';
}

/// Formats a property key the way it would be written in source.
LineTextSpan formatKey(ValueEntry entry) {
  final String key = entry.key ?? '';

  if (entry.keyKind == ValueKeyKind.symbol) {
    return LineTextSpan(key, token: StyleToken.symbol);
  }

  if (entry.keyKind == ValueKeyKind.internal) {
    return LineTextSpan(key, token: StyleToken.muted);
  }

  if (entry.keyKind == ValueKeyKind.indexed || _identifier.hasMatch(key)) {
    return LineTextSpan(key, token: StyleToken.key);
  }

  return LineTextSpan(_quote(key), token: StyleToken.key);
}

/// The name shown before a container's contents, such as `User` or `Map(2)`.
String _labelOf(ValueNode node) {
  final int size = node.size ?? node.children?.length ?? 0;

  switch (node.kind) {
    case ValueKind.list:
      final String? name = node.className;

      return name != null && name != 'List' ? '$name($size)' : '($size)';
    case ValueKind.map:
    case ValueKind.set:
      return '${node.className ?? (node.kind == ValueKind.map ? 'Map' : 'Set')}($size)';
    case ValueKind.object:
      final String? className = node.className;

      return className != null && className != 'Object' ? className : '';
    default:
      return node.className ?? '';
  }
}

/// A short name for a nested container, used inside another preview.
String _shortLabel(ValueNode node) {
  final int size = node.size ?? node.children?.length ?? 0;

  switch (node.kind) {
    case ValueKind.list:
      final String? name = node.className;

      return '${name != null && name != 'List' ? name : 'List'}($size)';
    case ValueKind.map:
    case ValueKind.set:
      return _labelOf(node);
    case ValueKind.object:
      final String? className = node.className;

      return className != null && className != 'Object' ? className : '{…}';
    default:
      return node.className ?? '';
  }
}

String _elementText(ValueNode node, bool withAttributes) {
  final String tag = node.value ?? 'element';
  final List<MapEntry<String, String>>? attributes = node.attributes;

  if (!withAttributes || attributes == null || attributes.isEmpty) {
    return '<$tag>';
  }

  final String written = attributes
      .map((MapEntry<String, String> pair) {
        return pair.value.isEmpty ? pair.key : '${pair.key}="${pair.value}"';
      })
      .join(' ');

  return '<$tag $written>';
}

/// Spans for a leaf value, or a short label for a container nested inside a
/// preview.
List<LineTextSpan> _leafSpans(ValueNode node, bool nested) {
  switch (node.kind) {
    case ValueKind.nullValue:
      return <LineTextSpan>[const LineTextSpan('null', token: StyleToken.nullValue)];
    case ValueKind.boolean:
      return <LineTextSpan>[LineTextSpan(node.value ?? 'false', token: StyleToken.boolean)];
    case ValueKind.number:
      return <LineTextSpan>[LineTextSpan(node.value ?? 'NaN', token: StyleToken.number)];
    case ValueKind.bigint:
      return <LineTextSpan>[LineTextSpan(node.value ?? '0', token: StyleToken.number)];
    case ValueKind.string:
      return <LineTextSpan>[LineTextSpan(_stringText(node, nested), token: StyleToken.string)];
    case ValueKind.symbol:
      return <LineTextSpan>[LineTextSpan(node.value ?? 'Symbol()', token: StyleToken.symbol)];
    case ValueKind.function:
      return <LineTextSpan>[
        const LineTextSpan('ƒ ', token: StyleToken.function),
        LineTextSpan(node.value ?? '()', token: StyleToken.defaultToken),
      ];
    case ValueKind.classValue:
      return <LineTextSpan>[
        const LineTextSpan('class ', token: StyleToken.function),
        LineTextSpan(node.value ?? '', token: StyleToken.defaultToken),
      ];
    case ValueKind.date:
      return <LineTextSpan>[LineTextSpan(node.value ?? 'Invalid Date', token: StyleToken.date)];
    case ValueKind.regexp:
      return <LineTextSpan>[LineTextSpan(node.value ?? '//', token: StyleToken.regexp)];
    case ValueKind.error:
      return <LineTextSpan>[LineTextSpan(errorTitle(node), token: StyleToken.error)];
    case ValueKind.future:
      return <LineTextSpan>[
        LineTextSpan(node.className ?? 'Future', token: StyleToken.defaultToken),
      ];
    case ValueKind.element:
      return <LineTextSpan>[LineTextSpan(_elementText(node, !nested), token: StyleToken.tag)];
    case ValueKind.text:
      return <LineTextSpan>[LineTextSpan(_stringText(node), token: StyleToken.string)];
    case ValueKind.circular:
      return <LineTextSpan>[const LineTextSpan('[Circular]', token: StyleToken.muted)];
    case ValueKind.accessor:
      final String text = switch (node.accessor) {
        AccessorKind.set => '[Setter]',
        AccessorKind.getSet => '[Getter/Setter]',
        _ => '[Getter]',
      };

      return <LineTextSpan>[LineTextSpan(text, token: StyleToken.muted)];
    default:
      return <LineTextSpan>[LineTextSpan(_shortLabel(node), token: StyleToken.defaultToken)];
  }
}

/// `StateError: message`, or just the name when there is no message.
///
/// With no name at all the message stands alone, which is the case a release
/// build for the web leaves: it does not keep the type names an error would
/// otherwise be titled with.
String errorTitle(ValueNode node) {
  final String? name = node.className;
  final String? message = node.value;
  final bool hasMessage = message != null && message.isNotEmpty;

  if (name == null || name.isEmpty) {
    return hasMessage ? message : 'Error';
  }

  return hasMessage ? '$name: $message' : name;
}

bool _isContainer(ValueNode node) {
  return node.kind == ValueKind.object ||
      node.kind == ValueKind.list ||
      node.kind == ValueKind.map ||
      node.kind == ValueKind.set;
}

int _measure(List<LineTextSpan> spans) {
  int cells = 0;

  for (final LineTextSpan span in spans) {
    cells += span.text.length;
  }

  return cells;
}

/// Returns a one-line preview of a value, such as `{id: 1, name: 'lognal'}` or
/// `(3) [1, 2, 3]`. Containers inside the preview are shown by name only, and
/// the preview is cut with `…` once it passes [previewCells].
List<LineTextSpan> previewValue(ValueNode node, [bool nested = false]) {
  if (!_isContainer(node) || nested) {
    return _leafSpans(node, nested);
  }

  final String label = _labelOf(node);
  final List<LineTextSpan> spans = <LineTextSpan>[];

  if (label.isNotEmpty) {
    spans.add(
      LineTextSpan(
        '$label ',
        token: node.kind == ValueKind.object ? StyleToken.defaultToken : StyleToken.muted,
      ),
    );
  }

  final List<ValueEntry>? children = node.children;
  final bool isList = node.kind == ValueKind.list;

  if (children == null) {
    // An object the capture could not open shows what it says about itself.
    // Dart has no way to read the fields of an arbitrary value, so a class that
    // writes its own `toString()` is the common case here, and printing `{…}`
    // over a description the author wrote would throw away the only thing the
    // log line has. The JavaScript side never reaches this branch: it reads the
    // properties instead.
    final String? text = node.value;

    if (node.kind == ValueKind.object && text != null && text.isNotEmpty) {
      return <LineTextSpan>[LineTextSpan(text, token: StyleToken.defaultToken)];
    }

    spans.add(LineTextSpan(isList ? '[…]' : '{…}', token: StyleToken.defaultToken));

    return spans;
  }

  spans.add(LineTextSpan(isList ? '[' : '{', token: StyleToken.defaultToken));

  int shown = 0;

  for (final ValueEntry child in children) {
    if (_measure(spans) > previewCells) {
      break;
    }

    if (shown > 0) {
      spans.add(const LineTextSpan(', ', token: StyleToken.defaultToken));
    }

    final ValueNode? keyValue = child.keyValue;

    if (node.kind == ValueKind.map && keyValue != null) {
      spans
        ..addAll(_leafSpans(keyValue, true))
        ..add(const LineTextSpan(': ', token: StyleToken.defaultToken));
    } else if (!isList && node.kind != ValueKind.set && child.key != null) {
      spans
        ..add(formatKey(child))
        ..add(const LineTextSpan(': ', token: StyleToken.defaultToken));
    }

    spans.addAll(_leafSpans(child.value, true));
    shown++;
  }

  if (shown < children.length || node.omitted > 0) {
    spans.add(LineTextSpan(shown > 0 ? ', …' : '…', token: StyleToken.muted));
  }

  spans.add(LineTextSpan(isList ? ']' : '}', token: StyleToken.defaultToken));

  return spans;
}
