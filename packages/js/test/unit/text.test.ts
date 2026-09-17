import { describe, expect, it } from 'vitest';
import {
	BREAK_KEEP,
	BREAK_NORMAL,
	BREAK_SPACE,
	type ShapedLine
} from '../../src/core/layout/types.ts';
import { AnsiParser, stripAnsi } from '../../src/core/text/ansi.ts';
import { splitGraphemes, splitGraphemesFallback } from '../../src/core/text/graphemes.ts';
import { LineSplitter, splitLines } from '../../src/core/text/line-splitter.ts';
import { measureCells, truncateCells } from '../../src/core/text/measure.ts';
import { shapeLine, textBetween } from '../../src/core/text/shape.ts';
import { clusterWidth, codePointWidth } from '../../src/core/text/width.ts';
import { wrapLine } from '../../src/core/text/wrap.ts';

const rowsOf = (
	text: string,
	columns: number,
	mode: 'word' | 'char' | 'none' = 'word'
): string[] => {
	const line = shapeLine([{ text }], 0);
	const starts = wrapLine(line, columns, mode);

	return starts.map((start, index) => textBetween(line, start, starts[index + 1] ?? line.length));
};

/** The same ASCII line in the general form, so both wrapping paths can be compared. */
const generalLine = (text: string): ShapedLine => {
	return {
		indent: 0,
		spans: [{ text }],
		spanStarts: Uint32Array.of(0),
		simple: false,
		text,
		clusters: text.split(''),
		widths: Uint8Array.from(text.split('').map(() => 1)),
		breaks: Uint8Array.from(
			text.split('').map((character) => (character === ' ' ? BREAK_SPACE : BREAK_NORMAL))
		),
		length: text.length,
		cells: text.length,
		wrap: true
	};
};

describe('character width', () => {
	it('gives ASCII and Latin-1 letters one cell', () => {
		expect(codePointWidth(0x41)).toBe(1);
		expect(clusterWidth('é')).toBe(1);
	});

	it('gives Hangul, Han, kana and fullwidth forms two cells', () => {
		expect(clusterWidth('한')).toBe(2);
		expect(clusterWidth('中')).toBe(2);
		expect(clusterWidth('カ')).toBe(2);
		expect(clusterWidth('Ａ')).toBe(2);
	});

	it('gives emoji sequences two cells', () => {
		expect(clusterWidth('👍')).toBe(2);
		expect(clusterWidth('👩‍💻')).toBe(2);
		expect(clusterWidth('🇰🇷')).toBe(2);
		expect(clusterWidth('❤️')).toBe(2);
	});

	it('treats combining marks and Hangul vowel jamo as zero width inside a cluster', () => {
		expect(clusterWidth('é'.normalize('NFD'))).toBe(1);
		expect(clusterWidth('한'.normalize('NFD'))).toBe(2);
		expect(codePointWidth(0x0301)).toBe(0);
	});

	it('uses the ambiguous width option, except for box drawing', () => {
		expect(clusterWidth('①', 1)).toBe(1);
		expect(clusterWidth('①', 2)).toBe(2);
		expect(clusterWidth('─', 2)).toBe(1);
	});

	it('measures and truncates strings in cells', () => {
		expect(measureCells('ab한글')).toBe(6);
		expect(truncateCells('한글입니다', 5)).toBe('한글…');
	});
});

describe('grapheme splitting', () => {
	it('keeps decomposed Hangul syllables together', () => {
		const text = '한글'.normalize('NFD');

		expect(splitGraphemes(text)).toHaveLength(2);
		expect(splitGraphemesFallback(text)).toHaveLength(2);
	});

	it('keeps emoji sequences and flags together in the fallback splitter', () => {
		expect(splitGraphemesFallback('a👩‍💻🇰🇷🇯🇵👍🏽b')).toEqual(['a', '👩‍💻', '🇰🇷', '🇯🇵', '👍🏽', 'b']);
	});
});

describe('shaping', () => {
	it('keeps plain ASCII in the compact form', () => {
		const line = shapeLine([{ text: 'hello world' }], 2);

		expect(line.simple).toBe(true);
		expect(line.clusters).toBeNull();
		expect(line.cells).toBe(11);
		expect(line.indent).toBe(2);
	});

	it('expands tabs to the next tab stop', () => {
		const line = shapeLine([{ text: 'ab\tc' }], 0, {
			tabSize: 4,
			ambiguousWidth: 1,
			maxClusters: 100
		});

		expect(line.text).toBe('ab  c');
	});

	it('shows control and bidirectional formatting characters as visible notation', () => {
		const line = shapeLine(
			[{ text: `a${String.fromCharCode(0x1b)}b${String.fromCharCode(0x202e)}c` }],
			0
		);

		expect(line.text).toBe('a^[b<U+202E>c');
		expect(line.spans.some((span) => span.token === 'muted' && span.text === '^[')).toBe(true);
	});

	it('marks Hangul as keeping words together', () => {
		const line = shapeLine([{ text: '한 글' }], 0);

		expect(Array.from(line.breaks ?? [])).toEqual([BREAK_KEEP, BREAK_SPACE, BREAK_KEEP]);
	});

	it('cuts a line past the cluster limit', () => {
		const line = shapeLine([{ text: 'x'.repeat(50) }, { text: '가' }], 0, {
			tabSize: 8,
			ambiguousWidth: 1,
			maxClusters: 10
		});

		expect(line.length).toBe(10);
		expect(line.text.endsWith(' …')).toBe(true);
	});
});

describe('wrapping', () => {
	it('breaks at spaces and lets the space hang', () => {
		expect(rowsOf('hello brave new world', 11)).toEqual(['hello brave ', 'new world']);
	});

	it('breaks a word longer than the row between characters', () => {
		expect(rowsOf('abcdefghij', 4)).toEqual(['abcd', 'efgh', 'ij']);
	});

	it('fills rows in char mode and keeps one row in none mode', () => {
		expect(rowsOf('hello world', 4, 'char')).toEqual(['hell', 'o wo', 'rld']);
		expect(rowsOf('hello world', 4, 'none')).toEqual(['hello world']);
	});

	it('breaks Korean at spaces and Chinese between characters', () => {
		expect(rowsOf('안녕하세요 반갑습니다', 12)).toEqual(['안녕하세요 ', '반갑습니다']);
		expect(rowsOf('服务器已经启动了', 6)).toEqual(['服务器', '已经启', '动了']);
	});

	it('never splits a wide character across rows', () => {
		for (const row of rowsOf('a한글한글한글', 4, 'char')) {
			expect(measureCells(row)).toBeLessThanOrEqual(4);
		}
	});

	it('wraps plain ASCII the same way on the fast path and the general path', () => {
		const samples = [
			'one two three four five six',
			'aaaaaaaaaaaaa b c',
			'  leading spaces and    gaps  ',
			'x'
		];

		for (const text of samples) {
			for (let columns = 1; columns < 16; columns++) {
				for (const mode of ['word', 'char'] as const) {
					expect(wrapLine(shapeLine([{ text }], 0), columns, mode)).toEqual(
						wrapLine(generalLine(text), columns, mode)
					);
				}
			}
		}
	});
});

describe('ANSI escape codes', () => {
	it('turns colors and weights into styles and resets them', () => {
		const parts = new AnsiParser().parse('\x1b[31;1mred\x1b[0m plain');

		expect(parts).toEqual([
			{ type: 'text', text: 'red', style: { color: 1, bold: true } },
			{ type: 'text', text: ' plain' }
		]);
	});

	it('reads 256-color and true-color codes', () => {
		const [first, second] = new AnsiParser().parse('\x1b[38;5;208ma\x1b[48;2;1;2;255mb');

		expect(first.style?.color).toBe(208);
		expect(second.style?.background).toBe('#0102ff');
	});

	it('keeps the style across calls and removes other sequences', () => {
		const parser = new AnsiParser();

		parser.parse('\x1b[32mstart');
		expect(parser.parse('next')[0].style).toEqual({ color: 2 });
		expect(stripAnsi('\x1b[2J\x1b]8;;https://example.com\x07link\x1b]8;;\x07 done')).toBe(
			'link done'
		);
	});
});

describe('line splitting', () => {
	it('handles CRLF split across chunks and a lone CR', () => {
		const splitter = new LineSplitter();

		expect(splitter.push('a\r')).toEqual(['a']);
		expect(splitter.push('\nb\rc')).toEqual(['b']);
		expect(splitter.flush()).toEqual(['c']);
		expect(splitLines('x\ny\n')).toEqual(['x', 'y']);
	});
});
