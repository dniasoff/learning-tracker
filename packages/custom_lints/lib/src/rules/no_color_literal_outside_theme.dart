// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents direct `Color(0xFF…)` / `Color(0x…)` hex-literal constructor
/// calls outside the canonical `core/theme/` directory.
///
/// Colour definitions belong in `lib/core/theme/app_colors.dart` or
/// `lib/core/theme/app_theme.dart`. Feature and widget code must reference
/// the named constants from those files instead of embedding hex literals.
///
/// **Non-compliant** (triggers this lint):
/// ```dart
/// // In lib/features/dashboard/presentation/widgets/foo.dart
/// color: const Color(0xFF1A57C2),
/// ```
///
/// **Compliant** (use a named constant):
/// ```dart
/// import 'package:learning_tracker/core/theme/app_theme.dart';
/// color: AppTheme.brandBlueBright,
///
/// import 'package:learning_tracker/core/theme/app_colors.dart';
/// color: AppColors.blueMedium,
/// ```
///
/// Exceptions (whitelisted):
///   - Files under `lib/core/theme/`   — the canonical colour definition files
///   - `*.g.dart` / `*.freezed.dart`   — generated files
///
/// See W5.14 and W5.15 in the tech-debt remediation plan.
class NoColorLiteralOutsideTheme extends DartLintRule {
  const NoColorLiteralOutsideTheme() : super(code: _code);

  static const _code = LintCode(
    name: 'no_color_literal_outside_theme',
    problemMessage:
        "Direct Color(0x…) hex literals are not allowed outside lib/core/theme/. "
        "Use a named constant from AppColors or AppTheme instead.",
    errorSeverity: ErrorSeverity.WARNING,
  );

  /// Returns true when the file is inside the authorised theme directory.
  static bool _isWhitelisted(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (path.contains('lib/core/theme/')) return true;
    if (path.endsWith('.g.dart')) return true;
    if (path.endsWith('.freezed.dart')) return true;
    return false;
  }

  /// Returns true when the integer literal starts with a hex prefix that
  /// looks like an ARGB colour value (0xFF… or 0x0F… etc.).
  static bool _isHexColorLiteral(IntegerLiteral literal) {
    final lexeme = literal.literal.lexeme;
    // Hex colour literals start with 0x or 0X followed by 8 hex digits
    // (ARGB format). Require at least 0x followed by hex digits.
    return lexeme.startsWith('0x') || lexeme.startsWith('0X');
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (_isWhitelisted(resolver.path)) return;

    context.registry.addInstanceCreationExpression((node) {
      // Only flag `Color(...)` constructor calls.
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Color') return;

      // Must have exactly one argument that is a hex integer literal.
      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      // Allow negative literal wraps like Color(-0x...) — they are unusual
      // but valid. The typical pattern is Color(0xFF…).
      if (arg is! IntegerLiteral) return;
      if (!_isHexColorLiteral(arg)) return;

      reporter.atNode(node, _code);
    });
  }
}
