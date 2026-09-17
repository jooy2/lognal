/**
 * Builds the Flutter gallery into `src/public/flutter`, so the site can frame the real Flutter
 * build rather than show a picture of one.
 *
 * Run it with `npm run flutter`. It needs a Flutter SDK; without one the previews say so and show
 * the JavaScript half, which is the honest answer and not a broken rectangle.
 *
 * The output is not committed. `.gitignore` keeps it out, and the deploy workflow runs this
 * before it builds the site.
 */
import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DOCS_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const EXAMPLE = join(DOCS_ROOT, '..', 'packages', 'flutter', 'example');
const OUTPUT = join(DOCS_ROOT, 'src', 'public', 'flutter');

if (!existsSync(EXAMPLE)) {
	throw new Error(`The Flutter gallery is not at ${EXAMPLE}.`);
}

// `--base-href` because the gallery is served from a folder of this site rather than from a root
// of its own, and a Flutter build writes that path into its bootstrap script.
execFileSync(
	'flutter',
	['build', 'web', '--release', '--base-href', '/flutter/', '--no-wasm-dry-run'],
	{ cwd: EXAMPLE, stdio: 'inherit' }
);

rmSync(OUTPUT, { recursive: true, force: true });
mkdirSync(OUTPUT, { recursive: true });
cpSync(join(EXAMPLE, 'build', 'web'), OUTPUT, { recursive: true });

console.log(`Wrote the Flutter gallery to ${OUTPUT}.`);
