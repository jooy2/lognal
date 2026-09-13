/**
 * Copies the repository's `CHANGELOG.md` into the site, so the site shows the same file the
 * package ships. When the file is missing, a short page points to the repository instead.
 *
 * - `src/changelog.md` is the English page, the file as it is.
 * - `src/ko/changelog.md` is the Korean page. Release notes are written in English only, so the
 *   page keeps them in English and adds a Korean title and a sentence that says so.
 *
 * Runs before `npm run dev` and `npm run build`. Both copies are ignored by Git.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DOCS_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = join(DOCS_ROOT, '..', 'CHANGELOG.md');
const TARGET = join(DOCS_ROOT, 'src', 'changelog.md');
const KOREAN_TARGET = join(DOCS_ROOT, 'src', 'ko', 'changelog.md');
const EMPTY_CHANGELOG = [
	'# Changelog',
	'',
	'The changelog is kept in `CHANGELOG.md` in the [repository](https://github.com/jooy2/lognal).',
	''
].join('\n');
const KOREAN_HEADER = ['# 변경 내역', '', '변경 내역은 영어로 작성합니다.', ''].join('\n');
const TITLE = /^#[ \t]+[^\n]*\n?/m;

/** Replaces the title of the changelog with the Korean header, or adds the header on top. */
const toKorean = (changelog) => {
	const title = TITLE.exec(changelog);

	if (!title) {
		return `${KOREAN_HEADER}\n${changelog}`;
	}

	const before = changelog.slice(0, title.index);
	const after = changelog.slice(title.index + title[0].length).replace(/^\s*\n/, '');

	return `${before}${KOREAN_HEADER}\n${after}`;
};

const writePage = (path, content) => {
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, content);
};

const changelog = existsSync(SOURCE) ? readFileSync(SOURCE, 'utf8') : EMPTY_CHANGELOG;

writePage(TARGET, changelog);
writePage(KOREAN_TARGET, toKorean(changelog));
