<script setup lang="ts">
import { computed } from 'vue';

import { FRAMEWORKS } from '../../data/frameworks';

/**
 * A language's own logo, drawn at text size and in its own color.
 *
 * It is here rather than in `data/frameworks.ts` because a data file holding raw path data is a
 * data file nobody can read. Adding a language is an entry in that file plus a branch here, the
 * one place the "one entry" rule bends, and it bends because a logo is a drawing.
 *
 * Both marks are the products' own, used to name them. They take their color from `tint` rather
 * than from the text around them: a logo in the wrong color is a worse logo, and here the mark is
 * what identifies the choice rather than decorating it.
 */
const props = defineProps<{ framework: string; size?: number }>();

const size = computed(() => props.size ?? 14);
const tint = computed(
	() => FRAMEWORKS.find((item) => item.id === props.framework)?.tint ?? 'currentColor'
);
</script>

<template>
	<svg
		v-if="framework === 'js'"
		class="lognal-fw-mark"
		viewBox="0 0 24 24"
		:width="size"
		:height="size"
		:style="{ color: tint }"
		aria-hidden="true"
	>
		<rect width="24" height="24" rx="3" fill="currentColor" />
		<path
			d="M13.2 18.6c.45.75 1.04 1.3 2.1 1.3.88 0 1.44-.44 1.44-1.05 0-.73-.58-.99-1.55-1.41l-.53-.23c-1.53-.65-2.55-1.47-2.55-3.2 0-1.59 1.21-2.8 3.11-2.8 1.35 0 2.32.47 3.02 1.7l-1.65 1.06c-.36-.65-.75-.91-1.37-.91-.63 0-1.03.4-1.03.91 0 .64.4.9 1.31 1.3l.53.22c1.8.77 2.82 1.56 2.82 3.34 0 1.9-1.5 2.95-3.51 2.95-1.97 0-3.24-.94-3.86-2.17zm-7.1.18c.33.59.63 1.08 1.35 1.08.69 0 1.13-.27 1.13-1.33v-7.17h2.12v7.2c0 2.19-1.29 3.19-3.16 3.19-1.7 0-2.68-.88-3.18-1.93z"
			fill="#101010"
		/>
	</svg>
	<svg
		v-else-if="framework === 'flutter'"
		class="lognal-fw-mark"
		viewBox="0 0 24 24"
		:width="size"
		:height="size"
		:style="{ color: tint }"
		aria-hidden="true"
	>
		<path
			fill="currentColor"
			d="M14.314 0 2.3 12l3.7 3.7L21.684.013h-7.37Zm.014 11.072L7.857 17.53l6.47 6.47H21.7l-6.42-6.47 6.42-6.458h-7.372Z"
		/>
	</svg>
</template>
