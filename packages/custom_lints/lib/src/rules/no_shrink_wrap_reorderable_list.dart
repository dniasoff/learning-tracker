// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// AUD-tracks-05 (PF-2) Rule-0 checker.
///
/// Flags the plain (non-`.builder`) `ReorderableListView(...)` constructor
/// combined with `shrinkWrap: true`, anywhere under `lib/features/**`.
///
/// `shrinkWrap: true` forces the underlying sliver to compute its own total
/// scroll extent before an enclosing unbounded-height ancestor (typically a
/// `SingleChildScrollView`) can lay out — which means EVERY row is realized
/// (built) up front regardless of viewport, no matter how many items the
/// list holds. Because the plain `ReorderableListView(children: [...])`
/// constructor also expands its full item list eagerly into a `children:`
/// list literal before the widget is even built, the two combine into the
/// worst case: an unbounded, provider-driven collection (e.g. one row per
/// Siman/Masechta/curriculum node) built entirely in a single frame on an
/// ordinary, one-tap user action.
///
/// Simply switching to `ReorderableListView.builder` does NOT fix this
/// defect on its own: `shrinkWrap: true` alone already forces eager
/// realization of a `.builder` list too. The fix must drop
/// `shrinkWrap: true` (and the enclosing unbounded-height ancestor) —
/// typically by hosting the section as a `SliverReorderableList` inside a
/// real `CustomScrollView`/`Scrollable`, which is naturally lazy and never
/// needs `shrinkWrap` in the first place.
///
/// Written for `TrackLearningOrderScreen`'s masechtos reorder section — a
/// Mishna Berurah track has 697 Simanim, all realized in one frame by a
/// single tap of "Reorder Learning Order" pre-fix. See
/// `docs/audits/standards-audit-2026-07-03/delivery/findings/
/// AUD-tracks-05.json` (acceptance_criteria[0], "Rule-0: PF-2 checker").
///
/// See `packages/custom_lints/README.md` for rule rationale and remediation.
class NoShrinkWrapReorderableList extends DartLintRule {
  const NoShrinkWrapReorderableList() : super(code: _code);

  static const _code = LintCode(
    name: 'no_shrink_wrap_reorderable_list',
    problemMessage:
        'PF-2: the plain ReorderableListView(...) constructor combined with '
        'shrinkWrap: true forces every row to be realized (built) up front '
        'regardless of viewport, no matter how many items the list holds — '
        'shrinkWrap forces the sliver to compute its total scroll extent '
        'before an enclosing unbounded-height ancestor can lay out. Drop '
        'shrinkWrap and host the section as a SliverReorderableList inside '
        'a real CustomScrollView instead — see AUD-tracks-05.',
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
      if (typeName != 'ReorderableListView') return;

      // Only the plain/default constructor is affected by this exact
      // finding's shape; `.builder` is a distinct named constructor. (Per
      // the doc comment above, shrinkWrap alone still defeats `.builder`
      // too, but that combination is outside this rule's precise,
      // evidence-scoped pattern — see AUD-tracks-05's exact cited site.)
      if (node.constructorName.name != null) return;

      if (_hasShrinkWrapTrue(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// True if the constructor call has a `shrinkWrap: true` named argument.
  bool _hasShrinkWrapTrue(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'shrinkWrap') continue;
      final value = arg.expression;
      if (value is BooleanLiteral && value.value) return true;
    }
    return false;
  }
}
