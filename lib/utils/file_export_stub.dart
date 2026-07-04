import 'dart:typed_data';

/// Non-web fallback for [downloadAsFile] - never called (Settings only
/// invokes it when `kIsWeb`), but every platform must still compile it.
Future<void> downloadAsFile({
  required String fileName,
  required Uint8List bytes,
}) async {}
