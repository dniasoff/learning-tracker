// Overflow guard for [StudyDayConfigScreen] (P2 screen-body fix).
//
// The chazara-enabled body (intro copy + legend + 7 day-toggle tiles + summary)
// previously sat in a non-scrolling Column inside a SafeArea, so on a short
// viewport — or with large accessibility text — it overflowed *vertically*. The
// fix wraps that body in a SingleChildScrollView (with a MainAxisSize.min
// Column). This guard pumps the REAL screen, seeded with a chazara-enabled
// track, and asserts no RenderFlex overflow as the *vertical* axis is stressed:
// the tightest viewport heights at every text scale, including the contractual
// small×2.0 corner. That is exactly the axis the SingleChildScrollView fix
// guards.
//
// Why the viewport WIDTHS here are wide (not the harness's 280/320 corners):
// the screen's two-item legend Row (a "Study" dot+label beside a "Review only"
// dot+label) is a *single-line, horizontal-axis* element that genuinely cannot
// fit two accessibility-scaled (1.3×/2.0×) labels on a 280–412 dip width. That
// horizontal squeeze is an orthogonal concern to the vertical scroll-wrapping
// fix under test — it is not what the SingleChildScrollView addresses, and the
// lib screen is intentionally left unchanged here. We therefore pin the WIDTH
// wide enough for the legend at every scale and stress the HEIGHT + textScale,
// which is the dimension the fix actually protects. Flutter overflow is
// monotonic in (height, textScale), so the tightest heights at the largest
// scale prove the whole vertical continuum.

@Tags(['overflow'])
library;

import 'dart:ui' show Size;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/overflow_harness.dart';

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _UseHebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Narrow + short viewports that stress BOTH axes: the legend is now a Wrap
/// (chips flow to a second line) and the body is scroll-wrapped, so real
/// small-phone widths (320 = iPhone-SE-class, 280 = folded foldable) at large
/// text must not overflow. `s.first` (320×568) is the tightest viewport.
const _verticalStressSizes = <Size>[
  Size(320, 568),
  Size(280, 653),
  Size(412, 915),
];

void main() {
  late UserDatabase db;

  setUpAll(() {
    // Pin fonts to the bundled asset so GoogleFonts does not schedule a
    // runtime-fetch Timer that would outlive the widget tree under
    // pumpAndSettle.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = inMemoryDb();
    await seedProfile(db);
    final trackId = await seedTrack(
      db,
      profileId: 1,
      curriculumId: CurriculumId.mishnayos.storageKey,
    );
    // Two stages → chazara enabled → the full toggle-grid body renders (the
    // surface that overflowed before the SingleChildScrollView fix).
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
  });

  testWidgets(
    'StudyDayConfigScreen (chazara-enabled, full toggle grid) does not '
    'overflow vertically across the height/text-scale matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const StudyDayConfigScreen(curriculumId: CurriculumId.mishnayos),
        sizes: _verticalStressSizes,
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          useHebrewTermsProvider.overrideWith(_UseHebrewTermsOff.new),
          syncWriteFacadeProvider.overrideWithValue(null),
          allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
          activeTutorPermissionsProvider.overrideWithValue(null),
          // Override the Drift-backed config stream with a plain finite stream
          // (empty == all 7 days default to study). A real `watch()` query
          // would leave a Drift stream-cleanup Timer pending when the harness
          // tears the tree down between matrix cases, tripping the binding's
          // "Timer still pending" invariant. The empty list renders the same
          // full toggle grid the screen draws against an empty DB.
          studyDayConfigsProvider(CurriculumId.mishnayos).overrideWith(
            (ref) => Stream<List<StudyDayConfigEntry>>.value(const []),
          ),
        ],
      );
    },
  );
}
