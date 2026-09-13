import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import '../../src/styles/lognal.css';
import { LogViewer } from '../../src/viewer/viewer.ts';
import { KO_LABELS } from '../../src/viewer/labels.ts';

const nextFrame = (): Promise<void> => {
	return new Promise((resolve) =>
		requestAnimationFrame(() => requestAnimationFrame(() => resolve()))
	);
};

const waitFor = async (check: () => boolean, timeout = 2000): Promise<void> => {
	const started = performance.now();

	while (!check()) {
		if (performance.now() - started > timeout) {
			throw new Error('Timed out waiting for the condition');
		}

		await nextFrame();
	}
};

/** Counts canvas pixels that differ from the top-left pixel, which is background. */
const paintedPixels = (viewer: LogViewer): number => {
	const canvas = viewer.element.querySelector('canvas') as HTMLCanvasElement;
	const context = canvas.getContext('2d') as CanvasRenderingContext2D;
	const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
	let painted = 0;

	for (let index = 0; index < data.length; index += 4) {
		if (data[index] !== data[0] || data[index + 1] !== data[1] || data[index + 2] !== data[2]) {
			painted++;
		}
	}

	return painted;
};

let container: HTMLDivElement;

beforeEach(() => {
	container = document.createElement('div');
	container.style.width = '640px';
	container.style.height = '320px';
	document.body.append(container);
});

afterEach(() => {
	container.remove();
});

describe('LogViewer', () => {
	it('builds the toolbar, the log area and the status bar', () => {
		const viewer = new LogViewer(container);

		expect(viewer.element.querySelector('[role="toolbar"]')).not.toBeNull();
		expect(viewer.element.querySelector('canvas')).not.toBeNull();
		expect(viewer.element.querySelector('.lognal-statusbar')).not.toBeNull();
		expect(viewer.element.querySelector('.lognal-input')).toBeNull();
		viewer.dispose();
	});

	it('draws entries on the canvas', async () => {
		const viewer = new LogViewer(container, { theme: 'dark' });

		await nextFrame();

		const empty = paintedPixels(viewer);

		viewer.console.log('hello %s', 'canvas', { id: 1 });
		viewer.console.error(new Error('drawn in red'));
		await nextFrame();

		expect(paintedPixels(viewer)).toBeGreaterThan(empty + 100);
		viewer.dispose();
	});

	it('uses the colors of the theme', async () => {
		const viewer = new LogViewer(container, { theme: 'dark' });
		const canvas = viewer.element.querySelector('canvas') as HTMLCanvasElement;

		await nextFrame();

		const [red, green, blue] = (canvas.getContext('2d') as CanvasRenderingContext2D).getImageData(
			1,
			1,
			1,
			1
		).data;

		expect([red, green, blue]).toEqual([0x16, 0x18, 0x1d]);

		viewer.setOptions({ theme: 'light' });
		await nextFrame();

		expect(
			Array.from(
				(canvas.getContext('2d') as CanvasRenderingContext2D)
					.getImageData(1, 1, 1, 1)
					.data.slice(0, 3)
			)
		).toEqual([255, 255, 255]);
		viewer.dispose();
	});

	it('filters from the toolbar and reports the count in the status bar', async () => {
		const viewer = new LogViewer(container, { core: { mergeRepeats: false } });

		viewer.console.info('database connected');
		viewer.console.warn('disk almost full');
		viewer.console.log('request handled');

		const input = viewer.element.querySelector('.lognal-filter-input') as HTMLInputElement;

		input.value = 'disk';
		input.dispatchEvent(new Event('input'));

		await waitFor(() => viewer.layout.visibleCount === 1);
		await waitFor(
			() => viewer.element.querySelector('.lognal-status-count')?.textContent === '1 of 3 entries'
		);

		const levels = viewer.element.querySelector('.lognal-levels') as HTMLSelectElement;

		levels.value = 'error';
		levels.dispatchEvent(new Event('change'));
		await nextFrame();

		expect(viewer.getFilter()).toEqual({ text: 'disk', minLevel: 'error' });
		expect(viewer.layout.visibleCount).toBe(0);
		viewer.dispose();
	});

	it('toggles following, clears and changes wrapping from the toolbar', async () => {
		const viewer = new LogViewer(container);
		const follow = viewer.element.querySelector(
			'[aria-label="Follow new logs"]'
		) as HTMLButtonElement;
		const wrap = viewer.element.querySelector(
			'[aria-label="Wrap long lines"]'
		) as HTMLButtonElement;
		const clear = viewer.element.querySelector('[aria-label="Clear logs"]') as HTMLButtonElement;

		expect(follow.getAttribute('aria-pressed')).toBe('true');
		follow.click();
		expect(follow.getAttribute('aria-pressed')).toBe('false');
		expect(viewer.isFollowing).toBe(false);

		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('none');
		expect(wrap.getAttribute('aria-pressed')).toBe('false');

		viewer.console.log('to be cleared');
		clear.click();
		expect(viewer.store.size).toBe(0);
		viewer.dispose();
	});

	it('restores the previous wrapping mode and lets the level menu replace a level list', async () => {
		const viewer = new LogViewer(container, { core: { wrap: 'char' } });
		const wrap = viewer.element.querySelector(
			'[aria-label="Wrap long lines"]'
		) as HTMLButtonElement;
		const levels = viewer.element.querySelector('.lognal-levels') as HTMLSelectElement;

		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('none');
		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('char');

		viewer.setFilter({ levels: ['debug'] });
		levels.value = 'warn';
		levels.dispatchEvent(new Event('change'));
		expect(viewer.getFilter()).toEqual({ levels: undefined, minLevel: 'warn' });
		viewer.dispose();
	});

	it('reads font sizes written in rem and line heights written in px', async () => {
		const viewer = new LogViewer(container);

		viewer.element.style.setProperty('--lognal-font-size', '1rem');
		viewer.element.style.setProperty('--lognal-line-height', '24px');
		viewer.refresh();

		expect(viewer.element.style.getPropertyValue('--lognal-cell-height')).toBe('24px');
		viewer.dispose();
	});

	it('follows new entries to the bottom and stops when scrolled up', async () => {
		const viewer = new LogViewer(container, { statusBar: false, toolbar: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;

		for (let index = 0; index < 200; index++) {
			viewer.console.log(`line ${index}`);
		}

		await waitFor(
			() =>
				viewport.scrollTop > 0 &&
				viewport.scrollTop + viewport.clientHeight >= viewport.scrollHeight - 1
		);

		viewport.scrollTop = 0;
		await waitFor(() => !viewer.isFollowing);

		viewer.console.log('new line');
		await nextFrame();

		expect(viewport.scrollTop).toBe(0);
		expect((viewer.element.querySelector('.lognal-new-logs') as HTMLButtonElement).hidden).toBe(
			false
		);

		viewer.scrollToBottom();
		await waitFor(() => viewport.scrollTop + viewport.clientHeight >= viewport.scrollHeight - 1);
		viewer.dispose();
	});

	it('expands a value when its row is clicked', async () => {
		const viewer = new LogViewer(container, { toolbar: false, timestamps: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;

		viewer.console.log({ id: 1, name: 'lognal' });
		await nextFrame();
		expect(viewer.layout.rowCount).toBe(1);

		const rect = viewport.getBoundingClientRect();
		const point = {
			clientX: rect.left + 60,
			clientY: rect.top + 12,
			bubbles: true,
			button: 0,
			pointerId: 1,
			pointerType: 'mouse'
		};

		viewport.dispatchEvent(new PointerEvent('pointerdown', point));
		viewport.dispatchEvent(new PointerEvent('pointerup', point));
		await nextFrame();

		expect(viewer.layout.rowCount).toBe(3);
		viewer.dispose();
	});

	it('selects and returns text', async () => {
		const viewer = new LogViewer(container, { core: { mergeRepeats: false } });

		viewer.console.log('first');
		viewer.console.log('두 번째');
		await nextFrame();
		viewer.selectAll();

		expect(viewer.getSelectionText()).toBe('first\n두 번째');

		viewer.clearSelection();
		expect(viewer.getSelectionText()).toBe('');
		viewer.dispose();
	});

	it('mirrors the visible entries for screen readers', async () => {
		const viewer = new LogViewer(container);

		viewer.console.warn('screen reader text');
		await waitFor(() =>
			(viewer.element.querySelector('.lognal-mirror')?.textContent ?? '').includes(
				'screen reader text'
			)
		);
		viewer.dispose();
	});

	it('uses the Korean labels for the ko locale, also when the locale changes later', () => {
		const viewer = new LogViewer(container, { locale: 'ko-KR' });

		expect(viewer.element.querySelector(`[aria-label="${KO_LABELS.clear}"]`)).not.toBeNull();

		viewer.setOptions({ locale: 'en', labels: { clear: 'Empty' } });
		expect(viewer.element.querySelector('[aria-label="Empty"]')).not.toBeNull();
		expect(viewer.element.querySelector('[aria-label="Scroll to top"]')).not.toBeNull();

		viewer.setOptions({ locale: 'ko' });
		expect(viewer.element.querySelector(`[aria-label="${KO_LABELS.scrollToTop}"]`)).not.toBeNull();
		expect(viewer.element.querySelector('[aria-label="Empty"]')).not.toBeNull();
		viewer.dispose();
	});

	it('removes itself and stops the console hook on dispose', () => {
		const viewer = new LogViewer(container);
		const target = { log: () => undefined } as unknown as Console;
		const original = target.log;

		viewer.hookConsole(target, { methods: ['log'] });
		expect(target.log).not.toBe(original);

		viewer.dispose();
		expect(target.log).toBe(original);
		expect(container.childElementCount).toBe(0);
	});

	it('prints the reply of a command', async () => {
		const viewer = new LogViewer(container, {
			input: { onSubmit: async (command) => `echo: ${command}` }
		});
		const field = viewer.element.querySelector('.lognal-input-field') as HTMLTextAreaElement;

		field.value = '안녕';
		field.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));

		await waitFor(() => viewer.store.size === 2);

		const [input, output] = viewer.store.toArray();

		expect(input).toMatchObject({ kind: 'input', parts: [{ text: '안녕' }] });
		expect(output).toMatchObject({ kind: 'output', parts: [{ text: 'echo: 안녕' }] });
		viewer.dispose();
	});
});
