import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/core/value/data.dart';
import 'package:lognal/src/core/value/text.dart';
import 'package:lognal/src/sources/console/capture.dart';
import 'package:lognal/src/sources/console/console.dart';

String multiline(Object? value) {
  return formatValueText(captureValue(value), const ValueTextOptions(multiline: true));
}

String line(Object? value) => formatValueText(captureValue(value));

String data(Object? value) => formatJson(valueToJson(captureValue(value)));

class Account {
  const Account();

  Map<String, Object?> toJson() => <String, Object?>{'id': 7};
}

void main() {
  group('formatValueText', () {
    test('keeps every value on one line unless multiline is on', () {
      const Map<String, Object?> user = <String, Object?>{
        'id': 1,
        'roles': <String>['admin', 'editor'],
        'profile': <String, String>{'city': 'Seoul', 'zip': '04524'},
      };

      expect(
        line(user),
        "Map(3) { 'id': 1, 'roles': ['admin', 'editor'], "
        "'profile': Map(2) { 'city': 'Seoul', 'zip': '04524' } }",
      );
      expect(
        multiline(user),
        <String>[
          'Map(3) {',
          "  'id': 1,",
          "  'roles': ['admin', 'editor'],",
          "  'profile': Map(2) { 'city': 'Seoul', 'zip': '04524' }",
          '}',
        ].join('\n'),
      );
    });

    test('writes a short value on one line and a long one over several', () {
      expect(
        multiline(<String, Object?>{'id': 1, 'name': 'Ada'}),
        "Map(2) { 'id': 1, 'name': 'Ada' }",
      );
      expect(
        multiline(<String, Object?>{
          'id': 1,
          'name': 'Ada',
          'roles': <String>['admin', 'editor'],
          'profile': <String, Object?>{'city': 'Seoul', 'zip': '04524', 'verified': true},
        }),
        <String>[
          'Map(4) {',
          "  'id': 1,",
          "  'name': 'Ada',",
          "  'roles': ['admin', 'editor'],",
          "  'profile': Map(3) { 'city': 'Seoul', 'zip': '04524', 'verified': true }",
          '}',
        ].join('\n'),
      );
    });

    test('writes type names, sets and empty containers', () {
      expect(multiline(const Account()), 'Account { id: 7 }');
      expect(multiline(<String>{'x', 'y'}), "Set(2) { 'x', 'y' }");
      expect(multiline(<String, Object?>{}), 'Map(0) {}');
      expect(multiline(<Object?>[]), '[]');
    });

    test('writes leaves the way previews do, with strings in full', () {
      final String long = 'x' * 40;

      expect(
        multiline(<Object?>[null, -0.0, BigInt.from(10), RegExp('ab+c')]),
        '[null, -0.0, 10, /ab+c/]',
      );
      expect(multiline(<String, Object?>{'long': long}), "Map(1) { 'long': '$long' }");
      expect(
        multiline(<String, Object?>{'quote': "it's\nhere"}),
        "Map(1) { 'quote': 'it\\'s\\nhere' }",
      );
    });

    test('marks what the capture left out', () {
      const Map<String, Object?> deep = <String, Object?>{
        'deep': <String, Object?>{
          'deeper': <String, Object?>{
            'list': <int>[1, 2],
          },
        },
      };
      final Map<String, Object?> circular = <String, Object?>{};

      circular['self'] = circular;

      expect(
        formatValueText(captureValue(deep, const CaptureOptions(maxDepth: 2))),
        "Map(1) { 'deep': Map(1) { 'deeper': Map(1) {…} } }",
      );
      expect(multiline(circular), "Map(1) { 'self': [Circular] }");
      expect(
        formatValueText(captureValue(<int>[1, 2, 3], const CaptureOptions(maxProperties: 2))),
        '[1, 2, … 1 more]',
      );
    });

    test('writes an error with its stack trace and its properties', () {
      const ValueNode node = ValueNode(
        kind: ValueKind.error,
        className: 'StateError',
        value: 'Failed to load',
        stack: '    at load (app.dart:1:1)\n    at run (app.dart:2:1)',
        children: <ValueEntry>[
          ValueEntry(
            key: 'cause',
            keyKind: ValueKeyKind.property,
            value: ValueNode(
              kind: ValueKind.error,
              className: 'FormatException',
              value: 'Expected a string',
            ),
          ),
        ],
      );

      expect(
        formatValueText(node, const ValueTextOptions(multiline: true)),
        <String>[
          'StateError: Failed to load',
          '    at load (app.dart:1:1)',
          '    at run (app.dart:2:1) { cause: FormatException: Expected a string }',
        ].join('\n'),
      );
    });

    test('writes an element as markup', () {
      const ValueNode link = ValueNode(
        kind: ValueKind.element,
        value: 'a',
        attributes: <MapEntry<String, String>>[MapEntry<String, String>('href', '/')],
        children: <ValueEntry>[
          ValueEntry(
            value: ValueNode(kind: ValueKind.text, value: 'Home'),
          ),
        ],
      );
      const ValueNode nav = ValueNode(
        kind: ValueKind.element,
        value: 'nav',
        attributes: <MapEntry<String, String>>[MapEntry<String, String>('class', 'menu')],
        children: <ValueEntry>[
          ValueEntry(value: link),
          ValueEntry(
            value: ValueNode(
              kind: ValueKind.element,
              value: 'a',
              attributes: <MapEntry<String, String>>[MapEntry<String, String>('href', '/')],
            ),
          ),
        ],
      );

      expect(formatValueText(link), '<a href="/">Home</a>');
      expect(
        formatValueText(
          const ValueNode(
            kind: ValueKind.element,
            value: 'input',
            attributes: <MapEntry<String, String>>[MapEntry<String, String>('type', 'file')],
          ),
        ),
        '<input type="file">',
      );
      expect(formatValueText(nav), '<nav class="menu"><a href="/">Home</a><a href="/">…</a></nav>');
      expect(
        formatValueText(nav, const ValueTextOptions(multiline: true)),
        <String>[
          '<nav class="menu">',
          '  <a href="/">Home</a>',
          '  <a href="/">…</a>',
          '</nav>',
        ].join('\n'),
      );
    });
  });

  group('valueToJson and formatJson', () {
    test('writes maps, lists and sets as JSON', () {
      expect(
        data(<String, Object?>{
          'id': 1,
          'name': 'lognal',
          'roles': <String>['admin', 'editor'],
        }),
        '{ "id": 1, "name": "lognal", "roles": ["admin", "editor"] }',
      );
      expect(
        data(<String, Object?>{
          'id': 1,
          'name': 'lognal',
          'roles': <String>['admin', 'editor'],
          'profile': <String, Object?>{'city': 'Seoul', 'zip': '04524', 'verified': true},
        }),
        <String>[
          '{',
          '  "id": 1,',
          '  "name": "lognal",',
          '  "roles": ["admin", "editor"],',
          '  "profile": { "city": "Seoul", "zip": "04524", "verified": true }',
          '}',
        ].join('\n'),
      );
      expect(data(<int, String>{1: 'one'}), '[[1, "one"]]');
      expect(data(<String>{'x', 'y'}), '["x", "y"]');
    });

    test('writes values JSON has no type for as text', () {
      final Map<String, Object?> circular = <String, Object?>{};

      circular['self'] = circular;

      expect(
        jsonDecode(
          data(<Object?>[null, double.nan, BigInt.from(10), RegExp('ab+c'), DateTime.utc(1970)]),
        ),
        <Object?>[null, 'NaN', '10', '/ab+c/', '1970-01-01T00:00:00.000Z'],
      );
      expect(data(circular), '{ "self": "[Circular]" }');
      expect(
        formatJson(
          valueToJson(captureValue(<int>[1, 2, 3], const CaptureOptions(maxProperties: 2))),
        ),
        '[1, 2, "… 1 more"]',
      );
    });

    test('writes an error as an object with its name, message and stack', () {
      const ValueNode node = ValueNode(
        kind: ValueKind.error,
        className: 'FormatException',
        value: 'Expected a string',
        stack: '    at load (app.dart:1:1)',
        children: <ValueEntry>[
          ValueEntry(
            key: 'code',
            keyKind: ValueKeyKind.property,
            value: ValueNode(kind: ValueKind.number, value: '42'),
          ),
        ],
      );

      expect(jsonDecode(formatJson(valueToJson(node))), <String, Object?>{
        'name': 'FormatException',
        'message': 'Expected a string',
        'stack': 'at load (app.dart:1:1)',
        'code': 42,
      });
    });
  });

  group('formatEntryText', () {
    test('joins the text and the values of a logging call', () {
      final LogStore store = LogStore();
      final LognalConsole log = LognalConsole(store);

      log.log('user', <Object?>[
        <String, int>{'id': 1},
        'signed in',
      ]);

      expect(formatEntryText(store.at(0)!), "user Map(1) { 'id': 1 } signed in");
      expect(formatEntryData(store.at(0)!), '{ "id": 1 }');

      log.log('plain text');
      expect(formatEntryData(store.at(1)!), '"plain text"');

      log.log(
        <String, int>{'a': 1},
        <Object?>[
          <int>[2],
        ],
      );
      expect(formatEntryData(store.at(2)!), '[{ "a": 1 }, [2]]');
    });
  });
}
