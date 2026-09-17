/** Space between the tooltip and the control it belongs to, in CSS pixels. */
const GAP = 6;
/** The least space between the tooltip and the edge of the window, in CSS pixels. */
const MARGIN = 8;

/**
 * The label that appears under a control while the pointer rests on it.
 *
 * It replaces the tooltip of the browser, which waits about a second before it appears. One
 * element is reused for every control, and it is shown in the top layer where the browser has
 * the Popover API, so the `overflow: hidden` of the viewer does not cut it off. The control
 * keeps its own accessible name, so the tooltip is hidden from screen readers.
 */
export class Tooltip {
	readonly element: HTMLDivElement;
	private readonly ownerDocument: Document;
	private readonly usesPopover: boolean;
	private target: HTMLElement | null = null;

	constructor(ownerDocument: Document, container: HTMLElement) {
		this.ownerDocument = ownerDocument;
		this.element = ownerDocument.createElement('div');
		this.element.className = 'lognal-tooltip';
		this.element.setAttribute('aria-hidden', 'true');
		this.usesPopover = typeof this.element.showPopover === 'function';

		if (this.usesPopover) {
			this.element.setAttribute('popover', 'manual');
		} else {
			this.element.hidden = true;
		}

		container.append(this.element);
	}

	/**
	 * Shows `text` while the pointer or the keyboard is on `control`. The listeners live as long
	 * as the control does, so a control that is thrown away needs no cleanup.
	 */
	attach(control: HTMLElement, text: string): void {
		control.addEventListener('pointerenter', (event: PointerEvent) => {
			// A touch has no hover, and a press on the control does the work of the label.
			if (event.pointerType === 'mouse') {
				this.show(control, text);
			}
		});
		control.addEventListener('pointerleave', () => this.hide(control));
		control.addEventListener('pointerdown', () => this.hide(control));
		control.addEventListener('focus', () => {
			if (control.matches(':focus-visible')) {
				this.show(control, text);
			}
		});
		control.addEventListener('blur', () => this.hide(control));
		control.addEventListener('keydown', (event: KeyboardEvent) => {
			if (event.key === 'Escape') {
				this.hide(control);
			}
		});
	}

	/** Hides the tooltip, whichever control it belongs to. */
	close(): void {
		if (!this.target) {
			return;
		}

		this.target = null;

		if (this.usesPopover) {
			this.element.hidePopover();
		} else {
			this.element.hidden = true;
		}
	}

	dispose(): void {
		this.close();
		this.element.remove();
	}

	private show(control: HTMLElement, text: string): void {
		if (!text || !control.isConnected) {
			return;
		}

		this.target = control;
		this.element.textContent = text;

		if (this.usesPopover) {
			this.element.showPopover();
		} else {
			this.element.hidden = false;
		}

		this.place(control);
	}

	private hide(control: HTMLElement): void {
		if (this.target === control) {
			this.close();
		}
	}

	/** Centers the tooltip under the control, and moves it inside the window when it would leave. */
	private place(control: HTMLElement): void {
		const doc = this.ownerDocument;
		const view = doc.defaultView;
		const viewWidth = doc.documentElement.clientWidth || view?.innerWidth || 0;
		const viewHeight = doc.documentElement.clientHeight || view?.innerHeight || 0;
		const anchor = control.getBoundingClientRect();
		const width = this.element.offsetWidth;
		const height = this.element.offsetHeight;
		const left = anchor.left + (anchor.width - width) / 2;
		const below = anchor.bottom + GAP;
		const top = below + height > viewHeight - MARGIN ? anchor.top - GAP - height : below;

		this.element.style.left = `${Math.round(Math.min(Math.max(MARGIN, left), Math.max(MARGIN, viewWidth - width - MARGIN)))}px`;
		this.element.style.top = `${Math.round(Math.max(MARGIN, top))}px`;
	}
}
