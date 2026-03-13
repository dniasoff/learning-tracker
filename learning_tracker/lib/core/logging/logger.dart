import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide logger that wraps [Talker] with sensitive-data filtering.
///
/// All log calls go through [_safeMessage] which redacts any message that
/// contains recognised sensitive-data patterns before forwarding to Talker.
///
/// Log level conventions:
/// - `verbose` / `debug`: state changes, development details
/// - `info`: user actions, normal flow events
/// - `warning`: recoverable issues (API retry, offline mode)
/// - `error`: failures requiring attention
/// - `critical`: system failures (database error, auth failure)
class AppLogger {
  /// Creates an [AppLogger] that filters log messages through
  /// [SensitiveDataPatterns] before forwarding them to [talker].
  ///
  /// Prefer using the [instance] singleton in production and inject a
  /// test-specific [Talker] via [talkerProvider] in unit tests.
  AppLogger(this._talker);

  final Talker _talker;

  static Talker? _talkerInstance;

  /// The singleton [Talker] instance used by the static helpers.
  static Talker get instance {
    _talkerInstance ??= _createTalker();
    return _talkerInstance!;
  }

  /// Initialises the singleton [Talker] instance with application settings.
  ///
  /// Call once during app startup before any logging occurs.
  static Talker init() {
    _talkerInstance = _createTalker();
    return _talkerInstance!;
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
  static void setupFlutterErrorHandlers() {
    FlutterError.onError = (FlutterErrorDetails details) {
      instance.handle(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      instance.handle(error, stack);
      return true;
    };
  }

  // ─── Instance logging methods with sensitive-data filtering ─────────────────

  void info(String message) => _talker.info(_safeMessage(message));
  void debug(String message) => _talker.debug(_safeMessage(message));
  void warning(String message) => _talker.warning(_safeMessage(message));
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _talker.error(_safeMessage(message), error, stackTrace);
  void critical(String message, [Object? error, StackTrace? stackTrace]) =>
      _talker.critical(_safeMessage(message), error, stackTrace);

  void log(String message, {LogLevel level = LogLevel.info}) =>
      _talker.log(_safeMessage(message), logLevel: level);

  /// Forwards exception handling without message transformation.
  void handle(Object error, [StackTrace? stackTrace, String? message]) =>
      _talker.handle(error, stackTrace, message);

  /// The underlying [Talker] instance (use for providers / observers).
  Talker get talker => _talker;

  // ─── Sensitive-data filtering ────────────────────────────────────────────────

  static String _safeMessage(String message) {
    if (SensitiveDataPatterns.containsSensitiveData(message)) {
      return '[REDACTED — message contained sensitive data]';
    }
    return message;
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
