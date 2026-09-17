import 'package:lognal/src/sources/text/file_source.dart';

/// Opens a file on the local file system, which the web does not have.
///
/// A browser hands a picked file to the page as bytes or as a stream, so wrap
/// that in a [CallbackTextFile] instead.
TextFileSource localTextFile(String path) {
  throw UnsupportedError(
    'lognal: there is no local file system on the web. Wrap the file the browser '
    'gave you in a CallbackTextFile instead.',
  );
}
