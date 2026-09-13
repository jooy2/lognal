---
order: 3
description: lognal을 이루는 부분이 어떻게 맞물리는지, 각 부분은 어디서 읽으면 되는지 안내합니다.
---

# 가이드

lognal 뷰어는 몇 가지 부분으로 이루어져 있고, 각 부분은 따로 떼어 쓸 수도 있습니다.

- `LogStore`는 항목을 추가된 순서대로 보관합니다. 화면 표시와는 관계가 없으므로, 스토어 하나를 여러 뷰어가 함께 보여 주거나 뷰어가 생기기 전부터 메시지를 모아 둘 수 있습니다.
- 소스는 스토어에 항목을 씁니다. `hookConsole`과 `createConsole`은 콘솔 호출을 기록하고, `readTextFile`과 `followTextFile`은 파일을 읽고, `store.write`는 텍스트를 바로 추가합니다.
- `LogLayout`은 어떤 항목을 보여 줄지 정하고, 뷰어 너비에 맞춰 항목을 행으로 나눕니다.
- 렌더러는 보이는 행을 그립니다. 내장된 `CanvasRenderer`는 Canvas 2D 컨텍스트를 씁니다.
- `LogViewer`는 이 모두를 묶어 도구 모음, 스크롤, 선택, 입력 줄, 상태 표시줄, 스크린 리더용 목록을 제공합니다.

```ts
import { LogStore, LogViewer, hookConsole } from 'lognal';

// 페이지가 시작될 때부터 콘솔을 기록합니다.
const store = new LogStore({ maxEntries: 50000 });

hookConsole(console, store);

// 뷰어를 놓을 자리가 생기면 스토어를 보여 줍니다.
const viewer = new LogViewer(document.getElementById('logs')!, { store });
```

## 이 가이드의 페이지 {#pages-in-this-guide}

- [콘솔 기록](/ko/guide/console): 콘솔 가로채기, 지원하는 메서드, 서식 지정자, 캡처 한도.
- [값 표시](/ko/guide/values): 미리 보기, 펼치고 접기, 오류, 표, 그룹, 반복 메시지.
- [텍스트 파일](/ko/guide/text-files): 파일 읽기, 인코딩, 늘어나는 파일 따라 읽기, ANSI 색.
- [뷰어](/ko/guide/viewer): 옵션, 도구 모음, 상태 표시줄, 타임스탬프, 필터, 선택, 입력 줄, 레이블, 이벤트.
- [테마와 글꼴](/ko/guide/theming): 테마 모드, CSS 사용자 지정 속성, 고정폭 글꼴.
- [React](/ko/guide/react): 컴포넌트와 props, ref, 스토어 공유, 서버 렌더링.
- [한국어와 CJK 문자](/ko/guide/cjk): 문자 폭, 줄 바꿈, IME 입력, 필터, 파일 인코딩.
