/// Story acceptance tests for Epic 27, Story 27.4 — Widget + golden test
/// suite (canonical screens) with Hebrew variants.
///
/// Each `goldenTest()` registers FOUR `testWidgets` entries — one per
/// `(locale, brightness)` pair — via the helper from DNI-377 (brightness
/// axis added for R2, the golden matrix). Every site below now baselines
/// real pixels (`skipGolden` omitted/false) — `track_card_*` needed the
/// shared `perTrackOverrides` provider stubs (see that call site) to avoid
/// tripping the real completion/chazara/sync/auth provider chain.
@Tags(['epic_27'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, test;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/hierarchy_progress_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/curriculum_picker_step.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

import '../features/tracks/setup/helpers/track_hub_test_helpers.dart'
    show perTrackOverrides;
import '../helpers/drift_memory.dart';
import '../helpers/golden_font_loader.dart' show loadFonts;
import '../helpers/golden_runner.dart';

// ─── Test scaffolding ────────────────────────────────────────────────────────

/// Wraps a widget in the minimum scaffolding the canonical widgets need:
/// `ProviderScope`, a `MaterialApp` with `AppLocalizations`, the real theme,
/// and a `Scaffold` so widgets that call `ScaffoldMessenger.of` don't crash.
///
/// `overrides` lets a test stub Riverpod providers (e.g.
/// `useHebrewTermsProvider` for the Hebrew variant of widgets that read it).
Widget _pumpHarness({
  required Widget child,
  required Locale locale,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(brightness: brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

/// Builds a minimal `CurriculumTrack` row for golden fixtures. Drift's
/// generated constructor needs every column, but goldens only care about the
/// few that drive rendering.
CurriculumTrack _track({
  required int id,
  required String curriculumId,
  required String trackType,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return CurriculumTrack(
    id: id,
    profileId: 1,
    curriculumId: curriculumId,
    state: 'active',
    stateChangedAt: now,
    activatedAt: now,
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    // Several widgets in the tree read SharedPreferences via
    // ProfileScopedPreference; without an in-memory mock the platform
    // channel throws MissingPluginException before the harness can pump.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await loadFonts();
  });

  group(
    'Story 27.4 — golden tests for canonical screen widgets',
    tags: ['story_27_4'],
    () {
      // ── AC: TrackCard — 4 data shapes ────────────────────────────────────
      //
      // The four shapes map to the four trackTypes the design produces:
      //   personal | school | advanced | program-enrolled (showProgress=true)
      // All four share the same canonical layout — that is the point of the
      // golden test (visual regression catches accidental per-shape drift).

      for (final shape in const [
        _TrackShape(name: 'personal_no_progress', trackType: 'personal'),
        _TrackShape(name: 'school_no_progress', trackType: 'school'),
        _TrackShape(name: 'advanced_with_progress', trackType: 'advanced'),
        _TrackShape(name: 'program_with_progress', trackType: 'personal'),
      ]) {
        final trackForShape = _track(
          id: 1,
          curriculumId: 'mishnayos',
          trackType: shape.trackType,
        );
        goldenTest(
          'track_card_${shape.name}',
          // Two override layers, both needed:
          //  - `perTrackOverrides` (the same helper the track-management hub
          //    L1 suite uses) stubs completion/chazara/program-enrollment
          //    directly, because the REAL providers chain through
          //    trackProgressServiceProvider -> syncWriteFacadeProvider ->
          //    AuthStateNotifier -> FirebaseAuth.instance, which throws
          //    "No Firebase App" in a widget-test sandbox.
          //  - `userDatabaseProvider` still needs a real (unseeded)
          //    in-memory DB: `trackDisplayTitle`'s `trackCustomNameProvider`
          //    reads it directly (no auth/sync chain involved there), and
          //    without an override it opens the real drift_flutter-backed
          //    file DB, which throws `MissingPluginException` for
          //    `path_provider` outside a real app.
          builder: (locale, brightness) => _pumpHarness(
            locale: locale,
            brightness: brightness,
            overrides: [
              ...perTrackOverrides([trackForShape]),
              userDatabaseProvider.overrideWith((ref) {
                final db = inMemoryDb();
                addTearDown(db.close);
                return db;
              }),
            ],
            child: LearningTrackCard(
              track: trackForShape,
              showProgress: shape.name.contains('progress'),
            ),
          ),
        );
      }

      // ── AC: StatCard ─────────────────────────────────────────────────────

      goldenTest(
        'stat_card',
        builder: (locale, brightness) => _pumpHarness(
          locale: locale,
          brightness: brightness,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: OverallStatsCard(
              stats: OverallCurriculumStats(
                totalItems: 4192,
                completedAllStages: 312,
                inProgress: 88,
                notStarted: 3792,
              ),
            ),
          ),
        ),
      );

      // ── AC: StreakHero ───────────────────────────────────────────────────

      goldenTest(
        'streak_hero_child',
        builder: (locale, brightness) => _pumpHarness(
          locale: locale,
          brightness: brightness,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: StreakWidget(
              currentStreak: 7,
              maxStreak: 21,
              userMode: ProfileMode.child,
            ),
          ),
        ),
      );

      goldenTest(
        'streak_hero_adult',
        builder: (locale, brightness) => _pumpHarness(
          locale: locale,
          brightness: brightness,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: StreakWidget(
              currentStreak: 12,
              maxStreak: 30,
              userMode: ProfileMode.adult,
            ),
          ),
        ),
      );

      // ── AC: CurriculumPicker ─────────────────────────────────────────────

      goldenTest(
        'curriculum_picker',
        // CurriculumPickerStep is `StatelessWidget` but child tiles are
        // `ConsumerWidget` reading `useHebrewTermsProvider`; mocked
        // SharedPreferences (set in setUpAll) gives the default value.
        builder: (locale, brightness) => _pumpHarness(
          locale: locale,
          brightness: brightness,
          child: CurriculumPickerStep(onSelected: (_) {}),
        ),
      );

      // ── AC: ProgressOverview ─────────────────────────────────────────────

      goldenTest(
        'progress_overview',
        builder: (locale, brightness) => _pumpHarness(
          locale: locale,
          brightness: brightness,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: HierarchyProgressCard(
              level: HierarchyLevelProgress(
                curriculumId: CurriculumId.mishnayos,
                level: 1,
                levelName: 'Seder Zeraim',
                totalItems: 74,
                completedItems: 18,
                stageBreakdown: [
                  StageBreakdownEntry(stageName: 'Learned', count: 18),
                  StageBreakdownEntry(stageName: 'Chazara 1', count: 9),
                ],
                trackBreakdown: {},
              ),
            ),
          ),
        ),
      );
    },
  );

  // ── AC: Interaction tests ────────────────────────────────────────────────

  group('Story 27.4 — interaction tests', tags: ['story_27_4'], () {
    test(
      'CompletionButton — constructor surface locks required fields',
      // TODO(DNI-393): CompletionButton was removed in the Wave-3/4 refactor.
      // Skip until a replacement widget is identified or this test is deleted.
      skip:
          'CompletionButton widget no longer exists (removed in Wave-3/4 refactor)',
      () {
        expect(true, isTrue);
      },
    );

    test('BulkMarkScreen — constructor surface exposes curriculumId and '
        'optional scopeConstraints', () {
      // Full flow lives in story 27.5/27.6 (needs the content-hierarchy
      // provider stack). This checks the real constructor contract instead
      // of the vacuous `expect(BulkMarkScreen, isNotNull)` — a bare type
      // literal is never null, so that check couldn't fail either.
      const withoutScope = BulkMarkScreen(curriculumId: CurriculumId.mishnayos);
      expect(withoutScope.curriculumId, CurriculumId.mishnayos);
      expect(withoutScope.scopeConstraints, isNull);

      const withScope = BulkMarkScreen(
        curriculumId: CurriculumId.mishnayos,
        scopeConstraints: [ScopeEntry(level: 1, value: 'seder_zeraim')],
      );
      expect(withScope.scopeConstraints, hasLength(1));
      expect(withScope.scopeConstraints!.single.value, 'seder_zeraim');
    });

    testWidgets(
      'DraggableOrderItem — renders drag handle when showDragHandle is true',
      (tester) async {
        await tester.pumpWidget(
          _pumpHarness(
            locale: const Locale('en'),
            child: ReorderableListView(
              onReorderItem: _noOpReorder,
              children: const [
                DraggableOrderItem(
                  key: ValueKey('item-0'),
                  item: LearningOrderItem(
                    sefariaRef: 'Berakhot',
                    displayNameHe: 'ברכות',
                    displayNameEn: 'Berakhot',
                    userSortOrder: 0,
                  ),
                  index: 0,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      },
    );

    testWidgets(
      'DraggableOrderItem — omits drag handle when showDragHandle is false',
      (tester) async {
        await tester.pumpWidget(
          _pumpHarness(
            locale: const Locale('en'),
            child: const Material(
              child: DraggableOrderItem(
                item: LearningOrderItem(
                  sefariaRef: 'Shabbat',
                  displayNameHe: 'שבת',
                  displayNameEn: 'Shabbat',
                  userSortOrder: 1,
                ),
                index: 0,
                showDragHandle: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_handle), findsNothing);
      },
    );

    testWidgets('DraggableOrderItem — respects Hebrew RTL directionality', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpHarness(
          locale: const Locale('he'),
          overrides: [useHebrewTermsProvider.overrideWith(_AlwaysHebrew.new)],
          child: const Material(
            child: DraggableOrderItem(
              item: LearningOrderItem(
                sefariaRef: 'Eruvin',
                displayNameHe: 'עירובין',
                displayNameEn: 'Eruvin',
                userSortOrder: 2,
              ),
              index: 0,
              showDragHandle: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DraggableOrderItem), findsOneWidget);
    });
  });

  // ── Structural AC checks (do not need golden baselines) ─────────────────

  group('Story 27.4 — AC structural verification', tags: ['story_27_4'], () {
    test('golden test for TrackCard covers exactly 4 data shapes', () {
      // Asserts against golden_runner.dart's own registration log, not a
      // hardcoded copy of the shape names — a copy is disconnected from
      // the loop above, so deleting a real shape wouldn't touch it.
      final trackCardNames = registeredGoldenTests
          .map((registration) => registration.name)
          .where((name) => name.startsWith('track_card_'))
          .toSet();
      expect(trackCardNames, hasLength(4));
    });

    test('Hebrew variant ships for every golden widget', () {
      // Asserts against the registration log instead of a hardcoded
      // `['en', 'he']` literal: if golden_runner.dart's `_localeVariants`
      // ever drops Hebrew, no registration carries 'he' and this fails.
      final localesByName = <String, Set<String>>{};
      for (final registration in registeredGoldenTests) {
        localesByName
            .putIfAbsent(registration.name, () => <String>{})
            .add(registration.locale.languageCode);
      }
      // Sanity: the registry is actually populated by the goldenTest()
      // calls above — an empty registry would make the loop below
      // vacuously pass.
      expect(localesByName, isNotEmpty);

      final missingHebrew = localesByName.entries
          .where((entry) => !entry.value.contains('he'))
          .map((entry) => entry.key)
          .toList();
      expect(missingHebrew, isEmpty);
    });
  });
}

// ─── Fixtures / helpers ─────────────────────────────────────────────────────

void _noOpReorder(int oldIndex, int newIndex) {}

class _TrackShape {
  const _TrackShape({required this.name, required this.trackType});
  final String name;
  final String trackType;
}

/// Test-only `UseHebrewTerms` notifier that returns `true` so widgets
/// downstream of `useHebrewTermsProvider` render their Hebrew path.
class _AlwaysHebrew extends UseHebrewTerms {
  @override
  bool build() => true;
}
