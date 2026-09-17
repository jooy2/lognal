---
order: 3
description: 로그 파일을 lognal에 읽어 들이고, UTF-8이나 EUC-KR 같은 레거시 인코딩을 알아내고, 늘어나는 파일을 따라 읽고, ANSI 색이 들어간 텍스트를 쓰는 방법을 설명합니다.
---

# 텍스트 파일

## 파일 읽기 {#read-a-file}

::: fw js

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

파일은 256KiB씩 나눠 읽으므로, 큰 파일이라도 문자열 하나로 메모리에 올릴 필요가 없습니다.

:::

::: fw flutter

`readTextStream`은 바이트 조각 스트림을 읽고 줄마다 항목을 하나씩 추가합니다. 메모리에 올라가는 것은 지금 디코딩하는 조각과 만들고 있는 줄뿐이므로, 메모리보다 큰 파일도 문제없이 읽습니다.

```dart
import 'package:lognal/lognal.dart';

final ReadTextResult result = await readTextStream(
  localTextFile('/var/log/app.log').openRead(),
  store,
);

log.info('Read %d lines as %s', <Object?>[result.lines, result.decoded]);
```

`localTextFile(path)`는 파일 시스템이 있는 플랫폼에서 파일을 엽니다. 웹에는 파일 시스템이 없으므로, 브라우저가 페이지에 넘긴 바이트를 `readTextBytes`에 넘깁니다.

```dart
final XFile? picked = await openFile();

if (picked != null) {
  await readTextBytes(await picked.readAsBytes(), store);
}
```

파일을 고르는 일은 애플리케이션의 몫입니다. 사용자가 고른 파일을 읽으려면 플러그인이 필요하고, 어떤 플러그인을 쓸지는 링크를 여는 것과 마찬가지로 애플리케이션이 정합니다.

:::

줄은 `\n`, `\r\n`, 단독 `\r`에서 끝나고, 파일 끝의 줄 바꿈은 빈 줄을 만들지 않습니다.

파일을 읽을 때는 스토어 옵션 두 가지가 중요합니다.

- `maxEntries`는 보관할 줄 수를 정합니다. 기본값은 10,000이고, 넘으면 가장 오래된 줄부터 버립니다.
- `mergeRepeats`가 기본으로 켜져 있어서, 똑같은 줄이 이어지면 반복 횟수가 붙은 항목 하나로 합칩니다. 줄마다 항목을 따로 두려면 끄세요.

### 옵션 {#options}

::: fw js

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

:::

::: fw flutter

| 옵션               | 타입                                    | 기본값                   | 설명                                                                                            |
| ------------------ | --------------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------- |
| `encoding`         | `String`                                | `'auto'`                 | `'utf-8'` 같은 인코딩입니다. `'auto'`이면 자동으로 알아냅니다.                                  |
| `fallbackEncoding` | `String?`                               | `locale`의 레거시 인코딩 | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                                            |
| `level`            | `LogLevel`                              | `LogLevel.log`           | 모든 줄의 수준입니다.                                                                           |
| `ansi`             | `bool`                                  | `true`                   | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다. `false`이면 이스케이프 문자가 `^[`로 보입니다. |
| `onProgress`       | `void Function(int loaded, int? total)` | 없음                     | 조각을 읽을 때마다 지금까지 읽은 바이트 수와, 크기를 아는 경우 전체 크기를 넘겨 호출합니다.     |

퓨처는 `ReadTextResult`로 완료합니다. `lines`, `bytes`, 파일이 어떤 인코딩으로 간주됐는지를 담은 `encoding`, 실제로 어떤 인코딩으로 디코딩했는지를 담은 `decoded`가 들어 있습니다. 파일이 알린 인코딩을 아무것도 디코딩하지 못한 경우를 사용자에게 알리려면 이 둘을 비교하세요.

:::

## 인코딩 {#encodings}

`encoding: 'auto'`이면 lognal은 다음 순서로 인코딩을 고릅니다.

1. 파일 앞의 BOM이 가리키는 UTF-8, UTF-16LE, UTF-16BE.
1. 파일의 처음 64KiB가 올바른 UTF-8이면 UTF-8.
1. `fallbackEncoding`.

기본 대체 인코딩은 HTML 표준의 기본 인코딩 표를 따라, 읽는 사람의 언어에서 시스템이 가정하는 인코딩입니다.

| 언어                                              | 대체 인코딩    |
| ------------------------------------------------- | -------------- |
| 한국어(`ko`)                                      | `euc-kr`       |
| 일본어(`ja`)                                      | `shift_jis`    |
| 번체 중국어(`zh-TW`, `zh-HK`, `zh-MO`, `zh-Hant`) | `big5`         |
| 그 밖의 중국어(`zh`)                              | `gbk`          |
| 러시아어, 우크라이나어 등 키릴 문자 언어          | `windows-1251` |
| 표에 없는 모든 언어                               | `windows-1252` |

표에는 중부 유럽, 그리스, 발트, 아랍, 히브리, 터키, 타이, 베트남 언어도 들어 있습니다. `legacyEncodingFor(locale)`은 어떤 언어 태그에 대해서든 대체 인코딩을 돌려주고, `detectEncoding(bytes, fallback)`은 이미 가진 바이트의 인코딩을 알려 줍니다.

::: fw js

예전 한국어 Windows 프로그램이 저장한 파일은 대개 EUC-KR입니다. 브라우저 언어와 상관없이 그런 파일을 읽어야 한다면 대체 인코딩을 직접 지정하세요.

```ts
await readTextFile(file, viewer.store, { fallbackEncoding: 'euc-kr' });
```

인코딩 이름은 `TextDecoder`에 그대로 넘기므로, `TextDecoder`가 받는 이름은 모두 쓸 수 있습니다. 모르는 이름을 넘기면 `readTextFile`이 `RangeError`로 거부합니다.

:::

::: fw flutter

### 이 패키지가 디코딩하는 것 {#what-this-package-decodes}

UTF-8, 두 바이트 순서의 UTF-16, Latin-1, Windows-1252는 여기서 디코딩합니다. `euc-kr`, `shift_jis`, `big5`, `gbk` 같은 레거시 CJK 인코딩은 각각 수만 자 규모의 표가 필요합니다. 브라우저에는 이미 있고 Dart에는 없으므로, 표 네 개를 싣는 대신 여러분에게서 하나를 받습니다.

```dart
final void Function() remove = registerTextDecoder((String encoding) {
  return encoding == 'euc-kr' ? MyEucKrSink() : null;
});
```

등록한 팩토리는 리더가 만나는 모든 인코딩에 대해 나중에 등록한 것부터 질문을 받고, 처리하지 않는 인코딩에는 `null`을 돌려줍니다. 그래서 내장 디코더를 대체할 수도 있습니다. 어떤 이름을 아는지는 `decoderFor(name)`이 답합니다.

알아낸 인코딩의 디코더가 없으면 읽기는 Windows-1252로 물러서고 `result.decoded`에 그 사실을 남깁니다. 레거시 파일이 실패하는 대신 깨진 글자로 읽히는 이유입니다. 무슨 일이 있었는지 사용자에게 알려 주세요.

```dart
if (result.encoding != result.decoded) {
  log.warn('%s could not be decoded, so it was read as %s', <Object?>[
    result.encoding,
    result.decoded,
  ]);
}
```

:::

## 늘어나는 파일 따라 읽기 {#follow-a-growing-file}

`followTextFile`은 파일을 읽고 그 뒤에 덧붙는 줄을 계속 추가합니다. `tail -f`와 같습니다.

::: fw js

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

File System Access API의 파일 핸들이 필요하며, 이 API는 보안 페이지의 Chromium 계열 브라우저에서만 제공합니다. 파일 선택 창은 클릭 같은 사용자 동작에서 열어야 합니다. `<input type="file">`로 고른 파일은 스냅숏이라 따라 읽을 수 없으니 `readTextFile`로 한 번만 읽으세요.

| 옵션               | 타입                       | 기본값                        | 설명                                                                            |
| ------------------ | -------------------------- | ----------------------------- | ------------------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                        | 새 데이터를 확인하는 간격(밀리초)입니다.                                        |
| `encoding`         | `string`                   | `'auto'`                      | 인코딩입니다. `'auto'`이면 처음 읽을 때 알아냅니다.                             |
| `fallbackEncoding` | `string`                   | 브라우저 언어의 레거시 인코딩 | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                            |
| `level`            | `LogLevel`                 | `'log'`                       | 모든 줄의 수준입니다.                                                           |
| `ansi`             | `boolean`                  | `true`                        | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                                |
| `onReset`          | `() => void`               | 없음                          | 파일이 교체, 회전, 잘림으로 처음부터 다시 읽힐 때 호출합니다.                   |
| `onError`          | `(error: unknown) => void` | 없음                          | 첫 번째 이후의 확인이 실패할 때 호출합니다. 권한이 회수된 경우 등이 해당합니다. |

:::

::: fw flutter

```dart
final FollowHandle follow = followTextFile(
  localTextFile('/var/log/app.log'),
  store,
  options: FollowTextOptions(
    interval: const Duration(seconds: 1),
    onError: (Object error) => log.warn('Could not read the file', <Object?>[error]),
  ),
);

try {
  final int lines = await follow.ready;

  log.info('Read %d lines, now following', <Object?>[lines]);
} catch (error) {
  log.error(error);
}
```

경로가 아니라 `TextFileSource`를 받습니다. 파일 시스템이 없는 웹에서도 패키지가 컴파일되게 하기 위해서입니다. `localTextFile`이 그중 하나이고, 그 밖의 것은 `CallbackTextFile`로 감쌉니다.

```dart
final TextFileSource source = CallbackTextFile(
  length: () async => bytes.length,
  read: (int start) => Stream<List<int>>.value(bytes.sublist(start)),
  lastModified: () async => modified,
);
```

| 옵션               | 타입                    | 기본값                   | 설명                                                                            |
| ------------------ | ----------------------- | ------------------------ | ------------------------------------------------------------------------------- |
| `interval`         | `Duration`              | `Duration(seconds: 1)`   | 새 데이터를 확인하는 간격입니다.                                                |
| `encoding`         | `String`                | `'auto'`                 | 인코딩입니다. `'auto'`이면 처음 읽을 때 알아냅니다.                             |
| `fallbackEncoding` | `String?`               | `locale`의 레거시 인코딩 | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                            |
| `level`            | `LogLevel`              | `LogLevel.log`           | 모든 줄의 수준입니다.                                                           |
| `ansi`             | `bool`                  | `true`                   | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                                |
| `onReset`          | `void Function()`       | 없음                     | 파일이 교체, 회전, 잘림으로 처음부터 다시 읽힐 때 호출합니다.                   |
| `onError`          | `void Function(Object)` | 없음                     | 첫 번째 이후의 확인이 실패할 때 호출합니다. 파일이 사라진 경우 등이 해당합니다. |

:::

`followTextFile`은 곧바로 핸들을 돌려줍니다.

- `ready`는 첫 읽기가 끝나면 추가한 줄 수로 <Fw js="이행하는 프로미스입니다" flutter="완료하는 퓨처입니다" />. 첫 읽기가 실패하면 대신 그 오류로 <Fw js="거부되고" flutter="완료되고" />, 그 오류로는 `onError`를 호출하지 않습니다. 예제처럼 처리하세요.
- `stop()`은 확인을 멈춥니다. 디코더가 들고 있던 것과 끝나지 않은 마지막 줄이 있으면 함께 씁니다.

확인할 때마다 소스에 크기를 묻고 마지막 위치 뒤의 바이트를 읽습니다. 줄 바꿈으로 끝나지 않은 줄은 다음 확인까지 기다립니다. 확인이 실패해도, 첫 읽기가 실패해도 확인은 계속합니다.

파일이 마지막 위치보다 짧아졌거나, 크기는 같은데 수정 시각이 달라졌으면 교체된 것으로 봅니다. 이때는 디코더가 들고 있던 것과 끝나지 않은 줄을 쓰고, 처음부터 다시 읽고, `onReset`을 호출합니다. 크기를 바꾸지 않고 저장하거나 타임스탬프만 건드려도 교체로 봅니다. 이미 읽은 부분보다 큰 교체는 덧붙은 데이터처럼 보이므로 알아내지 못합니다.

## ANSI 색이 들어간 텍스트 쓰기 {#write-text-with-ansi-colors}

<Fw js="viewer.write와 viewer.writeLines" flutter="store.write와 store.writeLines" />는 텍스트를 바로 추가합니다. `write`는 항목 하나를 만들고 줄 바꿈을 그 안에 두며, `writeLines`는 줄마다 항목을 하나씩 만듭니다. 파일 리더와 달리 따로 요청하지 않으면 ANSI 이스케이프 코드를 그대로 둡니다.

::: fw js

```ts
viewer.writeLines('\x1b[32m✔\x1b[0m build finished in \x1b[1m1.2s\x1b[0m', { ansi: true });
viewer.write('Deploy started', { level: 'info' });
```

터미널이 줄을 넘어가도 스타일을 유지하듯, 스타일은 출력 조각을 넘어 이어질 수 있습니다. 호출을 넘어 유지하려면 같은 `AnsiParser`를 매번 넘기세요.

```ts
import { AnsiParser } from 'lognal';

const parser = new AnsiParser();
const socket = new WebSocket('wss://example.com/build-log');

socket.addEventListener('message', (event) => {
	viewer.writeLines(String(event.data), { ansi: parser });
});
```

:::

::: fw flutter

```dart
store
  ..writeLines(
    '\x1b[32m✔\x1b[0m build finished in \x1b[1m1.2s\x1b[0m',
    const WriteOptions(ansi: true),
  )
  ..write('Deploy started', const WriteOptions(level: LogLevel.info));
```

터미널이 줄을 넘어가도 스타일을 유지하듯, 스타일은 출력 조각을 넘어 이어질 수 있습니다. 호출을 넘어 유지하려면 같은 `AnsiParser`를 매번 넘기세요.

```dart
final AnsiParser parser = AnsiParser();

socket.stream.listen((Object? message) {
  store.writeLines('$message', WriteOptions(parser: parser));
});
```

:::

`writeLines`는 호출이 끝나는 지점을 줄의 끝으로 봅니다. 조각이 줄 중간에서 끊길 수 있다면 `TextLineWriter`로 쓰세요. 줄 바꿈이 올 때까지 끝나지 않은 줄을 들고 있고, 끄지 않는 한 ANSI 코드도 해석합니다.

::: fw js

```ts
import { TextLineWriter } from 'lognal';

const writer = new TextLineWriter(viewer.store);

socket.addEventListener('message', (event) => writer.write(String(event.data)));
socket.addEventListener('close', () => writer.flush());
```

:::

::: fw flutter

```dart
final TextLineWriter writer = TextLineWriter(store);

socket.stream.listen(
  (Object? message) => writer.write('$message'),
  onDone: writer.flush,
);
```

:::

파서는 SGR 코드를 스타일로 바꾸고, 커서 이동이나 OSC 하이퍼링크 래퍼 같은 다른 이스케이프 시퀀스는 모두 없앱니다. 그래야 이상한 문자로 남지 않습니다.

| 코드                       | 스타일                                          |
| -------------------------- | ----------------------------------------------- |
| `0`                        | 모든 스타일을 초기화합니다.                     |
| `1`, `2`, `3`, `4`, `9`    | 굵게, 흐리게, 기울임, 밑줄, 취소선.             |
| `22`, `23`, `24`, `29`     | 굵게와 흐리게, 기울임, 밑줄, 취소선을 끕니다.   |
| `30`~~`37`, `90`~~`97`     | 테마의 16색 중에서 글자 색을 고릅니다.          |
| `40`~~`47`, `100`~~`107`   | 테마의 16색 중에서 배경색을 고릅니다.           |
| `38;5;n`, `48;5;n`         | 256색 팔레트에서 글자 색이나 배경색을 고릅니다. |
| `38;2;r;g;b`, `48;2;r;g;b` | RGB로 글자 색이나 배경색을 지정합니다.          |
| `39`, `49`                 | 기본 글자 색이나 배경색으로 돌아갑니다.         |

0~~15번 색은 테마가 가진 16색에서, 16~~231번은 6 × 6 × 6 색 큐브에서, 232~255번은 회색 계단에서 가져옵니다. 반전 같은 다른 코드는 무시합니다. `stripAnsi(text)`는 문자열에서 이스케이프 시퀀스를 모두 없앱니다.

`write`와 `writeLines`는 `level`, `kind`, `time`, `groups`, `token`, `style`도 받습니다. [`WriteOptions`](/ko/reference/log-store#writeoptions)를 참고하세요.
