import 'dart:convert';

import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/text.dart';

/// A list or a map stays on one line when it takes at most this many characters.
const int _breakLength = 72;
const String _indent = '  ';

/// The key that holds the count of properties a snapshot left out.
const String _omittedKey = '…';

String _keyOf(ValueEntry entry) {
  final String key = entry.key ?? '';

  return entry.keyKind == ValueKeyKind.symbol ? '[$key]' : key;
}

Object? _numberOf(ValueNode node) {
  final num? value = num.tryParse(node.value ?? '');

  // JSON has no NaN or Infinity, so they stay text. `-0` becomes `0`.
  if (value == null || !value.isFinite) {
    return node.value ?? 'NaN';
  }

  return value == 0 ? 0 : value;
}

Map<String, Object?> _objectOf(
  List<ValueEntry> children,
  int omitted, [
  Map<String, Object?>? into,
]) {
  final Map<String, Object?> result = into ?? <String, Object?>{};

  for (final ValueEntry child in children) {
    result[_keyOf(child)] = valueToJson(child.value);
  }

  if (omitted > 0) {
    result[_omittedKey] = '$omitted more';
  }

  return result;
}

Object? _listOf(ValueNode node) {
  final List<Object?> items = (node.children ?? <ValueEntry>[])
      .map((ValueEntry child) => valueToJson(child.value))
      .toList();

  if (node.omitted > 0) {
    items.add('… ${node.omitted} more');
  }

  return items;
}

Object? _mapOf(ValueNode node) {
  final List<ValueEntry> children = node.children ?? <ValueEntry>[];

  // A map with text keys reads best as an object. Other keys become
  // [key, value] pairs.
  if (children.every((ValueEntry child) => child.keyValue?.kind == ValueKind.string)) {
    return _objectOf(
      children
          .map(
            (ValueEntry child) => ValueEntry(key: child.keyValue?.value ?? '', value: child.value),
          )
          .toList(),
      node.omitted,
    );
  }

  final List<Object?> pairs = children
      .map<Object?>(
        (ValueEntry child) => <Object?>[
          child.keyValue == null ? null : valueToJson(child.keyValue!),
          valueToJson(child.value),
        ],
      )
      .toList();

  if (node.omitted > 0) {
    pairs.add('… ${node.omitted} more');
  }

  return pairs;
}

/// Converts a captured value to JSON data.
///
/// Values JSON has no type for are written as text the way previews write them:
/// `Symbol(token)`, `ƒ (int) => String`, `RegExp(/ab+c/)`, `[Circular]`. A date
/// becomes its ISO text, a set becomes a list, a map with text keys becomes an
/// object, an error becomes an object with its name, message and stack, and an
/// element becomes its markup. What the snapshot left out is marked with `…`.
Object? valueToJson(ValueNode node) {
  if ((node.kind == ValueKind.object ||
          node.kind == ValueKind.list ||
          node.kind == ValueKind.map ||
          node.kind == ValueKind.set) &&
      node.children == null) {
    return uncapturedText(node);
  }

  switch (node.kind) {
    case ValueKind.nullValue:
      return null;
    case ValueKind.boolean:
      return node.value == 'true';
    case ValueKind.number:
      return _numberOf(node);
    case ValueKind.string:
    case ValueKind.text:
      return '${node.value ?? ''}${node.truncated > 0 ? '…' : ''}';
    case ValueKind.date:
    case ValueKind.regexp:
    case ValueKind.symbol:
    case ValueKind.bigint:
    case ValueKind.function:
    case ValueKind.classValue:
    case ValueKind.future:
    case ValueKind.circular:
    case ValueKind.accessor:
    case ValueKind.element:
      return formatValueText(node);
    case ValueKind.error:
      final Map<String, Object?> result = <String, Object?>{
        'name': node.className ?? 'Error',
        'message': node.value ?? '',
      };
      final String? stack = node.stack;

      if (stack != null && stack.isNotEmpty) {
        result['stack'] = stack.split('\n').map((String line) => line.trim()).join('\n');
      }

      return _objectOf(node.children ?? <ValueEntry>[], node.omitted, result);
    case ValueKind.list:
    case ValueKind.set:
      return _listOf(node);
    case ValueKind.map:
      return _mapOf(node);
    default:
      return _objectOf(node.children ?? <ValueEntry>[], node.omitted);
  }
}

/// Writes JSON data, keeping a list or a map on one line when it is short
/// enough.
String formatJson(Object? value, [String indent = '']) {
  if (value is! List<Object?> && value is! Map<String, Object?>) {
    return jsonEncode(value);
  }

  final String childIndent = indent + _indent;
  final bool isList = value is List<Object?>;
  final List<String> items = isList
      ? value.map((Object? item) => formatJson(item, childIndent)).toList()
      : (value as Map<String, Object?>).entries
            .map(
              (MapEntry<String, Object?> entry) =>
                  '${jsonEncode(entry.key)}: ${formatJson(entry.value, childIndent)}',
            )
            .toList();
  final String open = isList ? '[' : '{';
  final String close = isList ? ']' : '}';

  if (items.isEmpty) {
    return '$open$close';
  }

  final String single = isList ? '[${items.join(', ')}]' : '{ ${items.join(', ')} }';

  if (!single.contains('\n') && indent.length + single.length <= _breakLength) {
    return single;
  }

  final String body = items.map((String item) => childIndent + item).join(',\n');

  return '$open\n$body\n$indent$close';
}

/// The data of an entry: its value, a list of its values, or its text when it
/// has none.
Object? _entryData(LogEntry entry) {
  final List<Object?> values = entry.parts
      .whereType<ValuePart>()
      .map((ValuePart part) => valueToJson(part.value))
      .toList();

  if (values.isEmpty) {
    return formatEntryText(entry);
  }

  return values.length == 1 ? values.first : values;
}

/// Returns the values of an entry as JSON text: the value itself when the entry
/// has one, a list of the values when it has several, and the text of the entry
/// when it has none.
String formatEntryData(LogEntry entry) => formatJson(_entryData(entry));

/// Returns the data of several entries as one JSON list, with an item for every
/// entry.
String formatEntriesData(List<LogEntry> entries) {
  return formatJson(entries.map(_entryData).toList());
}
