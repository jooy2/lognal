import type { MuteRule } from '../core/filter.js';
import { createIcon } from './icons.js';
import type { ViewerLabels } from './labels.js';

/** How long the dialog waits after a keystroke before it reports a changed rule. */
const TYPING_DELAY = 200;
/** Key code browsers report for a key press that belongs to an IME composition. */
const IME_KEY_CODE = 229;

let muteDialogCount = 0;

export interface MuteDialogOpenOptions {
	/** The rules to show. The dialog works on a copy of them. */
	rules: readonly MuteRule[];
	/** Called with the whole list whenever a rule is added, changed or removed. */
	onChange: (rules: MuteRule[]) => void;
	/** The element that gets focus back when the dialog closes. */
	returnFocus: HTMLElement;
}

/**
 * Gives a control the label that appears while the pointer rests on it. The viewer passes its
 * own, so the dialog follows the `tooltips` option.
 */
export type DescribeControl = (control: HTMLElement, label: string) => void;

/** Whether text compiles as a regular expression. Plain text always does. */
const isValidRule = (rule: MuteRule): boolean => {
	if (!rule.regex) {
		return true;
	}

	try {
		new RegExp(rule.text);

		return true;
	} catch {
		return false;
	}
};

/**
 * The dialog that manages the rules which keep messages out of the log.
 *
 * Each rule is a line with the text to hide, a switch that turns the rule off without deleting
 * it, two toggles for letter case and regular expressions, and a button that removes it. Every
 * change is reported right away, so the log follows while the dialog is open.
 */
export class MuteDialog {
	readonly element: HTMLDialogElement;
	private readonly ownerDocument: Document;
	private readonly heading: HTMLDivElement;
	private readonly message: HTMLParagraphElement;
	private readonly list: HTMLUListElement;
	private readonly empty: HTMLParagraphElement;
	private readonly field: HTMLInputElement;
	private readonly addButton: HTMLButtonElement;
	private readonly closeButton: HTMLButtonElement;
	private labels: ViewerLabels | null = null;
	private current: MuteDialogOpenOptions | null = null;
	private rules: MuteRule[] = [];
	private typingTimer: ReturnType<typeof setTimeout> | undefined;
	/** Whether the press that ends in a click started outside the box of the dialog. */
	private pressedOutside = false;

	constructor(
		ownerDocument: Document,
		container: HTMLElement,
		private readonly describe: DescribeControl
	) {
		const doc = ownerDocument;
		const id = `lognal-mute-${++muteDialogCount}`;
		const body = doc.createElement('div');
		const area = doc.createElement('div');
		const add = doc.createElement('div');
		const actions = doc.createElement('div');

		this.ownerDocument = doc;
		this.element = doc.createElement('dialog');
		this.element.className = 'lognal-dialog lognal-mute-dialog';
		this.heading = doc.createElement('div');
		this.heading.className = 'lognal-dialog-title';
		this.heading.id = `${id}-title`;
		this.message = doc.createElement('p');
		this.message.className = 'lognal-dialog-message';
		this.message.id = `${id}-message`;
		this.list = doc.createElement('ul');
		this.list.className = 'lognal-mute-list';
		this.empty = doc.createElement('p');
		this.empty.className = 'lognal-mute-empty';
		this.field = doc.createElement('input');
		this.field.type = 'text';
		this.field.className = 'lognal-mute-field';
		this.field.spellcheck = false;
		this.field.autocomplete = 'off';
		this.field.addEventListener('keydown', this.onFieldKeyDown);
		this.addButton = doc.createElement('button');
		this.addButton.type = 'button';
		this.addButton.className = 'lognal-dialog-button is-primary';
		this.addButton.addEventListener('click', () => this.addRule());
		this.closeButton = doc.createElement('button');
		this.closeButton.type = 'button';
		this.closeButton.className = 'lognal-dialog-button';
		this.closeButton.addEventListener('click', () => this.close());
		// The rules sit in a box of their own height, so adding or removing one does not move the
		// rest of the dialog.
		area.className = 'lognal-mute-area';
		area.append(this.list, this.empty);
		add.className = 'lognal-mute-add';
		add.append(this.field, this.addButton);
		actions.className = 'lognal-dialog-actions';
		actions.append(this.closeButton);
		body.className = 'lognal-dialog-body';
		body.append(this.heading, this.message, area, add, actions);
		this.element.append(body);
		this.element.setAttribute('aria-labelledby', this.heading.id);
		this.element.setAttribute('aria-describedby', this.message.id);
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
		this.labels = labels;
		this.heading.textContent = labels.mute;
		this.message.textContent = labels.muteMessage;
		this.empty.textContent = labels.muteEmpty;
		this.field.placeholder = labels.muteText;
		this.field.setAttribute('aria-label', labels.muteText);
		this.addButton.textContent = labels.muteAdd;
		this.closeButton.textContent = labels.muteClose;

		if (this.current) {
			this.render();
		}
	}

	open(options: MuteDialogOpenOptions): void {
		this.current = options;
		this.rules = options.rules.map((rule) => ({ ...rule }));
		this.field.value = '';
		this.render();

		if (!this.element.hasAttribute('open')) {
			try {
				this.element.showModal();
			} catch {
				// The browser has no `showModal`, or the viewer is not in a document.
				this.element.setAttribute('open', '');
			}
		}

		this.field.focus({ preventScroll: true });
	}

	close(): void {
		const current = this.current;

		if (!current) {
			return;
		}

		this.current = null;
		clearTimeout(this.typingTimer);

		if (this.element.hasAttribute('open')) {
			if (typeof this.element.close === 'function') {
				this.element.close();
			} else {
				this.element.removeAttribute('open');
			}
		}

		current.returnFocus.focus({ preventScroll: true });
	}

	dispose(): void {
		this.current = null;
		clearTimeout(this.typingTimer);
		this.element.remove();
	}

	/** Adds the rule in the field, if it holds anything. */
	private addRule(): void {
		const text = this.field.value.trim();

		if (!text) {
			return;
		}

		this.rules.push({ text });
		this.field.value = '';
		this.render();
		this.report();
		this.field.focus({ preventScroll: true });
	}

	/** Reports the rules, leaving out the ones whose text was emptied. */
	private report(): void {
		this.current?.onChange(
			this.rules.filter((rule) => rule.text !== '').map((rule) => ({ ...rule }))
		);
	}

	private render(): void {
		const doc = this.ownerDocument;
		const labels = this.labels;

		if (!labels) {
			return;
		}

		this.empty.hidden = this.rules.length > 0;
		this.list.hidden = this.rules.length === 0;
		this.list.replaceChildren(
			...this.rules.map((rule, index) => {
				const item = doc.createElement('li');
				const enabled = doc.createElement('input');
				const text = doc.createElement('input');

				item.className = 'lognal-mute-rule';
				enabled.type = 'checkbox';
				enabled.className = 'lognal-mute-enabled';
				enabled.checked = rule.enabled !== false;
				enabled.setAttribute('aria-label', labels.muteEnabled);
				this.describe(enabled, labels.muteEnabled);
				enabled.addEventListener('change', () => {
					this.rules[index] = { ...rule, enabled: enabled.checked };
					this.report();
				});
				text.type = 'text';
				text.className = 'lognal-mute-text';
				text.value = rule.text;
				text.spellcheck = false;
				text.setAttribute('aria-label', labels.muteText);
				text.addEventListener('input', () => {
					clearTimeout(this.typingTimer);
					this.typingTimer = setTimeout(() => {
						this.rules[index] = { ...this.rules[index], text: text.value };
						this.markValid(text, this.rules[index]);
						this.report();
					}, TYPING_DELAY);
				});
				item.append(enabled, text);
				item.append(
					this.flagButton(labels.searchCase, 'Aa', rule.caseSensitive === true, (on) => {
						this.rules[index] = { ...this.rules[index], caseSensitive: on };
						this.report();
					}),
					this.flagButton(labels.searchRegex, '.*', rule.regex === true, (on) => {
						this.rules[index] = { ...this.rules[index], regex: on };
						this.markValid(text, this.rules[index]);
						this.report();
					})
				);

				const remove = doc.createElement('button');

				remove.type = 'button';
				remove.className = 'lognal-mute-remove';
				remove.setAttribute('aria-label', labels.muteRemove);
				remove.append(createIcon(doc, 'close'));
				this.describe(remove, labels.muteRemove);
				remove.addEventListener('click', () => {
					this.rules.splice(index, 1);
					this.render();
					this.report();
					this.field.focus({ preventScroll: true });
				});
				item.append(remove);
				this.markValid(text, rule);

				return item;
			})
		);
	}

	/** Marks the field of a rule whose regular expression does not compile. */
	private markValid(field: HTMLInputElement, rule: MuteRule): void {
		const valid = isValidRule(rule);

		field.toggleAttribute('aria-invalid', !valid);
		field.title = valid ? '' : (this.labels?.searchInvalid ?? '');
	}

	private flagButton(
		label: string,
		text: string,
		pressed: boolean,
		onToggle: (pressed: boolean) => void
	): HTMLButtonElement {
		const button = this.ownerDocument.createElement('button');

		button.type = 'button';
		button.className = 'lognal-mute-flag';
		button.textContent = text;
		button.setAttribute('aria-label', label);
		this.describe(button, label);
		button.setAttribute('aria-pressed', String(pressed));
		button.addEventListener('click', () => {
			const next = button.getAttribute('aria-pressed') !== 'true';

			button.setAttribute('aria-pressed', String(next));
			onToggle(next);
		});

		return button;
	}

	/**
	 * Enter adds the rule in the field. A key press that belongs to an IME composition, such as the
	 * Enter that confirms a Japanese candidate, is left to the input method.
	 */
	private readonly onFieldKeyDown = (event: KeyboardEvent): void => {
		if (event.key !== 'Enter' || event.isComposing || event.keyCode === IME_KEY_CODE) {
			return;
		}

		event.preventDefault();
		this.addRule();
	};

	/** The browser closed the dialog itself, for example for the back gesture of a phone. */
	private readonly onClose = (): void => {
		this.close();
	};

	private readonly onKeyDown = (event: KeyboardEvent): void => {
		if (event.key === 'Escape') {
			event.preventDefault();
			event.stopPropagation();
			this.close();
		}
	};

	/** A press on the backdrop reaches the dialog element itself; a press inside reaches its body. */
	private readonly onPointerDown = (event: PointerEvent): void => {
		this.pressedOutside = event.target === this.element;
	};

	private readonly onClick = (event: MouseEvent): void => {
		if (this.pressedOutside && event.target === this.element) {
			this.close();
		}

		this.pressedOutside = false;
	};
}
