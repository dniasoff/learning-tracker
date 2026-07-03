// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a Torah DOMAIN-TERM English literal hardcoded in a USER-FACING string
/// in presentation code.
///
/// The app must render Torah domain terms through the shared label library
/// ([domainTermLabels] / [CurriculumLabels] / [CurriculumLabelRenderer]) or via
/// l10n so they honour the Hebrew-terms contract and the Ashkenazi/Sephardi
/// nusach setting (see `docs/hebrew-terms.md`). A bare English literal such as
/// `Text('Mishnayos done!')` bypasses that contract.
///
/// The curated term list is deliberately CONSERVATIVE: only high-signal
/// plurals/variants are flagged. Ambiguous common English words (Review, Page,
/// Seder, Daf, Amud, Perek, Mishnah, Siyum) are excluded to avoid false
/// positives.
///
/// **Compliant** (route through the label library):
/// ```dart
/// // Bad — hardcoded domain term in UI string
/// Text('Mishnayos done!')
///
/// // Good — rendered via the shared label library / l10n
/// Text(domainTermLabels(ref).mishnayos)
/// Text(l10n.mishnayosDone)
/// ```
class NoHardcodedDomainTerm extends DartLintRule {
  const NoHardcodedDomainTerm() : super(code: _code);

  static const _code = LintCode(
    name: 'no_hardcoded_domain_term',
    problemMessage:
        "Hardcoded Torah domain term in UI — render via domainTermLabels / "
        'CurriculumLabels / l10n so it honours the Hebrew-terms + '
        'Ashkenazi/Sephardi settings.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Curated, conservative list of high-signal Torah domain terms.
  ///
  /// Case-sensitive whole-word matching is used against the literal text.
  /// Deliberately excludes ambiguous singulars / common English words
  /// (Review, Page, Seder, Daf, Amud, Perek, Mishnah, Siyum).
  static const _domainTerms = {
    'Mishnayos',
    'Mishnayot',
    'Masechta',
    'Masechtos',
    'Masekhet',
    'Masekhtot',
    'Dafim',
    'Dapim',
    'Amudim',
    'Perakim',
    'Pesukim',
    'Chazara',
    'Siyumim',
    'Shabbos',
    'Shabbat',
    'Tractate',
    'Sedarim',
  };

  /// Named arguments / constructors that render user-facing text.
  static const _uiNamedArgs = {
    'labelText',
    'hintText',
    'title',
    'subtitle',
    'content',
    'message',
    'semanticLabel',
    'tooltip',
  };

  /// Widget constructors that take a positional user-facing string.
  static const _uiWidgets = {
    'Text',
    'SnackBar',
    'Tooltip',
  };

  /// Returns true when [filePath] must NOT be linted.
  ///
  /// Exempt:
  ///   - `lib/core/labels/` — the canonical label library.
  ///   - `lib/l10n/` — generated/authored localisation (ARB English legitimately
  ///     contains these words).
  ///   - `*.g.dart` / `*.freezed.dart` — generated files.
  ///   - test files (`/test/` or `_test.dart`).
  static bool _isExempt(String filePath) {
    final path = filePath.replaceAll(r'\', '/');
    if (path.contains('lib/core/labels/')) return true;
    if (path.contains('lib/l10n/')) return true;
    if (path.endsWith('.g.dart')) return true;
    if (path.endsWith('.freezed.dart')) return true;
    if (path.contains('/test/')) return true;
    if (path.endsWith('_test.dart')) return true;
    return false;
  }

  /// Returns the first curated domain term that appears as a WHOLE WORD
  /// (case-sensitive) in [text], or null if none.
  static String? _matchedTerm(String text) {
    for (final term in _domainTerms) {
      final pattern = RegExp('(?<![A-Za-z])${RegExp.escape(term)}(?![A-Za-z])');
      if (pattern.hasMatch(text)) return term;
    }
    return null;
  }

  /// Returns true when [node] is an argument in a user-facing widget context.
  ///
  /// Pragmatic context detection — flags only when the literal is:
  ///   - a positional argument to a `Text(...)` / `SnackBar(...)` / `Tooltip(...)`
  ///     constructor, OR
  ///   - the value of a UI-facing named argument (`labelText:`, `title:`, ...).
  ///
  /// Errs toward FEWER false positives: a literal used as a Map key, enum
  /// value, plain variable, etc. is not flagged.
  static bool _isInUiContext(AstNode literal) {
    final parent = literal.parent;
    if (parent == null) return false;

    // Named argument value: `title: 'Mishnayos'`.
    if (parent is NamedExpression) {
      final argName = parent.name.label.name;
      if (!_uiNamedArgs.contains(argName)) return false;
      return _enclosingIsInvocation(parent);
    }

    // Positional argument inside an argument list: `Text('Mishnayos')`.
    if (parent is ArgumentList) {
      return _invocationName(parent.parent) != null &&
          _uiWidgets.contains(_invocationName(parent.parent));
    }

    return false;
  }

  /// Returns the constructor/method name of [node] if it is an
  /// [InstanceCreationExpression] or [MethodInvocation], else null.
  static String? _invocationName(AstNode? node) {
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name.lexeme;
    }
    if (node is MethodInvocation) {
      return node.methodName.name;
    }
    return null;
  }

  /// Returns true when [namedExpr] is an argument to ANY invocation
  /// (constructor or method) — i.e. genuinely a UI-facing named parameter.
  static bool _enclosingIsInvocation(NamedExpression namedExpr) {
    final argList = namedExpr.parent;
    if (argList is! ArgumentList) return false;
    final invocation = argList.parent;
    return invocation is InstanceCreationExpression ||
        invocation is MethodInvocation;
  }

  void _reportIfDomainTerm(
    AstNode literal,
    String text,
    ErrorReporter reporter,
  ) {
    if (_matchedTerm(text) == null) return;
    if (!_isInUiContext(literal)) return;
    reporter.atNode(literal, _code);
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (_isExempt(resolver.path)) return;

    // `'Mishnayos done!'`
    context.registry.addSimpleStringLiteral((node) {
      _reportIfDomainTerm(node, node.value, reporter);
    });

    // `'Mishnayos: $count'` — interpolations: inspect the literal text chunks.
    context.registry.addStringInterpolation((node) {
      final buffer = StringBuffer();
      for (final element in node.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        }
      }
      _reportIfDomainTerm(node, buffer.toString(), reporter);
    });
  }
}
