---
order: 2
description: 로그 항목을 보관하는 LogStore의 옵션, 메서드, 변경 알림, 쓰기 옵션을 정리한 레퍼런스입니다.
---

# LogStore

```ts
import { LogStore } from 'lognal';

const store = new LogStore({ maxEntries: 50000 });
```

로그 항목을 추가된 순서대로 보관합니다. 스토어는 항목을 어떻게 보여 줄지 모르므로, 스토어 하나를 여러 뷰어가 함께 보여 주거나 뷰어가 생기기 전부터 메시지를 모아 둘 수 있습니다.

## 생성자 {#constructor}

```ts
new LogStore(options?: Partial<LogStoreOptions>)
```

## LogStoreOptions {#logstoreoptions}

| 옵션           | 타입         | 기본값  | 설명                                                                                                                                      |
| -------------- | ------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `maxEntries`   | `number`     | `10000` | 스토어가 보관하는 최대 항목 수입니다. 가득 차면 새 항목이 들어올 때마다 가장 오래된 항목을 버립니다. 모두 보관하려면 `Infinity`를 씁니다. |
| `mergeRepeats` | `RepeatMode` | `true`  | 바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. [`RepeatMode`](#repeatmode)를 참고하세요.                                             |

`DEFAULT_STORE_OPTIONS`에 이 기본값이 들어 있습니다.

## 속성 {#properties}

| 속성      | 타입     | 설명                                                                                   |
| --------- | -------- | -------------------------------------------------------------------------------------- |
| `size`    | `number` | 보관 중인 항목 수입니다.                                                               |
| `firstId` | `number` | 보관 중인 가장 오래된 항목의 id입니다. 스토어가 비어 있으면 다음 항목이 받을 id입니다. |
| `lastId`  | `number` | 보관 중인 가장 새 항목의 id입니다. 스토어가 비어 있으면 `firstId - 1`입니다.           |

id는 1부터 시작해 새 항목마다 1씩 늘어납니다. `clear()`를 호출한 뒤에도 같은 id를 다시 쓰지 않습니다.

## 메서드 {#methods}

| 메서드                                                  | 반환값                      | 설명                                                                                                                                                   |
| ------------------------------------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `getOptions()`                                          | `Readonly<LogStoreOptions>` | 옵션을 반환합니다.                                                                                                                                     |
| `setOptions(options: Partial<LogStoreOptions>)`         | `void`                      | 옵션을 바꿉니다. `maxEntries`를 줄이면 오래된 항목을 바로 버립니다.                                                                                    |
| `at(index: number)`                                     | `LogEntry \| undefined`     | 위치에 있는 항목을 반환합니다. 0이 보관 중인 가장 오래된 항목입니다.                                                                                   |
| `get(id: number)`                                       | `LogEntry \| undefined`     | 아직 보관 중이라면 id에 해당하는 항목을 반환합니다.                                                                                                    |
| `toArray()`                                             | `LogEntry[]`                | 모든 항목을 오래된 순서로 반환합니다.                                                                                                                  |
| `[Symbol.iterator]()`                                   | `Iterator<LogEntry>`        | 항목을 오래된 순서로 순회합니다.                                                                                                                       |
| `append(init: LogEntryInit \| readonly LogEntryInit[])` | `LogEntry[]`                | 항목을 하나 또는 여러 개 추가하고, 새로 만든 항목만 반환합니다. 앞 항목에 합쳐진 메시지는 그 항목의 `repeat`만 올리고 반환 배열에는 들어가지 않습니다. |
| `write(text: string, options?: WriteOptions)`           | `LogEntry \| undefined`     | 텍스트를 항목 하나로 추가합니다. 줄 바꿈은 항목 안에 그대로 둡니다. 새 항목이나, 텍스트가 합쳐진 항목을 반환합니다.                                    |
| `writeLines(text: string, options?: WriteOptions)`      | `LogEntry[]`                | 텍스트를 줄마다 항목 하나씩 추가하고, 새로 만든 항목을 반환합니다.                                                                                     |
| `clear()`                                               | `void`                      | 항목을 모두 지웁니다.                                                                                                                                  |
| `setCollapsed(id: number, collapsed: boolean)`          | `void`                      | 그룹 머리글이나 반복 묶음의 첫 항목을 접거나 펼쳐서, 그 안의 항목을 숨기거나 보여 줍니다.                                                              |
| `isRunHead(entry: LogEntry)`                            | `boolean`                   | 스토어가 아직 들고 있는 반복 묶음의 첫 항목인지, 곧 그 묶음을 펼칠 수 있는지 알려 줍니다.                                                              |
| `subscribe(listener: StoreListener)`                    | `() => void`                | 바뀔 때마다 리스너를 호출합니다. 리스너를 떼는 함수를 반환합니다.                                                                                      |

```ts
import { LogStore } from 'lognal';

const store = new LogStore();

store.append({
	level: 'warn',
	parts: [
		{ type: 'text', text: 'Slow query ' },
		{ type: 'text', text: '1.8s', token: 'number' }
	]
});

const stop = store.subscribe((change) => {
	if (change.type === 'append') {
		document.title = `${store.size} log entries`;
	}
});
```

## WriteOptions {#writeoptions}

스토어와 뷰어의 `write`, `writeLines`가 받는 옵션입니다.

| 옵션     | 타입                    | 기본값      | 설명                                                                                                                           |
| -------- | ----------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `level`  | `LogLevel`              | `'log'`     | 항목의 수준입니다.                                                                                                             |
| `kind`   | `LogKind`               | `'message'` | 항목의 종류입니다.                                                                                                             |
| `time`   | `number`                | 현재 시각   | 항목의 시각으로, 밀리초 단위의 에포크 시각입니다.                                                                              |
| `groups` | `readonly number[]`     | `[]`        | 항목이 속한 열린 그룹의 id입니다. 가장 바깥 그룹이 먼저 옵니다.                                                                |
| `token`  | `StyleToken`            | 없음        | 텍스트의 의미 색입니다.                                                                                                        |
| `style`  | `TextStyle`             | 없음        | 텍스트에 직접 지정하는 스타일입니다. `ansi`를 지정하면 무시합니다.                                                             |
| `ansi`   | `boolean \| AnsiParser` | `false`     | 텍스트의 ANSI 이스케이프 코드를 스타일로 바꿀지 정합니다. 파서를 넘기면 여러 번 호출해도 스타일이 이어집니다.                  |
| `wrap`   | `boolean`               | `true`      | `false`이면 텍스트의 줄마다 한 행에 둡니다. 표처럼 모양을 지켜야 하는 텍스트에 씁니다. 뷰어보다 넓은 줄은 가로로 스크롤합니다. |

## RepeatMode {#repeatmode}

```ts
type RepeatMode = boolean | 'collapse';
```

바로 앞과 똑같은 메시지를 어떻게 처리할지 정합니다. `true`는 메시지를 버리고 앞 항목의 반복 횟수를 올리며, `'collapse'`는 메시지를 모두 보관하고 연속된 메시지를 횟수와 함께 접힌 항목 하나로 보여 주고, `false`는 메시지마다 항목을 따로 만듭니다. `message` 종류의 항목만 묶이고, 오류나 자식이 있는 값을 담은 항목은 묶이지 않습니다. [반복 메시지](/ko/guide/values#repeated-messages)를 참고하세요.

## StoreChange {#storechange}

스토어 리스너가 받는 값입니다.

| `type`     | 다른 필드                                 | 보내는 때                                                                                                       |
| ---------- | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `'append'` | `entries: readonly LogEntry[]`            | 항목이 추가됐을 때입니다.                                                                                       |
| `'update'` | `entry: LogEntry`, `visibility?: boolean` | 항목의 반복 횟수나 접힘 상태가 바뀌었습니다. `visibility`는 다른 항목까지 숨기거나 보여 주는 변경임을 뜻합니다. |
| `'trim'`   | `count: number`                           | `maxEntries` 때문에 오래된 항목을 버렸을 때입니다.                                                              |
| `'clear'`  | 없음                                      | 항목을 모두 지웠을 때입니다.                                                                                    |

```ts
type StoreListener = (change: StoreChange) => void;
```

`'append'` 변경이 먼저 오고, 그 추가 때문에 생긴 `'trim'` 변경이 뒤따릅니다.
