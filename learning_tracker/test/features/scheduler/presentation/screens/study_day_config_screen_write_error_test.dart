// ignore_for_file: deprecated_member_use
// Test-only: TestWidgetsFlutterBinding.instance.window.*TestValue is the only
// binding-level viewport-sizing API available in setUp (no tester there). It
// is functional and test-scoped, not production tech debt.
/// Regression test for AUD-scheduler-17.
///
/// `StudyDayConfigScreen._toggleDay` ran its DB write
/// (`db.studyDayConfigDao.upsertDayConfig`) with no surrounding try/catch —
/// a thrown exception (constraint violation, disk error) had no local
/// `AppLogger` call, and `ref.invalidate(allDailyTasksProvider)` had no
/// `context.mounted` guard even though the SnackBar three lines later in the
/// same method already checks `context.mounted` before touching the
/// disposed-widget-unsafe `ScaffoldMessenger`.
///
/// This test forces a real DB write failure (the `study_day_configs` table
/// is dropped out from under the DAO, so `upsertDayConfig`'s INSERT throws a
/// genuine `SqliteException` — the same failure class the finding names)
/// and asserts:
///   1. The failure is logged via `AppLogger` (EH-3) — not silently
///      swallowed, not left for the global zone handler to mislabel as
///      fatal.
///   2. The screen does not crash / leave an unhandled exception behind.
@Tags(['scheduler', 'l1'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/pump_app.dart';

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _buildScreen({required UserDatabase db}) {
  return pumpApp(
    child: const StudyDayConfigScreen(curriculumId: CurriculumId.mishnayos),
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
      syncWriteFacadeProvider.overrideWithValue(null),
      allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
    ],
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Fresh Talker per test so `history` only reflects this test's logging.
    AppLogger.init();
    TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue =
        const Size(1080, 2340);
    TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 3.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
    TestWidgetsFlutterBinding.instance.window.clearDevicePixelRatioTestValue();
  });

  group('AUD-scheduler-17: _toggleDay DB-write failure handling', () {
    testWidgets(
      'a write failure is logged via AppLogger instead of vanishing silently',
      (tester) async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        final trackId = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'mishnayos',
        );
        // Two stages -> chazara enabled -> day-toggle tiles render (mirrors
        // the "chazara-enabled track" setup in
        // study_day_config_screen_l1_test.dart).
        for (var i = 1; i <= 2; i++) {
          await db.stageDao.insertStageDefinition(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              trackId: trackId,
              stageOrder: i,
              stageName: 'Stage $i',
              schedule: const Value('{"type":"delay","delay_days":0}'),
            ),
          );
        }

        await tester.pumpWidget(_buildScreen(db: db));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Drop the table out from under the DAO so the next upsert throws a
        // genuine SqliteException — a realistic instance of the "constraint
        // violation, disk error" class the finding names, not a fabricated
        // stand-in for behavior.
        await db.customStatement('DROP TABLE study_day_configs');

        await tester.tap(find.text('Sun'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any((m) => m.contains('study_day_toggle_write_failed')),
          isTrue,
          reason:
              'AUD-scheduler-17: a thrown upsertDayConfig exception must be '
              'logged via AppLogger (EH-3), not silently swallowed. '
              'Talker history: $history',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
