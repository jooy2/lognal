import { codePointWidth } from './width.js';

/** Splits text into user-perceived characters (grapheme clusters). */
export type GraphemeSplitter = (text: string) => string[];

const ZERO_WIDTH_JOINER = 0x200d;
const REGIONAL_INDICATOR_FIRST = 0x1f1e6;
const REGIONAL_INDICATOR_LAST = 0x1f1ff;

const isRegionalIndicator = (codePoint: number): boolean => {
	return codePoint >= REGIONAL_INDICATOR_FIRST && codePoint <= REGIONAL_INDICATOR_LAST;
};

const isEmojiModifier = (codePoint: number): boolean => {
	return codePoint >= 0x1f3fb && codePoint <= 0x1f3ff;
};

/**
 * A grapheme splitter that needs no platform support.
 *
 * It joins combining marks, variation selectors, emoji modifiers, zero width joiner sequences
 * and regional indicator pairs to the character before them. That covers the cases a log line
 * meets in practice; `Intl.Segmenter` is used instead wherever it exists.
 */
export const splitGraphemesFallback: GraphemeSplitter = (text) => {
	const clusters: string[] = [];
	let joinNext = false;
	let regionalCount = 0;

	for (const character of text) {
		const codePoint = character.codePointAt(0) ?? 0;
		const last = clusters.length - 1;
		const attaches =
			last >= 0 &&
			(joinNext ||
				codePointWidth(codePoint) === 0 ||
				isEmojiModifier(codePoint) ||
				(isRegionalIndicator(codePoint) && regionalCount % 2 === 1));

		if (attaches) {
			clusters[last] += character;
		} else {
			clusters.push(character);
		}

		regionalCount = isRegionalIndicator(codePoint) ? regionalCount + 1 : 0;
		joinNext = codePoint === ZERO_WIDTH_JOINER;
	}

	return clusters;
};

interface SegmenterLike {
	segment(input: string): Iterable<{ segment: string }>;
}

let activeSplitter: GraphemeSplitter | null = null;

const createDefaultSplitter = (): GraphemeSplitter => {
	const intl = (globalThis as { Intl?: { Segmenter?: new (...args: unknown[]) => SegmenterLike } })
		.Intl;

	if (intl?.Segmenter) {
		const segmenter = new intl.Segmenter(undefined, { granularity: 'grapheme' });

		return (text) => {
			const clusters: string[] = [];

			for (const { segment } of segmenter.segment(text)) {
				clusters.push(segment);
			}

			return clusters;
		};
	}

	return splitGraphemesFallback;
};

/**
 * Replaces the grapheme splitter used by the text layout. Pass `null` to go back to the
 * default, which uses `Intl.Segmenter` when the platform has it.
 */
export const setGraphemeSplitter = (splitter: GraphemeSplitter | null): void => {
	activeSplitter = splitter;
};

/** Splits text into grapheme clusters with the active splitter. */
export const splitGraphemes = (text: string): string[] => {
	if (!activeSplitter) {
		activeSplitter = createDefaultSplitter();
	}

	return activeSplitter(text);
};
