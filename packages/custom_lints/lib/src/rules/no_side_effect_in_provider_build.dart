// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-sync-08 (AC1) Rule-0 checker — SM-2 Enforce backstop.
///
/// Flags two side-effect shapes found directly (synchronously) inside the
/// `create` callback passed to a legacy `Provider`/`StreamProvider`/
/// `FutureProvider` constructor (including their `.autoDispose`/`.family`
/// named constructors):
///
///   1. **A chained-property assignment** — `a.b.c = value;` where the
///      assignment target (`a.b`) is itself a member-access chain
///      (`PropertyAccess`, `PrefixedIdentifier`, or `MethodInvocation`),
///      not a bare local/`ref` identifier. This is the "DAO field mutation"
///      shape: reaching through a getter chain to mutate a field owned by
///      some other object (e.g. `database.pointsBalanceDao.syncSink = x;`).
///   2. **A call to `unawaited(...)`** — a fire-and-forget async call.
///
/// Both were exactly the shape in
/// `outboxSyncWriteFacadeProvider` (`features/sync/presentation/providers/
/// sync_providers.dart`, pre-AUD-sync-08 fix):
/// ```dart
/// final outboxSyncWriteFacadeProvider = Provider<OutboxSyncWriteFacade?>((ref) {
///   // ...
///   database.pointsBalanceDao.syncSink = facade;             // (1)
///   unawaited(database.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(profileId)); // (2)
///   return facade;
/// });
/// ```
///
/// **Severity: WARNING.** SM-2 (`docs/coding-standards.md`) requires
/// provider `build`/`create` bodies to stay pure: "no writes, no
/// request-firing, no side effects" — Riverpod's own do/don't guide
/// documents that side effects in `build` race and get skipped or
/// duplicated on rebuild. `build`/`create` can rerun for reasons unrelated
/// to a meaningful state change (a sibling watched provider rebuilding,
/// hot-reload, provider disposal/recreation, test overrides) — a
/// synchronous field mutation or fire-and-forget call there re-fires on
/// every such rerun with no way to gate it to "once per meaningful change".
///
/// **Not flagged (deliberately):**
/// - Assignments to a bare identifier or a single-hop property (`ref.state
///   = x;`, `count = 1;`) — these are ordinary state writes, not a reach
///   through an externally-owned object's chain.
/// - Anything inside a **nested closure** passed as an argument (e.g. an
///   `onEnqueueDrain: () async { ... }` callback) — those run later, on
///   whatever trigger the closure is wired to, not synchronously during
///   `build`/`create`. Detection does not descend into nested
///   `FunctionExpression` bodies.
/// - `@riverpod`-codegen `Notifier`/`AsyncNotifier` classes — those are
///   covered by [NoUnguardedAsyncNotifierInit] for their own build-time
///   hazard shape; this rule is scoped to the legacy `Provider`/
///   `StreamProvider`/`FutureProvider` constructor family named in SM-1/
///   SM-2.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoSideEffectInProviderBuild extends DartLintRule {
  const NoSideEffectInProviderBuild() : super(code: _code);

  static const _code = LintCode(
    name: 'no_side_effect_in_provider_build',
    problemMessage:
        'SM-2: this statement mutates a field reached through a chained '
        'member access, or fires an unawaited async call, directly inside '
        "a Provider's create callback. build/create can rerun for reasons "
        'unrelated to a meaningful state change and Riverpod\'s own '
        'do/don\'t guide documents that side effects there race or '
        'duplicate on rebuild — move it into ref.listen/onDispose or an '
        'explicit one-shot trigger instead (see AUD-sync-08).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Legacy provider constructor family this rule scopes to (SM-1's
  /// migration-candidate primitives that still take a raw `create` body).
  static const _providerConstructorNames = {
    'Provider',
    'StreamProvider',
    'FutureProvider',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path.replaceAll(r'\', '/');
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return;

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_providerConstructorNames.contains(typeName)) return;

      FunctionExpression? callback;
      for (final arg in node.argumentList.arguments) {
        if (arg is FunctionExpression) {
          callback = arg;
          break;
        }
      }
      if (callback == null) return;

      final body = callback.body;
      if (body is! BlockFunctionBody) return;

      final finder = _SideEffectFinder();
      body.block.accept(finder);

      for (final violation in finder.violations) {
        reporter.atNode(violation, _code);
      }
    });
  }
}

/// Collects the two violation shapes ([NoSideEffectInProviderBuild]'s
/// doc comment) found directly in a `create` callback's body, without
/// descending into nested function-literal bodies (deferred callbacks).
class _SideEffectFinder extends RecursiveAstVisitor<void> {
  final List<AstNode> violations = [];

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Deliberately do not call super/visitChildren: anything inside a
    // nested closure (e.g. `onEnqueueDrain: () async { ... }`) runs later,
    // not synchronously during this provider's build/create.
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    if (lhs is PropertyAccess && _isChainedTarget(lhs.target)) {
      violations.add(node);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'unawaited') {
      violations.add(node);
    }
    super.visitMethodInvocation(node);
  }

  /// True when [target] is itself a member-access chain (`a.b`, `a.b()`
  /// then `.c`) rather than a bare identifier — the "reached through a DAO
  /// getter chain" shape this rule targets.
  static bool _isChainedTarget(Expression? target) {
    return target is PropertyAccess ||
        target is PrefixedIdentifier ||
        target is MethodInvocation;
  }
}
