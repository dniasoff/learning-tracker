// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-onboarding-01 (AC2) Rule-0 checker for SM-4.
///
/// SM-4: "After any `await` in a Notifier method or async callback, check
/// `ref.mounted` before touching `ref` or `state`." (the `BuildContext`
/// analog for `State`/`ConsumerState` is `mounted`.) Riverpod 3 throws
/// `UnmountedRefException` when a disposed `Ref` is touched, and Flutter
/// throws `setState() called after dispose()` — an autoDispose provider or a
/// widget can be torn down while an `await` is still in flight (backgrounding
/// the app, popping the route mid-write), and resuming without a guard
/// crashes.
///
/// This rule flags a `state = ...` assignment or a bare `setState(...)` call
/// that appears — in the same method body's statement sequence, including
/// inside `try`/`catch` blocks — after an `await` with no intervening
/// `if (!mounted) return;` / `if (!ref.mounted) return;` (or an
/// `if (mounted) { ... }` / `if (ref.mounted) { ... }` wrapping guard) in
/// between.
///
/// Scope: methods on a Riverpod Notifier-like class (`Notifier`,
/// `AsyncNotifier`, `StateNotifier`, the riverpod_generator `_$` codegen
/// shape, etc. — reusing the same detection as
/// [NoUnguardedAsyncNotifierInit]) or a `State`/`ConsumerState` subclass,
/// whose body is `async`.
///
/// Detection is intentionally syntactic and scoped to the METHOD BODY's own
/// statement sequence (recursing into `try`/`catch`/`finally` blocks as their
/// own sequential scan, seeded with "already pending" when the sibling `try`
/// block contains an await) — it does not analyze `if`/`for`/`while`
/// branches beyond the two mounted-guard shapes named above. This mirrors the
/// exact defect class from AUD-onboarding-01 (`OnboardingController.advance`,
/// `BulkMarkScreen._proceedToConfirmation` /`_executeBulkMark`,
/// `OnboardingProfileCreationStep._createProfile`) and avoids false positives
/// from deeper control-flow heuristics; more exotic guard placements are left
/// to human triage.
///
/// **Not flagged:**
/// - `state =` / `setState(...)` with no preceding `await` in the method.
/// - Preceded by an early-return guard: `if (!mounted) return;` /
///   `if (!ref.mounted) return;`.
/// - Wrapped in `if (mounted) { ... }` / `if (ref.mounted) { ... }` (or a
///   `mounted && ...` / `ref.mounted && ...` conjunction).
/// - A `catch` clause whose sibling `try` block contains no `await` (nothing
///   there could have raced a disposal).
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoUnguardedStateTouchAfterAwait extends DartLintRule {
  const NoUnguardedStateTouchAfterAwait() : super(code: _code);

  static const _code = LintCode(
    name: 'no_unguarded_state_touch_after_await',
    problemMessage:
        'This `state =` / `setState(...)` runs after an `await` with no '
        '`mounted` / `ref.mounted` guard in between. If the Notifier/State '
        'was disposed while that await was in flight, this throws '
        '(UnmountedRefException / setState-after-dispose). Add '
        '`if (!mounted) return;` / `if (!ref.mounted) return;` immediately '
        'after the await (SM-4).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _notifierSuperclassNames = {
    'Notifier',
    'AsyncNotifier',
    'StateNotifier',
    'StreamNotifier',
    'AutoDisposeNotifier',
    'AutoDisposeAsyncNotifier',
    'AutoDisposeStreamNotifier',
    'FamilyNotifier',
    'FamilyAsyncNotifier',
    'AutoDisposeFamilyNotifier',
    'AutoDisposeFamilyAsyncNotifier',
  };

  static const _stateSuperclassNames = {'State', 'ConsumerState'};

  static bool _isGenerated(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.gr.dart');
  }

  static bool _isInScope(ClassDeclaration decl) {
    final superName = decl.extendsClause?.superclass.name.lexeme;
    if (superName == null) return false;
    if (superName == '_\$${decl.name.lexeme}') return true;
    return _notifierSuperclassNames.contains(superName) ||
        _stateSuperclassNames.contains(superName);
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (_isGenerated(resolver.path)) return;

    context.registry.addClassDeclaration((decl) {
      if (!_isInScope(decl)) return;

      for (final member in decl.members) {
        if (member is! MethodDeclaration || member.isStatic) continue;
        final body = member.body;
        if (body is! BlockFunctionBody || !body.isAsynchronous) continue;
        _scanBlock(body.block, reporter);
      }
    });
  }

  /// Sequentially scans [block]'s own statement list, tracking whether an
  /// `await` has occurred with no mounted guard since. [initialPending]
  /// seeds the state for a `catch`-body scan whose sibling `try` may already
  /// contain an await.
  static void _scanBlock(
    Block block,
    ErrorReporter reporter, {
    bool initialPending = false,
  }) {
    var pending = initialPending;

    for (final stmt in block.statements) {
      if (_isMountedEarlyReturnGuard(stmt)) {
        pending = false;
        continue;
      }
      if (_isMountedWrappingGuard(stmt)) {
        // Treated as safe; do not flag inside it. Does not clear `pending`
        // for statements that follow — mounted could still flip during a
        // later await.
        continue;
      }

      if (pending && _touchesStateOrSetState(stmt)) {
        reporter.atNode(stmt, _code);
      }

      if (stmt is TryStatement) {
        _scanBlock(stmt.body, reporter);
        final tryPending = pending || _containsAwait(stmt.body);
        for (final clause in stmt.catchClauses) {
          _scanBlock(clause.body, reporter, initialPending: tryPending);
        }
        if (stmt.finallyBlock != null) {
          _scanBlock(
            stmt.finallyBlock!,
            reporter,
            initialPending: tryPending,
          );
        }
      }

      if (_containsAwait(stmt)) {
        pending = true;
      }
    }
  }

  static bool _touchesStateOrSetState(Statement stmt) {
    if (stmt is! ExpressionStatement) return false;
    final expr = stmt.expression;
    if (expr is AssignmentExpression) {
      final lhs = expr.leftHandSide;
      if (lhs is SimpleIdentifier && lhs.name == 'state') return true;
    }
    if (expr is MethodInvocation &&
        (expr.target == null || expr.target is ThisExpression) &&
        expr.methodName.name == 'setState') {
      return true;
    }
    return false;
  }

  static bool _containsAwait(AstNode node) {
    final finder = _AwaitFinder();
    node.accept(finder);
    return finder.found;
  }

  static bool _isMountedEarlyReturnGuard(Statement stmt) {
    if (stmt is! IfStatement) return false;
    if (stmt.elseStatement != null) return false;
    if (!_isNegatedMountedCondition(stmt.expression)) return false;
    return _isReturnOnly(stmt.thenStatement);
  }

  static bool _isReturnOnly(Statement thenStmt) {
    if (thenStmt is ReturnStatement) return true;
    if (thenStmt is Block && thenStmt.statements.length == 1) {
      return thenStmt.statements.first is ReturnStatement;
    }
    return false;
  }

  static bool _isNegatedMountedCondition(Expression expr) {
    return expr is PrefixExpression &&
        expr.operator.lexeme == '!' &&
        _isMountedExpr(expr.operand);
  }

  static bool _isMountedWrappingGuard(Statement stmt) {
    if (stmt is! IfStatement) return false;
    if (stmt.elseStatement != null) return false;
    return _conditionImpliesMounted(stmt.expression);
  }

  static bool _conditionImpliesMounted(Expression expr) {
    if (_isMountedExpr(expr)) return true;
    if (expr is BinaryExpression && expr.operator.lexeme == '&&') {
      return _conditionImpliesMounted(expr.leftOperand) ||
          _conditionImpliesMounted(expr.rightOperand);
    }
    return false;
  }

  /// Matches `mounted` (bare State getter) or `ref.mounted`.
  static bool _isMountedExpr(Expression expr) {
    if (expr is SimpleIdentifier) return expr.name == 'mounted';
    if (expr is PrefixedIdentifier) {
      return expr.prefix.name == 'ref' && expr.identifier.name == 'mounted';
    }
    if (expr is PropertyAccess) {
      final target = expr.target;
      return target is SimpleIdentifier &&
          target.name == 'ref' &&
          expr.propertyName.name == 'mounted';
    }
    return false;
  }
}

/// Finds an [AwaitExpression] anywhere in the visited subtree, EXCLUDING
/// nested closures (`FunctionExpression`) — their own await sequencing is
/// independent of the enclosing method's control flow.
class _AwaitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not descend — see class doc comment.
  }
}
