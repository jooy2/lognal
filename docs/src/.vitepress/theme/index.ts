import type { Theme } from 'vitepress';
import DefaultTheme from 'vitepress/theme';

import FullDemo from '../components/demo/FullDemo.vue';
import LiveViewer from '../components/LiveViewer.vue';
import './brand.css';
import './demo.css';

export default {
	extends: DefaultTheme,
	enhanceApp({ app }) {
		app.component('FullDemo', FullDemo);
		app.component('LiveViewer', LiveViewer);
	}
} satisfies Theme;
