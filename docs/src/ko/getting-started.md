---
order: 2
description: lognal을 설치하고, 스타일시트를 추가하고, 순수 JavaScript나 React로 뷰어를 만들고, 브라우저 콘솔을 옮겨 보여 주는 방법을 설명합니다.
---

# 시작하기

## 설치 {#install}

```sh
npm install lognal
```

## 스타일시트 추가 {#add-the-stylesheet}

애플리케이션에서 `lognal/style.css`를 한 번 가져옵니다. 도구 모음, 로그 영역, 입력 줄, 상태 표시줄의 레이아웃과 밝은 테마, 어두운 테마의 색이 들어 있습니다.

```ts
import 'lognal/style.css';
```

## 컨테이너에 높이 지정 {#give-the-container-a-height}

뷰어는 자신을 만든 요소를 가득 채웁니다. 뷰어의 루트 요소는 `height: 100%`이고 최소 높이가 160픽셀이므로, 컨테이너에는 고정 크기나 flex, grid 레이아웃으로 높이를 따로 정해야 합니다.

```html
<div id="logs" style="height: 400px"></div>
```

## 뷰어 만들기 {#create-a-viewer}

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!, {
	theme: 'auto',
	timestamps: 'time'
});

viewer.write('Server started');
viewer.console.info('Connected to %s in %dms', 'database', 12);
viewer.console.log('Current user', { id: 42, name: 'Ada', roles: ['admin'] });
```

- `viewer.write`는 일반 텍스트 한 줄을 추가합니다.
- `viewer.console`은 콘솔 메서드를 갖춘 객체입니다. 이 뷰어에만 쓰고 브라우저 콘솔은 건드리지 않습니다.
- `viewer.dispose()`는 페이지에서 뷰어를 없애고 뷰어가 시작한 작업을 모두 멈춥니다.

옵션은 [뷰어](/ko/guide/viewer)에서 모두 설명합니다.

## React에서 쓰기 {#use-it-with-react}

```tsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export function Logs() {
	return <LogViewer style={{ height: 400 }} theme="auto" hookConsole />;
}
```

컴포넌트는 뷰어 옵션을 props로 받습니다. ref, 스토어 공유, 서버 렌더링은 [React](/ko/guide/react)에서 다룹니다.

## 브라우저 콘솔 옮겨 보기 {#mirror-the-browser-console}

`hookConsole`은 전역 `console` 호출을 모두 뷰어에 기록합니다. 메시지는 브라우저 콘솔에도 그대로 나옵니다.

```ts
const unhook = viewer.hookConsole();

console.warn('Disk usage is at %d%%', 91);
console.error(new Error('Failed to load the user profile'));

// 기록을 멈춥니다. 뷰어를 dispose해도 멈춥니다.
unhook();
```

## 다음 단계 {#next-steps}

- [콘솔 기록](/ko/guide/console): 지원하는 메서드, 서식 지정자, 캡처 한도.
- [값 표시](/ko/guide/values): 객체, 오류, 표, 그룹을 보여 주는 방식.
- [텍스트 파일](/ko/guide/text-files): 로그 파일 읽기와 따라 읽기.
- [테마와 글꼴](/ko/guide/theming): 색, 다크 모드, 고정폭 글꼴.
