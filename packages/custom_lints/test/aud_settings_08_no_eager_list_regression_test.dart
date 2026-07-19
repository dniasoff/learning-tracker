// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_eager_list_in_non_lazy_scroll_container.dart';

/// AUD-settings-08 regression test.
///
/// The finding flagged `ScopeSelectionScreen._buildBody`
/// (learning_tracker/lib/features/settings/presentation/screens/
/// scope_selection_screen.dart): a plain `ListView(children: [...])` whose
/// `if (!_selectAll) ...[…]` branch spread `..._buildLevelValueTiles(
/// allItems)` — a same-class helper method that itself did an eager
/// `values.map((value) => CheckboxListTile(...)).toList()` over every
/// distinct raw value at the user-chosen hierarchy level (up to 697 for
/// CurriculumId.mishnaBerurah's 'Siman' level per the finding's own
/// evidence).
///
/// Like `sacred_time_no_color_literal_regression_test.dart`
/// (AUD-sacred_time-09), this test resolves and analyzes the REAL
/// production file on disk via [DartLintRule.testAnalyzeAndRun] — it does
/// not depend on the `dart run custom_lint` plugin-discovery path, which is
/// currently broken (see docs/coding-standards.md, "custom_lint toolchain
/// status"). That makes this a live, non-fabricated regression guard: if a
/// future edit reintroduces an eager per-value widget expansion in this
/// file, this test fails again automatically.
///
/// This test was run BEFORE the AUD-settings-08 source fix (with the rule
/// extension already in place) to capture the violation red — see the
/// commit history for the captured failing output. It is green now that
/// `_buildBody` routes the per-value tiles through a `SliverList(delegate:
/// SliverChildBuilderDelegate(...))` inside a `CustomScrollView` instead of
/// the eager `ListView(children:)` + `.map().toList()` pair.
void main() {
  group('AUD-settings-08 — no_eager_list_in_non_lazy_scroll_container', () {
    const rule = NoEagerListInNonLazyScrollContainer();

    Future<List<String>> violationsIn(
        String relativePathFromThisPackage) async {
      final absolute = File(relativePathFromThisPackage).absolute.path;
      final normalized = File(absolute).resolveSymbolicLinksSync();
      final errors = await rule.testAnalyzeAndRun(File(normalized));
      return errors
          .where(
            (e) =>
                e.errorCode.name ==
                'no_eager_list_in_non_lazy_scroll_container',
          )
          .map((e) => 'offset ${e.offset}: ${e.message}')
          .toList();
    }

    test(
      'scope_selection_screen.dart has zero eager-list-into-non-lazy-'
      'container violations',
      () async {
        final hits = await violationsIn(
          '../../learning_tracker/lib/features/settings/presentation/'
          'screens/scope_selection_screen.dart',
        );
        expect(
          hits,
          isEmpty,
          reason: 'AUD-settings-08: ScopeSelectionScreen must route its '
              'per-value checkbox list through a lazy builder instead of an '
              'eager ListView(children:) + .map().toList(), found: $hits',
        );
      },
    );
  });
}
