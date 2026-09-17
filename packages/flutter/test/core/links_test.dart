import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/src/core/layout/layout.dart';
import 'package:lognal/src/core/layout/types.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/text/links.dart';
import 'package:lognal/src/core/types.dart';

List<String> urls(String text) => findLinks(text).map((TextLink link) => link.url).toList();

void main() {
  group('findLinks', () {
    test('finds http and https addresses with their ranges', () {
      const String text =
          'Docs at https://lognal.cdget.com/guide/ and HTTP://EXAMPLE.COM:8080/a?b=1#c';
      final List<TextLink> links = findLinks(text);

      expect(links.map((TextLink link) => link.url).toList(), <String>[
        'https://lognal.cdget.com/guide/',
        'HTTP://EXAMPLE.COM:8080/a?b=1#c',
      ]);

      for (final TextLink link in links) {
        expect(link.start, text.indexOf(link.url));
        expect(text.substring(link.start, link.end), link.url);
      }
    });

    test('leaves out punctuation after an address and closing brackets without a pair', () {
      expect(urls('See https://example.com/a.'), <String>['https://example.com/a']);
      expect(urls('(see https://example.com/page)'), <String>['https://example.com/page']);
      expect(urls('https://en.wikipedia.org/wiki/Mercury_(planet), then'), <String>[
        'https://en.wikipedia.org/wiki/Mercury_(planet)',
      ]);
      expect(urls("url: 'https://example.com/q?x=1'"), <String>['https://example.com/q?x=1']);
      expect(urls('<https://example.com/>'), <String>['https://example.com/']);
      expect(urls('문서는 https://example.com/한글 에 있습니다.'), <String>['https://example.com/한글']);
      expect(urls('주소: https://example.com/문서。'), <String>['https://example.com/문서']);
    });

    test('ignores other schemes, a missing host and a scheme inside a word', () {
      expect(urls('ftp://example.com javascript:alert(1) mailto:user@example.com'), isEmpty);
      expect(urls('https:// and http:///path'), isEmpty);
      expect(urls('xhttps://example.com'), isEmpty);
    });

    test('ends an address before an invisible character and finds the address after it', () {
      final String override = String.fromCharCode(0x202e);
      final String zeroWidthSpace = String.fromCharCode(0x200b);

      expect(urls('https://example.com/${override}gpj.exe'), <String>['https://example.com/']);
      expect(urls('https://a.example${zeroWidthSpace}https://b.example'), <String>[
        'https://a.example',
        'https://b.example',
      ]);
    });
  });

  group('links in the layout', () {
    test('gives every address in text an action that opens it', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store);
      final LogEntry entry = store.write('Open https://example.com/docs now')!;

      layout.sync();

      final VisualRow row = layout.getRows(0, 1).first;

      expect(row.runs.map((RowRun run) => run.text).toList(), <String>[
        'Open ',
        'https://example.com/docs',
        ' now',
      ]);
      expect(row.runs.map((RowRun run) => run.action is OpenLinkAction).toList(), <bool>[
        false,
        true,
        false,
      ]);
      expect(layout.linksOf(entry.id), <String>['https://example.com/docs']);
    });

    test('keeps the rows when links are turned off, and lists each address once', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store, options: const LayoutOptions(wrap: WrapMode.char));
      final LogEntry entry = store.write(
        'https://example.com/a https://example.com/b https://example.com/a ' * 4,
      )!;

      layout.columns = 40;
      layout.sync();

      final int rows = layout.rowCount;

      expect(layout.linksOf(entry.id), <String>['https://example.com/a', 'https://example.com/b']);

      layout.options = layout.options.copyWith(links: false);
      layout.sync();

      expect(layout.rowCount, rows);
      expect(
        layout
            .getRows(0, rows)
            .every((VisualRow row) => row.runs.every((RowRun run) => run.action == null)),
        isTrue,
      );
      expect(layout.linksOf(entry.id), isEmpty);
    });

    test('links an address in the rows of an open value, not in the preview that opens it', () {
      final LogStore store = LogStore();
      final LogLayout layout = LogLayout(store);
      const ValueNode value = ValueNode(
        kind: ValueKind.object,
        children: <ValueEntry>[
          ValueEntry(
            key: 'url',
            keyKind: ValueKeyKind.property,
            value: ValueNode(kind: ValueKind.string, value: 'https://example.com/x'),
          ),
        ],
      );
      final LogEntry entry = store.add(const LogEntryInit(parts: <LogPart>[ValuePart(value)]))!;

      layout.sync();
      expect(layout.linksOf(entry.id), isEmpty);

      layout.setExpanded(entry, '0', true);
      layout.sync();

      final VisualRow child = layout.getRows(0, 2)[1];

      expect(layout.linksOf(entry.id), <String>['https://example.com/x']);
      expect(
        child.runs.firstWhere((RowRun run) => run.action is OpenLinkAction).text,
        'https://example.com/x',
      );
    });
  });
}
