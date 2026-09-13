import type { SearchOptions } from '../core/layout/search.js';
import { createIcon, type IconName } from './icons.js';
import type { ViewerLabels } from './labels.js';

/** How long typing pauses before the search runs, in milliseconds. */
const QUERY_DELAY = 120;

/**
 * The toggle Alt+C or Alt+R switches. On macOS, Option with a letter types a character, so the
 * physical key decides, and the letter only when the event does not report the key.
 */
const toggleOfKey = (event: KeyboardEvent): keyof SearchOptions | null => {
	const letter = event.code ? event.code : `Key${event.key.toUpperCase()}`;

	return letter === 'KeyC' ? 'caseSensitive' : letter === 'KeyR' ? 'regex' : null;
};

export interface SearchBarOptions {
	/** Called with the text to search for and how to compare it, once typing pauses. */
	onQuery: (query: string, options: Required<SearchOptions>) => void;
	onNext: () => void;
	onPrevious: () => void;
	onClose: () => void;
}

/**
 * The bar that opens over the log for a search: a field, the position of the current match, and
 * buttons for the previous match, the next match and closing the bar.
 *
 * Two toggles decide whether letter case must match and whether the text is a regular
 * expression. In the field, Enter goes to the next match, Shift+Enter to the previous one, Alt+C
 * and Alt+R switch the toggles, and Escape closes the bar.
 */
export class SearchBar {
	readonly element: HTMLFormElement;
	private readonly input: HTMLInputElement;
	private readonly results: HTMLSpanElement;
	private readonly buttons: Record<'previous' | 'next' | 'close', HTMLButtonElement>;
	private readonly toggles: Record<keyof SearchOptions, HTMLButtonElement>;
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
		const toggle = (text: string, key: keyof SearchOptions): HTMLButtonElement => {
			const element = doc.createElement('button');

			element.type = 'button';
			element.className = 'lognal-button lognal-search-toggle';
			element.textContent = text;
			element.setAttribute('aria-pressed', 'false');
			element.addEventListener('click', () => this.switchToggle(key));

			return element;
		};

		this.toggles = { caseSensitive: toggle('Aa', 'caseSensitive'), regex: toggle('.*', 'regex') };
		this.buttons = {
			previous: button('chevronUp', () => this.go(options.onPrevious)),
			next: button('chevronDown', () => this.go(options.onNext)),
			close: button('close', () => options.onClose())
		};
		this.element.append(
			this.input,
			this.toggles.caseSensitive,
			this.toggles.regex,
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

	/** Which toggles are on. */
	get searchOptions(): Required<SearchOptions> {
		return {
			caseSensitive: this.toggles.caseSensitive.getAttribute('aria-pressed') === 'true',
			regex: this.toggles.regex.getAttribute('aria-pressed') === 'true'
		};
	}

	/** Switches the toggles that `options` names. */
	setOptions(options: SearchOptions): void {
		for (const key of ['caseSensitive', 'regex'] as const) {
			if (options[key] !== undefined) {
				this.toggles[key].setAttribute('aria-pressed', String(options[key]));
			}
		}
	}

	/** Marks the field as holding a pattern that does not compile, with `message` as its title. */
	setInvalid(message: string | null): void {
		this.input.toggleAttribute('aria-invalid', message !== null);
		this.input.title = message ?? '';
	}

	setLabels(labels: ViewerLabels): void {
		const named: [HTMLElement, string][] = [
			[this.element, labels.search],
			[this.input, labels.search],
			[this.buttons.previous, labels.searchPrevious],
			[this.buttons.next, labels.searchNext],
			[this.buttons.close, labels.searchClose],
			[this.toggles.caseSensitive, labels.searchCase],
			[this.toggles.regex, labels.searchRegex]
		];

		for (const [element, label] of named) {
			element.setAttribute('aria-label', label);
		}

		for (const element of [...Object.values(this.buttons), ...Object.values(this.toggles)]) {
			element.title = element.getAttribute('aria-label') ?? '';
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
		this.options.onQuery(this.input.value, this.searchOptions);
	}

	private switchToggle(key: keyof SearchOptions): void {
		const element = this.toggles[key];

		element.setAttribute('aria-pressed', String(element.getAttribute('aria-pressed') !== 'true'));
		this.flush();
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

		const toggle = event.altKey && !event.ctrlKey && !event.metaKey ? toggleOfKey(event) : null;

		if (toggle) {
			event.preventDefault();
			this.switchToggle(toggle);
		} else if (event.key === 'Enter') {
			event.preventDefault();
			this.go(event.shiftKey ? this.options.onPrevious : this.options.onNext);
		} else if (event.key === 'Escape') {
			event.preventDefault();
			event.stopPropagation();
			this.options.onClose();
		}
	};
}
