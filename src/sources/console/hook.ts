import type { LogStore } from '../../core/store.js';
import {
	CONSOLE_METHODS,
	ConsoleRecorder,
	type ConsoleMethod,
	type RecorderOptions
} from './recorder.js';

export interface HookConsoleOptions extends Partial<RecorderOptions> {
	/** The methods to hook. Defaults to every method in `CONSOLE_METHODS`. */
	methods?: readonly ConsoleMethod[];
	/** Whether the original method still runs, so messages keep reaching the browser console. */
	passthrough?: boolean;
}

/** An object with the console methods lognal records. */
export type LognalConsole = { [Method in ConsoleMethod]: (...args: unknown[]) => void };

type ConsoleLike = Record<string, unknown>;
type StackCapture = (target: object, constructorOpt?: (...args: never[]) => unknown) => void;

const FRAME_V8 = /^\s+at\s/;
const FRAME_OTHER = /@/;

/** Removes the lines before the first stack frame, such as V8's `Error` header. */
const framesOnly = (stack: string): string[] => {
	const lines = stack.split('\n');
	const first = lines.findIndex((line) => FRAME_V8.test(line) || FRAME_OTHER.test(line));

	return first < 0 ? [] : lines.slice(first);
};

/**
 * Returns the stack trace of the code that called `wrapper`, without the frames of lognal
 * itself. V8 can leave those frames out on its own; elsewhere the first frame is dropped.
 */
const captureStack = (wrapper: (...args: never[]) => unknown): string => {
	const captureStackTrace = (Error as unknown as { captureStackTrace?: StackCapture })
		.captureStackTrace;

	if (typeof captureStackTrace === 'function') {
		const holder: { stack?: string } = {};

		captureStackTrace(holder, wrapper);

		return framesOnly(holder.stack ?? '').join('\n');
	}

	return framesOnly(new Error().stack ?? '')
		.slice(2)
		.join('\n');
};

/**
 * Replaces the methods of a console so every call is also recorded in a store.
 *
 * Returns a function that restores the original methods. If another script wrapped a method
 * after lognal did, that method is left in place and lognal's wrapper stops recording.
 *
 * A call is recorded before the original method runs, and an error while recording never
 * reaches the page.
 */
export const hookConsole = (
	target: Console,
	store: LogStore,
	options: HookConsoleOptions = {}
): (() => void) => {
	const { methods = CONSOLE_METHODS, passthrough = true, ...recorderOptions } = options;
	const recorder = new ConsoleRecorder(store, recorderOptions);
	const console = target as unknown as ConsoleLike;
	const installed = new Map<ConsoleMethod, { original: unknown; wrapper: unknown }>();
	let active = true;
	let recording = false;

	for (const method of methods) {
		if (installed.has(method)) {
			continue;
		}

		const original = console[method];
		const wrapper = function (this: unknown, ...args: unknown[]): unknown {
			if (active && !recording) {
				recording = true;

				try {
					recorder.record(method, args, method === 'trace' ? captureStack(wrapper) : undefined);
				} catch {
					// Recording must never break the page that logged the message.
				} finally {
					recording = false;
				}
			}

			if (passthrough && typeof original === 'function') {
				return original.apply(this, args);
			}

			return undefined;
		};

		console[method] = wrapper;
		installed.set(method, { original, wrapper });
	}

	return () => {
		if (!active) {
			return;
		}

		active = false;

		for (const [method, { original, wrapper }] of installed) {
			if (console[method] === wrapper) {
				console[method] = original;
			}
		}
	};
};

/**
 * Creates an object with the console methods that records into a store without touching the
 * global console. Use it to write to a viewer from your own code.
 */
export const createConsole = (
	store: LogStore,
	options: Partial<RecorderOptions> = {}
): LognalConsole => {
	const recorder = new ConsoleRecorder(store, options);
	const result = {} as LognalConsole;

	for (const method of CONSOLE_METHODS) {
		const call = (...args: unknown[]): void => {
			recorder.record(method, args, method === 'trace' ? captureStack(call) : undefined);
		};

		result[method] = call;
	}

	return result;
};
