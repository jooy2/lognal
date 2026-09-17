import type { LogStore } from '../../core/store.js';
import type { LogLevel } from '../../core/types.js';
import { detectEncoding, legacyEncodingFor } from './encoding.js';
import { TextLineWriter } from './read-file.js';

/** The part of `FileSystemFileHandle` that following a file needs. */
export interface FileHandleLike {
	getFile(): Promise<Blob & { lastModified?: number }>;
}

export interface FollowTextOptions {
	/** Milliseconds between checks for new data. */
	interval?: number;
	/** The encoding, or `auto` to detect it from the first bytes. */
	encoding?: string;
	/** The encoding `auto` falls back to when the file is not UTF-8. */
	fallbackEncoding?: string;
	/** The level of every line. */
	level?: LogLevel;
	/** Whether ANSI escape codes become styles. Defaults to `true`. */
	ansi?: boolean;
	/**
	 * Called when the file was replaced rather than appended to: it got shorter, or it kept its
	 * size but was modified. The file is then read again from the start.
	 */
	onReset?: () => void;
	/** Called when reading fails, for example because permission was withdrawn. */
	onError?: (error: unknown) => void;
}

/** Controls a followed file. */
export interface FollowHandle {
	/** Stops checking the file and writes any unfinished last line. */
	stop(): void;
	/**
	 * Resolves after the first read with the number of lines it added, or rejects when the first
	 * read fails. Checking goes on either way; later failures go to `onError`.
	 */
	ready: Promise<number>;
}

const DEFAULT_INTERVAL = 1000;

const browserLanguage = (): string | undefined => {
	return (globalThis as { navigator?: { language?: string } }).navigator?.language;
};

/**
 * Reads a file and keeps adding the lines appended to it, like `tail -f`.
 *
 * This needs a file handle from the File System Access API (`showOpenFilePicker`), which only
 * Chromium-based browsers provide. Every check asks the handle for a fresh copy of the file
 * and reads what was added since the last one. A file picked with `<input type="file">` is a
 * snapshot that cannot be followed; read it once with `readTextFile` instead.
 *
 * When the file gets shorter, or keeps its size but changes, it was replaced rather than
 * appended to, so it is read again from the start and `onReset` is called.
 */
export const followTextFile = (
	handle: FileHandleLike,
	store: LogStore,
	options: FollowTextOptions = {}
): FollowHandle => {
	const interval = options.interval ?? DEFAULT_INTERVAL;
	const writerOptions = { level: options.level, ansi: options.ansi };
	let writer = new TextLineWriter(store, writerOptions);
	let decoder: TextDecoder | null = null;
	let offset = 0;
	let lastModified: number | undefined;
	let stopped = false;
	let timer: ReturnType<typeof setTimeout> | undefined;
	let settleReady: { resolve: (lines: number) => void; reject: (error: unknown) => void } | null =
		null;

	const ready = new Promise<number>((resolve, reject) => {
		settleReady = { resolve, reject };
	});

	// A caller that never awaits `ready` should not see an unhandled rejection.
	ready.catch(() => undefined);

	const reset = (): void => {
		writer.write(decoder?.decode() ?? '');
		writer.flush();
		writer = new TextLineWriter(store, writerOptions);
		decoder = null;
		offset = 0;
		options.onReset?.();
	};

	const check = async (): Promise<void> => {
		const file = await handle.getFile();

		if (stopped) {
			return;
		}

		const replaced =
			file.size < offset ||
			(file.size === offset &&
				offset > 0 &&
				file.lastModified !== undefined &&
				lastModified !== undefined &&
				file.lastModified !== lastModified);

		lastModified = file.lastModified;

		if (replaced) {
			reset();
		}

		if (file.size === offset) {
			return;
		}

		const bytes = new Uint8Array(await file.slice(offset).arrayBuffer());

		if (stopped) {
			return;
		}

		if (!decoder) {
			const requested = options.encoding ?? 'auto';
			const encoding =
				requested === 'auto'
					? detectEncoding(bytes, options.fallbackEncoding ?? legacyEncodingFor(browserLanguage()))
					: requested;

			decoder = new TextDecoder(encoding);
		}

		writer.write(decoder.decode(bytes, { stream: true }));
		offset += bytes.byteLength;
	};

	const loop = async (): Promise<void> => {
		if (stopped) {
			return;
		}

		try {
			await check();
			settleReady?.resolve(writer.lines);
		} catch (error) {
			if (settleReady) {
				settleReady.reject(error);
			} else {
				options.onError?.(error);
			}
		}

		settleReady = null;

		if (!stopped) {
			timer = setTimeout(() => {
				void loop();
			}, interval);
		}
	};

	void loop();

	return {
		ready,
		stop: () => {
			if (stopped) {
				return;
			}

			stopped = true;
			clearTimeout(timer);
			writer.write(decoder?.decode() ?? '');
			writer.flush();
		}
	};
};
