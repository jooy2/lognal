import { describe, expect, it } from 'vitest';
import { LogLayout } from '../../src/core/layout/layout.ts';
import { compileSearch, LogSearch } from '../../src/core/layout/search.ts';
import { LogStore } from '../../src/core/store.ts';

const text = (value: string) => ({ parts: [{ type: 'text' as const, text: value }] });

const setup = (lines: string[], maxEntries = 1000) => {
	const store = new LogStore({ maxEntries, mergeRepeats: false });
	const layout = new LogLayout(store);
	const search = new LogSearch(layout);

	store.append(lines.map(text));
	layout.sync();

	return { store, layout, search };
};

const scanAll = (layout: LogLayout, search: LogSearch): void => {
	layout.sync();

	while (search.pending) {
		search.scan(2);
	}
};

describe('compileSearch', () => {
	it('matches the text as typed, ignoring case and special characters', () => {
		const { pattern } = compileSearch('a.b(');

		expect('A.B( axb('.match(pattern!)).toEqual(['A.B(']);
		expect(compileSearch('')).toEqual({ pattern: null, error: null });
	});

	it('matches case and regular expressions when asked, and reports a bad pattern', () => {
		expect('Error error'.match(compileSearch('error', { caseSensitive: true }).pattern!)).toEqual([
			'error'
		]);
		expect('id=12 id=345'.match(compileSearch('id=\\d+', { regex: true }).pattern!)).toEqual([
			'id=12',
			'id=345'
		]);

		const broken = compileSearch('(', { regex: true });

		expect(broken.pattern).toBeNull();
		expect(broken.error).toEqual(expect.any(String));
	});
});

describe('LogSearch', () => {
	it('finds every match as cell ranges, in order, a slice at a time', () => {
		const { layout, search } = setup(['error one', 'nothing', 'Error two, error three']);

		search.setQuery('error');
		expect(search.pending).toBe(true);
		search.scan(1);
		expect(search.count).toBe(1);
		expect(search.pending).toBe(true);
		scanAll(layout, search);

		expect(search.count).toBe(3);
		expect(search.getMatch(1)).toMatchObject({ line: 0, from: 0, to: 5 });
		expect(search.getMatch(2)).toMatchObject({ line: 0, from: 11, to: 16 });
		expect(search.pending).toBe(false);
	});

	it('counts wide characters as two cells and matches decomposed Hangul', () => {
		const { layout, search } = setup([`파일 ${'한글'.normalize('NFD')}.txt`]);

		search.setQuery('한글');
		scanAll(layout, search);

		// `파일 ` takes five cells, and each Hangul syllable two.
		expect(search.getMatch(0)).toMatchObject({ from: 5, to: 9 });
	});

	it('searches again when only the options change, and finds nothing for a bad pattern', () => {
		const { layout, search } = setup(['Error 1', 'error 22']);

		search.setQuery('error');
		scanAll(layout, search);
		expect(search.count).toBe(2);

		expect(search.setQuery('error', { caseSensitive: true })).toBe(true);
		scanAll(layout, search);
		expect(search.count).toBe(1);

		search.setQuery('\\d{2}', { regex: true });
		scanAll(layout, search);
		expect(search.count).toBe(1);
		expect(search.getMatch(0)).toMatchObject({ entryId: 2, from: 6, to: 8 });

		search.setQuery('[', { regex: true });
		expect(search.error).toEqual(expect.any(String));
		expect(search.pending).toBe(false);
		expect(search.count).toBe(0);
	});

	it('moves through the matches and wraps around', () => {
		const { layout, search } = setup(['a', 'a', 'a']);

		search.setQuery('a');
		scanAll(layout, search);

		expect(search.next()?.entryId).toBe(1);
		expect(search.next()?.entryId).toBe(2);
		expect(search.previous()?.entryId).toBe(1);
		expect(search.previous()?.entryId).toBe(3);
		expect(search.next()?.entryId).toBe(1);
	});

	it('searches new entries, forgets dropped ones and keeps the current match', () => {
		const { store, layout, search } = setup(['hit 1', 'hit 2', 'hit 3'], 3);

		search.setQuery('hit');
		scanAll(layout, search);
		search.select(2);

		store.append(text('hit 4'));
		scanAll(layout, search);

		expect(search.count).toBe(3);
		expect(search.getMatch(0)?.entryId).toBe(2);
		expect(search.current).toBe(1);
		expect(search.getMatch(search.current)?.entryId).toBe(3);
	});

	it('starts again when the filter changes and finds the current match again', () => {
		const { layout, search } = setup(['hit one', 'skip', 'hit two']);

		search.setQuery('hit');
		scanAll(layout, search);
		search.select(1);

		layout.setFilter({ text: 'two' });
		scanAll(layout, search);

		expect(search.count).toBe(1);
		expect(search.current).toBe(0);
		expect(search.matchesOf(3)).toHaveLength(1);
		expect(search.matchesOf(1)).toBeUndefined();
	});
});

describe('LogLayout.locatePosition', () => {
	it('returns the wrapped row that shows a cell', () => {
		// Lines never wrap narrower than 16 columns.
		const { layout } = setup(['first', 'aaaa bbbb cccc dddd eeee']);

		layout.setColumns(16);
		layout.sync();

		expect(layout.locatePosition({ entryId: 2, line: 0, cell: 0 })).toEqual({
			entryRow: 0,
			indent: 0
		});
		expect(layout.locatePosition({ entryId: 2, line: 0, cell: 12 })?.entryRow).toBe(0);
		expect(layout.locatePosition({ entryId: 2, line: 0, cell: 20 })?.entryRow).toBe(1);
		expect(layout.locatePosition({ entryId: 9, line: 0, cell: 0 })).toBeNull();
	});
});
