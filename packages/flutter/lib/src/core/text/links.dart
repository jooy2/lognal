/// A web address found in text, as a range of UTF-16 code units.
class TextLink {
  /// Creates a found address.
  const TextLink({required this.start, required this.end, required this.url});

  /// The index of the first character of the address.
  final int start;

  /// The index after the last character of the address.
  final int end;

  /// The address, which is the text between [start] and [end].
  final String url;
}

/// `http://` or `https://` in any letter case, not preceded by a letter or a
/// digit, and the characters after it up to a space, a control character, a
/// quote or an angle bracket.
final RegExp _linkPattern = RegExp(
  '\\bhttps?://[^\\s"\'`<>\\x00-\\x1f\\x7f]+',
  caseSensitive: false,
);

/// An address needs a host that starts with a letter or a digit, or an IPv6
/// address.
final RegExp _host = RegExp(r'^https?://[\p{L}\p{N}\[]', caseSensitive: false, unicode: true);

/// Punctuation that usually ends the sentence around an address rather than the
/// address.
const String _trailingPunctuation = '.,;:!?…。、，．！？：；';

/// Closing brackets, with the opening bracket each one pairs with.
const Map<String, String> _brackets = <String, String>{
  ')': '(',
  ']': '[',
  '}': '{',
  '）': '（',
  '」': '「',
  '』': '『',
  '】': '【',
  '〉': '〈',
  '》': '《',
};

/// Returns whether a character is invisible or changes the order of the text
/// around it, such as a zero width space or a bidirectional override. An address
/// ends before any of them, so what a link opens is never hidden.
bool isFormatCharacter(int code) {
  return code == 0x061c ||
      (code >= 0x200b && code <= 0x200f) ||
      (code >= 0x202a && code <= 0x202e) ||
      (code >= 0x2060 && code <= 0x206f) ||
      code == 0xfeff;
}

int _countOf(String text, String character) {
  int count = 0;

  for (
    int index = text.indexOf(character);
    index >= 0;
    index = text.indexOf(character, index + 1)
  ) {
    count++;
  }

  return count;
}

/// Removes what follows an address rather than belonging to it: punctuation at
/// the end, and a closing bracket that has no opening bracket in the address, as
/// in `(see https://example.com)`.
String _trimAddress(String text) {
  int end = text.length;

  while (end > 0) {
    final String last = text[end - 1];
    final String? opening = _brackets[last];

    if (_trailingPunctuation.contains(last)) {
      end--;
    } else if (opening != null &&
        _countOf(text.substring(0, end), last) > _countOf(text.substring(0, end), opening)) {
      end--;
    } else {
      break;
    }
  }

  return text.substring(0, end);
}

/// Finds the `http` and `https` addresses in text. Addresses with any other
/// scheme, and text without a host after `://`, are not links.
List<TextLink> findLinks(String text) {
  final List<TextLink> links = <TextLink>[];

  if (!text.contains('://')) {
    return links;
  }

  int from = 0;

  while (from <= text.length) {
    // `allMatches` with a start index rather than a match on a slice: the
    // pattern opens with `\b`, and a slice would hide the character before it
    // and let an address inside a word start one.
    final RegExpMatch? match = _linkPattern.allMatches(text, from).firstOrNull;

    if (match == null) {
      break;
    }

    String candidate = match.group(0)!;
    int next = match.end;

    for (int index = 0; index < candidate.length; index++) {
      if (isFormatCharacter(candidate.codeUnitAt(index))) {
        candidate = candidate.substring(0, index);
        // Look for another address after the character.
        next = match.start + index;
        break;
      }
    }

    final String url = _trimAddress(candidate);

    if (_host.hasMatch(url)) {
      links.add(TextLink(start: match.start, end: match.start + url.length, url: url));
    }

    from = next > from ? next : from + 1;
  }

  return links;
}
