import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { DEFAULT_RENDER_THEME } from '../../src/renderer/theme.ts';
import { BUILT_IN_THEMES, resolveTheme } from '../../src/viewer/theme.ts';

const stylesheet = readFileSync(
	new URL('../../src/styles/lognal.css', import.meta.url),
	'utf8'
).replace(/\/\*[\s\S]*?\*\//g, '');

/** Every rule of the stylesheet, as its list of selectors and its declarations. */
const rules = [...stylesheet.matchAll(/([^{}]+)\{([^{}]*)\}/g)].map((match) => ({
	selectors: match[1].split(',').map((selector) => selector.trim()),
	body: match[2]
}));

/** The `--lognal-*` properties the rules with a selector set, in the order they are declared. */
const propertiesOf = (selector: string): Map<string, string> => {
	const properties = new Map<string, string>();

	for (const rule of rules.filter((item) => item.selectors.includes(selector))) {
		for (const match of rule.body.matchAll(/--lognal-([\w-]+):\s*([^;]+);/g)) {
			properties.set(match[1], match[2].trim());
		}
	}

	return properties;
};

/** The selector that holds a palette. The light palette is the base block. */
const selectorOf = (theme: string): string => {
	return theme === 'light' ? '.lognal' : `.lognal[data-theme='${theme}']`;
};

describe('themes', () => {
	it('matches the dark palette of the stylesheet with the default render theme', () => {
		const dark = propertiesOf(".lognal[data-theme='dark']");

		expect(DEFAULT_RENDER_THEME.background).toBe(dark.get('background'));
		expect(DEFAULT_RENDER_THEME.debug).toBe(dark.get('debug'));
		expect(DEFAULT_RENDER_THEME.errorBackground).toBe(dark.get('error-background'));
		expect(DEFAULT_RENDER_THEME.hover).toBe(dark.get('hover'));

		for (const [token, color] of Object.entries(DEFAULT_RENDER_THEME.tokens)) {
			expect(color, token).toBe(dark.get(`token-${token}`));
		}

		DEFAULT_RENDER_THEME.ansi.forEach((color, index) => {
			expect(color, `ansi-${index}`).toBe(dark.get(`ansi-${index}`));
		});
	});

	it('gives every built-in theme all the colors of the light palette', () => {
		// The colors of the base block, which holds the light palette, and not its sizes or fonts.
		const colors = [...propertiesOf('.lognal')]
			.filter(([name, value]) => /^(#|rgba?\()/.test(value) || name.endsWith('shadow'))
			.map(([name]) => name);

		expect(colors.length).toBeGreaterThan(50);

		for (const theme of BUILT_IN_THEMES) {
			const properties = propertiesOf(selectorOf(theme));

			for (const name of colors) {
				expect(properties.has(name), `${theme} is missing --lognal-${name}`).toBe(true);
			}
		}
	});

	it('follows the operating system only for the automatic theme', () => {
		expect(resolveTheme('auto', false)).toBe('light');
		expect(resolveTheme('auto', true)).toBe('dark');
		expect(resolveTheme('midnight', true)).toBe('midnight');
		expect(resolveTheme('mine', false)).toBe('mine');
	});
});
