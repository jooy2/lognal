/** A web address found in text, as a range of UTF-16 code units. */
export interface TextLink {
	/** The index of the first character of the address. */
	start: number;
	/** The index after the last character of the address. */
	end: number;
	/** The address, which is the text between `start` and `end`. */
	url: string;
}

/**
 * `http://` or `https://` in any letter case, not preceded by a letter or a digit, and the
 * characters after it up to a space, a control character, a quote or an angle bracket.
 */
const LINK_PATTERN = /\bhttps?:\/\/[^\s"'`<>\x00-\x1f\x7f]+/gi;
/** An address needs a host that starts with a letter or a digit, or an IPv6 address. */
const HOST = /^https?:\/\/[\p{L}\p{N}[]/iu;
/** Punctuation that usually ends the sentence around an address rather than the address. */
const TRAILING_PUNCTUATION = '.,;:!?…。、，．！？：；';
/** Closing brackets, with the opening bracket each one pairs with. */
const BRACKETS: Record<string, string> = {
	')': '(',
	']': '[',
	'}': '{',
	'）': '（',
	'」': '「',
	'』': '『',
	'】': '【',
	'〉': '〈',
	'》': '《'
};

/**
 * Returns whether a character is invisible or changes the order of the text around it, such as
 * a zero width space or a bidirectional override. An address ends before any of them, so what a
 * link opens is never hidden.
 */
export const isFormatCharacter = (code: number): boolean => {
	return (
		code === 0x061c ||
		(code >= 0x200b && code <= 0x200f) ||
		(code >= 0x202a && code <= 0x202e) ||
		(code >= 0x2060 && code <= 0x206f) ||
		code === 0xfeff
	);
};

const countOf = (text: string, character: string): number => {
	let count = 0;

	for (
		let index = text.indexOf(character);
		index >= 0;
		index = text.indexOf(character, index + 1)
	) {
		count++;
	}

	return count;
};

/**
 * Removes what follows an address rather than belonging to it: punctuation at the end, and a
 * closing bracket that has no opening bracket in the address, as in `(see https://example.com)`.
 */
const trimAddress = (text: string): string => {
	let end = text.length;

	while (end > 0) {
		const last = text[end - 1];
		const opening = BRACKETS[last];

		if (TRAILING_PUNCTUATION.includes(last)) {
			end--;
		} else if (
			opening !== undefined &&
			countOf(text.slice(0, end), last) > countOf(text.slice(0, end), opening)
		) {
			end--;
		} else {
			break;
		}
	}

	return text.slice(0, end);
};

/**
 * Finds the `http` and `https` addresses in text. Addresses with any other scheme, and text
 * without a host after `://`, are not links.
 */
export const findLinks = (text: string): TextLink[] => {
	const links: TextLink[] = [];

	if (!text.includes('://')) {
		return links;
	}

	LINK_PATTERN.lastIndex = 0;

	for (let match = LINK_PATTERN.exec(text); match; match = LINK_PATTERN.exec(text)) {
		let candidate = match[0];

		for (let index = 0; index < candidate.length; index++) {
			if (isFormatCharacter(candidate.charCodeAt(index))) {
				candidate = candidate.slice(0, index);
				// Look for another address after the character.
				LINK_PATTERN.lastIndex = match.index + index;
				break;
			}
		}

		const url = trimAddress(candidate);

		if (HOST.test(url)) {
			links.push({ start: match.index, end: match.index + url.length, url });
		}
	}

	return links;
};
