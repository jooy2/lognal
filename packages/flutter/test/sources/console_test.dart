import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/sources/console/capture.dart';
import 'package:lognal/src/sources/console/console.dart';
import 'package:lognal/src/sources/console/css_color.dart';
import 'package:lognal/src/sources/console/format.dart';
import 'package:lognal/src/sources/console/hook.dart';

ValueNode capture(Object? value) => captureValue(value);

String textOf(List<LogPart> parts) {
  return parts
      .map(
        (LogPart part) => part is TextPart ? part.text : '<${(part as ValuePart).value.kind.name}>',
      )
      .join();
}

LogEntry lastEntry(LogStore store) => store.at(store.size - 1)!;

class Account {
  Account(this.id);

  final int id;

  Map<String, Object?> toJson() => <String, Object?>{'id': id};
}

class Plain {
  const Plain();
}

class Described {
  const Described();

  @override
  String toString() => 'Described(all of it)';
}

void main() {
  group('captureValue', () {
    test('captures primitives the way they print', () {
      expect(captureValue(-0.0).kind, ValueKind.number);
      expect(captureValue(-0.0).value, '-0.0');
      expect(captureValue(BigInt.from(10)).value, '10');
      expect(captureValue(#token).kind, ValueKind.symbol);
      expect(captureValue(null).kind, ValueKind.nullValue);
      expect(captureValue(double.nan).value, 'NaN');
    });

    test('takes the value at call time', () {
      final Map<String, Object?> user = <String, Object?>{'name': 'before'};
      final ValueNode node = captureValue(user);

      user['name'] = 'after';

      expect(node.children?.first.value.value, 'before');
    });

    test('marks circular references', () {
      final Map<String, Object?> value = <String, Object?>{};

      value['self'] = value;

      expect(captureValue(value).children?.first.value.kind, ValueKind.circular);
    });

    test('respects the depth, property, string and node limits', () {
      const Map<String, Object?> deep = <String, Object?>{
        'a': <String, Object?>{
          'b': <String, Object?>{
            'c': <String, Object?>{'d': 1},
          },
        },
      };
      final Map<String, Object?> wide = <String, Object?>{
        for (int index = 0; index < 10; index++) 'key$index': index,
      };
      final ValueNode depthNode = captureValue(deep, const CaptureOptions(maxDepth: 2));
      final ValueNode? inner = depthNode.children?.first.value.children?.first.value;

      expect(inner?.kind, ValueKind.map);
      expect(inner?.children, isNull);
      expect(captureValue(wide, const CaptureOptions(maxProperties: 3)).omitted, 7);

      final ValueNode long = captureValue('x' * 20, const CaptureOptions(maxStringLength: 5));

      expect(long.value, 'xxxxx');
      expect(long.truncated, 15);
      expect(
        captureValue(
          List<Map<String, int>>.generate(50, (int _) => <String, int>{'x': 1}),
          const CaptureOptions(maxNodes: 10),
        ).children?.length,
        lessThan(10),
      );
    });

    test('recognizes built-in types', () {
      expect(captureValue(DateTime.utc(1970)).kind, ValueKind.date);
      expect(captureValue(DateTime.utc(1970)).value, '1970-01-01T00:00:00.000Z');
      expect(captureValue(RegExp('a+b')).value, '/a+b/');
      expect(captureValue(<String, int>{'a': 1}).kind, ValueKind.map);
      expect(captureValue(<String, int>{'a': 1}).size, 1);
      expect(captureValue(<int>{1, 2}).kind, ValueKind.set);
      expect(captureValue(<int>[1, 2, 3]).size, 3);
      expect(captureValue(Uint8List.fromList(<int>[1, 2, 3])).kind, ValueKind.list);
      expect(captureValue(int).kind, ValueKind.classValue);
      expect(captureValue(main).kind, ValueKind.function);
      expect(captureValue(Future<int>.value(1)).kind, ValueKind.future);
    });

    test('keeps the type name of an instance and opens it through toJson', () {
      final ValueNode node = captureValue(Account(7));

      expect(node.className, 'Account');
      expect(node.children?.first.key, 'id');
      expect(node.children?.first.value.value, '7');
      expect(captureValue(Account(7), const CaptureOptions(expandToJson: false)).children, isNull);
    });

    test('shows an object that cannot be opened by what it says about itself', () {
      expect(captureValue(const Plain()).value, isNull);
      expect(captureValue(const Described()).value, 'Described(all of it)');
    });

    test('captures errors with their message and their stack', () {
      late ValueNode node;

      try {
        throw StateError('broken');
      } on StateError catch (error, stack) {
        node = captureValue(error).copyWith(stack: stack.toString());
      }

      expect(node.kind, ValueKind.error);
      expect(node.className, 'StateError');
      expect(node.value, 'broken');
      expect(node.stack, isNotEmpty);
      expect(captureValue(const FormatException('bad')).value, 'bad');
    });

    test('survives a toJson that throws', () {
      expect(() => captureValue(_Hostile()), returnsNormally);
      expect(captureValue(_Hostile()).className, '_Hostile');
    });
  });

  group('format specifiers', () {
    test('applies %s, %d, %i and %f the way the Console Standard describes', () {
      final FormattedMessage formatted = applyFormat(<Object?>[
        '%s|%d|%i|%f|%%',
        'text',
        '42.9',
        -1.5,
        '3.25',
        'extra',
      ], capture);

      expect(textOf(formatted.parts), 'text|42|-1|3.25|%');
      expect(formatted.rest, <Object?>['extra']);
    });

    test('inserts values for %o and %O and leaves specifiers without arguments as written', () {
      final FormattedMessage formatted = applyFormat(<Object?>[
        'a %o b %O c %s',
        <String, int>{'x': 1},
        <int>[1],
      ], capture);

      expect(textOf(formatted.parts), 'a <map> b <list> c %s');
    });

    test('styles the text after %c with the allowed properties only', () {
      final FormattedMessage formatted = applyFormat(<Object?>[
        '%cred%c plain',
        'color: red; background: url(https://example.com/x.png) #000; font-weight: bold',
        '',
      ], capture);
      final TextPart first = formatted.parts.first as TextPart;

      expect(first.text, 'red');
      expect(first.style?.color, const RgbTextColor(0xffff0000));
      expect(first.style?.background, const RgbTextColor(0xff000000));
      expect(first.style?.bold, isTrue);
      expect((formatted.parts[1] as TextPart).style, isNull);
    });

    test('rejects colors that could load a resource', () {
      expect(parseCssColor('rgb(1 2 3 / 50%)'), isNotNull);
      expect(parseCssColor('url(x)'), isNull);
      expect(parseConsoleCss('color: url(x)'), isNull);
    });

    test('joins the remaining arguments with spaces', () {
      expect(
        textOf(formatArguments(<Object?>['count', 3, 'items'], capture)),
        'count <number> items',
      );
      expect(textOf(formatArguments(<Object?>['%d%%', 50, 'done'], capture)), '50% done');
      expect(textOf(formatArguments(<Object?>['only %s'], capture)), 'only %s');
    });
  });

  group('LognalConsole', () {
    test('records levels and group membership', () {
      final LogStore store = LogStore();
      final LognalConsole log = LognalConsole(store);

      log.group('outer');
      log.warn('inside');
      log.groupEnd();
      log.error('outside');

      final List<LogEntry> entries = store.toList();

      expect(entries[0].kind, LogKind.group);
      expect(entries[0].collapsed, isFalse);
      expect(entries[1].level, LogLevel.warn);
      expect(entries[1].groups, <int>[entries[0].id]);
      expect(entries[2].level, LogLevel.error);
      expect(entries[2].groups, isEmpty);
    });

    test('counts, resets counts and warns about a missing counter', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: RepeatMode.keep),
      );
      final LognalConsole log = LognalConsole(store);

      log.count('clicks');
      log.count('clicks');
      log.countReset('clicks');
      log.count('clicks');
      log.countReset('other');

      expect(store.toList().map((LogEntry entry) => textOf(entry.parts)).toList(), <String>[
        'clicks: 1',
        'clicks: 2',
        'clicks: 1',
        "Count for 'other' does not exist",
      ]);
    });

    test('measures timers and warns about a missing one', () {
      final LogStore store = LogStore();
      final LognalConsole log = LognalConsole(store);

      log.time('load');
      log.timeEnd('load');
      log.timeEnd('load');

      final List<String> texts = store
          .toList()
          .map((LogEntry entry) => textOf(entry.parts))
          .toList();

      expect(texts.first, startsWith('load: '));
      expect(texts.first, endsWith(' ms'));
      expect(texts[1], "Timer 'load' does not exist");
    });

    test('writes assertion failures the way the standard describes', () {
      final LogStore store = LogStore(
        options: const LogStoreOptions(mergeRepeats: RepeatMode.keep),
      );
      final LognalConsole log = LognalConsole(store);

      log.assertCondition(true, <Object?>['not shown']);
      log.assertCondition(false);
      log.assertCondition(false, <Object?>['value is %d', 3]);
      log.assertCondition(false, <Object?>[
        <String, int>{'code': 1},
      ]);

      expect(store.toList().map((LogEntry entry) => textOf(entry.parts)).toList(), <String>[
        'Assertion failed',
        'Assertion failed: value is 3',
        'Assertion failed <map>',
      ]);
    });

    test('draws a table that lines up wide characters', () {
      final LogStore store = LogStore();

      LognalConsole(store).table(<Map<String, Object?>>[
        <String, Object?>{'name': '김철수', 'age': 30},
        <String, Object?>{'name': 'Ann'},
      ]);

      final List<String> lines = textOf(lastEntry(store).parts).split('\n');
      final Set<int> widths = lines.map((String line) {
        return line.runes.fold<int>(
          0,
          (int sum, int rune) => sum + (rune >= 0xac00 && rune <= 0xd7a3 ? 2 : 1),
        );
      }).toSet();

      expect(lines[1], contains('(index)'));
      expect(widths, hasLength(1));
    });

    test('clears the store and notes it', () {
      final LogStore store = LogStore();
      final LognalConsole log = LognalConsole(store);

      log.log('before');
      log.clear();

      expect(store.size, 1);
      expect(lastEntry(store).kind, LogKind.system);
    });

    test('adds the stack of trace', () {
      final LogStore store = LogStore();

      LognalConsole(store).trace('here');

      final String text = textOf(lastEntry(store).parts);

      expect(text, startsWith('here\n'));
      expect(text, contains('console_test.dart'));
    });
  });

  group('hookDebugPrint', () {
    test('records calls, still runs the original and restores it', () {
      final List<String?> printed = <String?>[];
      final DebugPrintCallback original = debugPrint;
      final LogStore store = LogStore();

      debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);

      final DebugPrintCallback ours = debugPrint;
      final void Function() unhook = hookDebugPrint(store);

      debugPrint('hello');
      unhook();
      debugPrint('after');

      expect(printed, <String?>['hello', 'after']);
      expect(store.size, 1);
      expect(debugPrint, same(ours));

      debugPrint = original;
    });

    test('leaves a later wrapper in place and stops recording', () {
      final DebugPrintCallback original = debugPrint;
      final LogStore store = LogStore();
      final void Function() unhook = hookDebugPrint(
        store,
        options: const HookOptions(passthrough: false),
      );
      final DebugPrintCallback ours = debugPrint;

      void later(String? message, {int? wrapWidth}) => ours(message, wrapWidth: wrapWidth);

      debugPrint = later;
      unhook();
      debugPrint('ignored');

      expect(debugPrint, same(later));
      expect(store.size, 0);

      debugPrint = original;
    });

    test('runs code in a zone whose print reaches the store', () {
      final LogStore store = LogStore();

      runZonedWithLognal(store, () {
        // ignore: avoid_print
        print('from the zone');
      }, options: const HookOptions(passthrough: false));

      expect(store.size, 1);
      expect(textOf(store.at(0)!.parts), 'from the zone');
    });
  });
}

class _Hostile {
  Map<String, Object?> toJson() => throw StateError('no');
}
