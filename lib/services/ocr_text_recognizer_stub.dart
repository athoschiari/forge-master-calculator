/// Fallback used on any target without dart:io (currently: web). The UI never
/// triggers this path -- every screenshot-import entry point is gated behind
/// `isMobilePlatform` -- but the API must exist so [ScreenshotImportFlow]
/// compiles uniformly across platforms.
class OcrTextRecognizer {
  Future<String> recognizeText(String imagePath) async {
    throw UnsupportedError('OCR is not supported on this platform.');
  }
}
