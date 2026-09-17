/**
 * Copies each package's `CHANGELOG.md` into the site, so the site shows the same files the
 * packages ship. When one is missing, a short line points to the repository instead.
 *
 * The two packages version on their own, so the page holds both, each inside the `::: fw` block
 * of the language it belongs to: a reader who has picked Flutter sees the pub.dev releases and
 * nothing else.
 *
 * - `src/changelog.md` is the English page, the files as they are.
 * - `src/ko/changelog.md` is the Korean page. Release notes are written in English only, so the
 *   page keeps them in English and adds a Korean title and a sentence that says so.
 *
 * Runs before `npm run dev` and `npm run build`. Both copies are ignored by Git.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DOCS_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PACKAGES = [
	{ id: 'js', path: ['packages', 'js', 'CHANGELOG.md'], en: 'npm', ko: 'npm' },
	{ id: 'flutter', path: ['packages', 'flutter', 'CHANGELOG.md'], en: 'pub.dev', ko: 'pub.dev' }
];
const TARGET = join(DOCS_ROOT, 'src', 'changelog.md');
const KOREAN_TARGET = join(DOCS_ROOT, 'src', 'ko', 'changelog.md');
const MISSING = 'The changelog is kept in the [repository](https://github.com/jooy2/lognal).';
const FIRST_RELEASE = /^## /m;

/**
 * The releases of one package, and nothing else.
 *
 * Everything above the first release heading is the file's own preamble: its title, and the line
 * pointing at the other package's changelog. Both are written for somebody reading the repository
 * and neither belongs on a page that already has a title and a switch.
 */
const bodyOf = (entry) => {
	const path = join(DOCS_ROOT, '..', ...entry.path);

	if (!existsSync(path)) {
		return MISSING;
	}

	const changelog = readFileSync(path, 'utf8');
	const first = FIRST_RELEASE.exec(changelog);

	return first ? changelog.slice(first.index) : changelog;
};

/**
 * One page with both packages on it, each inside the `::: fw` block of its own language. The
 * heading is the page's, and the sentence under it names the registry the releases belong to.
 */
const pageFor = (locale) => {
	const title = locale === 'ko' ? '# 변경 내역' : '# Changelog';
	const note =
		locale === 'ko'
			? '변경 내역은 영어로 작성합니다. 두 패키지는 각자 버전을 올립니다.'
			: 'Release notes are written in English. The two packages version on their own.';
	const blocks = PACKAGES.map((entry) => {
		const registry = locale === 'ko' ? `${entry.ko} 패키지입니다.` : `Releases on ${entry.en}.`;

		return [`::: fw ${entry.id}`, '', registry, '', bodyOf(entry).trimEnd(), '', ':::', ''].join(
			'\n'
		);
	});

	return [title, '', note, '', ...blocks].join('\n');
};

const writePage = (path, content) => {
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, content);
};

writePage(TARGET, pageFor('en'));
writePage(KOREAN_TARGET, pageFor('ko'));
