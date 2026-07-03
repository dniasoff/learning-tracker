// ignore_for_file: deprecated_member_use
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents a feature from importing another feature's internals directly.
///
/// Features must only communicate via their barrel file (`<feature>.dart`),
/// which is the single public-surface export for each feature directory.
///
/// Allowed:  `package:learning_tracker/features/tracks/tracks.dart`
/// Disallowed: `package:learning_tracker/features/tracks/domain/models/foo.dart`
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoFeatureCrossImport extends DartLintRule {
  const NoFeatureCrossImport() : super(code: _code);

  static const _code = LintCode(
    name: 'no_feature_cross_import',
    problemMessage:
        "Cross-feature import detected: 'features/X/…' imported from 'features/Y/…'. "
        "Only the barrel 'features/X/X.dart' is allowed across feature boundaries.",
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // Matches: package:learning_tracker/features/<feature>/...
  static final _featureImportPattern = RegExp(
    r'^package:learning_tracker/features/([^/]+)/(.+)$',
  );

  // Matches: .../features/<feature>/... in file paths
  static final _featureFilePattern = RegExp(
    r'[/\\]features[/\\]([^/\\]+)[/\\]',
  );

  /// Returns the feature segment if [filePath] lives inside a feature folder.
  static String? _featureOf(String filePath) {
    final match = _featureFilePattern.firstMatch(filePath);
    return match?.group(1);
  }

  /// Returns true iff [importedPath] is the barrel file for [importedFeature].
  ///
  /// The barrel is exactly `<feature>.dart` (no sub-directory). For example,
  /// feature `tracks` → barrel is `tracks.dart`.
  static bool _isBarrel(String importedFeature, String importedPath) {
    return importedPath == '$importedFeature.dart';
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final hostFeature = _featureOf(resolver.path);
    // Only lint files that live inside a feature directory.
    if (hostFeature == null) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      final match = _featureImportPattern.firstMatch(uri);
      if (match == null) return;

      final importedFeature = match.group(1)!;
      final importedPath = match.group(2)!;

      // Same-feature imports are always fine.
      if (importedFeature == hostFeature) return;

      // Crossing at the feature barrel is the allowed surface.
      if (_isBarrel(importedFeature, importedPath)) return;

      reporter.atNode(node, _code);
    });
  }
}
