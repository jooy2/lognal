import { errorTitle, previewValue } from './value/preview.js';
import { LOG_LEVELS, type LogEntry, type LogLevel, type ValueNode } from './types.js';

/** Which entries a viewer shows. */
export interface LogFilter {
	/** Text an entry must contain. Empty text matches every entry. */
	text?: string;
	/** Whether `text` is a regular expression. */
	regex?: boolean;
	/** Whether letter case must match. */
	caseSensitive?: boolean;
	/** The least severe level shown. */
	minLevel?: LogLevel;
	/** The levels shown. When set, `minLevel` is ignored. */
	levels?: readonly LogLevel[];
}

/** The most characters of an entry the text filter looks at. */
const SEARCH_TEXT_LIMIT = 20000;

const searchTextCache = new WeakMap<LogEntry, { version: number; text: string }>();

const valueText = (node: ValueNode): string => {
	if (node.kind === 'error') {
		return `${errorTitle(node)}\n${node.stack ?? ''}`;
	}

	return previewValue(node)
		.map((span) => span.text)
		.join('');
};

/**
 * Returns the text of an entry as the filter sees it: its text parts, and a one-line preview of
 * every value.
 */
export const entrySearchText = (entry: LogEntry): string => {
	const cached = searchTextCache.get(entry);

	if (cached && cached.version === entry.version) {
		return cached.text;
	}

	let text = '';

	for (const part of entry.parts) {
		text += part.type === 'text' ? part.text : valueText(part.value);

		if (text.length > SEARCH_TEXT_LIMIT) {
			text = text.slice(0, SEARCH_TEXT_LIMIT);
			break;
		}
	}

	// Compose decomposed Hangul and accented letters, so text copied from a macOS file name
	// matches what the user types.
	text = text.normalize('NFC');
	searchTextCache.set(entry, { version: entry.version, text });

	return text;
};

/** A compiled filter. `matches` is `null` when the filter lets every entry through. */
export interface CompiledFilter {
	matches: ((entry: LogEntry) => boolean) | null;
	/** Finds matches in a line of text, for highlighting. `null` when there is no text filter. */
	pattern: RegExp | null;
	/** Set when `text` is not a valid regular expression. */
	error: string | null;
}

const escapeRegExp = (text: string): string => {
	return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};

/** Turns a filter into a function that tests entries. */
export const compileFilter = (filter: LogFilter | null | undefined): CompiledFilter => {
	if (!filter) {
		return { matches: null, pattern: null, error: null };
	}

	const levels = filter.levels
		? new Set(filter.levels)
		: filter.minLevel
			? new Set(LOG_LEVELS.slice(LOG_LEVELS.indexOf(filter.minLevel)))
			: null;
	let pattern: RegExp | null = null;
	let error: string | null = null;

	if (filter.text) {
		const flags = filter.caseSensitive ? 'g' : 'gi';

		try {
			const text = filter.text.normalize('NFC');

			pattern = new RegExp(filter.regex ? text : escapeRegExp(text), flags);
		} catch (caught) {
			error = caught instanceof Error ? caught.message : String(caught);
		}
	}

	if (!levels && !pattern && !error) {
		return { matches: null, pattern: null, error: null };
	}

	const matches = (entry: LogEntry): boolean => {
		if (entry.kind === 'group' && !pattern && !error) {
			return true;
		}

		if (levels && entry.kind !== 'input' && entry.kind !== 'system' && !levels.has(entry.level)) {
			return false;
		}

		if (error) {
			return false;
		}

		if (pattern) {
			pattern.lastIndex = 0;

			return pattern.test(entrySearchText(entry));
		}

		return true;
	};

	return { matches, pattern, error };
};
