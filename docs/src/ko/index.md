---
layout: home

title: lognal
titleTemplate: 캔버스로 그리는 브라우저 로그 뷰어
description: lognal은 캔버스에 그리는 터미널 스타일의 브라우저 로그 뷰어입니다. 콘솔 출력을 옮겨 보여 주고, 로그 파일을 읽고, 값을 펼치고 접으며 살펴볼 수 있습니다.

hero:
  name: lognal
  text: 브라우저에서 쓰는 터미널 스타일 로그 뷰어
  tagline: 로그를 캔버스에 그리고, 콘솔 출력을 옮겨 보여 주고, 로그 파일을 읽고, 값을 펼치고 접으며 살펴봅니다.
  actions:
    - theme: brand
      text: 시작하기
      link: /ko/getting-started
    - theme: alt
      text: 가이드
      link: /ko/guide/
  image:
    src: /icon.webp
    alt: lognal

features:
  - title: 캔버스에 그립니다
    details: 줄마다 DOM 요소를 만들지 않고 캔버스 하나에 로그를 그립니다. 한 프레임을 그리는 비용은 쌓인 기록의 양이 아니라 화면에 보이는 행 수로 정해집니다.
    link: /ko/introduction
    linkText: 캔버스를 쓰는 이유
  - title: 콘솔을 그대로 옮깁니다
    details: console.log, warn, error, table, group, count, time 같은 메서드를 기록하고 %s, %d, %o, %c 서식 지정자도 처리합니다.
    link: /ko/guide/console
    linkText: 콘솔 기록
  - title: 펼쳐 보는 값
    details: 객체, 배열, Map, Set, 오류, DOM 요소를 로그를 남긴 순간의 모습으로 저장하고, 클릭해서 펼치거나 접습니다.
    link: /ko/guide/values
    linkText: 값 표시
  - title: 로그 파일 읽기
    details: 선택한 파일을 조각으로 나눠 읽고 UTF-8이나 EUC-KR 같은 레거시 인코딩을 알아냅니다. Chromium 계열 브라우저에서는 계속 늘어나는 파일도 따라 읽습니다.
    link: /ko/guide/text-files
    linkText: 텍스트 파일
  - title: 한국어와 CJK 문자
    details: 전각 문자는 두 칸을 차지하고, 줄이 바뀔 때 한글 낱말은 쪼개지지 않으며, 입력 줄은 IME 조합이 끝날 때까지 기다립니다.
    link: /ko/guide/cjk
    linkText: 한국어와 CJK
  - title: 프레임워크 없이 동작합니다
    details: 코어에는 런타임 의존성도, 프레임워크 코드도 없습니다. React 컴포넌트는 lognal/react에서 가져오고, 색은 모두 CSS 사용자 지정 속성으로 바꿉니다.
    link: /ko/guide/react
    linkText: React
---

## 직접 써 보기 {#try-it}

아래 뷰어는 이 저장소의 라이브러리 코드로 동작합니다. 버튼으로 로그를 쓴 다음 도구 모음을 써 보세요. 텍스트로 거르거나, 수준을 고르거나, 줄 바꿈을 끄거나, 위로 스크롤해서 따라가기를 멈출 수 있습니다.

<ClientOnly>
  <LiveViewer preset="console" />
</ClientOnly>

## 간단한 예제 {#a-short-example}

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!);

viewer.hookConsole();
console.log('Signed in as %s', 'ada', { id: 42, roles: ['admin'] });
```

컨테이너에는 `#logs { height: 400px; }`처럼 높이를 지정해야 합니다. 전체 설정 방법은 [시작하기](/ko/getting-started)에 있습니다.
