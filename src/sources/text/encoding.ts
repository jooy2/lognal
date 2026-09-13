/**
 * The legacy encoding a browser assumes for a page in each language, used when a file is not
 * valid UTF-8. The list is the "suggested default encoding" table of the HTML Standard.
 */
const LEGACY_ENCODINGS: [RegExp, string][] = [
	[/^ko\b/i, 'euc-kr'],
	[/^ja\b/i, 'shift_jis'],
	[/^zh-(hant|hk|mo|tw)\b/i, 'big5'],
	[/^zh\b/i, 'gbk'],
	[/^(ba|be|bg|kk|ky|mk|ru|sah|sr|tg|tt|uk)\b/i, 'windows-1251'],
	[/^(cs|hr|sk)\b/i, 'windows-1250'],
	[/^(hu|pl|sl)\b/i, 'iso-8859-2'],
	[/^el\b/i, 'iso-8859-7'],
	[/^(et|lt|lv)\b/i, 'windows-1257'],
	[/^(ar|fa)\b/i, 'windows-1256'],
	[/^he\b/i, 'windows-1255'],
	[/^(az|ku|tr)\b/i, 'windows-1254'],
	[/^th\b/i, 'windows-874'],
	[/^vi\b/i, 'windows-1258']
];

/** Returns the legacy encoding for a language tag, such as `euc-kr` for `ko-KR`. */
export const legacyEncodingFor = (locale: string | undefined): string => {
	for (const [pattern, encoding] of LEGACY_ENCODINGS) {
		if (locale && pattern.test(locale)) {
			return encoding;
		}
	}

	return 'windows-1252';
};

/** Returns the encoding a byte order mark at the start of the bytes announces, if any. */
export const encodingFromBom = (bytes: Uint8Array): string | null => {
	if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
		return 'utf-8';
	}

	if (bytes[0] === 0xff && bytes[1] === 0xfe) {
		return 'utf-16le';
	}

	if (bytes[0] === 0xfe && bytes[1] === 0xff) {
		return 'utf-16be';
	}

	return null;
};

/** Returns whether the bytes are valid UTF-8. A sequence cut at the end still counts as valid. */
export const isValidUtf8 = (bytes: Uint8Array): boolean => {
	try {
		new TextDecoder('utf-8', { fatal: true }).decode(bytes, { stream: true });

		return true;
	} catch {
		return false;
	}
};

/**
 * Picks the encoding of a file from its first bytes: the byte order mark if there is one,
 * then UTF-8 if the bytes are valid UTF-8, and otherwise `fallback`.
 */
export const detectEncoding = (bytes: Uint8Array, fallback: string): string => {
	return encodingFromBom(bytes) ?? (isValidUtf8(bytes) ? 'utf-8' : fallback);
};
