import type { LogLayout } from './layout.js';
import type { TextMatch } from './types.js';

/** The most matches a search keeps. Past it, the rest of the log is not searched. */
export const MAX_SEARCH_MATCHES = 100000;

const SPECIAL_CHARACTERS = /[.*+?^${}()|[\]\\]/g;

/**
 * Builds the pattern of a search: the text as typed, ignoring letter case, in Unicode
 * normalization form C. Returns `null` for empty text.
 */
export const compileSearch = (query: string): RegExp | null => {
	const text = query.normalize('NFC');

	return text ? new RegExp(text.replace(SPECIAL_CHARACTERS, '\\$&'), 'gi') : null;
};

const sameMatch = (a: TextMatch, b: TextMatch): boolean => {
	return a.entryId === b.entryId && a.line === b.line && a.from === b.from;
};

/**
 * Finds text in the visible entries of a layout without hiding any of them, and keeps track of
 * the current match.
 *
 * The log is searched a slice at a time with `scan`, so a long log never blocks a frame.
 * Entries added at the end are searched as they arrive, matches in entries dropped from the
 * front are forgotten, and any other change to the text, such as a new filter or an expanded
 * value, starts the search again. The current match stays current as long as it still exists.
 */
export class LogSearch {
	private pattern: RegExp | null = null;
	private text = '';
	private matches: TextMatch[] = [];
	private readonly byEntry = new Map<number, TextMatch[]>();
	private scannedVersion = -1;
	/** The id of the last entry searched. Visible entries after it are still to be searched. */
	private scannedId = 0;
	private currentIndex = -1;
	private currentMatch: TextMatch | null = null;

	constructor(private readonly layout: LogLayout) {}

	/** The text searched for. */
	get query(): string {
		return this.text;
	}

	get count(): number {
		return this.matches.length;
	}

	/** The index of the current match, or -1 when there is none. */
	get current(): number {
		return this.currentIndex;
	}

	/** Whether part of the log still has to be searched. */
	get pending(): boolean {
		if (!this.pattern || this.matches.length >= MAX_SEARCH_MATCHES) {
			return false;
		}

		const last = this.layout.entryAt(this.layout.visibleCount - 1);

		return this.scannedVersion !== this.layout.textVersion || (last?.id ?? 0) > this.scannedId;
	}

	/** Sets the text to search for. Returns whether it changed. */
	setQuery(query: string): boolean {
		if (query === this.text) {
			return false;
		}

		this.text = query;
		this.pattern = compileSearch(query);
		this.currentMatch = null;
		this.restart();

		return true;
	}

	/** Returns the matches in an entry, if it has any. */
	matchesOf(entryId: number): readonly TextMatch[] | undefined {
		return this.byEntry.get(entryId);
	}

	getMatch(index: number): TextMatch | undefined {
		return this.matches[index];
	}

	/** Returns the index of the first match in the entry with the given id or a later one. */
	firstMatchFrom(entryId: number): number {
		let low = 0;
		let high = this.matches.length;

		while (low < high) {
			const middle = (low + high) >> 1;

			if (this.matches[middle].entryId < entryId) {
				low = middle + 1;
			} else {
				high = middle;
			}
		}

		return low < this.matches.length ? low : -1;
	}

	/** Makes a match the current one. An index out of range clears the current match. */
	select(index: number): TextMatch | null {
		const match = this.matches[index] ?? null;

		this.currentIndex = match ? index : -1;
		this.currentMatch = match;

		return match;
	}

	/** Moves to the next match, or back to the first one after the last. */
	next(): TextMatch | null {
		return this.count === 0 ? null : this.select((this.currentIndex + 1) % this.count);
	}

	/** Moves to the previous match, or on to the last one before the first. */
	previous(): TextMatch | null {
		if (this.count === 0) {
			return null;
		}

		return this.select(this.currentIndex <= 0 ? this.count - 1 : this.currentIndex - 1);
	}

	/**
	 * Searches up to `entries` more visible entries. Call `layout.sync` first. Returns whether
	 * the matches changed.
	 */
	scan(entries: number): boolean {
		const pattern = this.pattern;

		if (!pattern) {
			return false;
		}

		let changed = false;

		if (this.scannedVersion !== this.layout.textVersion) {
			changed = this.matches.length > 0;
			this.restart();
		}

		changed = this.forgetDropped() || changed;

		let index = this.layout.indexFrom(this.scannedId + 1);
		const end = Math.min(this.layout.visibleCount, index + entries);

		for (; index < end && this.matches.length < MAX_SEARCH_MATCHES; index++) {
			const entry = this.layout.entryAt(index);

			if (!entry) {
				break;
			}

			const found = this.layout.findInEntry(
				entry,
				pattern,
				MAX_SEARCH_MATCHES - this.matches.length
			);

			this.scannedId = entry.id;

			if (found.length === 0) {
				continue;
			}

			for (const match of found) {
				if (this.currentMatch && this.currentIndex < 0 && sameMatch(match, this.currentMatch)) {
					this.currentIndex = this.matches.length;
					this.currentMatch = match;
				}

				this.matches.push(match);
			}

			this.byEntry.set(entry.id, found);
			changed = true;
		}

		return changed;
	}

	private restart(): void {
		this.matches = [];
		this.byEntry.clear();
		this.scannedVersion = this.layout.textVersion;
		this.scannedId = 0;
		this.currentIndex = -1;
	}

	/** Forgets the matches in entries that were dropped from the front of the log. */
	private forgetDropped(): boolean {
		const firstId = this.layout.entryAt(0)?.id ?? Number.POSITIVE_INFINITY;
		let dropped = 0;

		while (dropped < this.matches.length && this.matches[dropped].entryId < firstId) {
			this.byEntry.delete(this.matches[dropped].entryId);
			dropped++;
		}

		if (dropped === 0) {
			return false;
		}

		this.matches.splice(0, dropped);

		if (this.currentIndex >= dropped) {
			this.currentIndex -= dropped;
		} else if (this.currentIndex >= 0) {
			this.currentIndex = -1;
			this.currentMatch = null;
		}

		return true;
	}
}
