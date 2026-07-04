import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [bytes] as [fileName] via a throwaway
/// Blob URL and an auto-clicked anchor - the standard way to save a file on
/// web, since there's no filesystem to write to directly.
Future<void> downloadAsFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}
