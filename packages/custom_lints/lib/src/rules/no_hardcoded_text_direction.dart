// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns on hardcoded directional values in widget files.
///
/// Using `left`/`right` variants of Flutter layout APIs assumes LTR layout and
/// breaks RTL (e.g. Hebrew) UI.  Use the direction-aware equivalents instead:
///
///   - `EdgeInsets.only(left:…)` / `…only(right:…)` → `EdgeInsetsDirectional.only(start:…/end:…)`
///   - `Alignment.centerLeft` / `.centerRight` → `AlignmentDirectional.centerStart / centerEnd`
///   - `TextAlign.left` / `TextAlign.right` → `TextAlign.start` / `TextAlign.end`
///
/// **Severity: WARNING** — existing code contains many violations; clean up
/// incrementally. New code must not introduce new violations.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoHardcodedTextDirection extends DartLintRule {
  const NoHardcodedTextDirection() : super(code: _code);

  static const _code = LintCode(
    name: 'no_hardcoded_text_direction',
    problemMessage: "Hardcoded directional value detected. "
        "Use direction-aware alternatives (EdgeInsetsDirectional, "
        "AlignmentDirectional.centerStart/centerEnd, TextAlign.start/end) "
        "so the UI works correctly in both LTR and RTL locales.",
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // -------------------------------------------------------------------------
  // Restricted static member accesses: Alignment.centerLeft, TextAlign.left …
  // -------------------------------------------------------------------------

  /// Maps a class name to the set of property names that are restricted.
  static const _restrictedStaticMembers = <String, Set<String>>{
    'Alignment': {'centerLeft', 'centerRight'},
    'TextAlign': {'left', 'right'},
  };

  // -------------------------------------------------------------------------
  // Restricted named argument names inside EdgeInsets.only(…)
  // -------------------------------------------------------------------------

  /// Argument names within an `EdgeInsets.only(…)` call that are restricted.
  static const _restrictedEdgeInsetsArgs = {'left', 'right'};

  /// The class that carries the restricted named arguments.
  static const _edgeInsetsClass = 'EdgeInsets';

  /// The constructor / factory method name that triggers inspection.
  static const _edgeInsetsMethod = 'only';

  /// Returns true when [filePath] should be skipped (generated files).
  static bool _isGenerated(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
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
    if (_isGenerated(resolver.path)) return;

    // ------------------------------------------------------------------
    // 1. `Alignment.centerLeft`, `Alignment.centerRight`,
    //    `TextAlign.left`, `TextAlign.right`
    //    → represented as PrefixedIdentifier: `Alignment`.`centerLeft`
    // ------------------------------------------------------------------
    context.registry.addPrefixedIdentifier((node) {
      final className = node.prefix.name;
      final memberName = node.identifier.name;
      final restricted = _restrictedStaticMembers[className];
      if (restricted != null && restricted.contains(memberName)) {
        reporter.atNode(node, _code);
      }
    });

    // ------------------------------------------------------------------
    // 2. `EdgeInsets.only(left: …)` / `EdgeInsets.only(right: …)`
    //    The call is a MethodInvocation whose target is a SimpleIdentifier
    //    or PrefixedIdentifier for `EdgeInsets`, method name is `only`,
    //    and the argument list contains a named arg `left` or `right`.
    // ------------------------------------------------------------------
    context.registry.addMethodInvocation((node) {
      // Accept both `EdgeInsets.only(…)` and (less common) a direct call.
      final methodName = node.methodName.name;
      if (methodName != _edgeInsetsMethod) return;

      // Determine the receiver class name.
      final target = node.realTarget;
      if (target == null) return;
      final targetName = target.toSource();
      if (targetName != _edgeInsetsClass) return;

      // Check named arguments.
      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final label = arg.name.label.name;
        if (_restrictedEdgeInsetsArgs.contains(label)) {
          reporter.atNode(arg, _code);
        }
      }
    });
  }
}
