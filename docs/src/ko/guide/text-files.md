---
order: 3
description: readTextFile로 로그 파일을 lognal에 읽어 들이고, UTF-8이나 EUC-KR 같은 레거시 인코딩을 알아내고, followTextFile로 늘어나는 파일을 따라 읽고, ANSI 색이 들어간 텍스트를 쓰는 방법을 설명합니다.
---

# 텍스트 파일

## 파일 읽기 {#read-a-file}

`readTextFile`은 `<input type="file">`로 고르거나 페이지에 끌어다 놓은 파일 같은 `Blob`을 읽고, 줄마다 항목을 하나씩 추가합니다.

```ts
import { LogViewer, readTextFile } from 'lognal';

const viewer = new LogViewer(container, {
	core: { maxEntries: 200000, mergeRepeats: false }
});
const picker = document.querySelector<HTMLInputElement>('#log-file')!;

picker.addEventListener('change', async () => {
	const file = picker.files?.[0];

	if (!file) {
		return;
	}

	const result = await readTextFile(file, viewer.store);

	viewer.console.info(`Read ${result.lines} lines from ${file.name} as ${result.encoding}`);
});
```

파일은 256KiB씩 나눠 읽으므로, 큰 파일이라도 문자열 하나로 메모리에 올릴 필요가 없습니다. 줄은 `\n`, `\r\n`, 단독 `\r`에서 끝나고, 파일 끝의 줄 바꿈은 빈 줄을 만들지 않습니다.

파일을 읽을 때는 스토어 옵션 두 가지가 중요합니다.

- `maxEntries`는 보관할 줄 수를 정합니다. 기본값은 10,000이고, 넘으면 가장 오래된 줄부터 버립니다. 모든 줄을 보관하려면 `Infinity`를 씁니다.
- `mergeRepeats`가 기본으로 켜져 있어서, 똑같은 줄이 이어지면 반복 횟수가 붙은 항목 하나로 합칩니다. 줄마다 항목을 따로 두려면 끄세요.

### 옵션 {#options}

| 옵션               | 타입                                      | 기본값                        | 설명                                                                                            |
| ------------------ | ----------------------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------- |
| `encoding`         | `string`                                  | `'auto'`                      | `'utf-8'`, `'euc-kr'` 같은 인코딩입니다. `'auto'`이면 자동으로 알아냅니다.                      |
| `fallbackEncoding` | `string`                                  | 브라우저 언어의 레거시 인코딩 | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                                            |
| `level`            | `LogLevel`                                | `'log'`                       | 모든 줄의 수준입니다.                                                                           |
| `ansi`             | `boolean`                                 | `true`                        | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다. `false`이면 이스케이프 문자가 `^[`로 보입니다. |
| `chunkSize`        | `number`                                  | `262144`                      | 한 번에 읽는 바이트 수입니다.                                                                   |
| `signal`           | `AbortSignal`                             | 없음                          | 중단 신호가 오면 읽기를 멈춥니다. 그때까지 읽은 줄은 스토어에 남습니다.                         |
| `onProgress`       | `(loaded: number, total: number) => void` | 없음                          | 조각을 읽을 때마다 지금까지 읽은 바이트 수와 파일 크기를 넘겨 호출합니다.                       |

반환하는 프로미스는 `{ lines, bytes, encoding }`으로 이행합니다. 각각 추가한 줄 수, 읽은 바이트 수, 사용한 인코딩입니다. 중단 신호로 멈춰도 프로미스는 거부되지 않고, 멈춘 시점까지의 값으로 이행합니다.

## 인코딩 {#encodings}

`encoding: 'auto'`이면 lognal은 다음 순서로 인코딩을 고릅니다.

1. 파일 앞의 BOM이 가리키는 UTF-8, UTF-16LE, UTF-16BE.
1. 파일의 처음 64KiB가 올바른 UTF-8이면 UTF-8.
1. `fallbackEncoding`.

기본 대체 인코딩은 사용자 언어로 된 페이지에 브라우저가 가정하는 인코딩입니다. `navigator.language`와 HTML Standard의 기본 인코딩 추천 표를 따릅니다.

| 언어                                              | 대체 인코딩    |
| ------------------------------------------------- | -------------- |
| 한국어(`ko`)                                      | `euc-kr`       |
| 일본어(`ja`)                                      | `shift_jis`    |
| 번체 중국어(`zh-TW`, `zh-HK`, `zh-MO`, `zh-Hant`) | `big5`         |
| 그 밖의 중국어(`zh`)                              | `gbk`          |
| 러시아어, 우크라이나어 등 키릴 문자를 쓰는 언어   | `windows-1251` |
| 표에 없는 모든 언어                               | `windows-1252` |

표에는 중앙유럽 언어, 그리스어, 발트어, 아랍어, 히브리어, 튀르키예어, 태국어, 베트남어도 들어 있습니다. 언어 태그에 맞는 대체 인코딩은 `legacyEncodingFor(locale)`로 얻습니다.

한국어판 Windows의 오래된 프로그램이 저장한 파일은 대개 EUC-KR입니다. 브라우저 언어와 상관없이 이런 파일을 읽어야 한다면 대체 인코딩을 직접 지정하세요.

```ts
await readTextFile(file, viewer.store, { fallbackEncoding: 'euc-kr' });
```

인코딩 이름은 `TextDecoder`에 그대로 넘기므로, `TextDecoder`가 받는 이름은 모두 쓸 수 있습니다. 모르는 이름을 넘기면 `readTextFile`은 `RangeError`로 거부됩니다. 이미 읽어 둔 바이트의 인코딩을 알아내려면 `detectEncoding(bytes, fallback)`을 호출합니다.

## 늘어나는 파일 따라 읽기 {#follow-a-growing-file}

`followTextFile`은 `tail -f`처럼 파일을 읽은 뒤 새로 덧붙는 줄을 계속 추가합니다.

```js
import { followTextFile } from 'lognal';

button.addEventListener('click', async () => {
	const [handle] = await window.showOpenFilePicker();
	const follow = followTextFile(handle, viewer.store, {
		interval: 1000,
		onError: (error) => viewer.console.warn('Could not read the file', error)
	});

	try {
		const lines = await follow.ready;

		viewer.console.info(`Read ${lines} lines, now following`);
	} catch (error) {
		viewer.console.error('Could not read the file', error);
	}
});
```

File System Access API의 파일 핸들이 필요하며, 이 API는 Chromium 계열 브라우저의 보안 페이지에서만 쓸 수 있습니다. 파일 선택 창은 클릭 같은 사용자 동작 안에서 열어야 합니다. `<input type="file">`로 고른 파일은 그 순간의 사본이라 따라 읽을 수 없으니 `readTextFile`로 한 번 읽으세요.

| 옵션               | 타입                       | 기본값                        | 설명                                                                |
| ------------------ | -------------------------- | ----------------------------- | ------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                        | 새 데이터를 확인하는 간격이며, 단위는 밀리초입니다.                 |
| `encoding`         | `string`                   | `'auto'`                      | 인코딩입니다. `'auto'`이면 처음 읽은 내용으로 알아냅니다.           |
| `fallbackEncoding` | `string`                   | 브라우저 언어의 레거시 인코딩 | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                |
| `level`            | `LogLevel`                 | `'log'`                       | 모든 줄의 수준입니다.                                               |
| `ansi`             | `boolean`                  | `true`                        | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                    |
| `onReset`          | `() => void`               | 없음                          | 파일이 교체되거나 잘려서 처음부터 다시 읽을 때 호출합니다.          |
| `onError`          | `(error: unknown) => void` | 없음                          | 첫 번째 이후의 확인이 권한 취소 같은 이유로 실패했을 때 호출합니다. |

`followTextFile`은 핸들을 바로 반환합니다.

- `ready`는 첫 읽기가 끝나면 그때 추가한 줄 수로 이행하는 프로미스입니다. 권한 오류처럼 첫 읽기가 실패하면 `ready`는 그 오류로 거부되고, 이 실패에는 `onError`를 호출하지 않습니다. 예제처럼 거부를 처리하세요.
- `stop()`은 파일 확인을 멈춥니다. 이때 디코더에 남은 내용과 끝나지 않은 마지막 줄이 있으면 기록합니다.

확인할 때마다 핸들에서 파일의 새 사본을 받아 마지막으로 읽은 위치 뒤의 바이트를 읽습니다. 줄 바꿈으로 끝나지 않은 줄은 다음 확인까지 기다립니다. 확인이 실패해도, 첫 읽기가 실패한 경우에도 확인은 계속합니다.

파일이 마지막으로 읽은 위치보다 짧아졌거나, 크기는 그대로인데 `lastModified` 시각이 바뀌었으면 lognal은 파일이 교체된 것으로 봅니다. 그러면 디코더에 남은 내용과 끝나지 않은 줄을 기록하고, 처음부터 다시 읽고, `onReset`을 호출합니다. 크기를 바꾸지 않고 저장하거나 수정 시각만 바꾼 경우도 교체로 봅니다. 이미 읽은 부분보다 큰 파일로 교체되면 내용이 덧붙은 것과 구별되지 않아 알아채지 못합니다.

## ANSI 색이 들어간 텍스트 쓰기 {#write-text-with-ansi-colors}

`viewer.write`와 `viewer.writeLines`는 텍스트를 바로 추가합니다. `write`는 항목 하나를 추가하고 줄 바꿈을 그 안에 그대로 두며, `writeLines`는 줄마다 항목을 하나씩 추가합니다. 파일 읽기 함수와 달리 `ansi: true`를 넘기지 않으면 ANSI 이스케이프 코드를 해석하지 않습니다.

```ts
viewer.writeLines('\x1b[32m✔\x1b[0m build finished in \x1b[1m1.2s\x1b[0m', { ansi: true });
viewer.write('Deploy started', { level: 'info' });
```

터미널이 줄에서 줄로 스타일을 이어 가듯, 출력 한 조각의 스타일이 다음 조각까지 이어질 수 있습니다. 여러 번 호출해도 스타일을 유지하려면 같은 `AnsiParser`를 계속 넘기세요.

```ts
import { AnsiParser } from 'lognal';

const parser = new AnsiParser();
const socket = new WebSocket('wss://example.com/build-log');

socket.addEventListener('message', (event) => {
	viewer.writeLines(String(event.data), { ansi: parser });
});
```

`writeLines`는 호출이 끝나는 곳을 줄의 끝으로 봅니다. 조각이 줄 중간에서 끊길 수 있다면 `TextLineWriter`로 쓰세요. 끝나지 않은 줄은 줄 바꿈이 올 때까지 붙잡아 두고, `ansi: false`를 넘기지 않는 한 ANSI 코드를 해석합니다.

```ts
import { TextLineWriter } from 'lognal';

const writer = new TextLineWriter(viewer.store);

socket.addEventListener('message', (event) => writer.write(String(event.data)));
socket.addEventListener('close', () => writer.flush());
```

파서는 SGR 코드를 스타일로 바꾸고, 커서 이동이나 OSC 하이퍼링크 같은 다른 이스케이프 시퀀스는 모두 지웁니다. 그래서 알 수 없는 문자가 화면에 끼어들지 않습니다.

| 코드                       | 스타일                                        |
| -------------------------- | --------------------------------------------- |
| `0`                        | 모든 스타일을 초기화합니다.                   |
| `1`, `2`, `3`, `4`, `9`    | 굵게, 흐리게, 기울임, 밑줄, 취소선.           |
| `22`, `23`, `24`, `29`     | 굵게와 흐리게, 기울임, 밑줄, 취소선을 끕니다. |
| `30`~~`37`, `90`~~`97`     | 테마의 16색 가운데 글자 색.                   |
| `40`~~`47`, `100`~~`107`   | 테마의 16색 가운데 배경색.                    |
| `38;5;n`, `48;5;n`         | 256색 팔레트의 글자 색이나 배경색.            |
| `38;2;r;g;b`, `48;2;r;g;b` | RGB로 지정한 글자 색이나 배경색.              |
| `39`, `49`                 | 기본 글자 색이나 기본 배경색.                 |

0~~15번 색은 테마의 `--lognal-ansi-*` 속성에서, 16~~231번은 6×6×6 색 큐브에서, 232~255번은 회색 단계에서 가져옵니다. 반전 같은 다른 코드는 무시합니다. 문자열에서 이스케이프 시퀀스를 모두 지우려면 `stripAnsi(text)`를 씁니다.

`write`와 `writeLines`는 `level`, `kind`, `time`, `groups`, `token`, `style`도 받습니다. [`WriteOptions`](/ko/reference/log-store#writeoptions)를 참고하세요.
