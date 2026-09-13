import { createIcon, type IconName } from './icons.js';

/** Space between the popup and the control it opens from, in CSS pixels. */
const GAP = 4;
/** The least space between the popup and the edge of the window, in CSS pixels. */
const MARGIN = 8;

let popupCount = 0;

/** One choice in a popup. */
export interface PopupItem {
	label: string;
	icon?: IconName;
	/** Marks the chosen option of a list box. */
	selected?: boolean;
	/** Draws a line before the item, to set it apart from the items above it. */
	startsGroup?: boolean;
	onSelect: () => void;
}

/** A rectangle in client coordinates, such as the one `getBoundingClientRect` returns. */
export interface PopupAnchor {
	left: number;
	top: number;
	right: number;
	bottom: number;
}

export interface PopupOpenOptions {
	/** `listbox` for a choice of one value, `menu` for a list of actions. */
	role: 'listbox' | 'menu';
	/** The accessible name of the popup. */
	label: string;
	items: PopupItem[];
	/** The rectangle the popup opens next to. */
	anchor: PopupAnchor;
	/** Whether the popup lines up with the left or the right edge of the anchor. */
	align: 'start' | 'end';
	/** The control that opened the popup. A press on it is left to the control itself. */
	trigger?: HTMLElement;
	/** The element that gets focus back when the popup closes. */
	returnFocus: HTMLElement;
	/** Called after the popup closed, however it closed. */
	onClose?: () => void;
}

/**
 * A list of choices that opens over the page, used for the level menu and the entry menu.
 *
 * The popup is shown in the top layer with the Popover API where the browser has it, so the
 * `overflow: hidden` of the viewer does not cut it off. It stays a child of the viewer, so it
 * inherits the `--lognal-*` custom properties. While it is open it holds focus and marks the
 * active item with `aria-activedescendant`; the arrow keys, Home and End move, Enter and Space
 * choose, and Escape and Tab close it.
 */
export class PopupMenu {
	readonly element: HTMLDivElement;
	private readonly ownerDocument: Document;
	private readonly usesPopover: boolean;
	private current: PopupOpenOptions | null = null;
	private itemElements: HTMLDivElement[] = [];
	private active = -1;

	constructor(
		ownerDocument: Document,
		private readonly container: HTMLElement
	) {
		this.ownerDocument = ownerDocument;
		this.element = ownerDocument.createElement('div');
		this.element.className = 'lognal-popup';
		this.element.id = `lognal-popup-${++popupCount}`;
		this.element.tabIndex = -1;
		this.usesPopover = typeof this.element.showPopover === 'function';

		if (this.usesPopover) {
			this.element.setAttribute('popover', 'manual');
		} else {
			this.element.hidden = true;
		}

		this.element.addEventListener('keydown', this.onKeyDown);
		this.element.addEventListener('pointerdown', this.onPointerDown);
		this.element.addEventListener('pointermove', this.onPointerMove);
		this.element.addEventListener('click', this.onClick);
		this.element.addEventListener('focusout', this.onFocusOut);
		this.element.addEventListener('contextmenu', this.onContextMenu);
		container.append(this.element);
	}

	get isOpen(): boolean {
		return this.current !== null;
	}

	/** The control that opened the popup, while it is open. */
	get trigger(): HTMLElement | undefined {
		return this.current?.trigger;
	}

	open(options: PopupOpenOptions): void {
		this.close(false);

		const doc = this.ownerDocument;
		const itemRole = options.role === 'listbox' ? 'option' : 'menuitem';
		const hasIcons = options.items.some((item) => item.icon);

		this.current = options;
		this.element.setAttribute('role', options.role);
		this.element.setAttribute('aria-label', options.label);
		this.itemElements = options.items.map((item, index) => {
			const element = doc.createElement('div');
			const label = doc.createElement('span');

			element.className = 'lognal-popup-item';
			element.id = `${this.element.id}-${index}`;
			element.dataset.index = String(index);
			element.setAttribute('role', itemRole);

			if (options.role === 'listbox') {
				const check = createIcon(doc, 'check');

				check.classList.add('lognal-popup-check');
				element.setAttribute('aria-selected', String(Boolean(item.selected)));
				element.append(check);
			}

			if (item.icon) {
				element.append(createIcon(doc, item.icon));
			} else if (hasIcons) {
				// Keeps the label in line with the labels of the items that have an icon.
				const space = doc.createElement('span');

				space.className = 'lognal-popup-icon-space';
				element.append(space);
			}

			label.className = 'lognal-popup-label';
			label.textContent = item.label;
			element.append(label);

			return element;
		});
		this.element.replaceChildren(
			...this.itemElements.flatMap((element, index) => {
				if (!options.items[index].startsGroup || index === 0) {
					return [element];
				}

				const separator = doc.createElement('div');

				separator.className = 'lognal-popup-separator';
				separator.setAttribute('role', 'separator');

				return [separator, element];
			})
		);

		if (this.usesPopover) {
			this.element.showPopover();
		} else {
			this.element.hidden = false;
		}

		this.place(options.anchor, options.align);
		this.element.focus({ preventScroll: true });
		this.setActive(
			Math.max(
				0,
				options.items.findIndex((item) => item.selected)
			)
		);

		const view = doc.defaultView;

		doc.addEventListener('pointerdown', this.onDocumentPointerDown, true);
		doc.addEventListener('scroll', this.onDocumentScroll, true);
		view?.addEventListener('resize', this.onWindowResize);
	}

	/** Closes the popup. With `restoreFocus`, focus goes back to where `open` was told. */
	close(restoreFocus = true): void {
		const current = this.current;

		if (!current) {
			return;
		}

		const doc = this.ownerDocument;

		this.current = null;
		this.active = -1;
		doc.removeEventListener('pointerdown', this.onDocumentPointerDown, true);
		doc.removeEventListener('scroll', this.onDocumentScroll, true);
		doc.defaultView?.removeEventListener('resize', this.onWindowResize);
		this.element.removeAttribute('aria-activedescendant');

		if (this.usesPopover) {
			this.element.hidePopover();
		} else {
			this.element.hidden = true;
		}

		if (restoreFocus) {
			current.returnFocus.focus({ preventScroll: true });
		}

		current.onClose?.();
	}

	dispose(): void {
		this.close(false);
		this.element.remove();
	}

	/** Places the popup next to the anchor, and moves it inside the window when it would leave. */
	private place(anchor: PopupAnchor, align: 'start' | 'end'): void {
		const doc = this.ownerDocument;
		const view = doc.defaultView;
		const viewWidth = doc.documentElement.clientWidth || view?.innerWidth || 0;
		const viewHeight = doc.documentElement.clientHeight || view?.innerHeight || 0;
		const width = this.element.offsetWidth;
		const height = this.element.offsetHeight;
		let left = align === 'end' ? anchor.right - width : anchor.left;
		let top = anchor.bottom + GAP;

		if (top + height > viewHeight - MARGIN && anchor.top - GAP - height >= MARGIN) {
			top = anchor.top - GAP - height;
		}

		left = Math.min(Math.max(MARGIN, left), Math.max(MARGIN, viewWidth - width - MARGIN));
		top = Math.min(Math.max(MARGIN, top), Math.max(MARGIN, viewHeight - height - MARGIN));
		this.element.style.left = `${Math.round(left)}px`;
		this.element.style.top = `${Math.round(top)}px`;
	}

	private setActive(index: number): void {
		const previous = this.itemElements[this.active];
		const next = this.itemElements[index];

		previous?.classList.remove('is-active');
		this.active = next ? index : -1;

		if (!next) {
			this.element.removeAttribute('aria-activedescendant');

			return;
		}

		next.classList.add('is-active');
		this.element.setAttribute('aria-activedescendant', next.id);

		// Keep the active item in view when the list scrolls.
		if (next.offsetTop < this.element.scrollTop) {
			this.element.scrollTop = next.offsetTop;
		} else if (
			next.offsetTop + next.offsetHeight >
			this.element.scrollTop + this.element.clientHeight
		) {
			this.element.scrollTop = next.offsetTop + next.offsetHeight - this.element.clientHeight;
		}
	}

	private choose(index: number): void {
		const item = this.current?.items[index];

		if (!item) {
			return;
		}

		this.close();
		item.onSelect();
	}

	private readonly onKeyDown = (event: KeyboardEvent): void => {
		const count = this.itemElements.length;

		if (!this.current || count === 0) {
			return;
		}

		if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
			const step = event.key === 'ArrowDown' ? 1 : -1;

			event.preventDefault();
			this.setActive((this.active + step + count) % count);
		} else if (event.key === 'Home' || event.key === 'End') {
			event.preventDefault();
			this.setActive(event.key === 'Home' ? 0 : count - 1);
		} else if (event.key === 'Enter' || event.key === ' ') {
			event.preventDefault();
			this.choose(this.active);
		} else if (event.key === 'Escape') {
			event.preventDefault();
			event.stopPropagation();
			this.close();
		} else if (event.key === 'Tab') {
			// Focus goes back to the control first, so Tab moves on from there.
			this.close();
		}
	};

	/** Keeps focus in the popup when an item is pressed. */
	private readonly onPointerDown = (event: PointerEvent): void => {
		event.preventDefault();
	};

	private readonly onPointerMove = (event: PointerEvent): void => {
		const item = (event.target as Element).closest<HTMLElement>('.lognal-popup-item');

		if (item) {
			this.setActive(Number(item.dataset.index));
		}
	};

	private readonly onClick = (event: MouseEvent): void => {
		const item = (event.target as Element).closest<HTMLElement>('.lognal-popup-item');

		if (item) {
			this.choose(Number(item.dataset.index));
		}
	};

	private readonly onFocusOut = (event: FocusEvent): void => {
		const next = event.relatedTarget as Node | null;

		if (this.current && (!next || !this.element.contains(next))) {
			this.close(false);
		}
	};

	private readonly onContextMenu = (event: MouseEvent): void => {
		event.preventDefault();
	};

	private readonly onDocumentPointerDown = (event: PointerEvent): void => {
		const target = event.target as Node;

		if (this.element.contains(target) || this.current?.trigger?.contains(target)) {
			return;
		}

		this.close(false);
	};

	/** Closes the popup when the page scrolls, since the control it opened from moves away. */
	private readonly onDocumentScroll = (event: Event): void => {
		const target = event.target as Node | null;

		if (target && target !== this.ownerDocument && this.container.contains(target)) {
			return;
		}

		this.close(false);
	};

	private readonly onWindowResize = (): void => {
		this.close(false);
	};
}
