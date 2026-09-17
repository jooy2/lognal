<script setup lang="ts">
import { useData } from 'vitepress';
import { computed, onMounted, ref } from 'vue';

import { framework, setFramework } from '../../data/framework';
import { DEFAULT_FRAMEWORK, FRAMEWORKS } from '../../data/frameworks';
import FrameworkMark from './FrameworkMark.vue';

/**
 * The language switch, at the top of the sidebar.
 *
 * It sits above the menu rather than in the navigation bar because it is not navigation: it does
 * not take the reader anywhere, it changes what the page they are already on says. The sidebar is
 * where the rest of that scoping lives, and on a narrow screen the drawer carries it along.
 *
 * A segmented control rather than a `<select>`, and the reason is not that a select is ugly.
 * There are exactly two options, both are always worth showing, and the choice colors every page
 * on the site. Built out of real radio inputs, hidden and labelled, which is what buys the arrow
 * keys, the group semantics and the focus behaviour for free.
 */
const props = defineProps({
	/**
	 * Drops the sticky strip, for a page that has no sidebar to pin it to. The demo page is the
	 * one: it is full width and has no menu, and a reader who cannot switch there cannot see the
	 * other package's viewer at all.
	 */
	compact: { type: Boolean, default: false }
});

const { lang } = useData();
const label = computed(() => (lang.value.startsWith('ko') ? '패키지' : 'Package'));

/*
 * Which option the radios say is chosen, and it is deliberately behind the page for one tick.
 *
 * The pre-rendered HTML is built with the default selected, because that is all a build can know.
 * `syncFramework()` runs in `enhanceApp`, before hydration, so by the time this component first
 * renders in the browser it already holds the stored choice, and a first render that disagrees
 * with the server's DOM is precisely what Vue does not repair.
 *
 * Rendering the default first and correcting it in `onMounted` makes the correction an ordinary
 * update, which Vue does apply. What the eye reads meanwhile is not this at all: the active
 * option is drawn from `html[data-fw]`, which the inline head script sets before the first paint.
 */
const hydrated = ref(false);

onMounted(() => {
	hydrated.value = true;
});

const checked = computed(() => (hydrated.value ? framework.value : DEFAULT_FRAMEWORK));
</script>

<template>
	<div class="lognal-fw-switch" :class="{ 'lognal-fw-switch-compact': props.compact }">
		<p id="lognal-fw-label" class="lognal-fw-title">{{ label }}</p>
		<div class="lognal-fw-track" role="radiogroup" aria-labelledby="lognal-fw-label">
			<label v-for="item in FRAMEWORKS" :key="item.id" class="lognal-fw-option" :data-fw="item.id">
				<input
					type="radio"
					name="lognal-fw"
					:value="item.id"
					:checked="checked === item.id"
					@change="setFramework(item.id)"
				/>
				<FrameworkMark :framework="item.id" />
				<span>{{ item.label }}</span>
			</label>
		</div>
	</div>
</template>
