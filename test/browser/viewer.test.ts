import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
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

/** Opens the level menu and chooses the option with the given label. */
const chooseLevel = (viewer: LogViewer, label: string): void => {
	const trigger = viewer.element.querySelector('.lognal-levels') as HTMLButtonElement;

	trigger.click();

	const option = Array.from(viewer.element.querySelectorAll('.lognal-popup [role="option"]')).find(
		(item) => item.textContent === label
	) as HTMLElement;

	option.click();
};

/** Moves a mouse pointer over the log, at a point relative to the top left of the log area. */
const hover = (viewer: LogViewer, x: number, y: number): void => {
	const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
	const rect = viewport.getBoundingClientRect();

	viewport.dispatchEvent(
		new PointerEvent('pointermove', {
			clientX: rect.left + x,
			clientY: rect.top + y,
			bubbles: true,
			pointerId: 1,
			pointerType: 'mouse'
		})
	);
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

		chooseLevel(viewer, 'Errors only');
		await nextFrame();

		expect(viewer.getFilter()).toEqual({ text: 'disk', minLevel: 'error' });
		expect(viewer.element.querySelector('.lognal-levels-value')?.textContent).toBe('Errors only');
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
		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('none');
		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('char');

		viewer.setFilter({ levels: ['debug'] });
		chooseLevel(viewer, 'Warnings and errors');
		expect(viewer.getFilter()).toEqual({ levels: undefined, minLevel: 'warn' });
		viewer.dispose();
	});

	it('opens the level menu with the keyboard and closes it with Escape', async () => {
		const viewer = new LogViewer(container);
		const trigger = viewer.element.querySelector('.lognal-levels') as HTMLButtonElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const key = (target: HTMLElement, name: string): void => {
			target.dispatchEvent(
				new KeyboardEvent('keydown', { key: name, bubbles: true, cancelable: true })
			);
		};

		trigger.focus();
		key(trigger, 'ArrowDown');
		expect(trigger.getAttribute('aria-expanded')).toBe('true');
		expect(popup.getAttribute('role')).toBe('listbox');
		expect(document.activeElement).toBe(popup);
		expect(popup.querySelector('[aria-selected="true"]')?.textContent).toBe('All levels');

		key(popup, 'ArrowDown');
		key(popup, 'ArrowDown');
		key(popup, 'Enter');
		expect(viewer.getFilter()).toEqual({ levels: undefined, minLevel: 'info' });
		expect(trigger.getAttribute('aria-expanded')).toBe('false');
		expect(document.activeElement).toBe(trigger);

		key(trigger, 'ArrowDown');
		expect(popup.querySelector('[aria-selected="true"]')?.textContent).toBe('Info and above');
		key(popup, 'Escape');
		expect(trigger.getAttribute('aria-expanded')).toBe('false');
		expect(document.activeElement).toBe(trigger);
		expect(viewer.getFilter()).toEqual({ levels: undefined, minLevel: 'info' });

		viewer.setFilter({ minLevel: 'error' });
		expect(viewer.element.querySelector('.lognal-levels-value')?.textContent).toBe('Errors only');
		viewer.dispose();
	});

	it('shows a menu button over the entry under the pointer and copies the entry from it', async () => {
		const viewer = new LogViewer(container, { timestamps: false, core: { mergeRepeats: false } });
		const button = viewer.element.querySelector('.lognal-entry-actions') as HTMLButtonElement;
		const writeText = vi.spyOn(navigator.clipboard, 'writeText').mockResolvedValue(undefined);

		viewer.console.log('first entry');
		viewer.write('second entry\nline two\nline three', { level: 'error' });
		await nextFrame();
		expect(button.hidden).toBe(true);

		const rowHeight = parseFloat(viewer.element.style.getPropertyValue('--lognal-cell-height'));

		// The third row is the second line of the second entry, which starts on the second row.
		hover(viewer, 100, 4 + rowHeight * 2.5);
		expect(button.hidden).toBe(false);
		expect(button.getAttribute('aria-label')).toBe('Entry actions');
		expect(button.style.transform).toBe(`translateY(${Math.round(4 + rowHeight)}px)`);

		button.click();

		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const item = popup.querySelector('[role="menuitem"]') as HTMLElement;

		expect(popup.getAttribute('role')).toBe('menu');
		expect(button.getAttribute('aria-expanded')).toBe('true');
		expect(item.textContent).toBe('Copy as text');

		item.click();
		await waitFor(() => writeText.mock.calls.length === 1);

		const [first, second] = viewer.store.toArray();

		expect(writeText).toHaveBeenCalledWith(viewer.getEntryText(second.id));
		expect(viewer.getEntryText(second.id)).toBe('second entry\nline two\nline three');
		expect(viewer.getEntryText(first.id)).toBe('first entry');
		expect(button.getAttribute('aria-expanded')).toBe('false');

		viewer.element
			.querySelector('.lognal-body')
			?.dispatchEvent(new PointerEvent('pointerleave', { pointerType: 'mouse' }));
		expect(button.hidden).toBe(true);

		writeText.mockRestore();
		viewer.dispose();
	});

	it('opens the entry menu with Shift+F10 and hides the button when entryMenu is off', async () => {
		const viewer = new LogViewer(container, { toolbar: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const button = viewer.element.querySelector('.lognal-entry-actions') as HTMLButtonElement;

		viewer.console.log('only entry');
		await nextFrame();

		viewport.focus();
		viewport.dispatchEvent(
			new KeyboardEvent('keydown', { key: 'F10', shiftKey: true, bubbles: true, cancelable: true })
		);
		expect(popup.getAttribute('role')).toBe('menu');
		expect(document.activeElement).toBe(popup);
		expect(button.hidden).toBe(false);

		popup.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
		expect(document.activeElement).toBe(viewport);
		expect(button.hidden).toBe(true);

		viewer.setOptions({ entryMenu: false });
		hover(viewer, 100, 8);
		expect(button.hidden).toBe(true);
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

	it('keeps the entry at the top of the view in place when the width changes', async () => {
		const viewer = new LogViewer(container, { core: { mergeRepeats: false, maxEntries: 20000 } });
		const sentence =
			'Each line is long enough to wrap onto more rows when the viewer gets narrow. ';

		for (let index = 0; index < 5000; index++) {
			viewer.write(`${index} ${sentence.repeat((index % 4) + 1)}`);
		}

		await nextFrame();
		viewer.scrollToEntry(3000);
		await nextFrame();

		const topEntry = (): number =>
			(viewer as unknown as { visibleRows: { entry: { id: number } }[] }).visibleRows[0]?.entry.id;

		expect(topEntry()).toBe(3000);

		container.style.width = '360px';
		await waitFor(() => viewer.layout.pendingCount === 0, 5000);
		await nextFrame();

		expect(topEntry()).toBe(3000);
		expect(viewer.isFollowing).toBe(false);
		viewer.dispose();
	});

	it('scrolls sideways for a table wider than the viewer while other lines wrap', async () => {
		container.style.width = '320px';

		const viewer = new LogViewer(container, { timestamps: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;

		viewer.console.log('A sentence that wraps inside the narrow viewer instead of scrolling.');
		await nextFrame();
		expect(viewport.scrollWidth).toBeLessThanOrEqual(viewport.clientWidth);

		viewer.console.table([
			{ name: 'Alice', role: 'administrator', team: 'platform', active: true }
		]);
		await nextFrame();
		expect(viewport.scrollWidth).toBeGreaterThan(viewport.clientWidth);
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
