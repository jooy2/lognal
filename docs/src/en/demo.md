---
layout: page
sidebar: false
pageClass: demo-layout
title: Demo
description: Try every feature of lognal in the browser. Write console messages, typed values, ANSI text and Korean text, read files, change each viewer option, and call the methods of LogViewer.
---

<div class="demo-page">
<div class="demo-intro">
<div class="demo-intro-text vp-doc">

# Demo

::: fw js

This page runs lognal from its repository. Write sample logs with the buttons, change any option and watch the viewer follow, and call the methods of `LogViewer` while its events are listed. Files you open here are read in your browser and are not uploaded.

:::

::: fw flutter

This is the Flutter gallery, built from `packages/flutter/example` and framed here, so what you are looking at is the real Flutter build rather than a picture of one. Write sample logs with the buttons on the left, then try the toolbar. It takes its palette from this page's light and dark switch.

:::

</div>

<FrameworkSelect compact />

</div>

::: fw js

<ClientOnly>
  <FullDemo />
</ClientOnly>

:::

::: fw flutter

<ClientOnly>
  <FlutterDemo fill />
</ClientOnly>

:::

</div>
