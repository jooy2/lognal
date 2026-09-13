<script setup lang="ts">
/**
 * A working lognal viewer with a few buttons that write sample logs.
 *
 * lognal draws on a canvas and reads the page's CSS, so it only runs in the browser. The
 * library is imported when the component mounts, and the page wraps the component in
 * `<ClientOnly>`. `lognal` resolves to the repository source through the alias in `config.mts`.
 */
import type { LognalConsole, LogViewer, LogViewerOptions } from 'lognal';
import { useData } from 'vitepress';
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';

type Preset = 'console' | 'values' | 'korean' | 'input';
type Locale = 'en' | 'ko';

interface DemoAction {
	label: Record<Locale, string>;
	run: (log: LognalConsole) => void;
}

interface DemoPreset {
	options?: LogViewerOptions;
	start: (log: LognalConsole, locale: Locale) => void;
	actions: DemoAction[];
}

const props = withDefaults(defineProps<{ preset?: Preset; height?: number }>(), {
	preset: 'console',
	height: 360
});

const runCommand = (command: string): unknown => {
	const [name, ...words] = command.trim().split(/\s+/);

	if (name === 'help') {
		return 'Commands: echo <text>, time, json, error';
	}

	if (name === 'echo') {
		return words.join(' ');
	}

	if (name === 'time') {
		return new Date();
	}

	if (name === 'json') {
		return { command, words, length: command.length };
	}

	if (name === 'error') {
		throw new TypeError('This command always fails');
	}

	return new Promise((resolve) => {
		setTimeout(() => resolve(`Unknown command: ${name}`), 300);
	});
};

const PRESETS: Record<Preset, DemoPreset> = {
	console: {
		start: (log) => {
			log.log('Server started on port %d', 8080);
			log.info('Connected to %s in %fms', 'database', 12.5);
			log.debug('Cache hit ratio', 0.93);
			log.warn('The %s option is deprecated', 'legacyMode');
			log.error(new Error('Failed to load the user profile'));
			log.log('%cStyled%c text', 'color: #43d786; font-weight: bold', '');
		},
		actions: [
			{
				label: { en: 'Log', ko: '로그' },
				run: (log) => log.log('Request handled in %dms', Math.round(Math.random() * 120))
			},
			{
				label: { en: 'Warning', ko: '경고' },
				run: (log) => log.warn('Disk usage is at %d%%', 91)
			},
			{
				label: { en: 'Error', ko: '오류' },
				run: (log) => log.error(new RangeError('Retry limit reached'))
			},
			{
				label: { en: '1,000 lines', ko: '1,000줄' },
				run: (log) => {
					for (let index = 0; index < 1000; index++) {
						log.log(`Line ${index} handled in ${Math.round(Math.random() * 100)}ms`);
					}
				}
			}
		]
	},
	values: {
		start: (log) => {
			log.log('user', { id: 1, name: 'lognal', roles: ['admin', 'editor'], active: true });
			log.log([1, 2, 3, { nested: true }, [4, 5]]);
			log.log(
				new Map<string, unknown>([
					['a', 1],
					['b', { deep: [1, 2] }]
				]),
				new Set(['x', 'y'])
			);
			log.error(new TypeError('Expected a string, received a number'));
		},
		actions: [
			{
				label: { en: 'Table', ko: '표' },
				run: (log) =>
					log.table([
						{ name: 'Alice', role: 'admin', active: true },
						{ name: 'Bob', role: 'editor', active: false }
					])
			},
			{
				label: { en: 'Group', ko: '그룹' },
				run: (log) => {
					log.group('Request %s', '/api/users');
					log.log('Headers', { accept: 'application/json' });
					log.groupCollapsed('Response');
					log.log('Status', 200);
					log.groupEnd();
					log.groupEnd();
				}
			},
			{
				label: { en: 'Element', ko: '요소' },
				run: (log) => {
					const nav = document.createElement('nav');
					const link = document.createElement('a');

					nav.className = 'menu';
					link.href = '/';
					link.textContent = 'Home';
					nav.append(link);
					log.log(nav);
				}
			},
			{
				label: { en: 'Circular', ko: '순환 참조' },
				run: (log) => {
					const node: Record<string, unknown> = { name: 'node' };

					node.self = node;
					log.log(node, Symbol('token'), 10n, -0, null, undefined);
				}
			}
		]
	},
	korean: {
		start: (log) => {
			log.log('안녕하세요. lognal은 캔버스에 로그를 그리는 뷰어입니다.');
			log.info('中文日志：服务器已启动。日本語のログ：サーバーが起動しました。');
			log.log({ 이름: '홍길동', 도시: '서울', 태그: ['개발', '로그'] });
		},
		actions: [
			{
				label: { en: 'Long sentence', ko: '긴 문장' },
				run: (log) =>
					log.log(
						'한글과 English가 섞인 긴 문장은 공백에서 줄이 바뀝니다. 창 너비를 줄이면 한글 낱말이 중간에서 잘리지 않고 통째로 다음 줄로 넘어갑니다.'
					)
			},
			{
				label: { en: 'Emoji', ko: '이모지' },
				run: (log) => {
					// Two emoji joined by U+200D, built here so the file holds no invisible character.
					const technologist = ['👩', '💻'].join(String.fromCharCode(0x200d));

					log.log(`Emoji 👍 🇰🇷 ${technologist} and full-width ＡＢＣ`);
				}
			},
			{
				label: { en: 'Decomposed Hangul', ko: '풀어쓴 한글' },
				run: (log) => log.warn(`macOS file name: ${'한글 로그.txt'.normalize('NFD')}`)
			}
		]
	},
	input: {
		options: {
			input: { onSubmit: runCommand }
		},
		start: (log, locale) => {
			log.info(
				locale === 'ko' ? 'help를 입력하고 Enter 키를 누르세요.' : 'Type help and press Enter.'
			);
		},
		actions: [
			{
				label: { en: 'Message from the server', ko: '서버 메시지' },
				run: (log) => log.info('Message from the server', { at: new Date().toISOString() })
			}
		]
	}
};

const { isDark, localeIndex } = useData();
const locale = computed<Locale>(() => (localeIndex.value === 'ko' ? 'ko' : 'en'));
const preset = computed(() => PRESETS[props.preset]);
const container = ref<HTMLElement | null>(null);
const ready = ref(false);

let viewer: LogViewer | null = null;
let unmounted = false;

const themeOf = (dark: boolean): 'dark' | 'light' => (dark ? 'dark' : 'light');

const handleAction = (action: DemoAction): void => {
	if (viewer) {
		action.run(viewer.console);
	}
};

onMounted(async () => {
	const [{ LogViewer: Viewer }] = await Promise.all([import('lognal'), import('lognal/style.css')]);

	if (unmounted || !container.value) {
		return;
	}

	viewer = new Viewer(container.value, {
		...preset.value.options,
		theme: themeOf(isDark.value),
		locale: locale.value
	});
	preset.value.start(viewer.console, locale.value);
	ready.value = true;
});

watch(isDark, (dark) => {
	viewer?.setOptions({ theme: themeOf(dark) });
});

onBeforeUnmount(() => {
	unmounted = true;
	viewer?.dispose();
	viewer = null;
});
</script>

<template>
	<div class="live-viewer">
		<div
			class="live-viewer-actions"
			role="group"
			:aria-label="locale === 'ko' ? '예제 로그 쓰기' : 'Write sample logs'"
		>
			<button
				v-for="action in preset.actions"
				:key="action.label.en"
				type="button"
				:disabled="!ready"
				@click="handleAction(action)"
			>
				{{ action.label[locale] }}
			</button>
		</div>
		<div ref="container" class="live-viewer-screen" :style="{ height: `${height}px` }"></div>
	</div>
</template>

<style scoped>
.live-viewer {
	margin: 16px 0;
}

.live-viewer-actions {
	display: flex;
	flex-wrap: wrap;
	gap: 8px;
	margin-bottom: 12px;
}

.live-viewer-actions button {
	min-height: 36px;
	padding: 0 14px;
	color: var(--vp-c-text-1);
	background-color: var(--vp-c-bg-soft);
	border: 1px solid var(--vp-c-divider);
	border-radius: 8px;
	font-size: 14px;
	font-weight: 500;
}

.live-viewer-actions button:hover:enabled {
	border-color: var(--vp-c-brand-1);
}

.live-viewer-actions button:focus-visible {
	outline: 2px solid var(--vp-c-brand-1);
	outline-offset: 2px;
}

.live-viewer-actions button:disabled {
	cursor: default;
	opacity: 0.6;
}
</style>
