import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import '../../src/styles/lognal.css';
import { CanvasRenderer } from '../../src/renderer/canvas/canvas-renderer.ts';
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

/** Opens the level menu, chooses the option with the given label and closes the menu. */
const chooseLevel = (viewer: LogViewer, label: string): void => {
	const trigger = viewer.element.querySelector('.lognal-levels') as HTMLButtonElement;
	const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;

	trigger.click();

	const option = Array.from(viewer.element.querySelectorAll('.lognal-popup [role="option"]')).find(
		(item) => item.textContent === label
	) as HTMLElement;

	option.click();
	popup.dispatchEvent(
		new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true })
	);
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

/** Clicks the log with a mouse, at a point relative to the top left of the log area. */
const click = (viewer: LogViewer, x: number, y: number, init: PointerEventInit = {}): void => {
	const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
	const rect = viewport.getBoundingClientRect();
	const point: PointerEventInit = {
		clientX: rect.left + x,
		clientY: rect.top + y,
		bubbles: true,
		button: 0,
		pointerId: 1,
		pointerType: 'mouse',
		...init
	};

	viewport.dispatchEvent(new PointerEvent('pointerdown', point));
	viewport.dispatchEvent(new PointerEvent('pointerup', point));
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

	it('shows the name of a toolbar control as soon as the pointer reaches it', () => {
		const viewer = new LogViewer(container);
		const follow = viewer.element.querySelector('.lognal-button') as HTMLButtonElement;
		const tooltip = viewer.element.querySelector('.lognal-tooltip') as HTMLDivElement;
		const isOpen = (): boolean => {
			return tooltip.hasAttribute('popover') ? tooltip.matches(':popover-open') : !tooltip.hidden;
		};

		expect(follow.title).toBe('');
		expect(isOpen()).toBe(false);

		follow.dispatchEvent(new PointerEvent('pointerenter', { pointerType: 'mouse' }));

		expect(tooltip.textContent).toBe('Follow new logs');
		expect(isOpen()).toBe(true);

		follow.dispatchEvent(new PointerEvent('pointerleave', { pointerType: 'mouse' }));

		expect(isOpen()).toBe(false);
		viewer.dispose();
	});

	it('leaves the tooltip to the browser when tooltips are off', () => {
		const viewer = new LogViewer(container, { tooltips: false });
		const follow = viewer.element.querySelector('.lognal-button') as HTMLButtonElement;
		const tooltip = viewer.element.querySelector('.lognal-tooltip') as HTMLDivElement;

		expect(follow.title).toBe('Follow new logs');

		follow.dispatchEvent(new PointerEvent('pointerenter', { pointerType: 'mouse' }));

		expect(tooltip.textContent).toBe('');
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

		viewer.setOptions({ theme: 'midnight' });
		await nextFrame();

		expect(
			Array.from(
				(canvas.getContext('2d') as CanvasRenderingContext2D)
					.getImageData(1, 1, 1, 1)
					.data.slice(0, 3)
			)
		).toEqual([0x0f, 0x12, 0x26]);
		viewer.dispose();
	});

	it('chooses a theme from the toolbar and resolves the automatic one', async () => {
		const viewer = new LogViewer(container);
		const trigger = viewer.element.querySelector('[aria-label="Theme"]') as HTMLButtonElement;
		const prefersDark = matchMedia('(prefers-color-scheme: dark)').matches;
		const options = (): HTMLElement[] => {
			return Array.from(viewer.element.querySelectorAll('.lognal-popup [role="option"]'));
		};

		// The automatic theme is resolved here, so the stylesheet holds one block per palette.
		expect(viewer.element.dataset.theme).toBe(prefersDark ? 'dark' : 'light');

		trigger.click();
		expect(options().map((option) => option.textContent)).toEqual([
			'System',
			'Light',
			'Paper',
			'Dark',
			'Midnight',
			'Ember',
			'Moss'
		]);
		expect(options()[0].getAttribute('aria-selected')).toBe('true');

		options()[5].click();
		await nextFrame();

		expect(viewer.element.dataset.theme).toBe('ember');
		expect(trigger.getAttribute('aria-expanded')).toBe('false');

		trigger.click();
		expect(options()[5].getAttribute('aria-selected')).toBe('true');

		// A second press on the button closes the menu.
		trigger.click();
		expect(trigger.getAttribute('aria-expanded')).toBe('false');

		viewer.setOptions({ themes: ['auto', { name: 'mine', label: 'Mine' }] });
		trigger.click();
		expect(options().map((option) => option.textContent)).toEqual(['System', 'Mine']);

		options()[1].click();
		await nextFrame();

		expect(viewer.element.dataset.theme).toBe('mine');
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

		chooseLevel(viewer, 'Error');
		await nextFrame();

		expect(viewer.getFilter()).toEqual({ text: 'disk', levels: ['error'] });
		expect(viewer.element.querySelector('.lognal-levels-value')?.textContent).toBe('Error');
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

	it('restores the previous wrapping mode and adds a level from the level menu', async () => {
		const viewer = new LogViewer(container, { core: { wrap: 'char' } });
		const wrap = viewer.element.querySelector(
			'[aria-label="Wrap long lines"]'
		) as HTMLButtonElement;
		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('none');
		wrap.click();
		expect(viewer.layout.getOptions().wrap).toBe('char');

		viewer.setFilter({ levels: ['debug'] });
		chooseLevel(viewer, 'Warning');
		expect(viewer.getFilter()).toEqual({ levels: ['debug', 'warn'] });
		expect(viewer.element.querySelector('.lognal-levels-value')?.textContent).toBe('2 levels');

		chooseLevel(viewer, 'Debug');
		expect(viewer.getFilter()).toEqual({ levels: ['warn'] });

		chooseLevel(viewer, 'All levels');
		expect(viewer.getFilter()).toEqual({ levels: undefined });
		expect(viewer.element.querySelector('.lognal-levels-value')?.textContent).toBe('All levels');
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
		expect(viewer.getFilter()).toEqual({ levels: ['log'] });

		// The menu takes several levels, so it stays open after a choice.
		expect(trigger.getAttribute('aria-expanded')).toBe('true');
		expect(document.activeElement).toBe(popup);
		expect(popup.querySelector('[aria-selected="true"]')?.textContent).toBe('Log');

		key(popup, 'ArrowDown');
		key(popup, 'Enter');
		expect(viewer.getFilter()).toEqual({ levels: ['log', 'info'] });
		expect(popup.querySelectorAll('[aria-selected="true"]').length).toBe(2);

		key(popup, 'Escape');
		expect(trigger.getAttribute('aria-expanded')).toBe('false');
		expect(document.activeElement).toBe(trigger);
		expect(viewer.getFilter()).toEqual({ levels: ['log', 'info'] });

		viewer.setFilter({ minLevel: 'error' });
		expect(viewer.element.querySelector('.lognal-levels-value')?.textContent).toBe('Error');
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
		const items = Array.from(popup.querySelectorAll<HTMLElement>('[role="menuitem"]'));
		const [item] = items;

		expect(popup.getAttribute('role')).toBe('menu');
		expect(button.getAttribute('aria-expanded')).toBe('true');
		expect(items.map((element) => element.textContent)).toEqual([
			'Copy as text',
			'Copy with timestamp',
			'Copy as formatted text'
		]);

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

	it('marks the rows of the hovered entry for the renderer', async () => {
		const render = vi.spyOn(CanvasRenderer.prototype, 'render');
		const viewer = new LogViewer(container, { timestamps: false, core: { mergeRepeats: false } });
		const hoveredRows = (): boolean[] => {
			const frame = render.mock.calls[render.mock.calls.length - 1][0];

			return frame.decorations.map((decoration) => Boolean(decoration.hovered));
		};

		viewer.console.log('first entry');
		viewer.write('second entry\nline two', { level: 'warn' });
		await nextFrame();
		expect(hoveredRows()).toEqual([false, false, false]);

		const rowHeight = parseFloat(viewer.element.style.getPropertyValue('--lognal-cell-height'));

		hover(viewer, 100, 4 + rowHeight * 1.5);
		await nextFrame();
		expect(hoveredRows()).toEqual([false, true, true]);

		viewer.element
			.querySelector('.lognal-body')
			?.dispatchEvent(new PointerEvent('pointerleave', { pointerType: 'mouse' }));
		await nextFrame();
		expect(hoveredRows()).toEqual([false, false, false]);

		render.mockRestore();
		viewer.dispose();
	});

	it('copies an entry with its timestamp and adds menu items of its own', async () => {
		const onSelect = vi.fn();
		const viewer = new LogViewer(container, {
			timestamps: 'iso',
			entryMenu: { items: (entry) => [{ label: `Pin ${entry.id}`, onSelect }] }
		});
		const button = viewer.element.querySelector('.lognal-entry-actions') as HTMLButtonElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;

		viewer.write('hello', { time: 0 });
		await nextFrame();

		const [entry] = viewer.store.toArray();

		expect(viewer.getEntryText(entry.id, { timestamp: true })).toBe(
			'1970-01-01T00:00:00.000Z hello'
		);

		// A closed value is copied in full, not as its one-line preview.
		viewer.console.log('user', { id: 1, roles: ['admin', 'editor'], profile: { city: 'Seoul' } });
		await nextFrame();

		const user = viewer.store.at(1)!;

		expect(viewer.layout.rowsOf(user.id)).toBe(1);
		expect(viewer.getEntryText(user.id)).toBe(
			"user { id: 1, roles: ['admin', 'editor'], profile: { city: 'Seoul' } }"
		);

		hover(viewer, 200, 8);
		button.click();

		const labels = Array.from(popup.children).map((child) =>
			child.getAttribute('role') === 'separator' ? '---' : child.textContent
		);

		expect(labels).toEqual([
			'Copy as text',
			'Copy with timestamp',
			'Copy as formatted text',
			'---',
			`Pin ${entry.id}`
		]);

		(popup.querySelector('[role="menuitem"]:last-child') as HTMLElement).click();
		expect(onSelect).toHaveBeenCalledWith(entry, viewer);
		expect(popup.matches(':popover-open')).toBe(false);

		viewer.setOptions({ entryMenu: { copy: false } });
		hover(viewer, 200, 30);
		hover(viewer, 200, 8);
		expect(button.hidden).toBe(true);
		viewer.dispose();
	});

	it('copies an entry as formatted text with colors and as data', async () => {
		const viewer = new LogViewer(container, { theme: 'light', timestamps: false });
		const button = viewer.element.querySelector('.lognal-entry-actions') as HTMLButtonElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const write = vi.spyOn(navigator.clipboard, 'write').mockResolvedValue(undefined);
		const writeText = vi.spyOn(navigator.clipboard, 'writeText').mockResolvedValue(undefined);
		const user = {
			id: 1,
			name: 'lognal',
			roles: ['admin', 'editor'],
			profile: { city: 'Seoul', zip: '04524', verified: true }
		};
		const choose = (label: string): void => {
			hover(viewer, 200, 8);
			button.click();
			(
				Array.from(popup.querySelectorAll('[role="menuitem"]')).find(
					(item) => item.textContent === label
				) as HTMLElement
			).click();
		};

		viewer.console.log('user', user);
		await nextFrame();

		const [entry] = viewer.store.toArray();
		const formatted = [
			'user {',
			'  id: 1,',
			"  name: 'lognal',",
			"  roles: ['admin', 'editor'],",
			"  profile: { city: 'Seoul', zip: '04524', verified: true }",
			'}'
		].join('\n');

		expect(viewer.getEntryText(entry.id, { format: 'formatted' })).toBe(formatted);
		expect(JSON.parse(viewer.getEntryText(entry.id, { format: 'data' }))).toEqual(user);

		choose('Copy as formatted text');
		await waitFor(() => write.mock.calls.length === 1);

		const [item] = write.mock.calls[0][0];
		const html = await (await item.getType('text/html')).text();

		expect(await (await item.getType('text/plain')).text()).toBe(formatted);
		expect(html).toContain('<pre style="');
		// Strings take the string token color of the light theme.
		expect(html).toContain(`<span style="color: #1f7a47">'lognal'</span>`);

		choose('Copy as data');
		await waitFor(() => writeText.mock.calls.length === 1);
		expect(JSON.parse(writeText.mock.calls[0][0])).toEqual(user);

		write.mockRestore();
		writeText.mockRestore();
		viewer.dispose();
	});

	it('expands and collapses every value of an entry from its menu', async () => {
		const viewer = new LogViewer(container, { timestamps: false, core: { mergeRepeats: false } });
		const button = viewer.element.querySelector('.lognal-entry-actions') as HTMLButtonElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const labelsAt = (y: number): string[] => {
			hover(viewer, 200, y);
			button.click();

			return Array.from(popup.querySelectorAll('[role="menuitem"]')).map(
				(item) => item.textContent ?? ''
			);
		};
		const choose = (label: string): void => {
			(
				Array.from(popup.querySelectorAll('[role="menuitem"]')).find(
					(item) => item.textContent === label
				) as HTMLElement
			).click();
		};

		viewer.console.log({ user: { id: 1, roles: ['admin'] } });
		viewer.console.log('plain text');
		await nextFrame();

		const [entry, plain] = viewer.store.toArray();

		expect(labelsAt(8)).toContain('Expand all');
		choose('Expand all');
		await nextFrame();
		// The object, `user`, its `id` and `roles`, and the item of `roles`.
		expect(viewer.layout.rowsOf(entry.id)).toBe(5);

		expect(labelsAt(8)).toContain('Collapse all');
		choose('Collapse all');
		await nextFrame();
		expect(viewer.layout.rowsOf(entry.id)).toBe(1);

		const rowHeight = parseFloat(viewer.element.style.getPropertyValue('--lognal-cell-height'));

		expect(labelsAt(4 + rowHeight * 1.5)).not.toContain('Expand all');
		popup.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
		expect(viewer.getEntryText(plain.id)).toBe('plain text');
		viewer.dispose();
	});

	it('asks before it opens a link in a new tab', async () => {
		const open = vi.spyOn(window, 'open').mockReturnValue(null);
		const viewer = new LogViewer(container, { timestamps: false, toolbar: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const dialog = viewer.element.querySelector('.lognal-dialog') as HTMLDialogElement;
		const url = `https://example.com/${'a'.repeat(60)}`;

		viewer.write(url);
		await nextFrame();

		click(viewer, 100, 12);
		expect(dialog.open).toBe(true);
		expect(dialog.querySelector('.lognal-dialog-address')?.textContent).toBe(url);
		expect(document.activeElement?.textContent).toBe('Open link');

		(
			Array.from(dialog.querySelectorAll('button')).find(
				(button) => button.textContent === 'Cancel'
			) as HTMLButtonElement
		).click();
		expect(dialog.open).toBe(false);

		click(viewer, 100, 12);
		dialog.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
		expect(dialog.open).toBe(false);
		expect(open).not.toHaveBeenCalled();

		click(viewer, 100, 12);
		(dialog.querySelector('.is-primary') as HTMLButtonElement).click();
		expect(open).toHaveBeenCalledWith(url, '_blank', 'noopener,noreferrer');
		expect(dialog.open).toBe(false);
		expect(document.activeElement).toBe(viewport);

		open.mockRestore();
		viewer.dispose();
	});

	it('opens a link right away, ignores it, or draws plain text, as the options say', async () => {
		const open = vi.spyOn(window, 'open').mockReturnValue(null);
		const viewer = new LogViewer(container, {
			timestamps: false,
			toolbar: false,
			linkClick: 'open'
		});
		const dialog = viewer.element.querySelector('.lognal-dialog') as HTMLDialogElement;
		const entry = viewer.store.write(`https://example.com/${'b'.repeat(60)}`);

		await nextFrame();

		click(viewer, 100, 12);
		expect(open).toHaveBeenCalledTimes(1);
		expect(dialog.open).toBe(false);

		// A click with Shift extends the selection instead.
		click(viewer, 100, 12, { shiftKey: true });
		expect(open).toHaveBeenCalledTimes(1);

		viewer.setOptions({ linkClick: 'ignore' });
		click(viewer, 100, 12);
		expect(open).toHaveBeenCalledTimes(1);
		expect(dialog.open).toBe(false);

		viewer.setOptions({ linkClick: 'confirm', core: { links: false } });
		await nextFrame();
		click(viewer, 100, 12);
		expect(dialog.open).toBe(false);
		expect(viewer.layout.linksOf(entry!.id)).toEqual([]);

		open.mockRestore();
		viewer.dispose();
	});

	it('opens a link without asking on Ctrl+click or Cmd+click in text mode', async () => {
		const open = vi.spyOn(window, 'open').mockReturnValue(null);
		const viewer = new LogViewer(container, { timestamps: false, toolbar: false });
		const dialog = viewer.element.querySelector('.lognal-dialog') as HTMLDialogElement;
		const apple = /Mac|iPhone|iPad/.test(navigator.platform);
		const primary = apple ? { metaKey: true } : { ctrlKey: true };
		const secondary = apple ? { ctrlKey: true } : { metaKey: true };
		const url = `https://example.com/${'c'.repeat(60)}`;
		const entry = viewer.store.write(url);

		await nextFrame();

		click(viewer, 100, 12, primary);
		expect(open).toHaveBeenCalledWith(url, '_blank', 'noopener,noreferrer');
		expect(dialog.open).toBe(false);

		// Shift along with it, or the other key of the platform, selects text instead.
		click(viewer, 100, 12, { ...primary, shiftKey: true });
		click(viewer, 100, 12, secondary);
		expect(open).toHaveBeenCalledTimes(1);
		expect(dialog.open).toBe(false);

		viewer.setOptions({ linkClick: 'ignore' });
		click(viewer, 100, 12, primary);
		expect(open).toHaveBeenCalledTimes(1);

		// In entry mode, the same click adds the entry to the selection.
		viewer.setOptions({ linkClick: 'confirm', selectionMode: 'entry' });
		click(viewer, 100, 12, primary);
		expect(open).toHaveBeenCalledTimes(1);
		expect(viewer.getSelectedEntryIds()).toEqual([entry!.id]);

		open.mockRestore();
		viewer.dispose();
	});

	it('offers to open the links of an entry from its menu', async () => {
		const viewer = new LogViewer(container, { timestamps: false });
		const button = viewer.element.querySelector('.lognal-entry-actions') as HTMLButtonElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const dialog = viewer.element.querySelector('.lognal-dialog') as HTMLDialogElement;

		viewer.write('Mirrors: https://a.example/x and https://b.example/문서');
		await nextFrame();
		hover(viewer, 200, 8);
		button.click();

		const items = Array.from(popup.querySelectorAll<HTMLElement>('[role="menuitem"]'));

		expect(items.map((item) => item.textContent)).toEqual([
			'Copy as text',
			'Copy with timestamp',
			'Copy as formatted text',
			'Open https://a.example/x',
			'Open https://b.example/문서'
		]);

		items[4].click();
		expect(dialog.open).toBe(true);
		// The address is decoded for reading, although the browser encodes the path.
		expect(dialog.querySelector('.lognal-dialog-address')?.textContent).toBe(
			'https://b.example/문서'
		);

		dialog.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
		expect(dialog.open).toBe(false);

		viewer.setOptions({ linkClick: 'ignore' });
		hover(viewer, 200, 30);
		hover(viewer, 200, 8);
		button.click();
		expect(popup.textContent).not.toContain('https://');
		viewer.dispose();
	});

	it('searches with Ctrl+F, highlights every match and moves to the next one', async () => {
		const render = vi.spyOn(CanvasRenderer.prototype, 'render');
		const viewer = new LogViewer(container, { timestamps: false, core: { mergeRepeats: false } });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const bar = viewer.element.querySelector('.lognal-search') as HTMLFormElement;
		const input = bar.querySelector('input') as HTMLInputElement;
		const results = bar.querySelector('.lognal-search-count') as HTMLSpanElement;
		const lastFrame = () => render.mock.calls[render.mock.calls.length - 1][0];

		for (let index = 0; index < 300; index++) {
			viewer.write(index === 10 || index === 250 ? `line ${index} needle` : `line ${index}`);
		}

		await nextFrame();
		viewport.focus();

		const shortcut = new KeyboardEvent('keydown', {
			key: 'f',
			ctrlKey: true,
			bubbles: true,
			cancelable: true
		});

		viewport.dispatchEvent(shortcut);
		expect(shortcut.defaultPrevented).toBe(true);
		expect(bar.hidden).toBe(false);
		expect(document.activeElement).toBe(input);

		input.value = 'NEEDLE';
		input.dispatchEvent(new Event('input'));
		await waitFor(() => results.textContent === '1/2');

		// No match is below the bottom of the log, so the first match becomes current and is shown.
		await waitFor(() => lastFrame().rows.some((row) => row.entry.id === 11));

		const shown = lastFrame();
		const currentRow = shown.rows.findIndex((row) => row.entry.id === 11);

		expect(viewer.isFollowing).toBe(false);
		expect(shown.decorations[currentRow].searchCurrent).toEqual([8, 14]);

		input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
		await waitFor(() => results.textContent === '2/2');
		await waitFor(() => lastFrame().rows.some((row) => row.entry.id === 251));

		input.dispatchEvent(
			new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true, bubbles: true })
		);
		expect(results.textContent).toBe('1/2');

		input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
		expect(bar.hidden).toBe(true);
		expect(document.activeElement).toBe(viewport);
		await nextFrame();
		expect(lastFrame().decorations.some((decoration) => decoration.searchCurrent)).toBe(false);

		render.mockRestore();
		viewer.dispose();
	});

	it('keeps every entry visible while searching and searches new entries', async () => {
		const viewer = new LogViewer(container, { core: { mergeRepeats: false } });
		const results = viewer.element.querySelector('.lognal-search-count') as HTMLSpanElement;

		viewer.write('alpha beta');
		viewer.write('gamma');
		await nextFrame();
		viewer.openSearch('gamma');
		await waitFor(() => results.textContent === '1/1');
		expect(viewer.layout.visibleCount).toBe(2);

		viewer.write('gamma again');
		await waitFor(() => results.textContent === '1/2');
		viewer.findNext();
		expect(results.textContent).toBe('2/2');
		viewer.findNext();
		expect(results.textContent).toBe('1/2');

		viewer.openSearch('missing');
		await waitFor(() => results.textContent === 'No results');
		viewer.dispose();
	});

	it('matches case and regular expressions with the toggles of the search bar', async () => {
		const viewer = new LogViewer(container, { core: { mergeRepeats: false } });
		const bar = viewer.element.querySelector('.lognal-search') as HTMLFormElement;
		const input = bar.querySelector('input') as HTMLInputElement;
		const results = bar.querySelector('.lognal-search-count') as HTMLSpanElement;
		const [caseToggle, regexToggle] = Array.from(
			bar.querySelectorAll<HTMLButtonElement>('.lognal-search-toggle')
		);

		viewer.write('Error 404');
		viewer.write('error 500');
		await nextFrame();
		viewer.openSearch('error');
		await waitFor(() => results.textContent === '1/2');

		expect(caseToggle.getAttribute('aria-label')).toBe('Match case');
		caseToggle.click();
		expect(caseToggle.getAttribute('aria-pressed')).toBe('true');
		await waitFor(() => results.textContent === '1/1');

		input.value = 'error \\d+';
		input.dispatchEvent(
			new KeyboardEvent('keydown', { key: 'r', code: 'KeyR', altKey: true, bubbles: true })
		);
		expect(regexToggle.getAttribute('aria-pressed')).toBe('true');
		await waitFor(() => results.textContent === '1/1');

		viewer.openSearch('(', { regex: true });
		expect(input.hasAttribute('aria-invalid')).toBe(true);
		expect(input.title).toBe('Not a valid regular expression');
		expect(results.textContent).toBe('');

		viewer.openSearch('404', { caseSensitive: false, regex: false });
		expect(input.hasAttribute('aria-invalid')).toBe(false);
		expect(caseToggle.getAttribute('aria-pressed')).toBe('false');
		await waitFor(() => results.textContent === '1/1');
		viewer.dispose();
	});

	it('leaves Ctrl+F to the browser when search is off', () => {
		const viewer = new LogViewer(container, { search: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const shortcut = new KeyboardEvent('keydown', {
			key: 'f',
			metaKey: true,
			bubbles: true,
			cancelable: true
		});

		viewport.dispatchEvent(shortcut);
		expect(shortcut.defaultPrevented).toBe(false);
		expect((viewer.element.querySelector('.lognal-search') as HTMLFormElement).hidden).toBe(true);
		viewer.dispose();
	});

	it('escapes log text in the HTML of a formatted copy', async () => {
		const viewer = new LogViewer(container);
		const write = vi.spyOn(navigator.clipboard, 'write').mockResolvedValue(undefined);

		viewer.write('<img src=x onerror="alert(1)"> & more');
		await viewer.copyEntry(viewer.store.at(0)!.id, { format: 'formatted' });

		const html = await (await write.mock.calls[0][0][0].getType('text/html')).text();

		expect(html).toContain('&lt;img src=x onerror=&quot;alert(1)&quot;&gt; &amp; more');
		expect(html).not.toContain('<img');
		write.mockRestore();
		viewer.dispose();
	});

	it('opens the entry menu on a long press and not on a touch that moves', async () => {
		const viewer = new LogViewer(container, { toolbar: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const rect = (): DOMRect => viewport.getBoundingClientRect();
		const touch = (type: string, x: number, y: number): PointerEvent => {
			const event = new PointerEvent(type, {
				clientX: rect().left + x,
				clientY: rect().top + y,
				bubbles: true,
				cancelable: true,
				isPrimary: true,
				pointerId: 7,
				pointerType: 'touch'
			});

			viewport.dispatchEvent(event);

			return event;
		};

		viewer.console.log('touch me');
		await nextFrame();

		touch('pointerdown', 100, 8);
		touch('pointermove', 100, 40);
		await new Promise((resolve) => setTimeout(resolve, 600));
		expect(popup.matches(':popover-open')).toBe(false);

		touch('pointerdown', 100, 8);
		await new Promise((resolve) => setTimeout(resolve, 600));
		expect(popup.getAttribute('role')).toBe('menu');
		expect(popup.matches(':popover-open')).toBe(true);

		const menu = new MouseEvent('contextmenu', { bubbles: true, cancelable: true });

		viewport.dispatchEvent(menu);
		expect(menu.defaultPrevented).toBe(true);
		touch('pointerup', 100, 8);
		popup.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

		// A browser that opens its own menu first opens the entry menu at once instead.
		touch('pointerdown', 100, 8);

		const early = new MouseEvent('contextmenu', { bubbles: true, cancelable: true });

		viewport.dispatchEvent(early);
		expect(early.defaultPrevented).toBe(true);
		expect(popup.matches(':popover-open')).toBe(true);
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

	it('expands a value when its row is tapped, and not when the touch moves', async () => {
		const viewer = new LogViewer(container, { toolbar: false, timestamps: false });
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;

		viewer.console.log({ id: 1, name: 'lognal' });
		await nextFrame();

		const rect = viewport.getBoundingClientRect();
		const touch = (type: string, x: number): void => {
			viewport.dispatchEvent(
				new PointerEvent(type, {
					clientX: rect.left + x,
					clientY: rect.top + 12,
					bubbles: true,
					isPrimary: true,
					pointerId: 7,
					pointerType: 'touch'
				})
			);
		};

		touch('pointerdown', 60);
		touch('pointermove', 120);
		touch('pointerup', 120);
		await nextFrame();
		expect(viewer.layout.rowCount).toBe(1);

		touch('pointerdown', 60);
		touch('pointerup', 62);
		await nextFrame();
		expect(viewer.layout.rowCount).toBe(3);

		touch('pointerdown', 60);
		touch('pointercancel', 60);
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

	it('selects whole entries with a click, Ctrl or Cmd, Shift and a drag in entry mode', async () => {
		const render = vi.spyOn(CanvasRenderer.prototype, 'render');
		const viewer = new LogViewer(container, {
			timestamps: false,
			toolbar: false,
			selectionMode: 'entry',
			core: { mergeRepeats: false }
		});
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const additive = /Mac|iPhone|iPad/.test(navigator.platform)
			? { metaKey: true }
			: { ctrlKey: true };
		const onSelection = vi.fn();
		const selectedRows = (): boolean[] => {
			const frame = render.mock.calls[render.mock.calls.length - 1][0];

			return frame.decorations.map((decoration) => Boolean(decoration.entrySelected));
		};

		viewer.on('selection', onSelection);

		for (const text of ['first', 'second', 'third', 'fourth']) {
			viewer.write(text);
		}

		await nextFrame();

		const rowHeight = parseFloat(viewer.element.style.getPropertyValue('--lognal-cell-height'));
		const rowY = (index: number): number => 4 + rowHeight * (index + 0.5);
		const ids = viewer.store.toArray().map((entry) => entry.id);

		expect(viewport.dataset.selection).toBe('entry');

		click(viewer, 60, rowY(1));
		expect(viewer.getSelectedEntryIds()).toEqual([ids[1]]);

		click(viewer, 60, rowY(3), additive);
		expect(viewer.getSelectedEntryIds()).toEqual([ids[1], ids[3]]);

		click(viewer, 60, rowY(1), additive);
		expect(viewer.getSelectedEntryIds()).toEqual([ids[3]]);

		// The range starts from the entry chosen last, which Ctrl or Cmd chose.
		click(viewer, 60, rowY(0), { shiftKey: true });
		expect(viewer.getSelectedEntryIds()).toEqual([ids[0], ids[1]]);

		click(viewer, 60, rowY(3), { shiftKey: true });
		expect(viewer.getSelectedEntryIds()).toEqual(ids.slice(1));
		expect(viewer.getSelectionText()).toBe('second\nthird\nfourth');
		expect(onSelection).toHaveBeenLastCalledWith('second\nthird\nfourth');

		await nextFrame();
		expect(selectedRows()).toEqual([false, true, true, true]);

		const pointer = (type: string, y: number): void => {
			const rect = viewport.getBoundingClientRect();

			viewport.dispatchEvent(
				new PointerEvent(type, {
					clientX: rect.left + 60,
					clientY: rect.top + y,
					bubbles: true,
					button: 0,
					pointerId: 1,
					pointerType: 'mouse'
				})
			);
		};

		pointer('pointerdown', rowY(0));
		pointer('pointermove', rowY(2));
		pointer('pointerup', rowY(2));
		expect(viewer.getSelectedEntryIds()).toEqual(ids.slice(0, 3));

		// A double-click selects no word, and a press below the entries clears the selection.
		viewport.dispatchEvent(
			new MouseEvent('dblclick', {
				clientX: viewport.getBoundingClientRect().left + 60,
				clientY: viewport.getBoundingClientRect().top + rowY(1),
				bubbles: true
			})
		);
		expect(viewer.getSelectedEntryIds()).toEqual(ids.slice(0, 3));

		click(viewer, 60, rowY(8));
		expect(viewer.getSelectedEntryIds()).toEqual([]);
		expect(onSelection).toHaveBeenLastCalledWith('');

		// A drag that starts on the empty space below the entries selects the ones it reaches.
		pointer('pointerdown', rowY(8));
		pointer('pointermove', rowY(2));
		pointer('pointerup', rowY(2));
		expect(viewer.getSelectedEntryIds()).toEqual(ids.slice(2));

		render.mockRestore();
		viewer.dispose();
	});

	it('collapses a run of identical messages and opens it from its badge', async () => {
		const viewer = new LogViewer(container, {
			timestamps: false,
			toolbar: false,
			core: { mergeRepeats: 'collapse' }
		});

		viewer.write('same');
		viewer.write('same');
		viewer.write('same');
		viewer.write('other');
		await nextFrame();

		const rowHeight = parseFloat(viewer.element.style.getPropertyValue('--lognal-cell-height'));
		const rowY = (index: number): number => 4 + rowHeight * (index + 0.5);

		expect(viewer.store.size).toBe(4);
		expect(viewer.layout.visibleCount).toBe(2);

		// The badge sits in the marker column, before the text.
		click(viewer, 12, rowY(0));
		await nextFrame();

		expect(viewer.layout.visibleCount).toBe(4);

		click(viewer, 12, rowY(0));
		await nextFrame();

		expect(viewer.layout.visibleCount).toBe(2);

		// A click on the text of the entry leaves the run alone.
		click(viewer, 60, rowY(0));
		await nextFrame();

		expect(viewer.layout.visibleCount).toBe(2);
		viewer.dispose();
	});

	it('moves through, selects and copies entries with the keyboard in entry mode', async () => {
		const render = vi.spyOn(CanvasRenderer.prototype, 'render');
		const writeText = vi.spyOn(navigator.clipboard, 'writeText').mockResolvedValue(undefined);
		const viewer = new LogViewer(container, {
			timestamps: false,
			toolbar: false,
			selectionMode: 'entry',
			core: { mergeRepeats: false }
		});
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const announcer = viewer.element.querySelector('.lognal-announcer') as HTMLDivElement;
		const press = (key: string, init: KeyboardEventInit = {}): void => {
			viewport.dispatchEvent(
				new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...init })
			);
		};
		const focusedRows = (): boolean[] => {
			const frame = render.mock.calls[render.mock.calls.length - 1][0];

			return frame.decorations.map((decoration) => Boolean(decoration.entryFocused));
		};

		viewer.console.log('first');
		viewer.console.warn('second');
		viewer.console.log({ id: 3 });
		await nextFrame();
		viewport.focus();

		const ids = viewer.store.toArray().map((entry) => entry.id);

		press('ArrowDown');
		expect(viewer.getSelectedEntryIds()).toEqual([ids[0]]);

		press('ArrowDown', { shiftKey: true });
		expect(viewer.getSelectedEntryIds()).toEqual([ids[0], ids[1]]);
		expect(announcer.getAttribute('aria-live')).toBe('polite');
		expect(announcer.textContent).toBe('warn: second. 2 entries selected');

		await nextFrame();
		expect(focusedRows()).toEqual([false, true, false]);

		// Ctrl moves the focused entry without changing the selection, and Space adds it.
		press('ArrowDown', { ctrlKey: true });
		expect(viewer.getSelectedEntryIds()).toEqual([ids[0], ids[1]]);
		press(' ');
		expect(viewer.getSelectedEntryIds()).toEqual(ids);

		press('c', { ctrlKey: true });
		await waitFor(() => writeText.mock.calls.length === 1);
		expect(writeText).toHaveBeenCalledWith('first\nsecond\n{ id: 3 }');
		expect(JSON.parse(viewer.getSelectionText({ format: 'data' }))).toEqual([
			'first',
			'second',
			{ id: 3 }
		]);

		press('Home');
		expect(viewer.getSelectedEntryIds()).toEqual([ids[0]]);
		press('End', { shiftKey: true });
		expect(viewer.getSelectedEntryIds()).toEqual(ids);

		press('Escape');
		expect(viewer.getSelectedEntryIds()).toEqual([]);

		press('a', { ctrlKey: true });
		expect(viewer.getSelectedEntryIds()).toEqual(ids);
		expect(announcer.textContent).toBe('3 entries selected');

		// The outline shows only while the log has focus.
		viewport.blur();
		await nextFrame();
		expect(focusedRows()).toEqual([false, false, false]);

		writeText.mockRestore();
		render.mockRestore();
		viewer.dispose();
	});

	it('counts the selected entries in the status bar in entry mode', async () => {
		const viewer = new LogViewer(container, {
			timestamps: false,
			selectionMode: 'entry',
			core: { mergeRepeats: false }
		});
		const selectionStatus = (): HTMLSpanElement => {
			return viewer.element.querySelector('.lognal-status-selection') as HTMLSpanElement;
		};

		viewer.write('alpha');
		viewer.write('beta', { level: 'error' });
		viewer.write('gamma');
		await nextFrame();
		expect(selectionStatus().hidden).toBe(true);

		viewer.selectAll();
		await nextFrame();
		expect(selectionStatus().hidden).toBe(false);
		expect(selectionStatus().textContent).toBe('3 entries selected');

		// Entries that the filter hides are not counted.
		viewer.setFilter({ minLevel: 'error' });
		await nextFrame();
		expect(selectionStatus().textContent).toBe('1 entry selected');

		viewer.setFilter(null);
		viewer.setOptions({ locale: 'ko' });
		await nextFrame();
		expect(selectionStatus().textContent).toBe('항목 3개 선택됨');

		viewer.clearSelection();
		await nextFrame();
		expect(selectionStatus().hidden).toBe(true);

		viewer.setOptions({ selectionMode: 'text' });
		viewer.selectAll();
		await nextFrame();
		expect(selectionStatus().hidden).toBe(true);
		viewer.dispose();
	});

	it('opens a menu for the selected entries on a right click and switches modes from the toolbar', async () => {
		const write = vi.spyOn(navigator.clipboard, 'write').mockResolvedValue(undefined);
		const viewer = new LogViewer(container, {
			theme: 'light',
			timestamps: false,
			core: { mergeRepeats: false },
			entryMenu: { items: () => [{ label: 'Pin', onSelect: () => undefined }] }
		});
		const viewport = viewer.element.querySelector('.lognal-viewport') as HTMLDivElement;
		const popup = viewer.element.querySelector('.lognal-popup') as HTMLDivElement;
		const toggle = viewer.element.querySelector(
			'[aria-label="Select whole entries"]'
		) as HTMLButtonElement;
		const menuLabels = (): string[] => {
			return Array.from(popup.querySelectorAll('[role="menuitem"]')).map(
				(item) => item.textContent ?? ''
			);
		};
		const rightClick = (y: number): void => {
			const rect = viewport.getBoundingClientRect();

			viewport.dispatchEvent(
				new MouseEvent('contextmenu', {
					clientX: rect.left + 60,
					clientY: rect.top + y,
					bubbles: true,
					cancelable: true
				})
			);
		};

		viewer.write('alpha');
		viewer.write('beta', { level: 'error' });
		viewer.write('gamma');
		await nextFrame();

		const rowHeight = parseFloat(viewer.element.style.getPropertyValue('--lognal-cell-height'));
		const rowY = (index: number): number => 4 + rowHeight * (index + 0.5);
		const ids = viewer.store.toArray().map((entry) => entry.id);

		viewer.selectAll();
		expect(viewer.getSelectionText()).toBe('alpha\nbeta\ngamma');
		expect(viewer.getSelectedEntryIds()).toEqual(ids);

		expect(toggle.getAttribute('aria-pressed')).toBe('false');
		toggle.click();
		expect(toggle.getAttribute('aria-pressed')).toBe('true');
		expect(viewer.getSelectionText()).toBe('');

		click(viewer, 60, rowY(0));
		click(viewer, 60, rowY(1), { shiftKey: true });
		rightClick(rowY(1));
		expect(menuLabels()).toEqual(['Copy as text', 'Copy with timestamp', 'Copy as formatted text']);

		(
			Array.from(popup.querySelectorAll<HTMLElement>('[role="menuitem"]')).find(
				(item) => item.textContent === 'Copy as formatted text'
			) as HTMLElement
		).click();
		await waitFor(() => write.mock.calls.length === 1);

		const [item] = write.mock.calls[0][0];
		const html = await (await item.getType('text/html')).text();

		expect(await (await item.getType('text/plain')).text()).toBe('alpha\nbeta');
		expect(html).toContain('>alpha</span>\n<span');
		expect(html).toContain('<span style="color: #c4262c">beta</span>');

		// A right click on an entry outside the selection selects it alone and opens its own menu.
		rightClick(rowY(2));
		expect(viewer.getSelectedEntryIds()).toEqual([ids[2]]);
		expect(menuLabels()).toContain('Pin');
		popup.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

		toggle.click();
		expect(viewer.getSelectedEntryIds()).toEqual([]);
		expect(viewport.dataset.selection).toBe('text');

		write.mockRestore();
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
