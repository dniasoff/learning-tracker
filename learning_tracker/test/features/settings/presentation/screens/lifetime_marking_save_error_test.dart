/// AUD-settings-07 regression: LifetimeCurriculumMarkingScreen._markSelections
/// catch block.
///
/// Root cause: the catch block interpolated the caught exception's
/// `.toString()` straight into `l10n.lifetimeMarkSaveError(e.toString())`,
/// so a Hebrew-speaking parent/child would see a half-English, technical
/// exception string in the save-failure SnackBar instead of a real
/// localized message (EH-5 / ST-4).
///
/// Fix: `lifetimeMarkSaveError` is now a fixed, already-localized fallback
/// (no `{error}` placeholder); the raw exception is logged via AppLogger for
/// diagnostics instead of being shown.
///
/// Test strategy: mirrors scope_lifetime_l1_test.dart's "Save drives the
/// real _markSelections call" test — pump LifetimeCurriculumMarkingScreen
/// with a fake ContentRepository (so "Select all in this list" populates a
/// real selection without depending on the on-disk content database) and
/// the before-tracking recorder's commands seam throwing a distinctive,
/// developer-facing exception (Story 1.11, DNI-473: Save is a
/// `before_tracking` capture through LearningCommands).
/// Tap Select-all then Save to drive the catch branch, then assert the
/// SnackBar shows only the fixed ARB copy — in both English and Hebrew —
/// and never the raw exception text.
@Tags(['settings', 'lifetime_marking', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/before_tracking_recorder.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';

// ── mocks / fakes ────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _NoBookmarks extends Fake implements BookmarkRepository {}

class _FakeActiveProfileId extends ActiveProfileId {
  @override
  String build() => _profileId;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ── minimal synthetic content (mirrors scope_lifetime_l1_test.dart) ─────────

const _kSeder1 = 'Seder Zeraim';
const _kMasechta1 = 'Berakhot';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';

final _kFakeItems = [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    displayNameHe: 'סדר זרעים',
    displayNameEn: _kSeder1,
    sefariaRef: 'Mishnah_Zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    level2: _kMasechta1,
    displayNameHe: 'ברכות',
    displayNameEn: _kMasechta1,
    sefariaRef: 'Mishnah_Berakhot',
    sortOrder: 1,
    isLeaf: false,
  ),
];

_MockContentRepository _makeFakeContentRepo() {
  final repo = _MockContentRepository();
  when(
    () => repo.getContentForCurriculum(any<CurriculumId>()),
  ).thenAnswer((_) async => _kFakeItems);
  when(
    () => repo.getScopedContent(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      scopeLevel: any<int>(named: 'scopeLevel'),
      scopeValues: any<List<String>>(named: 'scopeValues'),
    ),
  ).thenAnswer((_) async => _kFakeItems);
  when(
    () => repo.getHierarchyConfig(any<CurriculumId>()),
  ).thenAnswer((_) async => throw UnimplementedError('not needed'));
  when(
    () => repo.filterByLevel(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      level1: any<String>(named: 'level1'),
      level2: any<String>(named: 'level2'),
      level3: any<String>(named: 'level3'),
      level4: any<String>(named: 'level4'),
    ),
  ).thenAnswer((_) async => _kFakeItems);
  when(
    () => repo.search(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      query: any<String>(named: 'query'),
    ),
  ).thenAnswer((_) async => []);
  when(
    () => repo.getContentByRef(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      sefariaRef: any<String>(named: 'sefariaRef'),
    ),
  ).thenAnswer((_) async => null);
  return repo;
}

// ── harness ───────────────────────────────────────────────────────────────────

Widget _buildScreen({Locale locale = const Locale('en')}) {
  final content = _makeFakeContentRepo();
  return pumpApp(
    locale: locale,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId()),
      contentRepositoryProvider.overrideWithValue(content),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      ...learnerStateOverrides(
        scope: c0Scope(),
        state: LearnerState.empty(DateTime.utc(2026)),
      ),
      beforeTrackingRecorderProvider.overrideWithValue(
        BeforeTrackingRecorder(
          contentRepository: content,
          bookmarkRepository: _NoBookmarks(),
          commands: () async =>
              throw Exception('test-forced capture write failure'),
          events: () async => const [],
        ),
      ),
    ],
    child: const LifetimeCurriculumMarkingScreen(curriculumId: 'mishnayos'),
  );
}

/// Finds the "Select all in this list" toggle by enabled state rather than
/// its (locale-dependent) label: before any selection is made, it is the
/// only enabled [OutlinedButton] in the tree ("Clear selection" stays
/// disabled until `_selections` is non-empty).
final _selectAllButton = find.byWidgetPredicate(
  (w) => w is OutlinedButton && w.onPressed != null,
);

Future<void> _selectAllAndSave(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  await tester.tap(_selectAllButton);
  await tester.pump();

  final saveButton = find.byWidgetPredicate(
    (w) => w is FilledButton && w.onPressed != null,
  );
  expect(
    saveButton,
    findsOneWidget,
    reason:
        '"Select all in this list" must populate a real selection so Save '
        'becomes enabled — otherwise this test cannot reach the real '
        '_markSelections call site',
  );

  await tester.tap(saveButton);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(0); // scopeLevel
    registerFallbackValue(<String>[]); // scopeValues
    registerFallbackValue(''); // query / sefariaRef
  });

  testWidgets(
    'save failure -> SnackBar shows the fixed localized fallback, never the '
    'raw exception (AUD-settings-07, EH-5/ST-4)',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _selectAllAndSave(tester);

      expect(
        find.text("Couldn't save your marks. Please try again."),
        findsOneWidget,
      );
      expect(
        find.textContaining('test-forced capture write failure'),
        findsNothing,
        reason:
            'AUD-settings-07 (EH-5): the caught exception\'s raw message '
            'must never reach the widget tree — only ARB-sourced text may '
            'render.',
      );

      await _teardown(tester);
    },
  );

  testWidgets(
    'save failure under Hebrew locale -> SnackBar shows only ARB-sourced '
    'Hebrew text, never the raw exception (AUD-settings-07)',
    (tester) async {
      await tester.pumpWidget(_buildScreen(locale: const Locale('he')));
      await _selectAllAndSave(tester);

      expect(find.text('שמירת הסימונים נכשלה. נסו שוב.'), findsOneWidget);
      expect(
        find.textContaining('test-forced capture write failure'),
        findsNothing,
      );

      await _teardown(tester);
    },
  );
}
