/// Regression tests for two Lifetime Marking picker bugs that both stem from
/// the screen computing the WRONG hierarchy level for "select all / deselect
/// all in this list".
///
/// Root cause (both bugs): `_effectiveLevel` derived the level from
/// `_currentDisplayItems.length` — a folder SIZE — instead of the real
/// navigation depth. As soon as a drilled-in folder showed more than 4 rows
/// (the common case — most masechtas have dozens of dafim) the bogus level
/// fell past the 4-level cap, so `levelValueAt` returned null for every row.
/// Consequences:
///
///   * IL-LEVEL: "Select all in this list" added nothing (and, for folders of
///     1–4 rows, wrote duplicate ledger entries for the SHARED ancestor value
///     rather than one entry per visible row).
///
///   * IL-TOGGLE: with no selectable value found, `_allCurrentSelected`
///     vacuously returned `true`, so the toggle showed "Deselect all in this
///     list" even though nothing was selected, and re-tapping was a no-op —
///     including immediately after a "Clear selection".
///
/// The fix tracks the live navigation path length from
/// `HierarchySelectionPanel.onNavigationChanged` and computes
/// `level = pathLength + 1`, then requires at least one selectable item before
/// reporting "all selected".
@Tags(['settings', 'lifetime_marking'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _FakeActiveProfileId extends ActiveProfileId {
  @override
  String build() => _profileId;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';

/// Bavli-shaped content: level1=Seder, level2=Masechta, level3=Daf,
/// level4=Amud, with explicit non-leaf rows at every intermediate depth so the
/// hierarchy is drillable (mirrors `assets/content/hierarchy/bavli.json`).
///
/// [dafim] controls how many dafim each masechta has — use >4 to exercise the
/// folder-larger-than-the-level-cap path that broke select-all.
List<ContentItem> _bavliLikeContent({required List<String> dafim}) {
  final items = <ContentItem>[];
  var sort = 0;
  ContentItem mk({
    required String l1,
    String? l2,
    String? l3,
    String? l4,
    required bool leaf,
  }) {
    final ref = [l1, l2, l3].whereType<String>().join(' ') + (l4 ?? '');
    return ContentItem(
      curriculumId: 'bavli',
      level1: l1,
      level2: l2,
      level3: l3,
      level4: l4,
      displayNameHe: '',
      displayNameEn: ref,
      sefariaRef: leaf ? '$l2 $l3$l4' : ref,
      sortOrder: sort++,
      isLeaf: leaf,
    );
  }

  items.add(mk(l1: 'Seder Zeraim', leaf: false));
  for (final masechta in ['Berakhot', 'Peah']) {
    items.add(mk(l1: 'Seder Zeraim', l2: masechta, leaf: false));
    for (final daf in dafim) {
      items.add(mk(l1: 'Seder Zeraim', l2: masechta, l3: daf, leaf: false));
      for (final amud in ['a', 'b']) {
        items.add(
          mk(l1: 'Seder Zeraim', l2: masechta, l3: daf, l4: amud, leaf: true),
        );
      }
    }
  }
  return items;
}

Widget _buildScreen(List<ContentItem> content) {
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId()),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      curriculumLedgerProvider.overrideWith(
        (ref, id) async => const <LearningLedgerData>[],
      ),
      curriculumContentProvider.overrideWith((ref, curriculumId) async {
        return content;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LifetimeCurriculumMarkingScreen(
        curriculumId: CurriculumId.bavli.storageKey,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  testWidgets(
    'IL-TOGGLE: in a drilled-in folder of >4 rows, Select all selects every '
    'row and Clear selection flips the toggle back to "Select all in this list"',
    (tester) async {
      // Six dafim => the daf folder shows 6 rows, exceeding the 4-level cap
      // that the old folder-size-as-level logic tripped over.
      await tester.pumpWidget(
        _buildScreen(
          _bavliLikeContent(dafim: const ['2', '3', '4', '5', '6', '7']),
        ),
      );
      await _settle(tester);

      // Drill: Seder Zeraim -> Berakhot, landing on the daf list.
      await tester.tap(find.byIcon(Icons.navigate_next_rounded).first);
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.navigate_next_rounded).first);
      await _settle(tester);

      // Sanity: we are on the daf list (six dafim visible) and nothing is
      // selected yet, so the toggle reads "Select all".
      expect(find.text('Daf 2'), findsOneWidget);
      expect(find.text('Selected: 0'), findsOneWidget);
      expect(find.text('Select all in this list'), findsOneWidget);

      // Select all — must select all six dafim (pre-fix this selected zero).
      await tester.tap(find.text('Select all in this list'));
      await _settle(tester);
      expect(
        find.text('Selected: 6'),
        findsOneWidget,
        reason:
            'Select all must add one scope entry per visible daf (6), not zero '
            'and not a duplicated ancestor entry',
      );
      expect(
        find.text('Deselect all in this list'),
        findsOneWidget,
        reason: 'With every visible row selected the toggle must show Deselect',
      );

      // Clear selection — nothing remains selected.
      await tester.tap(find.text('Clear selection'));
      await _settle(tester);
      expect(find.text('Selected: 0'), findsOneWidget);
      expect(
        find.text('Select all in this list'),
        findsOneWidget,
        reason:
            'After Clear selection (Selected: 0) the toggle must flip back to '
            '"Select all in this list" — it must follow the real selection '
            'count, not vacuously report everything selected',
      );
      expect(find.text('Deselect all in this list'), findsNothing);
    },
  );

  testWidgets('IL-LEVEL: a 1–4 row folder selects exactly the visible rows (no '
      'duplicated ancestor entries)', (tester) async {
    // Two dafim => exercises the small-folder path that previously wrote
    // duplicate masechta-level entries instead of two daf-level entries.
    await tester.pumpWidget(
      _buildScreen(_bavliLikeContent(dafim: const ['2', '3'])),
    );
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.navigate_next_rounded).first);
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.navigate_next_rounded).first);
    await _settle(tester);

    expect(find.text('Daf 2'), findsOneWidget);
    await tester.tap(find.text('Select all in this list'));
    await _settle(tester);

    // Two visible dafim => Selected: 2 (distinct daf rows, not the masechta).
    expect(
      find.text('Selected: 2'),
      findsOneWidget,
      reason:
          'Select all on a two-daf folder must select the two dafim, not the '
          'shared masechta value twice',
    );

    // Deselecting clears just this level back to zero.
    await tester.tap(find.text('Deselect all in this list'));
    await _settle(tester);
    expect(find.text('Selected: 0'), findsOneWidget);
    expect(find.text('Select all in this list'), findsOneWidget);
  });
}
