// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-core-widgets-01 (AX-2 / EH-5) Rule-0 checker.
///
/// `AppErrorView`, `ErrorDisplay`, and `PinEntryWidget` are shared, widely
/// reused widgets in a Hebrew-first, EN+HE app (`AppErrorView` alone is used
/// from 16+ screens; `PinEntryWidget` gates parent-mode PIN entry). A
/// hardcoded English literal in any of their user-facing string slots ships
/// untranslated text into an otherwise-Hebrew UI — this is exactly the
/// defect class AUD-core-widgets-01 found and fixed.
///
/// Deliberately scoped to EXACTLY the three files named by that finding, not
/// all of `lib/core/widgets/` — other files in that directory may carry
/// pre-existing, differently-scoped violations that are not this finding's
/// responsibility to fix (scope discipline). Everywhere else in the app
/// remains covered only by [NoHardcodedDomainTerm] (curated Torah-term list)
/// plus manual review.
///
/// **Compliant**:
/// ```dart
/// Text(l10n.actionRetry)
/// _ErrorConfig(title: l10n.appErrorViewGenericTitle, subtitle: l10n.appErrorViewGenericBody, ...)
/// ```
///
/// **Violation**:
/// ```dart
/// Text('Retry')
/// _ErrorConfig(title: 'Something went wrong', ...)
/// ```
class NoHardcodedErrorWidgetString extends DartLintRule {
  const NoHardcodedErrorWidgetString() : super(code: _code);

  static const _code = LintCode(
    name: 'no_hardcoded_error_widget_string',
    problemMessage:
        'Hardcoded English literal in AppErrorView / ErrorDisplay / '
        'PinEntryWidget — resolve through AppLocalizations/ARB instead '
        '(AUD-core-widgets-01, AX-2/EH-5).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Exact target files (path-separator-normalised suffix match). This rule
  /// is intentionally scoped to just these three — see class doc.
  static const _targetFileSuffixes = {
    'lib/core/widgets/app_error_view.dart',
    'lib/core/widgets/error_display.dart',
    'lib/core/widgets/pin_entry_widget.dart',
  };

  /// Named arguments that render user-facing text in these widgets.
  /// Includes the internal `_ErrorConfig` helper's `title`/`subtitle`
  /// fields (not only real Flutter widget constructors) since that is where
  /// AppErrorView's original violations lived.
  static const _uiNamedArgs = {
    'title',
    'subtitle',
    'content',
    'message',
    'label',
    'semanticLabel',
    'tooltip',
    'hintText',
    'labelText',
    'errorText',
  };

  /// Widget constructors that take a positional user-facing string.
  static const _uiWidgets = {'Text', 'SnackBar', 'Tooltip'};

  /// At least one ASCII letter — excludes purely structural literals like
  /// `' '` (obscuring char) or `''` (empty counter text). English-literal
  /// detection only needs ASCII: this app's hardcoded-English defect class
  /// (AX-2) is, by definition, ASCII prose.
  static final _hasLetter = RegExp('[A-Za-z]');

  static bool _isTargetFile(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    return _targetFileSuffixes.any(path.endsWith);
  }

  /// Returns true when [literal] sits in a user-facing string slot: either
  /// a UI-facing named argument (`title: '...'`) or a positional argument to
  /// one of [_uiWidgets] (`Text('...')`).
  ///
  /// Errs toward FEWER false positives — a literal used as a Map key, enum
  /// value, or plain variable is not flagged.
  static bool _isInUiContext(AstNode literal) {
    final parent = literal.parent;
    if (parent == null) return false;

    if (parent is NamedExpression) {
      final argName = parent.name.label.name;
      if (!_uiNamedArgs.contains(argName)) return false;
      return _enclosingIsInvocation(parent);
    }

    if (parent is ArgumentList) {
      final name = _invocationName(parent.parent);
      return name != null && _uiWidgets.contains(name);
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

  void _reportIfHardcoded(
    AstNode literal,
    String text,
    ErrorReporter reporter,
  ) {
    if (!_hasLetter.hasMatch(text)) return;
    if (!_isInUiContext(literal)) return;
    reporter.atNode(literal, _code);
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isTargetFile(resolver.path)) return;

    // `'Retry'`
    context.registry.addSimpleStringLiteral((node) {
      _reportIfHardcoded(node, node.value, reporter);
    });

    // `'Try again in $n minute(s)'` — interpolations: inspect literal chunks.
    context.registry.addStringInterpolation((node) {
      final buffer = StringBuffer();
      for (final element in node.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        }
      }
      _reportIfHardcoded(node, buffer.toString(), reporter);
    });
  }
}
