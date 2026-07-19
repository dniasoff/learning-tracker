// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents direct calls to `logEvent(name, …)` outside `analytics_service.dart`.
///
/// All analytics events MUST be dispatched through the typed helper methods on
/// [AnalyticsService] (e.g. `analyticsService.logTrackAdded(...)`) rather than
/// calling `logEvent` directly. This ensures:
///   - Event names are defined as constants in [AnalyticsEvent].
///   - Parameter schemas are validated at the call site.
///   - Tests can verify analytics through the typed surface.
///
/// Only files inside `lib/core/analytics/` are allowed to invoke `logEvent`
/// because that directory owns the definition of the method (the abstract
/// `analytics_service.dart` contract and its concrete implementations,
/// e.g. `firebase_analytics_service.dart`).
///
/// **Non-compliant:**
/// ```dart
/// analyticsService.logEvent('custom_event', parameters: {'key': 'value'});
/// ```
///
/// **Compliant:**
/// ```dart
/// // Add a typed helper to AnalyticsService and call that instead.
/// analyticsService.logCustomEvent(key: 'value');
/// ```
///
/// See W7.21 in the tech-debt remediation plan.
class NoRawLogEvent extends DartLintRule {
  const NoRawLogEvent() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_logevent',
    problemMessage:
        "Direct calls to 'logEvent(name, …)' are not allowed outside "
        'analytics_service.dart. '
        'Add a typed helper method to AnalyticsService and call that instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Returns true when [filePath] is inside the authorised analytics
  /// directory. Anchored to the directory (like every sibling rule's
  /// "authorised owner" exemption — `lib/core/theme/`, `lib/core/labels/`,
  /// `lib/core/auth/`, `lib/core/sync/`, `lib/core/logging/`) rather than a
  /// bare filename suffix, so a same-named decoy file elsewhere in the tree
  /// (e.g. `lib/features/x/analytics_service.dart`) cannot inherit the
  /// exemption (AUD-guardrails-18).
  static bool _isWhitelisted(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (path.contains('lib/core/analytics/')) return true;
    if (path.endsWith('.g.dart')) return true;
    if (path.endsWith('.freezed.dart')) return true;
    return false;
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (_isWhitelisted(resolver.path)) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'logEvent') return;

      // Must have at least one positional argument (the event name string).
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Only flag calls where the first argument is a StringLiteral or
      // SimpleIdentifier — the typical raw-event-name pattern. This avoids
      // false positives if a package happens to expose an unrelated `logEvent`.
      final firstArg = args.first;
      if (firstArg is! StringLiteral && firstArg is! SimpleIdentifier) return;

      reporter.atNode(node, _code);
    });
  }
}
