// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-gamification-10 (AC3) Rule-0 checker.
///
/// Flags a Riverpod Notifier -- including `riverpod_generator`'s
/// `class Foo extends _$Foo` codegen shape -- whose state carries a
/// `loading`/`error`-shaped pair of fields (evidenced structurally by a
/// `copyWith(loading: ..., error: ..., ...)` call somewhere in the file:
/// this project's state DTOs are hand-written classes, not resolvable via a
/// shared base type, so field-shape is inferred from how the Notifier's own
/// mutation methods already construct the next state) where the file
/// contains **zero** `copyWith(...)` call that sets `error:` to anything
/// other than the literal `null`.
///
/// A `loading`/`error` pair on a Notifier's state exists so the screen can
/// show a spinner and a real error message when a mutation fails. If every
/// `copyWith(error: ...)` call in the file only ever resets it to `null`,
/// the field is declared-but-dead: any exception besides the ones already
/// special-cased elsewhere becomes a silent, invisible failure -- the user
/// taps an action, nothing happens, and no code path ever surfaces why
/// (AUD-gamification-10 / `RewardConfigController` before the fix: `loading`
/// and `error` were only ever reset to `false`/`null` in `bootstrap()`, and
/// none of the four async mutation methods ever set either to a failure
/// value).
///
/// **Not flagged:**
/// - A file with no Notifier-like class at all (see
///   `no_unguarded_async_notifier_init.dart`'s `_isNotifierLike` for the
///   same detection convention reused here).
/// - A file whose `copyWith(...)` calls never mention BOTH `loading:` and
///   `error:` together -- this rule only targets the specific
///   loading+error pair shape, not every optional-error field.
/// - A file with at least one `copyWith(error: <non-null>)` call anywhere
///   -- the field is being driven from at least one code path, even if
///   that coverage is incomplete (a human-triage question, not this rule's
///   job).
///
/// Detection is purely syntactic and file-scoped (no cross-file type
/// resolution): it does not verify the `copyWith` calls are chained off
/// `state` specifically, nor that the state class's `loading`/`error`
/// fields are the SAME class as the Notifier's declared state type -- see
/// `packages/custom_lints/README.md` for rule rationale and remediation.
class NoDeadErrorField extends DartLintRule {
  const NoDeadErrorField() : super(code: _code);

  static const _code = LintCode(
    name: 'no_dead_error_field',
    problemMessage:
        'SM-5 / EH-2 (AUD-gamification-10): this file\'s state carries a '
        'loading/error field pair (copyWith(loading: ..., error: ...) is '
        'called here), but no copyWith(...) call anywhere in the file ever '
        'sets `error:` to anything other than `null` -- the field is '
        'declared-but-dead. Any exception in an async mutation becomes a '
        'silent failure: no spinner clears, no error shows. Wire a failure '
        'path (e.g. via AsyncValue.guard) to set state.error on the '
        'non-happy path.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Riverpod superclass names that mark a class as a Notifier. Mirrors
  /// `no_unguarded_async_notifier_init.dart`'s `_notifierSuperclassNames`.
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
      ClassDeclaration? notifierClass;
      for (final decl in unit.declarations) {
        if (decl is ClassDeclaration && _isNotifierLike(decl)) {
          notifierClass = decl;
          break;
        }
      }
      if (notifierClass == null) return;

      final finder = _CopyWithLoadingErrorFinder();
      unit.accept(finder);

      if (!finder.hasLoadingArg || !finder.hasErrorArg) return;
      if (finder.hasNonNullErrorAssignment) return;

      reporter.atNode(notifierClass, _code);
    });
  }

  /// True when [decl] is a Riverpod Notifier: either its superclass is one
  /// of the well-known Riverpod base classes, or it follows
  /// riverpod_generator's `class Foo extends _$Foo` codegen convention (the
  /// shape every `@riverpod`/`@Riverpod`-annotated class produces).
  static bool _isNotifierLike(ClassDeclaration decl) {
    final superName = decl.extendsClause?.superclass.name.lexeme;
    if (superName == null) return false;
    if (superName == '_\$${decl.name.lexeme}') return true;
    return _notifierSuperclassNames.contains(superName);
  }
}

/// Walks every `copyWith(...)` call in the compilation unit, recording
/// whether `loading:`/`error:` named arguments appear anywhere, and whether
/// any `error:` argument is assigned something other than the literal
/// `null`.
class _CopyWithLoadingErrorFinder extends RecursiveAstVisitor<void> {
  bool hasLoadingArg = false;
  bool hasErrorArg = false;
  bool hasNonNullErrorAssignment = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'copyWith') {
      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final argName = arg.name.label.name;
        if (argName == 'loading') {
          hasLoadingArg = true;
        } else if (argName == 'error') {
          hasErrorArg = true;
          if (arg.expression is! NullLiteral) {
            hasNonNullErrorAssignment = true;
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}
