/// What the gallery's buttons write.
///
/// Invisible characters, such as a zero width joiner or a bidirectional
/// override, are built with `String.fromCharCode`, so this file holds none of
/// them.
library;

import 'dart:convert';
import 'dart:math';

import 'package:lognal/lognal.dart';

const String _escape = '\x1b';

/// Wraps text in an ANSI Select Graphic Rendition sequence and resets the style
/// after it.
String _sgr(String codes, String text) => '$_escape[${codes}m$text$_escape[0m';

/// A model class, to show what `toJson()` does for a value the viewer cannot
/// otherwise open.
class Account {
  const Account({required this.id, required this.name, required this.roles});

  final int id;
  final String name;
  final List<String> roles;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name, 'roles': roles};
}

/// A class that says what it is and nothing more, which is the other half of
/// the same story.
class Session {
  const Session(this.id);

  final String id;

  @override
  String toString() => 'Session($id)';
}

/// One button of the gallery.
class Sample {
  const Sample({required this.id, required this.label, required this.run});

  /// What the button is called in the code and in the site's query string.
  final String id;

  /// What the button says, in English and in Korean.
  final Map<String, String> label;

  /// What it writes.
  final void Function(LognalConsole log, LogStore store) run;
}

/// A group of buttons.
class SampleGroup {
  const SampleGroup({required this.id, required this.label, required this.samples});

  final String id;
  final Map<String, String> label;
  final List<Sample> samples;
}

final Random _random = Random(7);

/// Every button the gallery offers, in the order it shows them.
final List<SampleGroup> sampleGroups = <SampleGroup>[
  SampleGroup(
    id: 'console',
    label: <String, String>{'en': 'Logging', 'ko': '로그'},
    samples: <Sample>[
      Sample(
        id: 'levels',
        label: <String, String>{'en': 'Every level', 'ko': '모든 수준'},
        run: (LognalConsole log, LogStore store) {
          log
            ..debug('Cache lookup for %s', <Object?>['user:42'])
            ..log('GET /api/users handled in %dms', <Object?>[38])
            ..info('Connected to %s in %fms', <Object?>['database', 12.5])
            ..warn('Response time is above %dms', <Object?>[500])
            ..error('Payment service returned %d', <Object?>[503]);
        },
      ),
      Sample(
        id: 'format',
        label: <String, String>{'en': 'Format specifiers', 'ko': '포맷 지정자'},
        run: (LognalConsole log, LogStore store) {
          log
            ..log('%s requests in %fs', <Object?>[128, '2.5'])
            ..log('%d and %i read integers, %f reads a float', <Object?>['42.9px', '7', '3.14abc'])
            ..log('User %o signed in with %O', <Object?>[
              <String, int>{'id': 42},
              <String, Object?>{'theme': 'dark', 'beta': true},
            ])
            ..log('Disk usage is at 91%% with %s left', <Object?>['12 GB', 'and extra arguments'])
            ..log('A specifier without an argument stays: %s and %d');
        },
      ),
      Sample(
        id: 'styled',
        label: <String, String>{'en': 'Styled text', 'ko': '스타일 텍스트'},
        run: (LognalConsole log, LogStore store) {
          log
            ..log('%cSuccess%c build finished', <Object?>['color: #1f7a47; font-weight: bold', ''])
            ..log('%c background %c and %citalic underlined text', <Object?>[
              'background: #4697fd; color: white',
              '',
              'font-style: italic; text-decoration: underline',
            ])
            ..log(
              '%cOnly what the viewer can draw is kept, so this has no image and no large font',
              <Object?>[
                'color: rgb(200 60 40); '
                    'background-image: url(https://example.com/image.png); font-size: 40px',
              ],
            );
        },
      ),
      Sample(
        id: 'repeats',
        label: <String, String>{'en': 'A repeated message', 'ko': '반복되는 메시지'},
        run: (LognalConsole log, LogStore store) {
          for (int index = 0; index < 5; index++) {
            log.warn('Retrying the connection');
          }
        },
      ),
      Sample(
        id: 'counters',
        label: <String, String>{'en': 'Counters and timers', 'ko': '카운터와 타이머'},
        run: (LognalConsole log, LogStore store) {
          log
            ..count()
            ..count()
            ..count('api')
            ..countReset('api')
            ..count('api')
            ..time('render')
            ..timeLog('render', <Object?>['first frame'])
            ..timeEnd('render');
        },
      ),
      Sample(
        id: 'groups',
        label: <String, String>{'en': 'Groups', 'ko': '그룹'},
        run: (LognalConsole log, LogStore store) {
          log
            ..group('Request 4812')
            ..log('Matched route %s', <Object?>['/api/orders/:id'])
            ..groupCollapsed('Headers')
            ..log('accept: application/json')
            ..log('accept-language: ko-KR')
            ..groupEnd()
            ..info('Answered in 41ms')
            ..groupEnd();
        },
      ),
      Sample(
        id: 'errors',
        label: <String, String>{'en': 'An error with its stack', 'ko': '스택이 있는 오류'},
        run: (LognalConsole log, LogStore store) {
          try {
            throw StateError('The order was already paid');
          } on StateError catch (error, stack) {
            log.error(error, const <Object?>[], stack);
          }

          log.assertCondition(false, <Object?>['the queue is empty']);
        },
      ),
    ],
  ),
  SampleGroup(
    id: 'values',
    label: <String, String>{'en': 'Values', 'ko': '값'},
    samples: <Sample>[
      Sample(
        id: 'collections',
        label: <String, String>{'en': 'Lists, maps and sets', 'ko': '리스트, 맵, 세트'},
        run: (LognalConsole log, LogStore store) {
          log
            ..dir(<String, Object?>{
              'id': 4812,
              'total': 39500,
              'items': <Map<String, Object?>>[
                <String, Object?>{'sku': 'A-1', 'quantity': 2},
                <String, Object?>{'sku': 'B-7', 'quantity': 1},
              ],
              'paid': true,
              'coupon': null,
            })
            ..dir(<int, String>{1: 'one', 2: 'two', 3: 'three'})
            ..dir(<String>{'read', 'write', 'admin'});
        },
      ),
      Sample(
        id: 'objects',
        label: <String, String>{'en': 'Your own classes', 'ko': '직접 만든 클래스'},
        run: (LognalConsole log, LogStore store) {
          log
            ..log('A class with `toJson()` opens', <Object?>[
              const Account(id: 42, name: 'Ada', roles: <String>['admin', 'editor']),
            ])
            ..log('One with only `toString()` says what it says', <Object?>[const Session('9f3a')])
            ..log('And the rest show their type', <Object?>[DateTime.now(), Duration.zero]);
        },
      ),
      Sample(
        id: 'table',
        label: <String, String>{'en': 'A table', 'ko': '테이블'},
        run: (LognalConsole log, LogStore store) {
          log.table(<Map<String, Object?>>[
            <String, Object?>{'name': '김철수', 'role': '관리자', 'orders': 12},
            <String, Object?>{'name': 'Ada Lovelace', 'role': 'editor', 'orders': 3},
            <String, Object?>{'name': '佐藤', 'role': 'viewer', 'orders': 0},
          ]);
        },
      ),
      Sample(
        id: 'deep',
        label: <String, String>{'en': 'Past the limits', 'ko': '한계를 넘는 값'},
        run: (LognalConsole log, LogStore store) {
          final Map<String, Object?> circular = <String, Object?>{'name': 'root'};

          circular['self'] = circular;
          log
            ..dir(circular)
            ..dir(<String, Object?>{
              'a': <String, Object?>{
                'b': <String, Object?>{
                  'c': <String, Object?>{
                    'd': <String, Object?>{
                      'e': <String, Object?>{'f': 'too deep to capture'},
                    },
                  },
                },
              },
            })
            ..dir(List<int>.generate(200, (int index) => index));
        },
      ),
    ],
  ),
  SampleGroup(
    id: 'text',
    label: <String, String>{'en': 'Text', 'ko': '텍스트'},
    samples: <Sample>[
      Sample(
        id: 'ansi',
        label: <String, String>{'en': 'ANSI colors', 'ko': 'ANSI 색상'},
        run: (LognalConsole log, LogStore store) {
          store.writeLines(
            <String>[
              '${_sgr('32', 'INFO ')} server listening on ${_sgr('4;36', 'http://localhost:3000')}',
              '${_sgr('33', 'WARN ')} ${_sgr('2', 'cache miss for user:42')}',
              '${_sgr('1;31', 'ERROR')} ${_sgr('38;5;208', 'payment')} timed out after 30s',
              _sgr('48;2;30;30;46;97', ' a true-color background '),
            ].join('\n'),
            const WriteOptions(ansi: true),
          );
        },
      ),
      Sample(
        id: 'wide',
        label: <String, String>{'en': 'Korean, Chinese and emoji', 'ko': '한중일과 이모지'},
        run: (LognalConsole log, LogStore store) {
          final String zeroWidthJoiner = String.fromCharCode(0x200d);

          store
            ..write('안녕하세요. 로그 뷰어가 한글을 공백에서 줄바꿈합니다. 아주 긴 한 줄을 넣어도 단어가 끊기지 않습니다.')
            ..write('服务器已经启动了，日志按字符换行。')
            ..write('ログはそのまま表示されます。')
            ..write('👩$zeroWidthJoiner💻 개발자, 🇰🇷 국기, 👍🏽 피부색까지 두 칸으로 셉니다.');
        },
      ),
      Sample(
        id: 'control',
        label: <String, String>{'en': 'What is made visible', 'ko': '보이게 바꾸는 문자'},
        run: (LognalConsole log, LogStore store) {
          final String override = String.fromCharCode(0x202e);
          final String bell = String.fromCharCode(0x07);

          store
            ..write('A control character shows as a notation: ${bell}here')
            ..write('A bidirectional override cannot reorder this: ${override}exe.txt')
            ..write('A tab lines up:\tone\ttwo\tthree');
        },
      ),
      Sample(
        id: 'links',
        label: <String, String>{'en': 'Links', 'ko': '링크'},
        run: (LognalConsole log, LogStore store) {
          store
            ..write(
              'Docs at https://lognal.cdget.com/guide/ and the source at '
              'https://github.com/jooy2/lognal',
            )
            ..write('Punctuation after an address is not part of it: https://example.com/a.')
            ..write('And another scheme is not a link: ftp://example.com');
        },
      ),
      Sample(
        id: 'nowrap',
        label: <String, String>{'en': 'A line that never wraps', 'ko': '줄바꿈하지 않는 줄'},
        run: (LognalConsole log, LogStore store) {
          store.write(
            'id    | route                         | status | ms\n'
            '------+-------------------------------+--------+------\n'
            '4812  | /api/orders/4812              | 200    | 41\n'
            '4813  | /api/orders/4813/attachments  | 500    | 1204',
            const WriteOptions(wrap: false),
          );
        },
      ),
    ],
  ),
  SampleGroup(
    id: 'volume',
    label: <String, String>{'en': 'Volume', 'ko': '대량'},
    samples: <Sample>[
      Sample(
        id: 'burst',
        label: <String, String>{'en': '10,000 lines', 'ko': '10,000줄'},
        run: (LognalConsole log, LogStore store) {
          const List<String> routes = <String>[
            '/api/orders',
            '/api/users/42',
            '/assets/app.js',
            '/health',
          ];
          final List<LogEntryInit> entries = List<LogEntryInit>.generate(10000, (int index) {
            final int status = _random.nextInt(20) == 0 ? 500 : 200;

            return LogEntryInit(
              level: status == 500 ? LogLevel.error : LogLevel.log,
              parts: <LogPart>[
                TextPart('${routes[index % routes.length]} $status in ${_random.nextInt(400)}ms'),
              ],
            );
          });

          store.append(entries);
        },
      ),
      Sample(
        id: 'file',
        label: <String, String>{'en': 'A log file, read', 'ko': '로그 파일 읽기'},
        run: (LognalConsole log, LogStore store) {
          readTextBytes(utf8.encode(sampleLogFile()), store).ignore();
        },
      ),
    ],
  ),
];

/// A log file the gallery reads without asking the reader for one.
String sampleLogFile() {
  final List<String> lines = <String>[
    '2026-09-17 09:00:01 INFO  boot: lognal 1.0.0',
    '2026-09-17 09:00:01 INFO  boot: 설정 파일을 읽었습니다 (config/app.yaml)',
    '2026-09-17 09:00:02 WARN  cache: no entry for user:42',
  ];

  for (int index = 0; index < 60; index++) {
    lines.add(
      '2026-09-17 09:0${index % 10}:${(index * 7) % 60} '
      '${index % 11 == 0 ? 'ERROR' : 'INFO '} '
      'http: GET /api/orders/${4800 + index} '
      '${index % 11 == 0 ? 500 : 200} in ${20 + index % 90}ms',
    );
  }

  return '${lines.join('\n')}\n';
}

/// What the input line answers.
Object? runCommand(String command) {
  final List<String> words = command.trim().split(RegExp(r'\s+'));
  final String name = words.first;
  final List<String> rest = words.skip(1).toList();

  switch (name) {
    case 'help':
      return 'Commands: echo <text>, time, json, error';
    case 'echo':
      return rest.join(' ');
    case 'time':
      return DateTime.now();
    case 'json':
      return <String, Object?>{'command': command, 'words': rest, 'length': command.length};
    case 'error':
      throw const FormatException('This command always fails');
    default:
      return Future<String>.delayed(
        const Duration(milliseconds: 300),
        () => 'Unknown command: $name',
      );
  }
}
