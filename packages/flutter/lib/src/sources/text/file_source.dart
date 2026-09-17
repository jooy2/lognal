/// A file that can be measured and read from an offset, which is everything
/// following a growing file needs.
///
/// It is an interface rather than a `File` so the package compiles for the web,
/// where there is no file system and a picked file arrives as bytes.
/// [CallbackTextFile] wraps whatever the platform gives you, and
/// `localTextFile` opens a path where the platform has one.
abstract class TextFileSource {
  /// Lets a subclass declare a `const` constructor.
  const TextFileSource();

  /// The current size of the file in bytes.
  Future<int> length();

  /// When the file was last written, where the platform reports it.
  ///
  /// It is what tells a file that was replaced from a file that was appended to,
  /// in the one case the size cannot: a file rewritten to exactly the length it
  /// had. Return `null` where the platform does not know.
  Future<DateTime?> lastModified();

  /// Reads the bytes from [start] to the end of the file.
  Stream<List<int>> openRead([int start = 0]);
}

/// A [TextFileSource] built out of three functions, for a platform this package
/// has no direct access to.
class CallbackTextFile extends TextFileSource {
  /// Creates the source.
  const CallbackTextFile({
    required Future<int> Function() length,
    required Stream<List<int>> Function(int start) read,
    Future<DateTime?> Function()? lastModified,
  }) : _length = length,
       _read = read,
       _lastModified = lastModified;

  final Future<int> Function() _length;
  final Stream<List<int>> Function(int start) _read;
  final Future<DateTime?> Function()? _lastModified;

  @override
  Future<int> length() => _length();

  @override
  Future<DateTime?> lastModified() async => _lastModified == null ? null : _lastModified();

  @override
  Stream<List<int>> openRead([int start = 0]) => _read(start);
}
