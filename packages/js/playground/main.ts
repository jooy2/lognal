import '../src/styles/lognal.css';
import { LogViewer, readTextFile, type ThemeMode } from '../src/index.ts';

const container = document.getElementById('viewer') as HTMLElement;
const viewer = new LogViewer(container, {
	core: { maxEntries: 50000 },
	input: {
		onSubmit: (command) => {
			const [name, ...rest] = command.trim().split(/\s+/);

			if (name === 'help') {
				return 'Commands: echo <text>, time, json, error';
			}

			if (name === 'echo') {
				return rest.join(' ');
			}

			if (name === 'time') {
				return new Date();
			}

			if (name === 'json') {
				return { command, words: rest, length: command.length };
			}

			if (name === 'error') {
				throw new TypeError('This command always fails');
			}

			return new Promise((resolve) => setTimeout(() => resolve(`Unknown command: ${name}`), 200));
		}
	}
});
const log = viewer.console;

(window as unknown as { viewer: LogViewer }).viewer = viewer;

const actions: Record<string, () => void> = {
	basic: () => {
		log.log('Server started on port %d', 8080);
		log.info('Connected to %s in %fms', 'database', 12.5);
		log.debug('Cache hit ratio', 0.93);
		log.warn('Deprecated option %o will be removed', 'legacyMode');
		log.error(new Error('Failed to load the user profile'));
		log.log(
			'%cStyled%c text with %cCSS',
			'color: #43d786; font-weight: bold',
			'',
			'background: #4697fd; color: white'
		);
		log.log('Same message');
		log.log('Same message');
		log.log('Same message');
	},
	values: () => {
		const user = {
			id: 1,
			name: 'lognal',
			roles: ['admin', 'editor'],
			profile: { city: 'Seoul', zip: '04524' }
		};
		const circular: Record<string, unknown> = { name: 'circular' };

		circular.self = circular;
		log.log('user', user);
		log.log([1, 2, 3, { nested: true }, [4, 5]]);
		log.log(
			new Map<string, unknown>([
				['a', 1],
				['b', { deep: [1, 2] }]
			]),
			new Set(['x', 'y'])
		);
		log.log(circular, Symbol('token'), 10n, -0, NaN, null, undefined);
		log.dir(document.body);
		log.log(function namedFunction() {}, class Example {}, /ab+c/gi, new Date(0));
	},
	korean: () => {
		log.log('안녕하세요. lognal은 캔버스에 로그를 그리는 뷰어입니다.');
		log.log(
			'한글과 English가 섞인 긴 문장은 공백에서 줄이 바뀝니다. 이 문장은 줄 바꿈을 확인하려고 일부러 길게 썼습니다. 창 크기를 줄여 보세요.'
		);
		log.info('中文日志：服务器已启动。日本語のログ：サーバーが起動しました。');
		log.log('Emoji 👍 🇰🇷 👩‍💻 and full-width ＡＢＣ');
		log.log({ 이름: '홍길동', 도시: '서울', 태그: ['개발', '로그'] });
		log.warn('자모 분리형 한글: ' + '한글'.normalize('NFD'));
	},
	group: () => {
		log.group('Request %s', '/api/users');
		log.log('Headers', { accept: 'application/json' });
		log.groupCollapsed('Response');
		log.log('Status', 200);
		log.groupEnd();
		log.groupEnd();
		log.table([
			{ name: 'Alice', role: 'admin', active: true },
			{ name: '김철수', role: 'editor', active: false }
		]);
		log.count();
		log.count();
		log.time('task');
		log.timeEnd('task');
		log.assert(false, 'Something is %s', 'wrong');
		log.trace('Trace here');
	},
	ansi: () => {
		viewer.writeLines(
			'\x1b[32m✔\x1b[0m build finished in \x1b[1m1.2s\x1b[0m\n\x1b[33mwarning\x1b[0m unused variable\n\x1b[31;1merror\x1b[0m \x1b[4mmissing semicolon\x1b[0m\n\x1b[38;5;208m256 color\x1b[0m and \x1b[38;2;120;200;255mtrue color\x1b[0m',
			{ ansi: true }
		);
	},
	burst: () => {
		const started = performance.now();

		for (let index = 0; index < 10000; index++) {
			log.log(
				`Line ${index} - request handled in ${Math.round(Math.random() * 100)}ms`,
				index % 50 === 0 ? { index } : ''
			);
		}

		log.info(`Logged 10,000 lines in ${Math.round(performance.now() - started)}ms`);
	}
};

let stream: ReturnType<typeof setInterval> | undefined;

document.querySelector('.playground-actions')?.addEventListener('click', (event) => {
	const button = (event.target as HTMLElement).closest('button');
	const action = button?.dataset.action;

	if (action === 'stream' && button) {
		if (stream) {
			clearInterval(stream);
			stream = undefined;
			button.textContent = 'Start stream';
		} else {
			let count = 0;

			stream = setInterval(() => {
				const level = count % 17 === 0 ? 'warn' : count % 31 === 0 ? 'error' : 'log';

				log[level](`Stream message ${count++}`, { at: Date.now() });
			}, 50);
			button.textContent = 'Stop stream';
		}

		return;
	}

	if (action && actions[action]) {
		actions[action]();
	}
});

document.querySelector('[data-action="theme"]')?.addEventListener('change', (event) => {
	viewer.setOptions({ theme: (event.target as HTMLSelectElement).value as ThemeMode });
});

document.querySelector('[data-action="file"]')?.addEventListener('change', async (event) => {
	const file = (event.target as HTMLInputElement).files?.[0];

	if (file) {
		const result = await readTextFile(file, viewer.store);

		log.info(`Read ${result.lines} lines from ${file.name} as ${result.encoding}`);
	}
});

actions.basic();
