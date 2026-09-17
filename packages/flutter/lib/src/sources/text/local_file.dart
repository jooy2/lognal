/// Opening a file by path, where the platform has a file system.
///
/// The web has none, and importing `dart:io` there does not compile, so the
/// implementation is chosen when the application is built rather than when it
/// runs.
library;

export 'package:lognal/src/sources/text/local_file_web.dart'
    if (dart.library.io) 'package:lognal/src/sources/text/local_file_io.dart';
