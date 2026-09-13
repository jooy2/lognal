---
order: 5
description: lognal의 밝은 테마, 어두운 테마, 자동 모드를 전환하고, --lognal-* CSS 사용자 지정 속성으로 모양을 바꾸고, 한국어에 맞는 고정폭 글꼴을 고르는 방법을 설명합니다.
---

# 테마와 글꼴

## 테마 모드 {#theme-modes}

| `theme`   | 색                                                                                   |
| --------- | ------------------------------------------------------------------------------------ |
| `'auto'`  | `prefers-color-scheme`를 따르고, 운영체제 설정이 바뀌면 함께 바뀝니다. 기본값입니다. |
| `'light'` | 항상 밝은 테마입니다.                                                                |
| `'dark'`  | 항상 어두운 테마입니다.                                                              |

```ts
const viewer = new LogViewer(container, { theme: 'auto' });
const darkModeSwitch = document.querySelector<HTMLInputElement>('#dark-mode')!;

darkModeSwitch.addEventListener('change', () => {
	viewer.setOptions({ theme: darkModeSwitch.checked ? 'dark' : 'light' });
});
```

뷰어는 루트 요소인 `.lognal`의 `data-theme` 속성에 모드를 쓰고, 스타일시트는 이 속성을 보고 색을 고릅니다.

## 색이 캔버스에 전달되는 과정 {#how-colors-reach-the-canvas}

뷰어의 색과 크기는 모두 `.lognal`에 정의된 `--lognal-*` CSS 사용자 지정 속성입니다. 캔버스는 CSS를 직접 쓸 수 없으므로, 뷰어가 계산된 값을 읽어 렌더러에 넘깁니다. 값을 읽는 때는 뷰어를 만들 때, 테마가 바뀔 때, `'auto'` 모드에서 운영체제가 밝은 모드와 어두운 모드를 오갈 때입니다.

부모 요소의 클래스를 바꾸는 식으로 그 밖의 시점에 속성을 바꿨다면 `viewer.refresh()`를 호출하세요. 그래야 캔버스가 새 값을 반영합니다.

어두운 색은 `.lognal[data-theme='dark']`에 한 번, `prefers-color-scheme: dark` 미디어 쿼리 안의 `.lognal[data-theme='auto']`에 한 번 더 정의되어 있습니다. 두 테마의 색을 모두 바꾸려면 세 곳을 모두 덮어써야 합니다.

```css
.build-log .lognal {
	--lognal-background: #fbfaf7;
	--lognal-accent: #7a3cff;
}

.build-log .lognal[data-theme='dark'] {
	--lognal-background: #0d1117;
	--lognal-accent: #b18cff;
}

@media (prefers-color-scheme: dark) {
	.build-log .lognal[data-theme='auto'] {
		--lognal-background: #0d1117;
		--lognal-accent: #b18cff;
	}
}
```

`rgb()`, `hsl()`, `oklch()`를 비롯해 캔버스가 받는 색이면 무엇이든 쓸 수 있습니다.

## 사용자 지정 속성 {#custom-properties}

### 텍스트 격자 {#text-grid}

로그와 입력 줄의 글꼴을 정합니다. 로그에는 `font` 옵션이 이 속성보다 우선하고, 입력 줄에는 항상 이 속성을 씁니다.

| 속성                   | 기본값                                                                                                                        | 설명                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `--lognal-font-family` | `ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'D2Coding', 'Noto Sans Mono CJK KR', 'Liberation Mono', monospace` | 고정폭 글꼴 목록입니다.                                                                            |
| `--lognal-font-size`   | `13px`                                                                                                                        | 글꼴 크기입니다. `px`, `rem`, `em` 단위로 씁니다.                                                  |
| `--lognal-font-weight` | `400`                                                                                                                         | 일반 텍스트의 굵기입니다. 굵은 텍스트는 `700` 이상으로 그립니다.                                   |
| `--lognal-line-height` | `1.6`                                                                                                                         | 행 높이입니다. 글꼴 크기의 배수(숫자나 `em`), 백분율, `px`·`rem` 단위의 길이 가운데 하나로 씁니다. |

뷰어는 캔버스에 쓰려고 두 값을 픽셀로 바꿉니다.

- `1.6`처럼 단위가 없거나 `1.6em`처럼 `em` 단위인 줄 높이는 글꼴 크기의 배수입니다. `150%` 같은 백분율은 `1.5`가 되고, `20px` 같은 길이는 글꼴 크기로 나눕니다.
- 글꼴 크기를 `rem`으로 쓰면 루트 요소의 글꼴 크기를, `em`으로 쓰면 `.lognal` 요소의 글꼴 크기를 기준으로 계산합니다. 스타일시트는 `.lognal`의 글꼴 크기를 `--lognal-ui-font-size`로 정합니다.
- `calc()` 식처럼 뷰어가 읽지 못하는 값은 기본값으로 대신합니다.

입력 줄도 같은 속성을 CSS로 읽으므로 로그와 입력 줄의 행 높이가 같습니다.

뷰어는 루트 요소에 `--lognal-cell-height`도 설정합니다. 값은 한 행의 높이를 픽셀로 나타낸 것입니다. 설정값이 아니라 뷰어가 내놓는 값이므로 직접 만든 CSS에서 읽어 쓸 수 있습니다.

### 도구 모음과 상태 표시줄 {#toolbar-and-status-bar}

뷰어에서 일반 HTML로 된 부분의 모양을 정합니다.

| 속성                        | 기본값                                                                                     | 설명                                       |
| --------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------ |
| `--lognal-ui-font-family`   | `system-ui, -apple-system, 'Segoe UI', 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif` | 도구 모음과 상태 표시줄의 글꼴입니다.      |
| `--lognal-ui-font-size`     | `12px`                                                                                     | 도구 모음과 상태 표시줄의 글꼴 크기입니다. |
| `--lognal-radius`           | `10px`                                                                                     | 뷰어 모서리의 반경입니다.                  |
| `--lognal-control-radius`   | `6px`                                                                                      | 버튼과 입력란 모서리의 반경입니다.         |
| `--lognal-toolbar-height`   | `40px`                                                                                     | 도구 모음의 최소 높이입니다.               |
| `--lognal-statusbar-height` | `26px`                                                                                     | 상태 표시줄의 최소 높이입니다.             |

| 속성                             | 밝은 테마                  | 어두운 테마                 | 설명                                  |
| -------------------------------- | -------------------------- | --------------------------- | ------------------------------------- |
| `--lognal-border`                | `#e3e6eb`                  | `#2a2e37`                   | 뷰어, 입력란, 구분선의 테두리입니다.  |
| `--lognal-surface`               | `#f6f7f9`                  | `#1c1f25`                   | 도구 모음과 상태 표시줄의 배경입니다. |
| `--lognal-control-hover`         | `rgba(29, 33, 41, 0.07)`   | `rgba(227, 229, 234, 0.08)` | 포인터가 올라간 버튼입니다.           |
| `--lognal-control-active`        | `rgba(31, 111, 214, 0.12)` | `rgba(90, 162, 255, 0.18)`  | 따라가기 버튼처럼 눌린 버튼입니다.    |
| `--lognal-focus-ring`            | `#1f6fd6`                  | `#5aa2ff`                   | 포커스 윤곽선입니다.                  |
| `--lognal-scrollbar-thumb`       | `rgba(29, 33, 41, 0.28)`   | `rgba(227, 229, 234, 0.25)` | 스크롤바 막대입니다.                  |
| `--lognal-scrollbar-thumb-hover` | `rgba(29, 33, 41, 0.45)`   | `rgba(227, 229, 234, 0.42)` | 포인터가 올라간 스크롤바 막대입니다.  |

### 로그 색 {#log-colors}

캔버스가 이 색으로 그립니다. `background`, `foreground`, `muted`, `accent`는 도구 모음, 입력 줄, 상태 표시줄에도 쓰입니다.

| 속성                        | 밝은 테마                  | 어두운 테마                 | 설명                                                    |
| --------------------------- | -------------------------- | --------------------------- | ------------------------------------------------------- |
| `--lognal-background`       | `#ffffff`                  | `#16181d`                   | 로그와 입력 줄의 배경입니다.                            |
| `--lognal-foreground`       | `#1d2129`                  | `#e3e5ea`                   | 일반 텍스트입니다.                                      |
| `--lognal-muted`            | `#646a78`                  | `#8f94a1`                   | 타임스탬프, 알림, 펼침 삼각형, 응답 표시입니다.         |
| `--lognal-accent`           | `#1f6fd6`                  | `#5aa2ff`                   | 입력 표시, 프롬프트, 눌린 버튼, **새 로그** 버튼입니다. |
| `--lognal-selection`        | `rgba(31, 111, 214, 0.22)` | `rgba(90, 162, 255, 0.3)`   | 선택한 텍스트입니다.                                    |
| `--lognal-match`            | `rgba(240, 173, 0, 0.3)`   | `rgba(252, 191, 50, 0.3)`   | 필터와 일치한 부분입니다.                               |
| `--lognal-separator`        | `rgba(29, 33, 41, 0.06)`   | `rgba(227, 229, 234, 0.05)` | 항목 사이의 선입니다.                                   |
| `--lognal-error`            | `#c4262c`                  | `#ff8a8d`                   | 오류 텍스트, 표시, 반복 배지입니다.                     |
| `--lognal-error-background` | `rgba(222, 53, 58, 0.07)`  | `rgba(252, 79, 83, 0.1)`    | 오류 행의 배경입니다.                                   |
| `--lognal-warn`             | `#8a5a00`                  | `#fcc549`                   | 경고 텍스트, 표시, 반복 배지입니다.                     |
| `--lognal-warn-background`  | `rgba(240, 173, 0, 0.1)`   | `rgba(252, 191, 50, 0.08)`  | 경고 행의 배경입니다.                                   |
| `--lognal-info`             | `#1f6fd6`                  | `#5aa2ff`                   | info 항목의 표시입니다.                                 |
| `--lognal-debug`            | `#646a78`                  | `#8f94a1`                   | debug 항목의 텍스트입니다.                              |

### 값 색 {#value-colors}

값과 스타일이 들어간 텍스트는 이 토큰 색을 씁니다. 앞의 열두 개는 내장된 값 서식이 쓰고, `warn`, `info`, `accent`, `attribute`는 `write`와 `writeLines`의 `token` 옵션으로 쓸 수 있습니다.

| 속성                       | 밝은 테마 | 어두운 테마 | 쓰이는 곳                                        |
| -------------------------- | --------- | ----------- | ------------------------------------------------ |
| `--lognal-token-string`    | `#1f7a47` | `#7fd6a4`   | 문자열                                           |
| `--lognal-token-number`    | `#6f42c1` | `#b9a8ff`   | 숫자와 bigint                                    |
| `--lognal-token-boolean`   | `#6f42c1` | `#b9a8ff`   | `true`와 `false`                                 |
| `--lognal-token-null`      | `#646a78` | `#8f94a1`   | `null`과 `undefined`                             |
| `--lognal-token-key`       | `#1a5fb4` | `#82bdff`   | 속성 이름과 배열 인덱스                          |
| `--lognal-token-symbol`    | `#a3316f` | `#f5a3d7`   | 심벌과 심벌 키                                   |
| `--lognal-token-function`  | `#1a5fb4` | `#82bdff`   | 함수 이름 앞의 `ƒ`와 `class`                     |
| `--lognal-token-regexp`    | `#b1361e` | `#ffa585`   | 정규 표현식                                      |
| `--lognal-token-date`      | `#1f7a47` | `#7fd6a4`   | 날짜                                             |
| `--lognal-token-tag`       | `#1a5fb4` | `#82bdff`   | DOM 요소                                         |
| `--lognal-token-error`     | `#c4262c` | `#ff8a8d`   | 오류 제목                                        |
| `--lognal-token-muted`     | `#646a78` | `#8f94a1`   | 스택 트레이스, `… more` 행, 접근자, `[Circular]` |
| `--lognal-token-warn`      | `#8a5a00` | `#fcc549`   | `warn` 토큰                                      |
| `--lognal-token-info`      | `#1f6fd6` | `#5aa2ff`   | `info` 토큰                                      |
| `--lognal-token-accent`    | `#1f6fd6` | `#5aa2ff`   | `accent` 토큰                                    |
| `--lognal-token-attribute` | `#8a5a00` | `#fcc549`   | `attribute` 토큰                                 |

### ANSI 색 {#ansi-colors}

`--lognal-ansi-0`부터 `--lognal-ansi-15`까지는 ANSI 이스케이프 코드 30~~37, 90~~97이 고르는 16색입니다. 검정, 빨강, 초록, 노랑, 파랑, 자홍, 청록, 흰색 순서이고 그 뒤로 각 색의 밝은 버전이 이어집니다.

| 번호 | 밝은 테마 | 어두운 테마 | 번호 | 밝은 테마 | 어두운 테마 |
| ---- | --------- | ----------- | ---- | --------- | ----------- |
| 0    | `#1d2129` | `#3b3f4a`   | 8    | `#4b515e` | `#6b7080`   |
| 1    | `#c4262c` | `#fc5c60`   | 9    | `#de353a` | `#ff8a8d`   |
| 2    | `#1f7a47` | `#43d786`   | 10   | `#238b50` | `#7ee3a8`   |
| 3    | `#8a5a00` | `#fcbf32`   | 11   | `#9c6a00` | `#ffd466`   |
| 4    | `#1f6fd6` | `#5aa2ff`   | 12   | `#2f7fe6` | `#82bdff`   |
| 5    | `#8f3aa8` | `#c792ea`   | 13   | `#a34bbd` | `#ddb6f2`   |
| 6    | `#0e7c86` | `#56d4dd`   | 14   | `#10909b` | `#8ae6ec`   |
| 7    | `#646a78` | `#d0d3db`   | 15   | `#1d2129` | `#ffffff`   |

## 글꼴 {#fonts}

로그는 칸으로 된 격자에 배치합니다. 반각 문자는 한 칸, 한글 음절 같은 전각 문자는 두 칸을 차지합니다. 이 격자에 맞는 글꼴은 고정폭 글꼴뿐입니다. 가변폭 글꼴도 그려지기는 하지만 글자가 칸과 어긋나서 선택 영역과 강조가 엉뚱한 곳에 표시됩니다.

글꼴은 CSS나 `font` 옵션으로 정합니다. 로그에는 옵션이 우선하지만, CSS는 입력 줄의 모양도 함께 정하므로 대개 CSS에서 정하는 편이 낫습니다.

```css
.lognal {
	--lognal-font-family: 'JetBrains Mono', D2Coding, monospace;
	--lognal-font-size: 14px;
	--lognal-line-height: 1.5;
}
```

```ts
new LogViewer(container, {
	font: { family: "'JetBrains Mono', D2Coding, monospace", size: 14, lineHeight: 1.5 }
});
```

뷰어는 목록에서 브라우저가 쓸 수 있는 첫 번째 글꼴로 칸 너비를 잽니다. 그 글꼴에 없는 글자는 브라우저가 대체 글꼴로 그립니다. lognal은 ASCII가 아닌 텍스트를 글자마다 격자 위치에 맞춰 따로 그리므로, 대체 글꼴의 글리프 때문에 줄의 나머지가 밀리지 않습니다. 칸보다 넓은 글리프는 칸에 맞게 좁히고, 두 칸보다 좁은 전각 글리프는 두 칸의 가운데에 놓습니다.

### 한국어에 맞는 글꼴 {#fonts-for-korean-text}

라틴 문자용 고정폭 글꼴은 대부분 한글이 없고, 대체 글꼴의 한글 글리프는 두 칸보다 좁을 때가 많아 음절 사이가 벌어집니다. 한국어가 섞인 로그에는 한글을 라틴 문자의 정확히 두 배 너비로 그린 고정폭 글꼴을 쓰세요. [D2Coding](https://github.com/naver/d2codingfont)이나 Noto Sans Mono CJK KR이 그런 글꼴입니다. 이런 글꼴을 쓰면 음절이 두 칸을 빈틈 없이 채웁니다.

```css
@font-face {
	font-family: 'D2Coding';
	src: url('/fonts/D2Coding.woff2') format('woff2');
	font-display: swap;
}

.lognal {
	--lognal-font-family: 'D2Coding', monospace;
}
```

### 웹 글꼴 {#web-fonts}

뷰어는 `document.fonts.ready`가 이행될 때, 그리고 화면에 있는 글자를 담은 웹 글꼴을 다 불러왔을 때 글꼴을 다시 잽니다. 뷰어를 만든 뒤에 CSS에서 글꼴 속성을 바꿨다면 `viewer.refresh()`를 호출하세요.
