import 'dart:io';

import 'package:lognal/src/sources/text/file_source.dart';

/// A file on the local file system.
class _LocalTextFile extends TextFileSource {
  const _LocalTextFile(this.path);

  final String path;

  @override
  Future<int> length() => File(path).length();

  @override
  Future<DateTime?> lastModified() async {
    try {
      return await File(path).lastModified();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Stream<List<int>> openRead([int start = 0]) => File(path).openRead(start);
}

/// Opens a file on the local file system.
TextFileSource localTextFile(String path) => _LocalTextFile(path);
