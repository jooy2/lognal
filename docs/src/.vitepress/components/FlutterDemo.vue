<script setup lang="ts">
/**
 * A live preview of the Flutter viewer, framed.
 *
 * The gallery under `packages/flutter/example` is built into `public/flutter` and shown in an
 * `<iframe>`, because a Flutter web app is a canvas and an event loop and cannot share a document
 * with anything else. That is also what makes it worth doing: the preview is the real Flutter
 * build rather than a picture of one.
 *
 * The gallery is not committed and not everybody has a Flutter SDK, so one request decides
 * whether it is there. Without it the preview says so, which is the honest answer and not a
 * broken rectangle.
 */
import { useData, withBase } from 'vitepress';
import { computed, onBeforeUnmount, onMounted, ref, useTemplateRef, watch } from 'vue';

const props = withDefaults(
	defineProps<{
		/** Which sample the gallery starts with, or nothing for the whole gallery. */
		demo?: string;
		/** How tall the frame is. A frame has no content of ours to measure. */
		height?: number;
	}>(),
	{ demo: undefined, height: 420 }
);

const { isDark, lang } = useData();
const frame = useTemplateRef<HTMLIFrameElement>('frame');

/**
 * Whether the gallery has been built into `public/flutter`.
 *
 * One request for the whole session, for the smallest file the build produces. `null` until it
 * comes back, so nothing is framed on a guess.
 */
const built = ref<boolean | null>(null);
let probe: Promise<boolean> | null = null;

const galleryUrl = withBase('/flutter/');

const galleryBuilt = (url: string): Promise<boolean> => {
	probe ??= fetch(url, { method: 'HEAD' })
		.then((response) => response.ok)
		.catch(() => false);

	return probe;
};

/** Which of the two languages the library speaks this page is written in. */
const locale = computed(() => (lang.value.startsWith('ko') ? 'ko' : 'en'));

/*
 * `index.html` is named rather than left to the directory.
 *
 * A built site is served by something that resolves `/flutter/` to the index inside it; the dev
 * server is Vite's static middleware, which does not, and a request it cannot answer falls
 * through to VitePress's router and comes back as the site's own 404 page inside the frame.
 * Naming the file works in both.
 */
const source = computed(() => {
	const demo = props.demo ? `demo=${props.demo}&` : '';

	return `${galleryUrl}index.html?${demo}locale=${locale.value}`;
});

/**
 * Telling the framed gallery which palette this page is in.
 *
 * It cannot ride in the query string: `src` changing is the engine loading again from nothing,
 * which is a second or so of blank rectangle to change one color. So which demo and which
 * language ride in the URL, and the one that moves is posted through the frame instead.
 *
 * Same origin both ways. The gallery is served out of this site's own `public/`, so there is no
 * other origin in it, and a message from one is somebody else's page with this one framed inside.
 */
const tellFrame = (): void => {
	frame.value?.contentWindow?.postMessage(
		{ lognal: 'theme', value: isDark.value ? 'dark' : 'light' },
		window.location.origin
	);
};

/**
 * The gallery saying it is listening, which is when it can first be told.
 *
 * A Flutter engine arrives over the network and the frame loads lazily, so there is no moment
 * this page can work out on its own. The frame speaks first, and this answers with wherever the
 * switch is by then.
 */
const onMessage = (event: MessageEvent): void => {
	const message: unknown = event.data;

	if (
		event.origin === window.location.origin &&
		event.source === frame.value?.contentWindow &&
		typeof message === 'object' &&
		message !== null &&
		(message as { lognal?: unknown }).lognal === 'ready'
	) {
		tellFrame();
	}
};

onMounted(() => {
	window.addEventListener('message', onMessage);
	void galleryBuilt(`${galleryUrl}version.json`).then((ok) => {
		built.value = ok;
	});
});

onBeforeUnmount(() => {
	window.removeEventListener('message', onMessage);
});

watch(isDark, tellFrame);
</script>

<template>
	<div class="lognal-demo">
		<p v-if="built === false" class="lognal-demo-missing">
			The Flutter preview needs the gallery built — <code>npm run flutter</code> in
			<code>docs/</code>.
		</p>
		<iframe
			v-else-if="built"
			ref="frame"
			class="lognal-demo-frame"
			:src="source"
			:style="{ height: `${height}px` }"
			title="lognal for Flutter"
			loading="lazy"
		/>
		<div v-else class="lognal-demo-frame" :style="{ height: `${height}px` }" />
	</div>
</template>
