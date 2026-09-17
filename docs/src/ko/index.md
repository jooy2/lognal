---
layout: home

title: lognal
titleTemplate: 웹과 Flutter를 위한 캔버스 로그 뷰어
description: lognal은 캔버스에 그리는 터미널 스타일 로그 뷰어입니다. 브라우저와 Flutter 양쪽에서 동작하며, 애플리케이션이 출력하는 내용을 옮겨 보여 주고, 로그 파일을 읽고, 값을 펼치고 접으며 살펴봅니다.

hero:
  name: lognal
  text: 터미널 스타일 로그 뷰어, 두 언어로
  tagline: 코어 하나를 npm과 pub.dev 두 곳에 올렸습니다. 로그를 캔버스에 그리고, 애플리케이션 출력을 옮겨 보여 주고, 로그 파일을 읽고, 값을 펼치고 접으며 살펴봅니다.
  actions:
    - theme: brand
      text: 시작하기
      link: /ko/getting-started
    - theme: alt
      text: 가이드
      link: /ko/guide/
    - theme: alt
      text: 데모
      link: /ko/demo
  image:
    src: /icon.webp
    alt: lognal

features:
  - title: 캔버스에 그립니다
    details: 줄마다 DOM 요소를 만들지 않고 캔버스 하나에 로그를 그립니다. 한 프레임을 그리는 비용은 쌓인 기록의 양이 아니라 화면에 보이는 행 수로 정해집니다.
    link: /ko/introduction
    linkText: 캔버스를 쓰는 이유
  - title: 출력을 그대로 옮깁니다
    details: 브라우저에서는 console.log, warn, error, table, group을, Flutter에서는 debugPrint와 print와 실패한 빌드를 기록합니다. 호출한 순간의 값을 저장하고 %s, %d, %o, %c 서식 지정자도 처리합니다.
    link: /ko/guide/console
    linkText: 출력 기록
  - title: 펼쳐 보는 값
    details: 객체, 리스트, 맵, 세트, 오류를 로그를 남긴 순간의 모습으로 저장하고, 클릭해서 펼치거나 접습니다.
    link: /ko/guide/values
    linkText: 값 표시
  - title: 로그 파일 읽기
    details: 파일을 조각으로 나눠 읽고 바이트만 보고 인코딩을 알아냅니다. 계속 늘어나는 파일도 따라 읽습니다.
    link: /ko/guide/text-files
    linkText: 텍스트 파일
  - title: 한국어와 CJK 문자
    details: 전각 문자는 두 칸을 차지하고, 줄이 바뀔 때 한글 낱말은 쪼개지지 않으며, 입력 줄은 IME 조합이 끝날 때까지 기다립니다.
    link: /ko/guide/cjk
    linkText: 한국어와 CJK
  - title: 하나의 라이브러리, 두 언어
    details: 코어를 TypeScript와 Dart로 파일 단위까지 똑같이 썼고, 양쪽 테스트가 같은 것을 확인합니다. 로그 한 줄은 브라우저에서도 앱에서도 같은 뜻입니다.
    link: /ko/guide/framework
    linkText: 프레임워크에서
---

## 직접 써 보기 {#try-it}

아래 뷰어는 이 저장소의 라이브러리 코드로 동작합니다. 버튼으로 로그를 쓴 다음 도구 모음을 써 보세요. 텍스트로 거르거나, 수준을 고르거나, 줄 바꿈을 끄거나, 위로 스크롤해서 따라가기를 멈출 수 있습니다. 나머지 옵션과 기능은 [데모 페이지](/ko/demo)에 모두 있습니다.

<ClientOnly>
  <LiveViewer preset="console" />
</ClientOnly>

## 간단한 예제 {#a-short-example}

다른 페이지에는 메뉴 위에 언어 스위치가 있습니다. 예제를 어느 패키지로 쓸지 그 스위치가 정합니다. 이 페이지에는 메뉴가 없으니 둘 다 싣습니다.

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!);

viewer.hookConsole();
console.log('Signed in as %s', 'ada', { id: 42, roles: ['admin'] });
```

```dart
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();

hookDebugPrint(store);
debugPrint('Signed in as ada');

// … 화면에서 로그가 들어갈 자리에.
SizedBox(height: 400, child: LogViewer(store: store));
```

뷰어를 담는 쪽에는 높이가 있어야 합니다. 전체 설정 방법은 [시작하기](/ko/getting-started)에 있습니다.
