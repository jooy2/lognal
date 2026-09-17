import type { LogStore } from '../../core/store.js';
import type { LogEntryInit, LogKind, LogLevel, LogPart } from '../../core/types.js';
import { formatArguments } from './format.js';
import { DEFAULT_CAPTURE_OPTIONS, snapshotValue, type CaptureOptions } from './snapshot.js';
import { formatTable } from './table.js';

/** The console methods lognal records. */
export type ConsoleMethod =
	| 'log'
	| 'info'
	| 'warn'
	| 'error'
	| 'debug'
	| 'trace'
	| 'dir'
	| 'dirxml'
	| 'table'
	| 'group'
	| 'groupCollapsed'
	| 'groupEnd'
	| 'count'
	| 'countReset'
	| 'time'
	| 'timeLog'
	| 'timeEnd'
	| 'assert'
	| 'clear';

export const CONSOLE_METHODS: readonly ConsoleMethod[] = [
	'log',
	'info',
	'warn',
	'error',
	'debug',
	'trace',
	'dir',
	'dirxml',
	'table',
	'group',
	'groupCollapsed',
	'groupEnd',
	'count',
	'countReset',
	'time',
	'timeLog',
	'timeEnd',
	'assert',
	'clear'
];

export interface RecorderOptions extends CaptureOptions {
	/** Whether `console.clear` removes the entries from the store. */
	clearStore: boolean;
}

export const DEFAULT_RECORDER_OPTIONS: RecorderOptions = {
	...DEFAULT_CAPTURE_OPTIONS,
	clearStore: true
};

const DEFAULT_LABEL = 'default';

const now = (): number => {
	return typeof performance !== 'undefined' ? performance.now() : Date.now();
};

const labelOf = (value: unknown): string => {
	return value === undefined ? DEFAULT_LABEL : String(value);
};

const formatDuration = (milliseconds: number): string => {
	return `${Number(milliseconds.toFixed(3))} ms`;
};

const text = (value: string, extra: Partial<LogPart> = {}): LogPart => {
	return { type: 'text', text: value, ...extra } as LogPart;
};

/**
 * Turns console calls into store entries.
 *
 * A recorder keeps the state the Console Standard gives a console: the count map, the timer
 * table and the group stack. Everything is captured synchronously, when the method is called.
 */
export class ConsoleRecorder {
	private options: RecorderOptions;
	private readonly counts = new Map<string, number>();
	private readonly timers = new Map<string, number>();
	private groups: number[] = [];

	constructor(
		private readonly store: LogStore,
		options: Partial<RecorderOptions> = {}
	) {
		this.options = { ...DEFAULT_RECORDER_OPTIONS, ...options };
	}

	setOptions(options: Partial<RecorderOptions>): void {
		this.options = { ...this.options, ...options };
	}

	/**
	 * Records one call. `stack` is the caller's stack trace, which only `trace` uses.
	 */
	record(method: ConsoleMethod, args: readonly unknown[], stack?: string): void {
		switch (method) {
			case 'log':
			case 'info':
			case 'warn':
			case 'error':
			case 'debug':
				this.add(method, formatArguments(args, this.capture));
				break;
			case 'dir':
				this.add('log', [{ type: 'value', value: this.capture(args[0]) }]);
				break;
			case 'dirxml':
				this.add(
					'log',
					args.length > 0
						? args.flatMap((value, index): LogPart[] => [
								...(index > 0 ? [text(' ')] : []),
								{ type: 'value', value: this.capture(value) }
							])
						: [text('undefined', { token: 'null' })]
				);
				break;
			case 'trace':
				this.trace(args, stack);
				break;
			case 'table':
				this.table(args);
				break;
			case 'group':
			case 'groupCollapsed':
				this.group(args, method === 'groupCollapsed');
				break;
			case 'groupEnd':
				this.groups = this.groups.slice(0, -1);
				break;
			case 'count':
				this.count(args[0]);
				break;
			case 'countReset':
				this.countReset(args[0]);
				break;
			case 'time':
				this.time(args[0]);
				break;
			case 'timeLog':
				this.timeLog(args[0], args.slice(1));
				break;
			case 'timeEnd':
				this.timeEnd(args[0]);
				break;
			case 'assert':
				this.assert(args);
				break;
			case 'clear':
				this.clear();
				break;
			default:
				break;
		}
	}

	private readonly capture = (value: unknown) => {
		return snapshotValue(value, this.options);
	};

	private add(
		level: LogLevel,
		parts: LogPart[],
		kind: LogKind = 'message',
		init: Partial<LogEntryInit> = {}
	): void {
		this.store.append({ level, kind, parts, groups: [...this.groups], ...init });
	}

	private trace(args: readonly unknown[], stack?: string): void {
		const parts: LogPart[] =
			args.length > 0 ? formatArguments(args, this.capture) : [text('console.trace')];

		if (stack) {
			const frames = stack
				.split('\n')
				.map((frame) => frame.trim())
				.filter(Boolean)
				.map((frame) => `    ${frame}`)
				.join('\n');

			parts.push(text(`\n${frames}`, { token: 'muted' }));
		}

		this.add('log', parts);
	}

	private table(args: readonly unknown[]): void {
		const [data, properties] = args;

		if (data === null || typeof data !== 'object') {
			this.add('log', formatArguments(args, this.capture));

			return;
		}

		const node = snapshotValue(data, { ...this.options, maxDepth: 2 });
		const columns = Array.isArray(properties) ? properties.map((key) => String(key)) : undefined;
		const table = formatTable(node, columns);

		// A table keeps its rows whole; a table wider than the viewer scrolls sideways.
		this.add(
			'log',
			table === null ? [{ type: 'value', value: node }] : [text(table, { wrap: false })]
		);
	}

	private group(args: readonly unknown[], collapsed: boolean): void {
		const parts =
			args.length > 0
				? formatArguments(args, this.capture).map((part) =>
						part.type === 'text' ? { ...part, style: { ...part.style, bold: true } } : part
					)
				: [text(collapsed ? 'console.groupCollapsed' : 'console.group', { style: { bold: true } })];
		const [entry] = this.store.append({
			level: 'log',
			kind: 'group',
			parts,
			groups: [...this.groups],
			collapsed
		});

		if (entry) {
			this.groups = [...this.groups, entry.id];
		}
	}

	private count(label: unknown): void {
		const key = labelOf(label);
		const count = (this.counts.get(key) ?? 0) + 1;

		this.counts.set(key, count);
		this.add('info', [text(`${key}: ${count}`)]);
	}

	private countReset(label: unknown): void {
		const key = labelOf(label);

		if (this.counts.has(key)) {
			this.counts.set(key, 0);
		} else {
			this.add('warn', [text(`Count for '${key}' does not exist`)]);
		}
	}

	private time(label: unknown): void {
		const key = labelOf(label);

		if (this.timers.has(key)) {
			this.add('warn', [text(`Timer '${key}' already exists`)]);

			return;
		}

		this.timers.set(key, now());
	}

	private timeLog(label: unknown, data: readonly unknown[]): void {
		const key = labelOf(label);
		const start = this.timers.get(key);

		if (start === undefined) {
			this.add('warn', [text(`Timer '${key}' does not exist`)]);

			return;
		}

		const parts: LogPart[] = [text(`${key}: ${formatDuration(now() - start)}`)];

		for (const value of data) {
			parts.push(text(' '));
			parts.push(
				typeof value === 'string' ? text(value) : { type: 'value', value: this.capture(value) }
			);
		}

		this.add('log', parts);
	}

	private timeEnd(label: unknown): void {
		const key = labelOf(label);
		const start = this.timers.get(key);

		if (start === undefined) {
			this.add('warn', [text(`Timer '${key}' does not exist`)]);

			return;
		}

		this.timers.delete(key);
		this.add('info', [text(`${key}: ${formatDuration(now() - start)}`)]);
	}

	private assert(args: readonly unknown[]): void {
		const [condition, ...data] = args;

		if (condition) {
			return;
		}

		if (data.length === 0) {
			this.add('error', [text('Assertion failed')]);

			return;
		}

		if (typeof data[0] === 'string') {
			data[0] = `Assertion failed: ${data[0]}`;
		} else {
			data.unshift('Assertion failed');
		}

		this.add('error', formatArguments(data, this.capture));
	}

	private clear(): void {
		this.groups = [];

		if (this.options.clearStore) {
			this.store.clear();
		}

		this.add('log', [text('Console was cleared', { token: 'muted' })], 'system');
	}
}
