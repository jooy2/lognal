import type { LogEntry, ValueEntry, ValueNode } from '../types.js';
import { formatEntryText, formatValueText, uncapturedText } from './text.js';

/** A JSON value. */
export type JsonValue = null | boolean | number | string | JsonValue[] | JsonObject;

/** An array or object stays on one line when it takes at most this many characters. */
const BREAK_LENGTH = 72;
const INDENT = '  ';
/** The key that holds the count of properties a snapshot left out. */
const OMITTED_KEY = '…';

const keyOf = (entry: ValueEntry): string => {
	const key = entry.key ?? '';

	return entry.keyKind === 'symbol' ? `[${key}]` : key;
};

const numberOf = (node: ValueNode): number | string => {
	const value = Number(node.value);

	// JSON has no NaN or Infinity, so they stay text. `-0` becomes `0`.
	return Number.isFinite(value) ? value + 0 : (node.value ?? 'NaN');
};

type JsonObject = { [key: string]: JsonValue };

/**
 * An object without a prototype, so a logged key such as `__proto__` becomes a property instead
 * of changing the prototype.
 */
const createObject = (): JsonObject => Object.create(null) as JsonObject;

const objectOf = (
	children: readonly ValueEntry[],
	omitted: number | undefined,
	result: JsonObject = createObject()
): JsonObject => {
	for (const child of children) {
		result[keyOf(child)] = valueToJson(child.value);
	}

	if ((omitted ?? 0) > 0) {
		result[OMITTED_KEY] = `${omitted} more`;
	}

	return result;
};

const arrayOf = (node: ValueNode): JsonValue => {
	const items = (node.children ?? []).map((child) => valueToJson(child.value));

	if ((node.omitted ?? 0) > 0) {
		items.push(`… ${node.omitted} more`);
	}

	return items;
};

const mapOf = (node: ValueNode): JsonValue => {
	const children = node.children ?? [];

	// A map with text keys reads best as an object. Other keys become [key, value] pairs.
	if (children.every((child) => child.keyValue?.kind === 'string')) {
		return objectOf(
			children.map((child) => ({ key: child.keyValue?.value ?? '', value: child.value })),
			node.omitted
		);
	}

	const pairs: JsonValue[] = children.map((child) => [
		child.keyValue ? valueToJson(child.keyValue) : null,
		valueToJson(child.value)
	]);

	if ((node.omitted ?? 0) > 0) {
		pairs.push(`… ${node.omitted} more`);
	}

	return pairs;
};

/**
 * Converts a captured value to JSON data. Values JSON has no type for are written as text the
 * way previews write them: `10n`, `Symbol(token)`, `ƒ handleClick()`, `/ab+c/gi`, `[Circular]`.
 * `undefined` becomes `null`, a date becomes its ISO text, a set becomes an array, a map with
 * text keys becomes an object, an error becomes an object with its name, message and stack, and
 * an element becomes its markup. What the snapshot left out is marked with `…`.
 */
export const valueToJson = (node: ValueNode): JsonValue => {
	if (
		(node.kind === 'object' ||
			node.kind === 'array' ||
			node.kind === 'map' ||
			node.kind === 'set') &&
		node.children === undefined
	) {
		return uncapturedText(node);
	}

	switch (node.kind) {
		case 'undefined':
		case 'null':
			return null;
		case 'boolean':
			return node.value === 'true';
		case 'number':
			return numberOf(node);
		case 'string':
		case 'text':
			return `${node.value ?? ''}${node.truncated ? '…' : ''}`;
		case 'date':
		case 'regexp':
		case 'symbol':
		case 'bigint':
		case 'function':
		case 'class':
		case 'weak':
		case 'promise':
		case 'circular':
		case 'accessor':
		case 'element':
			return formatValueText(node);
		case 'error': {
			const result = createObject();

			result.name = node.className ?? 'Error';
			result.message = node.value ?? '';

			if (node.stack) {
				result.stack = node.stack
					.split('\n')
					.map((line) => line.trim())
					.join('\n');
			}

			return objectOf(node.children ?? [], node.omitted, result);
		}
		case 'array':
		case 'set':
			return arrayOf(node);
		case 'map':
			return mapOf(node);
		default:
			return objectOf(node.children ?? [], node.omitted);
	}
};

/** Writes JSON data, keeping an array or object on one line when it is short enough. */
export const formatJson = (value: JsonValue, indent = ''): string => {
	if (value === null || typeof value !== 'object') {
		return JSON.stringify(value);
	}

	const childIndent = indent + INDENT;
	const isArray = Array.isArray(value);
	const items = isArray
		? value.map((item) => formatJson(item, childIndent))
		: Object.entries(value).map(
				([key, item]) => `${JSON.stringify(key)}: ${formatJson(item, childIndent)}`
			);
	const [open, close] = isArray ? ['[', ']'] : ['{', '}'];

	if (items.length === 0) {
		return `${open}${close}`;
	}

	const single = isArray ? `[${items.join(', ')}]` : `{ ${items.join(', ')} }`;

	if (!single.includes('\n') && indent.length + single.length <= BREAK_LENGTH) {
		return single;
	}

	return `${open}\n${items.map((item) => childIndent + item).join(',\n')}\n${indent}${close}`;
};

/** The data of an entry: its value, an array of its values, or its text when it has none. */
const entryData = (entry: LogEntry): JsonValue => {
	const values = entry.parts.flatMap((part) =>
		part.type === 'value' ? [valueToJson(part.value)] : []
	);

	if (values.length === 0) {
		return formatEntryText(entry);
	}

	return values.length === 1 ? values[0] : values;
};

/**
 * Returns the values of an entry as JSON text: the value itself when the entry has one, an
 * array of the values when it has several, and the text of the entry when it has none.
 */
export const formatEntryData = (entry: LogEntry): string => {
	return formatJson(entryData(entry));
};

/** Returns the data of several entries as one JSON array, with an item for every entry. */
export const formatEntriesData = (entries: readonly LogEntry[]): string => {
	return formatJson(entries.map(entryData));
};
