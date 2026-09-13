/**
 * What the buttons of the demo page write, the sample files it reads, and the commands its input
 * line answers.
 *
 * Invisible characters, such as a zero width joiner or a bidirectional override, are built with
 * `String.fromCharCode`, so this file holds none of them.
 */
import type { LogViewer, LognalConsole } from 'lognal';

import type { Messages, MessageValues } from './messages';

export type Notice = (key: keyof Messages['notice'], values?: MessageValues) => string;

export interface SampleContext {
	viewer: LogViewer;
	log: LognalConsole;
	notice: Notice;
	formatNumber: (value: number) => string;
}

export interface Sample {
	key: keyof Messages['sample'];
	run: (context: SampleContext) => void;
}

export interface SampleGroup {
	key: 'console' | 'values' | 'text' | 'cjk' | 'volume';
	samples: Sample[];
}

export type SampleFileKey = 'utf8-file' | 'utf16-file' | 'euckr-file';

const ESCAPE = String.fromCharCode(0x1b);
const ZERO_WIDTH_JOINER = String.fromCharCode(0x200d);

/** Wraps text in an ANSI Select Graphic Rendition sequence and resets the style after it. */
const sgr = (codes: string, text: string): string => `${ESCAPE}[${codes}m${text}${ESCAPE}[0m`;

const measure = (run: () => void): number => {
	const started = performance.now();

	run();

	return Math.round(performance.now() - started);
};

const createNav = (): HTMLElement => {
	const nav = document.createElement('nav');

	nav.className = 'menu';
	nav.setAttribute('aria-label', 'Main');

	for (const [href, text] of [
		['/', 'Home'],
		['/guide/', 'Guide']
	]) {
		const link = document.createElement('a');

		link.href = href;
		link.textContent = text;
		nav.append(link);
	}

	return nav;
};

class Account {
	id: number;
	owner: string;

	constructor(id: number, owner: string) {
		this.id = id;
		this.owner = owner;
	}
}

export const SAMPLE_GROUPS: SampleGroup[] = [
	{
		key: 'console',
		samples: [
			{
				key: 'levels',
				run: ({ log }) => {
					log.debug('Cache lookup for key %s', 'user:42');
					log.log('GET /api/users handled in %dms', 38);
					log.info('Connected to %s in %fms', 'database', 12.5);
					log.warn('Response time is above %dms', 500);
					log.error('Payment service returned %d', 503);
				}
			},
			{
				key: 'format',
				run: ({ log }) => {
					log.log('%s requests in %fs', 128, '2.5');
					log.log('%d and %i read integers, %f reads a float', '42.9px', '7', '3.14abc');
					log.log('User %o signed in with %O', { id: 42 }, { theme: 'dark', beta: true });
					log.log('Disk usage is at 91%% with %s left', '12 GB', 'and extra arguments', {
						unused: true
					});
					log.log('A specifier without an argument stays: %s and %d');
				}
			},
			{
				key: 'css',
				run: ({ log }) => {
					log.log('%cSuccess%c build finished', 'color: #1f7a47; font-weight: bold', '');
					log.log(
						'%c background %c and %citalic underlined text',
						'background: #4697fd; color: white',
						'',
						'font-style: italic; text-decoration: underline'
					);
					log.log(
						'%cOnly the styles the viewer can draw are kept, so this has no image and no large font',
						'color: oklch(60% 0.18 30); background-image: url(https://example.com/image.png); font-size: 40px'
					);
				}
			},
			{
				key: 'repeats',
				run: ({ log }) => {
					for (let index = 0; index < 5; index++) {
						log.warn('Retrying the connection');
					}
				}
			},
			{
				key: 'counters',
				run: ({ log }) => {
					log.count();
					log.count();
					log.count('api');
					log.countReset('api');
					log.count('api');
					log.time('render');
					log.timeLog('render', 'first frame');
					setTimeout(() => log.timeEnd('render'), 250);
				}
			},
			{
				key: 'assert',
				run: ({ log }) => {
					log.assert(true, 'A passing assertion writes nothing');
					log.assert(false, 'Expected %d items, received %d', 3, 2);
					log.trace('Trace from the demo page');
				}
			},
			{
				key: 'dir',
				run: ({ log }) => {
					log.dir('console.dir shows a string in quotes');
					log.dir({ request: { method: 'GET', path: '/api/users' } });
					log.dirxml(createNav());
				}
			},
			{
				key: 'clear',
				run: ({ log }) => {
					log.clear();
				}
			}
		]
	},
	{
		key: 'values',
		samples: [
			{
				key: 'objects',
				run: ({ log }) => {
					const user = {
						id: 1,
						name: 'Ada',
						roles: ['admin', 'editor'],
						profile: { city: 'Seoul', zip: '04524', verified: true }
					};

					log.log('user', user);
					user.name = 'Grace';
					log.log('The same object after its name changed', user);
					log.log([1, 'two', { three: 3 }, [4, [5, [6]]]]);
					log.log(new Account(7, 'team'), { [Symbol('id')]: 'symbol key', 'with space': true });
				}
			},
			{
				key: 'collections',
				run: ({ log }) => {
					log.log(
						new Map<string, unknown>([
							['status', 200],
							['headers', { 'content-type': 'application/json' }]
						])
					);
					log.log(new Set(['read', 'write', 'admin']));
					log.log(new Uint8Array([1, 2, 3, 4]), new Float64Array([0.5, 1.5]));
					log.log(new WeakMap(), new WeakSet(), Promise.resolve(42));
				}
			},
			{
				key: 'errors',
				run: ({ log }) => {
					const cause = new TypeError('Expected a string, received a number');

					log.error(new Error('Failed to load the user profile', { cause }));
					log.log('An error inside a value starts closed', {
						path: '/api/users',
						error: new RangeError('Retry limit reached')
					});

					try {
						JSON.parse('{');
					} catch (error) {
						log.error('Could not parse the response', error);
					}
				}
			},
			{
				key: 'element',
				run: ({ log }) => {
					log.log(createNav());
				}
			},
			{
				key: 'primitives',
				run: ({ log }) => {
					log.log(
						function handleClick() {},
						class User {},
						() => 1
					);
					log.log(new Date(0), /ab+c/gi, Symbol('token'), 10n);
					log.log(42, -0, NaN, Infinity, true, null, undefined);
				}
			},
			{
				key: 'special',
				run: ({ log }) => {
					const node: Record<string, unknown> = { name: 'root' };
					let volume = 3;
					const settings = {
						get expensive(): number {
							log.error('This getter should never run');

							return 0;
						},
						get volume(): number {
							return volume;
						},
						set volume(next: number) {
							volume = next;
						}
					};
					const proxy = new Proxy(
						{},
						{
							ownKeys: () => {
								throw new Error('The proxy refused to list its keys');
							}
						}
					);

					node.self = node;
					node.children = [node];
					log.log('Circular', node);
					log.log('Accessors are not called', settings);
					log.log('A proxy that throws', proxy);
				}
			},
			{
				key: 'limits',
				run: ({ log }) => {
					let deep: Record<string, unknown> = { level: 8 };

					for (let level = 7; level >= 1; level--) {
						deep = { level, child: deep };
					}

					log.log('Eight levels deep', deep);
					log.log(
						'500 items',
						Array.from({ length: 500 }, (_, index) => index)
					);
					log.log('A string of 12,000 characters', {
						text: 'lognal '.repeat(1715).slice(0, 12000)
					});
				}
			},
			{
				key: 'table',
				run: ({ log }) => {
					log.table([
						{ name: 'Alice', role: 'admin', active: true },
						{ name: '김철수', role: 'editor', active: false },
						{ name: 'Bob', role: 'viewer', active: true, note: 'On leave' }
					]);
					log.table(
						{
							build: { status: 'pass', seconds: 42, runner: 'linux' },
							test: { status: 'fail', seconds: 97, runner: 'macos' }
						},
						['status', 'seconds']
					);
				}
			},
			{
				key: 'groups',
				run: ({ log }) => {
					log.group('Request %s', 'GET /api/users');
					log.log('Headers', { accept: 'application/json' });
					log.groupCollapsed('Response');
					log.log('Status', 200);
					log.log('Body', { users: [{ id: 1 }, { id: 2 }] });
					log.groupEnd();
					log.warn('The response was slow');
					log.groupEnd();
					log.log('Outside the group');
				}
			}
		]
	},
	{
		key: 'text',
		samples: [
			{
				key: 'ansi',
				run: ({ viewer }) => {
					const normal = Array.from({ length: 8 }, (_, index) => sgr(`${40 + index}`, '   ')).join(
						''
					);
					const bright = Array.from({ length: 8 }, (_, index) => sgr(`${100 + index}`, '   ')).join(
						''
					);

					viewer.writeLines(
						[
							`${sgr('32', 'ok')} build finished in ${sgr('1', '1.2s')}`,
							`${sgr('33', 'warning')} ${sgr('2', 'dim')} ${sgr('3', 'italic')} ${sgr('9', 'strikethrough')}`,
							`${sgr('31;1', 'error')} ${sgr('4', 'missing semicolon')}`,
							`${normal} 16 theme colors`,
							`${bright} bright versions`,
							`${sgr('38;5;208', '256-color palette')} and ${sgr('38;2;120;200;255', 'RGB color')} ${sgr('30;48;5;150', ' background ')}`
						].join('\n'),
						{ ansi: true }
					);
				}
			},
			{
				key: 'preformatted',
				run: ({ viewer }) => {
					viewer.write(
						[
							'+--------------------+--------+---------+------------------------------------------+',
							'| job                | status | seconds | artifact                                 |',
							'+--------------------+--------+---------+------------------------------------------+',
							'| build              | pass   |      42 | dist/lognal-0.1.0.tgz                    |',
							'| integration-test   | fail   |      97 | reports/integration/chromium/summary.xml |',
							'+--------------------+--------+---------+------------------------------------------+'
						].join('\n'),
						{ wrap: false }
					);
					viewer.write(
						[
							'┌──────┬──────┐',
							'│ 이름 │ 상태 │',
							'├──────┼──────┤',
							'│ api  │ 정상 │',
							'└──────┴──────┘'
						].join('\n'),
						{
							wrap: false
						}
					);
				}
			},
			{
				key: 'long-line',
				run: ({ log }) => {
					const query = Array.from(
						{ length: 40 },
						(_, index) => `field${index}=value${index}`
					).join('&');

					log.log(`GET /api/search?${query} 200`);
				}
			},
			{
				key: 'links',
				run: ({ log, viewer }) => {
					log.info('Documentation: https://lognal.cdget.com/guide/viewer#links');
					log.log('A link in brackets (https://github.com/jooy2/lognal) ends before the bracket.');
					viewer.write(
						'한국어 문장 속 주소 https://lognal.cdget.com/ko/guide/viewer 도 링크가 됩니다.'
					);
					log.log('An address inside a value is a link once the value is open', {
						docs: 'https://lognal.cdget.com/reference/log-viewer'
					});
					log.warn('Other schemes stay text: javascript:alert(1), ftp://example.com');
				}
			},
			{
				key: 'tabs',
				run: ({ viewer }) => {
					viewer.writeLines(
						['name\tstatus\tseconds', 'build\tpass\t42', 'integration-test\tfail\t97'].join('\n')
					);
				}
			},
			{
				key: 'control',
				run: ({ log }) => {
					const bell = String.fromCharCode(7);
					const escape = ESCAPE;
					const deleteCharacter = String.fromCharCode(0x7f);
					const override = String.fromCharCode(0x202e);
					const zeroWidthSpace = String.fromCharCode(0x200b);

					log.log(`Bell ${bell}, escape ${escape}[31m and delete ${deleteCharacter} are shown`);
					log.log(`A right-to-left override hides the extension: invoice${override}fdp.exe`);
					log.log(`A zero width space sits between a${zeroWidthSpace}b`);
				}
			},
			{
				key: 'tokens',
				run: ({ viewer }) => {
					viewer.write('Written with the accent token', { token: 'accent' });
					viewer.write('Bold, underlined and ANSI color 208', {
						style: { bold: true, underline: true, color: 208 }
					});
					viewer.write('A notice written as a system entry', { kind: 'system' });
					viewer.write('A reply written as command output', { kind: 'output' });
					viewer.write('An info entry dated one hour ago', {
						level: 'info',
						time: Date.now() - 3_600_000
					});
				}
			}
		]
	},
	{
		key: 'cjk',
		samples: [
			{
				key: 'korean',
				run: ({ log }) => {
					log.log('안녕하세요. lognal은 캔버스에 로그를 그리는 뷰어입니다.');
					log.log(
						'한글과 English가 섞인 긴 문장은 공백에서 줄이 바뀝니다. 창 너비를 줄이면 한글 낱말은 중간에서 잘리지 않고 통째로 다음 줄로 넘어갑니다.'
					);
					log.warn('디스크 사용량이 %d%%입니다.', 91);
					log.log({ 이름: '홍길동', 도시: '서울', 태그: ['개발', '로그'] });
				}
			},
			{
				key: 'chinese-japanese',
				run: ({ log }) => {
					log.info('中文日志：服务器已启动，正在监听端口 8080。');
					log.info('日本語のログ：サーバーが起動しました。ポート 8080 で待機しています。');
					log.log('Fullwidth ＡＢＣ１２３ and halfwidth ｱｲｳ katakana');
				}
			},
			{
				key: 'emoji',
				run: ({ log }) => {
					const technologist = ['👩', '💻'].join(ZERO_WIDTH_JOINER);
					const family = ['👨', '👩', '👧'].join(ZERO_WIDTH_JOINER);
					const keycap = `1${String.fromCharCode(0xfe0f, 0x20e3)}`;

					log.log(`Emoji 👍 🚀 flags 🇰🇷 🇯🇵 and joined sequences ${technologist} ${family}`);
					log.log(`Skin tone 👋🏽 and keycap ${keycap}`);
				}
			},
			{
				key: 'decomposed',
				run: ({ log, notice }) => {
					log.warn(`A macOS file name in decomposed form: ${'한글 로그.txt'.normalize('NFD')}`);
					log.info(notice('decomposed-hint'));
				}
			},
			{
				key: 'ambiguous',
				run: ({ log, notice }) => {
					log.log('Ambiguous: ①②③ ○● αβγ ±× → ※');
					log.log('Box drawing always takes one cell: ┌─┬─┐ │a│b│ └─┴─┘');
					log.info(notice('ambiguous-hint'));
				}
			}
		]
	},
	{
		key: 'volume',
		samples: [
			{
				key: 'calls',
				run: ({ log, notice, formatNumber }) => {
					const count = 10000;
					const ms = measure(() => {
						for (let index = 0; index < count; index++) {
							if (index % 500 === 0) {
								log.log('Request %d handled', index, { index, cached: index % 1000 === 0 });
							} else {
								log.log(`Request ${index} handled in ${index % 97}ms`);
							}
						}
					});

					log.info(notice('timing-calls', { count: formatNumber(count), ms }));
				}
			},
			{
				key: 'lines',
				run: ({ viewer, log, notice, formatNumber }) => {
					const count = 100000;
					const text = Array.from(
						{ length: count },
						(_, index) => `${index} GET /api/items/${index % 1000} 200 ${index % 89}ms`
					).join('\n');
					const ms = measure(() => viewer.writeLines(text));

					log.info(notice('timing-lines', { count: formatNumber(count), ms }));
				}
			}
		]
	}
];

/** Writes message number `index` of the stream: mostly logs, with some debug, warning and error entries. */
export const writeStreamMessage = (log: LognalConsole, index: number): void => {
	const workers = ['alpha', 'beta', 'gamma'];
	const worker = workers[index % workers.length];

	if (index % 29 === 0) {
		log.error('Job %d on %s failed', index, worker, { attempt: (index % 3) + 1 });
	} else if (index % 13 === 0) {
		log.warn('Job %d on %s is slow', index, worker);
	} else if (index % 7 === 0) {
		log.debug('Heartbeat from %s', worker);
	} else {
		log.log(`Job ${index} on ${worker} finished in ${index % 250}ms`);
	}
};

/**
 * The same three log lines in EUC-KR, as hexadecimal bytes. Decoded, they read:
 *
 * 2026-09-13 14:03:09 [정보] 서버를 시작했습니다.
 * 2026-09-13 14:03:10 [경고] 디스크 사용량이 91%입니다.
 * 2026-09-13 14:03:11 [오류] 설정 파일을 읽지 못했습니다.
 */
const EUC_KR_SAMPLE =
	'323032362d30392d31332031343a30333a3039205bc1a4bab85d20bcadb9f6b8a620bdc3c0dbc7dfbdc0b4cfb4d92e0a' +
	'323032362d30392d31332031343a30333a3130205bb0e6b0ed5d20b5f0bdbac5a920bbe7bfebb7aec0cc20393125c0d4b4cfb4d92e0a' +
	'323032362d30392d31332031343a30333a3131205bbfc0b7f95d20bcb3c1a420c6c4c0cfc0bb20c0d0c1f620b8f8c7dfbdc0b4cfb4d92e0a';

const bytesOfHex = (hex: string): Uint8Array<ArrayBuffer> => {
	return Uint8Array.from(hex.match(/../g) ?? [], (pair) => Number.parseInt(pair, 16));
};

/** Encodes text as UTF-16LE with a byte order mark. */
const utf16Bytes = (text: string): Uint8Array<ArrayBuffer> => {
	const bytes = new Uint8Array(2 + text.length * 2);

	bytes[0] = 0xff;
	bytes[1] = 0xfe;

	for (let index = 0; index < text.length; index++) {
		const code = text.charCodeAt(index);

		bytes[2 + index * 2] = code & 0xff;
		bytes[3 + index * 2] = code >> 8;
	}

	return bytes;
};

export const createSampleFile = (key: SampleFileKey): File => {
	if (key === 'utf16-file') {
		const text = [
			'UTF-16LE with a byte order mark',
			'한글, 中文 and 日本語 in the same file',
			''
		].join('\n');

		return new File([utf16Bytes(text)], 'utf16.log', { type: 'text/plain' });
	}

	if (key === 'euckr-file') {
		return new File([bytesOfHex(EUC_KR_SAMPLE)], 'euc-kr.log', { type: 'text/plain' });
	}

	const text = [
		`${sgr('36', 'info')} install finished in 3.1s`,
		`${sgr('33', 'warn')} the peer dependency react is optional`,
		`${sgr('31;1', 'error')} test/browser/viewer.test.ts failed`,
		'한글이 들어간 줄도 UTF-8로 읽습니다.',
		''
	].join('\n');

	return new File([text], 'build.log', { type: 'text/plain' });
};

/** Answers a command from the input line. See `notice.help` for the list. */
export const runCommand = (command: string, viewer: LogViewer, notice: Notice): unknown => {
	const [name = '', ...words] = command.trim().split(/\s+/);
	const rest = words.join(' ');

	if (name === 'help') {
		return notice('help');
	}

	if (name === 'echo') {
		return rest;
	}

	if (name === 'time') {
		return new Date();
	}

	if (name === 'json') {
		return { command, words, length: command.length };
	}

	if (name === 'wait') {
		return new Promise((resolve) => {
			setTimeout(() => resolve(notice('wait')), 1000);
		});
	}

	if (name === 'later') {
		setTimeout(() => viewer.write(notice('later'), { kind: 'output' }), 1000);

		return undefined;
	}

	if (name === 'reject') {
		return new Promise((_, reject) => {
			setTimeout(() => reject(new Error(notice('reject'))), 500);
		});
	}

	if (name === 'error') {
		throw new TypeError(notice('error'));
	}

	if (name === 'filter') {
		viewer.setFilter(rest ? { text: rest } : null);

		return rest ? notice('filter', { text: rest }) : notice('filter-cleared');
	}

	if (name === 'clear') {
		viewer.clear();

		return undefined;
	}

	return notice('unknown-command', { name });
};
