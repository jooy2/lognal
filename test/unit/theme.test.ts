import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { DEFAULT_RENDER_THEME } from '../../src/renderer/theme.ts';

const stylesheet = readFileSync(new URL('../../src/styles/lognal.css', import.meta.url), 'utf8');

/** Reads the `--lognal-*` properties of the first rule that starts with `selector`. */
const propertiesOf = (selector: string): Map<string, string> => {
	const start = stylesheet.indexOf(`${selector} {`);
	const body = stylesheet.slice(start, stylesheet.indexOf('}', start));

	return new Map(
		[...body.matchAll(/--lognal-([\w-]+):\s*([^;]+);/g)].map((match) => [match[1], match[2].trim()])
	);
};

describe('default render theme', () => {
	it('matches the dark palette of the stylesheet', () => {
		const dark = propertiesOf(".lognal[data-theme='dark']");

		expect(DEFAULT_RENDER_THEME.background).toBe(dark.get('background'));
		expect(DEFAULT_RENDER_THEME.debug).toBe(dark.get('debug'));
		expect(DEFAULT_RENDER_THEME.errorBackground).toBe(dark.get('error-background'));

		for (const [token, color] of Object.entries(DEFAULT_RENDER_THEME.tokens)) {
			expect(color, token).toBe(dark.get(`token-${token}`));
		}

		DEFAULT_RENDER_THEME.ansi.forEach((color, index) => {
			expect(color, `ansi-${index}`).toBe(dark.get(`ansi-${index}`));
		});
	});

	it('defines the same properties in the automatic dark palette', () => {
		const dark = propertiesOf(".lognal[data-theme='dark']");
		const auto = propertiesOf("\t.lognal[data-theme='auto']");

		expect(Object.fromEntries(auto)).toEqual(Object.fromEntries(dark));
	});
});
