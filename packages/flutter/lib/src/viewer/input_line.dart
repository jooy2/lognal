import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/src/core/store.dart';
import 'package:lognal/src/core/types.dart';
import 'package:lognal/src/renderer/types.dart';
import 'package:lognal/src/theme/palettes.dart';
import 'package:lognal/src/viewer/controller.dart';
import 'package:lognal/src/viewer/controls.dart';
import 'package:lognal/src/viewer/labels.dart';
import 'package:lognal/src/viewer/options.dart';

/// The line under the log where a command is typed.
///
/// It is a real text field rather than something drawn on the canvas, which is
/// what makes an input method work: a Korean or Japanese keyboard composes into
/// the field, and the composing text is the field's, so Enter reaches the
/// command only once the composition is finished.
class LognalInputLine extends StatefulWidget {
  /// Creates the input line.
  const LognalInputLine({
    required this.controller,
    required this.options,
    required this.theme,
    required this.font,
    required this.labels,
    super.key,
  });

  /// The viewer's state.
  final LogViewerController controller;

  /// What answers the commands.
  final InputOptions options;

  /// The palette it is drawn from.
  final LognalTheme theme;

  /// The font the log is drawn with, which the field matches.
  final FontSettings font;

  /// The text of its parts.
  final ViewerLabels labels;

  @override
  State<LognalInputLine> createState() => _LognalInputLineState();
}

class _LognalInputLineState extends State<LognalInputLine> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'lognal input');
  final List<String> _history = <String>[];
  int _historyIndex = -1;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String command) {
    if (command.trim().isEmpty) {
      return;
    }

    _text.clear();
    _history.add(command);

    if (_history.length > widget.options.historySize) {
      _history.removeAt(0);
    }

    _historyIndex = -1;

    if (widget.options.echo) {
      widget.controller.write(command, const WriteOptions(kind: LogKind.input));
    }

    final Object? reply = widget.options.onSubmit(command);

    if (reply == null) {
      return;
    }

    if (reply is Future<Object?>) {
      unawaited(
        reply.then(_print).catchError((Object error) {
          _print(error, failed: true);
        }),
      );

      return;
    }

    _print(reply);
  }

  void _print(Object? value, {bool failed = false}) {
    if (!mounted || value == null) {
      return;
    }

    widget.controller.store.add(
      LogEntryInit(
        kind: LogKind.output,
        level: failed ? LogLevel.error : LogLevel.log,
        parts: <LogPart>[if (value is String) TextPart(value) else ValuePart(_capture(value))],
      ),
    );
  }

  ValueNode _capture(Object value) {
    return widget.controller.capture(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _recall(-1);

      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _recall(1);

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _recall(int step) {
    if (_history.isEmpty) {
      return;
    }

    final int next = _historyIndex < 0
        ? (step < 0 ? _history.length - 1 : -1)
        : (_historyIndex + step).clamp(-1, _history.length - 1);

    _historyIndex = next;
    _text.text = next < 0 ? '' : _history[next];
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final ChromeTheme chrome = widget.theme.chrome;
    final TextStyle style = TextStyle(
      color: chrome.foreground,
      fontFamily: widget.font.family,
      fontFamilyFallback: widget.font.fallbackFamilies,
      fontSize: widget.font.size,
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: chrome.background,
        border: Border(top: BorderSide(color: chrome.border)),
      ),
      child: Semantics(
        textField: true,
        label: widget.labels.input,
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                widget.options.prompt,
                style: style.copyWith(color: chrome.accent),
                textDirection: TextDirection.ltr,
              ),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: _onKey,
                child: LognalField(
                  controller: _text,
                  focusNode: _focus,
                  theme: chrome,
                  hint: widget.options.placeholder ?? widget.labels.inputPlaceholder,
                  style: style,
                  onSubmitted: _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
