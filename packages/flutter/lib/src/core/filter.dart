import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/text/normalize.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/preview.dart';

/// A rule that hides the entries whose text matches it, however the filter is
/// set. It is meant for noise a reader never wants to see, such as a message a
/// library repeats.
class MuteRule {
  /// Creates a rule.
  const MuteRule({
    required this.text,
    this.regex = false,
    this.caseSensitive = false,
    this.enabled = true,
  });

  /// The text an entry must contain to be hidden. An empty rule hides nothing.
  final String text;

  /// Whether [text] is a regular expression.
  final bool regex;

  /// Whether letter case must match.
  final bool caseSensitive;

  /// Whether the rule is applied.
  final bool enabled;

  /// A copy with the fields given here replaced.
  MuteRule copyWith({String? text, bool? regex, bool? caseSensitive, bool? enabled}) {
    return MuteRule(
      text: text ?? this.text,
      regex: regex ?? this.regex,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MuteRule &&
        other.text == text &&
        other.regex == regex &&
        other.caseSensitive == caseSensitive &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(text, regex, caseSensitive, enabled);
}

/// Which entries a viewer shows.
class LogFilter {
  /// Creates a filter.
  const LogFilter({
    this.text = '',
    this.regex = false,
    this.caseSensitive = false,
    this.minLevel,
    this.levels,
    this.mute = const <MuteRule>[],
  });

  /// Text an entry must contain. Empty text matches every entry.
  final String text;

  /// Whether [text] is a regular expression.
  final bool regex;

  /// Whether letter case must match.
  final bool caseSensitive;

  /// The least severe level shown.
  final LogLevel? minLevel;

  /// The levels shown. When set, [minLevel] is ignored.
  final List<LogLevel>? levels;

  /// Rules that hide entries whatever the rest of the filter says.
  final List<MuteRule> mute;

  /// A copy with the fields given here replaced.
  LogFilter copyWith({
    String? text,
    bool? regex,
    bool? caseSensitive,
    LogLevel? minLevel,
    List<LogLevel>? levels,
    List<MuteRule>? mute,
    bool clearLevels = false,
    bool clearMinLevel = false,
  }) {
    return LogFilter(
      text: text ?? this.text,
      regex: regex ?? this.regex,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      minLevel: clearMinLevel ? null : minLevel ?? this.minLevel,
      levels: clearLevels ? null : levels ?? this.levels,
      mute: mute ?? this.mute,
    );
  }
}

/// The most characters of an entry the text filter looks at.
const int _searchTextLimit = 20000;

class _CachedText {
  const _CachedText(this.version, this.text);

  final int version;
  final String text;
}

final Expando<_CachedText> _searchTextCache = Expando<_CachedText>('lognal search text');

String _valueText(ValueNode node) {
  if (node.kind == ValueKind.error) {
    return '${errorTitle(node)}\n${node.stack ?? ''}';
  }

  return previewValue(node).map((LineTextSpan span) => span.text).join();
}

/// Returns the text of an entry as the filter sees it: its text parts, and a
/// one-line preview of every value.
String entrySearchText(LogEntry entry) {
  final _CachedText? cached = _searchTextCache[entry];

  if (cached != null && cached.version == entry.version) {
    return cached.text;
  }

  final StringBuffer buffer = StringBuffer();

  for (final LogPart part in entry.parts) {
    buffer.write(part is TextPart ? part.text : _valueText((part as ValuePart).value));

    if (buffer.length > _searchTextLimit) {
      break;
    }
  }

  String text = buffer.toString();

  if (text.length > _searchTextLimit) {
    text = text.substring(0, _searchTextLimit);
  }

  // Compose decomposed Hangul and accented letters, so text copied from a macOS
  // file name matches what the user types.
  text = normalizeNfc(text);
  _searchTextCache[entry] = _CachedText(entry.version, text);

  return text;
}

/// A compiled filter. [matches] is `null` when the filter lets every entry
/// through.
class CompiledFilter {
  /// Creates a compiled filter.
  const CompiledFilter({this.matches, this.muted, this.pattern, this.error});

  /// Tests an entry against the filter. `null` when every entry passes.
  final bool Function(LogEntry entry)? matches;

  /// Tests an entry against the mute rules. `null` when no rule applies.
  final bool Function(LogEntry entry)? muted;

  /// Finds matches in a line of text, for highlighting. `null` when there is no
  /// text filter.
  final RegExp? pattern;

  /// Set when [LogFilter.text] is not a valid regular expression.
  final String? error;
}

/// Escapes the characters that have a meaning in a regular expression.
String escapeRegExp(String text) {
  return text.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (Match match) => '\\${match[0]}');
}

/// Turns the mute rules into a test, or `null` when no rule applies. A rule
/// whose regular expression does not compile is left out, so a rule being typed
/// hides nothing by accident.
bool Function(LogEntry entry)? _compileMute(List<MuteRule> rules) {
  final List<RegExp> patterns = <RegExp>[];

  for (final MuteRule rule in rules) {
    if (rule.text.isEmpty || !rule.enabled) {
      continue;
    }

    final String source = normalizeNfc(rule.text);

    try {
      patterns.add(
        RegExp(rule.regex ? source : escapeRegExp(source), caseSensitive: rule.caseSensitive),
      );
    } on FormatException {
      // The rule is not a valid pattern, so it hides nothing.
    }
  }

  if (patterns.isEmpty) {
    return null;
  }

  return (LogEntry entry) {
    // A command the user typed and a notice from the viewer are never hidden.
    if (entry.kind == LogKind.input || entry.kind == LogKind.system) {
      return false;
    }

    final String text = entrySearchText(entry);

    return patterns.any((RegExp pattern) => pattern.hasMatch(text));
  };
}

/// Turns a filter into a function that tests entries.
CompiledFilter compileFilter(LogFilter? filter) {
  if (filter == null) {
    return const CompiledFilter();
  }

  final List<LogLevel>? chosen = filter.levels;
  final LogLevel? minLevel = filter.minLevel;
  final Set<LogLevel>? levels = chosen != null
      ? chosen.toSet()
      : minLevel != null
      ? logLevels.sublist(minLevel.index).toSet()
      : null;
  RegExp? pattern;
  String? error;

  if (filter.text.isNotEmpty) {
    final String text = normalizeNfc(filter.text);

    try {
      pattern = RegExp(
        filter.regex ? text : escapeRegExp(text),
        caseSensitive: filter.caseSensitive,
      );
    } on FormatException catch (caught) {
      error = caught.message;
    }
  }

  final bool Function(LogEntry entry)? muted = _compileMute(filter.mute);

  if (levels == null && pattern == null && error == null) {
    return CompiledFilter(muted: muted);
  }

  final RegExp? compiled = pattern;
  final String? failure = error;

  bool matches(LogEntry entry) {
    if (entry.kind == LogKind.group && compiled == null && failure == null) {
      return true;
    }

    if (levels != null &&
        entry.kind != LogKind.input &&
        entry.kind != LogKind.system &&
        !levels.contains(entry.level)) {
      return false;
    }

    if (failure != null) {
      return false;
    }

    if (compiled != null) {
      return compiled.hasMatch(entrySearchText(entry));
    }

    return true;
  }

  return CompiledFilter(matches: matches, muted: muted, pattern: pattern, error: error);
}
