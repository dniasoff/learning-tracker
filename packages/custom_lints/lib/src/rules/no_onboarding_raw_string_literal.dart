// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-onboarding-04 / AX-2 [P] literals checker.
///
/// Flags a raw (non-empty) string literal — or a string interpolation whose
/// literal text chunks are non-empty — passed directly as a USER-FACING text
/// argument under `lib/features/onboarding/presentation/**`: a positional
/// argument to `Text(`/`SnackBar(`/`Tooltip(`, or the value of a UI-facing
/// named argument (`errorText:`, `hintText:`, `labelText:`, `label:`,
/// `title:`, `text:`, `message:`, `content:`, `semanticLabel:`, `tooltip:`)
/// on ANY constructor/method call.
///
/// The onboarding flow is this app's Hebrew-locale first-impression surface
/// (AUD-onboarding-03/-04): a bare English literal here ships untranslated
/// text into the Hebrew build. Every one of these sites must instead resolve
/// through `AppLocalizations` (`l10n.someKey`), never a hand-typed literal.
///
/// **Compliant**:
/// ```dart
/// // Bad — hardcoded literal
/// Text('Set a 4-digit PIN')
/// AppBarTitle(text: 'All Set!')
/// TextFormField(decoration: InputDecoration(errorText: 'PINs do not match'))
///
/// // Good — resolved through AppLocalizations
/// Text(l10n.onboardingSetPinTitle)
/// AppBarTitle(text: l10n.onboardingAllSetTitle)
/// TextFormField(decoration: InputDecoration(errorText: l10n.pinMismatch))
/// ```
///
/// Deliberately scoped ONLY to `lib/features/onboarding/presentation/**` —
/// this is a directory-scoped follow-on to `no_hardcoded_domain_term`, not a
/// general-purpose AX-2 literals checker for the whole app (that remains
/// [Pending] per `docs/coding-standards.md`).
class NoOnboardingRawStringLiteral extends DartLintRule {
  const NoOnboardingRawStringLiteral() : super(code: _code);

  static const _code = LintCode(
    name: 'no_onboarding_raw_string_literal',
    problemMessage:
        'AX-2: raw string literal passed as onboarding UI text — resolve '
        'through AppLocalizations (l10n.someKey) instead of a hardcoded '
        'literal so Hebrew-locale users see translated text.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Named arguments / constructors that render user-facing text.
  static const _uiNamedArgs = {
    'errorText',
    'hintText',
    'labelText',
    'label',
    'title',
    'text',
    'message',
    'content',
    'semanticLabel',
    'tooltip',
  };

  /// Widget constructors that take a positional user-facing string.
  static const _uiWidgets = {
    'Text',
    'SnackBar',
    'Tooltip',
  };

  /// Returns true when [filePath] is within the scoped onboarding
  /// presentation directory and must be linted.
  ///
  /// Exempt: generated files, and test files (`/test/` or `_test.dart`) —
  /// tests legitimately assert on literal strings.
  static bool _isInScope(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (!path.contains('lib/features/onboarding/presentation/')) {
      return false;
    }
    if (path.endsWith('.g.dart')) return false;
    if (path.endsWith('.freezed.dart')) return false;
    if (path.contains('/test/')) return false;
    if (path.endsWith('_test.dart')) return false;
    return true;
  }

  /// Returns true when [text] is non-empty after trimming — an empty or
  /// whitespace-only literal (e.g. a spacer `''`, a join separator) is never
  /// user-facing prose and must not be flagged.
  static bool _isNonEmptyProse(String text) => text.trim().isNotEmpty;

  /// Returns true when [node] is an argument in a user-facing widget context.
  ///
  /// Mirrors `no_hardcoded_domain_term`'s pragmatic, low-false-positive
  /// context detection: only positional args to [_uiWidgets] constructors,
  /// or the value of a [_uiNamedArgs] named argument to ANY invocation.
  static bool _isInUiContext(AstNode literal) {
    final parent = literal.parent;
    if (parent == null) return false;

    // Named argument value: `errorText: 'PINs do not match'`.
    if (parent is NamedExpression) {
      final argName = parent.name.label.name;
      if (!_uiNamedArgs.contains(argName)) return false;
      return _enclosingIsInvocation(parent);
    }

    // Positional argument inside an argument list: `Text('All Set!')`.
    if (parent is ArgumentList) {
      return _invocationName(parent.parent) != null &&
          _uiWidgets.contains(_invocationName(parent.parent));
    }

    return false;
  }

  static String? _invocationName(AstNode? node) {
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name.lexeme;
    }
    if (node is MethodInvocation) {
      return node.methodName.name;
    }
    return null;
  }

  static bool _enclosingIsInvocation(NamedExpression namedExpr) {
    final argList = namedExpr.parent;
    if (argList is! ArgumentList) return false;
    final invocation = argList.parent;
    return invocation is InstanceCreationExpression ||
        invocation is MethodInvocation;
  }

  void _reportIfViolation(
    AstNode literal,
    String text,
    ErrorReporter reporter,
  ) {
    if (!_isNonEmptyProse(text)) return;
    if (!_isInUiContext(literal)) return;
    reporter.atNode(literal, _code);
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isInScope(resolver.path)) return;

    // `'All Set!'`
    context.registry.addSimpleStringLiteral((node) {
      // An AppLocalizations getter access (`l10n.foo`) is a
      // PrefixedIdentifier/PropertyAccess, never a SimpleStringLiteral, so
      // legitimate l10n usage never reaches this callback at all.
      _reportIfViolation(node, node.value, reporter);
    });

    // `"$name's learning is all set up"` — inspect the literal text chunks;
    // an interpolation whose ONLY content is `${...}` expressions (no
    // literal prose) is not flagged (e.g. `'${someLabel}'`).
    context.registry.addStringInterpolation((node) {
      final buffer = StringBuffer();
      for (final element in node.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        }
      }
      _reportIfViolation(node, buffer.toString(), reporter);
    });
  }
}
