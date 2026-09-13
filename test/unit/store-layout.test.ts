import { describe, expect, it, vi } from 'vitest';
import { compileFilter, entrySearchText } from '../../src/core/filter.ts';
import { LogLayout } from '../../src/core/layout/layout.ts';
import { LogStore } from '../../src/core/store.ts';
import type { ValueNode } from '../../src/core/types.ts';
import { formatTimestamp } from '../../src/core/time.ts';

const text = (value: string) => ({ parts: [{ type: 'text' as const, text: value }] });

const object: ValueNode = {
	kind: 'object',
	children: [
		{ key: 'id', keyKind: 'property', value: { kind: 'number', value: '1' } },
		{ key: 'tags', keyKind: 'property', value: { kind: 'array', size: 2, children: [] } }
	]
};

const rowTexts = (layout: LogLayout): string[] => {
	layout.sync();

	return layout.getRows(0, layout.rowCount).map((row) => row.runs.map((run) => run.text).join(''));
};

describe('LogStore', () => {
	it('gives entries consecutive ids and looks them up by id', () => {
		const store = new LogStore();
		const [first, second] = store.append([text('a'), text('b')]);

		expect(second.id).toBe(first.id + 1);
		expect(store.get(second.id)).toBe(second);
		expect(store.size).toBe(2);
	});

	it('merges identical consecutive messages into a repeat count', () => {
		const store = new LogStore();
		const listener = vi.fn();

		store.subscribe(listener);
		store.append(text('same'));
		store.append(text('same'));
		store.append(text('other'));

		expect(store.size).toBe(2);
		expect(store.at(0)?.repeat).toBe(2);
		expect(listener).toHaveBeenCalledWith(expect.objectContaining({ type: 'update' }));
	});

	it('does not merge messages that hold expandable values', () => {
		const store = new LogStore();

		store.append({ parts: [{ type: 'value', value: object }] });
		store.append({ parts: [{ type: 'value', value: object }] });

		expect(store.size).toBe(2);
	});

	it('drops the oldest entries past maxEntries', () => {
		const store = new LogStore({ maxEntries: 3, mergeRepeats: false });

		for (let index = 0; index < 5; index++) {
			store.append(text(String(index)));
		}

		expect(store.size).toBe(3);
		expect(store.firstId).toBe(3);
		expect(store.get(2)).toBeUndefined();
		expect(store.toArray().map((entry) => (entry.parts[0] as { text: string }).text)).toEqual([
			'2',
			'3',
			'4'
		]);
	});

	it('writes one entry per line, with ANSI styles when asked', () => {
		const store = new LogStore();
		const entries = store.writeLines('\x1b[31mred\nnext', { ansi: true, level: 'warn' });

		expect(entries).toHaveLength(2);
		expect(entries[1].parts[0]).toMatchObject({ text: 'next', style: { color: 1 } });
		expect(entries[0].level).toBe('warn');
	});

	it('keeps counting ids after clear', () => {
		const store = new LogStore();

		store.append(text('a'));
		store.clear();

		const [entry] = store.append(text('b'));

		expect(store.size).toBe(1);
		expect(entry.id).toBe(2);
		expect(store.firstId).toBe(2);
	});
});

describe('filters', () => {
	it('matches by minimum level and by text', () => {
		const store = new LogStore({ mergeRepeats: false });
		const [debug, warn] = store.append([
			{ ...text('cache miss'), level: 'debug' },
			{ ...text('disk almost full'), level: 'warn' }
		]);
		const byLevel = compileFilter({ minLevel: 'info' });
		const byText = compileFilter({ text: 'CACHE' });

		expect(byLevel.matches?.(debug)).toBe(false);
		expect(byLevel.matches?.(warn)).toBe(true);
		expect(byText.matches?.(debug)).toBe(true);
		expect(byText.matches?.(warn)).toBe(false);
	});

	it('reports an invalid regular expression', () => {
		expect(compileFilter({ text: '(', regex: true }).error).not.toBeNull();
	});

	it('matches composed text against decomposed Hangul', () => {
		const store = new LogStore();
		const [entry] = store.append(text('파일 이름: ' + '한글'.normalize('NFD')));

		expect(compileFilter({ text: '한글' }).matches?.(entry)).toBe(true);
		expect(entrySearchText(entry)).toContain('한글');
	});
});

describe('LogLayout', () => {
	it('wraps entries to the column count and follows appends and trims', () => {
		const store = new LogStore({ maxEntries: 2, mergeRepeats: false });
		const layout = new LogLayout(store);

		layout.setColumns(20);
		store.append(text('short'));
		store.append(text('a longer line that has to wrap onto more rows'));

		expect(layout.sync()).toBe(true);
		expect(layout.rowCount).toBe(4);

		store.append(text('third'));
		layout.sync();

		expect(layout.visibleCount).toBe(2);
		expect(rowTexts(layout)[0]).toBe('a longer line that ');
	});

	it('counts the same rows for plain entries as for the general layout', () => {
		const store = new LogStore({ mergeRepeats: false });
		const layout = new LogLayout(store);
		const sample = 'The quick brown fox jumps over the lazy dog, then naps in the sun for a while.';

		layout.setColumns(17);
		store.append(text(sample));
		store.append({
			parts: [
				{ type: 'text', text: sample },
				{ type: 'text', text: '' }
			]
		});
		layout.sync();

		const rows = layout.getRows(0, layout.rowCount);
		const first = rows.filter((row) => row.entry.id === 1).length;
		const second = rows.filter((row) => row.entry.id === 2).length;

		expect(first).toBe(second);
	});

	it('hides filtered entries and members of a collapsed group', () => {
		const store = new LogStore({ mergeRepeats: false });
		const layout = new LogLayout(store);
		const [group] = store.append({ kind: 'group', parts: [{ type: 'text', text: 'group' }] });

		store.append({ ...text('inside'), groups: [group.id] });
		store.append({ ...text('outside error'), level: 'error' });
		layout.sync();
		expect(layout.visibleCount).toBe(3);

		layout.runAction(group.id, { type: 'toggle-group' });
		layout.sync();
		expect(layout.visibleCount).toBe(2);

		layout.setFilter({ minLevel: 'error' });
		layout.sync();
		expect(rowTexts(layout)).toEqual(['group', 'outside error']);
	});

	it('adds rows when a value is expanded', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);
		const [entry] = store.append({
			parts: [
				{ type: 'text', text: 'user ' },
				{ type: 'value', value: object }
			]
		});

		layout.sync();
		expect(layout.rowCount).toBe(1);

		layout.runAction(entry.id, { type: 'toggle-value', path: '1' });
		expect(layout.rowCount).toBe(3);
		expect(rowTexts(layout).slice(1)).toEqual(['id: 1', 'tags: (2) []']);
	});

	it('opens logged errors by default so the stack is visible', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);

		store.append({
			parts: [
				{
					type: 'value',
					value: { kind: 'error', className: 'TypeError', value: 'bad', stack: 'at a\nat b' }
				}
			]
		});

		expect(rowTexts(layout)).toEqual(['TypeError: bad', 'at a', 'at b']);
	});

	it('maps screen positions to text positions and copies text', () => {
		const store = new LogStore({ mergeRepeats: false });
		const layout = new LogLayout(store);

		layout.setColumns(40);
		store.append(text('first line'));
		store.append(text('한글 two'));
		layout.sync();

		const start = layout.positionAt(0, 6);
		// Column 1 is the right half of the first Hangul syllable, which snaps to its end.
		const end = layout.positionAt(1, 1);

		expect(start).toEqual({ entryId: 1, line: 0, cell: 6 });
		expect(end).toEqual({ entryId: 2, line: 0, cell: 2 });
		expect(layout.getText(start!, end!)).toBe('line\n한');
		expect(layout.getAllText()).toBe('first line\n한글 two');
	});

	it('finds the word at a position', () => {
		const store = new LogStore();
		const layout = new LogLayout(store);

		store.append(text('request_id=42 failed'));
		layout.sync();

		const range = layout.wordAt({ entryId: 1, line: 0, cell: 3 });

		expect(range && layout.getText(range[0], range[1])).toBe('request_id');
	});
});

describe('timestamps', () => {
	it('formats local times', () => {
		const time = new Date(2026, 8, 13, 4, 5, 6, 7).getTime();

		expect(formatTimestamp(time)).toBe('04:05:06.007');
		expect(formatTimestamp(time, 'datetime')).toBe('2026-09-13 04:05:06.007');
		expect(formatTimestamp(time, (value) => String(value))).toBe(String(time));
	});
});
