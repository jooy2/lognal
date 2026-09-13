---
order: 6
description: lognal/react의 LogViewer 컴포넌트로 React에서 lognal을 쓰는 방법과 props, ref, 스토어 공유, hookConsole prop, 서버 렌더링을 설명합니다.
---

# React

`lognal/react`는 `LogViewer` 컴포넌트를 내보냅니다. 이 컴포넌트는 컨테이너를 렌더링하고, 마운트된 뒤 그 안에 뷰어를 만듭니다. React 18 이상이 필요합니다.

```tsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export function Logs() {
	return <LogViewer style={{ height: 400 }} theme="auto" timestamps="datetime" />;
}
```

컨테이너에는 `height: 100%`가 지정되어 있고, 넘긴 `style`이 그 위에 적용됩니다. `style`이나 `className`, 부모 요소로 컴포넌트에 높이를 주세요.

## Props {#props}

[뷰어 옵션](/ko/guide/viewer#options)은 모두 prop으로도 넘길 수 있습니다. `store`, `core`, `theme`, `font`, `timestamps`, `follow`, `toolbar`, `statusBar`, `input`, `locale`, `labels`, `entryMenu`, `renderer`가 여기에 해당합니다. 컴포넌트에만 있는 prop은 다음과 같습니다.

| Prop                | 타입                                  | 설명                                                                 |
| ------------------- | ------------------------------------- | -------------------------------------------------------------------- |
| `className`         | `string`                              | 컨테이너의 클래스입니다.                                             |
| `style`             | `CSSProperties`                       | 컨테이너의 스타일입니다.                                             |
| `hookConsole`       | `boolean \| HookConsoleOptions`       | 컴포넌트가 마운트되어 있는 동안 전역 `console`을 뷰어에 기록합니다.  |
| `onReady`           | `(viewer: LogViewer \| null) => void` | 뷰어가 생기면 뷰어를, 뷰어를 정리한 뒤에는 `null`을 넘겨 호출합니다. |
| `onFollowChange`    | `(following: boolean) => void`        | 따라가기가 켜지거나 꺼질 때 호출합니다.                              |
| `onFilterChange`    | `(filter: LogFilter \| null) => void` | 필터가 바뀔 때 호출합니다.                                           |
| `onSelectionChange` | `(text: string) => void`              | 선택한 텍스트가 바뀔 때 호출합니다.                                  |

### prop 변경이 적용되는 방식 {#how-prop-changes-are-applied}

- 옵션 prop은 데이터로 비교합니다. 렌더링할 때마다 `toolbar` 객체를 새로 만들어 넘겨도 내용이 같으면 아무 비용이 들지 않습니다.
- 데이터가 바뀐 prop만 `viewer.setOptions`에 넘기고, `core`는 키마다 따로 비교합니다. 새 뷰어는 만들지 않습니다.
- prop 하나가 바뀌어도 다른 prop은 다시 적용하지 않습니다. `theme`이 바뀔 때 `follow`, `core.filter`, `core.wrap`은 적용하지 않으므로, 사용자가 도구 모음에서 바꾼 따라가기, 필터, 줄 바꿈이 그대로 남습니다. prop이 사용자의 선택을 덮어쓰는 것은 그 prop의 데이터가 바뀔 때뿐입니다.
- `input.onSubmit`, `timestamps` 함수, `labels.entries`, `entryMenu.items`처럼 옵션 안에 있는 함수는 늘 가장 최근 렌더링의 함수를 호출합니다. 새 함수를 넘겨도 바뀐 것으로 보지 않습니다.
- `store`나 `renderer`를 바꾸면 뷰어를 정리하고 새로 만듭니다.

prop을 빼면 그 옵션은 기본값으로 돌아갑니다.

| 뺀 prop                                                            | 적용하는 값                                                                           |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| `theme`, `font`, `timestamps`, `toolbar`, `statusBar`, `entryMenu` | `'auto'`, `{}`, `true`, `true`, `true`, `true`                                        |
| `input`, `labels`, `locale`                                        | `null`, `{}`, `undefined`이며, `locale`이 없으면 영어 레이블을 보여 줍니다.           |
| `core`의 키나 `core` 전체                                          | `DEFAULT_STORE_OPTIONS`나 `DEFAULT_LAYOUT_OPTIONS`의 값이고, `filter`는 `null`입니다. |
| `follow`                                                           | 아무것도 적용하지 않습니다. 따라가는 중이든 멈춘 상태든 지금 상태가 그대로 남습니다.  |

## 로그 쓰기 {#write-logs}

로그 항목은 React 상태를 거치지 않으므로, 새 메시지가 들어와도 컴포넌트를 다시 렌더링하지 않습니다. ref, `onReady`, 스토어 가운데 하나로 뷰어에 쓰세요.

ref에는 `lognal`의 `LogViewer` 인스턴스가 들어 있고, 마운트 전과 언마운트 뒤에는 `null`입니다.

```tsx
import { useRef } from 'react';
import type { LogViewer as Viewer } from 'lognal';
import { LogViewer } from 'lognal/react';

export function DeployLog() {
	const viewer = useRef<Viewer>(null);

	return (
		<>
			<button type="button" onClick={() => viewer.current?.console.info('Deploy started')}>
				Deploy
			</button>
			<LogViewer ref={viewer} style={{ height: 320 }} />
		</>
	);
}
```

## 스토어 공유 {#share-a-store}

컴포넌트 밖에서 만든 `LogStore`는 컴포넌트가 마운트되어 있든 아니든 항목을 모으고, 여러 컴포넌트가 같은 스토어를 보여 줄 수 있습니다.

```tsx
import { LogStore } from 'lognal';
import { LogViewer } from 'lognal/react';

const store = new LogStore({ maxEntries: 50000 });
const socket = new WebSocket('wss://example.com/logs');

socket.addEventListener('message', (event) => {
	store.write(String(event.data));
});

export function ServerLog() {
	return <LogViewer store={store} style={{ height: 400 }} />;
}
```

컴포넌트 안에서 스토어를 만들려면 `useState(() => new LogStore())`로 렌더링이 반복되어도 같은 스토어를 유지하세요. 렌더링할 때마다 새 스토어를 넘기면 그때마다 뷰어를 새로 만듭니다.

## 콘솔 기록 {#hook-the-console}

`hookConsole`은 컴포넌트가 마운트되어 있는 동안 전역 `console`을 기록하고, 언마운트될 때 원래대로 되돌립니다. 옵션을 넘기면 기록할 메서드와 캡처 한도를 고를 수 있습니다.

```tsx
import { LogViewer } from 'lognal/react';

export function ProblemLog() {
	return <LogViewer hookConsole={{ methods: ['warn', 'error'], maxDepth: 3 }} style={{ height: 400 }} />;
}
```

`hookConsole={true}`는 지원하는 메서드를 모두 기록합니다. prop의 데이터가 바뀔 때만 콘솔을 다시 가로채고, 개발 모드에서 컴포넌트를 두 번 마운트하는 `StrictMode`에서도 제대로 동작합니다.

## 서버 렌더링 {#server-rendering}

컴포넌트 파일은 `'use client'`로 시작하므로, Next.js App Router처럼 React Server Components를 쓰는 프레임워크는 이 컴포넌트를 클라이언트 컴포넌트로 다룹니다. 서버에서는 빈 컨테이너만 렌더링하고, 뷰어는 하이드레이션이 끝난 뒤 브라우저에서 만듭니다.

- `lognal/style.css`는 루트 레이아웃 같은 곳에서 한 번 가져옵니다.
- 서버에서 `lognal`을 가져와도 문제없습니다. 다만 `LogViewer`를 만들려면 브라우저가 필요하므로, 컴포넌트가 하는 것처럼 이펙트나 이벤트 핸들러 안에서 만드세요.
- `hookConsole`은 브라우저에서 일어난 호출만 기록합니다.

```tsx
// app/layout.tsx
import 'lognal/style.css';
```

```tsx
// app/logs/page.tsx
import { LogViewer } from 'lognal/react';

export default function LogsPage() {
	return <LogViewer hookConsole style={{ height: '80vh' }} />;
}
```
