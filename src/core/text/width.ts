import { AMBIGUOUS_RANGES, WIDE_RANGES, ZERO_WIDTH_RANGES } from './unicode-width-data.js';

/** How many cells an East Asian Ambiguous character takes. */
export type AmbiguousWidth = 1 | 2;

const BMP_SIZE = 0x10000;

// Values stored in `bmpCache`. Zero means the code point has not been looked up yet.
const CACHE_ZERO = 1;
const CACHE_NARROW = 2;
const CACHE_WIDE = 3;
const CACHE_AMBIGUOUS = 4;

const REGIONAL_INDICATOR_FIRST = 0x1f1e6;
const REGIONAL_INDICATOR_LAST = 0x1f1ff;
const VARIATION_SELECTOR_TEXT = 0xfe0e;
const VARIATION_SELECTOR_EMOJI = 0xfe0f;

const bmpCache = new Uint8Array(BMP_SIZE);

const isInRanges = (ranges: readonly number[], codePoint: number): boolean => {
	let low = 0;
	let high = ranges.length / 2 - 1;

	if (high < 0 || codePoint < ranges[0] || codePoint > ranges[ranges.length - 1]) {
		return false;
	}

	while (low <= high) {
		const middle = (low + high) >> 1;
		const start = ranges[middle * 2];
		const end = ranges[middle * 2 + 1];

		if (codePoint < start) {
			high = middle - 1;
		} else if (codePoint > end) {
			low = middle + 1;
		} else {
			return true;
		}
	}

	return false;
};

const classify = (codePoint: number): number => {
	// Box drawing and block elements are ambiguous in the data, but monospace fonts draw them
	// one cell wide, and tables drawn with them only line up that way.
	if (codePoint >= 0x2500 && codePoint <= 0x259f) {
		return CACHE_NARROW;
	}

	if (isInRanges(ZERO_WIDTH_RANGES, codePoint)) {
		return CACHE_ZERO;
	}

	if (isInRanges(WIDE_RANGES, codePoint)) {
		return CACHE_WIDE;
	}

	if (isInRanges(AMBIGUOUS_RANGES, codePoint)) {
		return CACHE_AMBIGUOUS;
	}

	return CACHE_NARROW;
};

/**
 * Returns how many cells a single code point takes: 0 for combining marks and format
 * characters, 2 for wide characters, and 1 otherwise.
 *
 * Control characters return 1. Callers are expected to replace them with a visible notation
 * before measuring.
 */
export const codePointWidth = (codePoint: number, ambiguousWidth: AmbiguousWidth = 1): number => {
	// Printable ASCII and the Latin-1 range before the first ambiguous character.
	if (codePoint < 0xa1) {
		return 1;
	}

	let kind: number;

	if (codePoint < BMP_SIZE) {
		kind = bmpCache[codePoint];

		if (kind === 0) {
			kind = classify(codePoint);
			bmpCache[codePoint] = kind;
		}
	} else {
		kind = classify(codePoint);
	}

	if (kind === CACHE_ZERO) {
		return 0;
	}

	if (kind === CACHE_WIDE) {
		return 2;
	}

	if (kind === CACHE_AMBIGUOUS) {
		return ambiguousWidth;
	}

	return 1;
};

/** Returns whether a code point is a Hangul syllable or jamo, where words break at spaces only. */
export const isHangul = (codePoint: number): boolean => {
	return (
		(codePoint >= 0xac00 && codePoint <= 0xd7a3) ||
		(codePoint >= 0x1100 && codePoint <= 0x11ff) ||
		(codePoint >= 0x3130 && codePoint <= 0x318f) ||
		(codePoint >= 0xa960 && codePoint <= 0xa97f) ||
		(codePoint >= 0xd7b0 && codePoint <= 0xd7ff)
	);
};

/**
 * Returns how many cells a grapheme cluster takes.
 *
 * The widest code point decides, with the rules emoji add on top: a cluster with the emoji
 * variation selector or a pair of regional indicators (a flag) is two cells, and one with the
 * text variation selector is one cell.
 */
export const clusterWidth = (cluster: string, ambiguousWidth: AmbiguousWidth = 1): number => {
	if (cluster.length === 1) {
		const code = cluster.charCodeAt(0);

		if (code < 0xa1) {
			return 1;
		}

		return Math.max(codePointWidth(code, ambiguousWidth), isZeroOnly(code) ? 0 : 1);
	}

	let width = 0;
	let hasEmojiSelector = false;
	let hasTextSelector = false;
	let hasRegionalIndicator = false;
	let hasVisible = false;

	for (const character of cluster) {
		const codePoint = character.codePointAt(0) ?? 0;

		if (codePoint === VARIATION_SELECTOR_EMOJI) {
			hasEmojiSelector = true;
			continue;
		}

		if (codePoint === VARIATION_SELECTOR_TEXT) {
			hasTextSelector = true;
			continue;
		}

		if (codePoint >= REGIONAL_INDICATOR_FIRST && codePoint <= REGIONAL_INDICATOR_LAST) {
			hasRegionalIndicator = true;
		}

		const codeWidth = codePointWidth(codePoint, ambiguousWidth);

		if (codeWidth > 0 || !isZeroOnly(codePoint)) {
			hasVisible = true;
		}

		if (codeWidth > width) {
			width = codeWidth;
		}
	}

	if (hasEmojiSelector || hasRegionalIndicator) {
		return 2;
	}

	if (hasTextSelector) {
		return 1;
	}

	if (width === 0) {
		return hasVisible ? 1 : 0;
	}

	return width;
};

/**
 * Invisible format characters, such as the zero width space, that take no cell even when they
 * stand alone. A combining mark on its own still takes one cell so it stays visible.
 */
const isZeroOnly = (codePoint: number): boolean => {
	return (
		codePoint === 0x200b ||
		codePoint === 0x200c ||
		codePoint === 0x200d ||
		codePoint === 0x2060 ||
		codePoint === 0xfeff ||
		codePoint === 0x00ad
	);
};
