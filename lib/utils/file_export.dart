import 'dart:typed_data';

import 'file_export_stub.dart' if (dart.library.html) 'file_export_web.dart'
    as impl;

/// Saves [bytes] as a file named [fileName] on web, where there's no
/// filesystem to write to and `file_picker`'s `saveFile()` isn't implemented
/// (it throws `UnimplementedError` on every browser) - conditionally
/// imports the real, web-only implementation so non-web builds never pull in
/// a browser-only library. Only meant to be called when `kIsWeb`; the stub
/// used on every other platform is a no-op.
Future<void> downloadAsFile({
  required String fileName,
  required Uint8List bytes,
}) =>
    impl.downloadAsFile(fileName: fileName, bytes: bytes);
