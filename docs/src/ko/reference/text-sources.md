---
order: 4
description: lognal의 텍스트 소스와 텍스트 유틸리티인 readTextFile, followTextFile, TextLineWriter, detectEncoding, legacyEncodingFor, AnsiParser, LineSplitter, 폭 계산 함수의 레퍼런스입니다.
---

# 텍스트 소스

예제는 가이드의 [텍스트 파일](/ko/guide/text-files)에 있습니다.

## readTextFile {#readtextfile}

```ts
readTextFile(file: Blob, store: LogStore, options?: ReadTextOptions): Promise<ReadTextResult>
```

`<input type="file">`로 고르거나 페이지에 끌어다 놓은 텍스트 파일을 읽고, 줄마다 항목을 하나씩 추가합니다. 파일을 조각으로 나눠 읽으므로 큰 파일을 문자열 하나로 메모리에 올릴 필요가 없습니다. 보관하는 줄 수는 여전히 스토어의 `maxEntries`가 정합니다.

### ReadTextOptions {#readtextoptions}

| 옵션               | 타입                                      | 기본값                                  | 설명                                                                                              |
| ------------------ | ----------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `encoding`         | `string`                                  | `'auto'`                                | 파일의 인코딩입니다. `'auto'`는 BOM을 읽고, UTF-8을 시도한 뒤, `fallbackEncoding`으로 넘어갑니다. |
| `fallbackEncoding` | `string`                                  | `legacyEncodingFor(navigator.language)` | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                                              |
| `level`            | `LogLevel`                                | `'log'`                                 | 모든 줄의 수준입니다.                                                                             |
| `ansi`             | `boolean`                                 | `true`                                  | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                                                  |
| `chunkSize`        | `number`                                  | `262144`                                | 한 번에 읽는 바이트 수입니다.                                                                     |
| `signal`           | `AbortSignal`                             | 없음                                    | 중단 신호가 오면 읽기를 멈춥니다. 그때까지 읽은 줄은 스토어에 남습니다.                           |
| `onProgress`       | `(loaded: number, total: number) => void` | 없음                                    | 조각을 읽을 때마다 지금까지 읽은 바이트 수와 전체 크기를 넘겨 호출합니다.                         |

### ReadTextResult {#readtextresult}

| 필드       | 타입     | 설명                  |
| ---------- | -------- | --------------------- |
| `lines`    | `number` | 추가한 줄 수입니다.   |
| `bytes`    | `number` | 읽은 바이트 수입니다. |
| `encoding` | `string` | 사용한 인코딩입니다.  |

## followTextFile {#followtextfile}

```ts
followTextFile(handle: FileHandleLike, store: LogStore, options?: FollowTextOptions): FollowHandle
```

`tail -f`처럼 파일을 읽은 뒤 새로 덧붙는 줄을 계속 추가합니다. 확인할 때마다 핸들에서 파일의 새 사본을 받아 지난번 이후에 추가된 부분을 읽습니다. Chromium 계열 브라우저에만 있는 File System Access API의 핸들이 필요합니다.

파일이 짧아졌거나, 크기는 그대로인데 `lastModified` 시각이 바뀌었으면 내용이 덧붙은 것이 아니라 파일이 교체된 것으로 봅니다. 이때는 처음부터 다시 읽고 `onReset`을 호출합니다.

### FileHandleLike {#filehandlelike}

```ts
interface FileHandleLike {
	getFile(): Promise<Blob & { lastModified?: number }>;
}
```

파일을 따라 읽는 데 필요한 `FileSystemFileHandle`의 일부입니다. `getFile` 메서드만 있으면 어떤 객체든 쓸 수 있어서 테스트할 때 편합니다.

### FollowTextOptions {#followtextoptions}

| 옵션               | 타입                       | 기본값                                  | 설명                                                                |
| ------------------ | -------------------------- | --------------------------------------- | ------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                                  | 새 데이터를 확인하는 간격이며, 단위는 밀리초입니다.                 |
| `encoding`         | `string`                   | `'auto'`                                | 인코딩입니다. `'auto'`이면 처음 읽은 바이트로 알아냅니다.           |
| `fallbackEncoding` | `string`                   | `legacyEncodingFor(navigator.language)` | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                |
| `level`            | `LogLevel`                 | `'log'`                                 | 모든 줄의 수준입니다.                                               |
| `ansi`             | `boolean`                  | `true`                                  | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                    |
| `onReset`          | `() => void`               | 없음                                    | 파일이 교체되어 처음부터 다시 읽을 때 호출합니다.                   |
| `onError`          | `(error: unknown) => void` | 없음                                    | 첫 번째 이후의 확인이 권한 취소 같은 이유로 실패했을 때 호출합니다. |

### FollowHandle {#followhandle}

| 멤버    | 타입              | 설명                                                                                                                                                            |
| ------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ready` | `Promise<number>` | 첫 읽기가 끝나면 그때 추가한 줄 수로 이행하고, 첫 읽기가 실패하면 그 오류로 거부됩니다. 이 실패에는 `onError`를 호출하지 않으며, 어느 쪽이든 확인은 계속합니다. |
| `stop`  | `() => void`      | 파일 확인을 멈추고, 디코더에 남은 내용과 끝나지 않은 마지막 줄을 기록합니다.                                                                                    |

## TextLineWriter {#textlinewriter}

```ts
new TextLineWriter(store: LogStore, options?: { level?: LogLevel; ansi?: boolean })
```

디코딩한 텍스트를 한 줄씩 스토어 항목으로 바꾸고, 조각 사이에서 끝나지 않은 줄과 ANSI 스타일을 이어 갑니다. `readTextFile`과 `followTextFile`이 이 클래스를 씁니다. `ansi`는 `false`를 넘기지 않으면 `true`이고, `level`의 기본값은 `'log'`입니다.

| 멤버                  | 타입      | 설명                                                      |
| --------------------- | --------- | --------------------------------------------------------- |
| `write(text: string)` | `void`    | 텍스트 조각을 추가하고, 그 조각으로 끝난 줄을 기록합니다. |
| `flush()`             | `void`    | 끝나지 않은 마지막 줄이 있으면 기록합니다.                |
| `lines`               | `number`  | 기록한 줄 수입니다.                                       |
| `hasPending`          | `boolean` | 줄 바꿈을 기다리는 끝나지 않은 줄이 있는지 나타냅니다.    |

## 인코딩 {#encodings}

### detectEncoding {#detectencoding}

```ts
detectEncoding(bytes: Uint8Array, fallback: string): string
```

파일 앞부분의 바이트로 인코딩을 고릅니다. BOM이 있으면 그에 맞는 `'utf-8'`, `'utf-16le'`, `'utf-16be'` 가운데 하나를, 없으면 올바른 UTF-8일 때 `'utf-8'`을, 그 밖에는 `fallback`을 반환합니다. `bytes` 끝에서 잘린 멀티바이트 시퀀스는 올바른 것으로 봅니다.

### legacyEncodingFor {#legacyencodingfor}

```ts
legacyEncodingFor(locale: string | undefined): string
```

HTML Standard의 기본 인코딩 추천 표를 따라, 그 언어의 페이지에 브라우저가 가정하는 레거시 인코딩을 반환합니다. 예를 들어 `'ko-KR'`이면 `'euc-kr'`입니다. 표에 없는 언어와 `undefined`에는 `'windows-1252'`를 반환합니다.

```ts
import { detectEncoding, legacyEncodingFor } from 'lognal';

// `file`은 <input type="file">에서 얻은 File 같은 Blob입니다.
const head = new Uint8Array(await file.slice(0, 65536).arrayBuffer());
const encoding = detectEncoding(head, legacyEncodingFor('ko-KR'));
// 'utf-8' 또는 'euc-kr'
```

## ANSI 이스케이프 코드 {#ansi-escape-codes}

### AnsiParser {#ansiparser}

```ts
new AnsiParser();
```

ANSI 이스케이프 코드가 들어간 텍스트를 스타일이 붙은 파트로 바꿉니다. SGR 코드는 스타일로 바꾸고 다른 이스케이프 시퀀스는 모두 지웁니다. 터미널이 줄에서 줄로 스타일을 이어 가듯, 스타일은 호출이 바뀌어도 이어집니다.

| 메서드                | 반환값       | 설명                                           |
| --------------------- | ------------ | ---------------------------------------------- |
| `parse(text: string)` | `TextPart[]` | 텍스트 한 조각을 해석합니다. 보통 한 줄입니다. |
| `reset()`             | `void`       | 현재 스타일을 잊습니다.                        |

```ts
import { AnsiParser } from 'lognal';

new AnsiParser().parse('\x1b[1;31mfailed\x1b[0m after 3 tries');
// [{ type: 'text', text: 'failed', style: { bold: true, color: 1 } },
//  { type: 'text', text: ' after 3 tries' }]
```

### stripAnsi {#stripansi}

```ts
stripAnsi(text: string): string
```

텍스트에서 ANSI 이스케이프 시퀀스를 모두 지웁니다.

## 줄 {#lines}

### LineSplitter {#linesplitter}

```ts
new LineSplitter();
```

이어서 들어오는 텍스트 조각을 줄로 나눕니다. 줄은 `\n`, `\r\n`, 단독 `\r`에서 끝나고, 두 조각에 걸쳐 나뉜 `\r\n`도 줄 바꿈 하나로 셉니다.

| 멤버                  | 타입       | 설명                                                         |
| --------------------- | ---------- | ------------------------------------------------------------ |
| `push(chunk: string)` | `string[]` | 조각을 추가하고, 그 조각으로 끝난 줄을 반환합니다.           |
| `flush()`             | `string[]` | 끝나지 않은 마지막 줄이 있으면 반환하고 상태를 초기화합니다. |
| `hasPending`          | `boolean`  | 줄 바꿈을 기다리는 텍스트가 있는지 나타냅니다.               |

### splitLines {#splitlines}

```ts
splitLines(text: string): string[]
```

문자열 전체를 줄로 나눕니다. 끝에 있는 줄 바꿈은 빈 줄을 만들지 않습니다.

## 텍스트 폭 {#text-width}

뷰어와 같은 규칙으로 텍스트를 잽니다. [격자 위의 폭](/ko/guide/cjk#width-on-the-grid)을 참고하세요.

| 함수                                                                             | 반환값     | 설명                                                                                                                |
| -------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------- |
| `measureCells(text: string, ambiguousWidth?: AmbiguousWidth)`                    | `number`   | 문자열이 한 행에서 차지하는 칸 수입니다.                                                                            |
| `truncateCells(text: string, maxCells: number, ambiguousWidth?: AmbiguousWidth)` | `string`   | 문자열을 `maxCells`칸 이하로 자르고, 잘린 부분이 있으면 `…`로 끝냅니다. 한도를 넘는 전각 문자는 쪼개지 않고 뺍니다. |
| `clusterWidth(cluster: string, ambiguousWidth?: AmbiguousWidth)`                 | `number`   | 그래핌 클러스터 하나가 차지하는 칸 수입니다.                                                                        |
| `codePointWidth(codePoint: number, ambiguousWidth?: AmbiguousWidth)`             | `number`   | 코드 포인트 하나가 차지하는 칸 수로, 0, 1, 2 가운데 하나입니다. 제어 문자는 1입니다.                                |
| `splitGraphemes(text: string)`                                                   | `string[]` | 현재 분할 함수로 텍스트를 그래핌 클러스터로 나눕니다.                                                               |
| `setGraphemeSplitter(splitter: GraphemeSplitter \| null)`                        | `void`     | 그래핌 분할 함수를 바꿉니다. `null`을 넘기면 `Intl.Segmenter`가 있을 때 그것을 쓰는 기본 함수로 돌아갑니다.         |

`ambiguousWidth`의 기본값은 `1`입니다. `UNICODE_VERSION`은 폭 데이터의 출처인 Unicode 버전으로, 값은 `'17.0.0'`입니다.

```ts
type AmbiguousWidth = 1 | 2;
type GraphemeSplitter = (text: string) => string[];
```
