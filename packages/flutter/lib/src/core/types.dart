/// Data types shared by every part of lognal.
///
/// Everything under `lib/src/core` is plain data and logic with no dependency
/// on Flutter or on a Dart-only platform API, so that it stays the same library
/// as the TypeScript core it was translated from. Platform features the core
/// needs, such as grapheme segmentation, are passed in rather than imported.
library;

/// Severity of an entry, from least to most severe.
enum LogLevel {
  /// Detail a developer asked for.
  debug,

  /// An ordinary message.
  log,

  /// A message worth noticing.
  info,

  /// Something that may be a problem.
  warn,

  /// Something that is a problem.
  error,
}

/// Every level, ordered from least to most severe.
const List<LogLevel> logLevels = LogLevel.values;

/// What an entry represents. The viewer marks each kind differently.
enum LogKind {
  /// A regular log message.
  message,

  /// A command the user typed into the input line.
  input,

  /// The reply to a command.
  output,

  /// The header of a group started with `group`.
  group,

  /// A notice from the viewer itself, such as "Console was cleared".
  system,
}

/// Semantic colors, resolved by the renderer from the theme.
enum StyleToken {
  /// The color of ordinary text, which the entry's own level decides.
  defaultToken,

  /// Text that is there but is not the point, such as a stack frame.
  muted,

  /// A string value.
  string,

  /// A number value.
  number,

  /// A boolean value.
  boolean,

  /// `null` and the absence of a value.
  nullValue,

  /// A property name.
  key,

  /// A symbol.
  symbol,

  /// A function or a class.
  function,

  /// A regular expression.
  regexp,

  /// A date.
  date,

  /// An element's tag name.
  tag,

  /// An element's attribute name.
  attribute,

  /// An error.
  error,

  /// A warning.
  warn,

  /// A notice.
  info,

  /// The viewer's accent color.
  accent,
}

/// A color given directly rather than through a token.
///
/// [AnsiTextColor] is an index into the ANSI palette; 0 to 15 follow the theme.
/// [RgbTextColor] is an exact color, as `0xAARRGGBB`.
sealed class TextColor {
  /// Lets a subclass declare a `const` constructor.
  const TextColor();
}

/// A color chosen from the 256-color ANSI palette.
class AnsiTextColor extends TextColor {
  /// Creates a color at [index] of the ANSI palette, from 0 to 255.
  const AnsiTextColor(this.index);

  /// The index into the palette. 0 to 15 come from the theme.
  final int index;

  @override
  bool operator ==(Object other) => other is AnsiTextColor && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'AnsiTextColor($index)';
}

/// An exact color, as the 32-bit value `0xAARRGGBB`.
class RgbTextColor extends TextColor {
  /// Creates a color from a 32-bit `0xAARRGGBB` value.
  const RgbTextColor(this.value);

  /// The color, as `0xAARRGGBB`.
  final int value;

  @override
  bool operator ==(Object other) => other is RgbTextColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RgbTextColor(0x${value.toRadixString(16).padLeft(8, '0')})';
}

/// Explicit styling, from a styled message or from ANSI escape codes.
class LogTextStyle {
  /// Creates a style. Every field left out is inherited from the entry.
  const LogTextStyle({
    this.color,
    this.background,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });

  /// The color of the text.
  final TextColor? color;

  /// The color behind the text.
  final TextColor? background;

  /// Whether the text is drawn bold.
  final bool bold;

  /// Whether the text is drawn faintly.
  final bool dim;

  /// Whether the text is drawn italic.
  final bool italic;

  /// Whether a line is drawn under the text.
  final bool underline;

  /// Whether a line is drawn through the text.
  final bool strikethrough;

  /// Whether the style sets nothing at all.
  bool get isEmpty =>
      color == null &&
      background == null &&
      !bold &&
      !dim &&
      !italic &&
      !underline &&
      !strikethrough;

  /// A copy with the fields given here replaced.
  ///
  /// `clearColor` and `clearBackground` remove a color, which passing `null`
  /// cannot do, because `null` is how a field says "leave this one alone".
  LogTextStyle copyWith({
    TextColor? color,
    TextColor? background,
    bool? bold,
    bool? dim,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool clearColor = false,
    bool clearBackground = false,
  }) {
    return LogTextStyle(
      color: clearColor ? null : color ?? this.color,
      background: clearBackground ? null : background ?? this.background,
      bold: bold ?? this.bold,
      dim: dim ?? this.dim,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LogTextStyle &&
        other.color == color &&
        other.background == background &&
        other.bold == bold &&
        other.dim == dim &&
        other.italic == italic &&
        other.underline == underline &&
        other.strikethrough == strikethrough;
  }

  @override
  int get hashCode {
    return Object.hash(color, background, bold, dim, italic, underline, strikethrough);
  }

  /// A string that is equal for two styles that are equal, used to merge repeats.
  String get signature {
    return '${color ?? ''}|${background ?? ''}|$bold$dim$italic$underline$strikethrough';
  }
}

/// One piece of an entry's content. Parts are displayed one after another.
sealed class LogPart {
  /// Lets a subclass declare a `const` constructor.
  const LogPart();
}

/// A run of text with one style.
class TextPart extends LogPart {
  /// Creates a run of text.
  const TextPart(this.text, {this.token, this.style, this.wrap = true});

  /// The text itself. A line break inside it starts a new line of the entry.
  final String text;

  /// The semantic color of the text.
  final StyleToken? token;

  /// Explicit styling, which wins over [token].
  final LogTextStyle? style;

  /// Whether the text may wrap.
  ///
  /// Set it to `false` to keep every line of this part on one row, for text
  /// whose layout matters, such as a table. A line wider than the viewer then
  /// scrolls sideways instead of wrapping.
  final bool wrap;

  /// A copy with the fields given here replaced.
  TextPart copyWith({String? text, StyleToken? token, LogTextStyle? style, bool? wrap}) {
    return TextPart(
      text ?? this.text,
      token: token ?? this.token,
      style: style ?? this.style,
      wrap: wrap ?? this.wrap,
    );
  }
}

/// A captured value, displayed with type-aware formatting.
class ValuePart extends LogPart {
  /// Creates a part that holds one captured value.
  const ValuePart(this.value);

  /// The captured value.
  final ValueNode value;
}

/// The kinds of value a snapshot can hold.
enum ValueKind {
  /// A value that was never set.
  nullValue,

  /// A boolean.
  boolean,

  /// A number, integer or floating point.
  number,

  /// An arbitrary-precision integer.
  bigint,

  /// A string.
  string,

  /// A symbol.
  symbol,

  /// A function or a closure.
  function,

  /// A type.
  classValue,

  /// A point in time.
  date,

  /// A regular expression.
  regexp,

  /// An error or an exception.
  error,

  /// An ordered collection.
  list,

  /// An object with named properties.
  object,

  /// A collection of key and value pairs.
  map,

  /// A collection of unique items.
  set,

  /// A value that is not ready yet.
  future,

  /// A node of a document tree.
  element,

  /// The text of such a node.
  text,

  /// A value already on the path from the root, so it was not followed.
  circular,

  /// A property that is a getter, a setter, or both.
  accessor,
}

/// How the key of a child is displayed.
enum ValueKeyKind {
  /// A property name.
  property,

  /// An index into a list.
  indexed,

  /// A symbol.
  symbol,

  /// A name the runtime gave the value rather than the code.
  internal,
}

/// Which parts of an accessor property are defined.
enum AccessorKind {
  /// Only a getter.
  get,

  /// Only a setter.
  set,

  /// Both.
  getSet,
}

/// A snapshot of a value, taken when it was logged.
///
/// The tree is plain data, so it can be sent through a port or saved as JSON.
/// It never holds a reference to the original value.
class ValueNode {
  /// Creates a captured value.
  const ValueNode({
    required this.kind,
    this.value,
    this.className,
    this.size,
    this.children,
    this.omitted = 0,
    this.truncated = 0,
    this.stack,
    this.attributes,
    this.accessor,
  });

  /// What sort of value this is.
  final ValueKind kind;

  /// The text of a leaf value: the string itself, a number as text, a function
  /// name, a date in ISO format, a regular expression, an error message, or an
  /// element's tag name.
  final String? value;

  /// The type name of an object, such as `Map` or `User`.
  final String? className;

  /// The length of a list or a string, or the size of a map or a set.
  final int? size;

  /// The captured children of an object, list, map, set, error or element.
  ///
  /// `null` means the value has children that were not captured because the
  /// depth limit was reached.
  final List<ValueEntry>? children;

  /// How many children exist but were left out because of a limit.
  final int omitted;

  /// How many characters were cut from a long string.
  final int truncated;

  /// The stack trace of an error, without its first line.
  final String? stack;

  /// The attributes of an element, as name and value pairs.
  final List<MapEntry<String, String>>? attributes;

  /// For an accessor property, which parts are defined.
  final AccessorKind? accessor;

  /// A copy with the fields given here replaced.
  ValueNode copyWith({
    ValueKind? kind,
    String? value,
    String? className,
    int? size,
    List<ValueEntry>? children,
    int? omitted,
    int? truncated,
    String? stack,
    List<MapEntry<String, String>>? attributes,
    AccessorKind? accessor,
  }) {
    return ValueNode(
      kind: kind ?? this.kind,
      value: value ?? this.value,
      className: className ?? this.className,
      size: size ?? this.size,
      children: children ?? this.children,
      omitted: omitted ?? this.omitted,
      truncated: truncated ?? this.truncated,
      stack: stack ?? this.stack,
      attributes: attributes ?? this.attributes,
      accessor: accessor ?? this.accessor,
    );
  }
}

/// A child of a value: a property, a list item, a map entry or a child node.
class ValueEntry {
  /// Creates a child of a captured value.
  const ValueEntry({required this.value, this.key, this.keyKind, this.keyValue});

  /// The captured child itself.
  final ValueNode value;

  /// The property name or index. Absent for set items and child nodes.
  final String? key;

  /// How the key is displayed.
  final ValueKeyKind? keyKind;

  /// The key of a map entry.
  final ValueNode? keyValue;
}

/// The fields a caller provides when adding an entry.
class LogEntryInit {
  /// Creates the description of an entry to add.
  const LogEntryInit({
    required this.parts,
    this.level = LogLevel.log,
    this.kind = LogKind.message,
    this.time,
    this.groups = const <int>[],
    this.collapsed = false,
  });

  /// The content of the entry.
  final List<LogPart> parts;

  /// How severe the entry is.
  final LogLevel level;

  /// What the entry represents.
  final LogKind kind;

  /// When the entry happened. Defaults to the time it is added.
  final DateTime? time;

  /// Ids of the open groups this entry belongs to, outermost first.
  final List<int> groups;

  /// For a group header, whether the group starts collapsed.
  final bool collapsed;

  /// A copy with the fields given here replaced.
  LogEntryInit copyWith({
    List<LogPart>? parts,
    LogLevel? level,
    LogKind? kind,
    DateTime? time,
    List<int>? groups,
    bool? collapsed,
  }) {
    return LogEntryInit(
      parts: parts ?? this.parts,
      level: level ?? this.level,
      kind: kind ?? this.kind,
      time: time ?? this.time,
      groups: groups ?? this.groups,
      collapsed: collapsed ?? this.collapsed,
    );
  }
}

/// An entry held by a store.
class LogEntry {
  /// Creates an entry. Only a [LogStore] does this; everything else reads them.
  LogEntry({
    required this.id,
    required this.time,
    required this.level,
    required this.kind,
    required this.parts,
    required this.groups,
    this.runHead,
    this.collapsed = false,
    this.repeat = 1,
    this.version = 0,
  });

  /// The position of the entry in the store, counted from the first ever added.
  final int id;

  /// When the entry happened.
  final DateTime time;

  /// How severe the entry is.
  final LogLevel level;

  /// What the entry represents.
  final LogKind kind;

  /// The content of the entry.
  final List<LogPart> parts;

  /// Ids of the open groups this entry belongs to, outermost first.
  final List<int> groups;

  /// The id of the first entry of the run of identical messages this one
  /// repeats, set only with [MergeRepeats.collapse]. The entry is hidden while
  /// that entry is collapsed.
  final int? runHead;

  /// For a group header, or for the first entry of a run, whether its members
  /// are hidden.
  bool collapsed;

  /// How many identical consecutive messages this entry stands for.
  int repeat;

  /// Increases whenever [collapsed] or [repeat] changes, so cached layouts can
  /// be refreshed.
  int version;
}
