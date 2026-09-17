import type { Theme } from 'vitepress';
import DefaultTheme from 'vitepress/theme';

import FlutterDemo from '../components/FlutterDemo.vue';
import FullDemo from '../components/demo/FullDemo.vue';
import LiveViewer from '../components/LiveViewer.vue';
import { syncFramework } from '../data/framework';
import './brand.css';
import './demo.css';
import './framework.css';
import FrameworkSelect from './components/FrameworkSelect.vue';
import Fw from './components/Fw.vue';
import Layout from './components/Layout.vue';

/**
 * The default theme, with this site's palette over it, the language switch in the sidebar, and
 * five components registered globally because Markdown pages use them by name: `<LiveViewer>`,
 * `<FullDemo>` and `<FlutterDemo>`, which are how a page shows a real viewer,
 * `<Fw js="…" flutter="…" />`, which is how a sentence says two things at once, and
 * `<FrameworkSelect compact />`, which is the sidebar's switch on a page that has no sidebar.
 */
export default {
	extends: DefaultTheme,
	Layout,
	enhanceApp({ app }) {
		app.component('FullDemo', FullDemo);
		app.component('FlutterDemo', FlutterDemo);
		app.component('LiveViewer', LiveViewer);
		app.component('Fw', Fw);
		app.component('FrameworkSelect', FrameworkSelect);

		// Reads the stored choice into the reactive copy the components use, and writes it back onto
		// `<html>`. No-op during server rendering.
		syncFramework();
	}
} satisfies Theme;
