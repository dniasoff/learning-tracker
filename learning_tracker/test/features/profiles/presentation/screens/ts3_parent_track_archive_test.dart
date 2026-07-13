/// AUD-profiles-01 / TS-3 regression test: "Archive (keep history)" in
/// ParentTrackManagementScreen must set state='archived' and preserve
/// goal/stage/point-config data — it must NOT route through
/// deleteTrackAndData (via CurriculumActivationService.deactivate), which
/// hard-deletes that config and is functionally identical to the
/// "Delete and wipe history" option.
///
/// RED → GREEN cycle (AUD-profiles-01):
///   RED:  the real archive path (CurriculumActivationService.deactivate)
///         hard-deletes goals/stage_definitions/point_config via
///         deleteTrackAndData and sets state='deleted' — TrackState.archived
///         is never written anywhere in production code.
///   GREEN: the real archive path (CurriculumActivationService.archive) sets
///          state='archived' and preserves goal/stage/point-config rows.
///
/// Both tests below drive the REAL production code path — the DB-level test
/// calls [CurriculumActivationService.archive] directly (the exact method
/// the screen calls), and the widget test longPresses a track on the real
/// [ParentTrackManagementScreen] and taps its actual "Archive (keep history)"
/// dialog button. Neither hand-writes the DB update nor hand-rolls a fake
/// dialog (the previous version of this file did both, which is why it
/// never caught the bug — see AUD-profiles-01).
@Tags(['profiles', 'ts3'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Minimal [TrackRepository] backed by the test's in-memory DB — only
/// [initializeDefaultTracks] is needed by [CurriculumActivationService].
class _TrackRepositoryForTest implements TrackRepository {
  _TrackRepositoryForTest(this._db);
  final UserDatabase _db;

  @override
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) =>
      _db.trackDao.initializeDefaultTracks(curriculumId, profileId: profileId);
}

/// Builds a [CurriculumActivationService] wired to [db] without sync — the
/// same construction the production provider performs, minus Firestore.
CurriculumActivationService _buildActivationService(
  UserDatabase db,
  int profileId,
) => CurriculumActivationService(
  database: db,
  pushCurriculumTrack: null,
  trackRepository: _TrackRepositoryForTest(db),
  profileId: profileId,
  syncFacade: null,
);

const _kProfileId = 1;

CurriculumTrack _track({
  int id = 1,
  int profileId = _kProfileId,
  String curriculumId = 'mishnayos',
}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: curriculumId,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

List<Override> _perTrackOverrides(List<CurriculumTrack> tracks) {
  final overrides = <Override>[];
  for (final t in tracks) {
    overrides.add(
      dashboardTrackCompletionPercentageProvider(
        t.id,
      ).overrideWith((ref) async => 0.0),
    );
    overrides.add(
      trackHasChazaraProvider(t.id).overrideWith((ref) async => false),
    );
  }
  overrides.add(
    dashboardHasProgramEnrollmentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => false),
  );
  return overrides;
}

Widget _buildApp({
  required _MockStackRouter router,
  required List<CurriculumTrack> tracks,
  required UserDatabase db,
  Locale locale = const Locale('en'),
}) {
  final profileId = tracks.isNotEmpty ? tracks.first.profileId : _kProfileId;
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(profileId),
      userDatabaseProvider.overrideWith((ref) => db),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      // Real, sync-less service — matches production wiring minus Firestore,
      // so the widget test below drives the real archive code path.
      curriculumActivationServiceProvider.overrideWith(
        (ref) => _buildActivationService(db, profileId),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const ParentTrackManagementScreen(),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Seeds a stage definition for [trackId] so we can verify it survives
/// archive (deleteTrackAndData would wipe it).
Future<void> _seedStage(UserDatabase db, int trackId, int profileId) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          trackId: trackId,
          profileId: profileId,
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Learn',
        ),
      );
}

/// Seeds a goal for [trackId] so we can verify it survives archive.
Future<void> _seedGoal(UserDatabase db, int trackId, int profileId) async {
  final now = DateTime.utc(2026, 1, 1);
  await db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

/// Seeds a point-config row for [trackId] so we can verify it survives
/// archive.
Future<void> _seedPointConfig(
  UserDatabase db,
  int trackId,
  int profileId,
) async {
  await db
      .into(db.pointConfigs)
      .insert(
        PointConfigsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.maybePop<dynamic>(any<dynamic>()),
    ).thenAnswer((_) async => true);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(
      () => router.navigate(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
  });

  group('TS-3 archive (keep history)', () {
    /// DB-level test: calls the exact method the screen calls
    /// (CurriculumActivationService.archive) — not a hand-written DB update.
    test('DB unit: CurriculumActivationService.archive sets state=archived and '
        'preserves stage/goal/point-config data', () async {
      final db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: _kProfileId,
        curriculumId: 'mishnayos',
      );
      // A second curriculum keeps the profile above the minimum-1
      // threshold so archive() doesn't throw LastActiveCurriculumException.
      await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');

      await _seedStage(db, trackId, _kProfileId);
      await _seedGoal(db, trackId, _kProfileId);
      await _seedPointConfig(db, trackId, _kProfileId);

      final service = _buildActivationService(db, _kProfileId);
      await service.archive(CurriculumId.mishnayos);

      // AUD-profiles-01: track state must be 'archived', not 'deleted'.
      final row = await db.trackDao.getTrackById(trackId);
      expect(
        row?.state,
        equals(TrackState.archived.storageKey),
        reason:
            'AUD-profiles-01: "Archive (keep history)" must set '
            'state=archived, not delete the track (state=deleted).',
      );

      // Config data (goals, stage definitions, point config) must survive.
      final stages = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.trackId.equals(trackId))).get();
      expect(
        stages,
        isNotEmpty,
        reason:
            'AUD-profiles-01: archive must preserve stage definitions — '
            'deleteTrackAndData wipes them.',
      );

      final goals = await (db.select(
        db.goals,
      )..where((t) => t.trackId.equals(trackId))).get();
      expect(
        goals,
        isNotEmpty,
        reason:
            'AUD-profiles-01: archive must preserve goals — '
            'deleteTrackAndData wipes them.',
      );

      final pointConfigs = await (db.select(
        db.pointConfigs,
      )..where((t) => t.trackId.equals(trackId))).get();
      expect(
        pointConfigs,
        isNotEmpty,
        reason:
            'AUD-profiles-01: archive must preserve point config — '
            'deleteTrackAndData wipes it.',
      );

      // Archived track must not appear in the active-tracks list.
      final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
      expect(
        active.any((t) => t.id == trackId),
        isFalse,
        reason: 'AUD-profiles-01: archived track must not appear active.',
      );

      await db.close();
    });

    /// Widget-level test: drives the REAL ParentTrackManagementScreen via
    /// longPress + tap on its actual dialog — no hand-rolled AlertDialog.
    testWidgets(
      'widget: longPress + "Archive (keep history)" on the real screen '
      'preserves stage/goal/point-config data',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(
          db,
          profileId: _kProfileId,
          curriculumId: 'mishnayos',
        );
        // Second curriculum keeps the profile above the minimum-1 threshold
        // so the dialog offers Archive/Wipe (not just the blocking message).
        await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');

        await _seedStage(db, trackId, _kProfileId);
        await _seedGoal(db, trackId, _kProfileId);
        await _seedPointConfig(db, trackId, _kProfileId);

        final track = _track(id: trackId, curriculumId: 'mishnayos');

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track], db: db),
        );
        await _settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Archive (keep history)'),
          findsOneWidget,
          reason:
              'AUD-profiles-01: the real archive dialog must offer '
              '"Archive (keep history)".',
        );

        await tester.tap(find.text('Archive (keep history)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final row = await db.trackDao.getTrackById(trackId);
        expect(
          row?.state,
          equals(TrackState.archived.storageKey),
          reason:
              'AUD-profiles-01: tapping "Archive (keep history)" on the real '
              'screen must set state=archived, not delete the track.',
        );

        final stages = await (db.select(
          db.stageDefinitions,
        )..where((t) => t.trackId.equals(trackId))).get();
        expect(
          stages,
          isNotEmpty,
          reason:
              'AUD-profiles-01: archiving from the real screen must preserve '
              'stage definitions.',
        );

        final goals = await (db.select(
          db.goals,
        )..where((t) => t.trackId.equals(trackId))).get();
        expect(
          goals,
          isNotEmpty,
          reason:
              'AUD-profiles-01: archiving from the real screen must preserve '
              'goals.',
        );

        final pointConfigs = await (db.select(
          db.pointConfigs,
        )..where((t) => t.trackId.equals(trackId))).get();
        expect(
          pointConfigs,
          isNotEmpty,
          reason:
              'AUD-profiles-01: archiving from the real screen must preserve '
              'point config.',
        );

        final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
        expect(
          active.any((t) => t.id == trackId),
          isFalse,
          reason:
              'AUD-profiles-01: archived track must not appear in the active '
              'tracks list.',
        );

        await db.close();
        await _teardown(tester);
      },
    );
  });
}
