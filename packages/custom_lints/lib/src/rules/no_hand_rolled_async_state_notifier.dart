// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-account-14 / SM-5 candidate flag.
///
/// Flags a plain `Notifier<T>` (never `AsyncNotifier<T>` / `AsyncValue<T>`,
/// which are the ones this rule nudges towards) whose state type `T` is a
/// hand-rolled sealed union with Idle/Initial-, Loading/Submitting-, AND
/// Error/Failure-shaped variants — the exact shape `AsyncValue<T>` already
/// models for free via `AsyncData` / the in-flight gap / `AsyncError`.
///
/// This is an INFO-level nudge, not a hard error. Detection is purely
/// syntactic (subclass name matching within the same file/library), so it
/// cannot distinguish "~20 scattered `state = ...` assignments" (the actual
/// SM-5 defect) from a notifier that keeps this public sealed-state shape
/// deliberately while driving every transition through a single internal
/// `AsyncValue.guard(...)` call — SM-5's own documented lighter-weight
/// alternative to a full `AsyncNotifier` migration (see
/// `sign_in_controller.dart`'s `SignInController`, fixed under
/// AUD-account-14: it still matches this shape by design and is an accepted,
/// intentional case). Both are surfaced as migration *candidates* for human
/// triage, not violations to silence.
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoHandRolledAsyncStateNotifier extends DartLintRule {
  const NoHandRolledAsyncStateNotifier() : super(code: _code);

  static const _code = LintCode(
    name: 'no_hand_rolled_async_state_notifier',
    problemMessage:
        'SM-5 AsyncNotifier-migration candidate: this Notifier<T> state type '
        'is a hand-rolled sealed union with Idle/Loading- and Error-shaped '
        'variants. Consider AsyncNotifier<T> + AsyncValue.guard so unhappy-'
        'path state transitions are guaranteed by the framework rather than '
        'hand-managed try/catch assignments.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final _idlePattern = RegExp('idle|initial', caseSensitive: false);
  static final _loadingPattern = RegExp(
    'loading|submitting|pending|inprogress|busy',
    caseSensitive: false,
  );
  static final _errorPattern = RegExp(
    'error|failure|failed',
    caseSensitive: false,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((unit) {
      // Pass 1: index every sealed class name, and every class's direct
      // subclasses by its (syntactic) superclass name — sealed subtypes must
      // live in the same library, so a same-file/library scan is sufficient.
      final sealedClassNames = <String>{};
      final subclassNamesBySuper = <String, List<String>>{};

      for (final decl in unit.declarations) {
        if (decl is! ClassDeclaration) continue;
        if (decl.sealedKeyword != null) {
          sealedClassNames.add(decl.name.lexeme);
        }
        final superName = decl.extendsClause?.superclass.name.lexeme;
        if (superName != null) {
          subclassNamesBySuper.putIfAbsent(superName, () => []).add(
                decl.name.lexeme,
              );
        }
      }

      if (sealedClassNames.isEmpty) return;

      // Pass 2: find `class X extends Notifier<T>` where T is one of the
      // sealed classes indexed above, and check T's subclass names cover
      // all three of the Idle / Loading / Error buckets.
      for (final decl in unit.declarations) {
        if (decl is! ClassDeclaration) continue;
        final extendsClause = decl.extendsClause;
        if (extendsClause == null) continue;
        // Exact match only. AsyncNotifier / StreamNotifier / NotifierBase
        // subtypes are the migration target itself and must never be
        // flagged; a substring match would wrongly catch them too.
        if (extendsClause.superclass.name.lexeme != 'Notifier') continue;

        final typeArgs = extendsClause.superclass.typeArguments?.arguments;
        if (typeArgs == null || typeArgs.length != 1) continue;
        final stateTypeArg = typeArgs.first;
        if (stateTypeArg is! NamedType) continue;
        final stateTypeName = stateTypeArg.name.lexeme;

        if (!sealedClassNames.contains(stateTypeName)) continue;

        final subclassNames = subclassNamesBySuper[stateTypeName] ?? const [];
        final hasIdle = subclassNames.any((n) => _idlePattern.hasMatch(n));
        final hasLoading = subclassNames.any(
          (n) => _loadingPattern.hasMatch(n),
        );
        final hasError = subclassNames.any((n) => _errorPattern.hasMatch(n));

        if (hasIdle && hasLoading && hasError) {
          reporter.atNode(extendsClause, _code);
        }
      }
    });
  }
}
