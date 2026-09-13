import { createIcon, type IconName } from './icons.js';
import type { ViewerLabels } from './labels.js';

/** How long typing pauses before the search runs, in milliseconds. */
const QUERY_DELAY = 120;

export interface SearchBarOptions {
	/** Called with the text to search for, once typing pauses. */
	onQuery: (query: string) => void;
	onNext: () => void;
	onPrevious: () => void;
	onClose: () => void;
}

/**
 * The bar that opens over the log for a search: a field, the position of the current match, and
 * buttons for the previous match, the next match and closing the bar.
 *
 * In the field, Enter goes to the next match, Shift+Enter to the previous one, and Escape closes
 * the bar.
 */
export class SearchBar {
	readonly element: HTMLFormElement;
	private readonly input: HTMLInputElement;
	private readonly results: HTMLSpanElement;
	private readonly buttons: Record<'previous' | 'next' | 'close', HTMLButtonElement>;
	private queryTimer: ReturnType<typeof setTimeout> | undefined;

	constructor(
		ownerDocument: Document,
		private readonly options: SearchBarOptions
	) {
		const doc = ownerDocument;
		const button = (icon: IconName, onClick: () => void): HTMLButtonElement => {
			const element = doc.createElement('button');

			element.type = 'button';
			element.className = 'lognal-button';
			element.append(createIcon(doc, icon));
			element.addEventListener('click', onClick);

			return element;
		};

		this.element = doc.createElement('form');
		this.element.className = 'lognal-search';
		this.element.setAttribute('role', 'search');
		this.element.hidden = true;
		this.input = doc.createElement('input');
		this.input.type = 'text';
		this.input.className = 'lognal-search-input';
		this.input.spellcheck = false;
		this.input.setAttribute('autocomplete', 'off');
		this.results = doc.createElement('span');
		this.results.className = 'lognal-search-count';
		this.results.setAttribute('aria-live', 'polite');
		this.buttons = {
			previous: button('chevronUp', () => this.go(options.onPrevious)),
			next: button('chevronDown', () => this.go(options.onNext)),
			close: button('close', () => options.onClose())
		};
		this.element.append(
			this.input,
			this.results,
			this.buttons.previous,
			this.buttons.next,
			this.buttons.close
		);
		this.element.addEventListener('submit', (event) => event.preventDefault());
		this.input.addEventListener('input', this.onInput);
		this.input.addEventListener('keydown', this.onKeyDown);
	}

	get isOpen(): boolean {
		return !this.element.hidden;
	}

	get value(): string {
		return this.input.value;
	}

	setLabels(labels: ViewerLabels): void {
		const named: [HTMLElement, string][] = [
			[this.element, labels.search],
			[this.input, labels.search],
			[this.buttons.previous, labels.searchPrevious],
			[this.buttons.next, labels.searchNext],
			[this.buttons.close, labels.searchClose]
		];

		for (const [element, label] of named) {
			element.setAttribute('aria-label', label);
		}

		for (const key of ['previous', 'next', 'close'] as const) {
			this.buttons[key].title = this.buttons[key].getAttribute('aria-label') ?? '';
		}

		this.input.placeholder = labels.search;
	}

	/**
	 * Shows the bar and selects the text of its field. With `query`, the field starts with it.
	 * The caller runs the search for the text in the field.
	 */
	open(query?: string): void {
		clearTimeout(this.queryTimer);
		this.queryTimer = undefined;
		this.element.hidden = false;

		if (query !== undefined) {
			this.input.value = query;
		}

		this.input.focus({ preventScroll: true });
		this.input.select();
	}

	close(): void {
		clearTimeout(this.queryTimer);
		this.queryTimer = undefined;
		this.element.hidden = true;
	}

	/** Shows the position of the current match, such as `3/12`. */
	setResults(text: string): void {
		if (this.results.textContent !== text) {
			this.results.textContent = text;
		}
	}

	dispose(): void {
		clearTimeout(this.queryTimer);
		this.element.remove();
	}

	/** Runs a search that is still waiting for typing to pause. */
	private flush(): void {
		clearTimeout(this.queryTimer);
		this.queryTimer = undefined;
		this.options.onQuery(this.input.value);
	}

	/** Moves between matches of what is in the field, even when typing has not paused yet. */
	private go(move: () => void): void {
		if (this.queryTimer !== undefined) {
			this.flush();
		}

		move();
	}

	private readonly onInput = (): void => {
		clearTimeout(this.queryTimer);
		this.queryTimer = setTimeout(() => this.flush(), QUERY_DELAY);
	};

	private readonly onKeyDown = (event: KeyboardEvent): void => {
		if (event.isComposing || event.keyCode === 229) {
			return;
		}

		if (event.key === 'Enter') {
			event.preventDefault();
			this.go(event.shiftKey ? this.options.onPrevious : this.options.onNext);
		} else if (event.key === 'Escape') {
			event.preventDefault();
			event.stopPropagation();
			this.options.onClose();
		}
	};
}
