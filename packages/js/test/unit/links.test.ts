import { describe, expect, it } from 'vitest';
import { LogLayout } from '../../src/core/layout/layout.ts';
import { LogStore } from '../../src/core/store.ts';
import { findLinks } from '../../src/core/text/links.ts';
import type { ValueNode } from '../../src/core/types.ts';

const urls = (text: string): string[] => findLinks(text).map((link) => link.url);

describe('findLinks', () => {
	it('finds http and https addresses with their ranges', () => {
		const text = 'Docs at https://lognal.cdget.com/guide/ and HTTP://EXAMPLE.COM:8080/a?b=1#c';
		const links = findLinks(text);

		expect(links.map((link) => link.url)).toEqual([
			'https://lognal.cdget.com/guide/',
			'HTTP://EXAMPLE.COM:8080/a?b=1#c'
		]);

		for (const link of links) {
			expect(link.start).toBe(text.indexOf(link.url));
			expect(text.slice(link.start, link.end)).toBe(link.url);
		}
	});

	it('leaves out punctuation after an address and closing brackets without a pair', () => {
		expect(urls('See https://example.com/a.')).toEqual(['https://example.com/a']);
		expect(urls('(see https://example.com/page)')).toEqual(['https://example.com/page']);
		expect(urls('https://en.wikipedia.org/wiki/Mercury_(planet), then')).toEqual([
			'https://en.wikipedia.org/wiki/Mercury_(planet)'
		]);
		expect(urls("url: 'https://example.com/q?x=1'")).toEqual(['https://example.com/q?x=1']);
		expect(urls('<https://example.com/>')).toEqual(['https://example.com/']);
		expect(urls('문서는 https://example.com/한글 에 있습니다.')).toEqual([
			'https://example.com/한글'
		]);
		expect(urls('주소: https://example.com/문서。')).toEqual(['https://example.com/문서']);
	});

	it('ignores other schemes, a missing host and a scheme inside a word', () => {
		expect(urls('ftp://example.com javascript:alert(1) mailto:user@example.com')).toEqual([]);
		expect(urls('https:// and http:///path')).toEqual([]);
		expect(urls('xhttps://example.com')).toEqual([]);
	});

	it('ends an address before an invisible character and finds the address after it', () => {
		const override = String.fromCharCode(0x202e);
		const zeroWidthSpace = String.fromCharCode(0x200b);

		expect(urls(`https://example.com/${override}gpj.exe`)).toEqual(['https://example.com/']);
		expect(urls(`https://a.example${zeroWidthSpace}https://b.example`)).toEqual([
			'https://a.example',
			'https://b.example'
		]);
	});
});

describe('links in the layout', () => {
	it('gives every address in text an action that opens it', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);
		const entry = store.write('Open https://example.com/docs now');

		layout.sync();

		const [row] = layout.getRows(0, 1);

		expect(row.runs.map((run) => [run.text, run.action])).toEqual([
			['Open ', undefined],
			['https://example.com/docs', { type: 'open-link', url: 'https://example.com/docs' }],
			[' now', undefined]
		]);
		expect(layout.linksOf(entry!.id)).toEqual(['https://example.com/docs']);
	});

	it('keeps the rows when links are turned off, and lists each address once', () => {
		const store = new LogStore();
		const layout = new LogLayout(store, { wrap: 'char' });
		const entry = store.write(
			'https://example.com/a https://example.com/b https://example.com/a '.repeat(4)
		);

		layout.setColumns(40);
		layout.sync();

		const rows = layout.rowCount;

		expect(layout.linksOf(entry!.id)).toEqual(['https://example.com/a', 'https://example.com/b']);

		layout.setOptions({ links: false });
		layout.sync();

		expect(layout.rowCount).toBe(rows);
		expect(layout.getRows(0, rows).every((row) => row.runs.every((run) => !run.action))).toBe(true);
		expect(layout.linksOf(entry!.id)).toEqual([]);
	});

	it('links an address in the rows of an open value, not in the preview that opens it', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);
		const value: ValueNode = {
			kind: 'object',
			children: [
				{
					key: 'url',
					keyKind: 'property',
					value: { kind: 'string', value: 'https://example.com/x' }
				}
			]
		};
		const [entry] = store.append({ parts: [{ type: 'value', value }] });

		layout.sync();
		expect(layout.linksOf(entry.id)).toEqual([]);

		layout.setExpanded(entry, '0', true);
		layout.sync();

		const [, child] = layout.getRows(0, 2);

		expect(layout.linksOf(entry.id)).toEqual(['https://example.com/x']);
		expect(child.runs.find((run) => run.action?.type === 'open-link')?.text).toBe(
			'https://example.com/x'
		);
	});
});
