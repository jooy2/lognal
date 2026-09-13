import { describe, expect, it, vi } from 'vitest';
import { LogStore } from '../../src/core/store.ts';
import type { LogEntry } from '../../src/core/types.ts';
import { detectEncoding, legacyEncodingFor } from '../../src/sources/text/encoding.ts';
import { followTextFile } from '../../src/sources/text/follow-file.ts';
import { readTextFile } from '../../src/sources/text/read-file.ts';

const lines = (store: LogStore): string[] => {
	return store
		.toArray()
		.map((entry: LogEntry) =>
			entry.parts.map((part) => (part.type === 'text' ? part.text : '')).join('')
		);
};

/** "안녕" followed by a line feed and "하세요", in EUC-KR. */
const EUC_KR_BYTES = Uint8Array.from([
	0xbe, 0xc8, 0xb3, 0xe7, 0x0a, 0xc7, 0xcf, 0xbc, 0xbc, 0xbf, 0xe4
]);

describe('encoding detection', () => {
	it('reads byte order marks and valid UTF-8', () => {
		expect(detectEncoding(Uint8Array.from([0xff, 0xfe, 0x41, 0x00]), 'windows-1252')).toBe(
			'utf-16le'
		);
		expect(detectEncoding(new TextEncoder().encode('한글'), 'euc-kr')).toBe('utf-8');
		expect(detectEncoding(EUC_KR_BYTES, 'euc-kr')).toBe('euc-kr');
	});

	it('picks the legacy encoding for the language', () => {
		expect(legacyEncodingFor('ko-KR')).toBe('euc-kr');
		expect(legacyEncodingFor('zh-TW')).toBe('big5');
		expect(legacyEncodingFor('zh-CN')).toBe('gbk');
		expect(legacyEncodingFor('en-US')).toBe('windows-1252');
	});
});

describe('readTextFile', () => {
	it('adds one entry per line and handles CRLF split across chunks', async () => {
		const store = new LogStore({ mergeRepeats: false });
		const result = await readTextFile(new Blob(['first\r\nsecond\r\nthird']), store, {
			chunkSize: 6
		});

		expect(lines(store)).toEqual(['first', 'second', 'third']);
		expect(result).toMatchObject({ lines: 3, encoding: 'utf-8' });
	});

	it('keeps multi-byte characters that a chunk boundary cuts', async () => {
		const store = new LogStore();

		await readTextFile(new Blob([new TextEncoder().encode('한글 로그\n두 번째 줄')]), store, {
			chunkSize: 1
		});

		expect(lines(store)).toEqual(['한글 로그', '두 번째 줄']);
	});

	it('decodes a Korean legacy file with the fallback encoding', async () => {
		const store = new LogStore();
		const result = await readTextFile(new Blob([EUC_KR_BYTES]), store, {
			fallbackEncoding: 'euc-kr'
		});

		expect(result.encoding).toBe('euc-kr');
		expect(lines(store)).toEqual(['안녕', '하세요']);
	});

	it('turns ANSI colors into styles unless turned off', async () => {
		const styled = new LogStore();
		const plain = new LogStore();

		await readTextFile(new Blob(['\x1b[32mok\x1b[0m']), styled);
		await readTextFile(new Blob(['\x1b[32mok\x1b[0m']), plain, { ansi: false });

		expect(styled.at(0)?.parts[0]).toMatchObject({ text: 'ok', style: { color: 2 } });
		expect((plain.at(0)?.parts[0] as { text: string }).text).toContain('\x1b[32m');
	});
});

describe('followTextFile', () => {
	it('adds the lines appended to a file and starts over when it shrinks', async () => {
		vi.useFakeTimers();

		const store = new LogStore({ mergeRepeats: false });
		let content = 'one\ntw';
		const onReset = vi.fn();
		const handle = { getFile: async () => new Blob([content]) };
		const follow = followTextFile(handle, store, { interval: 100, onReset });

		await follow.ready;
		expect(lines(store)).toEqual(['one']);

		content = 'one\ntwo\nthree\n';
		await vi.advanceTimersByTimeAsync(100);
		expect(lines(store)).toEqual(['one', 'two', 'three']);

		content = 'new\n';
		await vi.advanceTimersByTimeAsync(100);
		expect(onReset).toHaveBeenCalledOnce();
		expect(lines(store)).toEqual(['one', 'two', 'three', 'new']);

		follow.stop();
		vi.useRealTimers();
	});

	it('reads the file again when it keeps its size but changes', async () => {
		vi.useFakeTimers();

		const store = new LogStore({ mergeRepeats: false });
		let file = new File(['aaa\n'], 'log.txt', { lastModified: 1 });
		const follow = followTextFile({ getFile: async () => file }, store, { interval: 100 });

		await follow.ready;
		file = new File(['bbb\n'], 'log.txt', { lastModified: 2 });
		await vi.advanceTimersByTimeAsync(100);

		expect(lines(store)).toEqual(['aaa', 'bbb']);
		follow.stop();
		vi.useRealTimers();
	});

	it('writes the unfinished last line when stopped', async () => {
		const store = new LogStore();
		const follow = followTextFile({ getFile: async () => new Blob(['no line break']) }, store);

		await follow.ready;
		expect(store.size).toBe(0);

		follow.stop();
		expect(lines(store)).toEqual(['no line break']);
	});

	it('rejects ready when the first read fails', async () => {
		const onError = vi.fn();
		const follow = followTextFile(
			{
				getFile: async () => {
					throw new DOMException('Permission denied', 'NotAllowedError');
				}
			},
			new LogStore(),
			{ onError }
		);

		await expect(follow.ready).rejects.toThrow('Permission denied');
		expect(onError).not.toHaveBeenCalled();
		follow.stop();
	});
});
