import 'package:flutter/foundation.dart';

/// True only on Android/iOS. Uses [defaultTargetPlatform] rather than
/// dart:io's `Platform` (which fails to compile on web) so this is safe to
/// import from any widget file, including ones compiled into the web build.
/// Screenshot OCR import is mobile-only (see [ItemScreenshotParser]); every
/// UI entry point for it is gated behind this getter.
bool get isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
