import type { LineTextSpan } from '../layout/types.js';
import type { LogEntry, StyleToken, ValueEntry, ValueNode } from '../types.js';
import { errorTitle, formatKey, previewValue } from './preview.js';

export interface ValueTextOptions {
	/**
	 * Whether a value that is too long for one line is broken over several lines, with an indent
	 * for every level. Without it, every value stays on one line. Defaults to `false`.
	 */
	multiline?: boolean;
}

/** With `multiline`, a container stays on one line when it takes at most this many characters. */
const BREAK_LENGTH = 72;
const INDENT = '  ';
/** Elements that never have content, so they have no closing tag. */
const VOID_ELEMENTS = new Set([
	'area',
	'base',
	'br',
	'col',
	'embed',
	'hr',
	'img',
	'input',
	'link',
	'meta',
	'source',
	'track',
	'wbr'
]);

type Spans = LineTextSpan[];

interface Context {
	multiline: boolean;
	/** The indent of the line the value starts on. */
	indent: string;
}

const span = (text: string, token?: StyleToken): LineTextSpan => {
	return token ? { text, token } : { text };
};

const lengthOf = (spans: Spans): number => {
	let length = 0;

	for (const item of spans) {
		length += item.text.length;
	}

	return length;
};

const hasLineBreak = (spans: Spans): boolean => spans.some((item) => item.text.includes('\n'));

const childContext = (context: Context): Context => {
	return { ...context, indent: context.multiline ? context.indent + INDENT : '' };
};

/** The name written before the contents of a container, such as `User ` or `Map(2) `. */
const labelOf = (node: ValueNode): string => {
	const size = node.size ?? node.children?.length ?? 0;

	if (node.kind === 'map' || node.kind === 'set') {
		return `${node.className ?? (node.kind === 'map' ? 'Map' : 'Set')}(${size}) `;
	}

	if (node.kind === 'array') {
		return node.className && node.className !== 'Array' ? `${node.className}(${size}) ` : '';
	}

	return node.className && node.className !== 'Object' ? `${node.className} ` : '';
};

/** A container whose children were not captured, because the depth limit was reached. */
export const uncapturedText = (node: ValueNode): string => {
	if (node.kind === 'array' && (!node.className || node.className === 'Array')) {
		return `Array(${node.size ?? 0}) […]`;
	}

	return `${labelOf(node)}${node.kind === 'array' ? '[…]' : '{…}'}`;
};

const keySpan = (entry: ValueEntry): LineTextSpan => {
	const key = formatKey(entry);

	return entry.keyKind === 'symbol' ? { ...key, text: `[${key.text}]` } : key;
};

const omittedSpans = (node: ValueNode): Spans[] => {
	return (node.omitted ?? 0) > 0 ? [[span(`… ${node.omitted} more`, 'muted')]] : [];
};

/** Joins the items of a container on one line, or one item per line when they do not fit. */
const joinItems = (options: {
	label: Spans;
	open: string;
	close: string;
	items: Spans[];
	padding: string;
	context: Context;
}): Spans => {
	const { label, open, close, items, padding, context } = options;

	if (items.length === 0) {
		return [...label, span(`${open}${close}`)];
	}

	const single = [
		...label,
		span(`${open}${padding}`),
		...items.flatMap((item, index) => (index === 0 ? item : [span(', '), ...item])),
		span(`${padding}${close}`)
	];

	if (
		!context.multiline ||
		(!hasLineBreak(single) && context.indent.length + lengthOf(single) <= BREAK_LENGTH)
	) {
		return single;
	}

	const childIndent = context.indent + INDENT;

	return [
		...label,
		span(`${open}\n`),
		...items.flatMap((item, index) => [
			span(childIndent),
			...item,
			span(index < items.length - 1 ? ',\n' : '\n')
		]),
		span(`${context.indent}${close}`)
	];
};

const containerSpans = (node: ValueNode, context: Context): Spans => {
	const label = labelOf(node);

	if (node.children === undefined) {
		return [span(uncapturedText(node))];
	}

	const child = childContext(context);
	const items = node.children.map((entry) => {
		const value = valueSpans(entry.value, child);

		if (node.kind === 'map' && entry.keyValue) {
			return [...valueSpans(entry.keyValue, child), span(' => '), ...value];
		}

		if (node.kind === 'set' || entry.key === undefined || entry.keyKind === 'index') {
			return value;
		}

		return [keySpan(entry), span(': '), ...value];
	});
	const isArray = node.kind === 'array';

	return joinItems({
		label: label ? [span(label, node.kind === 'object' ? undefined : 'muted')] : [],
		open: isArray ? '[' : '{',
		close: isArray ? ']' : '}',
		items: [...items, ...omittedSpans(node)],
		padding: isArray ? '' : ' ',
		context
	});
};

const errorSpans = (node: ValueNode, context: Context): Spans => {
	const spans = [span(errorTitle(node), 'error')];

	for (const line of node.stack?.split('\n') ?? []) {
		spans.push(span(`\n${context.indent}${INDENT}${INDENT}${line.trim()}`, 'muted'));
	}

	if (!node.children?.length && !node.omitted) {
		return spans;
	}

	// The properties of an error, such as its `cause`, follow it the way an object's would.
	const properties: ValueNode = {
		kind: 'object',
		children: node.children ?? [],
		omitted: node.omitted
	};

	return [...spans, span(' '), ...containerSpans(properties, context)];
};

const elementSpans = (node: ValueNode, context: Context): Spans => {
	const tag = node.value ?? 'element';
	const open = previewValue(node);
	const close = span(`</${tag}>`, 'tag');

	if (VOID_ELEMENTS.has(tag)) {
		return open;
	}

	if (node.children === undefined) {
		return [...open, span('…', 'muted'), close];
	}

	const child = childContext(context);
	const items = [
		...node.children.map((entry) =>
			entry.value.kind === 'text' ? [span(entry.value.value ?? '')] : valueSpans(entry.value, child)
		),
		...omittedSpans(node)
	];

	if (items.length === 0) {
		return [...open, close];
	}

	const single = [...open, ...items.flat(), close];

	if (
		!context.multiline ||
		(items.length === 1 &&
			!hasLineBreak(single) &&
			context.indent.length + lengthOf(single) <= BREAK_LENGTH)
	) {
		return single;
	}

	return [
		...open,
		...items.flatMap((item) => [span(`\n${child.indent}`), ...item]),
		span(`\n${context.indent}`),
		close
	];
};

const valueSpans = (node: ValueNode, context: Context): Spans => {
	switch (node.kind) {
		case 'object':
		case 'array':
		case 'map':
		case 'set':
			return containerSpans(node, context);
		case 'error':
			return errorSpans(node, context);
		case 'element':
			return elementSpans(node, context);
		default:
			return previewValue(node);
	}
};

const textOf = (spans: Spans): string => spans.map((item) => item.text).join('');

/**
 * Writes out a value in full, the way code writes it, as far as it was captured: every
 * property, item and entry. Leaf values are written the way previews write them, such as
 * `'text'` or `ƒ handleClick()`. Each span carries the token that colors it.
 */
export const formatValueSpans = (
	node: ValueNode,
	options: ValueTextOptions = {}
): LineTextSpan[] => {
	return valueSpans(node, { multiline: options.multiline ?? false, indent: '' });
};

/** The text of `formatValueSpans`. */
export const formatValueText = (node: ValueNode, options: ValueTextOptions = {}): string => {
	return textOf(formatValueSpans(node, options));
};

/** Returns the spans of an entry: its text as it was written, and every value in full. */
export const formatEntrySpans = (
	entry: LogEntry,
	options: ValueTextOptions = {}
): LineTextSpan[] => {
	return entry.parts.flatMap((part): Spans => {
		if (part.type === 'value') {
			return formatValueSpans(part.value, options);
		}

		const text: LineTextSpan = { text: part.text };

		if (part.token) {
			text.token = part.token;
		}

		if (part.style) {
			text.style = part.style;
		}

		return [text];
	});
};

/** The text of `formatEntrySpans`. */
export const formatEntryText = (entry: LogEntry, options: ValueTextOptions = {}): string => {
	return textOf(formatEntrySpans(entry, options));
};
