// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// SM-4 Rule-0 checker (AUD-sync-04).
///
/// Flags a `ref.read(...)`/`ref.watch(...)`/`ref.invalidate(...)`/
/// `ref.refresh(...)`/`ref.listen(...)` call, or an assignment to a bare
/// `state` variable, that runs after an earlier `await` in the same async
/// method/closure with no `if (!ref.mounted) return;`-shaped guard in
/// between.
///
/// Riverpod 3 throws `UnmountedRefException` when a disposed [Ref] is
/// touched: an autoDispose provider can be torn down mid-`await` (e.g. a
/// profile switch or sign-out while a network round trip is in flight), and
/// the very next `ref.read`/`state =` after that `await` crashes. The fix is
/// always the same shape: `if (!ref.mounted) return;` immediately after the
/// `await`, before touching `ref`/`state` again.
///
/// Detection is purely syntactic and sequential — for each async
/// method/closure body, its top-level statements (and their nested
/// sub-statements, but never a NESTED function/closure's own body) are
/// walked in source order:
///   - an `if` statement whose condition mentions `mounted` clears the
///     "needs a guard" flag from that point on;
///   - any other statement containing a `ref.read`/`ref.watch`/
///     `ref.invalidate`/`ref.refresh`/`ref.listen` call, or a `state = ...`
///     assignment, is flagged while the flag is set;
///   - any statement containing an `await` expression sets the flag for
///     statements that follow it.
///
/// **Not flagged:**
/// - `ref`/`state` use before the first `await` in the body (nothing has had
///   a chance to go stale yet).
/// - `ref`/`state` use immediately after an `if (!ref.mounted) return;` (or
///   any `if` whose condition mentions `mounted`) guard.
/// - Calls on a nested closure's own `ref`/`state` (e.g. a `.then((_) { ...
///   })` callback) — that closure has its own async scope and is analyzed
///   independently when the visitor reaches it.
/// - A method name other than `read`/`watch`/`invalidate`/`refresh`/`listen`
///   on an identifier literally named `ref` (keeps the rule from firing on
///   an unrelated variable that happens to be named `ref`, e.g. a Firebase
///   Storage `Reference ref`, which has no such method names).
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoRefAfterAwaitWithoutMountedCheck extends DartLintRule {
  const NoRefAfterAwaitWithoutMountedCheck() : super(code: _code);

  static const _code = LintCode(
    name: 'no_ref_after_await_without_mounted_check',
    problemMessage:
        'SM-4: this ref.read/ref.watch/ref.invalidate/ref.refresh/ref.listen '
        'call (or `state = ...` assignment) runs after an earlier `await` in '
        'this async method/closure with no `if (!ref.mounted) return;` guard '
        'in between. Riverpod 3 throws UnmountedRefException if the provider '
        'was torn down (autoDispose, profile switch, sign-out) while the '
        'earlier await was in flight.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _refMethodNames = {
    'read',
    'watch',
    'invalidate',
    'refresh',
    'listen',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    void checkBody(FunctionBody body) {
      if (body is! BlockFunctionBody) return;
      if (!body.isAsynchronous) return;

      var needsGuard = false;
      for (final statement in body.block.statements) {
        if (_isMountedGuard(statement)) {
          needsGuard = false;
          continue;
        }

        if (needsGuard) {
          final touch = _findRefOrStateTouch(statement);
          if (touch != null) {
            reporter.atNode(touch, _code);
          }
        }

        if (_containsAwait(statement)) {
          needsGuard = true;
        }
      }
    }

    context.registry.addFunctionExpression((node) => checkBody(node.body));
    context.registry.addMethodDeclaration(
      (node) => checkBody(node.body),
    );
    context.registry.addFunctionDeclaration(
      (node) => checkBody(node.functionExpression.body),
    );
  }

  /// True when [statement] is `if (<cond mentioning "mounted">) ...` in any
  /// shape (`return;`, a block, `ref.mounted` or a bare `mounted`).
  static bool _isMountedGuard(Statement statement) {
    if (statement is! IfStatement) return false;
    return _ExpressionMentions(name: 'mounted').check(statement.expression);
  }

  static bool _containsAwait(Statement statement) {
    final finder = _AwaitFinder();
    statement.accept(finder);
    return finder.found;
  }

  static AstNode? _findRefOrStateTouch(Statement statement) {
    final finder = _RefOrStateTouchFinder(_refMethodNames);
    statement.accept(finder);
    return finder.found;
  }
}

/// True if [name] appears anywhere as a property/identifier name within the
/// given expression subtree (e.g. `ref.mounted`, `!ref.mounted`).
class _ExpressionMentions extends RecursiveAstVisitor<void> {
  _ExpressionMentions({required this.name});

  final String name;
  bool _found = false;

  bool check(AstNode node) {
    node.accept(this);
    return _found;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) _found = true;
    super.visitSimpleIdentifier(node);
  }
}

/// Finds an `AwaitExpression` anywhere in the subtree, never descending into
/// a nested function/closure body (that closure has its own async scope).
class _AwaitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not descend: a nested closure's own await does not run in this
    // statement's sequence.
  }
}

/// Finds the first `ref.<method>(...)` call (method in [refMethodNames]) or
/// `state = ...` assignment anywhere in the subtree, never descending into a
/// nested function/closure body.
class _RefOrStateTouchFinder extends RecursiveAstVisitor<void> {
  _RefOrStateTouchFinder(this.refMethodNames);

  final Set<String> refMethodNames;
  AstNode? found;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not descend: a nested closure's own ref/state use is out of scope.
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found == null) {
      final target = node.target;
      if (target is SimpleIdentifier &&
          target.name == 'ref' &&
          refMethodNames.contains(node.methodName.name)) {
        found = node;
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (found == null) {
      final lhs = node.leftHandSide;
      if (lhs is SimpleIdentifier && lhs.name == 'state') {
        found = node;
      }
    }
    super.visitAssignmentExpression(node);
  }
}
