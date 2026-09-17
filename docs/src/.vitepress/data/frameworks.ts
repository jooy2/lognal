/**
 * The languages lognal ships for, and the one axis of this site that is not a locale.
 *
 * A page says the same things about the viewer whichever package a reader installs: the same
 * options, the same reasons, the same log coming out the same way. Only the code, the names and
 * the install line differ. So the two are not two sites and not two folders; they are one page
 * with the parts that differ marked up, and this file is what marks them.
 *
 * Adding a language is an entry here plus the `::: fw <id>` blocks on whatever pages have
 * something to say about it. Nothing else reads the list.
 */
export interface FrameworkInfo {
	id: string;
	/** What the sidebar's switch shows. */
	label: string;
	/** The package name in that ecosystem's registry. */
	pkg: string;
	/** The fence language its code samples are written in. */
	lang: string;
	/**
	 * The brand's own color, for the mark beside the label.
	 *
	 * The one place this site paints something that is not its own or the library's, because a
	 * logo in the wrong color is a worse logo, and the mark identifies the choice rather than
	 * decorating it.
	 */
	tint: string;
}

export const FRAMEWORKS: FrameworkInfo[] = [
	{ id: 'js', label: 'JavaScript', pkg: 'lognal', lang: 'ts', tint: '#f7df1e' },
	{ id: 'flutter', label: 'Flutter', pkg: 'lognal', lang: 'dart', tint: '#42a5f5' }
];

export type Framework = string;

export const FRAMEWORK_IDS: string[] = FRAMEWORKS.map((framework) => framework.id);

export const DEFAULT_FRAMEWORK: Framework = 'js';

/**
 * Where the choice is remembered.
 *
 * Deliberately not in the URL. A reader who has picked Flutter has picked it for the whole site,
 * and a query string would have to be carried by every link on every page, including the ones
 * written by hand in prose.
 */
export const FRAMEWORK_STORAGE_KEY = 'lognal-framework';

/**
 * The choice, applied to `<html>` before the page paints.
 *
 * This runs as a blocking inline script in `<head>` rather than from the app, for the reason
 * every no-flash theme switch does: the choice decides which half of a page is displayed, and a
 * reader who picked Flutter would otherwise watch the JavaScript half render and disappear.
 * Written as a string because it has to be inlined into the document rather than imported.
 */
export const FRAMEWORK_HEAD_SCRIPT = `(function(){var i=${JSON.stringify(
	FRAMEWORK_IDS
)},v;try{v=localStorage.getItem(${JSON.stringify(
	FRAMEWORK_STORAGE_KEY
)})}catch(e){}document.documentElement.dataset.fw=i.indexOf(v)<0?${JSON.stringify(
	DEFAULT_FRAMEWORK
)}:v})()`;
