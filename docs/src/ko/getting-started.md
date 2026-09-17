---
order: 2
description: lognal을 설치하고 순수 JavaScript, React, Flutter에서 뷰어를 만들고, 애플리케이션이 이미 출력하는 내용을 옮겨 보여 주는 방법을 설명합니다.
---

# 시작하기

lognal은 하나의 코어에서 만든 언어별 패키지 두 개로 배포합니다. 메뉴 위 스위치에서 언어를 고르면 이 사이트의 모든 예제가 그 언어로 바뀝니다.

## 설치 {#install}

::: fw js

```sh
npm install lognal
```

:::

::: fw flutter

```sh
flutter pub add lognal
```

:::

::: fw js

## 스타일시트 추가 {#add-the-stylesheet}

애플리케이션에서 `lognal/style.css`를 한 번 가져옵니다. 도구 모음, 로그 영역, 입력 줄, 상태 표시줄의 레이아웃과 모든 테마의 색이 들어 있습니다.

```ts
import 'lognal/style.css';
```

:::

::: fw flutter

## 따로 추가할 것이 없음 {#nothing-else-to-add}

패키지에는 의존성도 스타일시트도 없습니다. 팔레트는 값이고, 위젯이 모든 것을 직접 그립니다. 웹에서만 고정폭 글꼴 하나를 준비해야 합니다. Flutter는 애플리케이션이 번들한 글꼴로 그리고 시스템 글꼴에는 접근하지 못하기 때문입니다. [테마와 글꼴](/ko/guide/theming)에서 다룹니다.

:::

## 높이 지정 {#give-it-a-height}

뷰어는 자신을 담은 것을 가득 채우므로, 담는 쪽에 높이가 있어야 합니다.

::: fw js

뷰어의 루트 요소는 `height: 100%`이고 최소 높이가 160픽셀이므로, 컨테이너에는 고정 크기나 flex, grid 레이아웃으로 높이를 따로 정해야 합니다.

```html
<div id="logs" style="height: 400px"></div>
```

:::

::: fw flutter

```dart
SizedBox(height: 400, child: LogViewer(store: store));
```

:::

## 뷰어 만들기 {#create-a-viewer}

::: fw js

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

:::

::: fw flutter

항목은 `LogStore`에 쌓이고 위젯은 그것을 보여 줍니다. 스토어를 위젯 밖에 두는 것이 핵심입니다. 로그 항목이 `setState`를 거치지 않으므로 메시지 하나는 리빌드가 아니라 다시 그리기 한 번입니다.

```dart
import 'package:flutter/widgets.dart';
import 'package:lognal/lognal.dart';

final LogStore store = LogStore();
final LognalConsole log = LognalConsole(store);

class LogPanel extends StatelessWidget {
  const LogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: LogViewer(
        store: store,
        options: const LogViewerOptions(theme: 'auto'),
      ),
    );
  }
}
```

```dart
store.write('Server started');
log.info('Connected to %s in %dms', <Object?>['database', 12]);
log.log('Current user', <Object?>[
  <String, Object?>{'id': 42, 'name': 'Ada', 'roles': <String>['admin']},
]);
```

- `store.write`는 일반 텍스트 한 줄을 추가합니다.
- `LognalConsole`은 로그 메서드를 갖춘 객체입니다. 스토어에만 쓰고 `print`는 건드리지 않습니다.
- 스크롤 위치, 선택, 검색 같은 나머지 상태는 `LogViewerController`가 들고 있으며, 이를 통해 코드에서 뷰어를 조작합니다. 넘기지 않으면 위젯이 직접 만듭니다.

:::

옵션은 [뷰어](/ko/guide/viewer)에서 모두 설명합니다.

::: fw js

## React에서 쓰기 {#use-it-with-react}

```tsx
import { LogViewer } from 'lognal/react';
import 'lognal/style.css';

export function Logs() {
	return <LogViewer style={{ height: 400 }} theme="auto" hookConsole />;
}
```

컴포넌트는 뷰어 옵션을 props로 받습니다. ref, 스토어 공유, 서버 렌더링은 [프레임워크에서](/ko/guide/framework)에서 다룹니다.

:::

::: fw flutter

## 코드에서 조작하기 {#drive-it-from-your-own-code}

```dart
final LogViewerController controller = LogViewerController(store: store);

// … build 안에서
LogViewer(controller: controller, options: const LogViewerOptions(theme: 'auto'));

// … 어디서든
controller.scrollToBottom();
await controller.copySelection();
```

컨트롤러가 무엇을 제공하는지, 위젯이 언제 직접 만드는지는 [프레임워크에서](/ko/guide/framework)에서 다룹니다.

:::

## 출력 옮겨 보기 {#mirror-what-the-application-prints}

::: fw js

`hookConsole`은 전역 `console` 호출을 모두 뷰어에 기록합니다. 메시지는 브라우저 콘솔에도 그대로 나옵니다.

```ts
const unhook = viewer.hookConsole();

console.warn('Disk usage is at %d%%', 91);
console.error(new Error('Failed to load the user profile'));

// 기록을 멈춥니다. 뷰어를 dispose해도 멈춥니다.
unhook();
```

:::

::: fw flutter

Dart는 세 가지 경로로 출력하므로 후크도 세 개입니다. 각각 후크를 떼는 함수를 돌려줍니다.

```dart
void main() {
  // Flutter 자신이 출력하는 것과 `debugPrint`에 넘긴 것.
  final void Function() unhookPrint = hookDebugPrint(store);
  // 빌드 중에 예외를 던진 위젯과 그 스택.
  final void Function() unhookErrors = hookFlutterErrors(store);

  // `print`는 변수가 아니라 존에 속하므로, 애플리케이션을 존 안에서 실행해 잡습니다.
  runZonedWithLognal(store, () => runApp(const MyApp()));
}
```

셋 다 원래 출력을 그대로 두므로 메시지는 터미널과 IDE에도 계속 나옵니다. 왜 셋인지는 [출력 기록](/ko/guide/console)에서 다룹니다.

:::

## 다음 단계 {#next-steps}

- [출력 기록](/ko/guide/console): 무엇을 기록하는지, 서식 지정자, 캡처 한도.
- [값 표시](/ko/guide/values): 객체, 오류, 표, 그룹을 보여 주는 방식.
- [텍스트 파일](/ko/guide/text-files): 로그 파일 읽기와 따라 읽기.
- [테마와 글꼴](/ko/guide/theming): 색, 다크 모드, 고정폭 글꼴.
