import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const DIST = join(ROOT, 'dist');
const require = createRequire(import.meta.url);

rmSync(DIST, { recursive: true, force: true });

// Run the compiler through Node so the script works the same on every platform.
execFileSync(
	process.execPath,
	[require.resolve('typescript/bin/tsc'), '--project', join(ROOT, 'tsconfig.build.json')],
	{ stdio: 'inherit' }
);

mkdirSync(DIST, { recursive: true });
copyFileSync(join(ROOT, 'src', 'styles', 'lognal.css'), join(DIST, 'lognal.css'));
