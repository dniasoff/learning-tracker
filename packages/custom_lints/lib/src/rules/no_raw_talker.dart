// ignore_for_file: deprecated_member_use
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents direct imports of `package:talker/talker.dart` outside the
/// centralised logging layer.
///
/// The `Talker` instance must be obtained through the application's logging
/// abstraction in `lib/core/logging/` — never by importing the raw package
/// elsewhere.  This ensures:
///   - Redaction rules (NFR8) are applied uniformly.
///   - Log levels and sinks are configured in one place.
///   - Tests can swap the logger without touching production code.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoRawTalker extends DartLintRule {
  const NoRawTalker() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_talker',
    problemMessage:
        "Direct import of 'package:talker/talker.dart' is not allowed outside "
        "lib/core/logging/. Obtain the logger via the core logging abstraction.",
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// The exact URI that is restricted.
  static const _restrictedUri = 'package:talker/talker.dart';

  /// Returns true when [filePath] is in an authorised directory and must not
  /// be linted.
  ///
  /// Whitelisted:
  ///   - `lib/core/logging/` — the sole authorised consumer of raw Talker.
  ///   - `*.g.dart`          — generated files.
  ///   - `*.freezed.dart`    — generated files.
  static bool _isWhitelisted(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (path.contains('lib/core/logging/')) return true;
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
      if (uri == _restrictedUri) {
        reporter.atNode(node, _code);
      }
    });
  }
}
