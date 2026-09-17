import type { LogStore } from '../../core/store.js';
import { AnsiParser } from '../../core/text/ansi.js';
import { LineSplitter } from '../../core/text/line-splitter.js';
import type { LogEntryInit, LogLevel } from '../../core/types.js';
import { detectEncoding, legacyEncodingFor } from './encoding.js';

export interface ReadTextOptions {
	/**
	 * The encoding of the file, such as `utf-8` or `euc-kr`. `auto` reads the byte order mark,
	 * then tries UTF-8, then falls back to `fallbackEncoding`.
	 */
	encoding?: string;
	/**
	 * The encoding used by `auto` when the file is not UTF-8. Defaults to the legacy encoding of
	 * the browser language, such as `euc-kr` for Korean.
	 */
	fallbackEncoding?: string;
	/** The level of every line. */
	level?: LogLevel;
	/** Whether ANSI escape codes become styles. Defaults to `true`. */
	ansi?: boolean;
	/** Bytes read at a time. */
	chunkSize?: number;
	/** Stops reading when aborted. The lines read so far stay in the store. */
	signal?: AbortSignal;
	/** Called after every chunk with the bytes read so far and the total size. */
	onProgress?: (loaded: number, total: number) => void;
}

export interface ReadTextResult {
	/** The number of lines added. */
	lines: number;
	/** The number of bytes read. */
	bytes: number;
	/** The encoding used. */
	encoding: string;
}

const DEFAULT_CHUNK_SIZE = 256 * 1024;
const DETECTION_BYTES = 64 * 1024;

const browserLanguage = (): string | undefined => {
	return (globalThis as { navigator?: { language?: string } }).navigator?.language;
};

/**
 * Turns decoded text into store entries one line at a time, keeping partial lines and the ANSI
 * style between chunks.
 */
export class TextLineWriter {
	private readonly splitter = new LineSplitter();
	private readonly parser: AnsiParser | null;
	private count = 0;

	constructor(
		private readonly store: LogStore,
		private readonly options: { level?: LogLevel; ansi?: boolean } = {}
	) {
		this.parser = options.ansi === false ? null : new AnsiParser();
	}

	/** The number of lines written. */
	get lines(): number {
		return this.count;
	}

	/** Whether an unfinished line is waiting for its line break. */
	get hasPending(): boolean {
		return this.splitter.hasPending;
	}

	write(text: string): void {
		this.add(this.splitter.push(text));
	}

	/** Writes the unfinished last line, if any. */
	flush(): void {
		this.add(this.splitter.flush());
	}

	private add(lines: string[]): void {
		if (lines.length === 0) {
			return;
		}

		const level = this.options.level ?? 'log';
		const entries: LogEntryInit[] = lines.map((line) => ({
			level,
			parts: this.parser ? this.parser.parse(line) : [{ type: 'text', text: line }]
		}));

		this.store.append(entries);
		this.count += lines.length;
	}
}

/**
 * Reads a text file, such as one picked with `<input type="file">` or dropped on the page, and
 * adds one entry per line.
 *
 * The file is read in chunks, so a large file does not have to fit in memory as one string.
 * The store's `maxEntries` still decides how many lines are kept.
 */
export const readTextFile = async (
	file: Blob,
	store: LogStore,
	options: ReadTextOptions = {}
): Promise<ReadTextResult> => {
	const chunkSize = options.chunkSize ?? DEFAULT_CHUNK_SIZE;
	const head = new Uint8Array(await file.slice(0, DETECTION_BYTES).arrayBuffer());
	const requested = options.encoding ?? 'auto';
	const encoding =
		requested === 'auto'
			? detectEncoding(head, options.fallbackEncoding ?? legacyEncodingFor(browserLanguage()))
			: requested;
	const decoder = new TextDecoder(encoding);
	const writer = new TextLineWriter(store, { level: options.level, ansi: options.ansi });
	let offset = 0;

	while (offset < file.size) {
		if (options.signal?.aborted) {
			break;
		}

		const end = Math.min(file.size, offset + chunkSize);
		const bytes = new Uint8Array(await file.slice(offset, end).arrayBuffer());

		writer.write(decoder.decode(bytes, { stream: true }));
		offset = end;
		options.onProgress?.(offset, file.size);
	}

	writer.write(decoder.decode());
	writer.flush();

	return { lines: writer.lines, bytes: offset, encoding };
};
