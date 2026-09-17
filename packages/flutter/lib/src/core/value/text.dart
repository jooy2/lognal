import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/preview.dart';

/// How a value is written out in full.
class ValueTextOptions {
  /// Creates the options.
  const ValueTextOptions({this.multiline = false});

  /// Whether a value that is too long for one line is broken over several
  /// lines, with an indent for every level. Without it, every value stays on
  /// one line.
  final bool multiline;
}

/// With `multiline`, a container stays on one line when it takes at most this
/// many characters.
const int _breakLength = 72;
const String _indent = '  ';

/// Elements that never have content, so they have no closing tag.
const Set<String> _voidElements = <String>{
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'source',
  'track',
  'wbr',
};

class _Context {
  const _Context({required this.multiline, required this.indent});

  final bool multiline;

  /// The indent of the line the value starts on.
  final String indent;
}

LineTextSpan _span(String text, [StyleToken? token]) => LineTextSpan(text, token: token);

int _lengthOf(List<LineTextSpan> spans) {
  int length = 0;

  for (final LineTextSpan item in spans) {
    length += item.text.length;
  }

  return length;
}

bool _hasLineBreak(List<LineTextSpan> spans) {
  return spans.any((LineTextSpan item) => item.text.contains('\n'));
}

_Context _childContext(_Context context) {
  return _Context(
    multiline: context.multiline,
    indent: context.multiline ? context.indent + _indent : '',
  );
}

/// The name written before the contents of a container, such as `User ` or
/// `Map(2) `.
String _labelOf(ValueNode node) {
  final int size = node.size ?? node.children?.length ?? 0;

  if (node.kind == ValueKind.map || node.kind == ValueKind.set) {
    return '${node.className ?? (node.kind == ValueKind.map ? 'Map' : 'Set')}($size) ';
  }

  final String? className = node.className;

  if (node.kind == ValueKind.list) {
    return className != null && className != 'List' ? '$className($size) ' : '';
  }

  return className != null && className != 'Object' ? '$className ' : '';
}

/// A container whose children were not captured, because the depth limit was
/// reached.
String uncapturedText(ValueNode node) {
  final String? className = node.className;

  if (node.kind == ValueKind.list && (className == null || className == 'List')) {
    return 'List(${node.size ?? 0}) […]';
  }

  return '${_labelOf(node)}${node.kind == ValueKind.list ? '[…]' : '{…}'}';
}

LineTextSpan _keySpan(ValueEntry entry) {
  final LineTextSpan key = formatKey(entry);

  return entry.keyKind == ValueKeyKind.symbol ? key.copyWith(text: '[${key.text}]') : key;
}

List<List<LineTextSpan>> _omittedSpans(ValueNode node) {
  return node.omitted > 0
      ? <List<LineTextSpan>>[
          <LineTextSpan>[_span('… ${node.omitted} more', StyleToken.muted)],
        ]
      : <List<LineTextSpan>>[];
}

/// Joins the items of a container on one line, or one item per line when they do
/// not fit.
List<LineTextSpan> _joinItems({
  required List<LineTextSpan> label,
  required String open,
  required String close,
  required List<List<LineTextSpan>> items,
  required String padding,
  required _Context context,
}) {
  if (items.isEmpty) {
    return <LineTextSpan>[...label, _span('$open$close')];
  }

  final List<LineTextSpan> single = <LineTextSpan>[
    ...label,
    _span('$open$padding'),
    for (int index = 0; index < items.length; index++) ...<LineTextSpan>[
      if (index > 0) _span(', '),
      ...items[index],
    ],
    _span('$padding$close'),
  ];

  if (!context.multiline ||
      (!_hasLineBreak(single) && context.indent.length + _lengthOf(single) <= _breakLength)) {
    return single;
  }

  final String childIndent = context.indent + _indent;

  return <LineTextSpan>[
    ...label,
    _span('$open\n'),
    for (int index = 0; index < items.length; index++) ...<LineTextSpan>[
      _span(childIndent),
      ...items[index],
      _span(index < items.length - 1 ? ',\n' : '\n'),
    ],
    _span('${context.indent}$close'),
  ];
}

List<LineTextSpan> _containerSpans(ValueNode node, _Context context) {
  final String label = _labelOf(node);
  final List<ValueEntry>? children = node.children;

  if (children == null) {
    return <LineTextSpan>[_span(uncapturedText(node))];
  }

  final _Context child = _childContext(context);
  final List<List<LineTextSpan>> items = children.map((ValueEntry entry) {
    final List<LineTextSpan> value = _valueSpans(entry.value, child);
    final ValueNode? keyValue = entry.keyValue;

    if (node.kind == ValueKind.map && keyValue != null) {
      return <LineTextSpan>[..._valueSpans(keyValue, child), _span(': '), ...value];
    }

    if (node.kind == ValueKind.set || entry.key == null || entry.keyKind == ValueKeyKind.indexed) {
      return value;
    }

    return <LineTextSpan>[_keySpan(entry), _span(': '), ...value];
  }).toList();
  final bool isList = node.kind == ValueKind.list;

  return _joinItems(
    label: label.isEmpty
        ? <LineTextSpan>[]
        : <LineTextSpan>[_span(label, node.kind == ValueKind.object ? null : StyleToken.muted)],
    open: isList ? '[' : '{',
    close: isList ? ']' : '}',
    items: <List<LineTextSpan>>[...items, ..._omittedSpans(node)],
    padding: isList ? '' : ' ',
    context: context,
  );
}

List<LineTextSpan> _errorSpans(ValueNode node, _Context context) {
  final List<LineTextSpan> spans = <LineTextSpan>[_span(errorTitle(node), StyleToken.error)];

  for (final String line in node.stack?.split('\n') ?? <String>[]) {
    spans.add(_span('\n${context.indent}$_indent$_indent${line.trim()}', StyleToken.muted));
  }

  final List<ValueEntry> children = node.children ?? <ValueEntry>[];

  if (children.isEmpty && node.omitted == 0) {
    return spans;
  }

  // The properties of an error, such as its `cause`, follow it the way an
  // object's would.
  final ValueNode properties = ValueNode(
    kind: ValueKind.object,
    children: children,
    omitted: node.omitted,
  );

  return <LineTextSpan>[...spans, _span(' '), ..._containerSpans(properties, context)];
}

List<LineTextSpan> _elementSpans(ValueNode node, _Context context) {
  final String tag = node.value ?? 'element';
  final List<LineTextSpan> open = previewValue(node);
  final LineTextSpan close = _span('</$tag>', StyleToken.tag);

  if (_voidElements.contains(tag)) {
    return open;
  }

  final List<ValueEntry>? children = node.children;

  if (children == null) {
    return <LineTextSpan>[...open, _span('…', StyleToken.muted), close];
  }

  final _Context child = _childContext(context);
  final List<List<LineTextSpan>> items = <List<LineTextSpan>>[
    ...children.map((ValueEntry entry) {
      return entry.value.kind == ValueKind.text
          ? <LineTextSpan>[_span(entry.value.value ?? '')]
          : _valueSpans(entry.value, child);
    }),
    ..._omittedSpans(node),
  ];

  if (items.isEmpty) {
    return <LineTextSpan>[...open, close];
  }

  final List<LineTextSpan> single = <LineTextSpan>[
    ...open,
    ...items.expand((List<LineTextSpan> item) => item),
    close,
  ];

  if (!context.multiline ||
      (items.length == 1 &&
          !_hasLineBreak(single) &&
          context.indent.length + _lengthOf(single) <= _breakLength)) {
    return single;
  }

  return <LineTextSpan>[
    ...open,
    for (final List<LineTextSpan> item in items) ...<LineTextSpan>[
      _span('\n${child.indent}'),
      ...item,
    ],
    _span('\n${context.indent}'),
    close,
  ];
}

List<LineTextSpan> _valueSpans(ValueNode node, _Context context) {
  switch (node.kind) {
    case ValueKind.object:
    case ValueKind.list:
    case ValueKind.map:
    case ValueKind.set:
      return _containerSpans(node, context);
    case ValueKind.error:
      return _errorSpans(node, context);
    case ValueKind.element:
      return _elementSpans(node, context);
    default:
      return previewValue(node);
  }
}

String _textOf(List<LineTextSpan> spans) {
  return spans.map((LineTextSpan item) => item.text).join();
}

/// Writes out a value in full, the way code writes it, as far as it was
/// captured: every property, item and entry. Leaf values are written the way
/// previews write them, such as `'text'` or `ƒ (int) => String`. Each span
/// carries the token that colors it.
List<LineTextSpan> formatValueSpans(
  ValueNode node, [
  ValueTextOptions options = const ValueTextOptions(),
]) {
  return _valueSpans(node, _Context(multiline: options.multiline, indent: ''));
}

/// The text of [formatValueSpans].
String formatValueText(ValueNode node, [ValueTextOptions options = const ValueTextOptions()]) {
  return _textOf(formatValueSpans(node, options));
}

/// Returns the spans of an entry: its text as it was written, and every value in
/// full.
List<LineTextSpan> formatEntrySpans(
  LogEntry entry, [
  ValueTextOptions options = const ValueTextOptions(),
]) {
  return entry.parts.expand((LogPart part) {
    if (part is ValuePart) {
      return formatValueSpans(part.value, options);
    }

    final TextPart text = part as TextPart;

    return <LineTextSpan>[LineTextSpan(text.text, token: text.token, style: text.style)];
  }).toList();
}

/// The text of [formatEntrySpans].
String formatEntryText(LogEntry entry, [ValueTextOptions options = const ValueTextOptions()]) {
  return _textOf(formatEntrySpans(entry, options));
}
