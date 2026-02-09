import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide Talker logger singleton.
///
/// Provides a single shared [Talker] instance configured with appropriate
/// log levels and settings for the application.
///
/// Log level conventions:
/// - `verbose` / `debug`: state changes, development details
/// - `info`: user actions, normal flow events
/// - `warning`: recoverable issues (API retry, offline mode)
/// - `error`: failures requiring attention
/// - `critical`: system failures (database error, auth failure)
class AppLogger {
  AppLogger._();

  static Talker? _instance;

  /// Returns the singleton [Talker] instance.
  ///
  /// The instance is lazily created on first access with default settings.
  /// Call [init] to configure before first use.
  static Talker get instance {
    _instance ??= _createTalker();
    return _instance!;
  }

  /// Initializes the Talker singleton with application settings.
  ///
  /// Should be called once during app startup before any logging occurs.
  /// Subsequent calls replace the existing instance.
  static Talker init() {
    _instance = _createTalker();
    return _instance!;
  }

  static Talker _createTalker() {
    return Talker(
      settings: TalkerSettings(
        enabled: true,
        useConsoleLogs: !kReleaseMode,
        maxHistoryItems: kReleaseMode ? 100 : 1000,
      ),
    );
  }

  /// Configures Flutter framework error handlers to route errors to Talker.
  ///
  /// Sets up:
  /// - [FlutterError.onError] for Flutter framework errors
  /// - [PlatformDispatcher.instance.onError] for unhandled platform errors
  static void setupFlutterErrorHandlers() {
    FlutterError.onError = (FlutterErrorDetails details) {
      instance.handle(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      instance.handle(error, stack);
      return true;
    };
  }
}

/// Patterns for sensitive data that must never appear in logs.
class SensitiveDataPatterns {
  SensitiveDataPatterns._();

  /// Fields that should be redacted from logged data.
  static const sensitiveFields = {
    'email',
    'password',
    'pin',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'secret',
  };

  /// Email address pattern for detection in log output.
  static final emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  /// PIN pattern (4-8 digit sequences that look like PINs).
  static final pinPattern = RegExp(r'(?<!\d)\d{4,8}(?!\d)');

  /// Returns true if the given text contains sensitive data patterns.
  static bool containsSensitiveData(String text) {
    final lowerText = text.toLowerCase();
    for (final field in sensitiveFields) {
      if (lowerText.contains(field)) return true;
    }
    if (emailPattern.hasMatch(text)) return true;
    return false;
  }
}
