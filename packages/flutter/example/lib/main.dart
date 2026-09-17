/// The lognal gallery.
///
/// Two jobs, and they are the same code seen from two sides:
///
/// - Run it (`flutter run`) and it is a gallery — the viewer, and a column of
///   buttons that write each kind of log into it. This is how the viewer is
///   looked at while it is being built.
/// - Build it for the web and the documentation site embeds it, one demo per
///   `<iframe>`, named by `?demo=console`. That is what makes the Flutter
///   previews on the site the real Flutter build rather than a screenshot.
///
/// Nothing here imports Material or Cupertino, for the same reason the library
/// does not: a gallery that needed a `MaterialApp` around it would not be
/// showing what a consumer of this package actually gets.
library;


import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:lognal/lognal.dart';
import 'package:lognal_example/host.dart';
import 'package:lognal_example/samples.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const GalleryApp());
}

/// The gallery.
class GalleryApp extends StatefulWidget {
  /// Creates the gallery.
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  /// Which demo the documentation site asked for, if it asked for one.
  ///
  /// Read once from the page's own query string. An embedded preview shows one
  /// sample and no gallery chrome; run as an app there is no query string and it
  /// shows all of them.
  static final String? _wanted = Uri.base.queryParameters['demo'];

  /// Which language the embedding page is written in, where it said.
  static final String _locale = switch (Uri.base.queryParameters['locale']) {
    'ko' => 'ko',
    _ => 'en',
  };

  late final LogStore _store = LogStore(options: const LogStoreOptions(maxEntries: 50000));
  late final LogViewerController _controller = LogViewerController(store: _store);
  String _theme = 'auto';
  void Function()? _stopListening;
  String? _notice;

  bool get _embedded => _wanted != null;

  @override
  void initState() {
    super.initState();
    _stopListening = listenToHost(
      onTheme: (String theme) {
        if (mounted) {
          setState(() => _theme = theme);
        }
      },
    );
    _start();
  }

  @override
  void dispose() {
    _stopListening?.call();
    _controller.dispose();
    super.dispose();
  }

  LognalConsole get _log => LognalConsole(_store);

  /// What the gallery writes before anybody presses anything.
  void _start() {
    final bool korean = _locale == 'ko';

    _log
      ..info(korean ? 'lognal 뷰어가 준비되었습니다.' : 'The lognal viewer is ready.')
      ..log(korean ? '왼쪽 버튼을 눌러 각 종류의 로그를 써 보세요.' : 'Press a button to write each kind of log.');

    final Sample? sample = _sampleFor(_wanted);

    if (sample != null) {
      sample.run(_log, _store);
    }
  }

  Sample? _sampleFor(String? id) {
    if (id == null) {
      return null;
    }

    for (final SampleGroup group in sampleGroups) {
      for (final Sample sample in group.samples) {
        if (sample.id == id) {
          return sample;
        }
      }
    }

    return null;
  }

  Future<void> _openFile() async {
    const XTypeGroup group = XTypeGroup(
      label: 'Log files',
      extensions: <String>['log', 'txt', 'json', 'csv'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);

    if (file == null || !mounted) {
      return;
    }

    final Uint8List bytes = await file.readAsBytes();
    final ReadTextResult result = await readTextBytes(bytes, _store);

    if (!mounted) {
      return;
    }

    setState(() {
      _notice = result.encoding == result.decoded
          ? '${file.name}: ${result.lines} lines, ${result.encoding}'
          : '${file.name}: ${result.lines} lines, ${result.encoding} is not one this build '
                'decodes, so it was read as ${result.decoded}';
    });
  }

  /// The font the gallery draws with.
  ///
  /// Named only on the web, where Flutter cannot reach the system's own
  /// monospace font and the bundled one is the only grid there is. Everywhere
  /// else the library picks the platform's, which is the right answer and one
  /// less thing for the gallery to carry.
  FontSettings get _font {
    return kIsWeb ? const FontSettings(family: 'NanumGothicCoding') : const FontSettings();
  }

  LogViewerOptions get _options {
    return LogViewerOptions(
      theme: _theme,
      locale: _locale,
      font: _font,
      core: const CoreOptions(maxEntries: 50000),
      input: InputOptions(onSubmit: runCommand),
      onOpenLink: (String url) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).ignore();
      },
      entryMenu: EntryMenuOptions(
        items: (LogEntry entry) => <EntryMenuItem>[
          EntryMenuItem(
            label: _locale == 'ko' ? '이 항목만 남기기' : 'Keep only this entry',
            onSelect: (LogEntry chosen) {
              _controller.setFilter(LogFilter(text: _controller.entryText(chosen.id)));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'lognal',
      color: const Color(0xff16181d),
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? _) => _getGalleryWidget(context),
    );
  }

  Widget _getGalleryWidget(BuildContext context) {
    final LognalTheme theme = _controller.options.resolveTheme(
      _theme,
      MediaQuery.platformBrightnessOf(context),
    );
    final Widget viewer = LogViewer(controller: _controller, options: _options);

    if (_embedded) {
      return ColoredBox(color: theme.chrome.background, child: viewer);
    }

    return ColoredBox(
      color: theme.chrome.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: 220, child: _getButtonsWidget(theme)),
              const SizedBox(width: 12),
              Expanded(child: viewer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getButtonsWidget(LognalTheme theme) {
    final String? notice = _notice;

    return ListView(
      children: <Widget>[
        for (final SampleGroup group in sampleGroups) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              group.label[_locale] ?? group.label['en']!,
              style: TextStyle(
                color: theme.chrome.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          for (final Sample sample in group.samples)
            _GalleryButton(
              theme: theme,
              label: sample.label[_locale] ?? sample.label['en']!,
              onPressed: () => sample.run(_log, _store),
            ),
        ],
        const SizedBox(height: 16),
        _GalleryButton(
          theme: theme,
          label: _locale == 'ko' ? '로그 파일 열기' : 'Open a log file',
          onPressed: _openFile,
        ),
        _GalleryButton(
          theme: theme,
          label: _locale == 'ko' ? '지우기' : 'Clear',
          onPressed: _controller.clear,
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              notice,
              style: TextStyle(color: theme.chrome.muted, fontSize: 11, height: 1.4),
              textDirection: TextDirection.ltr,
            ),
          ),
      ],
    );
  }
}

class _GalleryButton extends StatefulWidget {
  const _GalleryButton({required this.theme, required this.label, required this.onPressed});

  final LognalTheme theme;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GalleryButton> createState() => _GalleryButtonState();
}

class _GalleryButtonState extends State<_GalleryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ChromeTheme chrome = widget.theme.chrome;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent _) => setState(() => _hovered = true),
        onExit: (PointerExitEvent _) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered ? chrome.controlHover : chrome.surface,
              border: Border.all(color: chrome.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: TextStyle(color: chrome.foreground, fontSize: 12, height: 1.3),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  }
}
