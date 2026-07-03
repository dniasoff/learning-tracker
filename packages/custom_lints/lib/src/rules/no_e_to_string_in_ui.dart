// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when exception variables are converted to string via `.toString()`
/// inside `presentation/` files.
///
/// Propagating raw exception messages to the UI (via `e.toString()`) leaks
/// internal implementation details and untranslated text to users.
/// Presentation code should display a localised, user-friendly error message
/// (e.g. via `AppErrorView` or an l10n string) rather than the raw exception.
///
/// This lint targets the common identifier names used for caught exceptions
/// (`e`, `err`, `ex`, `error`, `exception`) when `.toString()` is called on
/// them inside a `presentation/` path.
///
/// **Compliant** (use a localised key or a typed check instead):
/// ```dart
/// // Bad — propagates raw Dart exception message to UI
/// Text(e.toString())
///
/// // Good — localised user-friendly message
/// Text(l10n.errorGeneric)
/// AppErrorView(message: l10n.errorUnknown)
/// ```
///
/// See W7.18 and W7.20 in the tech-debt remediation plan.
class NoEToStringInUi extends DartLintRule {
  const NoEToStringInUi() : super(code: _code);

  static const _code = LintCode(
    name: 'no_e_to_string_in_ui',
    problemMessage: "Avoid calling '.toString()' on exception variables inside "
        'presentation/. Use a localised error message or AppErrorView instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Identifier names commonly used for caught exceptions.
  static const _exceptionIdentifiers = {
    'e',
    'err',
    'ex',
    'error',
    'exception',
  };

  /// Returns true when [filePath] is inside a presentation layer.
  static bool _isPresentation(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    return path.contains('/presentation/');
  }

  /// Returns true when [filePath] is a generated file (exempt from linting).
  static bool _isGenerated(String filePath) {
    return filePath.endsWith('.g.dart') || filePath.endsWith('.freezed.dart');
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isPresentation(resolver.path)) return;
    if (_isGenerated(resolver.path)) return;

    context.registry.addMethodInvocation((node) {
      // Only flag `.toString()` calls (no arguments).
      if (node.methodName.name != 'toString') return;
      if (node.argumentList.arguments.isNotEmpty) return;

      // Check that the receiver is one of the known exception identifiers.
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (!_exceptionIdentifiers.contains(target.name)) return;

      reporter.atNode(node, _code);
    });
  }
}
