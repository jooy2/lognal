import type { LineTextSpan } from '../layout/types.js';
import type { ValueEntry, ValueNode } from '../types.js';

/** The most cells a one-line preview of an object, array, map or set takes before it is cut. */
export const PREVIEW_CELLS = 100;

const IDENTIFIER = /^[A-Za-z_$][\w$]*$/;

/** Returns whether a value can be expanded to show its children. */
export const isExpandable = (node: ValueNode): boolean => {
	if (node.kind === 'error') {
		return Boolean(node.stack) || (node.children?.length ?? 0) > 0;
	}

	if (
		node.kind !== 'object' &&
		node.kind !== 'array' &&
		node.kind !== 'map' &&
		node.kind !== 'set' &&
		node.kind !== 'element'
	) {
		return false;
	}

	return node.children !== undefined && (node.children.length > 0 || (node.omitted ?? 0) > 0);
};

const quote = (text: string): string => {
	const escaped = text
		.replace(/\\/g, '\\\\')
		.replace(/'/g, "\\'")
		.replace(/\n/g, '\\n')
		.replace(/\r/g, '\\r')
		.replace(/\t/g, '\\t');

	return `'${escaped}'`;
};

/** The longest string shown in full inside another value's preview. */
const NESTED_STRING_LENGTH = 50;

const stringText = (node: ValueNode, nested = false): string => {
	const value = node.value ?? '';

	if (nested && value.length > NESTED_STRING_LENGTH) {
		return `${quote(value.slice(0, NESTED_STRING_LENGTH))}…`;
	}

	return `${quote(value)}${node.truncated ? '…' : ''}`;
};

/** Formats a property key the way it would be written in an object literal. */
export const formatKey = (entry: ValueEntry): LineTextSpan => {
	const key = entry.key ?? '';

	if (entry.keyKind === 'symbol') {
		return { text: key, token: 'symbol' };
	}

	if (entry.keyKind === 'internal') {
		return { text: key, token: 'muted' };
	}

	if (entry.keyKind === 'index' || IDENTIFIER.test(key)) {
		return { text: key, token: 'key' };
	}

	return { text: quote(key), token: 'key' };
};

/** The name shown before an object's contents, such as `User` or `Map(2)`. */
const labelOf = (node: ValueNode): string => {
	const size = node.size ?? node.children?.length ?? 0;

	switch (node.kind) {
		case 'array':
			return node.className && node.className !== 'Array'
				? `${node.className}(${size})`
				: `(${size})`;
		case 'map':
		case 'set':
			return `${node.className ?? (node.kind === 'map' ? 'Map' : 'Set')}(${size})`;
		case 'object':
			return node.className && node.className !== 'Object' ? node.className : '';
		default:
			return node.className ?? '';
	}
};

/** A short name for a nested object, used inside another preview. */
const shortLabel = (node: ValueNode): string => {
	const size = node.size ?? node.children?.length ?? 0;

	switch (node.kind) {
		case 'array':
			return `${node.className && node.className !== 'Array' ? node.className : 'Array'}(${size})`;
		case 'map':
		case 'set':
			return labelOf(node);
		case 'object':
			return node.className && node.className !== 'Object' ? node.className : '{…}';
		default:
			return node.className ?? '';
	}
};

const elementText = (node: ValueNode, withAttributes: boolean): string => {
	const tag = node.value ?? 'element';

	if (!withAttributes || !node.attributes?.length) {
		return `<${tag}>`;
	}

	const attributes = node.attributes
		.map(([name, value]) => (value === '' ? name : `${name}="${value}"`))
		.join(' ');

	return `<${tag} ${attributes}>`;
};

/** Spans for a leaf value, or a short label for a container nested inside a preview. */
const leafSpans = (node: ValueNode, nested: boolean): LineTextSpan[] => {
	switch (node.kind) {
		case 'undefined':
			return [{ text: 'undefined', token: 'null' }];
		case 'null':
			return [{ text: 'null', token: 'null' }];
		case 'boolean':
			return [{ text: node.value ?? 'false', token: 'boolean' }];
		case 'number':
			return [{ text: node.value ?? 'NaN', token: 'number' }];
		case 'bigint':
			return [{ text: `${node.value ?? '0'}n`, token: 'number' }];
		case 'string':
			return [{ text: stringText(node, nested), token: 'string' }];
		case 'symbol':
			return [{ text: node.value ?? 'Symbol()', token: 'symbol' }];
		case 'function':
			return [
				{ text: 'ƒ ', token: 'function' },
				{ text: `${node.value ?? ''}()`, token: 'default' }
			];
		case 'class':
			return [
				{ text: 'class ', token: 'function' },
				{ text: node.value ?? '', token: 'default' }
			];
		case 'date':
			return [{ text: node.value ?? 'Invalid Date', token: 'date' }];
		case 'regexp':
			return [{ text: node.value ?? '/(?:)/', token: 'regexp' }];
		case 'error':
			return [{ text: errorTitle(node), token: 'error' }];
		case 'weak':
			return [{ text: node.className ?? 'WeakMap', token: 'default' }];
		case 'promise':
			return [{ text: node.className ?? 'Promise', token: 'default' }];
		case 'element':
			return [{ text: elementText(node, !nested), token: 'tag' }];
		case 'text':
			return [{ text: stringText(node), token: 'string' }];
		case 'circular':
			return [{ text: '[Circular]', token: 'muted' }];
		case 'accessor':
			return [
				{
					text:
						node.accessor === 'set'
							? '[Setter]'
							: node.accessor === 'get-set'
								? '[Getter/Setter]'
								: '[Getter]',
					token: 'muted'
				}
			];
		default:
			return [{ text: shortLabel(node), token: 'default' }];
	}
};

/** `TypeError: message`, or just the name when there is no message. */
export const errorTitle = (node: ValueNode): string => {
	const name = node.className ?? 'Error';

	return node.value ? `${name}: ${node.value}` : name;
};

const isContainer = (node: ValueNode): boolean => {
	return (
		node.kind === 'object' || node.kind === 'array' || node.kind === 'map' || node.kind === 'set'
	);
};

const measure = (spans: LineTextSpan[]): number => {
	let cells = 0;

	for (const span of spans) {
		cells += span.text.length;
	}

	return cells;
};

/**
 * Returns a one-line preview of a value, such as `{id: 1, name: 'lognal'}` or
 * `(3) [1, 2, 3]`. Objects inside the preview are shown by name only, and the preview is cut
 * with `…` once it passes `PREVIEW_CELLS`.
 */
export const previewValue = (node: ValueNode, nested = false): LineTextSpan[] => {
	if (!isContainer(node) || nested) {
		return leafSpans(node, nested);
	}

	const label = labelOf(node);
	const spans: LineTextSpan[] = [];

	if (label) {
		spans.push({ text: `${label} `, token: node.kind === 'object' ? 'default' : 'muted' });
	}

	if (node.children === undefined) {
		spans.push({ text: node.kind === 'array' ? '[…]' : '{…}', token: 'default' });

		return spans;
	}

	const isArray = node.kind === 'array';

	spans.push({ text: isArray ? '[' : '{', token: 'default' });

	let shown = 0;

	for (const child of node.children) {
		if (measure(spans) > PREVIEW_CELLS) {
			break;
		}

		if (shown > 0) {
			spans.push({ text: ', ', token: 'default' });
		}

		if (node.kind === 'map' && child.keyValue) {
			spans.push(...leafSpans(child.keyValue, true), { text: ' => ', token: 'default' });
		} else if (!isArray && node.kind !== 'set' && child.key !== undefined) {
			spans.push(formatKey(child), { text: ': ', token: 'default' });
		}

		spans.push(...leafSpans(child.value, true));
		shown++;
	}

	if (shown < node.children.length || (node.omitted ?? 0) > 0) {
		spans.push({ text: shown > 0 ? ', …' : '…', token: 'muted' });
	}

	spans.push({ text: isArray ? ']' : '}', token: 'default' });

	return spans;
};
