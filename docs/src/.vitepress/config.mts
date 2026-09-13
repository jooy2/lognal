import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { defineConfig, type HeadConfig, type PageData, type UserConfig } from 'vitepress';
import { withI18n } from 'vitepress-i18n';
import type { VitePressI18nOptions } from 'vitepress-i18n/types';
import { withSidebar } from 'vitepress-sidebar';
import type { VitePressSidebarOptions } from 'vitepress-sidebar/types';

const SITE_TITLE = 'lognal';
const HOSTNAME = 'https://lognal.cdget.com';
const REPOSITORY_URL = 'https://github.com/jooy2/lognal';
const OG_IMAGE_URL = `${HOSTNAME}/og-image.png`;

const supportedLocale = ['en', 'ko'];
const defaultLocale = supportedLocale[0];

const SOURCE_DIRECTORY = fileURLToPath(new URL('..', import.meta.url));
const LIBRARY_SOURCE_DIRECTORY = fileURLToPath(new URL('../../../src', import.meta.url));
const LIBRARY_ENTRY = fileURLToPath(new URL('../../../src/index.ts', import.meta.url));
const LIBRARY_STYLESHEET = fileURLToPath(
	new URL('../../../src/styles/lognal.css', import.meta.url)
);

const DESCRIPTIONS: Record<string, string> = {
	en: 'A terminal-style log viewer for the browser, drawn on a canvas. Mirror the console, read log files, and inspect typed values that expand and collapse.',
	ko: '캔버스에 그리는 터미널 스타일의 브라우저 로그 뷰어입니다. 콘솔 출력을 옮겨 보여 주고, 로그 파일을 읽고, 값을 펼치고 접으며 살펴볼 수 있습니다.'
};

const OG_LOCALES: Record<string, string> = {
	en: 'en_US',
	ko: 'ko_KR'
};

/** The locale of a page, from its path after the `en/` rewrite. */
const localeOf = (relativePath: string): string => {
	const [first] = relativePath.split('/');

	return supportedLocale.includes(first) && first !== defaultLocale ? first : defaultLocale;
};

/** The absolute URL of a page, the way `cleanUrls` serves it. */
const urlOf = (relativePath: string): string => {
	const path = relativePath.replace(/(^|\/)index\.md$/, '$1').replace(/\.md$/, '');

	return `${HOSTNAME}/${path}`;
};

/** The title VitePress writes into `<title>`, so the Open Graph title matches it. */
const documentTitleOf = (pageData: PageData): string => {
	const title = pageData.title || SITE_TITLE;
	const template = pageData.titleTemplate;

	if (typeof template === 'string' && template.includes(':title')) {
		return template.replace(/:title/g, title);
	}

	if (template === false || template === SITE_TITLE) {
		return title;
	}

	const suffix = typeof template === 'string' ? template : SITE_TITLE;

	return title === suffix ? title : `${title} | ${suffix}`;
};

/**
 * Whether a locale has a source file for a page. Pages of the default locale live in `en/`,
 * except the changelog, which `scripts/copy-changelog.mjs` writes to the source root.
 */
const hasSource = (locale: string, localFree: string): boolean => {
	if (locale !== defaultLocale) {
		return existsSync(`${SOURCE_DIRECTORY}${locale}/${localFree}`);
	}

	return (
		existsSync(`${SOURCE_DIRECTORY}${locale}/${localFree}`) ||
		existsSync(`${SOURCE_DIRECTORY}${localFree}`)
	);
};

/** Links to the same page in every locale that has it. */
const alternatesOf = (relativePath: string): HeadConfig[] => {
	const locale = localeOf(relativePath);
	const localFree = locale === defaultLocale ? relativePath : relativePath.slice(locale.length + 1);
	const links: HeadConfig[] = [];

	for (const other of supportedLocale) {
		if (!hasSource(other, localFree)) {
			continue;
		}

		const path = other === defaultLocale ? localFree : `${other}/${localFree}`;

		links.push(['link', { rel: 'alternate', hreflang: other, href: urlOf(path) }]);
	}

	if (links.length > 1) {
		links.push(['link', { rel: 'alternate', hreflang: 'x-default', href: urlOf(localFree) }]);

		return links;
	}

	return [];
};

const commonSidebarConfig: VitePressSidebarOptions = {
	collapsed: false,
	useTitleFromFileHeading: true,
	useTitleFromFrontmatter: true,
	useFolderTitleFromIndexFile: true,
	useFolderLinkFromIndexFile: true,
	sortMenusByFrontmatterOrder: true,
	frontmatterOrderDefaultValue: 99
};

const vitePressSidebarConfigs: VitePressSidebarOptions[] = supportedLocale.map((lang) => {
	return {
		...commonSidebarConfig,
		documentRootPath: `/src/${lang}`,
		// The demo and the changelog are in the navigation bar. The demo page has no sidebar, and
		// the English changelog sits outside `src/en`, so both stay out of every sidebar.
		excludeByGlobPattern: ['changelog.md', 'demo.md'],
		resolvePath: defaultLocale === lang ? '/' : `/${lang}/`,
		...(defaultLocale === lang ? {} : { basePath: `/${lang}/` })
	};
});

const vitePressI18nConfigs: VitePressI18nOptions = {
	locales: supportedLocale,
	rootLocale: defaultLocale,
	searchProvider: 'local',
	description: DESCRIPTIONS,
	themeConfig: {
		en: {
			nav: [
				{ text: 'Getting started', link: '/getting-started' },
				{ text: 'Guide', link: '/guide/' },
				{ text: 'Reference', link: '/reference/' },
				{ text: 'Demo', link: '/demo' },
				{ text: 'Changelog', link: '/changelog' }
			]
		},
		ko: {
			nav: [
				{ text: '시작하기', link: '/ko/getting-started' },
				{ text: '가이드', link: '/ko/guide/' },
				{ text: '레퍼런스', link: '/ko/reference/' },
				{ text: '데모', link: '/ko/demo' },
				{ text: '변경 내역', link: '/ko/changelog' }
			]
		}
	}
};

const vitePressConfigs: UserConfig = {
	title: SITE_TITLE,
	lastUpdated: true,
	outDir: '../dist',
	cleanUrls: true,
	metaChunk: true,
	head: [
		['link', { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/logo-32.png' }],
		['link', { rel: 'icon', type: 'image/png', sizes: '16x16', href: '/logo-16.png' }],
		['link', { rel: 'shortcut icon', href: '/favicon.ico' }],
		['link', { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' }],
		['meta', { name: 'theme-color', media: '(prefers-color-scheme: light)', content: '#ffffff' }],
		['meta', { name: 'theme-color', media: '(prefers-color-scheme: dark)', content: '#1b1b1f' }],
		['meta', { property: 'og:type', content: 'website' }],
		['meta', { property: 'og:site_name', content: SITE_TITLE }],
		['meta', { property: 'og:image', content: OG_IMAGE_URL }],
		['meta', { property: 'og:image:width', content: '1200' }],
		['meta', { property: 'og:image:height', content: '630' }],
		['meta', { name: 'twitter:card', content: 'summary_large_image' }],
		['meta', { name: 'twitter:image', content: OG_IMAGE_URL }]
	],
	sitemap: {
		hostname: HOSTNAME
	},
	rewrites: {
		'en/:rest*': ':rest*'
	},
	/** Adds the tags that differ from page to page: the canonical URL, alternates and Open Graph. */
	transformPageData(pageData) {
		const locale = localeOf(pageData.relativePath);
		const url = urlOf(pageData.relativePath);
		const title = documentTitleOf(pageData);
		const description = pageData.frontmatter.description ?? DESCRIPTIONS[locale];
		const head: HeadConfig[] = [
			['link', { rel: 'canonical', href: url }],
			...alternatesOf(pageData.relativePath),
			['meta', { property: 'og:title', content: title }],
			['meta', { property: 'og:description', content: description }],
			['meta', { property: 'og:url', content: url }],
			['meta', { property: 'og:locale', content: OG_LOCALES[locale] }],
			['meta', { name: 'twitter:title', content: title }],
			['meta', { name: 'twitter:description', content: description }]
		];

		pageData.frontmatter.head = [...(pageData.frontmatter.head ?? []), ...head];
	},
	vite: {
		resolve: {
			// The live demo imports lognal from the repository source, so the site always shows
			// the code it documents. `lognal/style.css` comes first so `lognal` does not match it.
			alias: [
				{ find: /^lognal\/style\.css$/, replacement: LIBRARY_STYLESHEET },
				{ find: /^lognal$/, replacement: LIBRARY_ENTRY }
			]
		},
		server: {
			// VitePress already allows the docs folder. The library source sits outside it.
			fs: {
				allow: [LIBRARY_SOURCE_DIRECTORY]
			}
		}
	},
	themeConfig: {
		logo: { src: '/logo.webp', alt: SITE_TITLE, width: 24, height: 24 },
		socialLinks: [
			{ icon: 'github', link: REPOSITORY_URL },
			{ icon: 'npm', link: 'https://www.npmjs.com/package/lognal' }
		],
		editLink: {
			pattern: `${REPOSITORY_URL}/edit/main/docs/src/:path`
		},
		footer: {
			message: 'Released under the MIT License',
			copyright: '© <a href="https://cdget.com">CDGet</a>'
		}
	}
};

export default defineConfig(
	withSidebar(withI18n(vitePressConfigs, vitePressI18nConfigs), vitePressSidebarConfigs)
);
