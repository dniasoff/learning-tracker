/// Regression test for TS-2:
/// SelfPacedGoalStep must accept a [scopeSelections] parameter and drive its
/// item-count math from the selected scope, not the full-curriculum total.
///
/// Before the fix: the step ignores the in-wizard scope selections and uses
/// [scopedItemCountProvider] which reads from the DB (where the scope isn't
/// saved yet during the wizard), returning the full-curriculum count.
///
/// After the fix: the step accepts [scopeSelections] and passes it to a
/// scoped item count calculation.
///
/// AUD-t-tracks-05: the original version of this file only constructed the
/// widget and asserted the constructor stored the field verbatim — a check
/// that Dart's own field assignment guarantees trivially and would stay
/// green even if `build()` stopped consuming
/// [SelfPacedGoalStep.scopeSelections] entirely. This version pumps the
/// widget with a mixed content fixture (items both inside and outside the
/// selected scope) plus a DIFFERENT full-curriculum DB count, and asserts
/// the rendered deadline card's item count reflects only the selected
/// scope — not the full content list, and not the DB-backed total.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart'
    show ActiveProfileId, activeProfileIdProvider;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/fake_clock.dart';
import '../../../../../helpers/pump_app.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FalseUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  String? build() => '01J6Q2H4A8M7K3P9R5T6V8WXYC';
}

class _AshkenaziVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

// ── Fixture ───────────────────────────────────────────────────────────────────

// The wizard-scoped content: 2 items in "Seder Zeraim" (the selected scope)
// and 3 items in "Seder Moed" (outside the selection) — 5 leaves total.
final _kMixedContent = [
  const ContentItem(
    curriculumId: 'mishnayos',
    sefariaRef: 'Berakhot 1',
    displayNameEn: 'Berakhot 1',
    displayNameHe: 'ברכות א',
    level1: 'Seder Zeraim',
    sortOrder: 0,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    sefariaRef: 'Berakhot 2',
    displayNameEn: 'Berakhot 2',
    displayNameHe: 'ברכות ב',
    level1: 'Seder Zeraim',
    sortOrder: 1,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    sefariaRef: 'Shabbos 1',
    displayNameEn: 'Shabbos 1',
    displayNameHe: 'שבת א',
    level1: 'Seder Moed',
    sortOrder: 2,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    sefariaRef: 'Shabbos 2',
    displayNameEn: 'Shabbos 2',
    displayNameHe: 'שבת ב',
    level1: 'Seder Moed',
    sortOrder: 3,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    sefariaRef: 'Shabbos 3',
    displayNameEn: 'Shabbos 3',
    displayNameHe: 'שבת ג',
    level1: 'Seder Moed',
    sortOrder: 4,
    isLeaf: true,
  ),
];

const _kScopedCountExpected = 2; // items in "Seder Zeraim" only
const _kFullContentCount = 5; // full mixed fixture (all leaves)
const _kDbFullCurriculumCount = 99; // DB-backed full-curriculum count —
// deliberately different from both of the above so a test that fell back to
// EITHER the unfiltered content length OR the DB count would be caught.

final _fixedNow = DateTime.utc(2026, 6, 11);

List<Override> _overrides() {
  final contentRepo = _MockContentRepository();

  when(
    () => contentRepo.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);

  return [
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
    scopedCurriculumContentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => _kMixedContent),
    // DB-backed full-curriculum count — must NOT be what the widget renders
    // when scopeSelections is provided.
    scopedItemCountProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => _kDbFullCurriculumCount),
    currentTransliterationVariantProvider.overrideWith(
      () => _AshkenaziVariant(),
    ),
  ];
}

Widget _buildStep({List<ScopeEntry>? scopeSelections}) {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;

  return pumpApp(
    retry: (_, __) => null,
    overrides: _overrides(),
    child: Scaffold(
      body: SelfPacedGoalStep(
        curriculumId: CurriculumId.mishnayos,
        studyDays: const {
          1: 'study',
          2: 'study',
          3: 'study',
          4: 'study',
          5: 'study',
        },
        onComplete: (_) {},
        scopeSelections: scopeSelections,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  setUp(() {
    installFakeClock(_fixedNow);
  });

  group('TS-2 — SelfPacedGoalStep.scopeSelections parameter', () {
    testWidgets(
      'pumping with scopeSelections renders an item count scoped to the '
      'selection, not the full content list and not the DB full-curriculum '
      'count',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const selections = [ScopeEntry(level: 1, value: 'Seder Zeraim')];

        await tester.pumpWidget(_buildStep(scopeSelections: selections));
        await _settle(tester);

        // The deadline card is rendered (blurred, since default mode is
        // pace) but its data is still built from real production logic —
        // reading `totalScopeItems` here exercises the exact
        // _countItemsInWizardScope() computation this finding guards.
        final deadlineCardWidget = tester.widget<DeadlineGoalCard>(
          find.byType(DeadlineGoalCard),
        );

        expect(
          deadlineCardWidget.totalScopeItems,
          equals(_kScopedCountExpected),
          reason:
              'TS-2: with scopeSelections provided, the rendered item count '
              'must reflect only the selected scope ($_kScopedCountExpected '
              'items in Seder Zeraim) — not the full mixed-content length '
              '($_kFullContentCount) and not the DB full-curriculum count '
              '($_kDbFullCurriculumCount). A regression that stops reading '
              'widget.scopeSelections in build() would surface one of those '
              'wrong totals here.',
        );
      },
    );

    test('SelfPacedGoalStep defaults scopeSelections to null', () {
      final step = SelfPacedGoalStep(
        curriculumId: CurriculumId.mishnayos,
        studyDays: const {},
        onComplete: (_) {},
      );

      expect(step.scopeSelections, isNull);
    });
  });
}
