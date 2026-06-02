// ignore_for_file: deprecated_member_use
// Test-only: TestWidgetsFlutterBinding.instance.window.*TestValue is the only
// binding-level viewport-sizing API available in setUp (no tester there). It is
// functional and test-scoped, not production tech debt.
/// L1 widget tests for [StudyDayConfigScreen].
///
/// Covers:
///   - Weekday toggle tiles render for chazara-enabled and chazara-disabled
///     curricula.
///   - Toggling a day persists to the database (upsertDayConfig call verified
///     by querying DB state post-tap).
///   - At-least-one-day invariant: the screen currently has NO enforcement;
///     the test documents this absence.
///   - Hardcoded-English string audit (day labels, body copy, badge labels).
///   - RTL / Hebrew smoke: screen pumps without errors under `he` locale.
///   - Tutor read-only gating: when `canEditStudyDays == false` tiles are
///     non-tappable.
///   - Error state renders a retry affordance.
@Tags(['scheduler', 'l1'])
library;

import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride(this._value);
  final bool _value;
  @override
  bool build() => _value;
}

/// Builds the test harness. The [configs] stream is used to override
/// [studyDayConfigsProvider]; the DB is passed for full persistence tests.
///
/// When [configs] is `null`, the screen's real provider chain is used
/// (requires [db] to be wired via [userDatabaseProvider]).
Widget _buildScreen({
  required CurriculumId curriculumId,
  required UserDatabase db,
  Stream<List<StudyDayConfigEntry>>? configs,
  TutorPermissions? tutorPerms,
  Locale locale = const Locale('en'),
}) {
  final overrides = [
    userDatabaseProvider.overrideWithValue(db),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
    useHebrewTermsProvider.overrideWith(
      () => _UseHebrewTermsOverride(locale.languageCode == 'he'),
    ),
    syncWriteFacadeProvider.overrideWithValue(null),
    allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
    activeTutorPermissionsProvider.overrideWithValue(tutorPerms),
    if (configs != null)
      studyDayConfigsProvider(curriculumId).overrideWith((ref) => configs),
  ];

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StudyDayConfigScreen(curriculumId: curriculumId),
    ),
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Renders all 7 weekday toggle tiles (chazara-enabled track) ──────────

  group('StudyDayConfigScreen — chazara-enabled track', () {
    late UserDatabase db;

    setUp(() async {
      // Phone-sized viewport so the 7-tile column fits without overflow.
      TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue =
          const Size(1080, 2340);
      TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 3.0;
      db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
      );
      // Two stages → chazara enabled (countStagesForTrack > 1).
      for (var i = 1; i <= 2; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: i,
            stageName: 'Stage $i',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
      TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
      TestWidgetsFlutterBinding.instance.window
          .clearDevicePixelRatioTestValue();
    });

    testWidgets('renders all 7 day-toggle tiles', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // All 7 short day labels must appear.
      for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
        expect(find.text(label), findsOneWidget, reason: '$label tile missing');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('legend shows Study and Review only labels', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // "Study" appears in legend + every default tile badge.
      expect(find.text('Study'), findsAtLeast(1));
      // "Review only" appears in legend (l10n key).
      expect(find.textContaining('Review'), findsAtLeast(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('summary shows 7 study days per week by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // With no configs, all days default to study.
      expect(find.text('7 study days per week'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('summary reflects seeded review day', (tester) async {
      // Seed Monday (dow=1) as review so only 6 study days.
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: 1,
        dayOfWeek: 1,
        dayType: DayType.review.storageKey,
      );

      await tester.pumpWidget(
        _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('6 study days per week'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── 2. Toggling a day persists via DB ──────────────────────────────────

    testWidgets('tapping a study-day tile calls upsertDayConfig with review', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap the Sunday tile (which defaults to study → should flip to review).
      await tester.tap(find.text('Sun'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify DB was updated: Sunday (dow=7) should now be 'review'.
      // Use a direct table query (not a watch stream) to avoid hanging.
      final sunRow =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(1) &
                    t.curriculumId.equals(CurriculumId.mishnayos.storageKey) &
                    t.dayOfWeek.equals(7),
              ))
              .getSingleOrNull();
      expect(
        sunRow,
        isNotNull,
        reason: 'Row for Sunday should exist after tap',
      );
      expect(
        sunRow!.dayType,
        equals(DayType.review.storageKey),
        reason: 'Sunday should be review after tap',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'tapping a review-day tile calls upsertDayConfig flipping to study',
      (tester) async {
        // Seed Wednesday (dow=3) as review.
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: 1,
          dayOfWeek: 3,
          dayType: DayType.review.storageKey,
        );

        await tester.pumpWidget(
          _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Tap the Wednesday tile → should flip to study.
        await tester.tap(find.text('Wed'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final wedRow =
            await (db.select(db.studyDayConfigs)..where(
                  (t) =>
                      t.profileId.equals(1) &
                      t.curriculumId.equals(CurriculumId.mishnayos.storageKey) &
                      t.dayOfWeek.equals(3),
                ))
                .getSingleOrNull();
        expect(wedRow, isNotNull);
        expect(wedRow!.dayType, equals(DayType.study.storageKey));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // ── 3. No track-type label shown anywhere ─────────────────────────────

    testWidgets('no track-type label (Personal/Standard/Custom) is shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.textContaining('אישי'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── 4. Hardcoded-English strings audit ──────────────────────────────────
    //
    // The following strings are hardcoded in the production source (not i18n).
    // They are documented here as found. This is intentional audit output —
    // see bugsFound in the StructuredOutput report.

    testWidgets('hardcoded body copy "Choose which days" is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Choose which days'),
        findsOneWidget,
        reason: 'Hardcoded English body copy present (not i18n)',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('hardcoded day labels Sun..Sat are present', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Hardcoded English day label "$label" present (not i18n)',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('badge labels use localized Study / Review only keys', (
      tester,
    ) async {
      // Seed one review day so both badge labels are visible.
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: 1,
        dayOfWeek: 7,
        dayType: DayType.review.storageKey,
      );

      await tester.pumpWidget(
        _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Badges now render via the same l10n keys as the legend
      // (schedulerStudyLabel / schedulerReviewOnlyLabel) — no longer the
      // hardcoded 'Study' / 'Review' literals. In en these resolve to
      // 'Study' and 'Review only'.
      expect(find.text('Study'), findsAtLeast(1));
      // The review badge now reads 'Review only' (the localized key), not the
      // old hardcoded bare 'Review'.
      expect(find.text('Review only'), findsAtLeast(1));
      // Regression guard: the previously-hardcoded bare 'Review' badge text
      // must no longer be emitted on its own.
      expect(find.text('Review'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('review badge renders Hebrew when Hebrew Terms is on', (
      tester,
    ) async {
      // Seed one review day so the review badge is visible.
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: 1,
        dayOfWeek: 7,
        dayType: DayType.review.storageKey,
      );

      // he locale drives the AppLocalizations badge strings to Hebrew.
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // schedulerStudyLabel = "לימוד", schedulerReviewOnlyLabel = "חזרה בלבד".
      expect(find.text('לימוד'), findsAtLeast(1));
      expect(find.text('חזרה בלבד'), findsAtLeast(1));
      // The old hardcoded English badges must not appear under he locale.
      expect(find.text('Study'), findsNothing);
      expect(find.text('Review'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── 5. At-least-one-day invariant is NOT enforced ────────────────────────
    //
    // BUG: the screen does not block the user from marking all 7 days as
    // review. This test is skipped because it documents a genuine absent
    // guard (not a currently-asserted invariant in production code).
    testWidgets(
      // ignore: lines_longer_than_80_chars
      'at-least-one-study-day invariant: all days can be toggled to review with no guard',
      (tester) async {
        // Seed all 7 days as review.
        for (final dow in [1, 2, 3, 4, 5, 6, 7]) {
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: 1,
            dayOfWeek: dow,
            dayType: DayType.review.storageKey,
          );
        }

        await tester.pumpWidget(
          _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Summary shows 0 study days — no error/warning is shown.
        expect(find.text('0 study days per week'), findsOneWidget);
        // No snackbar, no error widget shown.
        expect(find.byType(SnackBar), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
      skip: false, // Intentionally not skipped: documents the missing guard
    );

    // ── 6. Tutor read-only gating ────────────────────────────────────────────

    testWidgets('tutor without canEditStudyDays — tiles are non-tappable', (
      tester,
    ) async {
      const readOnlyPerms = TutorPermissions(canEditStudyDays: false);

      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
          tutorPerms: readOnlyPerms,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap a day tile — with canEdit=false onTap is null, so the DB row should
      // not exist after the tap.
      await tester.tap(find.text('Sun'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Use a direct get query to avoid hanging on a watch stream.
      final sunRow =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(1) &
                    t.curriculumId.equals(CurriculumId.mishnayos.storageKey) &
                    t.dayOfWeek.equals(7),
              ))
              .getSingleOrNull();
      // No row should have been written for Sunday.
      expect(
        sunRow,
        isNull,
        reason: 'Read-only tutor must not persist changes',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tutor with canEditStudyDays — tiles remain tappable', (
      tester,
    ) async {
      const editablePerms = TutorPermissions(canEditStudyDays: true);

      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
          tutorPerms: editablePerms,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Sun'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final sunRow2 =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(1) &
                    t.curriculumId.equals(CurriculumId.mishnayos.storageKey) &
                    t.dayOfWeek.equals(7),
              ))
              .getSingleOrNull();
      expect(sunRow2, isNotNull);
      expect(sunRow2!.dayType, equals(DayType.review.storageKey));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── 7. Error state ────────────────────────────────────────────────────────

    testWidgets('error state shows Retry button', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.error(Exception('db error')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── 8. Loading state ─────────────────────────────────────────────────────

    testWidgets('loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      // Never-completing stream to freeze in loading state.
      final controller = StreamController<List<StudyDayConfigEntry>>();

      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: controller.stream,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── 9. Display order: Sunday first ───────────────────────────────────────

    testWidgets('Sunday appears before Monday in display order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final sunPos = tester.getTopLeft(find.text('Sun')).dy;
      final monPos = tester.getTopLeft(find.text('Mon')).dy;
      expect(
        sunPos,
        lessThan(monPos),
        reason: 'Sunday must appear before Monday',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 10. Chazara-disabled track ────────────────────────────────────────────

  group('StudyDayConfigScreen — chazara-disabled track (learn-only)', () {
    late UserDatabase db;

    setUp(() async {
      TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue =
          const Size(1080, 2340);
      TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 3.0;
      db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
      );
      // Only ONE stage → chazara disabled.
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
      TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
      TestWidgetsFlutterBinding.instance.window
          .clearDevicePixelRatioTestValue();
    });

    testWidgets('shows neutral message and no day toggles', (tester) async {
      await tester.pumpWidget(
        _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Chazara-neutral message must be present.
      expect(
        find.textContaining('All days are study days for this track.'),
        findsOneWidget,
      );

      // Day-toggle tiles must NOT be present (no toggles for learn-only track).
      for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
        expect(
          find.text(label),
          findsNothing,
          reason: 'No day toggle for learn-only track: $label',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('neutral message does NOT mention chazara or review', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Per chazara rule: the fallback text must not say "chazara" or "review".
      expect(find.textContaining('chazara'), findsNothing);
      expect(find.textContaining('Chazara'), findsNothing);
      expect(find.textContaining('review'), findsNothing);
      expect(find.textContaining('Review'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('no track type label shown', (tester) async {
      await tester.pumpWidget(
        _buildScreen(curriculumId: CurriculumId.mishnayos, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 11. RTL / Hebrew smoke ────────────────────────────────────────────────

  group('StudyDayConfigScreen — RTL / Hebrew smoke', () {
    late UserDatabase db;

    setUp(() async {
      TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue =
          const Size(1080, 2340);
      TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 3.0;
      db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
      );
      for (var i = 1; i <= 2; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: i,
            stageName: 'Stage $i',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
      TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
      TestWidgetsFlutterBinding.instance.window
          .clearDevicePixelRatioTestValue();
    });

    testWidgets('screen pumps without error under he locale', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curriculumId: CurriculumId.mishnayos,
          db: db,
          configs: Stream.value(const []),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No overflow / error widgets must appear.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
