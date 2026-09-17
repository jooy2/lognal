---
layout: page
sidebar: false
pageClass: demo-layout
title: 데모
description: lognal의 모든 기능을 브라우저에서 시험합니다. 콘솔 메시지, 값, ANSI 텍스트, 한국어 텍스트를 쓰고, 파일을 읽고, 뷰어 옵션을 하나씩 바꾸고, LogViewer의 메서드를 호출해 보세요.
---

<div class="demo-page">
<div class="demo-intro vp-doc">

# 데모

::: fw js

이 페이지는 저장소의 lognal 소스를 그대로 실행합니다. 버튼으로 예제 로그를 쓰고, 옵션을 바꿔 뷰어가 어떻게 달라지는지 보고, `LogViewer`의 메서드를 호출하면서 이벤트를 확인해 보세요. 여기서 연 파일은 브라우저 안에서만 읽고 어디에도 올리지 않습니다.

:::

::: fw flutter

`packages/flutter/example`를 빌드한 Flutter 갤러리를 그대로 끼워 넣었습니다. 그림이 아니라 진짜 Flutter 빌드입니다. 왼쪽 버튼으로 예제 로그를 쓴 다음 도구 모음을 써 보세요. 팔레트는 이 페이지의 라이트/다크 스위치를 따릅니다.

:::

<FrameworkSelect compact />

</div>

::: fw js

<ClientOnly>
  <FullDemo />
</ClientOnly>

:::

::: fw flutter

<ClientOnly>
  <FlutterDemo :height="620" />
</ClientOnly>

:::

</div>
