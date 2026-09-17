import 'package:flutter/widgets.dart';

/// Path data for the icons of the viewer, drawn on a 16 by 16 grid with a 1.5
/// stroke — the same drawings the JavaScript package inlines as SVG.
enum LognalIcon {
  /// An arrow down onto a line: follow new logs.
  follow('M8 2.75v7.5M4.75 7 8 10.25 11.25 7M3.5 13.25h9'),

  /// A circle with a stroke through it: clear.
  clear('M8 2.75a5.25 5.25 0 1 0 0 10.5 5.25 5.25 0 0 0 0-10.5ZM4.3 11.7l7.4-7.4'),

  /// An arrow up to a line: scroll to top.
  top('M3.5 2.75h9M8 13.25v-7.5M4.75 9 8 5.75 11.25 9'),

  /// An arrow down to a line: scroll to bottom.
  bottom('M3.5 13.25h9M8 2.75v7.5M4.75 7 8 10.25 11.25 7'),

  /// A line that turns back on itself: wrap.
  wrap('M2.75 4h10.5M2.75 8h8.5a2 2 0 0 1 0 4H8.5M10 10.5 8.5 12l1.5 1.5M2.75 12h3'),

  /// A magnifying glass: search and filter.
  search('M7 2.75a4.25 4.25 0 1 0 0 8.5 4.25 4.25 0 0 0 0-8.5ZM10.25 10.25l3 3'),

  /// A chevron pointing down: a menu opens below.
  chevronDown('M4.75 6.5 8 9.75l3.25-3.25'),

  /// A chevron pointing up.
  chevronUp('M4.75 9.5 8 6.25l3.25 3.25'),

  /// A cross: close.
  close('M4.25 4.25l7.5 7.5M11.75 4.25l-7.5 7.5'),

  /// A tick: the chosen item of a menu.
  check('M3.75 8.25 6.5 11l5.75-6'),

  /// Three dots: the menu of an entry.
  more(
    'M8 4.5a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5ZM8 8.75a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 '
    '1.5ZM8 13a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z',
  ),

  /// Two overlapping sheets: copy.
  copy('M5.75 5.75h6.5v6.5h-6.5ZM3.75 10.25v-6.5h6.5'),

  /// A clock: copy with the timestamp.
  clock('M8 2.75a5.25 5.25 0 1 0 0 10.5 5.25 5.25 0 0 0 0-10.5ZM8 5.25V8l1.75 1.25'),

  /// Two angle brackets: formatted text.
  code('M5.5 4.75 2.25 8l3.25 3.25M10.5 4.75 13.75 8l-3.25 3.25'),

  /// Two arrows apart: expand all.
  expandAll('M4.75 5.75 8 2.5l3.25 3.25M4.75 10.25 8 13.5l3.25-3.25'),

  /// Two arrows together: collapse all.
  collapseAll('M4.75 2.5 8 5.75l3.25-3.25M4.75 13.5 8 10.25l3.25 3.25'),

  /// A block over two lines: select whole entries.
  selectEntries(
    'M3.25 2.75h9.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5h-9.5a.5.5 0 0 1-.5-.5v-3a.5.5 0 0 1 '
    '.5-.5ZM2.75 10h10.5M2.75 13.25h10.5',
  ),

  /// Two links of a chain: a web address.
  link(
    'M6.75 9.25a2.75 2.75 0 0 0 3.9 0l2-2a2.75 2.75 0 0 0-3.9-3.9l-.6.6M9.25 6.75a2.75 2.75 '
    '0 0 0-3.9 0l-2 2a2.75 2.75 0 0 0 3.9 3.9l.6-.6',
  ),

  /// An eye with a stroke through it: hidden messages.
  mute(
    'M2.75 2.75l10.5 10.5M6.2 4.05A6.3 6.3 0 0 1 8 3.8c3 0 5.25 2.4 6.25 4.2a9.3 9.3 0 0 '
    '1-1.9 2.3M9.6 9.7a2 2 0 0 1-2.8-2.8M4.4 5.3A9.6 9.6 0 0 0 1.75 8c1 1.8 3.25 4.2 6.25 '
    '4.2.8 0 1.5-.15 2.15-.4',
  ),

  /// A circle half filled: the theme menu.
  theme(
    'M8 2.75a5.25 5.25 0 1 0 0 10.5 5.25 5.25 0 0 0 0-10.5ZM8 2.75v10.5M10.5 4.6 4.6 '
    '10.5M11.25 7.35 7.35 11.25M9.4 3.3 3.3 9.4',
  ),

  /// A pair of braces: data.
  braces(
    'M6 2.75h-.5a1.5 1.5 0 0 0-1.5 1.5v2.25L2.75 8 4 9.5v2.25a1.5 1.5 0 0 0 1.5 1.5h.5M10 '
    '2.75h.5a1.5 1.5 0 0 1 1.5 1.5v2.25L13.25 8 12 9.5v2.25a1.5 1.5 0 0 1-1.5 1.5H10',
  ),

  /// The letter A, for matching letter case.
  matchCase('M3.25 12.5 7 3.5l3.75 9M4.6 9.5h4.8M12.5 12.5v-5'),

  /// A full stop and a star, for a regular expression.
  regex('M8 3.5v5M5.6 4.9l4.8 2.8M10.4 4.9 5.6 7.7M4 12.25h1.5');

  const LognalIcon(this.path);

  /// The SVG path data of the icon, on a 16 by 16 grid.
  final String path;
}

/// Draws one of the viewer's icons, stroked in the current color.
class LognalIconPainter extends CustomPainter {
  /// Creates a painter for an icon.
  const LognalIconPainter({required this.icon, required this.color, this.strokeWidth = 1.5});

  /// Which icon to draw.
  final LognalIcon icon;

  /// The color to stroke it in.
  final Color color;

  /// The width of the stroke, on the 16 by 16 grid.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 16;

    canvas
      ..save()
      ..scale(scale)
      ..drawPath(
        parseIconPath(icon.path),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(LognalIconPainter old) {
    return old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
  }
}

/// An icon at a size, as a widget.
class LognalIconView extends StatelessWidget {
  /// Creates the widget.
  const LognalIconView({required this.icon, required this.color, this.size = 16, super.key});

  /// Which icon to draw.
  final LognalIcon icon;

  /// The color to stroke it in.
  final Color color;

  /// The width and height of the icon.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: LognalIconPainter(icon: icon, color: color),
      ),
    );
  }
}

/// One command letter, or one number.
///
/// The number half is the grammar's own rather than `[\d.]+`: SVG lets numbers
/// run together, so `a.75.75` is two of them and a greedy match would read it as
/// one.
final RegExp _command = RegExp(
  r'([MmLlHhVvAaZzCcSsQqTt])|([-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?)',
);

/// Reads the subset of SVG path data the icons above are written in.
///
/// Move, line, horizontal and vertical line, cubic curve and arc, in the
/// absolute and relative forms, which is every command these twenty-odd
/// drawings use. Anything else is ignored rather than guessed at.
Path parseIconPath(String data) {
  final Path path = Path();
  final List<String> tokens = _command
      .allMatches(data)
      .map((RegExpMatch match) => match.group(0)!)
      .toList();
  double x = 0;
  double y = 0;
  double startX = 0;
  double startY = 0;
  String command = 'M';
  int index = 0;

  double number() => double.parse(tokens[index++]);

  while (index < tokens.length) {
    final String token = tokens[index];

    if (RegExp('^[A-Za-z]').hasMatch(token)) {
      command = token;
      index++;

      if (command == 'Z' || command == 'z') {
        path.close();
        x = startX;
        y = startY;
        continue;
      }
    }

    final bool relative = command.toLowerCase() == command;

    switch (command.toUpperCase()) {
      case 'M':
        final double dx = number();
        final double dy = number();

        x = relative ? x + dx : dx;
        y = relative ? y + dy : dy;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        // Every pair after the first is a line, the way SVG reads it.
        command = relative ? 'l' : 'L';
      case 'L':
        final double dx = number();
        final double dy = number();

        x = relative ? x + dx : dx;
        y = relative ? y + dy : dy;
        path.lineTo(x, y);
      case 'H':
        final double dx = number();

        x = relative ? x + dx : dx;
        path.lineTo(x, y);
      case 'V':
        final double dy = number();

        y = relative ? y + dy : dy;
        path.lineTo(x, y);
      case 'C':
        final double x1 = number();
        final double y1 = number();
        final double x2 = number();
        final double y2 = number();
        final double dx = number();
        final double dy = number();

        path.cubicTo(
          relative ? x + x1 : x1,
          relative ? y + y1 : y1,
          relative ? x + x2 : x2,
          relative ? y + y2 : y2,
          relative ? x + dx : dx,
          relative ? y + dy : dy,
        );
        x = relative ? x + dx : dx;
        y = relative ? y + dy : dy;
      case 'A':
        final double rx = number();
        final double ry = number();
        final double rotation = number();
        final bool largeArc = number() != 0;
        final bool clockwise = number() != 0;
        final double dx = number();
        final double dy = number();

        x = relative ? x + dx : dx;
        y = relative ? y + dy : dy;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: clockwise,
        );
      default:
        index++;
    }
  }

  return path;
}
