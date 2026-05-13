// ignore_for_file: deprecated_member_use
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents Firebase SDK imports outside the authorised core directories.
///
/// Firebase packages may only be imported from:
///   - `lib/core/auth/`   — authentication domain
///   - `lib/core/sync/`   — Firestore / Storage sync domain
///
/// All other files must go through the domain abstractions exposed by those
/// layers rather than importing Firebase directly.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoFirebaseOutsideCore extends DartLintRule {
  const NoFirebaseOutsideCore() : super(code: _code);

  static const _code = LintCode(
    name: 'no_firebase_outside_core',
    problemMessage:
        "Firebase packages may only be imported inside lib/core/auth/ or "
        "lib/core/sync/. Use the domain abstractions from those layers instead.",
    errorSeverity: ErrorSeverity.ERROR,
  );

  /// Firebase package URI prefixes that are restricted.
  static const _restrictedPrefixes = [
    'package:firebase_auth/',
    'package:cloud_firestore/',
    'package:firebase_storage/',
  ];

  /// Returns true when [filePath] is in an authorised directory and must not
  /// be linted.
  ///
  /// Whitelisted:
  ///   - `lib/core/auth/`   — authentication core
  ///   - `lib/core/sync/`   — sync / Firestore core
  ///   - `*.g.dart`         — generated files
  ///   - `*.freezed.dart`   — generated files
  static bool _isWhitelisted(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (path.contains('lib/core/auth/')) return true;
    if (path.contains('lib/core/sync/')) return true;
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

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      for (final prefix in _restrictedPrefixes) {
        if (uri.startsWith(prefix)) {
          reporter.atNode(node, _code);
          return;
        }
      }
    });
  }
}
