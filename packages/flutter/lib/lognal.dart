/// A terminal-style log viewer for Flutter, drawn on a canvas.
///
/// Mirror what the application already prints, read log files, and inspect
/// typed values that expand and collapse. The whole viewer is one widget,
/// [LogViewer]; everything below it is the same library the npm package ships,
/// translated file for file.
///
/// ```dart
/// final LogStore store = LogStore();
///
/// // Somewhere above your app, so what it prints reaches the viewer.
/// hookDebugPrint(store);
///
/// // And wherever the log belongs on screen. Give it a height.
/// SizedBox(height: 400, child: LogViewer(store: store));
/// ```
library;

export 'package:lognal/src/core/filter.dart'
    show CompiledFilter, LogFilter, MuteRule, compileFilter, entrySearchText, escapeRegExp;
export 'package:lognal/src/core/layout/entry_lines.dart' show ExpansionLookup, buildEntryLines;
export 'package:lognal/src/core/layout/layout.dart'
    show LayoutOptions, LogLayout, PositionLocation, RowLocation, defaultLayoutOptions;
export 'package:lognal/src/core/layout/search.dart'
    show CompiledSearch, LogSearch, SearchOptions, compileSearch, maxSearchMatches;
export 'package:lognal/src/core/layout/types.dart'
    show
        LineAction,
        LineIconSpan,
        LineSpan,
        LineTextSpan,
        LogPosition,
        LogicalLine,
        OpenLinkAction,
        RowRun,
        ShapedLine,
        ShapedSpan,
        TextMatch,
        ToggleGroupAction,
        ToggleRepeatAction,
        ToggleValueAction,
        VisualRow,
        WrapMode;
export 'package:lognal/src/core/store.dart'
    show
        LogStore,
        LogStoreOptions,
        MergeRepeats,
        StoreAppend,
        StoreChange,
        StoreClear,
        StoreListener,
        StoreTrim,
        StoreUpdate,
        WriteOptions,
        defaultStoreOptions;
export 'package:lognal/src/core/text/ansi.dart' show AnsiParser, stripAnsi;
export 'package:lognal/src/core/text/graphemes.dart'
    show GraphemeSplitter, setGraphemeSplitter, splitGraphemes, splitGraphemesFallback;
export 'package:lognal/src/core/text/line_splitter.dart' show LogLineSplitter, splitLines;
export 'package:lognal/src/core/text/links.dart' show TextLink, findLinks;
export 'package:lognal/src/core/text/measure.dart' show measureCells, padCells, truncateCells;
export 'package:lognal/src/core/text/normalize.dart' show normalizeNfc;
export 'package:lognal/src/core/text/shape.dart' show ShapeOptions, shapeLine;
export 'package:lognal/src/core/text/unicode_width_data.dart' show unicodeVersion;
export 'package:lognal/src/core/text/width.dart' show AmbiguousWidth, clusterWidth, codePointWidth;
export 'package:lognal/src/core/time.dart' show TimestampFormat, formatTimestamp;
export 'package:lognal/src/core/types.dart'
    show
        AccessorKind,
        AnsiTextColor,
        LogEntry,
        LogEntryInit,
        LogKind,
        LogLevel,
        LogPart,
        LogTextStyle,
        RgbTextColor,
        StyleToken,
        TextColor,
        TextPart,
        ValueEntry,
        ValueKeyKind,
        ValueKind,
        ValueNode,
        ValuePart,
        logLevels;
export 'package:lognal/src/core/value/data.dart'
    show formatEntriesData, formatEntryData, formatJson, valueToJson;
export 'package:lognal/src/core/value/preview.dart' show isExpandable, previewValue;
export 'package:lognal/src/core/value/text.dart'
    show ValueTextOptions, formatEntrySpans, formatEntryText, formatValueSpans, formatValueText;
export 'package:lognal/src/renderer/canvas_renderer.dart' show CanvasLogRenderer;
export 'package:lognal/src/renderer/palette.dart' show resolveTextColor;
export 'package:lognal/src/renderer/types.dart'
    show CellMetrics, FontSettings, LogRenderer, RenderFrame, RenderTheme, RowDecoration;
export 'package:lognal/src/sources/console/capture.dart'
    show CaptureOptions, captureValue, defaultCaptureOptions;
export 'package:lognal/src/sources/console/console.dart' show LognalConsole;
export 'package:lognal/src/sources/console/css_color.dart' show parseCssColor;
export 'package:lognal/src/sources/console/format.dart'
    show FormattedMessage, ValueCapture, applyFormat, formatArguments, parseConsoleCss;
export 'package:lognal/src/sources/console/hook.dart'
    show HookOptions, hookDebugPrint, hookFlutterErrors, runZonedWithLognal;
export 'package:lognal/src/sources/console/recorder.dart'
    show ConsoleMethod, ConsoleRecorder, RecorderOptions, consoleMethods, defaultRecorderOptions;
export 'package:lognal/src/sources/console/table.dart' show formatTable;
export 'package:lognal/src/sources/text/encoding.dart'
    show
        TextDecoderFactory,
        TextDecoderSink,
        builtInEncodings,
        decoderFor,
        detectEncoding,
        encodingFromBom,
        isValidUtf8,
        legacyEncodingFor,
        registerTextDecoder;
export 'package:lognal/src/sources/text/file_source.dart' show CallbackTextFile, TextFileSource;
export 'package:lognal/src/sources/text/follow_file.dart'
    show FollowHandle, FollowTextOptions, followTextFile;
export 'package:lognal/src/sources/text/local_file.dart' show localTextFile;
export 'package:lognal/src/sources/text/read_file.dart'
    show ReadTextOptions, ReadTextResult, TextLineWriter, readTextBytes, readTextStream;
export 'package:lognal/src/theme/palettes.dart'
    show
        ChromeTheme,
        LognalTheme,
        buildTheme,
        builtInTheme,
        builtInThemeNames,
        builtInThemes,
        darkTheme,
        emberTheme,
        lightTheme,
        midnightTheme,
        mossTheme,
        paperTheme,
        resolveTheme;
export 'package:lognal/src/viewer/controller.dart'
    show HitTest, LogViewerController, TextSelectionRange, ViewAnchor;
export 'package:lognal/src/viewer/labels.dart'
    show NumberFormatter, ViewerLabels, enLabels, formatCount, koLabels, labelsFor;
export 'package:lognal/src/viewer/log_viewer.dart' show LogViewer;
export 'package:lognal/src/viewer/options.dart'
    show
        CoreOptions,
        EntryMenuItem,
        EntryMenuOptions,
        EntryTextFormat,
        EntryTextOptions,
        InputOptions,
        LinkClick,
        LogViewerOptions,
        SelectionMode,
        ThemeChoice,
        ViewerToolbarOptions;
