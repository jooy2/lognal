import { errorTitle, previewValue } from './value/preview.js';
import { LOG_LEVELS, type LogEntry, type LogLevel, type ValueNode } from './types.js';

/**
 * A rule that hides the entries whose text matches it, however the filter is set. It is meant
 * for noise a reader never wants to see, such as a message a library repeats.
 */
export interface MuteRule {
	/** The text an entry must contain to be hidden. An empty rule hides nothing. */
	text: string;
	/** Whether `text` is a regular expression. */
	regex?: boolean;
	/** Whether letter case must match. */
	caseSensitive?: boolean;
	/** Whether the rule is applied. Defaults to `true`. */
	enabled?: boolean;
}

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
	/** Rules that hide entries whatever the rest of the filter says. */
	mute?: readonly MuteRule[];
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
	/** Tests an entry against the mute rules. `null` when no rule applies. */
	muted: ((entry: LogEntry) => boolean) | null;
	/** Finds matches in a line of text, for highlighting. `null` when there is no text filter. */
	pattern: RegExp | null;
	/** Set when `text` is not a valid regular expression. */
	error: string | null;
}

/** Escapes the characters that have a meaning in a regular expression. */
export const escapeRegExp = (text: string): string => {
	return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};

/**
 * Turns the mute rules into a test, or `null` when no rule applies. A rule whose regular
 * expression does not compile is left out, so a rule being typed hides nothing by accident.
 */
const compileMute = (
	rules: readonly MuteRule[] | undefined
): ((entry: LogEntry) => boolean) | null => {
	const patterns: RegExp[] = [];

	for (const rule of rules ?? []) {
		if (!rule.text || rule.enabled === false) {
			continue;
		}

		try {
			patterns.push(
				new RegExp(
					rule.regex ? rule.text.normalize('NFC') : escapeRegExp(rule.text.normalize('NFC')),
					rule.caseSensitive ? '' : 'i'
				)
			);
		} catch {
			// The rule is not a valid pattern, so it hides nothing.
		}
	}

	if (patterns.length === 0) {
		return null;
	}

	return (entry: LogEntry): boolean => {
		// A command the user typed and a notice from the viewer are never hidden.
		if (entry.kind === 'input' || entry.kind === 'system') {
			return false;
		}

		const text = entrySearchText(entry);

		return patterns.some((pattern) => pattern.test(text));
	};
};

/** Turns a filter into a function that tests entries. */
export const compileFilter = (filter: LogFilter | null | undefined): CompiledFilter => {
	if (!filter) {
		return { matches: null, muted: null, pattern: null, error: null };
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

	const muted = compileMute(filter.mute);

	if (!levels && !pattern && !error) {
		return { matches: null, muted, pattern: null, error: null };
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

	return { matches, muted, pattern, error };
};
