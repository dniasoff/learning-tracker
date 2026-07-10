// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-account-11 (AC3) Rule-0 checker.
///
/// Flags a Riverpod `Notifier`/`AsyncNotifier` — including
/// `riverpod_generator`'s `class Foo extends _$Foo` codegen shape — whose
/// `build()` kicks off a private async method **fire-and-forget**: called
/// as a bare statement (`_init();` / `this._init();`), never `await`ed and
/// never wrapped in a `try`/`catch` at the call site — where that private
/// method's own body contains **zero `try` statements anywhere**.
///
/// An exception anywhere in such a method is then an unobserved Future
/// rejection: `build()` already returned its placeholder state before the
/// async work settles, and nothing ever resets `state` on failure, so the
/// notifier can get stuck at that placeholder forever.
///
/// This is exactly the `AuthStateNotifier.build()` -> `_init()` shape that
/// caused AUD-account-11 (`auth_state_provider.dart` / `auth_state.dart`'s
/// own "Must not hang — see 19.6 startup hardening" doc comment on
/// `SessionStatus.initializing`) before it was fixed by wrapping `_init()`'s
/// entire body in try/catch and resolving `state` to a terminal value on
/// every path.
///
/// **Not flagged:**
/// - The call is `await`ed (ordinary sequential async code — a thrown
///   exception propagates to whatever calls `build()`/the method, it does
///   not vanish).
/// - The call is a bare statement but lexically inside a `try { ... }`
///   block at the call site.
/// - The callee's body contains at least one `try` statement anywhere —
///   this rule does not verify the try/catch is exhaustive (that is a
///   human-triage question for code review), only that the class made
///   *some* attempt to guard the async work it fired off. This mirrors
///   `AuthStateNotifier._init()` post-fix, which is deliberately NOT
///   flagged by this rule.
/// - The callee is public, or its body is not declared `async` (a
///   fire-and-forget call to a synchronous method cannot leave a dangling
///   Future rejection).
///
/// Detection is purely syntactic: `build()` calling a private sibling
/// method by name, resolved within the same class declaration. It does not
/// follow calls through a second method (`build()` calling `_setup()` which
/// itself fires `_init()`) — that indirection is intentionally left to
/// human triage rather than risking false positives from deeper call-graph
/// heuristics.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoUnguardedAsyncNotifierInit extends DartLintRule {
  const NoUnguardedAsyncNotifierInit() : super(code: _code);

  static const _code = LintCode(
    name: 'no_unguarded_async_notifier_init',
    problemMessage:
        'build() fires this private async method fire-and-forget (not '
        'awaited, not wrapped in try/catch here) and the method itself has '
        'no try/catch anywhere in its body — an exception there is an '
        'unobserved Future rejection that can strand this Notifier at its '
        "build()-time placeholder state forever. Wrap the method's body in "
        'try/catch and resolve `state` to a terminal value on every path '
        '(see AUD-account-11 / AuthStateNotifier._init()).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Riverpod superclass names that mark a class as a Notifier. The
  /// riverpod_generator codegen shape (`class Foo extends _$Foo`) is
  /// detected separately in [_isNotifierLike].
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

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((unit) {
      for (final decl in unit.declarations) {
        if (decl is! ClassDeclaration) continue;
        if (!_isNotifierLike(decl)) continue;

        final buildMethod = _findInstanceMethod(decl, 'build');
        if (buildMethod == null) continue;

        final buildBody = buildMethod.body;
        if (buildBody is! BlockFunctionBody) continue;

        final finder = _FireAndForgetFinder();
        buildBody.block.accept(finder);

        for (final invocation in finder.calls) {
          final methodName = invocation.methodName.name;
          final callee = _findInstanceMethod(decl, methodName);
          if (callee == null) continue;
          if (!callee.body.isAsynchronous) continue;
          if (_containsTry(callee.body)) continue;

          reporter.atNode(invocation, _code);
        }
      }
    });
  }

  /// True when [decl] is a Riverpod Notifier: either its superclass is one
  /// of the well-known Riverpod base classes ([_notifierSuperclassNames]),
  /// or it follows riverpod_generator's `class Foo extends _$Foo` codegen
  /// convention (the shape every `@riverpod`/`@Riverpod`-annotated class
  /// produces, e.g. `class AuthStateNotifier extends _$AuthStateNotifier`).
  static bool _isNotifierLike(ClassDeclaration decl) {
    final superName = decl.extendsClause?.superclass.name.lexeme;
    if (superName == null) return false;
    if (superName == '_\$${decl.name.lexeme}') return true;
    return _notifierSuperclassNames.contains(superName);
  }

  static MethodDeclaration? _findInstanceMethod(
    ClassDeclaration decl,
    String name,
  ) {
    for (final member in decl.members) {
      if (member is MethodDeclaration &&
          !member.isStatic &&
          member.name.lexeme == name) {
        return member;
      }
    }
    return null;
  }

  static bool _containsTry(FunctionBody body) {
    final finder = _TryFinder();
    body.accept(finder);
    return finder.found;
  }
}

/// Collects every bare (statement-level, unawaited) call to a private
/// (`_`-prefixed) method — `_foo();` or `this._foo();` — that is NOT
/// lexically inside a `try { ... }` block, anywhere within the visited body.
class _FireAndForgetFinder extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> calls = [];

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final expr = node.expression;
    if (expr is MethodInvocation) {
      final target = expr.target;
      final isUnqualifiedOrThis = target == null || target is ThisExpression;
      if (isUnqualifiedOrThis &&
          expr.methodName.name.startsWith('_') &&
          !_isInsideTryBody(node)) {
        calls.add(expr);
      }
    }
    super.visitExpressionStatement(node);
  }

  /// Walks parent pointers from [node] to the root, returning true if the
  /// walk ever passes from a `TryStatement`'s guarded `body` block into the
  /// `TryStatement` itself (as opposed to arriving via a `catchClauses`
  /// entry or the `finallyBlock`, neither of which protects the call).
  bool _isInsideTryBody(AstNode node) {
    AstNode child = node;
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is TryStatement && identical(child, parent.body)) {
        return true;
      }
      child = parent;
      parent = parent.parent;
    }
    return false;
  }
}

/// Sets [found] if the visited subtree contains a `try` statement anywhere
/// (including nested inside `if`/`for`/etc).
class _TryFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitTryStatement(TryStatement node) {
    found = true;
    // No need to recurse into it once found; harmless if we do.
  }
}
