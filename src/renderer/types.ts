import type { VisualRow } from '../core/layout/types.js';
import type { StyleToken } from '../core/types.js';

/** The font the log text is drawn with. Only monospace fonts line up on the grid. */
export interface FontSettings {
	/** A CSS font family list, such as `"JetBrains Mono", D2Coding, monospace`. */
	family: string;
	/** Font size in CSS pixels. */
	size: number;
	/** Font weight of regular text, such as `400`. */
	weight: number;
	/** Row height as a multiple of the font size. */
	lineHeight: number;
}

/** The size of one cell of the text grid, in CSS pixels. */
export interface CellMetrics {
	width: number;
	height: number;
	/** Distance from the top of a row to the text baseline. */
	baseline: number;
}

/** Colors the renderer draws with. Any CSS color works. */
export interface RenderTheme {
	background: string;
	foreground: string;
	muted: string;
	accent: string;
	selection: string;
	match: string;
	separator: string;
	/** The background of the rows of the entry under the pointer. */
	hover: string;
	/** The highlight of every match of a search. */
	searchMatch: string;
	/** The highlight of the current match of a search. */
	searchCurrent: string;
	/** The text of a link, unless the text has a color of its own. */
	link: string;
	/** The background of the rows of an entry selected in entry mode. */
	entrySelection: string;
	/** The outline of the entry the keyboard moves from in entry mode. */
	focusRing: string;
	error: string;
	errorBackground: string;
	warn: string;
	warnBackground: string;
	info: string;
	debug: string;
	tokens: Record<Exclude<StyleToken, 'default'>, string>;
	/** The 16 ANSI colors: black, red, green, yellow, blue, magenta, cyan, white, then bright. */
	ansi: string[];
}

/** Highlights on one row, as ranges of columns of the content area. */
export interface RowDecoration {
	selection?: [number, number];
	matches?: [number, number][];
	/** Whether the row belongs to the entry under the pointer, or to the entry whose menu is open. */
	hovered?: boolean;
	/** The columns of the matches of a search, other than the current match. */
	searchMatches?: [number, number][];
	/** The columns of the current match of a search, on the rows that show it. */
	searchCurrent?: [number, number];
	/** Whether the row belongs to an entry selected in entry mode. */
	entrySelected?: boolean;
	/** Whether the row belongs to the entry the keyboard moves from in entry mode. */
	entryFocused?: boolean;
}

/** Everything needed to draw one frame. */
export interface RenderFrame {
	rows: VisualRow[];
	decorations: RowDecoration[];
	/** Vertical offset of the first row in CSS pixels, zero or negative. */
	offsetY: number;
	/** Horizontal scroll of the content area in CSS pixels. */
	scrollX: number;
	/** Space before the gutter in CSS pixels. */
	paddingLeft: number;
	/** Cells taken by the timestamp column, or 0 when timestamps are hidden. */
	timestampCells: number;
	/** Cells taken by the level marker column. */
	markerCells: number;
	/** Formats the time of an entry for the timestamp column. */
	formatTime: (time: number) => string;
}

/**
 * Draws frames of the log. The viewer owns the layout, scrolling and input; a renderer only
 * turns a frame into pixels, so a different drawing technology can take its place.
 */
export interface Renderer {
	/** The element the renderer draws into. */
	readonly element: HTMLElement;
	setTheme(theme: RenderTheme): void;
	/** Sets the font and returns the size of a cell. */
	setFont(font: FontSettings): CellMetrics;
	getMetrics(): CellMetrics;
	/** Sets the drawing size in CSS pixels. */
	resize(width: number, height: number, pixelRatio: number): void;
	render(frame: RenderFrame): void;
	/**
	 * Called when fonts finish loading glyphs the last frame needed, so the viewer can measure
	 * again and redraw.
	 */
	onFontsChanged(listener: () => void): void;
	dispose(): void;
}
