import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/lognal.dart';
import 'package:lognal/src/viewer/controller.dart' show paddingTop;
import 'package:lognal/src/viewer/controls.dart' show LognalField;
import 'package:lognal/src/viewer/log_painter.dart';
import 'package:lognal/src/viewer/toolbar.dart' show LognalToolbar, filterDelay;

/// The painted log, which is what the pointer and the clip are tested through.
final Finder logSurface = find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is LogPainter,
);

/// What the pointer looks like over the log.
MouseCursor cursorOverLog(WidgetTester tester) {
  return tester
      .widget<MouseRegion>(find.ancestor(of: logSurface, matching: find.byType(MouseRegion)).first)
      .cursor;
}

/// A viewer in an application with no navigator, which is the hardest host the
/// widget has to work in.
///
/// Wide enough for the whole toolbar, which takes more room here than on a
/// screen: the font a widget test draws with puts every character in a square,
/// so a word is about twice as wide as it would really be.
Widget host(Widget child, {Size size = const Size(720, 360)}) {
  return WidgetsApp(
    color: const Color(0xff000000),
    builder: (BuildContext context, Widget? _) => Center(
      child: SizedBox(width: size.width, height: size.height, child: child),
    ),
  );
}

void main() {
  testWidgets('draws the toolbar, the log and the status bar', (WidgetTester tester) async {
    final LogStore store = LogStore();

    store.write('first message');
    await tester.pumpWidget(host(LogViewer(store: store)));
    await tester.pump();

    expect(find.byType(LogViewer), findsOneWidget);
    // The status bar counts what the log holds.
    expect(find.text('1 entry'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('shows the Korean labels for a Korean locale', (WidgetTester tester) async {
    await tester.pumpWidget(host(const LogViewer(options: LogViewerOptions(locale: 'ko'))));
    await tester.pump();

    expect(find.text('따라가는 중'), findsOneWidget);
    expect(find.text('로그 0개'), findsOneWidget);
  });

  testWidgets('leaves the toolbar, the status bar and the input out when asked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const LogViewer(
          options: LogViewerOptions(toolbar: ViewerToolbarOptions.hidden, statusBar: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Following'), findsNothing);
    // No toolbar filter and no input line, so nothing here takes text.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('the toolbar goes onto a second line rather than off a narrow viewer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const LogViewer()));
    await tester.pump();

    final double oneLine = tester.getSize(find.byType(LognalToolbar)).height;

    await tester.pumpWidget(host(const LogViewer(), size: const Size(380, 320)));
    await tester.pump();

    // A row that ran off the edge would be reported as an overflow and fail
    // this test on its own. What is left to say is that nothing was dropped and
    // that the bar took the second line it needed.
    expect(find.text('All levels'), findsOneWidget);
    expect(tester.getSize(find.byType(LognalToolbar)).height, greaterThan(oneLine));
    // Two short lines do not make the bar itself short: it is as wide as the
    // viewer it sits at the top of.
    expect(
      tester.getSize(find.byType(LognalToolbar)).width,
      tester.getSize(find.byType(LogViewer)).width,
    );
  });

  testWidgets('follows new entries and counts them', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    for (int index = 0; index < 200; index++) {
      controller.write('line $index');
    }

    await tester.pump();

    expect(controller.isFollowing, isTrue);
    expect(controller.store.size, 200);
    expect(find.text('200 entries'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('a wheel scroll stops following and the button brings it back', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    for (int index = 0; index < 500; index++) {
      controller.write('line $index');
    }

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();
    expect(controller.isFollowing, isTrue);

    final Offset centre = tester.getCenter(find.byType(LogViewer));
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);

    pointer.hover(centre);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -600)));
    await tester.pump();

    expect(controller.isFollowing, isFalse);
    expect(controller.topPixels, lessThan(controller.maxTopPixels));

    controller.scrollToBottom();
    await tester.pump();
    expect(controller.isFollowing, isTrue);

    controller.dispose();
  });

  testWidgets('the filter field hides what does not match', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    controller
      ..write('cache miss')
      ..write('disk full');

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();
    expect(find.text('2 entries'), findsOneWidget);

    controller.setFilter(const LogFilter(text: 'cache'));
    await tester.pump();

    expect(find.text('1 of 2 entries'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('a filter that shortens the log brings the view back inside it', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    for (int index = 0; index < 2000; index++) {
      controller.write(index == 7 ? 'needle here' : 'line $index');
    }

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();
    expect(controller.topPixels, controller.maxTopPixels);

    controller.setFilter(const LogFilter(text: 'needle'));
    await tester.pump();

    // The one row left is far above where the view was, and nothing but the
    // frame knows how short the log has become.
    expect(controller.frame().rows, isNotEmpty);
    expect(controller.topPixels, 0);

    controller.dispose();
  });

  testWidgets('the search bar opens with a query and counts the matches', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    controller
      ..write('error one')
      ..write('nothing')
      ..write('error two');

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    controller.openSearch('error');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(controller.search.count, 2);
    expect(find.text('0/2'), findsOneWidget);

    controller.findNext();
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);

    controller.closeSearch();
    await tester.pump();
    expect(find.text('1/2'), findsNothing);

    controller.dispose();
  });

  testWidgets('a tap opens the value under it', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    controller.store.add(
      LogEntryInit(
        parts: <LogPart>[
          ValuePart(captureValue(<String, int>{'id': 1})),
        ],
      ),
    );

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();
    expect(controller.layout.rowCount, 1);

    // The expander sits in the first two cells of the first row.
    final Offset origin = tester.getTopLeft(find.byType(LogViewer));
    final double x = origin.dx + controller.contentLeft + controller.metrics.width;
    final double y = origin.dy + 40 + paddingTop + controller.metrics.height / 2;

    await tester.tapAt(Offset(x, y));
    // Past the double-tap window, so the recognizer has no timer left running.
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.layout.rowCount, 2);

    controller.dispose();
  });

  testWidgets('the log is cut off at the edges of the surface it is drawn in', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    for (int index = 0; index < 200; index++) {
      controller.write('line $index');
    }

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    // A scroll leaves the first row on screen starting above the top of it, and
    // the canvas belongs to the application, so without this clip the row lands
    // on the toolbar.
    expect(
      tester.renderObject(logSurface),
      paints..clipRect(rect: Offset.zero & tester.getSize(logSurface)),
    );

    controller.dispose();
  });

  testWidgets('the text of a row is centred in it, with the marks beside it', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    controller.write('centred');
    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    final double rowHeight = controller.metrics.height;

    expect(
      tester.renderObject(logSurface),
      paints..something((Symbol method, List<dynamic> arguments) {
        if (method != #drawParagraph) {
          return false;
        }

        final ui.Paragraph paragraph = arguments[0] as ui.Paragraph;
        final Offset offset = arguments[1] as Offset;
        // The line the font draws is shorter than the row it sits on, so half
        // of what is left over goes above it. The level marks and the
        // expanders are drawn on the middle of the row, and this is what puts
        // the text beside them rather than above them.
        final double expected = paddingTop + (rowHeight - paragraph.height) / 2;

        return (offset.dy - expected).abs() <= 1;
      }),
    );

    controller.dispose();
  });

  testWidgets('the input line echoes a command and prints the reply', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();
    final List<String> commands = <String>[];

    await tester.pumpWidget(
      host(
        LogViewer(
          controller: controller,
          options: LogViewerOptions(
            input: InputOptions(
              onSubmit: (String command) {
                commands.add(command);

                return 'pong';
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder field = find.byType(EditableText).last;

    await tester.enterText(field, 'ping');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(commands, <String>['ping']);
    expect(controller.store.size, 2);
    expect(controller.store.at(0)?.kind, LogKind.input);
    expect(controller.store.at(1)?.kind, LogKind.output);

    controller.dispose();
  });

  testWidgets('entry mode selects whole entries and copies them', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    controller
      ..write('one')
      ..write('two');

    await tester.pumpWidget(
      host(
        LogViewer(
          controller: controller,
          options: const LogViewerOptions(selectionMode: SelectionMode.entry),
        ),
      ),
    );
    await tester.pump();

    controller.selectAll();
    await tester.pump();

    expect(controller.selectedEntries, <int>{1, 2});
    expect(find.text('2 entries selected'), findsOneWidget);
    expect(controller.selectionText(), 'one\ntwo');

    controller.dispose();
  });

  testWidgets('the level menu stays open while levels are added and taken away', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    controller
      ..write('a quiet line')
      ..write('a loud one', const WriteOptions(level: LogLevel.error))
      ..write('a careful one', const WriteOptions(level: LogLevel.warn));

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    // The application around the viewer has no navigator, which is the case a
    // menu of the framework's own could not serve.
    expect(find.byType(Navigator), findsNothing);

    await tester.tap(find.text('All levels'));
    await tester.pumpAndSettle();
    expect(find.text('Error'), findsOneWidget);

    await tester.tap(find.text('Error'));
    await tester.pumpAndSettle();

    expect(controller.filter?.levels, <LogLevel>[LogLevel.error]);
    expect(find.text('1 of 3 entries'), findsOneWidget);
    // Levels are a set, so the menu is still there with the next one a press
    // away. "Error" is on the button as well by now.
    expect(find.text('Warning'), findsOneWidget);

    await tester.tap(find.text('Warning'));
    await tester.pumpAndSettle();

    expect(controller.filter?.levels, <LogLevel>[LogLevel.warn, LogLevel.error]);
    expect(find.text('2 of 3 entries'), findsOneWidget);

    await tester.tapAt(tester.getBottomLeft(find.byType(LogViewer)) - const Offset(-8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Warning'), findsNothing);

    controller.dispose();
  });

  testWidgets('a press outside a menu closes it and chooses nothing', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    await tester.tap(find.text('All levels'));
    await tester.pumpAndSettle();
    expect(find.text('Error'), findsOneWidget);

    await tester.tapAt(tester.getBottomLeft(find.byType(LogViewer)) - const Offset(-8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsNothing);
    expect(controller.filter?.levels, isNull);

    controller.dispose();
  });

  testWidgets('a right press on an entry opens its menu', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    controller.write('right click me');
    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    final Offset origin = tester.getTopLeft(find.byType(LogViewer));
    final Offset row = origin + Offset(controller.contentLeft + 8, 40 + paddingTop + 4);
    final TestGesture gesture = await tester.startGesture(
      row,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Copy as text'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('a tap on a link asks before it opens', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();
    final List<String> opened = <String>[];

    controller.write('see https://example.com now');
    await tester.pumpWidget(
      host(
        LogViewer(
          controller: controller,
          options: LogViewerOptions(onOpenLink: opened.add),
        ),
      ),
    );
    await tester.pump();

    // Into the address itself, which starts at the fifth cell of the row.
    final Offset origin = tester.getTopLeft(find.byType(LogViewer));
    final double x = origin.dx + controller.contentLeft + controller.metrics.width * 6;
    final double y = origin.dy + 40 + paddingTop + controller.metrics.height / 2;

    await tester.tapAt(Offset(x, y));
    await tester.pumpAndSettle();
    expect(find.text('Open this link?'), findsOneWidget);
    expect(opened, isEmpty);

    // The sentence under the title runs onto a second line rather than losing
    // its end to an ellipsis.
    expect(tester.getSize(find.textContaining('Check the address')).height, greaterThan(20));

    await tester.tap(find.text('Open link'));
    await tester.pumpAndSettle();

    expect(opened, <String>['https://example.com']);
    expect(find.text('Open this link?'), findsNothing);

    controller.dispose();
  });

  testWidgets('the pointer over the log says what a press there would do', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    controller.write('see https://example.com now');
    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    final Offset origin = tester.getTopLeft(find.byType(LogViewer));
    final double row = origin.dy + 40 + paddingTop + controller.metrics.height / 2;
    final TestGesture pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);

    await pointer.addPointer(location: Offset(origin.dx + controller.contentLeft, row));
    addTearDown(pointer.removePointer);
    await tester.pump();
    expect(cursorOverLog(tester), SystemMouseCursors.text);

    // Over the address, where a press opens the link rather than starting a
    // selection.
    await pointer.moveTo(
      Offset(origin.dx + controller.contentLeft + controller.metrics.width * 6, row),
    );
    await tester.pump();
    expect(cursorOverLog(tester), SystemMouseCursors.click);

    controller.dispose();
  });

  testWidgets('the pointer picks entries out rather than reading them in entry mode', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    controller.write('one');
    await tester.pumpWidget(
      host(
        LogViewer(
          controller: controller,
          options: const LogViewerOptions(selectionMode: SelectionMode.entry),
        ),
      ),
    );
    await tester.pump();

    expect(cursorOverLog(tester), SystemMouseCursors.basic);

    controller.dispose();
  });

  testWidgets('the theme menu changes the palette', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    expect(controller.themeName, 'auto');

    await tester.tap(find.bySemanticsLabel('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(controller.themeName, 'dark');

    controller.setTheme('ember');
    await tester.pump();

    expect(controller.themeName, 'ember');
    expect(
      controller.options.resolveTheme('ember', Brightness.light).renderer.background,
      emberTheme.renderer.background,
    );

    controller.dispose();
  });

  testWidgets('a mute rule keeps entries out and the toolbar counts them', (
    WidgetTester tester,
  ) async {
    final LogViewerController controller = LogViewerController();

    controller
      ..write('GET /health')
      ..write('boot done')
      ..write('GET /health');

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    controller.setMuteRules(<MuteRule>[const MuteRule(text: '/health')]);
    await tester.pump();

    expect(controller.mutedCount, 2);
    expect(find.text('1 of 3 entries'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Hidden messages')));
    await tester.pumpAndSettle();
    expect(find.text('/health'), findsOneWidget);

    // A rule is edited where it stands: its text, whether letter case counts
    // and whether the text is a regular expression.
    await tester.tap(find.bySemanticsLabel('Use regular expression'));
    await tester.pumpAndSettle();
    expect(controller.muteRules.single.regex, isTrue);

    await tester.tap(find.bySemanticsLabel('Match case'));
    await tester.pumpAndSettle();
    expect(controller.muteRules.single.caseSensitive, isTrue);

    await tester.enterText(
      find.descendant(of: find.byType(ListView), matching: find.byType(EditableText)),
      '^GET',
    );
    // Past the wait an edited rule takes before it is applied.
    await tester.pump(filterDelay * 2);
    await tester.pumpAndSettle();
    expect(controller.muteRules.single.text, '^GET');
    expect(controller.mutedCount, 2);

    // A pattern that does not compile is marked in the color the log draws an
    // error in, which is what tells it apart from a field that is merely in
    // focus.
    await tester.enterText(
      find.descendant(of: find.byType(ListView), matching: find.byType(EditableText)),
      '^GET[',
    );
    await tester.pump(filterDelay * 2);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LognalField>(
            find.descendant(of: find.byType(ListView), matching: find.byType(LognalField)),
          )
          .invalid,
      isTrue,
    );
    expect(controller.mutedCount, 0);

    await tester.tap(find.bySemanticsLabel('Remove'));
    await tester.pumpAndSettle();
    expect(controller.muteRules, isEmpty);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing is hidden yet.'), findsNothing);

    controller.dispose();
  });
}
