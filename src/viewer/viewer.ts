import { entrySearchText, type LogFilter } from '../core/filter.js';
import { DEFAULT_LAYOUT_OPTIONS, LogLayout, type LayoutOptions } from '../core/layout/layout.js';
import type { LineAction, TextPosition, VisualRow, WrapMode } from '../core/layout/types.js';
import {
	DEFAULT_STORE_OPTIONS,
	LogStore,
	type LogStoreOptions,
	type StoreChange,
	type WriteOptions
} from '../core/store.js';
import { measureCells } from '../core/text/measure.js';
import { formatTimestamp, type TimestampFormat } from '../core/time.js';
import type { LogLevel, LogPart } from '../core/types.js';
import { CanvasRenderer } from '../renderer/canvas/canvas-renderer.js';
import type { CellMetrics, FontSettings, Renderer, RowDecoration } from '../renderer/types.js';
import {
	createConsole,
	hookConsole,
	type HookConsoleOptions,
	type LognalConsole
} from '../sources/console/hook.js';
import { snapshotValue } from '../sources/console/snapshot.js';
import { createIcon, type IconName } from './icons.js';
import { InputLine } from './input-line.js';
import { labelsFor, type ViewerLabels } from './labels.js';
import { Scrollbar } from './scrollbar.js';
import { readFont, readTheme, type ThemeMode } from './theme.js';

/** Options that belong to the core: what is kept, how it is laid out, and what is shown. */
export interface CoreOptions extends LogStoreOptions, LayoutOptions {
	filter: LogFilter | null;
}

/** Which controls the toolbar shows. */
export interface ToolbarOptions {
	follow: boolean;
	clear: boolean;
	scroll: boolean;
	wrap: boolean;
	filter: boolean;
	levels: boolean;
}

/** The input line, shown when something can answer the commands typed into it. */
export interface InputOptions {
	/**
	 * Called with each command. A returned value, or the value a returned promise resolves to,
	 * is printed as the reply. Return `undefined` to print nothing, for example when the reply
	 * arrives later through `viewer.write`.
	 */
	onSubmit: (command: string, viewer: LogViewer) => unknown;
	/** The prompt shown before the input. */
	prompt?: string;
	placeholder?: string;
	/** Whether the command is added to the log before it runs. */
	echo?: boolean;
	/** How many past commands the arrow keys go through. */
	historySize?: number;
}

export interface LogViewerOptions {
	/** A store to show. Several viewers can share one store. A new store is created when absent. */
	store?: LogStore;
	/** Core options. Store options also apply to a store passed in `store`. */
	core?: Partial<CoreOptions>;
	/** The color scheme. `auto` follows the operating system. */
	theme?: ThemeMode;
	/** The font. Values left out come from the `--lognal-font-*` CSS properties. */
	font?: Partial<FontSettings>;
	/** Whether each entry shows its time, and in which format. */
	timestamps?: boolean | TimestampFormat;
	/** Whether the view follows new entries at the start. */
	follow?: boolean;
	/** The toolbar, or `false` to hide it. */
	toolbar?: boolean | Partial<ToolbarOptions>;
	/** Whether the status bar is shown. */
	statusBar?: boolean;
	/** The input line. Leave it out for a read-only viewer. */
	input?: InputOptions | null;
	/** The language of the built-in labels and number formatting, such as `en` or `ko`. */
	locale?: string;
	/** Labels that replace the built-in ones. */
	labels?: Partial<ViewerLabels>;
	/** Creates the renderer. Defaults to the Canvas 2D renderer. */
	renderer?: (ownerDocument: Document) => Renderer;
}

/** Events a viewer emits. */
export interface LogViewerEvents {
	/** Following new entries was turned on or off. */
	follow: boolean;
	/** The filter changed, from the toolbar or through `setFilter`. */
	filter: LogFilter | null;
	/** The text selection changed. */
	selection: string;
}

type Listener<Value> = (value: Value) => void;

interface ResolvedOptions {
	theme: ThemeMode;
	font: Partial<FontSettings>;
	timestamps: TimestampFormat | null;
	toolbar: ToolbarOptions | null;
	statusBar: boolean;
	input: InputOptions | null;
	locale: string | undefined;
	/** The built-in labels for the locale with `labelOverrides` applied. */
	labels: ViewerLabels;
	labelOverrides: Partial<ViewerLabels>;
}

interface Selection {
	anchor: TextPosition;
	head: TextPosition;
}

interface HitTest {
	row: number;
	column: number;
	visualRow: VisualRow | undefined;
	action: LineAction | undefined;
}

const DEFAULT_TOOLBAR: ToolbarOptions = {
	follow: true,
	clear: true,
	scroll: true,
	wrap: true,
	filter: true,
	levels: true
};

/** Padding around the text, in CSS pixels. */
const PADDING_LEFT = 8;
const PADDING_RIGHT = 16;
const PADDING_TOP = 4;
const PADDING_BOTTOM = 8;
/** Cells of the column with the level marker. */
const MARKER_CELLS = 3;
/**
 * The tallest scroll area the viewer creates. Browsers cap the height of an element; Firefox is
 * the lowest at about 17.9 million pixels. Taller content is mapped onto this height.
 */
const MAX_SCROLL_HEIGHT = 15000000;
/** How close to the bottom, in CSS pixels, still counts as following. */
const FOLLOW_THRESHOLD = 4;
/** How often the status bar and the screen reader mirror update, in milliseconds. */
const ACCESSORY_DELAY = 200;
const FILTER_DELAY = 120;
const DRAG_THRESHOLD = 4;

const LEVEL_OPTIONS: { value: LogLevel | ''; label: keyof ViewerLabels }[] = [
	{ value: '', label: 'levelAll' },
	{ value: 'log', label: 'levelLog' },
	{ value: 'info', label: 'levelInfo' },
	{ value: 'warn', label: 'levelWarn' },
	{ value: 'error', label: 'levelError' }
];

/** Captures a pointer, ignoring the error a pointer that is no longer active throws. */
const capturePointer = (element: Element, pointerId: number): void => {
	try {
		element.setPointerCapture(pointerId);
	} catch {
		// The pointer ended before the capture could start.
	}
};

const comparePositions = (a: TextPosition, b: TextPosition): number => {
	return a.entryId - b.entryId || a.line - b.line || a.cell - b.cell;
};

const pick = <Source extends object, Key extends keyof Source>(
	source: Source,
	keys: readonly Key[]
): Partial<Pick<Source, Key>> => {
	const result: Partial<Pick<Source, Key>> = {};

	for (const key of keys) {
		if (source[key] !== undefined) {
			result[key] = source[key];
		}
	}

	return result;
};

const STORE_KEYS = Object.keys(DEFAULT_STORE_OPTIONS) as (keyof LogStoreOptions)[];
const LAYOUT_KEYS = Object.keys(DEFAULT_LAYOUT_OPTIONS) as (keyof LayoutOptions)[];

/**
 * A log viewer: a toolbar, the log drawn by a renderer, an optional input line and a status
 * bar. The viewer does the scrolling, selection, keyboard handling and accessibility, and
 * hands each frame to the renderer.
 *
 * Import `lognal/style.css` once for the layout and the themes.
 */
export class LogViewer {
	readonly store: LogStore;
	readonly layout: LogLayout;
	readonly element: HTMLDivElement;
	private readonly ownerDocument: Document;
	private readonly renderer: Renderer;
	private options: ResolvedOptions;
	private readonly body: HTMLDivElement;
	private readonly viewport: HTMLDivElement;
	private readonly spacer: HTMLDivElement;
	private readonly mirror: HTMLUListElement;
	private readonly verticalScrollbar: Scrollbar;
	private readonly horizontalScrollbar: Scrollbar;
	private readonly newLogsButton: HTMLButtonElement;
	private toolbarElement: HTMLDivElement | null = null;
	private statusElement: HTMLDivElement | null = null;
	private inputLine: InputLine | null = null;
	private readonly controls = new Map<
		string,
		HTMLButtonElement | HTMLInputElement | HTMLSelectElement
	>();
	private metrics: CellMetrics = { width: 8, height: 20, baseline: 14 };
	private width = 0;
	private height = 0;
	private following: boolean;
	private hasUnseen = false;
	private topPixels = 0;
	private firstRow = 0;
	private visibleRows: VisualRow[] = [];
	private expectedScrollTop: number | null = null;
	private lastScrollTop = 0;
	private columns = 1;
	private selection: Selection | null = null;
	private drag: {
		pointerId: number;
		x: number;
		y: number;
		action: HitTest | null;
		moved: boolean;
	} | null = null;
	private autoScrollFrame = 0;
	private lastPointer: { x: number; y: number } | null = null;
	private frame = 0;
	private accessoryTimer: ReturnType<typeof setTimeout> | undefined;
	private filterTimer: ReturnType<typeof setTimeout> | undefined;
	private filter: LogFilter | null = null;
	private readonly listeners = new Map<keyof LogViewerEvents, Set<Listener<never>>>();
	private readonly cleanups: (() => void)[] = [];
	private consoleObject: LognalConsole | null = null;
	/** The wrapping mode the toolbar button restores after turning wrapping off. */
	private wrapMode: WrapMode = 'word';
	private cachedNumberFormat: {
		locale: string | undefined;
		format: Intl.NumberFormat;
	} | null = null;
	private disposed = false;

	constructor(container: HTMLElement, options: LogViewerOptions = {}) {
		this.ownerDocument = container.ownerDocument;

		const core = options.core ?? {};

		this.store = options.store ?? new LogStore(pick(core, STORE_KEYS));

		if (options.store && Object.keys(pick(core, STORE_KEYS)).length > 0) {
			this.store.setOptions(pick(core, STORE_KEYS));
		}

		this.layout = new LogLayout(this.store, pick(core, LAYOUT_KEYS));
		this.options = this.resolveOptions(options);
		this.following = options.follow ?? true;

		const doc = this.ownerDocument;

		this.element = doc.createElement('div');
		this.element.className = 'lognal';
		this.body = doc.createElement('div');
		this.body.className = 'lognal-body';
		this.viewport = doc.createElement('div');
		this.viewport.className = 'lognal-viewport';
		this.viewport.tabIndex = 0;
		this.spacer = doc.createElement('div');
		this.spacer.className = 'lognal-spacer';
		this.viewport.append(this.spacer);
		this.mirror = doc.createElement('ul');
		this.mirror.className = 'lognal-mirror';
		this.renderer = options.renderer ? options.renderer(doc) : new CanvasRenderer(doc);
		this.verticalScrollbar = new Scrollbar(doc, 'vertical', this.viewport);
		this.horizontalScrollbar = new Scrollbar(doc, 'horizontal', this.viewport);
		this.newLogsButton = doc.createElement('button');
		this.newLogsButton.type = 'button';
		this.newLogsButton.className = 'lognal-new-logs';
		this.newLogsButton.hidden = true;
		this.newLogsButton.addEventListener('click', () => this.scrollToBottom());
		this.body.append(
			this.renderer.element,
			this.viewport,
			this.mirror,
			this.verticalScrollbar.element,
			this.horizontalScrollbar.element,
			this.newLogsButton
		);
		this.element.append(this.body);
		container.append(this.element);

		this.buildChrome();
		this.applyTheme();
		this.applyFont();

		if (core.filter) {
			this.setFilter(core.filter);
		}

		this.bindEvents();
		this.onResize();
	}

	/** An object with the console methods that writes to this viewer's store. */
	get console(): LognalConsole {
		if (!this.consoleObject) {
			this.consoleObject = createConsole(this.store);
		}

		return this.consoleObject;
	}

	/** Whether the view follows new entries. */
	get isFollowing(): boolean {
		return this.following;
	}

	/** Changes options after creation. Only the options given are changed. */
	setOptions(options: Omit<LogViewerOptions, 'store' | 'renderer'>): void {
		const core = options.core ?? {};
		const storeOptions = pick(core, STORE_KEYS);
		const layoutOptions = pick(core, LAYOUT_KEYS);

		if (Object.keys(storeOptions).length > 0) {
			this.store.setOptions(storeOptions);
		}

		if (Object.keys(layoutOptions).length > 0) {
			this.layout.setOptions(layoutOptions);
			this.syncWrapButton();
		}

		if (core.filter !== undefined) {
			this.setFilter(core.filter);
		}

		const previous = this.options;

		this.options = this.resolveOptions({
			...this.unresolvedOptions(),
			...options
		});

		if (
			options.toolbar !== undefined ||
			options.statusBar !== undefined ||
			options.input !== undefined ||
			options.labels !== undefined ||
			'locale' in options
		) {
			this.buildChrome();
		}

		if (options.theme !== undefined && options.theme !== previous.theme) {
			this.applyTheme();
		}

		if (options.font !== undefined || options.timestamps !== undefined) {
			this.applyFont();
		}

		if (options.follow !== undefined) {
			this.setFollowing(options.follow);
		}

		this.requestRender();
	}

	/** Adds text as one entry. */
	write(text: string, options?: WriteOptions): void {
		this.store.write(text, options);
	}

	/** Adds text as one entry per line. */
	writeLines(text: string, options?: WriteOptions): void {
		this.store.writeLines(text, options);
	}

	/**
	 * Starts recording a console, `console` by default, into this viewer's store. Returns a
	 * function that stops recording. Recording also stops when the viewer is disposed.
	 */
	hookConsole(target: Console = console, options?: HookConsoleOptions): () => void {
		const unhook = hookConsole(target, this.store, options);

		this.cleanups.push(unhook);

		return unhook;
	}

	/** Removes every entry. */
	clear(): void {
		this.store.clear();
		this.selection = null;
		this.hasUnseen = false;
	}

	/** Sets the filter. `null` shows every entry. */
	setFilter(filter: LogFilter | null): void {
		this.filter = filter;

		const compiled = this.layout.setFilter(filter);
		const input = this.controls.get('filter');
		const levels = this.controls.get('levels');

		if (input instanceof HTMLInputElement) {
			if (input.value !== (filter?.text ?? '')) {
				input.value = filter?.text ?? '';
			}

			input.toggleAttribute('aria-invalid', compiled.error !== null);
			input.title = compiled.error ? this.options.labels.invalidFilter : '';
		}

		if (levels instanceof HTMLSelectElement) {
			levels.value = filter?.minLevel ?? '';
		}

		this.emit('filter', filter);
		this.requestRender();
	}

	getFilter(): LogFilter | null {
		return this.filter;
	}

	/** Turns following new entries on or off. Turning it on scrolls to the newest entry. */
	setFollowing(following: boolean): void {
		if (this.following === following) {
			return;
		}

		this.following = following;

		if (following) {
			this.hasUnseen = false;
		}

		const button = this.controls.get('follow');

		if (button) {
			button.setAttribute('aria-pressed', String(following));
		}

		this.emit('follow', following);
		this.requestRender();
	}

	scrollToTop(): void {
		this.setFollowing(false);
		this.viewport.scrollTop = 0;
		this.requestRender();
	}

	scrollToBottom(): void {
		this.setFollowing(true);
		this.requestRender();
	}

	/** Scrolls so that an entry is at the top of the view. */
	scrollToEntry(entryId: number): void {
		this.layout.sync();

		const row = this.layout.rowOfEntry(entryId);

		if (row < 0) {
			return;
		}

		this.setFollowing(false);
		this.viewport.scrollTop = (PADDING_TOP + row * this.metrics.height) / this.scrollScale();
		this.requestRender();
	}

	/** Returns the selected text, or an empty string. */
	getSelectionText(): string {
		if (!this.selection || comparePositions(this.selection.anchor, this.selection.head) === 0) {
			return '';
		}

		this.layout.sync();

		return this.layout.getText(this.selection.anchor, this.selection.head);
	}

	/** Selects the text of every visible entry. */
	selectAll(): void {
		this.layout.sync();

		const first = this.layout.entryAt(0);
		const last = this.layout.entryAt(this.layout.visibleCount - 1);

		if (!first || !last) {
			return;
		}

		this.selection = {
			anchor: { entryId: first.id, line: 0, cell: 0 },
			head: {
				entryId: last.id,
				line: Number.MAX_SAFE_INTEGER,
				cell: Number.MAX_SAFE_INTEGER
			}
		};
		this.emit('selection', this.getSelectionText());
		this.requestRender();
	}

	clearSelection(): void {
		if (!this.selection) {
			return;
		}

		this.selection = null;
		this.emit('selection', '');
		this.requestRender();
	}

	/** Copies the selected text to the clipboard. Resolves to whether anything was copied. */
	async copySelection(): Promise<boolean> {
		const text = this.getSelectionText();

		if (!text) {
			return false;
		}

		const view = this.ownerDocument.defaultView;
		const clipboard = view?.navigator.clipboard;

		if (clipboard?.writeText && view?.isSecureContext) {
			try {
				await clipboard.writeText(text);

				return true;
			} catch {
				// Fall back to the copy command below.
			}
		}

		const textarea = this.ownerDocument.createElement('textarea');

		textarea.value = text;
		textarea.setAttribute('readonly', '');
		textarea.className = 'lognal-clipboard';
		this.element.append(textarea);
		textarea.select();

		let copied: boolean;

		try {
			copied = this.ownerDocument.execCommand('copy');
		} catch {
			copied = false;
		}

		textarea.remove();
		this.viewport.focus({ preventScroll: true });

		return copied;
	}

	/** Moves keyboard focus to the input line, or to the log when there is no input line. */
	focus(): void {
		if (this.inputLine) {
			this.inputLine.focus();
		} else {
			this.viewport.focus();
		}
	}

	/** Reads the theme and the font from CSS again, for example after the page changed them. */
	refresh(): void {
		this.applyTheme();
		this.applyFont();
	}

	/** Calls a listener for an event. Returns a function that removes the listener. */
	on<Name extends keyof LogViewerEvents>(
		name: Name,
		listener: Listener<LogViewerEvents[Name]>
	): () => void {
		const listeners = this.listeners.get(name) ?? new Set();

		listeners.add(listener as Listener<never>);
		this.listeners.set(name, listeners);

		return () => {
			listeners.delete(listener as Listener<never>);
		};
	}

	/** Removes the viewer from the page and stops everything it started. */
	dispose(): void {
		if (this.disposed) {
			return;
		}

		this.disposed = true;
		cancelAnimationFrame(this.frame);
		cancelAnimationFrame(this.autoScrollFrame);
		clearTimeout(this.accessoryTimer);
		clearTimeout(this.filterTimer);

		for (const cleanup of this.cleanups.splice(0)) {
			cleanup();
		}

		this.layout.dispose();
		this.renderer.dispose();
		this.verticalScrollbar.dispose();
		this.horizontalScrollbar.dispose();
		this.inputLine?.dispose();
		this.listeners.clear();
		this.element.remove();
	}

	private resolveOptions(options: LogViewerOptions): ResolvedOptions {
		const labelOverrides = options.labels ?? {};
		const labels = { ...labelsFor(options.locale), ...labelOverrides };
		const toolbar =
			options.toolbar === false
				? null
				: options.toolbar === true || options.toolbar === undefined
					? DEFAULT_TOOLBAR
					: { ...DEFAULT_TOOLBAR, ...options.toolbar };
		const timestamps =
			options.timestamps === false
				? null
				: options.timestamps === true || options.timestamps === undefined
					? 'time'
					: options.timestamps;

		return {
			theme: options.theme ?? 'auto',
			font: options.font ?? {},
			timestamps,
			toolbar,
			statusBar: options.statusBar ?? true,
			input: options.input ?? null,
			locale: options.locale,
			labels,
			labelOverrides
		};
	}

	private unresolvedOptions(): LogViewerOptions {
		const { theme, font, timestamps, toolbar, statusBar, input, locale, labelOverrides } =
			this.options;

		return {
			theme,
			font,
			timestamps: timestamps ?? false,
			toolbar: toolbar ?? false,
			statusBar,
			input,
			locale,
			labels: labelOverrides
		};
	}

	private emit<Name extends keyof LogViewerEvents>(name: Name, value: LogViewerEvents[Name]): void {
		for (const listener of this.listeners.get(name) ?? []) {
			(listener as Listener<LogViewerEvents[Name]>)(value);
		}
	}

	private listen<Target extends EventTarget>(
		target: Target,
		type: string,
		handler: (event: never) => void,
		options?: AddEventListenerOptions
	): void {
		target.addEventListener(type, handler as EventListener, options);
		this.cleanups.push(() => target.removeEventListener(type, handler as EventListener, options));
	}

	private bindEvents(): void {
		const view = this.ownerDocument.defaultView;

		this.listen(this.viewport, 'scroll', this.onScroll, { passive: true });
		this.listen(this.viewport, 'pointerdown', this.onPointerDown);
		this.listen(this.viewport, 'pointermove', this.onPointerMove);
		this.listen(this.viewport, 'pointerup', this.onPointerUp);
		this.listen(this.viewport, 'pointercancel', this.onPointerUp);
		this.listen(this.viewport, 'dblclick', this.onDoubleClick);
		this.listen(this.viewport, 'keydown', this.onKeyDown);
		this.listen(this.viewport, 'copy', this.onCopy);
		this.cleanups.push(this.store.subscribe(this.onStoreChange));
		this.renderer.onFontsChanged(() => this.applyFont());

		if (view && 'ResizeObserver' in view) {
			const observer = new view.ResizeObserver(() => this.onResize());

			observer.observe(this.body);
			this.cleanups.push(() => observer.disconnect());
		}

		if (view?.matchMedia) {
			const scheme = view.matchMedia('(prefers-color-scheme: dark)');

			this.listen(scheme, 'change', () => {
				if (this.options.theme === 'auto') {
					this.applyTheme();
				}
			});

			this.watchPixelRatio();
		}

		const fonts = (this.ownerDocument as Document & { fonts?: FontFaceSet }).fonts;

		if (fonts?.ready) {
			fonts.ready.then(() => {
				if (!this.disposed) {
					this.applyFont();
				}
			});
		}
	}

	private watchPixelRatio(): void {
		const view = this.ownerDocument.defaultView;

		if (!view?.matchMedia) {
			return;
		}

		const query = view.matchMedia(`(resolution: ${view.devicePixelRatio}dppx)`);
		const onChange = (): void => {
			query.removeEventListener('change', onChange);

			if (!this.disposed) {
				this.onResize();
				this.watchPixelRatio();
			}
		};

		query.addEventListener('change', onChange);
		this.cleanups.push(() => query.removeEventListener('change', onChange));
	}

	private buildChrome(): void {
		const doc = this.ownerDocument;
		const { labels, toolbar, statusBar, input } = this.options;

		this.toolbarElement?.remove();
		this.statusElement?.remove();
		this.controls.clear();
		this.element.setAttribute('role', 'region');
		this.element.setAttribute('aria-label', labels.viewer);
		this.viewport.setAttribute('aria-label', labels.viewer);
		this.mirror.setAttribute('aria-label', labels.entryList);
		this.newLogsButton.replaceChildren(
			createIcon(doc, 'arrowDown'),
			doc.createTextNode(labels.newLogs)
		);

		if (toolbar) {
			this.toolbarElement = this.buildToolbar(toolbar, labels);
			this.element.prepend(this.toolbarElement);
		} else {
			this.toolbarElement = null;
		}

		if (input) {
			const lineOptions = {
				onSubmit: (command: string) => this.onCommand(command),
				prompt: input.prompt ?? '>',
				placeholder: input.placeholder ?? labels.inputPlaceholder,
				label: labels.input,
				historySize: input.historySize ?? 100
			};

			if (this.inputLine) {
				this.inputLine.setOptions(lineOptions);
			} else {
				this.inputLine = new InputLine(doc, lineOptions);
			}

			this.body.after(this.inputLine.element);
		} else if (this.inputLine) {
			this.inputLine.dispose();
			this.inputLine = null;
		}

		if (statusBar) {
			this.statusElement = doc.createElement('div');
			this.statusElement.className = 'lognal-statusbar';

			const count = doc.createElement('span');
			const follow = doc.createElement('span');

			count.className = 'lognal-status-count';
			follow.className = 'lognal-status-follow';
			this.statusElement.append(count, follow);
			this.element.append(this.statusElement);
		} else {
			this.statusElement = null;
		}

		this.updateAccessories();
	}

	private buildToolbar(toolbar: ToolbarOptions, labels: ViewerLabels): HTMLDivElement {
		const doc = this.ownerDocument;
		const element = doc.createElement('div');
		const start = doc.createElement('div');
		const end = doc.createElement('div');

		element.className = 'lognal-toolbar';
		element.setAttribute('role', 'toolbar');
		element.setAttribute('aria-label', labels.toolbar);
		start.className = 'lognal-toolbar-group';
		end.className = 'lognal-toolbar-group lognal-toolbar-end';

		const button = (
			name: string,
			icon: IconName,
			label: string,
			onClick: () => void,
			pressed?: boolean
		): void => {
			const control = doc.createElement('button');

			control.type = 'button';
			control.className = 'lognal-button';
			control.title = label;
			control.setAttribute('aria-label', label);
			control.append(createIcon(doc, icon));

			if (pressed !== undefined) {
				control.setAttribute('aria-pressed', String(pressed));
			}

			control.addEventListener('click', onClick);
			start.append(control);
			this.controls.set(name, control);
		};
		const separator = (): void => {
			if (
				start.lastElementChild &&
				!start.lastElementChild.classList.contains('lognal-separator')
			) {
				const line = doc.createElement('span');

				line.className = 'lognal-separator';
				line.setAttribute('aria-hidden', 'true');
				start.append(line);
			}
		};

		if (toolbar.follow) {
			button(
				'follow',
				'follow',
				labels.follow,
				() => this.setFollowing(!this.following),
				this.following
			);
		}

		if (toolbar.clear) {
			button('clear', 'clear', labels.clear, () => this.clear());
		}

		if (toolbar.scroll) {
			separator();
			button('top', 'top', labels.scrollToTop, () => this.scrollToTop());
			button('bottom', 'bottom', labels.scrollToBottom, () => this.scrollToBottom());
		}

		if (toolbar.wrap) {
			separator();
			button(
				'wrap',
				'wrap',
				labels.wrap,
				() => {
					const current = this.layout.getOptions().wrap;

					if (current !== 'none') {
						this.wrapMode = current;
					}

					this.layout.setOptions({
						wrap: current === 'none' ? this.wrapMode : 'none'
					});
					this.syncWrapButton();
					this.requestRender();
				},
				this.layout.getOptions().wrap !== 'none'
			);
		}

		if (toolbar.filter) {
			const field = doc.createElement('label');
			const input = doc.createElement('input');

			field.className = 'lognal-filter';
			field.append(createIcon(doc, 'search'));
			input.type = 'search';
			input.className = 'lognal-filter-input';
			input.placeholder = labels.filter;
			input.setAttribute('aria-label', labels.filter);
			input.spellcheck = false;
			input.value = this.filter?.text ?? '';
			input.addEventListener('input', () => {
				clearTimeout(this.filterTimer);
				this.filterTimer = setTimeout(() => {
					this.setFilter({ ...this.filter, text: input.value });
				}, FILTER_DELAY);
			});
			field.append(input);
			end.append(field);
			this.controls.set('filter', input);
		}

		if (toolbar.levels) {
			const select = doc.createElement('select');

			select.className = 'lognal-levels';
			select.setAttribute('aria-label', labels.levels);
			select.title = labels.levels;

			for (const option of LEVEL_OPTIONS) {
				const element = doc.createElement('option');

				element.value = option.value;
				element.textContent = labels[option.label] as string;
				select.append(element);
			}

			select.value = this.filter?.minLevel ?? '';
			select.addEventListener('change', () => {
				// The menu sets a minimum level, which replaces a list of levels set through code.
				this.setFilter({
					...this.filter,
					levels: undefined,
					minLevel: (select.value || undefined) as LogLevel | undefined
				});
			});
			end.append(select);
			this.controls.set('levels', select);
		}

		element.append(start, end);

		return element;
	}

	private syncWrapButton(): void {
		this.controls
			.get('wrap')
			?.setAttribute('aria-pressed', String(this.layout.getOptions().wrap !== 'none'));
	}

	private applyTheme(): void {
		this.element.dataset.theme = this.options.theme;
		this.renderer.setTheme(readTheme(this.element));
		this.requestRender();
	}

	private applyFont(): void {
		if (this.disposed) {
			return;
		}

		this.metrics = this.renderer.setFont(readFont(this.element, this.options.font));
		this.element.style.setProperty('--lognal-cell-height', `${this.metrics.height}px`);
		this.updateColumns();
		this.requestRender();
	}

	private timestampCells(): number {
		const format = this.options.timestamps;

		if (format === null) {
			return 0;
		}

		return measureCells(formatTimestamp(Date.now(), format)) + 2;
	}

	private contentLeft(): number {
		return PADDING_LEFT + (this.timestampCells() + MARKER_CELLS) * this.metrics.width;
	}

	private updateColumns(): void {
		const available = this.width - this.contentLeft() - PADDING_RIGHT;

		this.columns = Math.max(1, Math.floor(available / this.metrics.width));
		this.layout.setColumns(this.columns);
	}

	private scrollScale(): number {
		const content = this.contentHeight();
		const client = this.viewport.clientHeight;
		const scrollable = Math.min(content, MAX_SCROLL_HEIGHT);

		if (content <= scrollable || scrollable <= client) {
			return 1;
		}

		return (content - client) / (scrollable - client);
	}

	private contentHeight(): number {
		return PADDING_TOP + this.layout.rowCount * this.metrics.height + PADDING_BOTTOM;
	}

	private requestRender(): void {
		if (this.frame || this.disposed) {
			return;
		}

		const view = this.ownerDocument.defaultView;

		this.frame = (view ?? globalThis).requestAnimationFrame(() => {
			this.frame = 0;
			this.render();
		});
	}

	private render(): void {
		if (this.disposed || this.width <= 0 || this.height <= 0) {
			return;
		}

		this.layout.sync();

		const rowHeight = this.metrics.height;
		const content = this.contentHeight();
		const client = this.viewport.clientHeight;
		const spacerHeight = Math.min(content, MAX_SCROLL_HEIGHT);
		// Lines that do not wrap, such as tables, can be wider than the view and scroll sideways.
		const wide = this.layout.getOptions().wrap === 'none' || this.layout.maxCells > this.columns;

		this.spacer.style.height = `${spacerHeight}px`;
		this.spacer.style.width = wide
			? `${this.contentLeft() + this.layout.maxCells * this.metrics.width + PADDING_RIGHT}px`
			: '';

		const maxScroll = Math.max(0, spacerHeight - client);
		const scrollTop = this.viewport.scrollTop;

		// The view was scrolled since the last frame, and its scroll event has not arrived yet.
		// Stop following now rather than snapping back to the bottom first.
		if (
			this.following &&
			Math.abs(scrollTop - Math.min(this.lastScrollTop, maxScroll)) >= 1 &&
			maxScroll - scrollTop > FOLLOW_THRESHOLD
		) {
			this.setFollowing(false);
		}

		if (this.following) {
			const bottom = Math.max(0, spacerHeight - client);

			if (Math.abs(this.viewport.scrollTop - bottom) >= 1) {
				this.expectedScrollTop = bottom;
				this.viewport.scrollTop = bottom;
			}
		}

		const scale = this.scrollScale();

		this.topPixels = Math.min(Math.max(0, content - client), this.viewport.scrollTop * scale);

		if (this.following) {
			this.topPixels = Math.max(0, content - client);
		}

		const firstRow = Math.max(0, Math.floor((this.topPixels - PADDING_TOP) / rowHeight));
		const offsetY = PADDING_TOP + firstRow * rowHeight - this.topPixels;
		const count = Math.ceil((this.height - offsetY) / rowHeight) + 1;
		const rows = this.layout.getRows(firstRow, count);

		this.firstRow = firstRow;
		this.visibleRows = rows;
		this.lastScrollTop = this.viewport.scrollTop;
		this.renderer.render({
			rows,
			decorations: rows.map((row) => this.decorationFor(row)),
			offsetY,
			scrollX: this.viewport.scrollLeft,
			paddingLeft: PADDING_LEFT,
			timestampCells: this.timestampCells(),
			markerCells: MARKER_CELLS,
			formatTime: (time) => formatTimestamp(time, this.options.timestamps ?? 'time')
		});
		this.verticalScrollbar.update();
		this.horizontalScrollbar.update();
		this.newLogsButton.hidden = this.following || !this.hasUnseen;
		this.updateStatus();
		this.scheduleAccessories();
	}

	private decorationFor(row: VisualRow): RowDecoration {
		const decoration: RowDecoration = {};
		const selection = this.selection;

		if (selection && comparePositions(selection.anchor, selection.head) !== 0) {
			const [start, end] =
				comparePositions(selection.anchor, selection.head) < 0
					? [selection.anchor, selection.head]
					: [selection.head, selection.anchor];
			const line = { entryId: row.entry.id, line: row.line, cell: 0 };
			const afterStart =
				row.entry.id > start.entryId || (row.entry.id === start.entryId && row.line >= start.line);
			const beforeEnd =
				row.entry.id < end.entryId || (row.entry.id === end.entryId && row.line <= end.line);

			if (afterStart && beforeEnd) {
				const rowEnd = row.startCell + row.cells;
				const isStartLine = line.entryId === start.entryId && line.line === start.line;
				const isEndLine = line.entryId === end.entryId && line.line === end.line;
				const from = Math.max(row.startCell, isStartLine ? start.cell : 0);
				const to = Math.min(rowEnd, isEndLine ? end.cell : rowEnd);
				const lineBreak = !isEndLine && to === rowEnd ? 1 : 0;

				if (to > from || lineBreak) {
					decoration.selection = [
						row.indent + from - row.startCell,
						row.indent + to - row.startCell + lineBreak
					];
				}
			}
		}

		const pattern = this.layout.getFilter().pattern;

		if (pattern) {
			decoration.matches = this.findMatches(row, pattern);
		}

		return decoration;
	}

	private findMatches(row: VisualRow, pattern: RegExp): [number, number][] {
		const columns: number[] = [];
		let text = '';
		let end = row.indent;

		for (const run of row.runs) {
			if (run.icon) {
				continue;
			}

			if (run.simple) {
				for (let index = 0; index < run.text.length; index++) {
					columns.push(run.column + index);
				}

				text += run.text;
			} else {
				let column = run.column;

				run.clusters.forEach((cluster, index) => {
					// The filter text is composed (NFC), so the row text is compared composed too.
					const composed = cluster.normalize('NFC');

					for (let unit = 0; unit < composed.length; unit++) {
						columns.push(column);
					}

					text += composed;
					column += run.widths[index] ?? 1;
				});
			}

			end = run.column + run.cells;
		}

		columns.push(end);

		const matches: [number, number][] = [];

		pattern.lastIndex = 0;

		for (let match = pattern.exec(text); match && matches.length < 64; match = pattern.exec(text)) {
			if (match[0].length === 0) {
				pattern.lastIndex++;
				continue;
			}

			matches.push([columns[match.index], columns[match.index + match[0].length] ?? end]);
		}

		return matches;
	}

	private scheduleAccessories(): void {
		if (this.accessoryTimer !== undefined) {
			return;
		}

		this.accessoryTimer = setTimeout(() => {
			this.accessoryTimer = undefined;
			this.updateAccessories();
		}, ACCESSORY_DELAY);
	}

	/** Updates the status bar. Cheap enough for every frame, since text is only written when it changes. */
	private updateStatus(): void {
		if (!this.statusElement) {
			return;
		}

		const { labels, locale } = this.options;
		const [count, follow] = Array.from(this.statusElement.children) as HTMLElement[];
		const numberFormat = this.numberFormat(locale);
		const countText = labels.entries(this.layout.visibleCount, this.store.size, (value) =>
			numberFormat.format(value)
		);
		const followText = this.following ? labels.following : labels.paused;

		if (count.textContent !== countText) {
			count.textContent = countText;
		}

		if (follow.textContent !== followText) {
			follow.textContent = followText;
			follow.classList.toggle('is-following', this.following);
		}
	}

	private updateAccessories(): void {
		if (this.disposed) {
			return;
		}

		this.updateStatus();

		const doc = this.ownerDocument;
		const seen = new Set<number>();
		const items: HTMLLIElement[] = [];

		for (const row of this.visibleRows) {
			if (seen.has(row.entry.id)) {
				continue;
			}

			seen.add(row.entry.id);

			const item = doc.createElement('li');
			const prefix =
				row.entry.level === 'error' || row.entry.level === 'warn' ? `${row.entry.level}: ` : '';

			item.textContent = `${prefix}${entrySearchText(row.entry)}`;
			items.push(item);
		}

		this.mirror.replaceChildren(...items);
	}

	private numberFormat(locale: string | undefined): Intl.NumberFormat {
		if (!this.cachedNumberFormat || this.cachedNumberFormat.locale !== locale) {
			this.cachedNumberFormat = {
				locale,
				format: new Intl.NumberFormat(locale)
			};
		}

		return this.cachedNumberFormat.format;
	}

	private hitTest(event: { clientX: number; clientY: number }): HitTest {
		const rect = this.viewport.getBoundingClientRect();
		const x = event.clientX - rect.left;
		const y = event.clientY - rect.top;
		const row = Math.floor((y + this.topPixels - PADDING_TOP) / this.metrics.height);
		const exactColumn = (x + this.viewport.scrollLeft - this.contentLeft()) / this.metrics.width;
		const visualRow = this.visibleRows[row - this.firstRow];
		const cellColumn = Math.floor(exactColumn);
		const run = visualRow?.runs.find(
			(item) => cellColumn >= item.column && cellColumn < item.column + item.cells
		);

		return {
			row,
			column: Math.max(0, Math.round(exactColumn)),
			visualRow,
			action: run?.action
		};
	}

	private positionFrom(hit: HitTest): TextPosition | null {
		if (hit.row < 0) {
			const first = this.layout.entryAt(0);

			return first ? { entryId: first.id, line: 0, cell: 0 } : null;
		}

		return this.layout.positionAt(hit.row, hit.column);
	}

	private readonly onStoreChange = (change: StoreChange): void => {
		if (change.type === 'append' && !this.following) {
			this.hasUnseen = true;
		} else if (change.type === 'clear') {
			this.hasUnseen = false;
		}

		this.requestRender();
	};

	private readonly onResize = (): void => {
		const view = this.ownerDocument.defaultView;
		const width = this.body.clientWidth;
		const height = this.body.clientHeight;

		this.width = width;
		this.height = height;
		this.renderer.resize(width, height, view?.devicePixelRatio ?? 1);
		this.updateColumns();
		this.requestRender();
	};

	private readonly onScroll = (): void => {
		const top = this.viewport.scrollTop;

		if (this.expectedScrollTop !== null && Math.abs(top - this.expectedScrollTop) < 1) {
			this.expectedScrollTop = null;
		} else {
			this.expectedScrollTop = null;

			const atBottom =
				top + this.viewport.clientHeight >= this.viewport.scrollHeight - FOLLOW_THRESHOLD;

			this.setFollowing(atBottom);
		}

		this.lastScrollTop = top;
		this.verticalScrollbar.update(true);
		this.horizontalScrollbar.update(true);
		this.requestRender();
	};

	private readonly onPointerDown = (event: PointerEvent): void => {
		if (event.button !== 0 || event.pointerType === 'touch') {
			return;
		}

		event.preventDefault();
		this.viewport.focus({ preventScroll: true });

		const hit = this.hitTest(event);
		const position = this.positionFrom(hit);

		this.drag = {
			pointerId: event.pointerId,
			x: event.clientX,
			y: event.clientY,
			action: hit.action ? hit : null,
			moved: false
		};
		this.lastPointer = { x: event.clientX, y: event.clientY };
		capturePointer(this.viewport, event.pointerId);

		if (!position) {
			this.clearSelection();

			return;
		}

		if (event.shiftKey && this.selection) {
			this.selection = { anchor: this.selection.anchor, head: position };
		} else {
			this.selection = { anchor: position, head: position };
		}

		this.requestRender();
	};

	private readonly onPointerMove = (event: PointerEvent): void => {
		if (!this.drag || event.pointerId !== this.drag.pointerId) {
			const hit = this.hitTest(event);

			this.viewport.classList.toggle('has-action', Boolean(hit.action));

			return;
		}

		this.lastPointer = { x: event.clientX, y: event.clientY };

		if (Math.hypot(event.clientX - this.drag.x, event.clientY - this.drag.y) > DRAG_THRESHOLD) {
			this.drag.moved = true;
		}

		this.extendSelection();
		this.updateAutoScroll();
	};

	private readonly onPointerUp = (event: PointerEvent): void => {
		if (!this.drag || event.pointerId !== this.drag.pointerId) {
			return;
		}

		const { action, moved } = this.drag;

		this.drag = null;
		cancelAnimationFrame(this.autoScrollFrame);
		this.autoScrollFrame = 0;

		if (this.viewport.hasPointerCapture(event.pointerId)) {
			this.viewport.releasePointerCapture(event.pointerId);
		}

		if (action?.action && action.visualRow && !moved) {
			this.selection = null;
			this.layout.runAction(action.visualRow.entry.id, action.action);
			this.requestRender();

			return;
		}

		const text = this.getSelectionText();

		if (!text) {
			this.selection = null;
		}

		this.emit('selection', text);
		this.requestRender();
	};

	private extendSelection(): void {
		if (!this.selection || !this.lastPointer) {
			return;
		}

		const rect = this.viewport.getBoundingClientRect();
		const clientY = Math.min(Math.max(this.lastPointer.y, rect.top - 1), rect.bottom + 1);
		const position = this.positionFrom(this.hitTest({ clientX: this.lastPointer.x, clientY }));

		if (position) {
			this.selection = { anchor: this.selection.anchor, head: position };
			this.requestRender();
		}
	}

	private updateAutoScroll(): void {
		if (this.autoScrollFrame || !this.drag || !this.lastPointer) {
			return;
		}

		const view = this.ownerDocument.defaultView ?? globalThis;
		const step = (): void => {
			this.autoScrollFrame = 0;

			if (!this.drag || !this.lastPointer) {
				return;
			}

			const rect = this.viewport.getBoundingClientRect();
			const above = rect.top - this.lastPointer.y;
			const below = this.lastPointer.y - rect.bottom;
			const distance = above > 0 ? -above : below > 0 ? below : 0;

			if (distance === 0) {
				return;
			}

			this.setFollowing(false);
			this.viewport.scrollTop +=
				Math.sign(distance) * Math.min(this.metrics.height * 3, Math.abs(distance));
			this.extendSelection();
			this.autoScrollFrame = view.requestAnimationFrame(step);
		};

		this.autoScrollFrame = view.requestAnimationFrame(step);
	}

	private readonly onDoubleClick = (event: MouseEvent): void => {
		const hit = this.hitTest(event);

		if (hit.action || !hit.visualRow) {
			return;
		}

		const position = this.positionFrom(hit);

		if (!position) {
			return;
		}

		const range = this.layout.wordAt(position);

		if (range) {
			this.selection = { anchor: range[0], head: range[1] };
			this.emit('selection', this.getSelectionText());
			this.requestRender();
		}
	};

	private readonly onKeyDown = (event: KeyboardEvent): void => {
		const modifier = event.ctrlKey || event.metaKey;
		const key = event.key.toLowerCase();

		if (modifier && key === 'c') {
			if (this.selection) {
				void this.copySelection();
			}

			return;
		}

		if (modifier && key === 'a') {
			event.preventDefault();
			this.selectAll();

			return;
		}

		if (event.key === 'Escape') {
			this.clearSelection();
		}
	};

	private readonly onCopy = (event: ClipboardEvent): void => {
		const text = this.getSelectionText();

		if (text && event.clipboardData) {
			event.clipboardData.setData('text/plain', text);
			event.preventDefault();
		}
	};

	private onCommand(command: string): void {
		const input = this.options.input;

		if (!input) {
			return;
		}

		if (input.echo !== false) {
			this.store.append({
				kind: 'input',
				parts: [{ type: 'text', text: command }]
			});
		}

		this.setFollowing(true);

		let result: unknown;

		try {
			result = input.onSubmit(command, this);
		} catch (error) {
			this.printReply(error, true);

			return;
		}

		if (result && typeof (result as PromiseLike<unknown>).then === 'function') {
			(result as PromiseLike<unknown>).then(
				(value) => this.printReply(value, false),
				(error) => this.printReply(error, true)
			);

			return;
		}

		this.printReply(result, false);
	}

	private printReply(value: unknown, failed: boolean): void {
		if (this.disposed || (value === undefined && !failed)) {
			return;
		}

		const part: LogPart =
			typeof value === 'string'
				? { type: 'text', text: value }
				: { type: 'value', value: snapshotValue(value) };

		this.store.append({
			kind: 'output',
			level: failed ? 'error' : 'log',
			parts: [part]
		});
	}
}
