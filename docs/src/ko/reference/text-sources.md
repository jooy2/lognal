---
order: 4
description: 텍스트 소스와 텍스트 유틸리티인 파일 읽기와 따라 읽기, 인코딩, AnsiParser, 줄 분할, 폭 계산 함수의 레퍼런스입니다.
---

# 텍스트 소스

예제는 가이드의 [텍스트 파일](/ko/guide/text-files)에 있습니다.

::: fw js

## readTextFile {#readtextfile}

```ts
readTextFile(file: Blob, store: LogStore, options?: ReadTextOptions): Promise<ReadTextResult>
```

`<input type="file">`로 고르거나 페이지에 끌어다 놓은 텍스트 파일을 읽고, 줄마다 항목을 하나씩 추가합니다. 파일을 조각으로 나눠 읽으므로 큰 파일을 문자열 하나로 메모리에 올릴 필요가 없습니다. 보관하는 줄 수는 여전히 스토어의 `maxEntries`가 정합니다.

:::

::: fw flutter

## readTextStream과 readTextBytes {#read-text}

```dart
Future<ReadTextResult> readTextStream(
  Stream<List<int>> chunks,
  LogStore store, {
  ReadTextOptions options = const ReadTextOptions(),
  int? totalBytes,
  String? locale,
})

Future<ReadTextResult> readTextBytes(
  List<int> bytes,
  LogStore store, {
  ReadTextOptions options = const ReadTextOptions(),
  int chunkSize = 256 * 1024,
  String? locale,
})
```

텍스트 파일을 읽고 줄마다 항목을 하나씩 추가합니다. 파일이 아니라 바이트 스트림을 받는 것은, 파일이 무엇인지가 플랫폼마다 다르기 때문입니다. `dart:io`가 있는 곳에서는 `File(path).openRead()`이고, 웹에서는 고른 파일 자신의 스트림입니다. 무엇도 문자열 하나로 만들지 않으므로 메모리보다 큰 파일도 잘 읽습니다. 보관하는 줄 수는 여전히 스토어의 `maxEntries`가 정합니다.

`readTextBytes`는 이미 메모리에 있는 파일을 위한 것이고, 조각으로 나누는 일까지 직접 합니다.

읽기를 멈추려면 스트림 구독을 멈추면 됩니다. `signal` 인자가 없는 것은 Dart의 스트림이 이미 취소할 수 있기 때문입니다.

:::

### ReadTextOptions {#readtextoptions}

::: fw js

| 옵션               | 타입                                      | 기본값                                  | 설명                                                                                              |
| ------------------ | ----------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `encoding`         | `string`                                  | `'auto'`                                | 파일의 인코딩입니다. `'auto'`는 BOM을 읽고, UTF-8을 시도한 뒤, `fallbackEncoding`으로 넘어갑니다. |
| `fallbackEncoding` | `string`                                  | `legacyEncodingFor(navigator.language)` | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                                              |
| `level`            | `LogLevel`                                | `'log'`                                 | 모든 줄의 수준입니다.                                                                             |
| `ansi`             | `boolean`                                 | `true`                                  | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                                                  |
| `chunkSize`        | `number`                                  | `262144`                                | 한 번에 읽는 바이트 수입니다.                                                                     |
| `signal`           | `AbortSignal`                             | 없음                                    | 중단 신호가 오면 읽기를 멈춥니다. 그때까지 읽은 줄은 스토어에 남습니다.                           |
| `onProgress`       | `(loaded: number, total: number) => void` | 없음                                    | 조각을 읽을 때마다 지금까지 읽은 바이트 수와 전체 크기를 넘겨 호출합니다.                         |

:::

::: fw flutter

| 옵션               | 타입                       | 기본값         | 설명                                                                                                                 |
| ------------------ | -------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------- |
| `encoding`         | `String`                   | `'auto'`       | 파일의 인코딩입니다. `auto`는 BOM을 읽고, UTF-8을 시도한 뒤, `fallbackEncoding`으로 넘어갑니다.                      |
| `fallbackEncoding` | `String?`                  | `locale`에서   | 파일이 UTF-8이 아닐 때 `auto`가 쓰는 인코딩입니다.                                                                   |
| `level`            | `LogLevel`                 | `LogLevel.log` | 모든 줄의 수준입니다.                                                                                                |
| `ansi`             | `bool`                     | `true`         | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                                                                     |
| `onProgress`       | `void Function(int, int)?` | `null`         | 조각을 읽을 때마다 지금까지 읽은 바이트 수와 전체 크기를 넘겨 호출합니다. `totalBytes`가 없으면 전체 크기는 0입니다. |

`chunkSize`는 옵션이 아니라 `readTextBytes`의 인자입니다. 이미 남이 조각으로 나눈 스트림에는 뜻이 없기 때문입니다.

:::

### ReadTextResult {#readtextresult}

::: fw js

| 필드       | 타입     | 설명                  |
| ---------- | -------- | --------------------- |
| `lines`    | `number` | 추가한 줄 수입니다.   |
| `bytes`    | `number` | 읽은 바이트 수입니다. |
| `encoding` | `string` | 사용한 인코딩입니다.  |

:::

::: fw flutter

| 필드       | 타입     | 설명                                                                                 |
| ---------- | -------- | ------------------------------------------------------------------------------------ |
| `lines`    | `int`    | 추가한 줄 수입니다.                                                                  |
| `bytes`    | `int`    | 읽은 바이트 수입니다.                                                                |
| `encoding` | `String` | 사용한 인코딩입니다.                                                                 |
| `decoded`  | `bool`   | 그 인코딩의 디코더를 찾았는지 나타냅니다. `false`이면 바이트를 Latin-1로 읽었습니다. |

:::

## followTextFile {#followtextfile}

::: fw js

```ts
followTextFile(handle: FileHandleLike, store: LogStore, options?: FollowTextOptions): FollowHandle
```

`tail -f`처럼 파일을 읽은 뒤 새로 덧붙는 줄을 계속 추가합니다. 확인할 때마다 핸들에서 파일의 새 사본을 받아 지난번 이후에 추가된 부분을 읽습니다. Chromium 계열 브라우저에만 있는 File System Access API의 핸들이 필요합니다.

:::

::: fw flutter

```dart
FollowHandle followTextFile(
  TextFileSource file,
  LogStore store, {
  FollowTextOptions options = const FollowTextOptions(),
  String? locale,
})
```

`tail -f`처럼 파일을 읽은 뒤 새로 덧붙는 줄을 계속 추가합니다. 확인할 때마다 소스에 크기를 묻고 지난번 이후에 추가된 부분을 읽습니다.

:::

파일이 짧아졌거나, 크기는 그대로인데 수정됐으면 내용이 덧붙은 것이 아니라 파일이 교체된 것으로 봅니다. 이때는 처음부터 다시 읽고 `onReset`을 호출합니다.

::: fw js

### FileHandleLike {#filehandlelike}

```ts
interface FileHandleLike {
	getFile(): Promise<Blob & { lastModified?: number }>;
}
```

파일을 따라 읽는 데 필요한 `FileSystemFileHandle`의 일부입니다. `getFile` 메서드만 있으면 어떤 객체든 쓸 수 있어서 테스트할 때 편합니다.

:::

::: fw flutter

### TextFileSource {#textfilesource}

```dart
abstract class TextFileSource {
  Future<int> length();
  Future<DateTime?> lastModified();
  Stream<List<int>> openRead([int start = 0]);
}
```

파일을 따라 읽는 데 필요한 것이 전부이고, 파일이 어디에 있는지는 담지 않습니다. 파일 시스템이 있는 플랫폼에서는 `localTextFile(path)`가 하나를 반환합니다. `CallbackTextFile`은 함수 셋으로 하나를 만드는데, 웹에서 고른 파일과 테스트가 모두 이것을 씁니다.

웹에서는 `dart:io`를 가져오면 컴파일되지 않으므로, `localTextFile`은 실행할 때가 아니라 빌드할 때 고릅니다. 웹에서는 예외를 던지고, 고른 파일은 `CallbackTextFile`로 갑니다.

:::

### FollowTextOptions {#followtextoptions}

::: fw js

| 옵션               | 타입                       | 기본값                                  | 설명                                                                |
| ------------------ | -------------------------- | --------------------------------------- | ------------------------------------------------------------------- |
| `interval`         | `number`                   | `1000`                                  | 새 데이터를 확인하는 간격이며, 단위는 밀리초입니다.                 |
| `encoding`         | `string`                   | `'auto'`                                | 인코딩입니다. `'auto'`이면 처음 읽은 바이트로 알아냅니다.           |
| `fallbackEncoding` | `string`                   | `legacyEncodingFor(navigator.language)` | 파일이 UTF-8이 아닐 때 `'auto'`가 쓰는 인코딩입니다.                |
| `level`            | `LogLevel`                 | `'log'`                                 | 모든 줄의 수준입니다.                                               |
| `ansi`             | `boolean`                  | `true`                                  | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                    |
| `onReset`          | `() => void`               | 없음                                    | 파일이 교체되어 처음부터 다시 읽을 때 호출합니다.                   |
| `onError`          | `(error: unknown) => void` | 없음                                    | 첫 번째 이후의 확인이 권한 취소 같은 이유로 실패했을 때 호출합니다. |

:::

::: fw flutter

| 옵션               | 타입                     | 기본값                 | 설명                                                                       |
| ------------------ | ------------------------ | ---------------------- | -------------------------------------------------------------------------- |
| `interval`         | `Duration`               | `Duration(seconds: 1)` | 새 데이터를 확인하는 간격입니다.                                           |
| `encoding`         | `String`                 | `'auto'`               | 인코딩입니다. `auto`이면 처음 읽은 바이트로 알아냅니다.                    |
| `fallbackEncoding` | `String?`                | `locale`에서           | 파일이 UTF-8이 아닐 때 `auto`가 쓰는 인코딩입니다.                         |
| `level`            | `LogLevel`               | `LogLevel.log`         | 모든 줄의 수준입니다.                                                      |
| `ansi`             | `bool`                   | `true`                 | ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다.                           |
| `onReset`          | `void Function()?`       | `null`                 | 파일이 교체되어 처음부터 다시 읽을 때 호출합니다.                          |
| `onError`          | `void Function(Object)?` | `null`                 | 첫 번째 이후의 확인이 파일이 사라진 것 같은 이유로 실패했을 때 호출합니다. |

:::

### FollowHandle {#followhandle}

| 멤버    | 타입                                                   | 설명                                                                                                                                                   |
| ------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ready` | <Fw js="Promise<number>" flutter="Future<int>" code /> | 첫 읽기가 끝나면 그때 추가한 줄 수로, 첫 읽기가 실패하면 그 오류로 완료됩니다. 이 실패에는 `onError`를 호출하지 않으며, 어느 쪽이든 확인은 계속합니다. |
| `stop`  | <Fw js="() => void" flutter="void Function()" code />  | 파일 확인을 멈추고, 디코더에 남은 내용과 끝나지 않은 마지막 줄을 기록합니다.                                                                           |

## TextLineWriter {#textlinewriter}

::: fw js

```ts
new TextLineWriter(store: LogStore, options?: { level?: LogLevel; ansi?: boolean })
```

:::

::: fw flutter

```dart
TextLineWriter(LogStore store, {LogLevel level = LogLevel.log, bool ansi = true})
```

:::

디코딩한 텍스트를 한 줄씩 스토어 항목으로 바꾸고, 조각 사이에서 끝나지 않은 줄과 ANSI 스타일을 이어 갑니다. 이 페이지의 읽기 함수들이 이 클래스를 씁니다.

| 멤버                                                              | 타입                                    | 설명                                                      |
| ----------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| <Fw js="write(text: string)" flutter="write(String text)" code /> | `void`                                  | 텍스트 조각을 추가하고, 그 조각으로 끝난 줄을 기록합니다. |
| `flush()`                                                         | `void`                                  | 끝나지 않은 마지막 줄이 있으면 기록합니다.                |
| `lines`                                                           | <Fw js="number" flutter="int" code />   | 기록한 줄 수입니다.                                       |
| `hasPending`                                                      | <Fw js="boolean" flutter="bool" code /> | 줄 바꿈을 기다리는 끝나지 않은 줄이 있는지 나타냅니다.    |

## 인코딩 {#encodings}

::: fw flutter

이 패키지가 직접 디코딩하는 인코딩은 UTF-8, UTF-16, Windows-1252, Latin-1이고, 그 목록이 `builtInEncodings`입니다. 레거시 CJK 인코딩은 수만 자짜리 표가 필요한데, 브라우저에는 이미 있고 Dart에는 없습니다. 그래서 표를 네 벌 더 넣는 대신 디코더를 여러분에게서 받습니다.

```dart
abstract class TextDecoderSink {
  String add(List<int> bytes);
  String close();
}

typedef TextDecoderFactory = TextDecoderSink? Function(String encoding);

void registerTextDecoder(TextDecoderFactory factory)
TextDecoderSink? decoderFor(String encoding)
```

팩토리는 읽기 함수가 만나는 인코딩마다 최근에 등록한 것부터 호출되고, 다루지 않는 인코딩에는 `null`을 반환합니다. 팩토리가 없으면 아무도 디코딩하지 못하는 파일을 Latin-1로 읽고 `ReadTextResult.decoded`가 `false`가 됩니다. [파일 인코딩](/ko/guide/cjk#file-encodings)을 참고하세요.

:::

### detectEncoding {#detectencoding}

::: fw js

```ts
detectEncoding(bytes: Uint8Array, fallback: string): string
```

:::

::: fw flutter

```dart
String detectEncoding(List<int> bytes, String fallback)
```

:::

파일 앞부분의 바이트로 인코딩을 고릅니다. BOM이 있으면 그에 맞는 `utf-8`, `utf-16le`, `utf-16be` 가운데 하나를, 없으면 올바른 UTF-8일 때 `utf-8`을, 그 밖에는 `fallback`을 반환합니다. `bytes` 끝에서 잘린 멀티바이트 시퀀스는 올바른 것으로 봅니다.

<Fw flutter="이를 이루는 두 부분인 encodingFromBom(bytes)과 isValidUtf8(bytes)도 공개되어 있습니다. 직접 만든 읽기 함수에 필요하기 때문입니다." />

### legacyEncodingFor {#legacyencodingfor}

```
legacyEncodingFor(locale)
```

HTML Standard의 기본 인코딩 추천 표를 따라, 그 언어의 페이지에 브라우저가 가정하는 레거시 인코딩을 반환합니다. 예를 들어 `ko-KR`이면 `euc-kr`입니다. 표에 없는 언어와 로케일이 없을 때는 `windows-1252`를 반환합니다.

::: fw js

```ts
import { detectEncoding, legacyEncodingFor } from 'lognal';

// `file`은 <input type="file">에서 얻은 File 같은 Blob입니다.
const head = new Uint8Array(await file.slice(0, 65536).arrayBuffer());
const encoding = detectEncoding(head, legacyEncodingFor('ko-KR'));
// 'utf-8' 또는 'euc-kr'
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

final List<int> head = await File(path).openRead(0, 65536).expand((List<int> c) => c).toList();
final String encoding = detectEncoding(head, legacyEncodingFor('ko-KR'));
// 'utf-8' 또는 'euc-kr'
```

:::

## ANSI 이스케이프 코드 {#ansi-escape-codes}

### AnsiParser {#ansiparser}

```
new AnsiParser()
```

ANSI 이스케이프 코드가 들어간 텍스트를 스타일이 붙은 파트로 바꿉니다. SGR 코드는 스타일로 바꾸고 다른 이스케이프 시퀀스는 모두 지웁니다. 터미널이 줄에서 줄로 스타일을 이어 가듯, 스타일은 호출이 바뀌어도 이어집니다.

| 메서드                                                            | 반환값                                               | 설명                                           |
| ----------------------------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------- |
| <Fw js="parse(text: string)" flutter="parse(String text)" code /> | <Fw js="TextPart[]" flutter="List<TextPart>" code /> | 텍스트 한 조각을 해석합니다. 보통 한 줄입니다. |
| `reset()`                                                         | `void`                                               | 현재 스타일을 잊습니다.                        |

::: fw js

```ts
import { AnsiParser } from 'lognal';

new AnsiParser().parse('\x1b[1;31mfailed\x1b[0m after 3 tries');
// [{ type: 'text', text: 'failed', style: { bold: true, color: 1 } },
//  { type: 'text', text: ' after 3 tries' }]
```

:::

::: fw flutter

```dart
import 'package:lognal/lognal.dart';

AnsiParser().parse('\x1b[1;31mfailed\x1b[0m after 3 tries');
// [TextPart('failed', style: LogTextStyle(bold: true, color: AnsiTextColor(1))),
//  TextPart(' after 3 tries')]
```

:::

### stripAnsi {#stripansi}

```
stripAnsi(text)
```

텍스트에서 ANSI 이스케이프 시퀀스를 모두 지웁니다.

## 줄 {#lines}

### LineSplitter {#linesplitter}

::: fw js

```ts
new LineSplitter();
```

:::

::: fw flutter

```dart
LogLineSplitter()
```

클래스 이름은 `LogLineSplitter`입니다. `LineSplitter`는 `dart:convert`가 먼저 쓰고 있습니다.

:::

이어서 들어오는 텍스트 조각을 줄로 나눕니다. 줄은 `\n`, `\r\n`, 단독 `\r`에서 끝나고, 두 조각에 걸쳐 나뉜 `\r\n`도 줄 바꿈 하나로 셉니다.

| 멤버                                                              | 타입                                             | 설명                                                         |
| ----------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| <Fw js="push(chunk: string)" flutter="push(String chunk)" code /> | <Fw js="string[]" flutter="List<String>" code /> | 조각을 추가하고, 그 조각으로 끝난 줄을 반환합니다.           |
| `flush()`                                                         | <Fw js="string[]" flutter="List<String>" code /> | 끝나지 않은 마지막 줄이 있으면 반환하고 상태를 초기화합니다. |
| `hasPending`                                                      | <Fw js="boolean" flutter="bool" code />          | 줄 바꿈을 기다리는 텍스트가 있는지 나타냅니다.               |

### splitLines {#splitlines}

```
splitLines(text)
```

문자열 전체를 줄로 나눕니다. 끝에 있는 줄 바꿈은 빈 줄을 만들지 않습니다.

## 텍스트 폭 {#text-width}

뷰어와 같은 규칙으로 텍스트를 잽니다. [격자 위의 폭](/ko/guide/cjk#width-on-the-grid)을 참고하세요.

::: fw js

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

:::

::: fw flutter

| 함수                                                                | 반환값         | 설명                                                                                                                  |
| ------------------------------------------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------- |
| `measureCells(String text, [AmbiguousWidth ambiguousWidth])`        | `int`          | 문자열이 한 행에서 차지하는 칸 수입니다.                                                                              |
| `truncateCells(String text, int maxCells, [AmbiguousWidth aw])`     | `String`       | 문자열을 `maxCells`칸 이하로 자르고, 잘린 부분이 있으면 `…`로 끝냅니다. 한도를 넘는 전각 문자는 쪼개지 않고 뺍니다.   |
| `padCells(String text, int cells, [AmbiguousWidth ambiguousWidth])` | `String`       | 문자열을 칸 수에 맞게 공백으로 채웁니다. 표를 만들 때 줄을 맞추는 함수입니다.                                         |
| `clusterWidth(String cluster, [AmbiguousWidth ambiguousWidth])`     | `int`          | 그래핌 클러스터 하나가 차지하는 칸 수입니다.                                                                          |
| `codePointWidth(int codePoint, [AmbiguousWidth ambiguousWidth])`    | `int`          | 코드 포인트 하나가 차지하는 칸 수로, 0, 1, 2 가운데 하나입니다. 제어 문자는 1입니다.                                  |
| `splitGraphemes(String text)`                                       | `List<String>` | 현재 분할 함수로 텍스트를 그래핌 클러스터로 나눕니다.                                                                 |
| `setGraphemeSplitter(GraphemeSplitter? splitter)`                   | `void`         | 그래핌 분할 함수를 바꿉니다. `null`을 넘기면 `package:characters`를 쓰는 기본 함수로 돌아갑니다.                      |
| `normalizeNfc(String text)`                                         | `String`       | 텍스트를 유니코드 정규화 형식 C로 합칩니다. 필터와 검색이 이 형태로 비교하며, Dart에는 `String.normalize`가 없습니다. |

`ambiguousWidth`의 기본값은 `1`입니다. `unicodeVersion`은 폭 데이터의 출처인 Unicode 버전으로, 값은 `'17.0.0'`입니다.

```dart
typedef AmbiguousWidth = int;
typedef GraphemeSplitter = List<String> Function(String text);
```

`splitGraphemesFallback`은 `package:characters`가 연결되지 않은 곳에서 쓰는 분할 함수이고, 테스트에서 둘을 비교할 수 있도록 공개되어 있습니다.

:::
