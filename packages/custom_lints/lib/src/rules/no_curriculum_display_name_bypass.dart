// ignore_for_file: deprecated_member_use
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents direct access to `.displayNameEn` or `.displayNameHe` outside
/// the canonical whitelist.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoCurriculumDisplayNameBypass extends DartLintRule {
  const NoCurriculumDisplayNameBypass() : super(code: _code);

  static const _code = LintCode(
    name: 'no_curriculum_display_name_bypass',
    problemMessage:
        "Direct access to '.displayNameEn' / '.displayNameHe' is not allowed "
        'outside lib/core/labels/. '
        'Use CurriculumLabelRenderer instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Property names that are restricted.
  static const _restrictedProperties = {'displayNameEn', 'displayNameHe'};

  /// Returns true when [filePath] is in the canonical whitelist and must not
  /// be linted.
  ///
  /// Whitelisted:
  ///   - `lib/core/labels/` — the sole authorised consumer of display names.
  ///   - `*.g.dart` and `*.freezed.dart` — generated files.
  static bool _isWhitelisted(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (path.contains('lib/core/labels/')) return true;
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

    // `obj.displayNameEn` — PropertyAccess nodes.
    context.registry.addPropertyAccess((node) {
      final propertyName = node.propertyName.name;
      if (_restrictedProperties.contains(propertyName)) {
        reporter.atNode(node, _code);
      }
    });

    // `prefix.displayNameEn` — PrefixedIdentifier nodes (simple chained
    // access that the analyser may represent differently from PropertyAccess).
    context.registry.addPrefixedIdentifier((node) {
      final identifier = node.identifier.name;
      if (_restrictedProperties.contains(identifier)) {
        reporter.atNode(node, _code);
      }
    });
  }
}
