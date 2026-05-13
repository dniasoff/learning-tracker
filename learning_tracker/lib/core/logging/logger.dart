import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide logger that wraps [Talker] with structured, field-level
/// PII filtering.
///
/// **Preferred API** — named parameters, per-key redaction:
/// ```dart
/// _logger.info(event: 'sync_pull_on_launch_completed');
/// _logger.debug(event: 'sync_merge_completions', fields: {'count': n});
/// _logger.error(event: 'sync_push_failed', exception: e, stackTrace: st);
/// ```
///
/// The `event` string is **always** preserved verbatim — "PIN setup screen
/// opened" will appear in logs unchanged.  Only values whose *key* is in the
/// [PiiRedactor.sensitiveKeys] allowlist are redacted.
///
/// **Legacy API** (plain strings) is still available via [infoMsg], [debugMsg],
/// etc. and routes through [PiiRedactor.scrubMessage] which strips bare email
/// addresses but does not do keyword scanning.
///
/// Log level conventions:
/// - `verbose` / `debug`: state changes, development details
/// - `info`: user actions, normal flow events
/// - `warning`: recoverable issues (API retry, offline mode)
/// - `error`: failures requiring attention
/// - `critical`: system failures (database error, auth failure)
class AppLogger {
  /// Creates an [AppLogger] wrapping the given [talker].
  ///
  /// Prefer using the [instance] singleton in production and inject a
  /// test-specific [AppLogger] in unit tests.
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
        // Keep 2000 entries (~10 min of typical activity) in all modes so
        // "Send Diagnostic Logs" in Settings can capture a full session window.
        maxHistoryItems: 2000,
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

  // ─── Structured API (preferred) ─────────────────────────────────────────────

  /// Log at INFO level. The [event] string is preserved verbatim;
  /// sensitive values in [fields] are redacted by key.
  void info({required String event, Map<String, dynamic>? fields}) =>
      _talker.info(_buildMessage(event, fields));

  /// Log at DEBUG level. The [event] string is preserved verbatim;
  /// sensitive values in [fields] are redacted by key.
  void debug({required String event, Map<String, dynamic>? fields}) =>
      _talker.debug(_buildMessage(event, fields));

  /// Log at WARNING level. The [event] string is preserved verbatim;
  /// sensitive values in [fields] are redacted by key.
  void warning({
    required String event,
    Map<String, dynamic>? fields,
    Object? exception,
    StackTrace? stackTrace,
  }) => _talker.warning(_buildMessage(event, fields), exception, stackTrace);

  /// Log at ERROR level. The [event] string is preserved verbatim;
  /// sensitive values in [fields] are redacted by key.
  void error({
    required String event,
    Map<String, dynamic>? fields,
    Object? exception,
    StackTrace? stackTrace,
  }) => _talker.error(_buildMessage(event, fields), exception, stackTrace);

  /// Log at CRITICAL level. The [event] string is preserved verbatim;
  /// sensitive values in [fields] are redacted by key.
  void critical({
    required String event,
    Map<String, dynamic>? fields,
    Object? exception,
    StackTrace? stackTrace,
  }) => _talker.critical(_buildMessage(event, fields), exception, stackTrace);

  // ─── Legacy string API (backward-compatible) ────────────────────────────────

  /// Log a plain string at INFO level. Bare email addresses are scrubbed.
  void infoMsg(String message) =>
      _talker.info(PiiRedactor.scrubMessage(message));

  /// Log a plain string at DEBUG level. Bare email addresses are scrubbed.
  void debugMsg(String message) =>
      _talker.debug(PiiRedactor.scrubMessage(message));

  /// Log a plain string at WARNING level. Bare email addresses are scrubbed.
  void warningMsg(
    String message, [
    Object? exception,
    StackTrace? stackTrace,
  ]) =>
      _talker.warning(PiiRedactor.scrubMessage(message), exception, stackTrace);

  /// Log a plain string at ERROR level. Bare email addresses are scrubbed.
  void errorMsg(String message, [Object? exception, StackTrace? stackTrace]) =>
      _talker.error(PiiRedactor.scrubMessage(message), exception, stackTrace);

  /// Log a plain string at CRITICAL level. Bare email addresses are scrubbed.
  void criticalMsg(
    String message, [
    Object? exception,
    StackTrace? stackTrace,
  ]) => _talker.critical(
    PiiRedactor.scrubMessage(message),
    exception,
    stackTrace,
  );

  void log(String message, {LogLevel level = LogLevel.info}) =>
      _talker.log(PiiRedactor.scrubMessage(message), logLevel: level);

  /// Forwards exception handling without message transformation.
  void handle(Object error, [StackTrace? stackTrace, String? message]) =>
      _talker.handle(error, stackTrace, message);

  /// The underlying [Talker] instance (use for providers / observers).
  Talker get talker => _talker;

  // ─── Internal helpers ────────────────────────────────────────────────────────

  static String _buildMessage(String event, Map<String, dynamic>? fields) {
    if (fields == null || fields.isEmpty) return event;
    final redacted = PiiRedactor.redactFields(fields);
    return '$event $redacted';
  }
}

/// Field-level PII redactor.
///
/// Operates on structured [fields] maps: values whose *key* is in
/// [sensitiveKeys] are replaced with `'[REDACTED]'`; all other keys
/// (including `event`) are preserved verbatim.
///
/// For unstructured strings, [scrubMessage] strips bare email addresses
/// without keyword scanning — so a message like "PIN setup screen opened"
/// passes through unchanged.
class PiiRedactor {
  PiiRedactor._();

  /// Keys whose *values* must be redacted from log output.
  static const sensitiveKeys = <String>{
    'userEmail',
    'email',
    'pinHash',
    'pin',
    'accessToken',
    'access_token',
    'refreshToken',
    'refresh_token',
    'idToken',
    'id_token',
    'firebaseUid',
    'uid',
    'password',
    'secret',
    'token',
  };

  /// Email address pattern for scrubbing bare addresses from strings.
  static final _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  /// Returns a copy of [fields] with values of sensitive keys replaced by
  /// `'[REDACTED]'`. All other entries are preserved unchanged.
  static Map<String, dynamic> redactFields(Map<String, dynamic> fields) {
    return {
      for (final entry in fields.entries)
        entry.key: sensitiveKeys.contains(entry.key)
            ? '[REDACTED]'
            : entry.value,
    };
  }

  /// Scrubs bare email addresses from an unstructured [message] string.
  ///
  /// Does **not** do keyword scanning — words like "pin" or "email" in the
  /// message body are not treated as sensitive data.
  static String scrubMessage(String message) {
    return message.replaceAll(_emailPattern, '[REDACTED]');
  }
}

/// Patterns for sensitive data that must never appear in logs.
///
/// @Deprecated Use [PiiRedactor] instead. This class is kept for
/// backward-compatibility with existing tests.
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
