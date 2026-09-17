import 'dart:convert';
import 'dart:typed_data';

/// Turns bytes into text, a chunk at a time, keeping whatever a chunk boundary
/// cut in half.
abstract class TextDecoderSink {
  /// Lets a subclass declare a `const` constructor.
  const TextDecoderSink();

  /// Decodes a chunk, holding back an incomplete sequence at its end.
  String add(List<int> bytes);

  /// Decodes whatever was held back, once there is no more input.
  String close();
}

/// Creates a decoder for an encoding, or returns `null` when it does not know
/// the encoding.
typedef TextDecoderFactory = TextDecoderSink? Function(String encoding);

/// The legacy encoding a system assumes for text in each language, used when a
/// file is not valid UTF-8. The list is the "suggested default encoding" table
/// of the HTML Standard, which is the same one the JavaScript package uses.
const List<List<String>> _legacyEncodings = <List<String>>[
  <String>[r'^ko\b', 'euc-kr'],
  <String>[r'^ja\b', 'shift_jis'],
  <String>[r'^zh-(hant|hk|mo|tw)\b', 'big5'],
  <String>[r'^zh\b', 'gbk'],
  <String>[r'^(ba|be|bg|kk|ky|mk|ru|sah|sr|tg|tt|uk)\b', 'windows-1251'],
  <String>[r'^(cs|hr|sk)\b', 'windows-1250'],
  <String>[r'^(hu|pl|sl)\b', 'iso-8859-2'],
  <String>[r'^el\b', 'iso-8859-7'],
  <String>[r'^(et|lt|lv)\b', 'windows-1257'],
  <String>[r'^(ar|fa)\b', 'windows-1256'],
  <String>[r'^he\b', 'windows-1255'],
  <String>[r'^(az|ku|tr)\b', 'windows-1254'],
  <String>[r'^th\b', 'windows-874'],
  <String>[r'^vi\b', 'windows-1258'],
];

/// Returns the legacy encoding for a language tag, such as `euc-kr` for `ko-KR`.
String legacyEncodingFor(String? locale) {
  if (locale != null) {
    for (final List<String> entry in _legacyEncodings) {
      if (RegExp(entry[0], caseSensitive: false).hasMatch(locale)) {
        return entry[1];
      }
    }
  }

  return 'windows-1252';
}

/// Returns the encoding a byte order mark at the start of the bytes announces,
/// if any.
String? encodingFromBom(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf) {
    return 'utf-8';
  }

  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
    return 'utf-16le';
  }

  if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
    return 'utf-16be';
  }

  return null;
}

/// Returns whether the bytes are valid UTF-8. A sequence cut at the end still
/// counts as valid.
bool isValidUtf8(List<int> bytes) {
  try {
    const Utf8Decoder(allowMalformed: false).convert(bytes);

    return true;
  } on FormatException {
    // A sequence the last chunk cut in half is not a reason to give up on UTF-8,
    // so the tail is tried again without its unfinished character.
    for (int back = 1; back <= 3 && back < bytes.length; back++) {
      try {
        const Utf8Decoder(allowMalformed: false).convert(bytes, 0, bytes.length - back);

        return true;
      } on FormatException {
        continue;
      }
    }

    return false;
  }
}

/// Picks the encoding of a file from its first bytes: the byte order mark if
/// there is one, then UTF-8 if the bytes are valid UTF-8, and otherwise
/// [fallback].
String detectEncoding(List<int> bytes, String fallback) {
  return encodingFromBom(bytes) ?? (isValidUtf8(bytes) ? 'utf-8' : fallback);
}

/// Windows-1252 differs from Latin-1 only in the 0x80 to 0x9f range, which is
/// where it puts the punctuation a Western log file actually contains.
const List<int> _windows1252High = <int>[
  0x20ac, 0x81, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, //
  0x02c6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8d, 0x017d, 0x8f,
  0x90, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014,
  0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0x9d, 0x017e, 0x0178,
];

class _Utf8Sink extends TextDecoderSink {
  final List<int> _pending = <int>[];
  bool _skipBom = true;

  @override
  String add(List<int> bytes) {
    _pending.addAll(bytes);

    if (_skipBom) {
      _skipBom = false;

      if (_pending.length >= 3 &&
          _pending[0] == 0xef &&
          _pending[1] == 0xbb &&
          _pending[2] == 0xbf) {
        _pending.removeRange(0, 3);
      }
    }

    // Everything up to the last character that may still be unfinished.
    int end = _pending.length;

    for (int back = 1; back <= 3 && back <= _pending.length; back++) {
      final int byte = _pending[_pending.length - back];

      if (byte < 0x80) {
        break;
      }

      if (byte >= 0xc0) {
        final int needed = byte >= 0xf0
            ? 4
            : byte >= 0xe0
            ? 3
            : 2;

        if (back < needed) {
          end = _pending.length - back;
        }

        break;
      }
    }

    final String text = const Utf8Decoder(allowMalformed: true).convert(_pending.sublist(0, end));

    _pending.removeRange(0, end);

    return text;
  }

  @override
  String close() {
    if (_pending.isEmpty) {
      return '';
    }

    final String text = const Utf8Decoder(allowMalformed: true).convert(_pending);

    _pending.clear();

    return text;
  }
}

class _Utf16Sink extends TextDecoderSink {
  _Utf16Sink({required this.littleEndian});

  final bool littleEndian;
  final List<int> _pending = <int>[];
  bool _skipBom = true;

  @override
  String add(List<int> bytes) {
    _pending.addAll(bytes);

    final int units = _pending.length ~/ 2;
    final List<int> codes = <int>[];

    for (int index = 0; index < units; index++) {
      final int low = _pending[index * 2];
      final int high = _pending[index * 2 + 1];

      codes.add(littleEndian ? low | (high << 8) : (low << 8) | high);
    }

    _pending.removeRange(0, units * 2);

    if (_skipBom && codes.isNotEmpty) {
      _skipBom = false;

      if (codes.first == 0xfeff) {
        codes.removeAt(0);
      }
    }

    return String.fromCharCodes(codes);
  }

  @override
  String close() {
    _pending.clear();

    return '';
  }
}

class _ByteTableSink extends TextDecoderSink {
  const _ByteTableSink(this.high);

  /// The characters the bytes 0x80 to 0x9f stand for, or `null` for Latin-1,
  /// where they are the control characters they already are.
  final List<int>? high;

  @override
  String add(List<int> bytes) {
    final Uint16List codes = Uint16List(bytes.length);
    final List<int>? table = high;

    for (int index = 0; index < bytes.length; index++) {
      final int byte = bytes[index];

      codes[index] = table != null && byte >= 0x80 && byte <= 0x9f ? table[byte - 0x80] : byte;
    }

    return String.fromCharCodes(codes);
  }

  @override
  String close() => '';
}

/// The encodings this package decodes on its own.
///
/// UTF-8 and UTF-16 cover everything written this decade, and Windows-1252 and
/// Latin-1 cover the Western legacy files. A legacy CJK encoding — `euc-kr`,
/// `shift_jis`, `big5`, `gbk` — needs a table of tens of thousands of characters
/// each, which the browser already has and Dart does not, so rather than ship
/// four of them the package takes one from you: see [registerTextDecoder].
const Set<String> builtInEncodings = <String>{
  'utf-8',
  'utf8',
  'utf-16le',
  'utf-16be',
  'utf-16',
  'latin1',
  'iso-8859-1',
  'windows-1252',
  'ascii',
  'us-ascii',
};

final List<TextDecoderFactory> _decoderFactories = <TextDecoderFactory>[];

/// Teaches this package an encoding it does not decode itself.
///
/// The factory is asked for every encoding the reader meets, newest first, and
/// returns `null` for the ones it does not handle. Use it to hand lognal a
/// decoder for `euc-kr` or another legacy encoding, from whichever package you
/// already depend on.
///
/// Returns a function that takes the factory back out again.
void Function() registerTextDecoder(TextDecoderFactory factory) {
  _decoderFactories.add(factory);

  return () => _decoderFactories.remove(factory);
}

/// Returns a decoder for an encoding, or `null` when nothing here knows it.
///
/// A registered factory is asked first, so an application can replace even a
/// built-in one.
TextDecoderSink? decoderFor(String encoding) {
  final String name = encoding.toLowerCase().trim();

  for (final TextDecoderFactory factory in _decoderFactories.reversed) {
    final TextDecoderSink? sink = factory(name);

    if (sink != null) {
      return sink;
    }
  }

  switch (name) {
    case 'utf-8':
    case 'utf8':
      return _Utf8Sink();
    case 'utf-16':
    case 'utf-16le':
      return _Utf16Sink(littleEndian: true);
    case 'utf-16be':
      return _Utf16Sink(littleEndian: false);
    case 'windows-1252':
      return const _ByteTableSink(_windows1252High);
    case 'latin1':
    case 'iso-8859-1':
    case 'ascii':
    case 'us-ascii':
      return const _ByteTableSink(null);
    default:
      return null;
  }
}
