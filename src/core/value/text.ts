import type { LogEntry, ValueEntry, ValueNode } from '../types.js';
import { errorTitle, formatKey, previewValue } from './preview.js';

/** A container fits on one line when it takes at most this many characters with its indent. */
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

const spansText = (node: ValueNode): string => {
	return previewValue(node)
		.map((span) => span.text)
		.join('');
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
const uncapturedText = (node: ValueNode): string => {
	if (node.kind === 'array' && (!node.className || node.className === 'Array')) {
		return `Array(${node.size ?? 0}) […]`;
	}

	return `${labelOf(node)}${node.kind === 'array' ? '[…]' : '{…}'}`;
};

const keyText = (entry: ValueEntry): string => {
	const key = formatKey(entry).text;

	return entry.keyKind === 'symbol' ? `[${key}]` : key;
};

const omittedText = (node: ValueNode): string[] => {
	return (node.omitted ?? 0) > 0 ? [`… ${node.omitted} more`] : [];
};

/** Joins the items of a container on one line when they fit, and one per line otherwise. */
const joinItems = (options: {
	label: string;
	open: string;
	close: string;
	items: string[];
	indent: string;
	padding: string;
}): string => {
	const { label, open, close, items, indent, padding } = options;

	if (items.length === 0) {
		return `${label}${open}${close}`;
	}

	const single = `${label}${open}${padding}${items.join(', ')}${padding}${close}`;

	if (!single.includes('\n') && indent.length + single.length <= BREAK_LENGTH) {
		return single;
	}

	const childIndent = indent + INDENT;

	return `${label}${open}\n${items.map((item) => childIndent + item).join(',\n')}\n${indent}${close}`;
};

const containerText = (node: ValueNode, indent: string): string => {
	if (node.children === undefined) {
		return uncapturedText(node);
	}

	const childIndent = indent + INDENT;
	const items = node.children.map((child) => {
		const value = formatValue(child.value, childIndent);

		if (node.kind === 'map' && child.keyValue) {
			return `${formatValue(child.keyValue, childIndent)} => ${value}`;
		}

		if (node.kind === 'set' || child.key === undefined || child.keyKind === 'index') {
			return value;
		}

		return `${keyText(child)}: ${value}`;
	});
	const isArray = node.kind === 'array';

	return joinItems({
		label: labelOf(node),
		open: isArray ? '[' : '{',
		close: isArray ? ']' : '}',
		items: [...items, ...omittedText(node)],
		indent,
		padding: isArray ? '' : ' '
	});
};

const errorText = (node: ValueNode, indent: string): string => {
	const lines = [errorTitle(node)];

	for (const line of node.stack?.split('\n') ?? []) {
		lines.push(`${indent}${INDENT}${INDENT}${line.trim()}`);
	}

	const text = lines.join('\n');

	if (!node.children?.length && !node.omitted) {
		return text;
	}

	// The properties of an error, such as its `cause`, follow it the way an object's would.
	const properties = containerText(
		{ kind: 'object', children: node.children ?? [], omitted: node.omitted },
		indent
	);

	return `${text} ${properties}`;
};

const elementText = (node: ValueNode, indent: string): string => {
	const tag = node.value ?? 'element';
	const open = spansText(node);
	const close = `</${tag}>`;

	if (VOID_ELEMENTS.has(tag)) {
		return open;
	}

	if (node.children === undefined) {
		return `${open}…${close}`;
	}

	const childIndent = indent + INDENT;
	const items = [
		...node.children.map((child) =>
			child.value.kind === 'text'
				? (child.value.value ?? '')
				: formatValue(child.value, childIndent)
		),
		...omittedText(node)
	];

	if (items.length === 0) {
		return `${open}${close}`;
	}

	const single = `${open}${items[0]}${close}`;

	if (
		items.length === 1 &&
		!single.includes('\n') &&
		indent.length + single.length <= BREAK_LENGTH
	) {
		return single;
	}

	return `${open}\n${items.map((item) => childIndent + item).join('\n')}\n${indent}${close}`;
};

/** Formats a value starting at a line that is indented by `indent`. */
const formatValue = (node: ValueNode, indent: string): string => {
	switch (node.kind) {
		case 'object':
		case 'array':
		case 'map':
		case 'set':
			return containerText(node, indent);
		case 'error':
			return errorText(node, indent);
		case 'element':
			return elementText(node, indent);
		default:
			return spansText(node);
	}
};

/**
 * Writes out a value in full, the way code writes it, as far as it was captured: every
 * property, item and entry, with nested values on lines of their own once they are too long for
 * one line. Leaf values are written the way previews write them, such as `'text'` or
 * `ƒ handleClick()`.
 */
export const formatValueText = (node: ValueNode): string => {
	return formatValue(node, '');
};

/** Returns the text of an entry: its text as it was written, and every value in full. */
export const formatEntryText = (entry: LogEntry): string => {
	return entry.parts
		.map((part) => (part.type === 'text' ? part.text : formatValueText(part.value)))
		.join('');
};
