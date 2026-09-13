import type { LogEntry, StyleToken, TextStyle } from '../types.js';

/** What happens when a span is clicked. */
export type LineAction = { type: 'toggle-value'; path: string } | { type: 'toggle-group' };

/** A run of text on a logical line. */
export interface LineTextSpan {
	text: string;
	token?: StyleToken;
	style?: TextStyle;
	action?: LineAction;
}

/** A small drawn symbol that takes two cells, such as the triangle that expands a value. */
export interface LineIconSpan {
	icon: 'expander';
	expanded: boolean;
	action: LineAction;
}

export type LineSpan = LineTextSpan | LineIconSpan;

/**
 * One line of an entry before wrapping. An entry has one logical line per line of text, plus
 * one for every visible row of an expanded value.
 */
export interface LogicalLine {
	/** Cells of indentation before the content, repeated on every wrapped row. */
	indent: number;
	spans: LineSpan[];
}

/** How a cluster lets a wrapped row break next to it. */
export const BREAK_NORMAL = 0;
/** A space: a row may break after it. */
export const BREAK_SPACE = 1;
/** A wide character that allows breaks on both sides, such as a Han ideograph. */
export const BREAK_WIDE = 2;
/** A wide character that keeps words together, such as a Hangul syllable. */
export const BREAK_KEEP = 3;

/** A span after control characters and tabs were replaced for display. */
export interface ShapedSpan {
	text: string;
	token?: StyleToken;
	style?: TextStyle;
	action?: LineAction;
	icon?: 'expander';
	expanded?: boolean;
}

/**
 * A logical line split into grapheme clusters, each with its width in cells.
 *
 * Most log lines are plain ASCII. Such a line is kept as `text`, where every character is one
 * cluster one cell wide, and the per-cluster arrays are left out to save memory.
 */
export interface ShapedLine {
	indent: number;
	spans: ShapedSpan[];
	/** The index of the first cluster of every span. */
	spanStarts: Uint32Array;
	/** Whether every cluster is a single printable ASCII character. */
	simple: boolean;
	/** The whole line. For a simple line, character `i` is cluster `i`. */
	text: string;
	/** The clusters of a line that is not simple. */
	clusters: string[] | null;
	/** The width of every cluster of a line that is not simple. */
	widths: Uint8Array | null;
	/** One of the `BREAK_*` values for every cluster of a line that is not simple. */
	breaks: Uint8Array | null;
	/** The number of clusters. */
	length: number;
	/** Total width in cells, without the indentation. */
	cells: number;
}

/** How long lines are handled. */
export type WrapMode = 'word' | 'char' | 'none';

/** A run of clusters on one visual row that share a span. */
export interface RowRun {
	/** Column where the run starts, counted from the start of the content area. */
	column: number;
	/** Width in cells. */
	cells: number;
	/** The text of the run. */
	text: string;
	/** The clusters of the run, for runs that must be drawn one cluster at a time. */
	clusters: string[];
	/** The width of every cluster in `clusters`. */
	widths: number[];
	/** Whether the run is plain ASCII that can be drawn in one call. */
	simple: boolean;
	token?: StyleToken;
	style?: TextStyle;
	action?: LineAction;
	icon?: 'expander';
	expanded?: boolean;
}

/** One row of the screen. */
export interface VisualRow {
	entry: LogEntry;
	/** Index of the logical line within the entry. */
	line: number;
	/** Index of the row within the logical line. */
	lineRow: number;
	/** Index of the row within the entry. */
	entryRow: number;
	/** Whether this is the first row of the entry. */
	first: boolean;
	/** Whether this is the last row of the entry. */
	last: boolean;
	/** Cells of indentation before the first run. */
	indent: number;
	/** Cell offset of the row's first cluster within the logical line, without indentation. */
	startCell: number;
	/** Width of the row's content in cells, without indentation. */
	cells: number;
	runs: RowRun[];
}

/** A position in the text of an entry, stable across wrapping. */
export interface TextPosition {
	entryId: number;
	line: number;
	/** Cell offset within the logical line, without indentation. */
	cell: number;
}
