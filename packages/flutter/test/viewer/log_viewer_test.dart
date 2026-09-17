import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lognal/lognal.dart';
import 'package:lognal/src/viewer/controller.dart' show paddingTop;
import 'package:lognal/src/viewer/log_painter.dart';

Widget host(Widget child, {Size size = const Size(640, 360)}) {
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
    final Finder surface = find.byWidgetPredicate(
      (Widget widget) => widget is CustomPaint && widget.painter is LogPainter,
    );

    expect(
      tester.renderObject(surface),
      paints..clipRect(rect: Offset.zero & tester.getSize(surface)),
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

    final Finder surface = find.byWidgetPredicate(
      (Widget widget) => widget is CustomPaint && widget.painter is LogPainter,
    );
    final double rowHeight = controller.metrics.height;

    expect(
      tester.renderObject(surface),
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

  testWidgets('the theme menu changes the palette', (WidgetTester tester) async {
    final LogViewerController controller = LogViewerController();

    await tester.pumpWidget(host(LogViewer(controller: controller)));
    await tester.pump();

    expect(controller.themeName, 'auto');

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

    controller.dispose();
  });
}
