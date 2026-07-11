// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-onboarding-11 (AC2) Rule-0 checker for EH-3.
///
/// EH-3: "Never swallow an error: every `catch` rethrows, converts, or logs
/// through `AppLogger`. No empty and no log-less catch blocks." The
/// analyzer's built-in `empty_catches` lint only flags a catch block with a
/// literally empty `{}` body — and Dart's own style guidance is to silence
/// that exact lint by adding a comment inside the block, which is precisely
/// the shape that slips past it undetected (e.g. the pre-fix
/// `BulkMarkScreen._loadPreExistingCompletions`: `catch (_) { // comment }`).
///
/// This is the "log-less-catch half" of the checker EH-3 names as
/// [Pending]: it flags any `catch` clause under `lib/` whose body contains
/// no call to `AppLogger.instance.<method>(...)` and no `rethrow` —
/// regardless of whether the body is literally empty, comment-only, or does
/// something else (e.g. a bare `setState`/`return`) without ever recording
/// why the exception was swallowed.
///
/// **Not flagged:**
/// - The catch body contains a `rethrow`.
/// - The catch body contains a call to `AppLogger.instance.<anything>(...)`,
///   anywhere (including nested inside an `if`/closure).
/// - Files outside `lib/` (tests/tooling use different conventions) or
///   generated files (`.g.dart` / `.freezed.dart` / `.gr.dart`).
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoLogLessCatch extends DartLintRule {
  const NoLogLessCatch() : super(code: _code);

  static const _code = LintCode(
    name: 'no_log_less_catch',
    problemMessage:
        'This catch block neither logs through AppLogger nor rethrows -- '
        'the exception is silently swallowed with no diagnostic trail '
        '(EH-3). Log via AppLogger.instance.<level>(event: ..., '
        'exception: e, stackTrace: st) before falling through, or rethrow.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static bool _isGenerated(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.gr.dart');
  }

  /// True when [filePath] is inside `lib/` — EH-3's checker is scoped there
  /// (per AUD-onboarding-11's acceptance criterion), not test/tool code.
  static bool _isInLib(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    return path.contains('/lib/');
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (_isGenerated(resolver.path)) return;
    if (!_isInLib(resolver.path)) return;

    context.registry.addCatchClause((node) {
      if (_handlesError(node.body)) return;
      reporter.atNode(node, _code);
    });
  }

  static bool _handlesError(Block catchBody) {
    final finder = _HandledFinder();
    catchBody.accept(finder);
    return finder.handled;
  }
}

/// Detects a `rethrow` or an `AppLogger.instance.<method>(...)` call
/// anywhere within the visited subtree (including inside nested
/// closures/if-blocks — unlike the await-sequencing rule, there is no
/// control-flow ordering concern here: any such call anywhere in the catch
/// body counts as "handled").
class _HandledFinder extends RecursiveAstVisitor<void> {
  bool handled = false;

  @override
  void visitRethrowExpression(RethrowExpression node) {
    handled = true;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isAppLoggerInstanceAccess(node.target)) {
      handled = true;
    }
    super.visitMethodInvocation(node);
  }

  /// Matches `AppLogger.instance` as the receiver of a method call —
  /// represented as either a [PrefixedIdentifier] (`AppLogger`.`instance`)
  /// or a [PropertyAccess] (`AppLogger`.`instance`) depending on how the
  /// analyzer resolves the two-segment chain at this syntactic position.
  static bool _isAppLoggerInstanceAccess(Expression? expr) {
    if (expr is PrefixedIdentifier) {
      return expr.prefix.name == 'AppLogger' &&
          expr.identifier.name == 'instance';
    }
    if (expr is PropertyAccess) {
      final target = expr.target;
      return target is SimpleIdentifier &&
          target.name == 'AppLogger' &&
          expr.propertyName.name == 'instance';
    }
    return false;
  }
}
