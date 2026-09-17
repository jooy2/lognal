import 'dart:ui';

import 'package:lognal/src/core/types.dart';

const List<int> _cubeLevels = <int>[0, 95, 135, 175, 215, 255];

/// Returns the color for a [TextColor]. An [AnsiTextColor] from 0 to 15 comes
/// from the theme, 16 to 231 from the 6x6x6 color cube, and 232 to 255 from the
/// gray ramp. An [RgbTextColor] is used as it is.
Color resolveTextColor(TextColor color, List<Color> themeColors) {
  if (color is RgbTextColor) {
    return Color(color.value);
  }

  final int index = (color as AnsiTextColor).index;

  if (index < 16) {
    if (index < themeColors.length) {
      return themeColors[index];
    }

    return themeColors.length > 7 ? themeColors[7] : const Color(0xffffffff);
  }

  if (index < 232) {
    final int offset = index - 16;
    final int red = _cubeLevels[offset ~/ 36 % 6];
    final int green = _cubeLevels[offset ~/ 6 % 6];
    final int blue = _cubeLevels[offset % 6];

    return Color.fromARGB(255, red, green, blue);
  }

  final int gray = 8 + ((index > 255 ? 255 : index) - 232) * 10;

  return Color.fromARGB(255, gray, gray, gray);
}
