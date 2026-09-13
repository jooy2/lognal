import { playwright } from '@vitest/browser-playwright';
import { defineConfig } from 'vitest/config';

const BROWSERS = (process.env.LOGNAL_TEST_BROWSERS ?? 'chromium,firefox,webkit')
	.split(',')
	.map((name) => name.trim())
	.filter(Boolean) as ('chromium' | 'firefox' | 'webkit')[];

export default defineConfig({
	test: {
		projects: [
			{
				test: {
					name: 'unit',
					include: ['test/unit/**/*.test.ts'],
					environment: 'node'
				}
			},
			{
				test: {
					name: 'browser',
					include: ['test/browser/**/*.test.{ts,tsx}'],
					browser: {
						enabled: true,
						headless: true,
						provider: playwright(),
						screenshotFailures: false,
						instances: BROWSERS.map((browser) => ({ browser }))
					}
				}
			}
		]
	}
});
