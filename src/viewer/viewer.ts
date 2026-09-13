import { entrySearchText, type LogFilter } from '../core/filter.js';
import { DEFAULT_LAYOUT_OPTIONS, LogLayout, type LayoutOptions } from '../core/layout/layout.js';
import { LogSearch, type SearchOptions } from '../core/layout/search.js';
import type {
	LineAction,
	TextMatch,
	TextPosition,
	VisualRow,
	WrapMode
} from '../core/layout/types.js';
import {
	DEFAULT_STORE_OPTIONS,
	LogStore,
	type LogStoreOptions,
	type StoreChange,
	type WriteOptions
} from '../core/store.js';
import { measureCells } from '../core/text/measure.js';
import { formatTimestamp, type TimestampFormat } from '../core/time.js';
import type { LogEntry, LogLevel, LogPart } from '../core/types.js';
import { formatEntryData } from '../core/value/data.js';
import { formatEntrySpans, formatEntryText } from '../core/value/text.js';
import { CanvasRenderer } from '../renderer/canvas/canvas-renderer.js';
import type { CellMetrics, FontSettings, Renderer, RowDecoration } from '../renderer/types.js';
import {
	createConsole,
	hookConsole,
	type HookConsoleOptions,
	type LognalConsole
} from '../sources/console/hook.js';
import { snapshotValue } from '../sources/console/snapshot.js';
import { entryHtml } from './entry-html.js';
import { createIcon, type IconName } from './icons.js';
import { InputLine } from './input-line.js';
import { labelsFor, type ViewerLabels } from './labels.js';
import { PopupMenu, type PopupAnchor, type PopupItem } from './popup-menu.js';
import { Scrollbar } from './scrollbar.js';
import { SearchBar } from './search-bar.js';
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

/** An action in the menu of an entry. */
export interface EntryMenuItem {
	/** The text of the item. */
	label: string;
	/** Called with the entry the menu was opened for, when the item is chosen. */
	onSelect: (entry: LogEntry, viewer: LogViewer) => void;
}

/** The menu that opens from the button at the end of the entry under the pointer. */
export interface EntryMenuOptions {
	/** Whether the menu starts with the built-in copy items. Defaults to `true`. */
	copy?: boolean;
	/** Returns the items that follow the built-in ones, for the entry the menu opens for. */
	items?: (entry: LogEntry, viewer: LogViewer) => EntryMenuItem[];
}

/**
 * How `getEntryText` and `copyEntry` write an entry.
 *
 * - `text`: every value on one line, without colors.
 * - `formatted`: values that are too long for one line broken over several lines. `copyEntry`
 *   also puts the text on the clipboard as HTML with the colors of the theme.
 * - `data`: the values of the entry as JSON.
 */
export type EntryTextFormat = 'text' | 'formatted' | 'data';

/** Options of `getEntryText` and `copyEntry`. */
export interface EntryTextOptions {
	/** How the entry is written. Defaults to `text`. */
	format?: EntryTextFormat;
	/**
	 * Whether the text starts with the time of the entry, in the format of the `timestamps`
	 * option. Ignored for `data`.
	 */
	timestamp?: boolean;
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
	/**
	 * The menu of actions that opens from a button at the end of the entry under the pointer, or
	 * `false` to turn the button off.
	 */
	entryMenu?: boolean | EntryMenuOptions;
	/**
	 * Whether Ctrl+F or Cmd+F, while focus is in the viewer, opens a bar that searches the log and
	 * highlights every match without hiding any entry.
	 */
	search?: boolean;
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
	/** The entry menu, or `null` when it is off or would have no items. */
	entryMenu: EntryMenuOptions | null;
	search: boolean;
}

interface Selection {
	anchor: TextPosition;
	head: TextPosition;
}

/** The row at the top of the view, kept when rows above it change height. */
interface ViewAnchor {
	entryId: number;
	/** The row within the entry. */
	entryRow: number;
	/** The distance from the top of the view to the top of the row, zero or negative. */
	offset: number;
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
/** The most entries laid out exactly when a frame starts. Past it, row counts are estimated. */
const SYNC_BUDGET = 2000;
/** Rows laid out exactly above and below the view, so a short scroll finds them ready. */
const MEASURE_MARGIN_ROWS = 50;
/** How long a touch stays in place before it opens the entry menu, in milliseconds. */
const LONG_PRESS_DELAY = 500;
/** How far a touch may move, in CSS pixels, and still count as a long press. */
const LONG_PRESS_SLOP = 10;
/** How long one slice of a search may run, and how many entries it takes at a time. */
const SEARCH_SLICE_MS = 8;
const SEARCH_BATCH = 200;
/** The longest selected text that a new search starts with. */
const SEARCH_SELECTION_LENGTH = 200;
/** How long one slice of background layout may run, and how many entries it takes at a time. */
const MEASURE_SLICE_MS = 8;
const MEASURE_BATCH = 200;

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

let viewerCount = 0;

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
	private readonly entryButton: HTMLButtonElement;
	private readonly popup: PopupMenu;
	private readonly search: LogSearch;
	private readonly searchBar: SearchBar;
	private searchTimer: ReturnType<typeof setTimeout> | undefined;
	/** Whether the next results of the search should make a match current and show it. */
	private revealOnResults = false;
	/** A prefix for the ids of elements that refer to each other. */
	private readonly id = `lognal-${++viewerCount}`;
	private toolbarElement: HTMLDivElement | null = null;
	private statusElement: HTMLDivElement | null = null;
	private inputLine: InputLine | null = null;
	private readonly controls = new Map<string, HTMLButtonElement | HTMLInputElement>();
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
	private anchor: ViewAnchor | null = null;
	private columns = 1;
	private measureTimer: ReturnType<typeof setTimeout> | undefined;
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
	/** Where the pointer is over the log, so the entry under it is found again after a scroll. */
	private hoverPoint: { clientX: number; clientY: number } | null = null;
	private hoverEntryId: number | null = null;
	/** The entry whose menu is open. Its button stays in place while the pointer moves away. */
	private menuEntryId: number | null = null;
	/** A touch that opens the entry menu if it stays in place long enough. */
	private longPress: {
		pointerId: number;
		clientX: number;
		clientY: number;
		timer: ReturnType<typeof setTimeout>;
	} | null = null;
	/** Whether the last touch opened the entry menu, so the menu of the browser stays closed. */
	private longPressOpened = false;
	private frame = 0;
	private accessoryTimer: ReturnType<typeof setTimeout> | undefined;
	private filterTimer: ReturnType<typeof setTimeout> | undefined;
	private filter: LogFilter | null = null;
	private readonly listeners = new Map<keyof LogViewerEvents, Set<Listener<never>>>();
	private readonly cleanups: (() => void)[] = [];
	private consoleObject: LognalConsole | null = null;
	/** The wrapping mode the toolbar button restores after turning wrapping off. */
	private wrapMode: WrapMode = 'word';
	private cachedNumberFormat: { locale: string | undefined; format: Intl.NumberFormat } | null =
		null;
	private disposed = false;

	constructor(container: HTMLElement, options: LogViewerOptions = {}) {
		this.ownerDocument = container.ownerDocument;

		const core = options.core ?? {};

		this.store = options.store ?? new LogStore(pick(core, STORE_KEYS));

		if (options.store && Object.keys(pick(core, STORE_KEYS)).length > 0) {
			this.store.setOptions(pick(core, STORE_KEYS));
		}

		this.layout = new LogLayout(this.store, pick(core, LAYOUT_KEYS));
		this.search = new LogSearch(this.layout);
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
		this.entryButton = doc.createElement('button');
		this.entryButton.type = 'button';
		this.entryButton.className = 'lognal-entry-actions';
		this.entryButton.hidden = true;
		this.entryButton.setAttribute('aria-haspopup', 'menu');
		this.entryButton.setAttribute('aria-expanded', 'false');
		this.entryButton.append(createIcon(doc, 'more'));
		this.entryButton.addEventListener('click', this.onEntryButtonClick);
		this.searchBar = new SearchBar(doc, {
			onQuery: (query, options) => this.onSearchQuery(query, options),
			onNext: () => this.findNext(),
			onPrevious: () => this.findPrevious(),
			onClose: () => this.closeSearch()
		});
		this.body.append(
			this.renderer.element,
			this.viewport,
			this.mirror,
			this.verticalScrollbar.element,
			this.horizontalScrollbar.element,
			this.newLogsButton,
			this.entryButton,
			this.searchBar.element
		);
		this.element.append(this.body);
		this.popup = new PopupMenu(doc, this.element);
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

		this.options = this.resolveOptions({ ...this.unresolvedOptions(), ...options });

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

		if (options.search === false) {
			this.closeSearch();
		}

		if (options.entryMenu !== undefined && !this.options.entryMenu && this.menuEntryId !== null) {
			this.popup.close(false);
		}

		this.updateEntryButton();
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

		if (levels) {
			this.syncLevels();
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
		this.layout.sync(SYNC_BUDGET);

		const first = this.layout.entryAt(0);

		this.anchor = first ? { entryId: first.id, entryRow: 0, offset: PADDING_TOP } : null;
		this.viewport.scrollTop = 0;
		this.lastScrollTop = 0;
		this.requestRender();
	}

	scrollToBottom(): void {
		this.setFollowing(true);
		this.requestRender();
	}

	/** Scrolls so that an entry is at the top of the view. */
	scrollToEntry(entryId: number): void {
		this.layout.sync(SYNC_BUDGET);

		if (this.layout.indexOf(entryId) < 0) {
			return;
		}

		this.setFollowing(false);
		this.anchor = { entryId, entryRow: 0, offset: 0 };
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
			head: { entryId: last.id, line: Number.MAX_SAFE_INTEGER, cell: Number.MAX_SAFE_INTEGER }
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
	copySelection(): Promise<boolean> {
		return this.writeClipboard(this.getSelectionText());
	}

	/**
	 * Returns the whole of an entry, whether its values are open or closed: the text as it was
	 * written, and every value written out in full as far as it was captured. See
	 * `EntryTextFormat` for the formats. Returns an empty string for an entry that is no longer in
	 * the store.
	 */
	getEntryText(entryId: number, options: EntryTextOptions = {}): string {
		const entry = this.store.get(entryId);

		if (!entry) {
			return '';
		}

		if (options.format === 'data') {
			return formatEntryData(entry);
		}

		const text = formatEntryText(entry, { multiline: options.format === 'formatted' });

		return options.timestamp ? `${this.timeOf(entry)} ${text}` : text;
	}

	/**
	 * Copies an entry to the clipboard in a format of `EntryTextFormat`. With `formatted`, the
	 * clipboard also gets HTML with the colors of the theme, for pages and apps that paste rich
	 * text. Resolves to whether anything was copied.
	 */
	copyEntry(entryId: number, options: EntryTextOptions = {}): Promise<boolean> {
		const entry = this.store.get(entryId);
		const text = this.getEntryText(entryId, options);

		if (!entry || options.format !== 'formatted') {
			return this.writeClipboard(text);
		}

		const spans = formatEntrySpans(entry, { multiline: true });
		const html = entryHtml({
			entry,
			spans: options.timestamp
				? [{ text: `${this.timeOf(entry)} `, token: 'muted' }, ...spans]
				: spans,
			theme: readTheme(this.element),
			font: readFont(this.element, this.options.font)
		});

		return this.writeClipboard(text, html);
	}

	private timeOf(entry: LogEntry): string {
		return formatTimestamp(entry.time, this.options.timestamps ?? 'time');
	}

	/** Writes text, and HTML when given, to the clipboard. Resolves to whether anything was copied. */
	private async writeClipboard(text: string, html?: string): Promise<boolean> {
		if (!text) {
			return false;
		}

		const doc = this.ownerDocument;
		const view = doc.defaultView as (Window & typeof globalThis) | null;
		const clipboard = view?.navigator.clipboard;

		if (clipboard && view?.isSecureContext) {
			try {
				if (html && clipboard.write && typeof view.ClipboardItem === 'function') {
					await clipboard.write([
						new view.ClipboardItem({
							'text/plain': new Blob([text], { type: 'text/plain' }),
							'text/html': new Blob([html], { type: 'text/html' })
						})
					]);

					return true;
				}

				if (clipboard.writeText) {
					await clipboard.writeText(text);

					return true;
				}
			} catch {
				// Fall back to the copy command below.
			}
		}

		// The copy command copies the selected text of a hidden field. A listener sets the data
		// itself, so the HTML goes along too.
		const textarea = doc.createElement('textarea');
		const onCopy = (event: ClipboardEvent): void => {
			if (event.clipboardData) {
				event.clipboardData.setData('text/plain', text);

				if (html) {
					event.clipboardData.setData('text/html', html);
				}

				event.preventDefault();
			}
		};

		textarea.value = text;
		textarea.setAttribute('readonly', '');
		textarea.className = 'lognal-clipboard';
		this.element.append(textarea);
		textarea.select();
		doc.addEventListener('copy', onCopy, true);

		let copied: boolean;

		try {
			copied = doc.execCommand('copy');
		} catch {
			copied = false;
		}

		doc.removeEventListener('copy', onCopy, true);
		textarea.remove();
		this.viewport.focus({ preventScroll: true });

		return copied;
	}

	/** Expands every value of an entry, and every value inside them, as far as they were captured. */
	expandEntry(entryId: number): void {
		this.layout.expandAll(entryId);
		this.requestRender();
	}

	/** Collapses every value of an entry, including an error logged on its own. */
	collapseEntry(entryId: number): void {
		this.layout.collapseAll(entryId);
		this.requestRender();
	}

	/**
	 * Opens the search bar and searches for `query`, or for the text already in the bar. Without
	 * `query`, a selection on one line becomes the text to search for. `options` switches the
	 * toggles of the bar. Does nothing when the `search` option is off.
	 */
	openSearch(query?: string, options?: SearchOptions): void {
		if (!this.options.search) {
			return;
		}

		const selected = this.getSelectionText();
		const text =
			query ??
			(selected && !selected.includes('\n') && selected.length <= SEARCH_SELECTION_LENGTH
				? selected
				: undefined);

		this.popup.close(false);

		if (options) {
			this.searchBar.setOptions(options);
		}

		this.searchBar.open(text);
		this.revealOnResults = true;
		this.onSearchQuery(this.searchBar.value, this.searchBar.searchOptions);
	}

	/** Closes the search bar and removes the highlights of the search. */
	closeSearch(): void {
		if (!this.searchBar.isOpen) {
			return;
		}

		const focused = this.searchBar.element.contains(this.ownerDocument.activeElement);

		clearTimeout(this.searchTimer);
		this.searchTimer = undefined;
		this.searchBar.close();
		this.search.setQuery('');

		if (focused) {
			this.viewport.focus({ preventScroll: true });
		}

		this.requestRender();
	}

	/** Makes the next match of the search current and scrolls to it. */
	findNext(): void {
		this.showMatch(this.search.next());
	}

	/** Makes the previous match of the search current and scrolls to it. */
	findPrevious(): void {
		this.showMatch(this.search.previous());
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
		this.cancelLongPress();
		clearTimeout(this.accessoryTimer);
		clearTimeout(this.filterTimer);
		clearTimeout(this.measureTimer);

		for (const cleanup of this.cleanups.splice(0)) {
			cleanup();
		}

		this.layout.dispose();
		this.renderer.dispose();
		this.popup.dispose();
		clearTimeout(this.searchTimer);
		this.searchBar.dispose();
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
		const menu = typeof options.entryMenu === 'object' ? options.entryMenu : {};
		const entryMenu =
			options.entryMenu === false || (menu.copy === false && !menu.items)
				? null
				: { copy: menu.copy ?? true, items: menu.items };
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
			labelOverrides,
			entryMenu,
			search: options.search ?? true
		};
	}

	private unresolvedOptions(): LogViewerOptions {
		const {
			theme,
			font,
			timestamps,
			toolbar,
			statusBar,
			input,
			locale,
			labelOverrides,
			entryMenu,
			search
		} = this.options;

		return {
			theme,
			font,
			timestamps: timestamps ?? false,
			toolbar: toolbar ?? false,
			statusBar,
			input,
			locale,
			labels: labelOverrides,
			entryMenu: entryMenu ?? false,
			search
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
		this.listen(this.viewport, 'contextmenu', this.onContextMenu);
		this.listen(this.body, 'pointerleave', this.onPointerLeave);
		this.listen(this.element, 'keydown', this.onViewerKeyDown);
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

		this.popup.close(false);
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
		this.entryButton.title = labels.entryActions;
		this.entryButton.setAttribute('aria-label', labels.entryActions);
		this.searchBar.setLabels(labels);

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

					this.layout.setOptions({ wrap: current === 'none' ? this.wrapMode : 'none' });
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
			const trigger = doc.createElement('button');
			const label = doc.createElement('span');
			const value = doc.createElement('span');

			trigger.type = 'button';
			trigger.className = 'lognal-levels';
			trigger.title = labels.levels;
			trigger.setAttribute('aria-haspopup', 'listbox');
			trigger.setAttribute('aria-expanded', 'false');
			trigger.setAttribute('aria-labelledby', `${this.id}-levels-label ${this.id}-levels-value`);
			label.id = `${this.id}-levels-label`;
			label.hidden = true;
			label.textContent = labels.levels;
			value.id = `${this.id}-levels-value`;
			value.className = 'lognal-levels-value';
			trigger.append(label, value, createIcon(doc, 'chevronDown'));
			trigger.addEventListener('click', () => {
				if (this.popup.isOpen && this.popup.trigger === trigger) {
					this.popup.close();
				} else {
					this.openLevelMenu(trigger);
				}
			});
			trigger.addEventListener('keydown', (event) => {
				if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
					event.preventDefault();
					this.openLevelMenu(trigger);
				}
			});
			end.append(trigger);
			this.controls.set('levels', trigger);
			this.syncLevels();
		}

		element.append(start, end);

		return element;
	}

	/** Shows the chosen minimum level on the level menu button. */
	private syncLevels(): void {
		const value = this.controls.get('levels')?.querySelector('.lognal-levels-value');
		const minLevel = this.filter?.minLevel ?? '';
		const option = LEVEL_OPTIONS.find((item) => item.value === minLevel) ?? LEVEL_OPTIONS[0];

		if (value) {
			value.textContent = this.options.labels[option.label] as string;
		}
	}

	private openLevelMenu(trigger: HTMLButtonElement): void {
		const { labels } = this.options;
		const minLevel = this.filter?.minLevel ?? '';

		this.popup.close(false);
		trigger.setAttribute('aria-expanded', 'true');
		this.popup.open({
			role: 'listbox',
			label: labels.levels,
			items: LEVEL_OPTIONS.map((option) => ({
				label: labels[option.label] as string,
				selected: option.value === minLevel,
				onSelect: () => {
					// The menu sets a minimum level, which replaces a list of levels set through code.
					this.setFilter({
						...this.filter,
						levels: undefined,
						minLevel: option.value || undefined
					});
				}
			})),
			anchor: trigger.getBoundingClientRect(),
			align: 'end',
			trigger,
			returnFocus: trigger,
			onClose: () => trigger.setAttribute('aria-expanded', 'false')
		});
	}

	/**
	 * Places the button of the entry under the pointer, or of the entry whose menu is open, at
	 * the right end of the first row of that entry that is on screen.
	 */
	private updateEntryButton(): void {
		const button = this.entryButton;
		const entryId = this.menuEntryId ?? this.hoverEntryId;
		const startRow = entryId === null ? -1 : this.layout.rowOfEntry(entryId);

		if (!this.options.entryMenu || entryId === null || startRow < 0) {
			button.hidden = true;

			if (this.menuEntryId !== null) {
				this.popup.close(false);
			}

			return;
		}

		const rowHeight = this.metrics.height;
		const top = PADDING_TOP + startRow * rowHeight - this.topPixels;
		const bottom = top + this.layout.rowsOf(entryId) * rowHeight;

		if (bottom <= 0 || top >= this.height) {
			button.hidden = true;

			return;
		}

		button.style.transform = `translateY(${Math.round(Math.min(Math.max(top, 0), bottom - rowHeight))}px)`;
		button.hidden = false;
	}

	private openEntryMenu(entryId: number): void {
		const { labels, entryMenu } = this.options;
		const entry = this.store.get(entryId);

		if (!entryMenu || !entry) {
			return;
		}

		const items: PopupItem[] = [];

		if (entryMenu.copy) {
			items.push(
				{
					label: labels.copyEntry,
					icon: 'copy',
					onSelect: () => {
						void this.copyEntry(entryId);
					}
				},
				{
					label: labels.copyEntryWithTime,
					icon: 'clock',
					onSelect: () => {
						void this.copyEntry(entryId, { timestamp: true });
					}
				},
				{
					label: labels.copyEntryFormatted,
					icon: 'code',
					onSelect: () => {
						void this.copyEntry(entryId, { format: 'formatted' });
					}
				}
			);

			// Data is only worth copying from an entry that holds values.
			if (entry.parts.some((part) => part.type === 'value')) {
				items.push({
					label: labels.copyEntryData,
					icon: 'braces',
					onSelect: () => {
						void this.copyEntry(entryId, { format: 'data' });
					}
				});
			}
		}

		if (this.layout.hasExpandableValues(entry)) {
			items.push(
				{
					label: labels.expandAll,
					icon: 'expandAll',
					startsGroup: items.length > 0,
					onSelect: () => this.expandEntry(entryId)
				},
				{
					label: labels.collapseAll,
					icon: 'collapseAll',
					onSelect: () => this.collapseEntry(entryId)
				}
			);
		}

		for (const [index, item] of (entryMenu.items?.(entry, this) ?? []).entries()) {
			items.push({
				label: item.label,
				startsGroup: index === 0 && items.length > 0,
				onSelect: () => item.onSelect(entry, this)
			});
		}

		if (items.length === 0) {
			return;
		}

		this.popup.close(false);
		this.menuEntryId = entryId;
		this.updateEntryButton();

		const view = this.viewport.getBoundingClientRect();
		// Without a button on screen, the menu opens from the top right corner of the log.
		const anchor: PopupAnchor = this.entryButton.hidden
			? { left: view.right, top: view.top, right: view.right, bottom: view.top }
			: this.entryButton.getBoundingClientRect();

		this.entryButton.setAttribute('aria-expanded', 'true');
		this.popup.open({
			role: 'menu',
			label: labels.entryActions,
			items,
			anchor,
			align: 'end',
			trigger: this.entryButton,
			returnFocus: this.viewport,
			onClose: () => {
				this.menuEntryId = null;
				this.entryButton.setAttribute('aria-expanded', 'false');
				this.updateEntryButton();
				this.requestRender();
			}
		});
		this.requestRender();
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

		this.layout.sync(SYNC_BUDGET);

		const viewport = this.viewport;
		const rowHeight = this.metrics.height;
		const client = viewport.clientHeight;
		const screenRows = Math.ceil(this.height / rowHeight) + 1;
		const scrollTop = viewport.scrollTop;

		// The view was scrolled since the last frame, and its scroll event has not arrived yet.
		// Follow the new position rather than the old anchor, and stop following the bottom.
		if (Math.abs(scrollTop - Math.min(this.lastScrollTop, viewport.scrollHeight - client)) >= 1) {
			this.anchor = null;

			if (this.following && viewport.scrollHeight - client - scrollTop > FOLLOW_THRESHOLD) {
				this.setFollowing(false);
			}
		}

		if (!this.following && !this.anchor) {
			this.anchor = this.anchorAt(scrollTop * this.scrollScale());
		}

		// Lay out the rows on screen exactly before reading them. The rest of the log keeps its
		// estimated row counts until `measurePending` gets to it.
		if (this.following) {
			this.layout.measureAround(null, screenRows + MEASURE_MARGIN_ROWS, 1);
		} else if (this.anchor) {
			this.layout.measureAround(
				this.anchor.entryId,
				MEASURE_MARGIN_ROWS,
				screenRows + MEASURE_MARGIN_ROWS
			);
		}

		const content = this.contentHeight();
		const spacerHeight = Math.min(content, MAX_SCROLL_HEIGHT);
		const wide = this.layout.getOptions().wrap === 'none' || this.layout.maxCells > this.columns;

		this.spacer.style.height = `${spacerHeight}px`;
		this.spacer.style.width = wide
			? `${this.contentLeft() + this.layout.maxCells * this.metrics.width + PADDING_RIGHT}px`
			: '';

		const maxTop = Math.max(0, content - client);
		const scale = this.scrollScale();
		let topPixels = Math.min(maxTop, viewport.scrollTop * scale);

		if (this.following) {
			topPixels = maxTop;
		} else if (this.anchor) {
			const entryStart = this.layout.rowOfEntry(this.anchor.entryId);

			if (entryStart < 0) {
				this.anchor = null;
			} else {
				const entryRow = Math.min(
					this.anchor.entryRow,
					Math.max(0, this.layout.rowsOf(this.anchor.entryId) - 1)
				);

				topPixels = Math.min(
					maxTop,
					Math.max(0, PADDING_TOP + (entryStart + entryRow) * rowHeight - this.anchor.offset)
				);
			}
		}

		const targetScrollTop = topPixels / scale;

		if (Math.abs(viewport.scrollTop - targetScrollTop) >= 1) {
			this.expectedScrollTop = targetScrollTop;
			viewport.scrollTop = targetScrollTop;
		}

		const firstRow = Math.max(0, Math.floor((topPixels - PADDING_TOP) / rowHeight));
		const offsetY = PADDING_TOP + firstRow * rowHeight - topPixels;
		const rows = this.layout.getRows(firstRow, Math.ceil((this.height - offsetY) / rowHeight) + 1);

		this.topPixels = topPixels;
		this.firstRow = firstRow;
		this.visibleRows = rows;
		this.lastScrollTop = viewport.scrollTop;
		this.anchor =
			this.following || !rows[0]
				? null
				: { entryId: rows[0].entry.id, entryRow: rows[0].entryRow, offset: offsetY };

		// The rows under a still pointer change when the log scrolls or grows.
		if (this.hoverPoint && !this.drag) {
			this.hoverEntryId = this.hitTest(this.hoverPoint).visualRow?.entry.id ?? null;
		}

		this.renderer.render({
			rows,
			decorations: rows.map((row) => this.decorationFor(row)),
			offsetY,
			scrollX: viewport.scrollLeft,
			paddingLeft: PADDING_LEFT,
			timestampCells: this.timestampCells(),
			markerCells: MARKER_CELLS,
			formatTime: (time) => formatTimestamp(time, this.options.timestamps ?? 'time')
		});
		this.verticalScrollbar.update();
		this.horizontalScrollbar.update();
		this.updateEntryButton();
		this.newLogsButton.hidden = this.following || !this.hasUnseen;
		this.updateStatus();
		this.scheduleAccessories();
		this.scheduleMeasure();

		if (this.search.pending) {
			this.scheduleSearch();
		}
	}

	/** Searches the log a slice at a time between frames. */
	private scheduleSearch(): void {
		if (this.searchTimer !== undefined || this.disposed) {
			return;
		}

		this.searchTimer = setTimeout(() => {
			this.searchTimer = undefined;
			this.layout.sync(SYNC_BUDGET);

			const started = performance.now();
			let changed = false;

			while (this.search.pending && performance.now() - started < SEARCH_SLICE_MS) {
				changed = this.search.scan(SEARCH_BATCH) || changed;
			}

			if (this.revealOnResults) {
				this.revealFirstMatch();
			}

			if (changed) {
				this.requestRender();
			}

			this.updateSearchResults();

			if (this.search.pending) {
				this.scheduleSearch();
			}
		}, 0);
	}

	private readonly onSearchQuery = (query: string, options: SearchOptions): void => {
		if (this.search.setQuery(query, options)) {
			this.revealOnResults = true;
		}

		this.updateSearchResults();
		this.requestRender();
	};

	/** Makes the first match at the top of the view or below it current, once one is found. */
	private revealFirstMatch(): void {
		const topId = this.visibleRows[0]?.entry.id ?? 0;
		let index = this.search.firstMatchFrom(topId);

		if (index < 0 && !this.search.pending) {
			index = this.search.count > 0 ? 0 : -1;
		}

		if (index >= 0 || !this.search.pending) {
			this.revealOnResults = false;
		}

		if (index >= 0) {
			this.showMatch(this.search.select(index));
		}
	}

	private showMatch(match: TextMatch | null): void {
		this.revealOnResults = false;

		if (match) {
			this.revealMatch(match);
		}

		this.updateSearchResults();
		this.requestRender();
	}

	/** Scrolls so a match is on screen, in the middle of the view when it was not. */
	private revealMatch(match: TextMatch): void {
		this.layout.sync(SYNC_BUDGET);

		const located = this.layout.locatePosition({
			entryId: match.entryId,
			line: match.line,
			cell: match.from
		});

		if (!located) {
			return;
		}

		const rowHeight = this.metrics.height;
		const shown = this.visibleRows.findIndex(
			(row) => row.entry.id === match.entryId && row.entryRow === located.entryRow
		);
		const rowTop = PADDING_TOP + (this.firstRow + shown) * rowHeight - this.topPixels;

		if (shown < 0 || rowTop < 0 || rowTop + rowHeight > this.height) {
			this.setFollowing(false);
			this.anchor = {
				entryId: match.entryId,
				entryRow: located.entryRow,
				offset: Math.max(0, Math.round((this.height - rowHeight) / 2))
			};
		}

		const cellWidth = this.metrics.width;
		const visibleWidth = this.viewport.clientWidth - this.contentLeft() - PADDING_RIGHT;
		const from = (located.indent + match.from) * cellWidth;
		const to = (located.indent + match.to) * cellWidth;
		const scrollLeft = this.viewport.scrollLeft;

		if (from < scrollLeft || to > scrollLeft + visibleWidth) {
			this.viewport.scrollLeft = Math.max(0, from - visibleWidth / 3);
		}
	}

	private updateSearchResults(): void {
		const { labels, locale } = this.options;
		const numberFormat = this.numberFormat(locale);
		const { query, count, current, pending, error } = this.search;
		const text =
			!query || error || (pending && count === 0)
				? ''
				: labels.searchResults(current + 1, count, (value) => numberFormat.format(value));

		this.searchBar.setResults(text);
		this.searchBar.setInvalid(error ? labels.searchInvalid : null);
	}

	/** Returns an anchor for the row at a pixel position of the whole log. */
	private anchorAt(topPixels: number): ViewAnchor | null {
		const row = Math.max(0, Math.floor((topPixels - PADDING_TOP) / this.metrics.height));
		const located = this.layout.locateRow(row);

		if (!located) {
			return null;
		}

		return {
			entryId: located.entry.id,
			entryRow: located.entryRow,
			offset: PADDING_TOP + row * this.metrics.height - topPixels
		};
	}

	/**
	 * Lays out the entries that still have estimated row counts, a slice at a time between
	 * frames, starting with the ones nearest to the view.
	 */
	private scheduleMeasure(): void {
		if (this.measureTimer !== undefined || this.disposed || this.layout.pendingCount === 0) {
			return;
		}

		this.measureTimer = setTimeout(() => {
			this.measureTimer = undefined;

			const started = performance.now();
			const focus = this.following ? null : (this.anchor?.entryId ?? null);
			let changed = false;

			while (this.layout.pendingCount > 0 && performance.now() - started < MEASURE_SLICE_MS) {
				changed = this.layout.measurePending(MEASURE_BATCH, focus) || changed;
			}

			if (changed) {
				this.requestRender();
			}

			this.scheduleMeasure();
		}, 0);
	}

	private decorationFor(row: VisualRow): RowDecoration {
		const decoration: RowDecoration = {};
		const selection = this.selection;

		if (row.entry.id === (this.menuEntryId ?? this.hoverEntryId)) {
			decoration.hovered = true;
		}

		const found = this.search.matchesOf(row.entry.id);

		if (found) {
			const current = this.search.getMatch(this.search.current);
			const start = row.startCell;
			const end = start + row.cells;

			for (const match of found) {
				if (match.line !== row.line || match.to <= start || match.from >= end) {
					continue;
				}

				const range: [number, number] = [
					row.indent + Math.max(match.from, start) - start,
					row.indent + Math.min(match.to, end) - start
				];

				if (match === current) {
					decoration.searchCurrent = range;
				} else {
					(decoration.searchMatches ??= []).push(range);
				}
			}
		}

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
			this.cachedNumberFormat = { locale, format: new Intl.NumberFormat(locale) };
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
		} else if (Math.abs(top - this.lastScrollTop) >= 1) {
			// Only a vertical scroll moves the anchor and decides following. A sideways scroll,
			// such as the one that shows a match of a search, leaves both as they are.
			this.expectedScrollTop = null;
			this.anchor = null;

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
		this.longPressOpened = false;

		if (event.pointerType === 'touch') {
			this.startLongPress(event);

			return;
		}

		if (event.button !== 0) {
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
		const press = this.longPress;

		if (press && event.pointerId === press.pointerId) {
			if (
				Math.hypot(event.clientX - press.clientX, event.clientY - press.clientY) > LONG_PRESS_SLOP
			) {
				this.cancelLongPress();
			}

			return;
		}
		if (!this.drag || event.pointerId !== this.drag.pointerId) {
			const hit = this.hitTest(event);

			this.viewport.classList.toggle('has-action', Boolean(hit.action));

			if (event.pointerType !== 'touch') {
				this.setHover({ clientX: event.clientX, clientY: event.clientY }, hit);
			}

			return;
		}

		this.lastPointer = { x: event.clientX, y: event.clientY };

		if (Math.hypot(event.clientX - this.drag.x, event.clientY - this.drag.y) > DRAG_THRESHOLD) {
			this.drag.moved = true;
			// The button would sit over the text being selected.
			this.setHover(null, null);
		}

		this.extendSelection();
		this.updateAutoScroll();
	};

	private setHover(point: { clientX: number; clientY: number } | null, hit: HitTest | null): void {
		const entryId = hit?.visualRow?.entry.id ?? null;

		this.hoverPoint = point;

		if (entryId !== this.hoverEntryId) {
			this.hoverEntryId = entryId;
			this.updateEntryButton();
			this.requestRender();
		}
	}

	private startLongPress(event: PointerEvent): void {
		this.cancelLongPress();

		if (!this.options.entryMenu || !event.isPrimary) {
			return;
		}

		this.longPress = {
			pointerId: event.pointerId,
			clientX: event.clientX,
			clientY: event.clientY,
			timer: setTimeout(() => this.finishLongPress(), LONG_PRESS_DELAY)
		};
	}

	/** Opens the entry menu for the entry under a touch that stayed in place. */
	private finishLongPress(): void {
		const press = this.longPress;

		if (!press) {
			return;
		}

		this.cancelLongPress();

		const entryId = this.hitTest(press).visualRow?.entry.id;

		if (entryId !== undefined) {
			this.longPressOpened = true;
			this.openEntryMenu(entryId);
		}
	}

	private cancelLongPress(): void {
		if (this.longPress) {
			clearTimeout(this.longPress.timer);
			this.longPress = null;
		}
	}

	/**
	 * Some browsers open their own menu on a long press, sometimes before the long press of the
	 * viewer fires. Open the entry menu then instead, and keep the menu of the browser closed.
	 */
	private readonly onContextMenu = (event: MouseEvent): void => {
		if (this.longPress) {
			event.preventDefault();
			this.finishLongPress();
		} else if (this.longPressOpened) {
			event.preventDefault();
		}
	};

	private readonly onPointerLeave = (): void => {
		this.setHover(null, null);
	};

	private readonly onEntryButtonClick = (): void => {
		if (this.menuEntryId !== null) {
			this.popup.close();
		} else if (this.hoverEntryId !== null) {
			this.openEntryMenu(this.hoverEntryId);
		}
	};

	private readonly onPointerUp = (event: PointerEvent): void => {
		if (this.longPress?.pointerId === event.pointerId) {
			this.cancelLongPress();
		}

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

		if (event.key === 'ContextMenu' || (event.shiftKey && event.key === 'F10')) {
			const selected = this.selection && this.layout.indexOf(this.selection.head.entryId) >= 0;
			const entryId = selected ? this.selection?.head.entryId : this.visibleRows[0]?.entry.id;

			event.preventDefault();

			if (this.options.entryMenu && entryId !== undefined) {
				this.openEntryMenu(entryId);
			}

			return;
		}

		if (event.key === 'Escape') {
			this.clearSelection();
		}
	};

	/** Keys that work wherever focus is inside the viewer: the search shortcuts. */
	private readonly onViewerKeyDown = (event: KeyboardEvent): void => {
		if (!this.options.search) {
			return;
		}

		const modifier = event.ctrlKey || event.metaKey;
		const key = event.key.toLowerCase();

		if (modifier && !event.altKey && key === 'f') {
			event.preventDefault();
			this.openSearch();

			return;
		}

		if (this.searchBar.isOpen && (event.key === 'F3' || (modifier && key === 'g'))) {
			event.preventDefault();

			if (event.shiftKey) {
				this.findPrevious();
			} else {
				this.findNext();
			}
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
			this.store.append({ kind: 'input', parts: [{ type: 'text', text: command }] });
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

		this.store.append({ kind: 'output', level: failed ? 'error' : 'log', parts: [part] });
	}
}
