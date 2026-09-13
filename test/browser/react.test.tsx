import { StrictMode, act, createRef } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import '../../src/styles/lognal.css';
import { LogStore } from '../../src/core/store.ts';
import { LogViewer } from '../../src/react/index.ts';
import type { LogViewer as Viewer } from '../../src/viewer/viewer.ts';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
	container = document.createElement('div');
	container.style.height = '300px';
	document.body.append(container);
	root = createRoot(container);
});

afterEach(() => {
	act(() => root.unmount());
	container.remove();
});

describe('React LogViewer', () => {
	it('creates the viewer, passes it to the ref and disposes it on unmount', async () => {
		const ref = createRef<Viewer>();
		const onReady = vi.fn();

		await act(async () => {
			root.render(<LogViewer ref={ref} onReady={onReady} theme="dark" />);
		});

		expect(ref.current).not.toBeNull();
		expect(onReady).toHaveBeenLastCalledWith(ref.current);
		expect(container.querySelector('.lognal')?.getAttribute('data-theme')).toBe('dark');

		await act(async () => {
			root.render(<></>);
		});

		expect(ref.current).toBeNull();
		expect(container.querySelector('.lognal')).toBeNull();
	});

	it('shows entries written to a shared store', async () => {
		const store = new LogStore();
		const ref = createRef<Viewer>();

		store.write('written before mount');

		await act(async () => {
			root.render(<LogViewer ref={ref} store={store} />);
		});

		store.write('written after mount');
		expect(ref.current?.store).toBe(store);
		expect(store.size).toBe(2);
	});

	it('applies changed props without creating a new viewer', async () => {
		const ref = createRef<Viewer>();

		await act(async () => {
			root.render(<LogViewer ref={ref} theme="dark" toolbar={{ levels: false }} />);
		});

		const first = ref.current;

		await act(async () => {
			root.render(<LogViewer ref={ref} theme="light" toolbar={{ levels: false }} />);
		});

		expect(ref.current).toBe(first);
		expect(container.querySelector('.lognal')?.getAttribute('data-theme')).toBe('light');
		expect(container.querySelector('.lognal-levels')).toBeNull();
	});

	it('applies only the props that changed', async () => {
		const ref = createRef<Viewer>();

		await act(async () => {
			root.render(<LogViewer ref={ref} theme="dark" core={{ wrap: 'word', maxEntries: 500 }} />);
		});

		(
			ref.current?.element.querySelector('[aria-label="Wrap long lines"]') as HTMLButtonElement
		).click();
		expect(ref.current?.layout.getOptions().wrap).toBe('none');

		await act(async () => {
			root.render(<LogViewer ref={ref} theme="light" core={{ wrap: 'word', maxEntries: 800 }} />);
		});

		expect(ref.current?.layout.getOptions().wrap).toBe('none');
		expect(ref.current?.store.getOptions().maxEntries).toBe(800);

		await act(async () => {
			root.render(<LogViewer ref={ref} theme="light" />);
		});

		expect(ref.current?.layout.getOptions().wrap).toBe('word');
		expect(ref.current?.store.getOptions().maxEntries).toBe(10000);
	});

	it('keeps the toolbar when a parent renders with new objects of the same content', async () => {
		await act(async () => {
			root.render(<LogViewer toolbar={{ clear: true }} input={{ onSubmit: () => 'a' }} />);
		});

		const toolbar = container.querySelector('.lognal-toolbar');

		await act(async () => {
			root.render(<LogViewer toolbar={{ clear: true }} input={{ onSubmit: () => 'b' }} />);
		});

		expect(container.querySelector('.lognal-toolbar')).toBe(toolbar);
	});

	it('hooks the console while mounted, also under StrictMode', async () => {
		const original = console.log;
		const ref = createRef<Viewer>();

		await act(async () => {
			root.render(
				<StrictMode>
					<LogViewer ref={ref} hookConsole={{ methods: ['log'], passthrough: false }} />
				</StrictMode>
			);
		});

		console.log('captured by the component');
		expect(ref.current?.store.size).toBe(1);

		await act(async () => {
			root.render(<></>);
		});

		expect(console.log).toBe(original);
	});
});
