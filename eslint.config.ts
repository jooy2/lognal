import { defineConfig, globalIgnores } from 'eslint/config';
import pluginJs from '@eslint/js';
import pluginTypeScriptESLint from 'typescript-eslint';
import configPrettier from 'eslint-config-prettier';
import globals from 'globals';

export default defineConfig([
	pluginJs.configs.recommended,
	pluginTypeScriptESLint.configs.recommended,
	globalIgnores([
		'**/.idea',
		'**/.vscode',
		'**/node_modules',
		'**/dist',
		'**/coverage',
		'docs/**',
		'**/package-lock.json'
	]),
	{
		files: ['**/*.{js,mjs,cjs,ts,tsx}'],
		languageOptions: {
			ecmaVersion: 'latest',
			sourceType: 'module',
			globals: {
				...globals.browser
			}
		},
		rules: {
			curly: ['error', 'all'],
			eqeqeq: 'error',
			'no-var': 'error',
			'prefer-const': 'error',
			'no-case-declarations': 'off',
			'no-control-regex': 'off',
			'no-trailing-spaces': 'error',
			'no-unused-vars': 'off',
			'@typescript-eslint/no-unused-vars': [
				'error',
				{
					argsIgnorePattern: '^_',
					varsIgnorePattern: '^_',
					caughtErrorsIgnorePattern: '^_'
				}
			],
			'@typescript-eslint/consistent-type-imports': 'error'
		}
	},
	{
		files: ['scripts/**/*.mjs', 'vitest.config.ts', 'eslint.config.ts'],
		languageOptions: {
			globals: {
				...globals.node
			}
		}
	},
	configPrettier
]);
