// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-tutoring-08 / AUD-scheduler-01 (PF-2) Rule-0 checker.
///
/// Flags an eagerly-expanded widget list — `for (final x in y) Widget(...)`,
/// `…iterable.map((x) => Widget(...))` / `.map(...).toList()`, or
/// `List.generate(count, (i) => Widget(...))` — fed directly into the
/// `children:` of a NON-lazy container:
///   - `ListView(children: […])` — the plain/default constructor, NOT
///     `.builder`/`.separated`/`.custom`, which are already lazy;
///   - a `Column(children: […])` that is itself wrapped in a
///     `SingleChildScrollView` (making the whole column scroll); or
///   - an `ExpansionTile(children: […])` — `ExpansionTile`'s own children
///     list has NO virtualization: the moment the tile itself is built
///     (e.g. `initiallyExpanded: true`, or the user expands it), every one
///     of its children is built up front regardless of viewport, even when
///     the tile is one lazily-mounted item inside an outer
///     `ListView.builder`.
///
/// A lazy `ListView.builder` (flattening multiple sections into one
/// item-model list, if needed) should be used instead whenever the expanded
/// collection is not provably small/bounded. To stay precise against
/// known-bounded, small, literal sources — and avoid flagging the many
/// legitimately-small fixed lists in the codebase (tab bars, filter chips,
/// a fixed enum's `.values`, an explicitly `.take(n)`-capped preview) — this
/// rule does NOT flag:
///   - `SomeEnum.values` (a compile-time-bounded enumeration);
///   - any iterable explicitly capped via `.take(n)`;
///   - a list/set literal; or
///   - a `List.generate(n, ...)` whose count is a literal int or a
///     `.length` read off one of the above bounded sources (e.g.
///     `List.generate(CurriculumId.values.length, ...)`).
///
/// This rule was written for two duplicated real-world shapes:
///   - AUD-tutoring-08: `ManageGrantsScreen` (a `for` loop feeding a plain
///     `ListView(children:)`) and Settings' embedded
///     `_PendingInvitesSection` (a `for` loop feeding a `Column` inside the
///     section) — both driven by `incomingTutorGrantsProvider` /
///     `pendingTutorInvitesProvider`, an unbounded roster with no archiving
///     path. See `docs/audits/standards-audit-2026-07-03/delivery/findings/
///     AUD-tutoring-08.json` (acceptance_criteria[0], "Rule-0: PF-2
///     checker").
///   - AUD-scheduler-01: `GroupedDailyView` called
///     `List.generate(tasks.length, (i) => DailyTaskCard(...))` inside an
///     always-expanded `ExpansionTile`, itself inside a plain
///     `ListView(children: curricula.map(...).toList())` — an unbounded,
///     provider-derived overdue-task backlog. See
///     `docs/audits/standards-audit-2026-07-03/delivery/findings/
///     AUD-scheduler-01.json` (acceptance_criteria[0], "Rule-0: PF-2
///     checker").
///   - AUD-settings-08: `ScopeSelectionScreen._buildBody` fed a plain
///     `ListView(children: [...])` a `for (final grant in activeGrants)`
///     -shaped list one level removed — an `if (!_selectAll) ...[…]` guard
///     spreading a nested list literal whose last element was
///     `..._buildLevelValueTiles(allItems)`, a same-class helper method
///     whose OWN body did the eager `values.map((value) => ...).toList()`
///     expansion. Neither the nested `if`/spread-of-list-literal wrapper
///     nor the one-hop indirection through a helper method were visible to
///     the original shapes above, which only inspected `children:`'s
///     direct elements. See `docs/audits/standards-audit-2026-07-03/
///     delivery/findings/AUD-settings-08.json` (acceptance_criteria[0]).
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoEagerListInNonLazyScrollContainer extends DartLintRule {
  const NoEagerListInNonLazyScrollContainer() : super(code: _code);

  static const _code = LintCode(
    name: 'no_eager_list_in_non_lazy_scroll_container',
    problemMessage:
        'PF-2: this for-loop/.map()/List.generate() expansion eagerly '
        'builds every row up front inside a non-lazy ListView/Column/'
        'ExpansionTile instead of a lazy ListView.builder or a windowed '
        'SliverList(delegate: SliverChildBuilderDelegate(...)). Unbounded '
        '(provider-driven) collections must be built lazily so off-screen '
        'rows are never realized — see AUD-tutoring-08 / AUD-scheduler-01.',
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
        return;
      }

      if (typeName == 'ExpansionTile') {
        // Unlike Column, ExpansionTile.children needs no "is this wrapped
        // in a scroll container" gate: ExpansionTile itself is never lazy
        // — the tile's own children are built up front the moment the
        // tile is built, whether or not it sits inside an outer lazy
        // ListView.builder (AUD-scheduler-01).
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

    // Shape 1: `children: [ …, for (final x in y) Widget(x), … ]`,
    // `children: [ …, ...xs.map((x) => Widget(x)), … ]`,
    // `children: [ …, ...List.generate(n, (i) => Widget(i)), … ]`, or one
    // of those reached through an `if (cond) ...[…]` guard / a nested
    // `...[…]` spread-of-list-literal wrapper (AUD-settings-08).
    if (childrenValue is ListLiteral) {
      for (final element in childrenValue.elements) {
        _checkCollectionElement(element, reporter);
      }
      return;
    }

    // Shape 2: `children: xs.map((x) => Widget(x)).toList()` or
    // `children: List.generate(n, (i) => Widget(i))` — the entire children
    // value IS the eager expansion, with no list literal wrapper. This is
    // exactly the AUD-scheduler-01 `ExpansionTile(children: List.generate(
    // tasks.length, ...))` shape.
    if (_isEagerMapExpansion(childrenValue) ||
        _isEagerListGenerate(childrenValue) ||
        _isEagerHelperMethodSpread(childrenValue)) {
      reporter.atNode(childrenValue, _code);
    }
  }

  /// Inspects one `children:` list-literal element, recursing through the
  /// two wrapper shapes that can hide an eager expansion from a flat scan
  /// of top-level elements:
  ///   - `if (cond) ...[ …eager… ]` / `if (cond) …eager… else …eager…`
  ///     (`IfElement` — both branches are checked); and
  ///   - `...[ …eager… ]`, a spread of a NESTED list literal, as opposed to
  ///     a spread of the eager expression itself (`SpreadElement` whose
  ///     expression is itself a `ListLiteral`).
  /// Both shapes appear together in `ScopeSelectionScreen._buildBody`
  /// (AUD-settings-08): `if (!_selectAll) ...[ …, ..._buildLevelValueTiles(
  /// allItems) ]`.
  void _checkCollectionElement(
    CollectionElement element,
    ErrorReporter reporter,
  ) {
    if (element is ForElement) {
      if (!_isBoundedForLoop(element)) {
        reporter.atNode(element, _code);
      }
      return;
    }
    if (element is IfElement) {
      _checkCollectionElement(element.thenElement, reporter);
      final elseElement = element.elseElement;
      if (elseElement != null) {
        _checkCollectionElement(elseElement, reporter);
      }
      return;
    }
    if (element is SpreadElement) {
      final expr = element.expression;
      if (expr is ListLiteral) {
        for (final inner in expr.elements) {
          _checkCollectionElement(inner, reporter);
        }
        return;
      }
      if (_isEagerMapExpansion(expr) ||
          _isEagerListGenerate(expr) ||
          _isEagerHelperMethodSpread(expr)) {
        reporter.atNode(element, _code);
      }
      return;
    }
    // A plain widget-expression element — nothing to check.
  }

  /// True for a bare (unprefixed — `_helper(...)`, not `x.helper(...)`)
  /// call to a method declared in the same enclosing class whose OWN body
  /// returns an eager map/`List.generate` expansion — the AUD-settings-08
  /// `..._buildLevelValueTiles(allItems)` shape, where
  /// `_buildLevelValueTiles` is a same-class helper that does
  /// `return values.map((value) => CheckboxListTile(...)).toList();`. This
  /// one-hop resolution intentionally does not chase further than a single
  /// method call — a helper that itself delegates to another helper is not
  /// covered, matching this rule's existing preference for precision over
  /// exhaustiveness (see the "does NOT flag" list above).
  bool _isEagerHelperMethodSpread(Expression expr) {
    if (expr is! MethodInvocation) return false;
    if (expr.target != null) return false;
    final methodName = expr.methodName.name;
    // 'map'/'toList'/'generate' are handled by the dedicated checks above;
    // treating them here too would just be a slower, redundant path.
    if (methodName == 'map' || methodName == 'toList') return false;

    final classDecl = expr.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return false;
    for (final member in classDecl.members) {
      if (member is MethodDeclaration && member.name.lexeme == methodName) {
        return _bodyReturnsEagerExpansion(member.body);
      }
    }
    return false;
  }

  /// True when [body]'s (single, final) return expression is itself an
  /// eager map/`List.generate` expansion.
  bool _bodyReturnsEagerExpansion(FunctionBody body) {
    if (body is ExpressionFunctionBody) {
      return _isEagerMapExpansion(body.expression) ||
          _isEagerListGenerate(body.expression);
    }
    if (body is BlockFunctionBody) {
      for (final stmt in body.block.statements.reversed) {
        if (stmt is ReturnStatement) {
          final returned = stmt.expression;
          if (returned == null) return false;
          return _isEagerMapExpansion(returned) ||
              _isEagerListGenerate(returned);
        }
      }
    }
    return false;
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
    return _isBoundedLengthExpression(condition.rightOperand);
  }

  /// True for a literal int, or an `EXPR.length` read where `EXPR` is a
  /// provably-bounded source (see [_isBoundedSource]). Covers both a
  /// compound target — `SomeEnum.values.length`, parsed as `PropertyAccess`
  /// — and a bare single-identifier target — `someList.length`, parsed as
  /// `PrefixedIdentifier` — since the analyzer disambiguates
  /// `identifier.identifier` chains differently depending on whether the
  /// left side is itself a simple identifier or a compound expression.
  bool _isBoundedLengthExpression(Expression expr) {
    if (expr is IntegerLiteral) return true;
    if (expr is PropertyAccess && expr.propertyName.name == 'length') {
      return _isBoundedSource(expr.target ?? expr);
    }
    if (expr is PrefixedIdentifier && expr.identifier.name == 'length') {
      return _isBoundedSource(expr.prefix);
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

  /// True for `List.generate(count, generator)` whose `count` is NOT a
  /// provably-bounded length expression (see [_isBoundedLengthExpression]) —
  /// the AUD-scheduler-01 `List.generate(tasks.length, (i) => ...)` shape.
  bool _isEagerListGenerate(Expression expr) {
    if (expr is! InstanceCreationExpression) return false;
    if (expr.constructorName.type.name.lexeme != 'List') return false;
    if (expr.constructorName.name?.name != 'generate') return false;

    final args = expr.argumentList.arguments;
    if (args.isEmpty) return false;
    return !_isBoundedLengthExpression(args.first);
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
          current.constructorName.type.name.lexeme == 'SingleChildScrollView') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
