import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device text recognition backed by Google ML Kit. Only ever
/// instantiated on Android/iOS (the only platforms the UI enables
/// screenshot import on), though the plugin itself also builds on other
/// dart:io targets.
class OcrTextRecognizer {
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
