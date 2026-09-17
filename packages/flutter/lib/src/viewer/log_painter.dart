import 'package:flutter/widgets.dart';
import 'package:lognal/src/renderer/canvas_renderer.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/viewer/controller.dart';

/// Paints the log through a renderer.
///
/// It repaints whenever the controller says so, which is once per change rather
/// than once per message: entries go into the store, and the next frame draws
/// whatever is there.
class LogPainter extends CustomPainter {
  /// Creates a painter.
  LogPainter({
    required this.controller,
    required this.renderer,
    required this.theme,
    required this.font,
  }) : super(repaint: controller);

  /// The viewer's state.
  final LogViewerController controller;

  /// What turns a frame into pixels.
  final CanvasLogRenderer renderer;

  /// The palette to draw with.
  final RenderTheme theme;

  /// The font to draw with.
  final FontSettings font;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.theme = theme;

    if (renderer.font != font) {
      renderer.setFont(font);
    }

    controller.setViewport(size, renderer.metrics);
    renderer.paint(canvas, size, controller.frame());
  }

  @override
  bool shouldRepaint(LogPainter old) {
    return old.controller != controller || old.theme != theme || old.font != font;
  }
}
