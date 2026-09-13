/** The most lines the input grows to before it scrolls. */
const MAX_VISIBLE_LINES = 6;
/** Key code browsers report for a key press that belongs to an IME composition. */
const IME_KEY_CODE = 229;

export interface InputLineOptions {
	/** Called with the text when the user presses Enter. */
	onSubmit: (text: string) => void;
	/** The prompt drawn before the input. */
	prompt: string;
	placeholder: string;
	label: string;
	/** How many past commands ArrowUp and ArrowDown go through. */
	historySize: number;
}

/**
 * The line where the user types commands.
 *
 * It is a real `<textarea>`, so the browser handles focus, the caret, selection, paste and
 * input method composition. Enter submits and Shift+Enter adds a line.
 *
 * A key press that belongs to an IME composition never submits by itself. Safari through
 * version 26 fires `compositionend` before the `keydown` of the key that commits the
 * composition, so that `keydown` reports `isComposing` as false. The input therefore also checks
 * key code 229 and keeps treating the composition as open until the task after `compositionend`.
 *
 * Input methods differ in what the Enter that ends a composition does next. A Japanese or Chinese
 * input method uses it to confirm a candidate, and nothing else happens. A Korean input method
 * finishes the syllable and passes the Enter on, so the browser goes on to insert a line break,
 * and the `keydown` of that Enter can arrive while the composition still counts as open. The
 * input cancels that line break in `beforeinput` and submits instead, unless Shift was held, so
 * one press is enough.
 */
export class InputLine {
	readonly element: HTMLFormElement;
	private readonly textarea: HTMLTextAreaElement;
	private readonly promptElement: HTMLSpanElement;
	private readonly history: string[] = [];
	private historyIndex = -1;
	private draft = '';
	private composing = false;
	private compositionTimer: ReturnType<typeof setTimeout> | undefined;
	/** Whether Shift was held on the last key press, which makes a line break a new line. */
	private shiftHeld = false;

	constructor(
		ownerDocument: Document,
		private options: InputLineOptions
	) {
		this.element = ownerDocument.createElement('form');
		this.element.className = 'lognal-input';
		this.promptElement = ownerDocument.createElement('span');
		this.promptElement.className = 'lognal-input-prompt';
		this.promptElement.setAttribute('aria-hidden', 'true');
		this.textarea = ownerDocument.createElement('textarea');
		this.textarea.className = 'lognal-input-field';
		this.textarea.rows = 1;
		this.textarea.spellcheck = false;
		this.textarea.setAttribute('autocomplete', 'off');
		this.textarea.setAttribute('autocapitalize', 'off');
		this.textarea.setAttribute('autocorrect', 'off');
		this.element.append(this.promptElement, this.textarea);
		this.setOptions(options);

		this.element.addEventListener('submit', this.onFormSubmit);
		this.textarea.addEventListener('keydown', this.onKeyDown);
		this.textarea.addEventListener('beforeinput', this.onBeforeInput);
		this.textarea.addEventListener('input', this.onInput);
		this.textarea.addEventListener('compositionstart', this.onCompositionStart);
		this.textarea.addEventListener('compositionend', this.onCompositionEnd);
	}

	get value(): string {
		return this.textarea.value;
	}

	setOptions(options: InputLineOptions): void {
		this.options = options;
		this.promptElement.textContent = options.prompt;
		this.textarea.placeholder = options.placeholder;
		this.textarea.setAttribute('aria-label', options.label);
	}

	focus(): void {
		this.textarea.focus();
	}

	dispose(): void {
		clearTimeout(this.compositionTimer);
		this.element.remove();
	}

	private submit(): void {
		const text = this.textarea.value;

		if (!text.trim()) {
			return;
		}

		if (this.history[this.history.length - 1] !== text) {
			this.history.push(text);

			if (this.history.length > this.options.historySize) {
				this.history.shift();
			}
		}

		this.historyIndex = -1;
		this.draft = '';
		this.textarea.value = '';
		this.resize();
		this.options.onSubmit(text);
	}

	private isComposing(event: KeyboardEvent): boolean {
		return this.composing || event.isComposing || event.keyCode === IME_KEY_CODE;
	}

	private showHistory(index: number): void {
		if (this.historyIndex === -1) {
			this.draft = this.textarea.value;
		}

		this.historyIndex = index;
		this.textarea.value = index === -1 ? this.draft : this.history[index];
		this.resize();

		const end = this.textarea.value.length;

		this.textarea.setSelectionRange(end, end);
	}

	private resize(): void {
		const lines = Math.min(MAX_VISIBLE_LINES, this.textarea.value.split('\n').length);

		this.textarea.rows = Math.max(1, lines);
	}

	private readonly onFormSubmit = (event: Event): void => {
		event.preventDefault();
		this.submit();
	};

	private readonly onKeyDown = (event: KeyboardEvent): void => {
		this.shiftHeld = event.shiftKey;

		if (this.isComposing(event)) {
			return;
		}

		const { selectionStart, selectionEnd, value } = this.textarea;
		const caretCollapsed = selectionStart === selectionEnd;

		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			this.submit();

			return;
		}

		if (
			event.key === 'ArrowUp' &&
			caretCollapsed &&
			!value.slice(0, selectionStart).includes('\n')
		) {
			const next = this.historyIndex === -1 ? this.history.length - 1 : this.historyIndex - 1;

			if (next >= 0) {
				event.preventDefault();
				this.showHistory(next);
			}

			return;
		}

		if (event.key === 'ArrowDown' && caretCollapsed && !value.slice(selectionEnd).includes('\n')) {
			if (this.historyIndex === -1) {
				return;
			}

			event.preventDefault();
			this.showHistory(this.historyIndex + 1 < this.history.length ? this.historyIndex + 1 : -1);
		}
	};

	/**
	 * Submits instead of inserting a line break that no `keydown` handled, such as the Enter a
	 * Korean input method passes on after finishing a syllable.
	 */
	private readonly onBeforeInput = (event: InputEvent): void => {
		if (event.inputType !== 'insertLineBreak' && event.inputType !== 'insertParagraph') {
			return;
		}

		if (this.shiftHeld) {
			return;
		}

		event.preventDefault();
		this.submit();
	};

	private readonly onInput = (): void => {
		this.resize();
	};

	private readonly onCompositionStart = (): void => {
		clearTimeout(this.compositionTimer);
		this.composing = true;
	};

	private readonly onCompositionEnd = (): void => {
		clearTimeout(this.compositionTimer);
		this.compositionTimer = setTimeout(() => {
			this.composing = false;
		}, 0);
	};
}
