import { AnsiParser } from './text/ansi.js';
import { splitLines } from './text/line-splitter.js';
import type {
	LogEntry,
	LogEntryInit,
	LogKind,
	LogLevel,
	LogPart,
	StyleToken,
	TextStyle
} from './types.js';

export interface LogStoreOptions {
	/**
	 * The most entries the store keeps. Once it is full, the oldest entry is dropped for every
	 * new one. Use `Infinity` to keep everything.
	 */
	maxEntries: number;
	/**
	 * Whether a message identical to the one before it increases that entry's repeat count
	 * instead of adding a new entry. Only entries of the `message` kind are merged, and only when
	 * every part is text or a value that cannot be expanded; an error is never merged.
	 */
	mergeRepeats: boolean;
}

export const DEFAULT_STORE_OPTIONS: LogStoreOptions = {
	maxEntries: 10000,
	mergeRepeats: true
};

/** A change to the contents of a store. */
export type StoreChange =
	| { type: 'append'; entries: readonly LogEntry[] }
	| { type: 'update'; entry: LogEntry }
	| { type: 'trim'; count: number }
	| { type: 'clear' };

export type StoreListener = (change: StoreChange) => void;

/** Options for adding plain text. */
export interface WriteOptions {
	level?: LogLevel;
	kind?: LogKind;
	time?: number;
	groups?: readonly number[];
	token?: StyleToken;
	style?: TextStyle;
	/** Set to `false` to keep every line on one row, for text such as a table. */
	wrap?: boolean;
	/**
	 * Whether ANSI escape codes in the text are turned into styles. Pass a parser to keep the
	 * style running across several calls. Defaults to `false`.
	 */
	ansi?: boolean | AnsiParser;
}

/** How many dropped slots the store tolerates before it compacts its array. */
const COMPACT_THRESHOLD = 4096;

const MERGE_SEPARATOR = String.fromCharCode(0);

/** Returns a string that is equal for two messages that should be merged, or `null`. */
const signatureOf = (init: LogEntryInit, level: LogLevel, kind: LogKind): string | null => {
	if (kind !== 'message') {
		return null;
	}

	const pieces: string[] = [level, (init.groups ?? []).join(',')];

	for (const part of init.parts) {
		if (part.type === 'text') {
			pieces.push(
				`t${part.wrap === false ? 'n' : ''}${part.text}${part.token ?? ''}${part.style ? JSON.stringify(part.style) : ''}`
			);
			continue;
		}

		const { value } = part;

		if (value.children !== undefined || value.kind === 'error') {
			return null;
		}

		pieces.push(`v${value.kind}:${value.value ?? ''}:${value.className ?? ''}`);
	}

	return pieces.join(MERGE_SEPARATOR);
};

/**
 * Holds log entries in the order they were added.
 *
 * The store knows nothing about how entries are displayed, so one store can feed several
 * viewers, or collect messages before any viewer exists.
 */
export class LogStore {
	private options: LogStoreOptions;
	private items: LogEntry[] = [];
	private start = 0;
	private nextId = 1;
	private oldestId = 1;
	private lastSignature: string | null = null;
	private readonly listeners = new Set<StoreListener>();

	constructor(options: Partial<LogStoreOptions> = {}) {
		this.options = { ...DEFAULT_STORE_OPTIONS, ...options };
	}

	/** The number of entries held. */
	get size(): number {
		return this.items.length - this.start;
	}

	/** The id of the oldest entry held. When the store is empty, the id the next entry gets. */
	get firstId(): number {
		return this.oldestId;
	}

	/** The id of the newest entry held, or `firstId - 1` when the store is empty. */
	get lastId(): number {
		return this.nextId - 1;
	}

	getOptions(): Readonly<LogStoreOptions> {
		return this.options;
	}

	setOptions(options: Partial<LogStoreOptions>): void {
		this.options = { ...this.options, ...options };
		this.trimToLimit();
	}

	/** Returns the entry at a position, where 0 is the oldest entry held. */
	at(index: number): LogEntry | undefined {
		if (index < 0 || index >= this.size) {
			return undefined;
		}

		return this.items[this.start + index];
	}

	/** Returns the entry with an id, if the store still holds it. */
	get(id: number): LogEntry | undefined {
		return this.at(id - this.oldestId);
	}

	/** Returns every entry, oldest first. */
	toArray(): LogEntry[] {
		return this.items.slice(this.start);
	}

	[Symbol.iterator](): Iterator<LogEntry> {
		return this.toArray()[Symbol.iterator]();
	}

	/**
	 * Adds one entry or several, and returns the entries that were created. A message merged into
	 * the entry before it only raises that entry's `repeat` count and is not returned.
	 */
	append(init: LogEntryInit | readonly LogEntryInit[]): LogEntry[] {
		const inits = Array.isArray(init) ? init : [init as LogEntryInit];
		const created: LogEntry[] = [];

		for (const item of inits) {
			const level = item.level ?? 'log';
			const kind = item.kind ?? 'message';
			const signature = this.options.mergeRepeats ? signatureOf(item, level, kind) : null;
			const last = this.at(this.size - 1);

			if (signature !== null && last && signature === this.lastSignature) {
				last.repeat++;
				last.version++;
				this.emit({ type: 'update', entry: last });
				continue;
			}

			const entry: LogEntry = {
				id: this.nextId++,
				time: item.time ?? Date.now(),
				level,
				kind,
				parts: item.parts,
				groups: item.groups ?? [],
				collapsed: item.collapsed ?? false,
				repeat: 1,
				version: 0
			};

			this.items.push(entry);
			this.lastSignature = signature;
			created.push(entry);
		}

		if (created.length > 0) {
			this.emit({ type: 'append', entries: created });
			this.trimToLimit();
		}

		return created;
	}

	/** Adds text as one entry. Line breaks stay inside the entry. */
	write(text: string, options: WriteOptions = {}): LogEntry | undefined {
		const parts = this.textParts(text, options);

		return this.append({ ...this.initOf(options), parts })[0] ?? this.at(this.size - 1);
	}

	/** Adds text as one entry per line. */
	writeLines(text: string, options: WriteOptions = {}): LogEntry[] {
		const parser =
			options.ansi instanceof AnsiParser ? options.ansi : options.ansi ? new AnsiParser() : null;
		const base = this.initOf(options);

		return this.append(
			splitLines(text).map((line) => ({
				...base,
				parts: this.textParts(line, { ...options, ansi: parser ?? false })
			}))
		);
	}

	/** Removes every entry. */
	clear(): void {
		this.items = [];
		this.start = 0;
		this.oldestId = this.nextId;
		this.lastSignature = null;
		this.emit({ type: 'clear' });
	}

	/** Collapses or expands a group header and hides or shows its members. */
	setCollapsed(id: number, collapsed: boolean): void {
		const entry = this.get(id);

		if (!entry || entry.collapsed === collapsed) {
			return;
		}

		entry.collapsed = collapsed;
		entry.version++;
		this.emit({ type: 'update', entry });
	}

	/** Calls a listener for every change. Returns a function that removes the listener. */
	subscribe(listener: StoreListener): () => void {
		this.listeners.add(listener);

		return () => {
			this.listeners.delete(listener);
		};
	}

	private initOf(options: WriteOptions): Omit<LogEntryInit, 'parts'> {
		return { level: options.level, kind: options.kind, time: options.time, groups: options.groups };
	}

	private textParts(text: string, options: WriteOptions): LogPart[] {
		if (options.ansi) {
			const parser = options.ansi instanceof AnsiParser ? options.ansi : new AnsiParser();

			return parser.parse(text).map((part) => ({
				...part,
				token: part.token ?? options.token,
				...(options.wrap === false ? { wrap: false } : {})
			}));
		}

		return [
			{
				type: 'text',
				text,
				token: options.token,
				style: options.style,
				...(options.wrap === false ? { wrap: false } : {})
			}
		];
	}

	private trimToLimit(): void {
		const excess = this.size - this.options.maxEntries;

		if (!(excess > 0)) {
			return;
		}

		this.start += excess;
		this.oldestId += excess;

		if (this.start > COMPACT_THRESHOLD && this.start > this.items.length / 2) {
			this.items = this.items.slice(this.start);
			this.start = 0;
		}

		if (this.size === 0) {
			this.lastSignature = null;
		}

		this.emit({ type: 'trim', count: excess });
	}

	private emit(change: StoreChange): void {
		for (const listener of this.listeners) {
			listener(change);
		}
	}
}
