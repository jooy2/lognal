---
order: 5
description: lognal의 기본 팔레트를 전환하고, 테마를 직접 만들고, 한국어에 맞는 고정폭 글꼴을 고르는 방법을 설명합니다.
---

# 테마와 글꼴

## 테마 {#theme-modes}

`theme`에는 `'auto'`, lognal이 기본으로 제공하는 팔레트 이름, 직접 만든 이름을 넘길 수 있습니다. 기본 팔레트는 테마 메뉴에 나오는 순서대로 <Fw js="BUILT_IN_THEMES" flutter="builtInThemes" code />에 들어 있습니다.

| `theme`      | 색                                                          |
| ------------ | ----------------------------------------------------------- |
| `'auto'`     | 시스템 설정에 따라 `light`나 `dark`를 씁니다. 기본값입니다. |
| `'light'`    | 기본 밝은 팔레트입니다.                                     |
| `'paper'`    | 미색 배경의 따뜻한 밝은 팔레트입니다.                       |
| `'dark'`     | 기본 어두운 팔레트입니다.                                   |
| `'midnight'` | 짙은 남색 바탕에 차가운 색을 쓰는 어두운 팔레트입니다.      |
| `'ember'`    | 따뜻한 갈색 바탕에 호박색을 강조색으로 쓰는 팔레트입니다.   |
| `'moss'`     | 짙은 녹색 바탕의 어두운 팔레트입니다.                       |

```ts

::: fw js

const viewer = new LogViewer(container, { theme: 'auto' });
const darkModeSwitch = document.querySelector<HTMLInputElement>('#dark-mode')!;

darkModeSwitch.addEventListener('change', () => {
	viewer.setOptions({ theme: darkModeSwitch.checked ? 'midnight' : 'paper' });
});
```

도구 모음의 **테마** 버튼을 누르면 같은 테마가 메뉴로 나오고, 메뉴에서 고르는 것은 `setOptions({ theme })`를 호출하는 것과 같습니다. 메뉴에 어떤 테마를 넣을지는 `themes`로 정하고, 테마에 원하는 이름을 붙일 수도 있습니다.

```ts
new LogViewer(container, {
	theme: 'brand',
	themes: ['auto', 'light', 'dark', { name: 'brand', label: '우리 색' }]
});
```

`toolbar: { theme: false }`를 넘기면 버튼이 사라지고, 옵션은 코드에서 그대로 쓸 수 있습니다.

뷰어는 루트 요소인 `.lognal`의 `data-theme` 속성에 팔레트 이름을 쓰고, 스타일시트는 이 속성을 보고 색을 고릅니다. `'auto'`는 쓰기 전에 실제 팔레트로 바뀌므로, `data-theme`에는 항상 팔레트 이름이 들어갑니다.

:::

::: fw flutter

```dart
LogViewer(store: store, options: LogViewerOptions(theme: isDark ? 'midnight' : 'paper'));
```

도구 모음의 **테마** 버튼을 누르면 같은 테마가 메뉴로 나오고, 메뉴에서 고르면 컨트롤러에 그 테마가 설정됩니다. 사용자가 고른 테마는 그대로 유지되고, `options.theme`에 새 값이 들어올 때만 바뀝니다. 메뉴에 어떤 테마를 넣을지는 `themes`로 정하고, 테마에 원하는 이름을 붙일 수도 있습니다.

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(
    theme: 'brand',
    themes: <ThemeChoice>[
      ThemeChoice('auto'),
      ThemeChoice('light'),
      ThemeChoice('dark'),
      ThemeChoice('brand', label: '우리 색'),
    ],
  ),
);
```

`toolbar: ViewerToolbarOptions(theme: false)`를 넘기면 버튼이 사라지고, `controller.setTheme(name)`은 코드에서 그대로 쓸 수 있습니다.

:::

::: fw js

## 색이 캔버스에 전달되는 과정 {#how-colors-reach-the-canvas}

뷰어의 색과 크기는 모두 `.lognal`에 정의된 `--lognal-*` CSS 사용자 지정 속성입니다. 캔버스는 CSS를 직접 쓸 수 없으므로, 뷰어가 계산된 값을 읽어 렌더러에 넘깁니다. 값을 읽는 때는 뷰어를 만들 때, 테마가 바뀔 때, `'auto'` 모드에서 운영체제가 밝은 모드와 어두운 모드를 오갈 때입니다.

부모 요소의 클래스를 바꾸는 식으로 그 밖의 시점에 속성을 바꿨다면 `viewer.refresh()`를 호출하세요. 그래야 캔버스가 새 값을 반영합니다.

밝은 색은 `.lognal`에 직접 정의하고, 나머지 팔레트는 각자의 `data-theme` 아래에서 그 값을 덮어씁니다. 밝은 테마와 어두운 테마의 색을 모두 바꾸려면 두 곳을 덮어쓰세요.

```css
.build-log .lognal {
	--lognal-background: #fbfaf7;
	--lognal-accent: #7a3cff;
}

.build-log .lognal[data-theme='dark'] {
	--lognal-background: #0d1117;
	--lognal-accent: #b18cff;
}
```

`rgb()`, `hsl()`, `oklch()`를 비롯해 캔버스가 받는 색이면 무엇이든 쓸 수 있습니다.

### 직접 만드는 테마 {#a-theme-of-your-own}

테마는 CSS 블록 하나와 `theme`에 넘길 이름이 전부입니다. 따로 등록할 것은 없고, 뷰어는 기본 팔레트와 똑같이 계산된 스타일에서 색을 읽습니다.

```css
.lognal[data-theme='brand'] {
	--lognal-background: #101417;
	--lognal-foreground: #e6edf3;
	--lognal-accent: #ffb454;
	--lognal-ansi-2: #8ddb8c;
	--lognal-token-string: var(--lognal-ansi-2);

	color-scheme: dark;
}
```

`.lognal`의 밝은 팔레트와 다른 색만 지정하면 됩니다. 덮어쓰지 않은 색은 밝은 팔레트 값을 그대로 씁니다. `lognal.css`의 `paper`, `midnight`, `ember`, `moss`가 이 방식으로 쓰여 있으니 출발점으로 삼기 좋습니다. 각 팔레트는 바탕색과 강조색, ANSI 16색을 정하고, 토큰 색은 `var()`로 ANSI 색을 따라갑니다.

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

| 속성                             | 밝은 테마                                                             | 어두운 테마                                                    | 설명                                                                                                                                  |
| -------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `--lognal-border`                | `#e3e6eb`                                                             | `#2a2e37`                                                      | 뷰어, 입력란, 구분선의 테두리입니다.                                                                                                  |
| `--lognal-surface`               | `#f6f7f9`                                                             | `#1c1f25`                                                      | 도구 모음과 상태 표시줄의 배경입니다.                                                                                                 |
| `--lognal-control-hover`         | `rgba(29, 33, 41, 0.07)`                                              | `rgba(227, 229, 234, 0.08)`                                    | 포인터가 올라간 버튼입니다.                                                                                                           |
| `--lognal-control-active`        | `rgba(31, 111, 214, 0.12)`                                            | `rgba(90, 162, 255, 0.18)`                                     | 따라가기 버튼처럼 눌린 버튼입니다.                                                                                                    |
| `--lognal-focus-ring`            | `#1f6fd6`                                                             | `#5aa2ff`                                                      | 도구 모음 버튼, 수준 메뉴, **새 로그** 버튼, 항목 메뉴 버튼의 포커스 윤곽선이고, 항목 모드에서 키보드가 가리키는 항목의 윤곽선입니다. |
| `--lognal-scrollbar-thumb`       | `rgba(29, 33, 41, 0.28)`                                              | `rgba(227, 229, 234, 0.25)`                                    | 스크롤바 막대입니다.                                                                                                                  |
| `--lognal-scrollbar-thumb-hover` | `rgba(29, 33, 41, 0.45)`                                              | `rgba(227, 229, 234, 0.42)`                                    | 포인터가 올라간 스크롤바 막대입니다.                                                                                                  |
| `--lognal-popup-shadow`          | `0 8px 24px rgba(29, 33, 41, 0.14), 0 1px 3px rgba(29, 33, 41, 0.08)` | `0 8px 24px rgba(0, 0, 0, 0.45), 0 1px 3px rgba(0, 0, 0, 0.3)` | 수준 메뉴와 항목 메뉴의 그림자입니다.                                                                                                 |

:::

::: fw flutter

## 색이 캔버스에 전달되는 과정 {#how-colors-reach-the-canvas-flutter}

팔레트는 스타일시트가 아니라 값입니다. `LognalTheme`은 그런 값 두 개를 들고 있습니다.

- `renderer`, 즉 `RenderTheme`은 로그를 그리는 색입니다. 텍스트, 표시, 강조, ANSI 16색, 토큰 색이 들어 있습니다.
- `chrome`, 즉 `ChromeTheme`은 로그 주변을 그리는 색입니다. 도구 모음, 상태 표시줄, 스크롤바, 메뉴, 대화 상자가 여기에 해당합니다.

뷰어는 빌드할 때 이름을 이 값으로 바꾸고, 페인터는 그 값에서 색을 가져옵니다. 애플리케이션의 `Theme`은 일부러 읽지 않습니다. 밝은 애플리케이션 안의 어두운 로그는 어두운 로그처럼 보여야 하고, 그 위에 밝은 메뉴를 열어서는 안 되기 때문입니다.

### 직접 만드는 테마 {#a-theme-of-your-own-flutter}

팔레트는 대개 배경, 글자 색, 강조색, 16색 램프이고 나머지는 거기서 따라옵니다. `buildTheme`이 그 규칙을 그대로 옮긴 것이고, `paper`, `midnight`, `ember`, `moss`도 이렇게 만들었습니다.

```dart
final LognalTheme brand = buildTheme(
  name: 'brand',
  brightness: Brightness.dark,
  background: const Color(0xff101417),
  foreground: const Color(0xffe6edf3),
  muted: const Color(0xff8b949e),
  accent: const Color(0xffffb454),
  border: const Color(0xff222a31),
  surface: const Color(0xff161b21),
  selection: const Color(0x47ffb454),
  entrySelection: const Color(0x1fffb454),
  controlActive: const Color(0x33ffb454),
  ansi: <Color>[/* 16색 */],
);

LogViewer(
  store: store,
  options: LogViewerOptions(
    theme: 'brand',
    themeResolver: (String name) => name == 'brand' ? brand : null,
    themes: const <ThemeChoice>[
      ThemeChoice('auto'),
      ThemeChoice('brand', label: '우리 색'),
    ],
  ),
);
```

`themeResolver`는 `auto`가 아닌 모든 이름에 대해 질문을 받고, 모르는 이름에는 `null`을 돌려줍니다. 그러면 플랫폼의 밝은 팔레트나 어두운 팔레트로 물러섭니다. 이 규칙을 따르지 않는 팔레트라면 `RenderTheme`과 `ChromeTheme`을 직접 만들어 `LognalTheme`에 담으세요.

## 색 {#the-colors}

### 크롬 {#the-chrome}

`ChromeTheme`이 들고 있는 값입니다.

| 필드                  | 밝은 팔레트  | 어두운 팔레트 | 설명                                      |
| --------------------- | ------------ | ------------- | ----------------------------------------- |
| `background`          | `0xffffffff` | `0xff16181d`  | 뷰어 뒤의 색입니다.                       |
| `foreground`          | `0xff1d2129` | `0xffe3e5ea`  | 크롬의 일반 텍스트입니다.                 |
| `muted`               | `0xff646a78` | `0xff8f94a1`  | 눌리지 않은 버튼과 보조 텍스트입니다.     |
| `accent`              | `0xff1f6fd6` | `0xff5aa2ff`  | 강조색입니다.                             |
| `border`              | `0xffe3e6eb` | `0xff2a2e37`  | 뷰어와 입력란의 테두리, 구분선입니다.     |
| `surface`             | `0xfff6f7f9` | `0xff1c1f25`  | 도구 모음과 상태 표시줄의 배경입니다.     |
| `controlHover`        | `0x121d2129` | `0x14e3e5ea`  | 포인터가 올라간 버튼입니다.               |
| `controlActive`       | `0x1f1f6fd6` | `0x2e5aa2ff`  | 따라가기처럼 눌려 있는 버튼입니다.        |
| `focusRing`           | `0xff1f6fd6` | `0xff5aa2ff`  | 키보드가 놓인 컨트롤 둘레의 테두리입니다. |
| `onAccent`            | `0xffffffff` | `0xff0b1220`  | `accent` 위의 글자 색입니다.              |
| `scrollbarThumb`      | `0x471d2129` | `0x40e3e5ea`  | 스크롤바 손잡이입니다.                    |
| `scrollbarThumbHover` | `0x731d2129` | `0x6be3e5ea`  | 포인터가 올라간 손잡이입니다.             |
| `shadow`              | `0x241d2129` | `0x73000000`  | 메뉴나 대화 상자 아래의 그림자입니다.     |

:::

### 로그 색 {#log-colors}

<Fw js="캔버스는 이 색으로 그립니다. `background`, `foreground`, `muted`, `accent`는 도구 모음, 입력 줄, 상태 표시줄의 색도 정합니다." flutter="`RenderTheme`이 들고 있는 값이고, 캔버스는 이 색으로 그립니다." />

::: fw js

캔버스가 이 색으로 그립니다. `background`, `foreground`, `muted`, `accent`는 도구 모음, 입력 줄, 상태 표시줄에도 쓰입니다.

| 속성                        | 밝은 테마                  | 어두운 테마                 | 설명                                                                     |
| --------------------------- | -------------------------- | --------------------------- | ------------------------------------------------------------------------ |
| `--lognal-background`       | `#ffffff`                  | `#16181d`                   | 로그와 입력 줄의 배경입니다.                                             |
| `--lognal-foreground`       | `#1d2129`                  | `#e3e5ea`                   | 일반 텍스트입니다.                                                       |
| `--lognal-muted`            | `#646a78`                  | `#8f94a1`                   | 타임스탬프, 알림, 펼침 삼각형, 응답 표시입니다.                          |
| `--lognal-accent`           | `#1f6fd6`                  | `#5aa2ff`                   | 입력 표시, 프롬프트, 눌린 버튼, **새 로그** 버튼입니다.                  |
| `--lognal-selection`        | `rgba(31, 111, 214, 0.22)` | `rgba(90, 162, 255, 0.3)`   | 선택한 텍스트입니다.                                                     |
| `--lognal-match`            | `rgba(240, 173, 0, 0.3)`   | `rgba(252, 191, 50, 0.3)`   | 필터와 일치한 부분입니다.                                                |
| `--lognal-separator`        | `rgba(29, 33, 41, 0.06)`   | `rgba(227, 229, 234, 0.05)` | 항목 사이의 선입니다.                                                    |
| `--lognal-hover`            | `rgba(29, 33, 41, 0.04)`   | `rgba(227, 229, 234, 0.06)` | 포인터가 올라간 항목의 행 배경입니다. `transparent`로 지정하면 꺼집니다. |
| `--lognal-search-match`     | `rgba(255, 200, 0, 0.4)`   | `rgba(255, 200, 0, 0.28)`   | 검색 결과입니다.                                                         |
| `--lognal-search-current`   | `rgba(255, 140, 0, 0.7)`   | `rgba(255, 140, 0, 0.6)`    | 현재 검색 결과입니다.                                                    |
| `--lognal-link`             | `#1f6fd6`                  | `#5aa2ff`                   | 링크의 텍스트와 밑줄입니다.                                              |
| `--lognal-entry-selection`  | `rgba(31, 111, 214, 0.1)`  | `rgba(90, 162, 255, 0.14)`  | 항목 모드에서 선택한 항목의 행 배경입니다.                               |
| `--lognal-error`            | `#c4262c`                  | `#ff8a8d`                   | 오류 텍스트, 표시, 반복 배지입니다.                                      |
| `--lognal-error-background` | `rgba(222, 53, 58, 0.07)`  | `rgba(252, 79, 83, 0.1)`    | 오류 행의 배경입니다.                                                    |
| `--lognal-warn`             | `#8a5a00`                  | `#fcc549`                   | 경고 텍스트, 표시, 반복 배지입니다.                                      |
| `--lognal-warn-background`  | `rgba(240, 173, 0, 0.1)`   | `rgba(252, 191, 50, 0.08)`  | 경고 행의 배경입니다.                                                    |
| `--lognal-info`             | `#1f6fd6`                  | `#5aa2ff`                   | info 항목의 표시입니다.                                                  |
| `--lognal-debug`            | `#646a78`                  | `#8f94a1`                   | debug 항목의 텍스트입니다.                                               |

:::

::: fw flutter

| 필드              | 밝은 팔레트  | 어두운 팔레트 | 설명                                            |
| ----------------- | ------------ | ------------- | ----------------------------------------------- |
| `background`      | `0xffffffff` | `0xff16181d`  | 로그의 배경입니다.                              |
| `foreground`      | `0xff1d2129` | `0xffe3e5ea`  | 일반 텍스트입니다.                              |
| `muted`           | `0xff646a78` | `0xff8f94a1`  | 타임스탬프, 알림, 펼침 삼각형, 출력 표시입니다. |
| `accent`          | `0xff1f6fd6` | `0xff5aa2ff`  | 입력 표시와 **새 로그** 버튼입니다.             |
| `selection`       | `0x381f6fd6` | `0x4d5aa2ff`  | 선택한 텍스트입니다.                            |
| `match`           | `0x4df0ad00` | `0x4dfcbf32`  | 필터에 걸린 부분입니다.                         |
| `separator`       | `0x0f1d2129` | `0x0de3e5ea`  | 항목 사이의 선입니다.                           |
| `hover`           | `0x0a1d2129` | `0x0fe3e5ea`  | 포인터가 올라간 항목의 행입니다.                |
| `searchMatch`     | `0x66ffc800` | `0x47ffc800`  | 검색에 걸린 모든 부분입니다.                    |
| `searchCurrent`   | `0xb2ff8c00` | `0x99ff8c00`  | 검색의 현재 결과입니다.                         |
| `link`            | `0xff1f6fd6` | `0xff5aa2ff`  | 링크의 글자와 밑줄입니다.                       |
| `entrySelection`  | `0x1a1f6fd6` | `0x245aa2ff`  | 항목 모드에서 선택한 항목의 행입니다.           |
| `focusRing`       | `0xff1f6fd6` | `0xff5aa2ff`  | 키보드가 놓인 항목의 테두리입니다.              |
| `error`           | `0xffc4262c` | `0xffff8a8d`  | 오류의 글자, 표시, 반복 배지입니다.             |
| `errorBackground` | `0x12de353a` | `0x1afc4f53`  | 오류 행의 배경입니다.                           |
| `warn`            | `0xff8a5a00` | `0xfffcc549`  | 경고의 글자, 표시, 반복 배지입니다.             |
| `warnBackground`  | `0x1af0ad00` | `0x14fcbf32`  | 경고 행의 배경입니다.                           |
| `info`            | `0xff1f6fd6` | `0xff5aa2ff`  | 정보 항목의 표시입니다.                         |
| `debug`           | `0xff646a78` | `0xff8f94a1`  | 디버그 항목의 글자입니다.                       |

:::

### 값 색 {#value-colors}

::: fw js

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

:::

::: fw flutter

값과 스타일이 입혀진 텍스트는 토큰 색을 씁니다. `RenderTheme`의 `tokens` 맵이고 키는 `StyleToken`입니다. `StyleToken.warn`, `info`, `accent`, `attribute`는 `write`와 `writeLines`의 `token` 옵션이 가리키는 이름이기도 합니다. 색 값은 JavaScript 패키지의 표와 같습니다.

:::

### ANSI 색 {#ansi-colors}

<Fw js="--lognal-ansi-0부터 --lognal-ansi-15까지" flutter="RenderTheme.ansi의 16색" />는 ANSI 이스케이프 코드 30~~37번과 90~~97번이 고르는 색입니다. 검정, 빨강, 초록, 노랑, 파랑, 자홍, 청록, 흰색 순서이고, 그다음에 각각의 밝은 색이 옵니다.

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

::: fw js

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

뷰어는 목록에서 브라우저가 쓸 수 있는 첫 번째 글꼴로 칸 너비를 잽니다. 그 글꼴에 없는 글자는 브라우저가 대체 글꼴로 그립니다.

:::

::: fw flutter

`FontSettings` 하나가 전부입니다.

```dart
LogViewer(
  store: store,
  options: const LogViewerOptions(
    font: FontSettings(
      family: 'JetBrainsMono',
      fallbackFamilies: <String>['D2Coding', 'Noto Sans Mono CJK KR'],
      size: 14,
      lineHeight: 1.5,
    ),
  ),
);
```

`family`를 비워 두면 뷰어가 플랫폼의 고정폭 글꼴(Menlo, Consolas, `monospace`)을 이름으로 지정하고, 그 뒤로 한국어와 일본어 고정폭 글꼴을 대체 글꼴로 둡니다. 웹만 빼면 어디서든 이게 맞는 답입니다.

### 웹에서 {#on-the-web}

Flutter는 애플리케이션이 번들한 글꼴로 그리고 시스템 글꼴에는 접근하지 못합니다. 그래서 웹 빌드에서 `monospace`라고 적으면 가변폭 글꼴이 잡히고 격자가 맞지 않습니다. 고정폭 글꼴을 싣고 이름을 알려 주세요.

```yaml
flutter:
  fonts:
    - family: JetBrainsMono
      fonts:
        - asset: fonts/JetBrainsMono-Regular.ttf
```

```dart
const FontSettings(family: 'JetBrainsMono');
```

`packages/flutter/example`의 갤러리가 바로 이렇게 하고 있으며, 어떤 글꼴을 왜 썼는지는 그 안의 `fonts/README.md`에 적어 두었습니다.

번들한 글꼴에 없는 글자는 엔진이 따로 글꼴을 받아 옵니다. 글꼴이 도착하면 뷰어가 다시 재고 다시 그리므로, 한글과 이모지는 네모로 남지 않고 잠시 뒤에 나타납니다.

:::

lognal은 ASCII가 아닌 텍스트를 글자마다 격자 위치에 맞춰 따로 그리므로, 대체 글꼴의 글리프 때문에 줄의 나머지가 밀리지 않습니다. 칸보다 넓은 글리프는 칸에 맞게 좁히고, 두 칸보다 좁은 전각 글리프는 두 칸의 가운데에 놓습니다.

### 한국어에 맞는 글꼴 {#fonts-for-korean-text}

라틴 문자용 고정폭 글꼴은 대부분 한글이 없고, 대체 글꼴의 한글 글리프는 두 칸보다 좁을 때가 많아 음절 사이가 벌어집니다. 한국어가 섞인 로그에는 한글을 라틴 문자의 정확히 두 배 너비로 그린 고정폭 글꼴을 쓰세요. [D2Coding](https://github.com/naver/d2codingfont), 나눔고딕코딩, Noto Sans Mono CJK KR이 그런 글꼴입니다. 이런 글꼴을 쓰면 음절이 두 칸을 빈틈 없이 채웁니다.

::: fw js

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

:::

::: fw flutter

```yaml
flutter:
  fonts:
    - family: D2Coding
      fonts:
        - asset: fonts/D2Coding.ttf
```

```dart
const FontSettings(family: 'D2Coding');
```

:::
