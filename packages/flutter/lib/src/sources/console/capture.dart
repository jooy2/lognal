import 'package:lognal/src/core/types.dart';

/// Limits that keep capturing a large or deep value cheap.
class CaptureOptions {
  /// Creates the limits.
  const CaptureOptions({
    this.maxDepth = 5,
    this.maxProperties = 100,
    this.maxStringLength = 10000,
    this.maxNodes = 2000,
    this.expandToJson = true,
  });

  /// How many levels of nested values are captured. Deeper values are shown by
  /// name only.
  final int maxDepth;

  /// The most properties, items or entries captured from one object, list, map
  /// or set.
  final int maxProperties;

  /// The longest string captured in full.
  final int maxStringLength;

  /// The most values captured for one argument, counting every nested value.
  final int maxNodes;

  /// Whether an object that defines `toJson()` is opened by calling it.
  ///
  /// Dart cannot read the fields of an arbitrary object without reflection,
  /// which a Flutter build does not ship, so this is the one way a model class
  /// expands into its properties rather than showing as one line of
  /// `toString()`. The call is a method the author wrote to be called, it runs
  /// inside a guard, and what it returns is captured under the same limits as
  /// anything else. Turn it off for a type whose `toJson()` is expensive or has
  /// an effect of its own.
  final bool expandToJson;

  /// A copy with the fields given here replaced.
  CaptureOptions copyWith({
    int? maxDepth,
    int? maxProperties,
    int? maxStringLength,
    int? maxNodes,
    bool? expandToJson,
  }) {
    return CaptureOptions(
      maxDepth: maxDepth ?? this.maxDepth,
      maxProperties: maxProperties ?? this.maxProperties,
      maxStringLength: maxStringLength ?? this.maxStringLength,
      maxNodes: maxNodes ?? this.maxNodes,
      expandToJson: expandToJson ?? this.expandToJson,
    );
  }
}

/// The limits a capture starts with.
const CaptureOptions defaultCaptureOptions = CaptureOptions();

/// What `Object.toString()` returns for a class that does not override it.
final RegExp _defaultToString = RegExp(r"^Instance of '.*'$");

/// The headers the errors in the SDK print in front of their message.
///
/// Dart has no rule that an error's `toString()` opens with its own type name —
/// `StateError` says `Bad state:` and `IndexError` says `RangeError (index):` —
/// so the ones that do not are listed rather than guessed at. Everything else is
/// covered by the type name itself, which is the convention an application's own
/// exceptions follow.
final List<RegExp> _errorHeaders = <RegExp>[
  RegExp(r'^Bad state: '),
  RegExp(r'^Unsupported operation: '),
  RegExp(r'^Concurrent modification during iteration: '),
  RegExp(r'^Invalid argument(?: ?\([^)]*\))?: '),
  RegExp(r'^RangeError(?: \([^)]*\))?: '),
  RegExp(r'^Assertion failed: '),
];

/// Removes the header an error's `toString()` opens with, so the title the
/// viewer draws reads `StateError: broken` rather than repeating itself.
String _messageOf(Object error, String className) {
  final String text = error.toString();

  if (text.startsWith('$className: ')) {
    return text.substring(className.length + 2);
  }

  for (final RegExp header in _errorHeaders) {
    final Match? match = header.matchAsPrefix(text);

    if (match != null) {
      return text.substring(match.end);
    }
  }

  return text;
}

class _Capture {
  _Capture(this.options);

  final CaptureOptions options;
  int _nodes = 0;
  final List<Object> _path = <Object>[];

  ValueNode value(Object? value, int depth) {
    _nodes++;

    if (value == null) {
      return const ValueNode(kind: ValueKind.nullValue);
    }

    if (value is bool) {
      return ValueNode(kind: ValueKind.boolean, value: '$value');
    }

    if (value is int) {
      return ValueNode(kind: ValueKind.number, value: '$value');
    }

    if (value is double) {
      return ValueNode(kind: ValueKind.number, value: _doubleText(value));
    }

    if (value is BigInt) {
      return ValueNode(kind: ValueKind.bigint, value: '$value');
    }

    if (value is String) {
      return _string(value);
    }

    if (value is Symbol) {
      return ValueNode(kind: ValueKind.symbol, value: '$value');
    }

    if (value is Type) {
      return ValueNode(kind: ValueKind.classValue, value: '$value');
    }

    if (value is DateTime) {
      return ValueNode(kind: ValueKind.date, value: value.toIso8601String());
    }

    if (value is RegExp) {
      return ValueNode(kind: ValueKind.regexp, value: '/${value.pattern}/');
    }

    if (value is Duration || value is Uri) {
      return ValueNode(
        kind: ValueKind.object,
        className: value.runtimeType.toString(),
        value: value.toString(),
      );
    }

    if (value is Function) {
      return ValueNode(kind: ValueKind.function, value: _functionText(value));
    }

    if (value is Future) {
      return ValueNode(kind: ValueKind.future, className: 'Future');
    }

    // Identity, not equality: two equal values are not the same value, and a
    // collection that holds an equal copy of itself is not a cycle.
    if (_path.any((Object item) => identical(item, value))) {
      return const ValueNode(kind: ValueKind.circular);
    }

    _path.add(value);

    try {
      return _object(value, depth);
    } finally {
      _path.removeLast();
    }
  }

  ValueNode _string(String value) {
    if (value.length <= options.maxStringLength) {
      return ValueNode(kind: ValueKind.string, value: value);
    }

    return ValueNode(
      kind: ValueKind.string,
      value: value.substring(0, options.maxStringLength),
      truncated: value.length - options.maxStringLength,
      size: value.length,
    );
  }

  /// Whether this value may capture its children, or is shown by name only.
  bool _canDescend(int depth) => depth < options.maxDepth && _nodes < options.maxNodes;

  ValueNode _object(Object value, int depth) {
    if (value is Error) {
      return _error(value, value.stackTrace, depth);
    }

    if (value is Exception) {
      return _error(value, null, depth);
    }

    if (value is Map<Object?, Object?>) {
      return _map(value, depth);
    }

    if (value is Set<Object?>) {
      return _set(value, depth);
    }

    if (value is Iterable<Object?>) {
      return _list(value, depth);
    }

    return _plainObject(value, depth);
  }

  ValueNode _plainObject(Object value, int depth) {
    final String className = value.runtimeType.toString();
    final String text = value.toString();
    final String? shown = _defaultToString.hasMatch(text) ? null : text;

    if (!options.expandToJson || !_canDescend(depth)) {
      return ValueNode(kind: ValueKind.object, className: className, value: shown);
    }

    final Object? json = _toJson(value);

    if (json == null || identical(json, value)) {
      return ValueNode(kind: ValueKind.object, className: className, value: shown);
    }

    // A map of string keys is how a model describes itself, so it is shown as
    // the object it stands for rather than as a map: `Account { id: 7 }` and not
    // `Account(1) { 'id': 7 }`.
    if (json is Map<Object?, Object?> && json.keys.every((Object? key) => key is String)) {
      final ValueNode captured = _map(json, depth);

      return ValueNode(
        kind: ValueKind.object,
        className: className,
        children: captured.children
            ?.map(
              (ValueEntry entry) =>
                  ValueEntry(key: entry.key, keyKind: ValueKeyKind.property, value: entry.value),
            )
            .toList(),
        omitted: captured.omitted,
      );
    }

    // What `toJson` returned, under this object's own name.
    return this.value(json, depth).copyWith(className: className);
  }

  /// Calls `toJson()` when the object has one, and returns `null` otherwise.
  Object? _toJson(Object value) {
    try {
      final dynamic result = (value as dynamic).toJson();

      return result is Object ? result : null;
    } on NoSuchMethodError {
      return null;
    } catch (_) {
      // The method is there and it threw. Showing the object by name is a
      // better answer than losing the log line.
      return null;
    }
  }

  ValueNode _list(Iterable<Object?> value, int depth) {
    final int length = value.length;
    final String className = value.runtimeType.toString();
    final ValueNode node = ValueNode(
      kind: ValueKind.list,
      className: _cleanTypeName(className, 'List'),
      size: length,
    );

    if (!_canDescend(depth)) {
      return node;
    }

    final List<ValueEntry> children = <ValueEntry>[];
    int index = 0;

    for (final Object? item in value) {
      if (children.length >= options.maxProperties || _nodes >= options.maxNodes) {
        break;
      }

      children.add(
        ValueEntry(
          key: '$index',
          keyKind: ValueKeyKind.indexed,
          value: this.value(item, depth + 1),
        ),
      );
      index++;
    }

    return node.copyWith(
      children: children,
      omitted: length > children.length ? length - children.length : 0,
    );
  }

  ValueNode _set(Set<Object?> value, int depth) {
    final ValueNode node = ValueNode(
      kind: ValueKind.set,
      className: _cleanTypeName(value.runtimeType.toString(), 'Set'),
      size: value.length,
    );

    if (!_canDescend(depth)) {
      return node;
    }

    final List<ValueEntry> children = <ValueEntry>[];

    for (final Object? item in value) {
      if (children.length >= options.maxProperties || _nodes >= options.maxNodes) {
        break;
      }

      children.add(ValueEntry(value: this.value(item, depth + 1)));
    }

    return node.copyWith(
      children: children,
      omitted: value.length > children.length ? value.length - children.length : 0,
    );
  }

  ValueNode _map(Map<Object?, Object?> value, int depth) {
    final ValueNode node = ValueNode(
      kind: ValueKind.map,
      className: _cleanTypeName(value.runtimeType.toString(), 'Map'),
      size: value.length,
    );

    if (!_canDescend(depth)) {
      return node;
    }

    final List<ValueEntry> children = <ValueEntry>[];

    for (final MapEntry<Object?, Object?> entry in value.entries) {
      if (children.length >= options.maxProperties || _nodes >= options.maxNodes) {
        break;
      }

      final Object? key = entry.key;

      children.add(
        ValueEntry(
          key: key is String ? key : null,
          keyKind: key is String ? ValueKeyKind.property : null,
          keyValue: this.value(key, depth + 1),
          value: this.value(entry.value, depth + 1),
        ),
      );
    }

    return node.copyWith(
      children: children,
      omitted: value.length > children.length ? value.length - children.length : 0,
    );
  }

  ValueNode _error(Object value, StackTrace? stackTrace, int depth) {
    final String className = value.runtimeType.toString();
    final String message = _messageOf(value, className);
    final String stack = stackTrace?.toString().trimRight() ?? '';
    final ValueNode node = ValueNode(
      kind: ValueKind.error,
      className: className,
      value: message,
      stack: stack.isEmpty
          ? null
          : stack.substring(
              0,
              stack.length > options.maxStringLength ? options.maxStringLength : stack.length,
            ),
    );

    if (!_canDescend(depth)) {
      return node;
    }

    // An error's own properties, where it publishes them the way a model does.
    final Object? json = options.expandToJson ? _toJson(value) : null;

    if (json is Map<Object?, Object?>) {
      final ValueNode captured = _map(json, depth);

      return node.copyWith(children: captured.children, omitted: captured.omitted);
    }

    return node;
  }
}

/// `_Map<String, int>` and `_GrowableList<int>` are implementation names. What a
/// reader wants is `Map` or the author's own type, so an internal name falls
/// back to the plain one.
String? _cleanTypeName(String className, String fallback) {
  final String name = className.split('<').first;

  if (name.startsWith('_') || name.isEmpty) {
    return fallback;
  }

  return name;
}

/// `-0.0` keeps its sign, and a whole double keeps its `.0`, so the text says
/// which of the two number types it came from.
String _doubleText(double value) {
  if (value.isNaN) {
    return 'NaN';
  }

  if (value.isInfinite) {
    return value.isNegative ? '-Infinity' : 'Infinity';
  }

  if (value == 0 && value.isNegative) {
    return '-0.0';
  }

  return '$value';
}

/// A closure's own description, without the `Closure: ` the runtime prefixes.
String _functionText(Function value) {
  final String text = value.toString();
  final int separator = text.indexOf(': ');

  return separator < 0 ? text : text.substring(separator + 2);
}

/// Captures a value as plain data, at the moment of the call.
///
/// A built-in type is recognized by what it is, a collection is walked, an error
/// carries its message and its stack trace, and anything else is shown by its
/// type and its `toString()` — or opened through `toJson()`, which is what Dart
/// has in place of the property enumeration the JavaScript side does. Each limit
/// in [options] bounds the work, and whatever it cuts is counted in the node's
/// `omitted` field.
ValueNode captureValue(Object? value, [CaptureOptions options = defaultCaptureOptions]) {
  return _Capture(options).value(value, 0);
}
