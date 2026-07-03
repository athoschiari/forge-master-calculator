// Facade for on-device text recognition. Conditionally exports the real
// google_mlkit_text_recognition-backed implementation on platforms that
// have dart:io (Android/iOS/desktop), and a stub everywhere else (web),
// so the web compiler never attempts to compile the ML Kit package at all
// -- that package has no web implementation and touches dart:io directly,
// which would otherwise break `flutter build web`.
export 'ocr_text_recognizer_stub.dart'
    if (dart.library.io) 'ocr_text_recognizer_io.dart';
