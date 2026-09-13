'use client';

import {
	forwardRef,
	useEffect,
	useMemo,
	useRef,
	useState,
	type CSSProperties,
	type ForwardedRef
} from 'react';
import type { LogFilter } from '../core/filter.js';
import { DEFAULT_LAYOUT_OPTIONS } from '../core/layout/layout.js';
import { DEFAULT_STORE_OPTIONS } from '../core/store.js';
import type { HookConsoleOptions } from '../sources/console/hook.js';
import type { ViewerLabels } from '../viewer/labels.js';
import { LogViewer as Viewer, type CoreOptions, type LogViewerOptions } from '../viewer/viewer.js';

export interface LogViewerProps extends LogViewerOptions {
	className?: string;
	style?: CSSProperties;
	/**
	 * Records the global `console` into the viewer while the component is mounted. Pass options
	 * to choose the methods and the capture limits.
	 */
	hookConsole?: boolean | HookConsoleOptions;
	/** Called with the viewer once it exists, and with `null` after it is disposed. */
	onReady?: (viewer: Viewer | null) => void;
	onFollowChange?: (following: boolean) => void;
	onFilterChange?: (filter: LogFilter | null) => void;
	onSelectionChange?: (text: string) => void;
}

type ViewerOptions = Omit<LogViewerOptions, 'store' | 'renderer'>;

const PROPS_WITHOUT_OPTIONS = new Set([
	'className',
	'style',
	'hookConsole',
	'onReady',
	'onFollowChange',
	'onFilterChange',
	'onSelectionChange',
	'store',
	'renderer'
]);

/** The value a core option returns to when its prop is removed. */
const CORE_DEFAULTS: CoreOptions = {
	...DEFAULT_STORE_OPTIONS,
	...DEFAULT_LAYOUT_OPTIONS,
	filter: null
};

const CORE_PREFIX = 'core.';

/** A string that changes only when the data of a value changes. Functions do not count. */
const keyOf = (value: unknown): string => {
	return (
		JSON.stringify(value, (_key, item: unknown) =>
			typeof item === 'function' ? '(function)' : item
		) ?? ''
	);
};

/** The data key of every option, with each core option on its own. */
const keysOfOptions = (options: ViewerOptions): Map<string, string> => {
	const keys = new Map<string, string>();

	for (const [name, value] of Object.entries(options)) {
		if (name === 'core' && value) {
			for (const [coreName, coreValue] of Object.entries(value)) {
				keys.set(`${CORE_PREFIX}${coreName}`, keyOf(coreValue));
			}
		} else {
			keys.set(name, keyOf(value));
		}
	}

	return keys;
};

const assignRef = (ref: ForwardedRef<Viewer | null>, value: Viewer | null): void => {
	if (typeof ref === 'function') {
		ref(value);
	} else if (ref) {
		ref.current = value;
	}
};

/**
 * The lognal viewer as a React component.
 *
 * The component renders a container and creates the viewer in it after mounting. Log entries
 * never go through React state: write to `store`, to the viewer from `onReady` or the ref, or
 * turn on `hookConsole`.
 *
 * Only the option props whose data changed are applied, so passing a new object with the same
 * contents on every render costs nothing, and a change to one prop does not undo what the
 * user did in the viewer, such as turning off wrapping from the toolbar.
 *
 * Give the component a height, through `style`, `className` or its parent.
 */
export const LogViewer = forwardRef<Viewer | null, LogViewerProps>(function LogViewer(props, ref) {
	const containerRef = useRef<HTMLDivElement>(null);
	const latest = useRef(props);
	const latestRef = useRef(ref);
	const appliedKeys = useRef(new Map<string, string>());
	const [viewer, setViewer] = useState<Viewer | null>(null);
	const { className, style, store, renderer, hookConsole } = props;

	latest.current = props;
	latestRef.current = ref;

	const options = useMemo(() => {
		const result: Record<string, unknown> = {};

		for (const [name, value] of Object.entries(props)) {
			if (!PROPS_WITHOUT_OPTIONS.has(name) && value !== undefined) {
				result[name] = value;
			}
		}

		return result as ViewerOptions;
	}, [props]);
	const optionsKey = keyOf(options);

	// Functions inside options call the latest props, so a new function on every render does not
	// count as a change.
	const stableOptions = useMemo((): ViewerOptions => {
		const current = options;
		// Options that were removed go back to their defaults instead of keeping the old value.
		const result: ViewerOptions = {
			theme: 'auto',
			font: {},
			timestamps: true,
			toolbar: true,
			statusBar: true,
			input: null,
			labels: {},
			locale: undefined,
			entryMenu: true,
			...current
		};

		if (current.input) {
			result.input = {
				...current.input,
				onSubmit: (command, instance) => latest.current.input?.onSubmit(command, instance)
			};
		}

		if (typeof current.timestamps === 'function') {
			result.timestamps = (time: number) => {
				const format = latest.current.timestamps;

				return typeof format === 'function' ? format(time) : String(time);
			};
		}

		if (current.labels?.entries) {
			result.labels = {
				...current.labels,
				entries: (...args: Parameters<ViewerLabels['entries']>) =>
					latest.current.labels?.entries?.(...args) ?? ''
			};
		}

		return result;
		// Rebuilt only when the data changes, which `optionsKey` tracks.
	}, [optionsKey]);
	const latestOptions = useRef(stableOptions);

	latestOptions.current = stableOptions;

	useEffect(() => {
		const container = containerRef.current;

		if (!container) {
			return;
		}

		const instance = new Viewer(container, { ...latestOptions.current, store, renderer });
		const offFollow = instance.on('follow', (value) => latest.current.onFollowChange?.(value));
		const offFilter = instance.on('filter', (value) => latest.current.onFilterChange?.(value));
		const offSelection = instance.on('selection', (value) =>
			latest.current.onSelectionChange?.(value)
		);

		appliedKeys.current = keysOfOptions(latestOptions.current);
		setViewer(instance);
		assignRef(latestRef.current, instance);
		latest.current.onReady?.(instance);

		return () => {
			offFollow();
			offFilter();
			offSelection();
			instance.dispose();
			setViewer(null);
			assignRef(latestRef.current, null);
			latest.current.onReady?.(null);
		};
	}, [store, renderer]);

	useEffect(() => {
		if (!viewer) {
			return;
		}

		const previous = appliedKeys.current;
		const next = keysOfOptions(stableOptions);
		const changes: Record<string, unknown> = {};
		const coreChanges: Record<string, unknown> = {};

		for (const name of new Set([...previous.keys(), ...next.keys()])) {
			if (previous.get(name) === next.get(name)) {
				continue;
			}

			if (name.startsWith(CORE_PREFIX)) {
				const coreName = name.slice(CORE_PREFIX.length) as keyof CoreOptions;

				coreChanges[coreName] = stableOptions.core?.[coreName] ?? CORE_DEFAULTS[coreName];
			} else {
				changes[name] = stableOptions[name as keyof ViewerOptions];
			}
		}

		if (Object.keys(coreChanges).length > 0) {
			changes.core = coreChanges;
		}

		appliedKeys.current = next;

		if (Object.keys(changes).length > 0) {
			viewer.setOptions(changes as ViewerOptions);
		}
	}, [viewer, stableOptions]);

	const hookKey = keyOf(hookConsole);

	useEffect(() => {
		if (!viewer || !hookConsole) {
			return;
		}

		return viewer.hookConsole(console, hookConsole === true ? undefined : hookConsole);
		// Hooked again only when the data of `hookConsole` changes, which `hookKey` tracks.
	}, [viewer, hookKey]);

	return <div ref={containerRef} className={className} style={{ height: '100%', ...style }} />;
});
