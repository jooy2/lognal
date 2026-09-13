import { afterEach, describe, expect, it, vi } from 'vitest';
import { InputLine } from '../../src/viewer/input-line.ts';

const created: InputLine[] = [];

const createInput = (
	onSubmit: (text: string) => void
): { input: InputLine; field: HTMLTextAreaElement } => {
	const input = new InputLine(document, {
		onSubmit,
		prompt: '>',
		placeholder: 'Type',
		label: 'Command',
		historySize: 10
	});

	document.body.append(input.element);
	created.push(input);

	return { input, field: input.element.querySelector('textarea') as HTMLTextAreaElement };
};

const keydown = (
	field: HTMLTextAreaElement,
	key: string,
	init: { keyCode?: number; isComposing?: boolean; shiftKey?: boolean } = {}
): KeyboardEvent => {
	const event = new KeyboardEvent('keydown', {
		key,
		bubbles: true,
		cancelable: true,
		isComposing: init.isComposing,
		shiftKey: init.shiftKey
	});

	if (init.keyCode !== undefined) {
		Object.defineProperty(event, 'keyCode', { value: init.keyCode });
	}

	field.dispatchEvent(event);

	return event;
};

afterEach(() => {
	for (const input of created.splice(0)) {
		input.dispose();
	}
});

describe('InputLine', () => {
	it('submits on Enter and adds a line on Shift+Enter', () => {
		const onSubmit = vi.fn();
		const { field } = createInput(onSubmit);

		field.value = 'first';
		expect(keydown(field, 'Enter', { shiftKey: true }).defaultPrevented).toBe(false);
		expect(onSubmit).not.toHaveBeenCalled();

		keydown(field, 'Enter');
		expect(onSubmit).toHaveBeenCalledWith('first');
		expect(field.value).toBe('');
	});

	it('ignores Enter while an IME composition is open', () => {
		const onSubmit = vi.fn();
		const { field } = createInput(onSubmit);

		field.value = '한';
		keydown(field, 'Enter', { isComposing: true });
		keydown(field, 'Enter', { keyCode: 229 });
		expect(onSubmit).not.toHaveBeenCalled();
	});

	it('ignores the Enter that Safari sends right after compositionend', async () => {
		const onSubmit = vi.fn();
		const { field } = createInput(onSubmit);

		field.value = '한글';
		field.dispatchEvent(new CompositionEvent('compositionstart'));
		field.dispatchEvent(new CompositionEvent('compositionend', { data: '글' }));
		keydown(field, 'Enter');
		expect(onSubmit).not.toHaveBeenCalled();

		await new Promise((resolve) => setTimeout(resolve, 0));
		keydown(field, 'Enter');
		expect(onSubmit).toHaveBeenCalledWith('한글');
	});

	it('goes through the history with the arrow keys and keeps the draft', () => {
		const { field } = createInput(() => undefined);

		for (const command of ['one', 'two']) {
			field.value = command;
			keydown(field, 'Enter');
		}

		field.value = 'draft';
		keydown(field, 'ArrowUp');
		expect(field.value).toBe('two');
		keydown(field, 'ArrowUp');
		expect(field.value).toBe('one');
		keydown(field, 'ArrowDown');
		keydown(field, 'ArrowDown');
		expect(field.value).toBe('draft');
	});

	it('does not submit blank input', () => {
		const onSubmit = vi.fn();
		const { field } = createInput(onSubmit);

		field.value = '   ';
		keydown(field, 'Enter');
		expect(onSubmit).not.toHaveBeenCalled();
	});
});
