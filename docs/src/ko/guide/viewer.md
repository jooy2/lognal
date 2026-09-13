---
order: 4
description: LogViewer의 모든 옵션과 기본값, 그리고 도구 모음, 상태 표시줄, 타임스탬프, 따라가기, 필터, 선택, 입력 줄, 레이블, 이벤트의 동작을 설명합니다.
---

# 뷰어

## 만들기와 정리 {#create-and-dispose}

`new LogViewer(container, options)`는 `container`의 끝에 뷰어를 추가합니다. 뷰어는 컨테이너를 가득 채우므로 컨테이너에 높이를 지정하세요.

```ts
import { LogViewer } from 'lognal';
import 'lognal/style.css';

const viewer = new LogViewer(document.getElementById('logs')!, {
	theme: 'dark',
	core: { maxEntries: 50000 }
});

// 나중에 뷰어가 더는 필요 없을 때:
viewer.dispose();
```

`dispose()`는 페이지에서 뷰어를 없애고, 이벤트 리스너를 떼고, `viewer.hookConsole`로 시작한 콘솔 기록을 멈춥니다. 스토어의 항목은 남아 있으므로 다른 뷰어에서 보여 줄 수 있습니다.

## 옵션 {#options}

| 옵션         | 타입                                    | 기본값       | 설명                                                                                  |
| ------------ | --------------------------------------- | ------------ | ------------------------------------------------------------------------------------- |
| `store`      | `LogStore`                              | 새 스토어    | 보여 줄 스토어입니다. 여러 뷰어가 스토어 하나를 함께 쓸 수 있습니다.                  |
| `core`       | `Partial<CoreOptions>`                  | 아래 표 참고 | 보관할 양, 줄 배치 방식, 보여 줄 항목을 정합니다.                                     |
| `theme`      | `'auto' \| 'light' \| 'dark'`           | `'auto'`     | 색 구성입니다. `'auto'`는 운영체제 설정을 따릅니다.                                   |
| `font`       | `Partial<FontSettings>`                 | CSS 값       | 로그의 글꼴입니다. 빠진 값은 `--lognal-font-*` 속성에서 가져옵니다.                   |
| `timestamps` | `boolean \| TimestampFormat`            | `true`       | 항목마다 시각을 보여 줄지, 어떤 형식으로 보여 줄지 정합니다. `true`는 `'time'`입니다. |
| `follow`     | `boolean`                               | `true`       | 처음에 새 항목을 따라갈지 정합니다.                                                   |
| `toolbar`    | `boolean \| Partial<ToolbarOptions>`    | `true`       | 도구 모음의 컨트롤입니다. `false`이면 도구 모음을 숨깁니다.                           |
| `statusBar`  | `boolean`                               | `true`       | 상태 표시줄을 보여 줄지 정합니다.                                                     |
| `input`      | `InputOptions \| null`                  | `null`       | 입력 줄입니다. 읽기 전용 뷰어라면 생략합니다.                                         |
| `locale`     | `string`                                | 없음         | 내장 레이블과 숫자 서식의 언어입니다. 예를 들면 `'ko'`입니다.                         |
| `labels`     | `Partial<ViewerLabels>`                 | 내장 레이블  | 내장 레이블 대신 쓸 레이블입니다.                                                     |
| `renderer`   | `(ownerDocument: Document) => Renderer` | Canvas 2D    | 렌더러를 만듭니다. [레이아웃과 렌더러](/ko/reference/layout#renderer)를 참고하세요.   |

### 코어 옵션 {#core-options}

| 옵션             | 타입                         | 기본값   | 설명                                                                                                                                   |
| ---------------- | ---------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`     | `number`                     | `10000`  | 스토어가 보관하는 최대 항목 수입니다. 넘으면 새 항목이 들어올 때마다 가장 오래된 항목을 버립니다. 모두 보관하려면 `Infinity`를 씁니다. |
| `mergeRepeats`   | `boolean`                    | `true`   | 바로 앞과 똑같은 메시지가 들어오면 앞 항목의 반복 횟수를 올릴지 정합니다.                                                              |
| `wrap`           | `'word' \| 'char' \| 'none'` | `'word'` | 뷰어보다 긴 줄을 처리하는 방식입니다. [줄 바꿈](/ko/guide/cjk#word-wrapping)을 참고하세요.                                             |
| `tabSize`        | `number`                     | `8`      | 탭 위치 사이의 칸 수입니다.                                                                                                            |
| `ambiguousWidth` | `1 \| 2`                     | `1`      | 동아시아 모호 폭 문자가 차지하는 칸 수입니다.                                                                                          |
| `maxClusters`    | `number`                     | `10000`  | 한 줄에 남기는 최대 글자 수입니다. 나머지는 `…`로 대신합니다.                                                                          |
| `filter`         | `LogFilter \| null`          | `null`   | 처음에 적용할 필터입니다. [필터](#filtering)를 참고하세요.                                                                             |

`maxEntries`와 `mergeRepeats`는 스토어의 옵션입니다. `store`와 함께 이 옵션을 넘기면 그 스토어에 적용되므로, 스토어를 함께 쓰는 모든 뷰어에 영향을 줍니다.

### 나중에 옵션 바꾸기 {#change-options-later}

`setOptions`는 넘긴 옵션만 바꾸고 나머지는 그대로 둡니다. `store`와 `renderer`는 만든 뒤에 바꿀 수 없습니다.

```ts
viewer.setOptions({ theme: 'light', toolbar: { levels: false } });
viewer.setOptions({ core: { wrap: 'none' } });
viewer.setOptions({ locale: 'ko' });
```

`toolbar`, `statusBar`, `input`, `labels`, `locale` 가운데 하나라도 넘기면 도구 모음, 입력 줄, 상태 표시줄을 다시 만듭니다. `locale`은 값이 `undefined`여도 키가 있기만 하면 다시 만듭니다. `locale`과 `labels`가 함께 적용되는 방식은 [레이블과 로케일](#labels-and-locale)에서 설명합니다.

## 도구 모음 {#toolbar}

| 컨트롤                       | `ToolbarOptions` 키 | 동작                                                                                                               |
| ---------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 새 로그 따라가기             | `follow`            | 따라가기를 켜거나 끕니다.                                                                                          |
| 로그 지우기                  | `clear`             | 스토어의 항목을 모두 지웁니다.                                                                                     |
| 맨 위로 이동, 맨 아래로 이동 | `scroll`            | 가장 오래된 항목이나 가장 새 항목으로 이동합니다. 맨 아래로 이동하면 따라가기가 켜집니다.                          |
| 긴 줄 바꾸기                 | `wrap`              | 줄 바꿈을 끕니다. 한 번 더 누르면 버튼이 끄기 전의 모드인 `'word'`나 `'char'`로 돌아갑니다.                        |
| 필터                         | `filter`            | 입력한 텍스트가 들어 있는 항목만 보여 줍니다. 입력을 멈추고 120ms 뒤에 적용합니다.                                 |
| 로그 수준                    | `levels`            | 모든 수준, 로그 이상, 정보 이상, 경고와 오류, 오류만 가운데 하나를 보여 줍니다. 고른 값은 `minLevel`로 적용합니다. |

기본으로 모든 컨트롤이 보입니다. 일부만 숨기려면 객체를, 도구 모음 전체를 숨기려면 `false`를 넘깁니다.

```ts
new LogViewer(container, { toolbar: { wrap: false, levels: false } });
new LogViewer(container, { toolbar: false });
```

`core: { wrap: 'none' }`처럼 버튼이 아닌 방법으로 줄 바꿈을 껐다면, 버튼을 누를 때 `'word'`가 켜집니다. 버튼으로 `'char'`를 끈 적이 있으면 `'char'`가 켜집니다.

`wrap` 설정과 상관없이 줄을 바꾸지 않는 텍스트도 있습니다. `console.table`의 출력과 `wrap: false`로 쓴 텍스트입니다. 이런 줄이 뷰어보다 넓으면 로그를 가로로 스크롤할 수 있고 가로 스크롤바가 나타납니다.

```ts
viewer.write(['+-------+------+', '| build | pass |', '+-------+------+'].join('\n'), { wrap: false });
```

## 상태 표시줄 {#status-bar}

상태 표시줄 왼쪽에는 `3 entries`처럼 항목 수가 나오고, 필터나 접힌 그룹 때문에 일부가 숨겨지면 `1 of 3 entries`처럼 나옵니다. 오른쪽에는 `Following`이나 `Paused`가 나옵니다. `locale: 'ko'`이면 `로그 3개`, `따라가는 중`처럼 한국어로 나옵니다. 상태 표시줄은 최대 200ms마다 갱신하고, 숫자는 `locale` 옵션에 맞는 서식으로 씁니다.

## 타임스탬프 {#timestamps}

항목마다 추가된 시각이나 함께 넘긴 `time`을 왼쪽 열에 보여 줍니다.

| `timestamps`               | 예                         |
| -------------------------- | -------------------------- |
| `true`, `'time'`           | `14:03:09.120`             |
| `'datetime'`               | `2026-09-13 14:03:09.120`  |
| `'iso'`                    | `2026-09-13T05:03:09.120Z` |
| `(time: number) => string` | 직접 정한 형식             |
| `false`                    | 타임스탬프 열 없음         |

`'time'`과 `'datetime'`은 현지 시각을, `'iso'`는 UTC를 씁니다. 열 너비는 선택한 형식으로 현재 시각을 쓴 길이로 정하므로, 함수는 매번 같은 길이의 텍스트를 반환해야 합니다. 더 긴 텍스트는 열에 맞게 좁혀서 그립니다.

```ts
new LogViewer(container, {
	timestamps: (time) => new Date(time).toLocaleTimeString('en-GB')
});
```

## 새 로그 따라가기 {#following-new-logs}

뷰어는 맨 아래에서 시작하고, 항목이 들어오는 동안 맨 아래에 머뭅니다. 위로 스크롤하면 따라가기가 멈추고, 멈춘 사이에 들어온 항목이 있으면 **새 로그** 버튼이 나타납니다. 맨 아래로 다시 스크롤하거나, 이 버튼이나 도구 모음의 따라가기 버튼을 누르면 다시 따라갑니다.

```ts
const checkpoint = viewer.store.write('Checkpoint', { level: 'info' });

// 나중에: 따라가기를 멈추고 체크포인트를 화면 맨 위에 보여 줍니다.
if (checkpoint) {
	viewer.scrollToEntry(checkpoint.id);
}

viewer.on('follow', (following) => {
	document.body.classList.toggle('logs-paused', !following);
});
```

`scrollToTop()`과 `scrollToEntry(id)`는 따라가기를 멈춥니다. `scrollToBottom()`과 `setFollowing(true)`는 다시 따라가게 하고, 지금 따라가는 중인지는 `viewer.isFollowing`으로 알 수 있습니다.

따라가기가 멈춘 동안에는 화면 맨 위의 항목을 제자리에 둡니다. 스토어 앞쪽의 항목이 지워지거나, 화면 위쪽의 값을 펼치거나, 폭이 바뀌어 줄 바꿈이 달라져도 읽던 위치가 움직이지 않습니다.

로그가 많을 때 폭이 바뀌면 화면에 보이는 행부터 배치하고, 나머지는 프레임 사이에 조금씩 나눠 배치합니다. 배치가 끝날 때까지 스크롤바는 추정한 행 높이를 쓰므로 막대가 조금 움직일 수 있지만, 화면에 보이는 내용은 그대로입니다.

## 필터 {#filtering}

```ts
// "timeout"이 들어 있고 경고 수준 이상인 항목.
viewer.setFilter({ text: 'timeout', minLevel: 'warn' });

// 대소문자를 구분하는 정규 표현식.
viewer.setFilter({ text: '^GET /api/', regex: true, caseSensitive: true });

// debug와 info 항목만.
viewer.setFilter({ levels: ['debug', 'info'] });

// 모든 항목 보이기.
viewer.setFilter(null);
```

| `LogFilter` 필드 | 타입         | 설명                                                                      |
| ---------------- | ------------ | ------------------------------------------------------------------------- |
| `text`           | `string`     | 항목에 들어 있어야 하는 텍스트입니다. 비어 있으면 모든 항목이 통과합니다. |
| `regex`          | `boolean`    | `text`를 정규 표현식으로 볼지 정합니다.                                   |
| `caseSensitive`  | `boolean`    | 대소문자를 구분할지 정합니다. 기본으로는 구분하지 않습니다.               |
| `minLevel`       | `LogLevel`   | 보여 줄 가장 낮은 수준입니다.                                             |
| `levels`         | `LogLevel[]` | 보여 줄 수준입니다. 이 값이 있으면 `minLevel`은 무시합니다.               |

수준은 낮은 것부터 `debug`, `log`, `info`, `warn`, `error` 순서입니다.

- 텍스트는 항목의 텍스트와 각 값의 한 줄 미리 보기에서 찾습니다. 오류는 제목과 스택 트레이스에서 찾습니다. 항목마다 처음 20,000자까지만 찾습니다.
- 일치하는 부분은 보이는 행에서 강조합니다.
- 컴파일되지 않는 정규 표현식을 넣으면 모든 항목을 숨기고 필터 입력란을 잘못된 값으로 표시합니다.
- 수준 필터는 입력 줄에 입력한 명령과 `Console was cleared` 같은 뷰어 알림을 숨기지 않습니다. 텍스트 필터가 없으면 그룹 머리글도 계속 보입니다.
- 도구 모음의 필터 입력란은 `text`만 바꾸므로, `setFilter`로 켠 `regex`는 사용자가 입력하는 동안에도 유지됩니다. 수준 메뉴는 `minLevel`을 정하고 `levels`를 지우므로, `setFilter({ levels })`를 호출한 뒤에도 제대로 동작합니다.
- 항목 텍스트와 필터 텍스트를 유니코드 정규화 형식 C로 맞춰 비교하므로, 풀어쓴 한글도 사용자가 입력한 글자와 일치합니다. [한국어와 CJK 문자](/ko/guide/cjk#filtering-decomposed-hangul)를 참고하세요.

도구 모음에서 바꾸든 `setFilter`로 바꾸든, 필터가 바뀔 때마다 `filter` 이벤트가 발생합니다. 현재 필터는 `getFilter()`로 얻습니다.

## 선택과 복사 {#selection-and-copy}

로그 영역에 포커스가 있을 때 마우스와 키보드는 이렇게 동작합니다.

| 동작                | 결과                                                    |
| ------------------- | ------------------------------------------------------- |
| 마우스로 드래그     | 텍스트를 선택합니다. 가장자리 밖으로 끌면 스크롤됩니다. |
| Shift를 누르고 클릭 | 선택 범위를 넓힙니다.                                   |
| 더블클릭            | 낱말 하나를 선택합니다.                                 |
| Ctrl+A나 Cmd+A      | 보이는 항목을 모두 선택합니다.                          |
| Ctrl+C나 Cmd+C      | 선택한 텍스트를 복사합니다.                             |
| Escape              | 선택을 해제합니다.                                      |

터치 입력은 로그를 스크롤하고 텍스트를 선택하지 않습니다. 여러 행에 걸쳐 줄 바꿈된 줄은 한 줄로 복사하고, 펼친 값의 행도 함께 복사합니다.

같은 동작을 메서드로도 쓸 수 있습니다. `getSelectionText()`, `selectAll()`, `clearSelection()`, `copySelection()`이 있고, `copySelection()`은 복사한 내용이 있는지를 불리언으로 이행합니다. 선택한 텍스트가 바뀔 때마다 `selection` 이벤트가 그 텍스트를 알려 줍니다.

## 입력 줄 {#input-line}

`input`을 넘기면 입력 줄이 나타납니다. 입력한 명령은 `onSubmit`으로 전달되고, 함수가 반환한 값을 응답으로 출력합니다.

<ClientOnly>
  <LiveViewer preset="input" :height="300" />
</ClientOnly>

```ts
const socket = new WebSocket('wss://example.com/console');
const viewer = new LogViewer(container, {
	input: {
		prompt: '$',
		onSubmit: (command) => {
			if (command === 'time') {
				return new Date();
			}

			// 명령을 서버로 보냅니다. 응답은 나중에 viewer.write로 들어옵니다.
			socket.send(command);
		}
	}
});

socket.addEventListener('message', (event) => viewer.write(String(event.data)));
```

| `InputOptions` 필드 | 타입                                              | 기본값           | 설명                                                    |
| ------------------- | ------------------------------------------------- | ---------------- | ------------------------------------------------------- |
| `onSubmit`          | `(command: string, viewer: LogViewer) => unknown` | 필수             | 명령마다 호출합니다.                                    |
| `prompt`            | `string`                                          | `'>'`            | 입력 앞에 보이는 프롬프트입니다.                        |
| `placeholder`       | `string`                                          | `Type a command` | 자리 표시 텍스트입니다. 기본값은 레이블에서 가져옵니다. |
| `echo`              | `boolean`                                         | `true`           | 명령을 실행하기 전에 로그에 추가할지 정합니다.          |
| `historySize`       | `number`                                          | `100`            | 화살표 키로 오갈 수 있는 이전 명령 수입니다.            |

응답은 `onSubmit`이 반환한 값에 따라 정해집니다.

- 문자열은 텍스트로 출력합니다.
- 그 밖의 값은 [타입에 맞게 표시하는 값](/ko/guide/values)으로 출력합니다.
- `undefined`는 아무것도 출력하지 않습니다. 응답이 나중에 오는 경우에 씁니다.
- 프로미스는 이행을 기다렸다가 그 값을 같은 방식으로 출력합니다.
- 함수가 던진 오류나 거부된 프로미스는 error 수준의 항목으로 출력합니다.

Enter는 명령을 제출하고, Shift+Enter는 줄을 추가합니다. 입력란은 여섯 줄까지 늘어납니다. 공백만 있는 명령은 무시합니다. 캐럿이 첫 줄이나 마지막 줄에 있을 때 ArrowUp과 ArrowDown으로 이전 명령을 오갑니다. 명령을 제출하면 따라가기가 켜집니다. IME 조합 중에 누른 Enter는 조합만 끝내고 명령을 제출하지 않습니다.

## 레이블과 로케일 {#labels-and-locale}

`locale: 'ko'`나 `'ko-KR'` 같은 언어 태그를 넘기면 도구 모음, 상태 표시줄, 접근성 이름이 한국어로 나옵니다. 그 밖의 언어는 영어 레이블을 씁니다. `locale`은 상태 표시줄의 숫자 서식에도 쓰입니다.

이미 만든 뷰어도 `setOptions({ locale })`로 내장 레이블의 언어를 바꿀 수 있습니다. `labels`로 넘긴 레이블은 새 내장 레이블 위에 그대로 남습니다. `setOptions`에 `labels`를 넘기면 앞서 넘긴 레이블을 대신하고, `labels: {}`를 넘기면 직접 지정한 레이블이 모두 사라집니다.

레이블은 `labels`로 바꿀 수 있습니다. `entries`는 보이는 항목 수, 전체 항목 수, 로케일에 맞게 숫자를 서식화하는 함수를 받는 함수입니다.

```ts
new LogViewer(container, {
	locale: 'ko',
	labels: {
		clear: '모두 지우기',
		entries: (shown, total, format) => (shown === total ? `항목 ${format(total)}개` : `항목 ${format(total)}개 중 ${format(shown)}개 표시`)
	}
});
```

레이블 목록은 [`ViewerLabels`](/ko/reference/log-viewer#viewerlabels)에 있습니다.

## 메서드와 이벤트 {#methods-and-events}

| 멤버                                                                       | 설명                                                                                       |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `console`                                                                  | 이 뷰어의 스토어에 쓰는, 콘솔 메서드를 갖춘 객체입니다.                                    |
| `write(text, options?)`                                                    | 텍스트를 항목 하나로 추가합니다.                                                           |
| `writeLines(text, options?)`                                               | 텍스트를 줄마다 항목 하나씩 추가합니다.                                                    |
| `hookConsole(target?, options?)`                                           | 콘솔을 스토어에 기록합니다. 기록을 멈추는 함수를 반환합니다.                               |
| `clear()`                                                                  | 항목을 모두 지웁니다.                                                                      |
| `setFilter(filter)`, `getFilter()`                                         | 필터를 정하거나 반환합니다.                                                                |
| `setFollowing(following)`                                                  | 따라가기를 켜거나 끕니다.                                                                  |
| `scrollToTop()`, `scrollToBottom()`, `scrollToEntry(id)`                   | 화면을 스크롤합니다.                                                                       |
| `getSelectionText()`, `selectAll()`, `clearSelection()`, `copySelection()` | 선택을 다룹니다.                                                                           |
| `focus()`                                                                  | 입력 줄에, 입력 줄이 없으면 로그 영역에 포커스를 줍니다.                                   |
| `refresh()`                                                                | CSS에서 테마와 글꼴을 다시 읽습니다.                                                       |
| `on(name, listener)`                                                       | `follow`, `filter`, `selection` 이벤트에 리스너를 답니다. 리스너를 떼는 함수를 반환합니다. |
| `setOptions(options)`                                                      | 넘긴 옵션만 바꾸고 나머지는 그대로 둡니다.                                                 |
| `dispose()`                                                                | 뷰어를 없애고 뷰어가 시작한 작업을 모두 멈춥니다.                                          |

정확한 시그니처는 [LogViewer 레퍼런스](/ko/reference/log-viewer)에 있습니다.

## 접근성 {#accessibility}

- 뷰어 전체는 `viewer` 레이블을 이름으로 쓰는 region 역할의 요소이고, 도구 모음은 이름이 붙은 버튼을 담은 toolbar 역할의 요소입니다. 따라가기 버튼과 줄 바꿈 버튼은 눌린 상태를 알립니다.
- 로그 영역은 키보드 포커스를 받을 수 있고, 다른 스크롤 영역처럼 화살표 키와 Page Up, Page Down으로 스크롤합니다.
- 화면에 보이지 않는 목록이 화면의 항목을 스크린 리더에 전달합니다. 경고와 오류는 `warn:`, `error:`로 시작합니다.
- 입력 줄은 이름이 붙은 `<textarea>`입니다.
