// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-tutoring-08 (PF-2) Rule-0 checker.
///
/// Flags an eagerly-expanded widget list — `for (final x in y) Widget(...)`,
/// or `…iterable.map((x) => Widget(...))` / `.map(...).toList()` — fed
/// directly into the `children:` of a NON-lazy scroll container:
///   - `ListView(children: […])` — the plain/default constructor, NOT
///     `.builder`/`.separated`/`.custom`, which are already lazy; or
///   - a `Column(children: […])` that is itself wrapped in a
///     `SingleChildScrollView` (making the whole column scroll).
///
/// A lazy `ListView.builder` (flattening multiple sections into one
/// item-model list, if needed) should be used instead whenever the expanded
/// collection is not provably small/bounded. To stay precise against
/// known-bounded, small, literal sources — and avoid flagging the many
/// legitimately-small fixed lists in the codebase (tab bars, filter chips,
/// a fixed enum's `.values`, an explicitly `.take(n)`-capped preview) — this
/// rule does NOT flag:
///   - `SomeEnum.values` (a compile-time-bounded enumeration);
///   - any iterable explicitly capped via `.take(n)`; or
///   - a list/set literal.
///
/// This is exactly the pattern AUD-tutoring-08 found duplicated across
/// `ManageGrantsScreen` (a `for` loop feeding a plain `ListView(children:)`)
/// and Settings' embedded `_PendingInvitesSection` (a `for` loop feeding a
/// `Column` inside the section) — both driven by `incomingTutorGrantsProvider`
/// / `pendingTutorInvitesProvider`, an unbounded roster with no archiving
/// path. See `docs/audits/standards-audit-2026-07-03/delivery/findings/
/// AUD-tutoring-08.json` (acceptance_criteria[0], "Rule-0: PF-2 checker").
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoEagerListInNonLazyScrollContainer extends DartLintRule {
  const NoEagerListInNonLazyScrollContainer() : super(code: _code);

  static const _code = LintCode(
    name: 'no_eager_list_in_non_lazy_scroll_container',
    problemMessage:
        'PF-2: this for-loop/.map() expansion eagerly builds every row up '
        'front inside a non-lazy ListView/Column instead of a lazy '
        'ListView.builder. Unbounded (provider-driven) collections must be '
        'built lazily so off-screen rows are never realized — see '
        'AUD-tutoring-08.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path.replaceAll(r'\', '/');
    if (!path.contains('/lib/features/')) return;
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return;

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      final namedConstructor = node.constructorName.name?.name;

      if (typeName == 'ListView') {
        // Only the plain/default constructor is eager; `.builder`,
        // `.separated` and `.custom` are already lazy and must never be
        // flagged.
        if (namedConstructor != null) return;
        _checkChildrenArgument(node, reporter);
        return;
      }

      if (typeName == 'Column') {
        if (!_isWrappedInSingleChildScrollView(node)) return;
        _checkChildrenArgument(node, reporter);
      }
    });
  }

  void _checkChildrenArgument(
    InstanceCreationExpression node,
    ErrorReporter reporter,
  ) {
    Expression? childrenValue;
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'children') {
        childrenValue = arg.expression;
        break;
      }
    }
    if (childrenValue == null) return;

    // Shape 1: `children: [ …, for (final x in y) Widget(x), … ]` or
    // `children: [ …, ...xs.map((x) => Widget(x)), … ]`.
    if (childrenValue is ListLiteral) {
      for (final element in childrenValue.elements) {
        if (element is ForElement && !_isBoundedForLoop(element)) {
          reporter.atNode(element, _code);
          continue;
        }
        if (element is SpreadElement &&
            _isEagerMapExpansion(element.expression)) {
          reporter.atNode(element, _code);
        }
      }
      return;
    }

    // Shape 2: `children: xs.map((x) => Widget(x)).toList()` — the entire
    // children value IS the eager expansion, with no list literal wrapper.
    if (_isEagerMapExpansion(childrenValue)) {
      reporter.atNode(childrenValue, _code);
    }
  }

  /// True for a bounded for-loop:
  ///   - `for (final x in EXPR) …` where `EXPR` is a provably-bounded source
  ///     (see [_isBoundedSource]); or
  ///   - a C-style counter loop `for (var i = 0; i < EXPR.length; i++) …`
  ///     whose upper bound is a provably-bounded source's `.length` (e.g.
  ///     `for (var i = 0; i < SomeEnum.values.length; i++)`).
  bool _isBoundedForLoop(ForElement element) {
    final forLoopParts = element.forLoopParts;
    if (forLoopParts is ForEachPartsWithDeclaration) {
      return _isBoundedSource(forLoopParts.iterable);
    }
    if (forLoopParts is ForPartsWithDeclarations) {
      final condition = forLoopParts.condition;
      return condition != null && _isBoundedCounterCondition(condition);
    }
    return false;
  }

  /// True for `i < EXPR.length` / `i <= EXPR.length` where `EXPR` is a
  /// provably-bounded source (see [_isBoundedSource]).
  bool _isBoundedCounterCondition(Expression condition) {
    if (condition is! BinaryExpression) return false;
    final operator = condition.operator.type;
    if (operator != TokenType.LT && operator != TokenType.LT_EQ) return false;

    final right = condition.rightOperand;
    if (right is PropertyAccess && right.propertyName.name == 'length') {
      return _isBoundedSource(right.target ?? right);
    }
    return false;
  }

  /// True for `<iterable>.map(...)` or `<iterable>.map(...).toList()` chains
  /// whose receiver is NOT a provably-bounded source (see
  /// [_isBoundedSource]).
  bool _isEagerMapExpansion(Expression expr) {
    MethodInvocation? mapCall;
    if (expr is MethodInvocation) {
      if (expr.methodName.name == 'toList') {
        final target = expr.target;
        if (target is MethodInvocation && target.methodName.name == 'map') {
          mapCall = target;
        }
      } else if (expr.methodName.name == 'map') {
        mapCall = expr;
      }
    }
    if (mapCall == null) return false;

    final receiver = mapCall.target;
    if (receiver == null) return false;
    return !_isBoundedSource(receiver);
  }

  /// `SomeEnum.values`, an explicitly `.take(n)`-capped iterable, or a
  /// list/set literal — all provably bounded/small, so exempt from this
  /// rule regardless of the container they feed.
  bool _isBoundedSource(Expression expr) {
    if (expr is PrefixedIdentifier && expr.identifier.name == 'values') {
      return true;
    }
    if (expr is PropertyAccess && expr.propertyName.name == 'values') {
      return true;
    }
    if (expr is MethodInvocation && expr.methodName.name == 'take') {
      return true;
    }
    if (expr is ListLiteral || expr is SetOrMapLiteral) return true;
    return false;
  }

  /// True when [node] (a `Column(...)` creation) is nested inside a
  /// `SingleChildScrollView(...)` creation within the same expression tree
  /// — i.e. the Column IS the thing that scrolls, the "scrollable Column"
  /// shape this rule targets. Climbing stops at the first closure/method
  /// boundary: a `Column` built inside another widget's own per-item
  /// builder closure (e.g. a `ListView.builder`'s `itemBuilder`) is a
  /// single row's own layout, not the top-level scrolling list, and must
  /// not be flagged.
  bool _isWrappedInSingleChildScrollView(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression || current is MethodDeclaration) {
        return false;
      }
      if (current is InstanceCreationExpression &&
          current.constructorName.type.name.lexeme ==
              'SingleChildScrollView') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
