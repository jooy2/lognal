import { describe, expect, it } from 'vitest';
import { LogStore } from '../../src/core/store.ts';
import type { ValueNode } from '../../src/core/types.ts';
import { formatEntryText, formatValueText } from '../../src/core/value/text.ts';
import { createConsole } from '../../src/sources/console/hook.ts';
import { snapshotValue } from '../../src/sources/console/snapshot.ts';

const text = (value: unknown): string => formatValueText(snapshotValue(value));

describe('formatValueText', () => {
	it('writes a short object on one line and a long one over several', () => {
		expect(text({ id: 1, name: 'Ada' })).toBe("{ id: 1, name: 'Ada' }");
		expect(
			text({
				id: 1,
				name: 'Ada',
				roles: ['admin', 'editor'],
				profile: { city: 'Seoul', zip: '04524', verified: true }
			})
		).toBe(
			[
				'{',
				'  id: 1,',
				"  name: 'Ada',",
				"  roles: ['admin', 'editor'],",
				"  profile: { city: 'Seoul', zip: '04524', verified: true }",
				'}'
			].join('\n')
		);
	});

	it('writes class names, maps, sets, typed arrays and empty containers', () => {
		class Account {
			id = 7;
		}

		expect(text(new Account())).toBe('Account { id: 7 }');
		expect(
			text(
				new Map<string, unknown>([
					['status', 200],
					['headers', { 'content-type': 'application/json' }]
				])
			)
		).toBe(
			[
				'Map(2) {',
				"  'status' => 200,",
				"  'headers' => { 'content-type': 'application/json' }",
				'}'
			].join('\n')
		);
		expect(text(new Set(['x', 'y']))).toBe("Set(2) { 'x', 'y' }");
		expect(text(new Uint8Array([1, 2]))).toBe('Uint8Array(2) [1, 2]');
		expect(text({})).toBe('{}');
		expect(text([])).toBe('[]');
	});

	it('writes leaves the way previews do, with strings in full', () => {
		const long = 'x'.repeat(60);

		expect(text([undefined, null, -0, 10n, Symbol('token'), /ab+c/gi])).toBe(
			'[undefined, null, -0, 10n, Symbol(token), /ab+c/gi]'
		);
		expect(text({ long })).toBe(`{ long: '${long}' }`);
		expect(text({ quote: "it's\nhere" })).toBe("{ quote: 'it\\'s\\nhere' }");
		// Symbol keys come after string keys, in the order `Reflect.ownKeys` returns them.
		expect(text({ [Symbol('id')]: 1, 'with space': true })).toBe(
			"{ 'with space': true, [Symbol(id)]: 1 }"
		);
	});

	it('marks what the snapshot left out', () => {
		const node: ValueNode = snapshotValue({ deep: { deeper: { list: [1, 2] } } }, { maxDepth: 2 });
		const circular: Record<string, unknown> = {};

		circular.self = circular;

		expect(formatValueText(node)).toBe('{ deep: { deeper: {…} } }');
		expect(text(circular)).toBe('{ self: [Circular] }');
		expect(formatValueText(snapshotValue([1, 2, 3], { maxProperties: 2 }))).toBe(
			'[1, 2, … 1 more]'
		);
		expect(
			formatValueText(
				snapshotValue({
					get value() {
						return 1;
					}
				})
			)
		).toBe('{ value: [Getter] }');
	});

	it('writes an error with its stack trace and its properties', () => {
		const node: ValueNode = {
			kind: 'error',
			className: 'Error',
			value: 'Failed to load',
			stack: '    at load (app.js:1:1)\n    at run (app.js:2:1)',
			children: [
				{
					key: 'cause',
					keyKind: 'property',
					value: { kind: 'error', className: 'TypeError', value: 'Expected a string' }
				}
			]
		};

		expect(formatValueText(node)).toBe(
			[
				'Error: Failed to load',
				'    at load (app.js:1:1)',
				'    at run (app.js:2:1) { cause: TypeError: Expected a string }'
			].join('\n')
		);
		expect(formatValueText({ kind: 'object', children: [{ key: 'error', value: node }] })).toBe(
			[
				'{',
				'  error: Error: Failed to load',
				'      at load (app.js:1:1)',
				'      at run (app.js:2:1) { cause: TypeError: Expected a string }',
				'}'
			].join('\n')
		);
	});

	it('writes an element as markup', () => {
		const link: ValueNode = {
			kind: 'element',
			value: 'a',
			attributes: [['href', '/']],
			children: [{ value: { kind: 'text', value: 'Home' } }]
		};
		const nav: ValueNode = {
			kind: 'element',
			value: 'nav',
			attributes: [['class', 'menu']],
			children: [{ value: link }, { value: { ...link, children: undefined } }]
		};

		expect(formatValueText(link)).toBe('<a href="/">Home</a>');
		expect(
			formatValueText({ kind: 'element', value: 'input', attributes: [['type', 'file']] })
		).toBe('<input type="file">');
		expect(formatValueText(nav)).toBe(
			['<nav class="menu">', '  <a href="/">Home</a>', '  <a href="/">…</a>', '</nav>'].join('\n')
		);
	});
});

describe('formatEntryText', () => {
	it('joins the text and the values of a console call', () => {
		const store = new LogStore();
		const log = createConsole(store);

		log.log('user', { id: 1 }, 'signed in');

		expect(formatEntryText(store.at(0)!)).toBe('user { id: 1 } signed in');
	});
});
