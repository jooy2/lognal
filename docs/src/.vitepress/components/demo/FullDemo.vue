<script setup lang="ts">
/**
 * The demo page: a viewer with every option, buttons that write each kind of log, text files, the
 * input line, and the methods and events of `LogViewer`.
 *
 * Like `LiveViewer`, it imports lognal when it mounts, because the viewer draws on a canvas and
 * reads the page's CSS. The page wraps it in `<ClientOnly>`.
 */
import type {
	EntryMenuOptions,
	FileHandleLike,
	FollowHandle,
	InputOptions,
	LinkClick,
	LogFilter,
	LogLevel,
	LogViewer,
	LogViewerOptions,
	SelectionMode,
	ThemeMode,
	TimestampFormat,
	ToolbarOptions,
	ViewerLabels,
	WrapMode
} from 'lognal';
import { useData } from 'vitepress';
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue';

import {
	formatMessage,
	MESSAGES,
	type DemoLocale,
	type Messages,
	type MessageValues
} from './messages';
import {
	createSampleFile,
	runCommand,
	SAMPLE_GROUPS,
	writeStreamMessage,
	type Notice,
	type Sample,
	type SampleContext,
	type SampleFileKey
} from './samples';

type Lognal = typeof import('lognal');
type ThemeChoice = 'site' | ThemeMode;
type LocaleChoice = 'site' | 'en' | 'ko' | 'de';
type TimestampChoice = 'off' | 'time' | 'datetime' | 'iso' | 'elapsed';
type ViewerSettings = Omit<LogViewerOptions, 'store' | 'renderer'>;
type PickerWindow = Window & {
	showOpenFilePicker?: () => Promise<(FileHandleLike & { name: string })[]>;
};

interface DemoEvent {
	id: number;
	name: string;
	detail: string;
}

const LEVELS: LogLevel[] = ['debug', 'log', 'info', 'warn', 'error'];
const SAMPLE_FILE_KEYS: SampleFileKey[] = ['utf8-file', 'utf16-file', 'euckr-file'];
const FALLBACK_ENCODINGS = ['euc-kr', 'shift_jis', 'big5', 'gbk', 'windows-1252'];
const FONT_FAMILIES = [
	"Menlo, Consolas, 'DejaVu Sans Mono', monospace",
	"'Courier New', Courier, monospace",
	"D2Coding, 'Noto Sans Mono CJK KR', monospace",
	"'JetBrains Mono', 'Cascadia Mono', 'Fira Mono', monospace"
];
const LOCALE_NAMES: Record<Exclude<LocaleChoice, 'site'>, string> = {
	en: 'English',
	ko: '한국어',
	de: 'Deutsch'
};
const MAX_ENTRIES = [1000, 10000, 100000, Infinity];
const MAX_CLUSTERS = [200, 10000, 100000];
const LINE_HEIGHTS = [1.2, 1.4, 1.6, 1.8, 2];
const TAB_SIZES = [2, 4, 8];
const STREAM_RATES = [10, 100, 1000];
const STREAM_TICK = 50;
const MAX_EVENTS = 12;
const MAX_EVENT_DETAIL = 80;
const DEFAULT_APPEARANCE = {
	fontFamily: '',
	fontSize: 13,
	lineHeight: 1.6,
	accent: '',
	radius: 10
};
const PAGE_OPENED_AT = Date.now();

const { isDark, localeIndex } = useData();
const siteLocale = computed<DemoLocale>(() => (localeIndex.value === 'ko' ? 'ko' : 'en'));
const numberFormat = computed(() => new Intl.NumberFormat(siteLocale.value));

const t = <Group extends keyof Messages>(
	group: Group,
	key: keyof Messages[Group],
	values?: MessageValues
): string => {
	return formatMessage(MESSAGES[siteLocale.value][group][key] as string, values);
};

const notice: Notice = (key, values) => t('notice', key, values);
const formatNumber = (value: number): string => numberFormat.value.format(value);

const settings = reactive({
	theme: 'site' as ThemeChoice,
	locale: 'site' as LocaleChoice,
	customLabels: false,
	timestamps: 'time' as TimestampChoice,
	statusBar: true,
	entryMenu: true,
	search: true,
	linkClick: 'confirm' as LinkClick,
	selectionMode: 'text' as SelectionMode,
	secondViewer: false,
	toolbar: true,
	toolbarControls: {
		follow: true,
		clear: true,
		scroll: true,
		wrap: true,
		selectionMode: true,
		filter: true,
		levels: true
	} as ToolbarOptions,
	wrap: 'word' as WrapMode,
	tabSize: 8,
	ambiguousWidth: 1 as 1 | 2,
	maxEntries: 10000,
	maxClusters: 10000,
	mergeRepeats: true,
	links: true,
	...DEFAULT_APPEARANCE,
	input: true,
	prompt: '>',
	echo: true
});

const filterForm = reactive({
	text: '',
	regex: false,
	caseSensitive: false,
	minLevel: '' as LogLevel | '',
	levels: [] as LogLevel[]
});

const container = ref<HTMLElement | null>(null);
const secondContainer = ref<HTMLElement | null>(null);
const ready = ref(false);
const following = ref(true);
const hooked = ref(false);
const streaming = ref(false);
const streamRate = ref(100);
const fallbackEncoding = ref('');
const reading = ref(false);
const readProgress = ref(0);
const canFollowFiles = ref(false);
const followingFile = ref(false);
const checkpointId = ref<number | null>(null);
const events = ref<DemoEvent[]>([]);

let lognal: Lognal | null = null;
let viewer: LogViewer | null = null;
let secondViewer: LogViewer | null = null;
let unhookConsole: (() => void) | null = null;
let streamTimer: ReturnType<typeof setInterval> | undefined;
let streamBudget = 0;
let streamIndex = 0;
let readController: AbortController | null = null;
let followHandle: FollowHandle | null = null;
let nextEventId = 0;
let unmounted = false;

const viewerTheme = (): ThemeMode => {
	if (settings.theme === 'site') {
		return isDark.value ? 'dark' : 'light';
	}

	return settings.theme;
};

const viewerLocale = (): string =>
	settings.locale === 'site' ? siteLocale.value : settings.locale;

/** A timestamp of the same length every time, as the `timestamps` option asks of a function. */
const formatElapsed = (time: number): string => {
	const seconds = (time - PAGE_OPENED_AT) / 1000;
	const sign = seconds < 0 ? '-' : '+';

	return `${sign}${Math.abs(seconds).toFixed(3).padStart(9, '0')}s`;
};

const viewerTimestamps = (): boolean | TimestampFormat => {
	if (settings.timestamps === 'off') {
		return false;
	}

	if (settings.timestamps === 'elapsed') {
		return formatElapsed;
	}

	return settings.timestamps;
};

const viewerLabels = (): Partial<ViewerLabels> => {
	if (!settings.customLabels) {
		return {};
	}

	return {
		filter: t('label', 'filter'),
		following: t('label', 'following'),
		paused: t('label', 'paused'),
		entries: (shown, total, format) => {
			return t('label', 'entries', { shown: format(shown), total: format(total) });
		}
	};
};

const viewerToolbar = (): boolean | Partial<ToolbarOptions> => {
	return settings.toolbar ? { ...settings.toolbarControls } : false;
};

/** The entry menu, with two items of the demo after the built-in ones. */
const viewerEntryMenu = (): boolean | EntryMenuOptions => {
	if (!settings.entryMenu) {
		return false;
	}

	return {
		items: (entry) => [
			{
				label: t('menu', 'only-level'),
				onSelect: (_, target) => target.setFilter({ levels: [entry.level] })
			},
			{
				label: t('menu', 'add-event'),
				onSelect: (item, target) => addEvent('entryMenu', target.getEntryText(item.id))
			}
		]
	};
};

const viewerInput = (): InputOptions | null => {
	if (!settings.input) {
		return null;
	}

	return {
		onSubmit: (command, target) => runCommand(command, target, notice),
		prompt: settings.prompt,
		echo: settings.echo
	};
};

const initialOptions = (): LogViewerOptions => ({
	theme: viewerTheme(),
	locale: viewerLocale(),
	labels: viewerLabels(),
	timestamps: viewerTimestamps(),
	statusBar: settings.statusBar,
	entryMenu: viewerEntryMenu(),
	search: settings.search,
	linkClick: settings.linkClick,
	selectionMode: settings.selectionMode,
	toolbar: viewerToolbar(),
	input: viewerInput(),
	core: {
		wrap: settings.wrap,
		tabSize: settings.tabSize,
		ambiguousWidth: settings.ambiguousWidth,
		maxEntries: settings.maxEntries,
		maxClusters: settings.maxClusters,
		mergeRepeats: settings.mergeRepeats,
		links: settings.links
	}
});

const applyOptions = (options: ViewerSettings): void => {
	viewer?.setOptions(options);
};

const addEvent = (name: string, value: unknown): void => {
	let detail = typeof value === 'string' ? value : (JSON.stringify(value) ?? String(value));

	if (detail.length > MAX_EVENT_DETAIL) {
		detail = `${detail.slice(0, MAX_EVENT_DETAIL)}…`;
	}

	const [latest] = events.value;

	// Dragging a selection reports every step. Keep only the latest one.
	if (latest && latest.name === name && name === 'selection') {
		latest.detail = detail;

		return;
	}

	events.value = [{ id: nextEventId++, name, detail }, ...events.value].slice(0, MAX_EVENTS);
};

const onFilterChange = (filter: LogFilter | null): void => {
	filterForm.text = filter?.text ?? '';
	filterForm.regex = filter?.regex ?? false;
	filterForm.caseSensitive = filter?.caseSensitive ?? false;
	filterForm.minLevel = filter?.minLevel ?? '';
	filterForm.levels = [...(filter?.levels ?? [])];
	addEvent('filter', filter);
};

const sampleContext = (): SampleContext | null => {
	if (!viewer) {
		return null;
	}

	return { viewer, log: viewer.console, notice, formatNumber };
};

const handleSample = (sample: Sample): void => {
	const context = sampleContext();

	if (context) {
		sample.run(context);
	}
};

const handleCallPageConsole = (): void => {
	console.log(notice('page-console'), { at: new Date().toISOString() });
	console.warn(notice('page-console'), ['console', 'warn']);
};

const stopStream = (): void => {
	clearInterval(streamTimer);
	streamTimer = undefined;
	streamBudget = 0;
	streaming.value = false;
};

const handleToggleStream = (): void => {
	if (streaming.value) {
		stopStream();

		return;
	}

	streamTimer = setInterval(() => {
		if (!viewer) {
			return;
		}

		streamBudget += (streamRate.value * STREAM_TICK) / 1000;

		while (streamBudget >= 1) {
			streamBudget -= 1;
			writeStreamMessage(viewer.console, streamIndex++);
		}
	}, STREAM_TICK);
	streaming.value = true;
};

const readFile = async (file: File): Promise<void> => {
	if (!viewer || !lognal) {
		return;
	}

	readController?.abort();

	const controller = new AbortController();
	const log = viewer.console;

	readController = controller;
	reading.value = true;
	readProgress.value = 0;

	try {
		const result = await lognal.readTextFile(file, viewer.store, {
			fallbackEncoding: fallbackEncoding.value || undefined,
			signal: controller.signal,
			onProgress: (loaded, total) => {
				readProgress.value = total > 0 ? loaded / total : 1;
			}
		});

		log.info(
			notice('file-read', {
				name: file.name,
				encoding: result.encoding,
				lines: formatNumber(result.lines),
				bytes: formatNumber(result.bytes)
			})
		);
	} catch (error) {
		log.error(notice('file-error'), error);
	} finally {
		if (readController === controller) {
			readController = null;
			reading.value = false;
		}
	}
};

const handleFileChange = (event: Event): void => {
	const input = event.target as HTMLInputElement;
	const file = input.files?.[0];

	if (file) {
		void readFile(file);
	}

	// Picking the same file again should read it again.
	input.value = '';
};

const handleSampleFile = (key: SampleFileKey): void => {
	void readFile(createSampleFile(key));
};

const handleCancelRead = (): void => {
	readController?.abort();
};

const stopFollowing = (): void => {
	followHandle?.stop();
	followHandle = null;
	followingFile.value = false;
};

const handleFollowFile = async (): Promise<void> => {
	const pickerWindow = window as PickerWindow;

	if (!pickerWindow.showOpenFilePicker || !viewer || !lognal) {
		return;
	}

	let handle: (FileHandleLike & { name: string }) | undefined;

	try {
		[handle] = await pickerWindow.showOpenFilePicker();
	} catch {
		// The picker was closed without a file.
		return;
	}

	if (!handle || !viewer) {
		return;
	}

	const log = viewer.console;

	stopFollowing();
	followHandle = lognal.followTextFile(handle, viewer.store, {
		fallbackEncoding: fallbackEncoding.value || undefined,
		onReset: () => log.info(notice('follow-reset')),
		onError: (error) => log.warn(notice('follow-error'), error)
	});
	followingFile.value = true;

	try {
		const lines = await followHandle.ready;

		log.info(notice('follow-ready', { name: handle.name, lines: formatNumber(lines) }));
	} catch (error) {
		log.error(notice('follow-error'), error);
	}
};

const handleStopFollowing = (): void => {
	stopFollowing();
	viewer?.console.info(notice('follow-stopped'));
};

const handleApplyFilter = (): void => {
	const filter: LogFilter = {
		text: filterForm.text,
		regex: filterForm.regex,
		caseSensitive: filterForm.caseSensitive
	};

	if (filterForm.levels.length > 0) {
		filter.levels = [...filterForm.levels];
	} else if (filterForm.minLevel) {
		filter.minLevel = filterForm.minLevel;
	}

	viewer?.setFilter(filter);
};

const handleResetFilter = (): void => {
	viewer?.setFilter(null);
};

const handleAddCheckpoint = (): void => {
	const entry = viewer?.store.write(
		`${notice('checkpoint')} ${new Date().toLocaleTimeString(siteLocale.value)}`,
		{
			level: 'info'
		}
	);

	checkpointId.value = entry?.id ?? null;
};

const handleGoToCheckpoint = (): void => {
	if (viewer && checkpointId.value !== null) {
		viewer.scrollToEntry(checkpointId.value);
	}
};

const handleCopy = async (): Promise<void> => {
	if (viewer) {
		addEvent('copySelection()', await viewer.copySelection());
	}
};

const handleResetAppearance = (): void => {
	Object.assign(settings, DEFAULT_APPEARANCE);
};

/**
 * Sets the font and color properties on the viewer's root element and reads them again. Setting
 * them in CSS, rather than with the `font` option, also changes the input line.
 */
const applyAppearance = (): void => {
	if (!viewer) {
		return;
	}

	const style = viewer.element.style;
	const properties: Record<string, string> = {
		'--lognal-font-family': settings.fontFamily,
		'--lognal-font-size': `${settings.fontSize}px`,
		'--lognal-line-height': String(settings.lineHeight),
		'--lognal-accent': settings.accent,
		'--lognal-focus-ring': settings.accent,
		'--lognal-radius': `${settings.radius}px`
	};

	for (const [name, value] of Object.entries(properties)) {
		if (value) {
			style.setProperty(name, value);
		} else {
			style.removeProperty(name);
		}
	}

	viewer.refresh();
};

const mountSecondViewer = (): void => {
	if (!lognal || !viewer || !secondContainer.value || secondViewer) {
		return;
	}

	secondViewer = new lognal.LogViewer(secondContainer.value, {
		store: viewer.store,
		theme: viewerTheme(),
		locale: viewerLocale(),
		toolbar: false,
		timestamps: false,
		core: { filter: { minLevel: 'warn' } }
	});
};

const disposeSecondViewer = (): void => {
	secondViewer?.dispose();
	secondViewer = null;
};

watch([() => settings.theme, isDark], () => {
	const theme = viewerTheme();

	viewer?.setOptions({ theme });
	secondViewer?.setOptions({ theme });
});

watch([() => settings.locale, () => settings.customLabels, siteLocale], () => {
	const locale = viewerLocale();

	applyOptions({ locale, labels: viewerLabels() });
	secondViewer?.setOptions({ locale });
});

watch(
	() => settings.timestamps,
	() => applyOptions({ timestamps: viewerTimestamps() })
);
watch(
	() => settings.statusBar,
	(statusBar) => applyOptions({ statusBar })
);
watch(
	() => settings.search,
	(search) => applyOptions({ search })
);
watch(
	() => settings.linkClick,
	(linkClick) => applyOptions({ linkClick })
);
watch(
	() => settings.selectionMode,
	(selectionMode) => applyOptions({ selectionMode })
);
watch(
	() => settings.entryMenu,
	() => applyOptions({ entryMenu: viewerEntryMenu() })
);
watch(
	[() => settings.toolbar, () => settings.toolbarControls],
	() => applyOptions({ toolbar: viewerToolbar() }),
	{ deep: true }
);
watch(
	() => settings.wrap,
	(wrap) => applyOptions({ core: { wrap } })
);
watch(
	() => settings.tabSize,
	(tabSize) => applyOptions({ core: { tabSize } })
);
watch(
	() => settings.ambiguousWidth,
	(ambiguousWidth) => applyOptions({ core: { ambiguousWidth } })
);
watch(
	() => settings.maxEntries,
	(maxEntries) => applyOptions({ core: { maxEntries } })
);
watch(
	() => settings.maxClusters,
	(maxClusters) => applyOptions({ core: { maxClusters } })
);
watch(
	() => settings.mergeRepeats,
	(mergeRepeats) => applyOptions({ core: { mergeRepeats } })
);
watch(
	() => settings.links,
	(links) => applyOptions({ core: { links } })
);
watch([() => settings.input, () => settings.prompt, () => settings.echo], () => {
	applyOptions({ input: viewerInput() });
});
watch(
	[
		() => settings.fontFamily,
		() => settings.fontSize,
		() => settings.lineHeight,
		() => settings.accent,
		() => settings.radius
	],
	applyAppearance
);

// `post` runs after the second container is added to or removed from the page.
watch(
	() => settings.secondViewer,
	(visible) => (visible ? mountSecondViewer() : disposeSecondViewer()),
	{ flush: 'post' }
);

watch(hooked, (on) => {
	unhookConsole?.();
	unhookConsole = null;

	if (on && viewer) {
		unhookConsole = viewer.hookConsole();
	}
});

onMounted(async () => {
	const [module] = await Promise.all([import('lognal'), import('lognal/style.css')]);

	if (unmounted || !container.value) {
		return;
	}

	lognal = module;
	viewer = new module.LogViewer(container.value, initialOptions());
	viewer.on('follow', (value) => {
		following.value = value;
		addEvent('follow', value);
	});
	viewer.on('filter', onFilterChange);
	viewer.on('selection', (text) => addEvent('selection', text));
	canFollowFiles.value = typeof (window as PickerWindow).showOpenFilePicker === 'function';
	ready.value = true;
	viewer.console.info(notice('ready'));
	SAMPLE_GROUPS[0].samples[0].run({ viewer, log: viewer.console, notice, formatNumber });
});

onBeforeUnmount(() => {
	unmounted = true;
	stopStream();
	readController?.abort();
	stopFollowing();
	unhookConsole?.();
	disposeSecondViewer();
	viewer?.dispose();
	viewer = null;
});
</script>

<template>
	<div class="demo">
		<div class="demo-stage">
			<div ref="container" class="demo-screen" :class="{ 'is-split': settings.secondViewer }"></div>
			<div v-if="settings.secondViewer" class="demo-second">
				<p class="demo-caption">{{ t('hint', 'second-viewer') }}</p>
				<div ref="secondContainer" class="demo-second-screen"></div>
			</div>
		</div>

		<div class="demo-controls">
			<section aria-labelledby="demo-samples">
				<h2 id="demo-samples">{{ t('heading', 'samples') }}</h2>

				<details v-for="group in SAMPLE_GROUPS" :key="group.key" class="demo-panel" open>
					<summary>{{ t('panel', group.key) }}</summary>
					<div class="demo-buttons">
						<button
							v-for="sample in group.samples"
							:key="sample.key"
							type="button"
							:disabled="!ready"
							@click="handleSample(sample)"
						>
							{{ t('sample', sample.key) }}
						</button>
					</div>

					<template v-if="group.key === 'console'">
						<label class="demo-check">
							<input v-model="hooked" type="checkbox" :disabled="!ready" />
							{{ t('control', 'hook') }}
						</label>
						<p class="demo-hint">{{ t('hint', 'hook') }}</p>
						<div class="demo-buttons">
							<button type="button" :disabled="!hooked" @click="handleCallPageConsole">
								{{ t('control', 'call-page-console') }}
							</button>
						</div>
					</template>

					<template v-if="group.key === 'volume'">
						<div class="demo-row">
							<label class="demo-field">
								<span>{{ t('control', 'stream-rate') }}</span>
								<select v-model="streamRate">
									<option v-for="rate in STREAM_RATES" :key="rate" :value="rate">
										{{ formatNumber(rate) }}
									</option>
								</select>
							</label>
							<button
								type="button"
								:class="{ 'is-active': streaming }"
								:disabled="!ready"
								@click="handleToggleStream"
							>
								{{ streaming ? t('control', 'stream-stop') : t('control', 'stream-start') }}
							</button>
						</div>
						<p class="demo-hint">{{ t('hint', 'volume') }}</p>
					</template>
				</details>

				<details class="demo-panel" open>
					<summary>{{ t('panel', 'files') }}</summary>
					<div class="demo-row">
						<label class="demo-field">
							<span>{{ t('control', 'fallback') }}</span>
							<select v-model="fallbackEncoding">
								<option value="">{{ t('control', 'fallback-browser') }}</option>
								<option v-for="encoding in FALLBACK_ENCODINGS" :key="encoding" :value="encoding">
									{{ encoding }}
								</option>
							</select>
						</label>
					</div>
					<div class="demo-buttons">
						<label class="demo-file" :class="{ 'is-disabled': !ready }">
							<input type="file" :disabled="!ready" @change="handleFileChange" />
							{{ t('control', 'open-file') }}
						</label>
						<button
							v-for="key in SAMPLE_FILE_KEYS"
							:key="key"
							type="button"
							:disabled="!ready"
							@click="handleSampleFile(key)"
						>
							{{ t('sample', key) }}
						</button>
					</div>
					<div v-if="reading" class="demo-row">
						<label class="demo-field is-wide">
							<span>{{ t('control', 'progress') }}</span>
							<progress :value="readProgress" max="1"></progress>
						</label>
						<button type="button" @click="handleCancelRead">{{
							t('control', 'cancel-read')
						}}</button>
					</div>
					<p class="demo-hint">{{ t('hint', 'files') }}</p>
					<div class="demo-buttons">
						<button
							v-if="!followingFile"
							type="button"
							:disabled="!ready || !canFollowFiles"
							@click="handleFollowFile"
						>
							{{ t('control', 'follow-file') }}
						</button>
						<button v-else type="button" @click="handleStopFollowing">
							{{ t('control', 'stop-follow') }}
						</button>
					</div>
					<p class="demo-hint">
						{{ canFollowFiles ? t('hint', 'follow') : t('hint', 'follow-unsupported') }}
					</p>
				</details>
			</section>

			<section aria-labelledby="demo-options">
				<h2 id="demo-options">{{ t('heading', 'options') }}</h2>

				<details class="demo-panel" open>
					<summary>{{ t('panel', 'viewer') }}</summary>
					<div class="demo-fields">
						<label class="demo-field">
							<span>{{ t('control', 'theme') }}</span>
							<select v-model="settings.theme">
								<option value="site">{{ t('common', 'same-as-site') }}</option>
								<option value="auto">{{ t('control', 'theme-auto') }}</option>
								<option value="light">{{ t('control', 'theme-light') }}</option>
								<option value="dark">{{ t('control', 'theme-dark') }}</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'locale') }}</span>
							<select v-model="settings.locale">
								<option value="site">{{ t('common', 'same-as-site') }}</option>
								<option v-for="(name, code) in LOCALE_NAMES" :key="code" :value="code" :lang="code">
									{{ name }}
								</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'timestamps') }}</span>
							<select v-model="settings.timestamps">
								<option value="off">{{ t('common', 'off') }}</option>
								<option value="time">'time'</option>
								<option value="datetime">'datetime'</option>
								<option value="iso">'iso'</option>
								<option value="elapsed">{{ t('control', 'timestamps-elapsed') }}</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'link-click') }}</span>
							<select v-model="settings.linkClick">
								<option value="confirm">{{ t('control', 'link-click-confirm') }}</option>
								<option value="open">{{ t('control', 'link-click-open') }}</option>
								<option value="ignore">{{ t('control', 'link-click-ignore') }}</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'selection-mode') }}</span>
							<select v-model="settings.selectionMode">
								<option value="text">{{ t('control', 'selection-mode-text') }}</option>
								<option value="entry">{{ t('control', 'selection-mode-entry') }}</option>
							</select>
						</label>
					</div>
					<p class="demo-hint">{{ t('hint', 'locale') }}</p>
					<p class="demo-hint">{{ t('hint', 'links') }}</p>
					<p class="demo-hint">{{ t('hint', 'selection-mode') }}</p>
					<label class="demo-check">
						<input v-model="settings.customLabels" type="checkbox" />
						{{ t('control', 'custom-labels') }}
					</label>
					<p class="demo-hint">{{ t('hint', 'custom-labels') }}</p>
					<label class="demo-check">
						<input v-model="settings.statusBar" type="checkbox" />
						{{ t('control', 'status-bar') }}
					</label>
					<label class="demo-check">
						<input v-model="settings.entryMenu" type="checkbox" />
						{{ t('control', 'entry-menu') }}
					</label>
					<p class="demo-hint">{{ t('hint', 'entry-menu') }}</p>
					<label class="demo-check">
						<input v-model="settings.search" type="checkbox" />
						{{ t('control', 'search') }}
					</label>
					<label class="demo-check">
						<input v-model="settings.secondViewer" type="checkbox" :disabled="!ready" />
						{{ t('control', 'second-viewer') }}
					</label>
				</details>

				<details class="demo-panel">
					<summary>{{ t('panel', 'toolbar') }}</summary>
					<label class="demo-check">
						<input v-model="settings.toolbar" type="checkbox" />
						{{ t('control', 'toolbar') }}
					</label>
					<fieldset class="demo-group" :disabled="!settings.toolbar">
						<legend>{{ t('control', 'toolbar-controls') }}</legend>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.follow" type="checkbox" />
							{{ t('control', 'toolbar-follow') }}
						</label>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.clear" type="checkbox" />
							{{ t('control', 'toolbar-clear') }}
						</label>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.scroll" type="checkbox" />
							{{ t('control', 'toolbar-scroll') }}
						</label>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.wrap" type="checkbox" />
							{{ t('control', 'toolbar-wrap') }}
						</label>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.selectionMode" type="checkbox" />
							{{ t('control', 'toolbar-selection-mode') }}
						</label>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.filter" type="checkbox" />
							{{ t('control', 'toolbar-filter') }}
						</label>
						<label class="demo-check">
							<input v-model="settings.toolbarControls.levels" type="checkbox" />
							{{ t('control', 'toolbar-levels') }}
						</label>
					</fieldset>
				</details>

				<details class="demo-panel">
					<summary>{{ t('panel', 'layout') }}</summary>
					<div class="demo-fields">
						<label class="demo-field">
							<span>{{ t('control', 'wrap') }}</span>
							<select v-model="settings.wrap">
								<option value="word">{{ t('control', 'wrap-word') }}</option>
								<option value="char">{{ t('control', 'wrap-char') }}</option>
								<option value="none">{{ t('common', 'off') }}</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'tab-size') }}</span>
							<select v-model="settings.tabSize">
								<option v-for="size in TAB_SIZES" :key="size" :value="size">{{ size }}</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'ambiguous-width') }}</span>
							<select v-model="settings.ambiguousWidth">
								<option :value="1">1</option>
								<option :value="2">2</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'max-entries') }}</span>
							<select v-model="settings.maxEntries">
								<option v-for="count in MAX_ENTRIES" :key="count" :value="count">
									{{ count === Infinity ? t('control', 'unlimited') : formatNumber(count) }}
								</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'max-clusters') }}</span>
							<select v-model="settings.maxClusters">
								<option v-for="count in MAX_CLUSTERS" :key="count" :value="count">
									{{ formatNumber(count) }}
								</option>
							</select>
						</label>
					</div>
					<label class="demo-check">
						<input v-model="settings.mergeRepeats" type="checkbox" />
						{{ t('control', 'merge-repeats') }}
					</label>
					<label class="demo-check">
						<input v-model="settings.links" type="checkbox" />
						{{ t('control', 'links') }}
					</label>
				</details>

				<details class="demo-panel">
					<summary>{{ t('panel', 'appearance') }}</summary>
					<div class="demo-fields">
						<label class="demo-field is-wide">
							<span>{{ t('control', 'font-family') }}</span>
							<select v-model="settings.fontFamily">
								<option value="">{{ t('control', 'font-default') }}</option>
								<option v-for="family in FONT_FAMILIES" :key="family" :value="family">
									{{ family }}
								</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'font-size') }}: {{ settings.fontSize }}px</span>
							<input v-model.number="settings.fontSize" type="range" min="10" max="20" step="1" />
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'line-height') }}</span>
							<select v-model="settings.lineHeight">
								<option v-for="height in LINE_HEIGHTS" :key="height" :value="height">
									{{ height }}
								</option>
							</select>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'accent') }}</span>
							<input
								type="color"
								:value="settings.accent || (isDark ? '#5aa2ff' : '#1f6fd6')"
								@input="settings.accent = ($event.target as HTMLInputElement).value"
							/>
						</label>
						<label class="demo-field">
							<span>{{ t('control', 'radius') }}: {{ settings.radius }}px</span>
							<input v-model.number="settings.radius" type="range" min="0" max="20" step="1" />
						</label>
					</div>
					<p class="demo-hint">{{ t('hint', 'font') }}</p>
					<div class="demo-buttons">
						<button type="button" @click="handleResetAppearance">
							{{ t('control', 'reset-appearance') }}
						</button>
					</div>
				</details>

				<details class="demo-panel">
					<summary>{{ t('panel', 'input') }}</summary>
					<label class="demo-check">
						<input v-model="settings.input" type="checkbox" />
						{{ t('control', 'input') }}
					</label>
					<div class="demo-fields">
						<label class="demo-field">
							<span>{{ t('control', 'prompt') }}</span>
							<input
								v-model.lazy="settings.prompt"
								type="text"
								maxlength="8"
								:disabled="!settings.input"
							/>
						</label>
					</div>
					<label class="demo-check">
						<input v-model="settings.echo" type="checkbox" :disabled="!settings.input" />
						{{ t('control', 'echo') }}
					</label>
					<p class="demo-hint">{{ t('hint', 'input') }}</p>
				</details>
			</section>

			<section aria-labelledby="demo-api">
				<h2 id="demo-api">{{ t('heading', 'api') }}</h2>

				<details class="demo-panel" open>
					<summary>{{ t('panel', 'filter') }}</summary>
					<form class="demo-form" @submit.prevent="handleApplyFilter">
						<div class="demo-fields">
							<label class="demo-field is-wide">
								<span>{{ t('control', 'filter-text') }}</span>
								<input v-model="filterForm.text" type="text" :disabled="!ready" />
							</label>
							<label class="demo-field">
								<span>{{ t('control', 'filter-min-level') }}</span>
								<select v-model="filterForm.minLevel" :disabled="!ready">
									<option value="">{{ t('control', 'filter-all') }}</option>
									<option v-for="level in LEVELS" :key="level" :value="level">{{ level }}</option>
								</select>
							</label>
						</div>
						<label class="demo-check">
							<input v-model="filterForm.regex" type="checkbox" :disabled="!ready" />
							{{ t('control', 'filter-regex') }}
						</label>
						<label class="demo-check">
							<input v-model="filterForm.caseSensitive" type="checkbox" :disabled="!ready" />
							{{ t('control', 'filter-case') }}
						</label>
						<fieldset class="demo-group is-inline" :disabled="!ready">
							<legend>{{ t('control', 'filter-levels') }}</legend>
							<label v-for="level in LEVELS" :key="level" class="demo-check">
								<input v-model="filterForm.levels" type="checkbox" :value="level" />
								{{ level }}
							</label>
						</fieldset>
						<p class="demo-hint">{{ t('hint', 'filter-levels') }}</p>
						<div class="demo-buttons">
							<button type="submit" :disabled="!ready">{{ t('control', 'apply-filter') }}</button>
							<button type="button" :disabled="!ready" @click="handleResetFilter">
								{{ t('control', 'reset-filter') }}
							</button>
						</div>
					</form>
				</details>

				<details class="demo-panel" open>
					<summary>{{ t('panel', 'methods') }}</summary>
					<div class="demo-buttons">
						<button type="button" :disabled="!ready" @click="viewer?.scrollToTop()">
							{{ t('control', 'scroll-top') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.scrollToBottom()">
							{{ t('control', 'scroll-bottom') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.setFollowing(!following)">
							{{ following ? t('control', 'pause') : t('control', 'resume') }}
						</button>
						<button type="button" :disabled="!ready" @click="handleAddCheckpoint">
							{{ t('control', 'add-checkpoint') }}
						</button>
						<button type="button" :disabled="checkpointId === null" @click="handleGoToCheckpoint">
							{{ t('control', 'go-checkpoint') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.selectAll()">
							{{ t('control', 'select-all') }}
						</button>
						<button type="button" :disabled="!ready" @click="handleCopy">
							{{ t('control', 'copy') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.clearSelection()">
							{{ t('control', 'clear-selection') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.focus()">
							{{ t('control', 'focus') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.openSearch()">
							{{ t('control', 'open-search') }}
						</button>
						<button type="button" :disabled="!ready" @click="viewer?.clear()">
							{{ t('control', 'clear') }}
						</button>
					</div>
				</details>

				<details class="demo-panel" open>
					<summary>{{ t('panel', 'events') }}</summary>
					<ol v-if="events.length > 0" class="demo-events">
						<li v-for="event in events" :key="event.id">
							<code>{{ event.name }}</code>
							<span>{{ event.detail }}</span>
						</li>
					</ol>
					<p v-else class="demo-hint">{{ t('hint', 'events-empty') }}</p>
					<div class="demo-buttons">
						<button type="button" :disabled="events.length === 0" @click="events = []">
							{{ t('control', 'clear-events') }}
						</button>
					</div>
				</details>
			</section>
		</div>
	</div>
</template>

<style scoped>
.demo {
	display: grid;
	grid-template-columns: minmax(0, 1fr);
	gap: 24px;
	align-items: start;
}

.demo-stage {
	position: sticky;
	top: 0;
	z-index: 1;
	display: flex;
	flex-direction: column;
	gap: 8px;
	height: 50vh;
	height: 50svh;
	min-height: 280px;
	padding: 8px 0;
	background-color: var(--vp-c-bg);
}

.demo-screen {
	flex: 1;
	min-height: 0;
}

.demo-second {
	display: flex;
	flex-direction: column;
	flex: 0 0 38%;
	min-height: 0;
}

.demo-second-screen {
	flex: 1;
	min-height: 0;
}

.demo-caption {
	margin: 0 0 6px;
	color: var(--vp-c-text-2);
	font-size: 13px;
}

/*
 * On wide screens the demo fills the rest of the page, which `demo.css` sizes to the screen. The
 * viewer stays in place, and only the controls scroll.
 */
@media (min-width: 960px) {
	.demo {
		flex: 1;
		min-height: 0;
		grid-template-columns: minmax(0, 1fr) 360px;
		grid-template-rows: minmax(0, 1fr);
		align-items: stretch;
	}

	.demo-stage {
		position: static;
		height: auto;
		min-height: 0;
		padding: 0;
	}

	.demo-controls {
		min-height: 0;
		overflow-y: auto;
		overscroll-behavior: contain;
		scrollbar-gutter: stable;
		/* Leaves room for the focus outlines of the controls next to the edges. */
		padding: 4px 8px 24px 4px;
	}
}

@media (min-width: 1280px) {
	.demo {
		grid-template-columns: minmax(0, 1fr) 420px;
	}
}

.demo-controls h2 {
	margin: 32px 0 12px;
	font-size: 20px;
	font-weight: 600;
	line-height: 28px;
}

.demo-controls section:first-child h2 {
	margin-top: 0;
}

.demo-panel {
	margin-bottom: 12px;
	padding: 0 16px;
	background-color: var(--vp-c-bg-soft);
	border: 1px solid var(--vp-c-divider);
	border-radius: 8px;
}

.demo-panel[open] {
	padding-bottom: 16px;
}

.demo-panel summary {
	margin: 0 -16px;
	padding: 12px 16px;
	font-weight: 600;
	cursor: pointer;
	border-radius: 8px;
}

.demo-panel summary:focus-visible {
	outline: 2px solid var(--vp-c-brand-1);
	outline-offset: -2px;
}

.demo-buttons,
.demo-row {
	display: flex;
	flex-wrap: wrap;
	gap: 8px;
	margin-top: 12px;
}

.demo-row {
	align-items: flex-end;
}

.demo-panel summary + .demo-buttons,
.demo-panel summary + .demo-fields,
.demo-panel summary + .demo-row,
.demo-panel summary + .demo-check,
.demo-panel summary + .demo-form > .demo-fields {
	margin-top: 0;
}

.demo-fields {
	display: grid;
	grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
	gap: 12px;
	margin: 12px 0;
}

.demo-field {
	display: flex;
	flex-direction: column;
	gap: 4px;
	min-width: 0;
	font-size: 13px;
	color: var(--vp-c-text-2);
}

.demo-field.is-wide {
	grid-column: 1 / -1;
	flex: 1 1 200px;
}

.demo-check {
	display: flex;
	align-items: center;
	gap: 8px;
	margin-top: 8px;
	font-size: 14px;
}

.demo-group {
	margin: 12px 0 0;
	padding: 4px 12px 12px;
	border: 1px solid var(--vp-c-divider);
	border-radius: 8px;
}

.demo-group legend {
	padding: 0 4px;
	font-size: 13px;
	color: var(--vp-c-text-2);
}

.demo-group.is-inline {
	display: flex;
	flex-wrap: wrap;
	column-gap: 16px;
}

.demo-group:disabled {
	opacity: 0.6;
}

.demo-hint {
	margin: 8px 0 0;
	color: var(--vp-c-text-2);
	font-size: 13px;
	line-height: 1.5;
}

.demo button,
.demo-file {
	display: inline-flex;
	align-items: center;
	min-height: 36px;
	padding: 0 12px;
	color: var(--vp-c-text-1);
	background-color: var(--vp-c-bg);
	border: 1px solid var(--vp-c-divider);
	border-radius: 8px;
	font-size: 14px;
	font-weight: 500;
	cursor: pointer;
}

.demo button:hover:enabled,
.demo-file:hover:not(.is-disabled) {
	border-color: var(--vp-c-brand-1);
}

.demo button.is-active {
	color: var(--vp-c-brand-1);
	background-color: var(--vp-c-brand-soft);
	border-color: var(--vp-c-brand-1);
}

.demo button:disabled,
.demo-file.is-disabled {
	cursor: default;
	opacity: 0.6;
}

.demo-file {
	/* Keeps the hidden input inside the label, so it does not stretch the page or the controls. */
	position: relative;
}

.demo-file input {
	position: absolute;
	width: 1px;
	height: 1px;
	overflow: hidden;
	clip-path: inset(50%);
	white-space: nowrap;
}

.demo button:focus-visible,
.demo-file:focus-within {
	outline: 2px solid var(--vp-c-brand-1);
	outline-offset: 2px;
}

.demo select,
.demo input[type='text'] {
	min-height: 36px;
	width: 100%;
	padding: 0 8px;
	color: var(--vp-c-text-1);
	background-color: var(--vp-c-bg);
	border: 1px solid var(--vp-c-divider);
	border-radius: 8px;
	font-size: 14px;
}

.demo select:focus-visible,
.demo input:focus-visible {
	outline: 2px solid var(--vp-c-brand-1);
	outline-offset: 1px;
}

.demo input[type='checkbox'] {
	width: 16px;
	height: 16px;
	accent-color: var(--vp-c-brand-1);
}

.demo input[type='range'] {
	accent-color: var(--vp-c-brand-1);
}

.demo input[type='color'] {
	width: 100%;
	height: 36px;
	padding: 2px;
	background-color: var(--vp-c-bg);
	border: 1px solid var(--vp-c-divider);
	border-radius: 8px;
}

.demo progress {
	width: 100%;
	height: 8px;
	accent-color: var(--vp-c-brand-1);
}

.demo-events {
	margin: 0;
	padding: 0;
	list-style: none;
	font-size: 13px;
}

.demo-events li {
	display: flex;
	gap: 8px;
	padding: 6px 0;
	border-bottom: 1px solid var(--vp-c-divider);
	overflow-wrap: anywhere;
}

.demo-events code {
	flex: none;
	color: var(--vp-c-brand-1);
	font-family: var(--vp-font-family-mono);
}
</style>
