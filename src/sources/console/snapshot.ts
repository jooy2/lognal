import type { ValueEntry, ValueNode } from '../../core/types.js';

/** Limits that keep capturing a large or deep value cheap. */
export interface CaptureOptions {
	/** How many levels of nested objects are captured. Deeper objects are shown by name only. */
	maxDepth: number;
	/** The most properties, items or entries captured from one object, array, map or set. */
	maxProperties: number;
	/** The longest string captured in full. */
	maxStringLength: number;
	/** The most values captured for one argument, counting every nested value. */
	maxNodes: number;
}

export const DEFAULT_CAPTURE_OPTIONS: CaptureOptions = {
	maxDepth: 5,
	maxProperties: 100,
	maxStringLength: 10000,
	maxNodes: 2000
};

/** The most attributes captured from one element, and the longest attribute value. */
const MAX_ATTRIBUTES = 20;
const MAX_ATTRIBUTE_LENGTH = 200;

type Getter = (this: unknown) => unknown;

const getterOf = (target: object | undefined, key: PropertyKey): Getter | undefined => {
	if (!target) {
		return undefined;
	}

	return Object.getOwnPropertyDescriptor(target, key)?.get as Getter | undefined;
};

/** Calls a built-in getter or method on a value, and returns `undefined` when it throws. */
const callBuiltIn = (
	fn: ((this: unknown, ...args: never[]) => unknown) | undefined,
	value: unknown
): unknown => {
	if (!fn) {
		return undefined;
	}

	try {
		return fn.call(value);
	} catch {
		return undefined;
	}
};

/** Returns whether a built-in accepts the value, which is how built-in types are told apart. */
const accepts = (
	fn: ((this: unknown, ...args: never[]) => unknown) | undefined,
	value: unknown
): boolean => {
	if (!fn) {
		return false;
	}

	try {
		fn.call(value);

		return true;
	} catch {
		return false;
	}
};

const globals = globalThis as {
	Node?: { prototype: object };
	Element?: { prototype: object };
	Attr?: { prototype: object };
	WeakRef?: { prototype: { deref: () => unknown } };
};

const TYPED_ARRAY_PROTOTYPE = Object.getPrototypeOf(Uint8Array.prototype) as object;
const TYPED_ARRAY_TAG = getterOf(TYPED_ARRAY_PROTOTYPE, Symbol.toStringTag);
const TYPED_ARRAY_LENGTH = getterOf(TYPED_ARRAY_PROTOTYPE, 'length');
const MAP_SIZE = getterOf(Map.prototype, 'size');
const SET_SIZE = getterOf(Set.prototype, 'size');
const ARRAY_BUFFER_LENGTH = getterOf(ArrayBuffer.prototype, 'byteLength');
const REGEXP_SOURCE = getterOf(RegExp.prototype, 'source');
const REGEXP_FLAGS = getterOf(RegExp.prototype, 'flags');
const NODE_TYPE = getterOf(globals.Node?.prototype, 'nodeType');

const WEAK_MAP_HAS = function (this: unknown): boolean {
	return WeakMap.prototype.has.call(this as WeakMap<object, unknown>, {});
};

const WEAK_SET_HAS = function (this: unknown): boolean {
	return WeakSet.prototype.has.call(this as WeakSet<object>, {});
};

const NATIVE_CODE = /\{\s*\[native code\]\s*\}\s*$/;

const isNativeFunction = (fn: unknown): boolean => {
	try {
		return typeof fn === 'function' && NATIVE_CODE.test(Function.prototype.toString.call(fn));
	} catch {
		return false;
	}
};

/** Looks a property up along the prototype chain without running user-defined getters. */
const readProperty = (value: object, key: PropertyKey): unknown => {
	let target: object | null = value;
	let depth = 0;

	while (target && depth < 32) {
		let descriptor: PropertyDescriptor | undefined;

		try {
			descriptor = Object.getOwnPropertyDescriptor(target, key);
		} catch {
			return undefined;
		}

		if (descriptor) {
			if ('value' in descriptor) {
				return descriptor.value;
			}

			return isNativeFunction(descriptor.get) ? callBuiltIn(descriptor.get, value) : undefined;
		}

		try {
			target = Object.getPrototypeOf(target);
		} catch {
			return undefined;
		}

		depth++;
	}

	return undefined;
};

const classNameOf = (value: object): string | undefined => {
	let prototype: object | null;

	try {
		prototype = Object.getPrototypeOf(value);
	} catch {
		return undefined;
	}

	if (!prototype) {
		return undefined;
	}

	const constructor = Object.getOwnPropertyDescriptor(prototype, 'constructor')?.value;

	if (typeof constructor !== 'function') {
		return undefined;
	}

	const name = Object.getOwnPropertyDescriptor(constructor, 'name')?.value;

	return typeof name === 'string' && name ? name : undefined;
};

const functionName = (fn: (...args: never[]) => unknown): string => {
	const name = Object.getOwnPropertyDescriptor(fn, 'name')?.value;

	return typeof name === 'string' ? name : '';
};

const isError = (value: object): boolean => {
	const isErrorCheck = (Error as { isError?: (value: unknown) => boolean }).isError;

	if (typeof isErrorCheck === 'function') {
		return isErrorCheck(value);
	}

	return value instanceof Error;
};

/** Removes the `Name: message` header V8 puts at the top of a stack trace. */
const stackWithoutHeader = (stack: string, name: string, message: string): string => {
	const header = message ? `${name}: ${message}` : name;

	if (stack.startsWith(header)) {
		return stack.slice(header.length).replace(/^\r?\n/, '');
	}

	return stack;
};

class Capture {
	private nodes = 0;
	private readonly path = new Set<object>();

	constructor(private readonly options: CaptureOptions) {}

	value(value: unknown, depth: number): ValueNode {
		this.nodes++;

		switch (typeof value) {
			case 'undefined':
				return { kind: 'undefined' };
			case 'boolean':
				return { kind: 'boolean', value: String(value) };
			case 'number':
				return { kind: 'number', value: Object.is(value, -0) ? '-0' : String(value) };
			case 'bigint':
				return {
					kind: 'bigint',
					value: String(callBuiltIn(BigInt.prototype.toString, value) ?? '')
				};
			case 'string':
				return this.string(value);
			case 'symbol':
				return {
					kind: 'symbol',
					value: String(callBuiltIn(Symbol.prototype.toString, value) ?? 'Symbol()')
				};
			case 'function':
				return this.function(value as (...args: never[]) => unknown);
			default:
				break;
		}

		if (value === null) {
			return { kind: 'null' };
		}

		const object = value as object;

		if (this.path.has(object)) {
			return { kind: 'circular' };
		}

		this.path.add(object);

		try {
			return this.object(object, depth);
		} finally {
			this.path.delete(object);
		}
	}

	private string(value: string): ValueNode {
		const { maxStringLength } = this.options;

		if (value.length <= maxStringLength) {
			return { kind: 'string', value };
		}

		return {
			kind: 'string',
			value: value.slice(0, maxStringLength),
			truncated: value.length - maxStringLength,
			size: value.length
		};
	}

	private function(fn: (...args: never[]) => unknown): ValueNode {
		let source = '';

		try {
			source = Function.prototype.toString.call(fn).slice(0, 6);
		} catch {
			// A revoked proxy has no source.
		}

		return { kind: source.startsWith('class') ? 'class' : 'function', value: functionName(fn) };
	}

	/** Whether this value may capture its children, or is shown by name only. */
	private canDescend(depth: number): boolean {
		return depth < this.options.maxDepth && this.nodes < this.options.maxNodes;
	}

	private object(value: object, depth: number): ValueNode {
		if (accepts(Date.prototype.getTime, value)) {
			const time = Date.prototype.getTime.call(value);

			return {
				kind: 'date',
				value: Number.isNaN(time) ? 'Invalid Date' : Date.prototype.toISOString.call(value)
			};
		}

		if (accepts(REGEXP_SOURCE, value) && value !== RegExp.prototype) {
			return {
				kind: 'regexp',
				value: `/${callBuiltIn(REGEXP_SOURCE, value)}/${callBuiltIn(REGEXP_FLAGS, value) ?? ''}`
			};
		}

		if (isError(value)) {
			return this.error(value, depth);
		}

		if (NODE_TYPE && accepts(NODE_TYPE, value)) {
			return this.domNode(value, depth);
		}

		if (Array.isArray(value)) {
			return this.array(value, depth);
		}

		if (ArrayBuffer.isView(value)) {
			return this.typedArray(value, depth);
		}

		if (accepts(MAP_SIZE, value)) {
			return this.map(value as Map<unknown, unknown>, depth);
		}

		if (accepts(SET_SIZE, value)) {
			return this.set(value as Set<unknown>, depth);
		}

		if (accepts(WEAK_MAP_HAS, value)) {
			return { kind: 'weak', className: 'WeakMap' };
		}

		if (accepts(WEAK_SET_HAS, value)) {
			return { kind: 'weak', className: 'WeakSet' };
		}

		if (globals.WeakRef && accepts(globals.WeakRef.prototype.deref, value)) {
			return { kind: 'weak', className: 'WeakRef' };
		}

		if (
			value instanceof Promise ||
			(readProperty(value, Symbol.toStringTag) === 'Promise' &&
				isNativeFunction(readProperty(value, 'then')))
		) {
			return { kind: 'promise', className: classNameOf(value) ?? 'Promise' };
		}

		if (accepts(ARRAY_BUFFER_LENGTH, value)) {
			return {
				kind: 'object',
				className: classNameOf(value) ?? 'ArrayBuffer',
				children: [
					{
						key: 'byteLength',
						value: { kind: 'number', value: String(callBuiltIn(ARRAY_BUFFER_LENGTH, value)) }
					}
				]
			};
		}

		return this.plainObject(value, depth);
	}

	private plainObject(value: object, depth: number): ValueNode {
		const node: ValueNode = { kind: 'object', className: classNameOf(value) };

		if (!this.canDescend(depth)) {
			return node;
		}

		const { children, omitted } = this.properties(value, depth);

		node.children = children;

		if (omitted > 0) {
			node.omitted = omitted;
		}

		return node;
	}

	private properties(
		value: object,
		depth: number,
		skip?: (key: string) => boolean
	): { children: ValueEntry[]; omitted: number } {
		const children: ValueEntry[] = [];
		let keys: (string | symbol)[];
		let omitted = 0;

		try {
			keys = Reflect.ownKeys(value);
		} catch {
			return { children, omitted };
		}

		for (const key of keys) {
			if (typeof key === 'string' && skip?.(key)) {
				continue;
			}

			let descriptor: PropertyDescriptor | undefined;

			try {
				descriptor = Object.getOwnPropertyDescriptor(value, key);
			} catch {
				continue;
			}

			if (!descriptor?.enumerable) {
				continue;
			}

			if (children.length >= this.options.maxProperties || this.nodes >= this.options.maxNodes) {
				omitted++;
				continue;
			}

			const child: ValueEntry =
				typeof key === 'symbol'
					? {
							key: String(callBuiltIn(Symbol.prototype.toString, key)),
							keyKind: 'symbol',
							value: { kind: 'undefined' }
						}
					: { key, keyKind: 'property', value: { kind: 'undefined' } };

			child.value =
				'value' in descriptor ? this.value(descriptor.value, depth + 1) : this.accessor(descriptor);
			children.push(child);
		}

		return { children, omitted };
	}

	private accessor(descriptor: PropertyDescriptor): ValueNode {
		this.nodes++;

		const accessor = descriptor.get && descriptor.set ? 'get-set' : descriptor.set ? 'set' : 'get';

		return { kind: 'accessor', accessor };
	}

	private array(value: unknown[], depth: number): ValueNode {
		let length = 0;

		try {
			length = value.length;
		} catch {
			// A proxy trap threw.
		}

		const node: ValueNode = {
			kind: 'array',
			className: classNameOf(value) ?? 'Array',
			size: length
		};

		if (!this.canDescend(depth)) {
			return node;
		}

		const limit = Math.min(length, this.options.maxProperties);
		const children: ValueEntry[] = [];

		for (let index = 0; index < limit; index++) {
			if (this.nodes >= this.options.maxNodes) {
				break;
			}

			let descriptor: PropertyDescriptor | undefined;

			try {
				descriptor = Object.getOwnPropertyDescriptor(value, index);
			} catch {
				descriptor = undefined;
			}

			const item =
				descriptor === undefined
					? ({ kind: 'undefined' } as ValueNode)
					: 'value' in descriptor
						? this.value(descriptor.value, depth + 1)
						: this.accessor(descriptor);

			children.push({ key: String(index), keyKind: 'index', value: item });
		}

		node.children = children;

		if (length > children.length) {
			node.omitted = length - children.length;
		}

		return node;
	}

	private typedArray(value: ArrayBufferView, depth: number): ValueNode {
		const className = String(
			callBuiltIn(TYPED_ARRAY_TAG, value) ?? classNameOf(value) ?? 'DataView'
		);
		const length = Number(callBuiltIn(TYPED_ARRAY_LENGTH, value) ?? value.byteLength);
		const node: ValueNode = { kind: 'array', className, size: length };

		if (!this.canDescend(depth) || className === 'DataView') {
			return node;
		}

		const items = value as unknown as ArrayLike<number | bigint>;
		const limit = Math.min(length, this.options.maxProperties);
		const children: ValueEntry[] = [];

		for (let index = 0; index < limit; index++) {
			children.push({
				key: String(index),
				keyKind: 'index',
				value: this.value(items[index], depth + 1)
			});
		}

		node.children = children;

		if (length > limit) {
			node.omitted = length - limit;
		}

		return node;
	}

	private map(value: Map<unknown, unknown>, depth: number): ValueNode {
		const size = Number(callBuiltIn(MAP_SIZE, value) ?? 0);
		const node: ValueNode = { kind: 'map', className: classNameOf(value) ?? 'Map', size };

		if (!this.canDescend(depth)) {
			return node;
		}

		const children: ValueEntry[] = [];

		try {
			for (const [key, item] of Map.prototype.entries.call(value)) {
				if (children.length >= this.options.maxProperties || this.nodes >= this.options.maxNodes) {
					break;
				}

				children.push({ keyValue: this.value(key, depth + 1), value: this.value(item, depth + 1) });
			}
		} catch {
			// The map changed while it was read, or a proxy trap threw.
		}

		node.children = children;

		if (size > children.length) {
			node.omitted = size - children.length;
		}

		return node;
	}

	private set(value: Set<unknown>, depth: number): ValueNode {
		const size = Number(callBuiltIn(SET_SIZE, value) ?? 0);
		const node: ValueNode = { kind: 'set', className: classNameOf(value) ?? 'Set', size };

		if (!this.canDescend(depth)) {
			return node;
		}

		const children: ValueEntry[] = [];

		try {
			for (const item of Set.prototype.values.call(value)) {
				if (children.length >= this.options.maxProperties || this.nodes >= this.options.maxNodes) {
					break;
				}

				children.push({ value: this.value(item, depth + 1) });
			}
		} catch {
			// The set changed while it was read, or a proxy trap threw.
		}

		node.children = children;

		if (size > children.length) {
			node.omitted = size - children.length;
		}

		return node;
	}

	private error(value: object, depth: number): ValueNode {
		const name = readProperty(value, 'name');
		const message = readProperty(value, 'message');
		const stack = readProperty(value, 'stack');
		const nameText = typeof name === 'string' && name ? name : (classNameOf(value) ?? 'Error');
		const messageText = typeof message === 'string' ? message : '';
		const node: ValueNode = { kind: 'error', className: nameText, value: messageText };

		if (typeof stack === 'string' && stack) {
			const trimmed = stackWithoutHeader(stack, nameText, messageText).trimEnd();

			if (trimmed) {
				node.stack = trimmed.slice(0, this.options.maxStringLength);
			}
		}

		if (this.canDescend(depth)) {
			const { children, omitted } = this.properties(
				value,
				depth,
				(key) => key === 'stack' || key === 'message'
			);
			const cause = Object.getOwnPropertyDescriptor(value, 'cause');

			if (cause && 'value' in cause && !cause.enumerable) {
				children.push({
					key: 'cause',
					keyKind: 'property',
					value: this.value(cause.value, depth + 1)
				});
			}

			if (children.length > 0) {
				node.children = children;
			}

			if (omitted > 0) {
				node.omitted = omitted;
			}
		}

		return node;
	}

	private domNode(value: object, depth: number): ValueNode {
		const type = Number(callBuiltIn(NODE_TYPE, value));
		const nodePrototype = globals.Node?.prototype;
		const elementPrototype = globals.Element?.prototype;

		if (type === 3) {
			const text = String(callBuiltIn(getterOf(nodePrototype, 'textContent'), value) ?? '');

			return { kind: 'text', value: text.slice(0, this.options.maxStringLength) };
		}

		if (type !== 1 && type !== 9 && type !== 11) {
			return { kind: 'object', className: classNameOf(value) };
		}

		const tag =
			type === 9
				? '#document'
				: type === 11
					? '#document-fragment'
					: String(callBuiltIn(getterOf(elementPrototype, 'localName'), value) ?? 'element');
		const node: ValueNode = { kind: 'element', value: tag };

		if (type === 1) {
			node.attributes = this.attributes(value);
		}

		if (!this.canDescend(depth)) {
			return node;
		}

		const childNodes = callBuiltIn(getterOf(nodePrototype, 'childNodes'), value) as
			ArrayLike<object> | undefined;
		const children: ValueEntry[] = [];
		let omitted = 0;

		for (let index = 0; childNodes && index < childNodes.length; index++) {
			const child = childNodes[index];
			const childType = Number(callBuiltIn(NODE_TYPE, child));

			if (childType === 3) {
				const text = String(
					callBuiltIn(getterOf(nodePrototype, 'textContent'), child) ?? ''
				).trim();

				if (!text) {
					continue;
				}
			} else if (childType !== 1) {
				continue;
			}

			if (children.length >= this.options.maxProperties || this.nodes >= this.options.maxNodes) {
				omitted++;
				continue;
			}

			const captured = this.value(child, depth + 1);

			if (captured.kind === 'text') {
				captured.value = captured.value?.trim();
			}

			children.push({ value: captured });
		}

		node.children = children;

		if (omitted > 0) {
			node.omitted = omitted;
		}

		return node;
	}

	private attributes(value: object): [string, string][] {
		const attributes = callBuiltIn(getterOf(globals.Element?.prototype, 'attributes'), value) as
			ArrayLike<object> | undefined;
		const attrPrototype = globals.Attr?.prototype;
		const nameGetter = getterOf(attrPrototype, 'name');
		const valueGetter = getterOf(attrPrototype, 'value');
		const result: [string, string][] = [];

		for (
			let index = 0;
			attributes && index < Math.min(attributes.length, MAX_ATTRIBUTES);
			index++
		) {
			const attribute = attributes[index];
			const name = String(callBuiltIn(nameGetter, attribute) ?? '');
			const text = String(callBuiltIn(valueGetter, attribute) ?? '');

			result.push([name, text.slice(0, MAX_ATTRIBUTE_LENGTH)]);
		}

		return result;
	}
}

/**
 * Captures a value as plain data, at the moment of the call.
 *
 * Getters defined by the page are never run: an accessor property is recorded as an accessor.
 * Built-in types are recognized with the engine's own methods rather than `instanceof`, so
 * values from another frame are recognized too. Each limit in `options` bounds the work, and
 * whatever it cuts is counted in the node's `omitted` field.
 */
export const snapshotValue = (value: unknown, options: Partial<CaptureOptions> = {}): ValueNode => {
	return new Capture({ ...DEFAULT_CAPTURE_OPTIONS, ...options }).value(value, 0);
};
