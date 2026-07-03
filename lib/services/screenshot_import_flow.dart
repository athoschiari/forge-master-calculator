import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../engine/item_screenshot_parser.dart';
import 'ocr_text_recognizer.dart';

/// Shared "pick a screenshot -> OCR -> parse" orchestration used by every
/// import-from-screenshot entry point (gear/pet/mount cards and the
/// comparison screen's candidate editor), so the flow isn't duplicated four
/// times.
class ScreenshotImportFlow {
  const ScreenshotImportFlow._();

  /// Shows a Camera/Gallery chooser, runs OCR, and parses the result. Returns
  /// null only when the user cancels the picker; otherwise always returns a
  /// (possibly mostly-empty) [ParsedItemScreenshot] so callers can always
  /// proceed into their editor -- OCR failures never block editing, they
  /// only surface as a non-blocking [SnackBar].
  static Future<ParsedItemScreenshot?> run(BuildContext context) async {
    final source = await _pickSource(context);
    if (source == null) return null;

    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return null;

    String text = '';
    try {
      text = await OcrTextRecognizer().recognizeText(file.path);
    } catch (_) {
      text = '';
    }

    final parsed = ItemScreenshotParser.parse(text);

    if (!context.mounted) return parsed;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No text found in that screenshot. Fill in the fields manually.'),
      ));
    } else if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Could not recognise stats in that screenshot. Check the fields below.'),
      ));
    }

    return parsed;
  }

  static Future<ImageSource?> _pickSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
}
