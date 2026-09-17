import { describe, expect, it, vi } from 'vitest';
import { LogStore } from '../../src/core/store.ts';
import type { LogEntry, LogPart, ValueNode } from '../../src/core/types.ts';
import {
	applyFormat,
	formatArguments,
	isSafeColor,
	parseConsoleCss
} from '../../src/sources/console/format.ts';
import { createConsole, hookConsole } from '../../src/sources/console/hook.ts';
import { snapshotValue } from '../../src/sources/console/snapshot.ts';

const capture = (value: unknown): ValueNode => snapshotValue(value);

const textOf = (parts: readonly LogPart[]): string => {
	return parts.map((part) => (part.type === 'text' ? part.text : `<${part.value.kind}>`)).join('');
};

const lastEntry = (store: LogStore): LogEntry => {
	return store.at(store.size - 1) as LogEntry;
};

describe('snapshotValue', () => {
	it('captures primitives the way they print', () => {
		expect(snapshotValue(-0)).toEqual({ kind: 'number', value: '-0' });
		expect(snapshotValue(10n)).toEqual({ kind: 'bigint', value: '10' });
		expect(snapshotValue(Symbol('token'))).toEqual({ kind: 'symbol', value: 'Symbol(token)' });
		expect(snapshotValue(undefined)).toEqual({ kind: 'undefined' });
	});

	it('takes the value at call time', () => {
		const user = { name: 'before' };
		const node = snapshotValue(user);

		user.name = 'after';

		expect(node.children?.[0].value.value).toBe('before');
	});

	it('never runs getters', () => {
		const getter = vi.fn(() => 'secret');
		const value = Object.defineProperty({}, 'lazy', { get: getter, enumerable: true });
		const node = snapshotValue(value);

		expect(getter).not.toHaveBeenCalled();
		expect(node.children?.[0].value).toEqual({ kind: 'accessor', accessor: 'get' });
	});

	it('marks circular references', () => {
		const value: Record<string, unknown> = {};

		value.self = value;

		expect(snapshotValue(value).children?.[0].value.kind).toBe('circular');
	});

	it('respects the depth, property, string and node limits', () => {
		const deep = { a: { b: { c: { d: 1 } } } };
		const wide = Object.fromEntries(
			Array.from({ length: 10 }, (_, index) => [`key${index}`, index])
		);
		const depthNode = snapshotValue(deep, { maxDepth: 2 });
		const inner = depthNode.children?.[0].value.children?.[0].value;

		expect(inner?.kind).toBe('object');
		expect(inner?.children).toBeUndefined();
		expect(snapshotValue(wide, { maxProperties: 3 })).toMatchObject({ omitted: 7 });
		expect(snapshotValue('x'.repeat(20), { maxStringLength: 5 })).toMatchObject({
			value: 'xxxxx',
			truncated: 15
		});
		expect(
			snapshotValue(
				Array.from({ length: 50 }, () => ({ x: 1 })),
				{ maxNodes: 10 }
			).children?.length
		).toBeLessThan(10);
	});

	it('recognizes built-in types', () => {
		expect(snapshotValue(new Date(0))).toEqual({ kind: 'date', value: '1970-01-01T00:00:00.000Z' });
		expect(snapshotValue(/a+b/gi)).toEqual({ kind: 'regexp', value: '/a+b/gi' });
		expect(snapshotValue(new Map([['a', 1]]))).toMatchObject({
			kind: 'map',
			size: 1,
			className: 'Map'
		});
		expect(snapshotValue(new Set([1, 2]))).toMatchObject({ kind: 'set', size: 2 });
		expect(snapshotValue(new Uint8Array([1, 2, 3]))).toMatchObject({
			kind: 'array',
			className: 'Uint8Array',
			size: 3
		});
		expect(snapshotValue(new WeakMap())).toEqual({ kind: 'weak', className: 'WeakMap' });
		expect(snapshotValue(class Example {})).toEqual({ kind: 'class', value: 'Example' });
		expect(snapshotValue(function named() {})).toEqual({ kind: 'function', value: 'named' });
	});

	it('keeps the class name of an instance', () => {
		class User {
			name = 'lognal';
		}

		expect(snapshotValue(new User())).toMatchObject({ kind: 'object', className: 'User' });
	});

	it('captures errors with their cause and without the stack header', () => {
		const error = new TypeError('broken', { cause: new Error('root') });
		const node = snapshotValue(error);

		expect(node).toMatchObject({ kind: 'error', className: 'TypeError', value: 'broken' });
		expect(node.stack?.startsWith('TypeError')).toBe(false);
		expect(node.children?.find((child) => child.key === 'cause')?.value).toMatchObject({
			kind: 'error',
			value: 'root'
		});
	});

	it('survives a proxy whose traps throw', () => {
		const hostile = new Proxy(
			{},
			{
				ownKeys: () => {
					throw new Error('no keys');
				}
			}
		);

		expect(() => snapshotValue(hostile)).not.toThrow();
	});
});

describe('format specifiers', () => {
	it('applies %s, %d, %i and %f with the Console Standard conversions', () => {
		const { parts, rest } = applyFormat(
			['%s|%d|%i|%f|%%', 'text', '42.9', -1.5, '3.25', 'extra'],
			capture
		);

		expect(textOf(parts)).toBe('text|42|-1|3.25|%');
		expect(rest).toEqual(['extra']);
	});

	it('inserts values for %o and %O and leaves specifiers without arguments as written', () => {
		const { parts } = applyFormat(['a %o b %O c %s', { x: 1 }, [1]], capture);

		expect(textOf(parts)).toBe('a <object> b <array> c %s');
	});

	it('styles the text after %c with the allowed properties only', () => {
		const { parts } = applyFormat(
			[
				'%cred%c plain',
				'color: red; background: url(https://example.com/x.png) #000; font-weight: bold',
				''
			],
			capture
		);

		expect(parts[0]).toEqual({
			type: 'text',
			text: 'red',
			style: { color: 'red', background: '#000', bold: true }
		});
		expect(parts[1]).toEqual({ type: 'text', text: ' plain' });
	});

	it('rejects colors that could load a resource', () => {
		expect(isSafeColor('rgb(1 2 3 / 50%)')).toBe(true);
		expect(isSafeColor('url(x)')).toBe(false);
		expect(parseConsoleCss('color: url(x)')).toBeUndefined();
	});

	it('joins the remaining arguments with spaces', () => {
		expect(textOf(formatArguments(['count', 3, 'items'], capture))).toBe('count <number> items');
		expect(textOf(formatArguments(['%d%%', 50, 'done'], capture))).toBe('50% done');
		expect(textOf(formatArguments(['only %s'], capture))).toBe('only %s');
	});
});

describe('console recorder', () => {
	it('records levels and group membership', () => {
		const store = new LogStore();
		const log = createConsole(store);

		log.group('outer');
		log.warn('inside');
		log.groupEnd();
		log.error('outside');

		const [group, inside, outside] = store.toArray();

		expect(group).toMatchObject({ kind: 'group', collapsed: false });
		expect(inside).toMatchObject({ level: 'warn', groups: [group.id] });
		expect(outside).toMatchObject({ level: 'error', groups: [] });
	});

	it('counts, resets counts and warns about a missing counter', () => {
		const store = new LogStore({ mergeRepeats: false });
		const log = createConsole(store);

		log.count('clicks');
		log.count('clicks');
		log.countReset('clicks');
		log.count('clicks');
		log.countReset('other');

		expect(store.toArray().map((entry) => textOf(entry.parts))).toEqual([
			'clicks: 1',
			'clicks: 2',
			'clicks: 1',
			"Count for 'other' does not exist"
		]);
	});

	it('measures timers at call time', () => {
		const store = new LogStore();
		const log = createConsole(store);
		const now = vi.spyOn(performance, 'now');

		now.mockReturnValue(1000);
		log.time('load');
		now.mockReturnValue(1250.5);
		log.timeLog('load', 'halfway');
		log.timeEnd('load');
		log.timeEnd('load');
		now.mockRestore();

		expect(store.toArray().map((entry) => textOf(entry.parts))).toEqual([
			'load: 250.5 ms halfway',
			'load: 250.5 ms',
			"Timer 'load' does not exist"
		]);
	});

	it('writes assertion failures the way the standard describes', () => {
		const store = new LogStore({ mergeRepeats: false });
		const log = createConsole(store);

		log.assert(true, 'not shown');
		log.assert(false);
		log.assert(false, 'value is %d', 3);
		log.assert(false, { code: 1 });

		expect(store.toArray().map((entry) => textOf(entry.parts))).toEqual([
			'Assertion failed',
			'Assertion failed: value is 3',
			'Assertion failed <object>'
		]);
	});

	it('draws console.table as a text table that lines up wide characters', () => {
		const store = new LogStore();

		createConsole(store).table([{ name: '김철수', age: 30 }, { name: 'Ann' }]);

		const lines = textOf(lastEntry(store).parts).split('\n');
		const widths = new Set(
			lines.map((line) =>
				[...line].reduce((sum, character) => sum + (/[가-힣]/.test(character) ? 2 : 1), 0)
			)
		);

		expect(lines[1]).toContain('(index)');
		expect(widths.size).toBe(1);
	});

	it('clears the store and notes it', () => {
		const store = new LogStore();
		const log = createConsole(store);

		log.log('before');
		log.clear();

		expect(store.size).toBe(1);
		expect(lastEntry(store)).toMatchObject({ kind: 'system' });
	});

	it('adds the stack of console.trace', () => {
		const store = new LogStore();

		createConsole(store).trace('here');

		const text = textOf(lastEntry(store).parts);

		expect(text.startsWith('here\n')).toBe(true);
		expect(text).toContain('console.test.ts');
	});
});

describe('hookConsole', () => {
	const fakeConsole = () => {
		const calls: unknown[][] = [];
		const target = {
			log: (...args: unknown[]) => calls.push(args),
			warn: (...args: unknown[]) => calls.push(args)
		};

		return { target: target as unknown as Console, calls };
	};

	it('records calls, still runs the original and restores it', () => {
		const { target, calls } = fakeConsole();
		const original = target.log;
		const store = new LogStore();
		const unhook = hookConsole(target, store, { methods: ['log'] });

		target.log('hello', 1);
		unhook();
		target.log('after');

		expect(calls).toEqual([['hello', 1], ['after']]);
		expect(store.size).toBe(1);
		expect(target.log).toBe(original);
	});

	it('does not break the page when recording fails', () => {
		const { target } = fakeConsole();
		const store = new LogStore();

		vi.spyOn(store, 'append').mockImplementation(() => {
			throw new Error('store failure');
		});
		hookConsole(target, store, { methods: ['log'] });

		expect(() => target.log('still fine')).not.toThrow();
	});

	it('leaves a later wrapper in place and stops recording', () => {
		const { target } = fakeConsole();
		const store = new LogStore();
		const unhook = hookConsole(target, store, { methods: ['log'] });
		const ours = target.log;
		const later = (...args: unknown[]) => ours(...args);

		target.log = later;
		unhook();
		target.log('ignored');

		expect(target.log).toBe(later);
		expect(store.size).toBe(0);
	});

	it('can skip the original method', () => {
		const { target, calls } = fakeConsole();

		hookConsole(target, new LogStore(), { methods: ['warn'], passthrough: false });
		target.warn('quiet');

		expect(calls).toEqual([]);
	});
});
