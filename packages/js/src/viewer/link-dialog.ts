import { isFormatCharacter } from '../core/text/links.js';
import type { ViewerLabels } from './labels.js';

let dialogCount = 0;

/** Whether text holds a space, a control character or an invisible formatting character. */
const hasHiddenCharacter = (text: string): boolean => {
	if (/[\s\x00-\x1f\x7f-\x9f]/.test(text)) {
		return true;
	}

	for (let index = 0; index < text.length; index++) {
		if (isFormatCharacter(text.charCodeAt(index))) {
			return true;
		}
	}

	return false;
};

/**
 * Writes an address the way a person reads it. Percent-encoded letters, such as Hangul in a
 * path, are decoded. The host stays the way the browser resolved it, so a host that only looks
 * like another one shows its `xn--` form. An address that would decode into a space or an
 * invisible character stays encoded.
 */
const readableAddress = (href: string): string => {
	try {
		const decoded = decodeURI(href);

		return hasHiddenCharacter(decoded) ? href : decoded;
	} catch {
		return href;
	}
};

const createButton = (
	ownerDocument: Document,
	className: string,
	onClick: () => void
): HTMLButtonElement => {
	const button = ownerDocument.createElement('button');

	button.type = 'button';
	button.className = className;
	button.addEventListener('click', onClick);

	return button;
};

export interface LinkDialogOpenOptions {
	/** The address to open, already checked to be an `http` or `https` URL. */
	href: string;
	/** Called when the user chooses to open the link. */
	onOpen: () => void;
	/** The element that gets focus back when the dialog closes. */
	returnFocus: HTMLElement;
}

/**
 * The dialog that asks before a link from the log opens, and shows the whole address first.
 *
 * It is a modal `<dialog>`: focus stays inside it and the page behind it takes no input. The
 * open button has focus, so Enter opens the link, and Escape or a click outside the dialog closes
 * it without opening anything.
 */
export class LinkDialog {
	readonly element: HTMLDialogElement;
	private readonly heading: HTMLDivElement;
	private readonly message: HTMLParagraphElement;
	private readonly address: HTMLParagraphElement;
	private readonly cancelButton: HTMLButtonElement;
	private readonly openButton: HTMLButtonElement;
	private current: LinkDialogOpenOptions | null = null;
	/** Whether the press that ends in a click started outside the box of the dialog. */
	private pressedOutside = false;

	constructor(ownerDocument: Document, container: HTMLElement) {
		const doc = ownerDocument;
		const id = `lognal-dialog-${++dialogCount}`;
		const body = doc.createElement('div');
		const actions = doc.createElement('div');

		this.element = doc.createElement('dialog');
		this.element.className = 'lognal-dialog';
		this.heading = doc.createElement('div');
		this.heading.className = 'lognal-dialog-title';
		this.heading.id = `${id}-title`;
		this.message = doc.createElement('p');
		this.message.className = 'lognal-dialog-message';
		this.message.id = `${id}-message`;
		this.address = doc.createElement('p');
		this.address.className = 'lognal-dialog-address';
		this.address.id = `${id}-address`;
		this.address.dir = 'ltr';
		this.cancelButton = createButton(doc, 'lognal-dialog-button', () => this.finish(false));
		this.openButton = createButton(doc, 'lognal-dialog-button is-primary', () => this.finish(true));
		body.className = 'lognal-dialog-body';
		actions.className = 'lognal-dialog-actions';
		actions.append(this.cancelButton, this.openButton);
		body.append(this.heading, this.message, this.address, actions);
		this.element.append(body);
		this.element.setAttribute('aria-labelledby', this.heading.id);
		this.element.setAttribute('aria-describedby', `${this.message.id} ${this.address.id}`);
		this.element.addEventListener('close', this.onClose);
		this.element.addEventListener('keydown', this.onKeyDown);
		this.element.addEventListener('pointerdown', this.onPointerDown);
		this.element.addEventListener('click', this.onClick);
		container.append(this.element);
	}

	get isOpen(): boolean {
		return this.current !== null;
	}

	setLabels(labels: ViewerLabels): void {
		this.heading.textContent = labels.linkDialogTitle;
		this.message.textContent = labels.linkDialogMessage;
		this.cancelButton.textContent = labels.linkDialogCancel;
		this.openButton.textContent = labels.linkDialogOpen;
	}

	/** Shows the dialog for an address, or shows a new address in the dialog that is open. */
	open(options: LinkDialogOpenOptions): void {
		this.current = options;
		this.address.textContent = readableAddress(options.href);

		if (!this.element.hasAttribute('open')) {
			try {
				this.element.showModal();
			} catch {
				// The browser has no `showModal`, or the viewer is not in a document.
				this.element.setAttribute('open', '');
			}
		}

		this.openButton.focus({ preventScroll: true });
	}

	/** Closes the dialog without opening the link. */
	close(): void {
		this.finish(false);
	}

	dispose(): void {
		this.current = null;
		this.element.remove();
	}

	private finish(confirmed: boolean): void {
		const current = this.current;

		if (!current) {
			return;
		}

		this.current = null;

		if (this.element.hasAttribute('open')) {
			if (typeof this.element.close === 'function') {
				this.element.close();
			} else {
				this.element.removeAttribute('open');
			}
		}

		current.returnFocus.focus({ preventScroll: true });

		if (confirmed) {
			current.onOpen();
		}
	}

	/** The browser closed the dialog itself, for example for the back gesture of a phone. */
	private readonly onClose = (): void => {
		this.finish(false);
	};

	private readonly onKeyDown = (event: KeyboardEvent): void => {
		if (event.key === 'Escape') {
			event.preventDefault();
			event.stopPropagation();
			this.finish(false);
		}
	};

	/** A press on the backdrop reaches the dialog element itself; a press inside reaches its body. */
	private readonly onPointerDown = (event: PointerEvent): void => {
		this.pressedOutside = event.target === this.element;
	};

	private readonly onClick = (event: MouseEvent): void => {
		if (this.pressedOutside && event.target === this.element) {
			this.finish(false);
		}

		this.pressedOutside = false;
	};
}
