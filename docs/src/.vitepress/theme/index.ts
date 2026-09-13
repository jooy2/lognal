import type { Theme } from 'vitepress';
import DefaultTheme from 'vitepress/theme';

import LiveViewer from '../components/LiveViewer.vue';
import './brand.css';

export default {
	extends: DefaultTheme,
	enhanceApp({ app }) {
		app.component('LiveViewer', LiveViewer);
	}
} satisfies Theme;
