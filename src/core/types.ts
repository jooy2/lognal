/**
 * Data types shared by every part of lognal.
 *
 * Everything under `src/core` is plain data and logic with no dependency on the DOM or on a
 * JavaScript-only API, so that it can be ported to other runtimes, such as Dart. Platform
 * features the core needs, such as grapheme segmentation, are passed in rather than imported.
 */

/** Severity of an entry, from least to most severe. */
export type LogLevel = 'debug' | 'log' | 'info' | 'warn' | 'error';

/** Every level, ordered from least to most severe. */
export const LOG_LEVELS: readonly LogLevel[] = ['debug', 'log', 'info', 'warn', 'error'];

/**
 * What an entry represents. The viewer marks each kind differently.
 *
 * - `message`: a regular log message.
 * - `input`: a command the user typed into the input line.
 * - `output`: the reply to a command.
 * - `group`: the header of a group started with `console.group`.
 * - `system`: a notice from the viewer itself, such as "Console was cleared".
 */
export type LogKind = 'message' | 'input' | 'output' | 'group' | 'system';

/** Semantic colors, resolved by the renderer from the theme. */
export type StyleToken =
	| 'default'
	| 'muted'
	| 'string'
	| 'number'
	| 'boolean'
	| 'null'
	| 'key'
	| 'symbol'
	| 'function'
	| 'regexp'
	| 'date'
	| 'tag'
	| 'attribute'
	| 'error'
	| 'warn'
	| 'info'
	| 'accent';

/**
 * A color given directly rather than through a token.
 *
 * A number from 0 to 255 is an index into the ANSI palette; 0 to 15 follow the theme. A string
 * is a CSS color such as `#ff0000` or `rgb(255 0 0)`.
 */
export type TextColor = number | string;

/** Explicit styling, from `%c` in a console message or from ANSI escape codes. */
export interface TextStyle {
	color?: TextColor;
	background?: TextColor;
	bold?: boolean;
	dim?: boolean;
	italic?: boolean;
	underline?: boolean;
	strikethrough?: boolean;
}

/** A run of text with one style. */
export interface TextPart {
	type: 'text';
	text: string;
	token?: StyleToken;
	style?: TextStyle;
}

/** A captured value, displayed with type-aware formatting. */
export interface ValuePart {
	type: 'value';
	value: ValueNode;
}

/** One piece of an entry's content. Parts are displayed one after another. */
export type LogPart = TextPart | ValuePart;

/** The kinds of value a snapshot can hold. */
export type ValueKind =
	| 'undefined'
	| 'null'
	| 'boolean'
	| 'number'
	| 'bigint'
	| 'string'
	| 'symbol'
	| 'function'
	| 'class'
	| 'date'
	| 'regexp'
	| 'error'
	| 'array'
	| 'object'
	| 'map'
	| 'set'
	| 'weak'
	| 'promise'
	| 'element'
	| 'text'
	| 'circular'
	| 'accessor';

/**
 * A snapshot of a value, taken when it was logged.
 *
 * The tree is plain data, so it can be passed through `postMessage` or saved as JSON. It never
 * holds a reference to the original value.
 */
export interface ValueNode {
	kind: ValueKind;
	/**
	 * The text of a leaf value: the string itself, a number as text, a function name, a date in
	 * ISO format, a regular expression literal, an error message, or an element's tag name.
	 */
	value?: string;
	/** The constructor name of an object, such as `Map` or `User`. */
	className?: string;
	/** The length of an array or string, or the size of a map or set. */
	size?: number;
	/**
	 * The captured children of an object, array, map, set, error or element. `undefined` means
	 * the value has children that were not captured because the depth limit was reached.
	 */
	children?: ValueEntry[];
	/** How many children exist but were left out because of a limit. */
	omitted?: number;
	/** How many characters were cut from a long string. */
	truncated?: number;
	/** The stack trace of an error, without its first line. */
	stack?: string;
	/** The attributes of an element, as name and value pairs. */
	attributes?: [string, string][];
	/** For an accessor property, which parts are defined. */
	accessor?: 'get' | 'set' | 'get-set';
}

/** A child of a value: a property, an array item, a map entry or a child node. */
export interface ValueEntry {
	/** The property name or index. Absent for set items and child nodes. */
	key?: string;
	/** How the key is displayed. */
	keyKind?: 'property' | 'index' | 'symbol' | 'internal';
	/** The key of a map entry. */
	keyValue?: ValueNode;
	value: ValueNode;
}

/** The fields a caller provides when adding an entry. */
export interface LogEntryInit {
	parts: LogPart[];
	level?: LogLevel;
	kind?: LogKind;
	/** Epoch milliseconds. Defaults to the time the entry is added. */
	time?: number;
	/** Ids of the open groups this entry belongs to, outermost first. */
	groups?: readonly number[];
	/** For a group header, whether the group starts collapsed. */
	collapsed?: boolean;
}

/** An entry held by a store. */
export interface LogEntry {
	readonly id: number;
	readonly time: number;
	readonly level: LogLevel;
	readonly kind: LogKind;
	readonly parts: readonly LogPart[];
	readonly groups: readonly number[];
	/** For a group header, whether its members are hidden. */
	collapsed: boolean;
	/** How many identical consecutive messages this entry stands for. */
	repeat: number;
	/** Increases whenever `collapsed` or `repeat` changes, so cached layouts can be refreshed. */
	version: number;
}
