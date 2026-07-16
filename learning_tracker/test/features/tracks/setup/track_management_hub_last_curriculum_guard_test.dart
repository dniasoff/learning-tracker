/// Regression test: TRK-HUB-04 — hub delete dialog must NOT delete the last
/// active curriculum without a guard.
///
/// Before the fix: `TrackManagementHubScreen._showDeleteDialog` calls
/// `dao.deleteTrackAndData()` / `dao.purgeHistory()` directly, bypassing the
/// `LastActiveCurriculumException` guard. Deleting the only track leaves the
/// profile with zero active curricula (dashboard dead-end).
///
/// After the fix: when the user tries to archive/wipe the last active track,
/// a user-facing snackbar is shown ("Cannot remove the last curriculum") and
/// the track remains active in the DB.
@Tags(['tracks', 'track_management_hub', 'trk_hub_04'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/drift_memory.dart';
import 'helpers/track_hub_test_helpers.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

/// Minimal [TrackRepository] backed by the test's in-memory DB.
/// Only [initializeDefaultTracks] is needed by [CurriculumActivationService].
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

const _kProfileId = 1;

/// Builds a [CurriculumActivationService] wired to [db] without sync.
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

Widget _buildApp({
  required MockStackRouter router,
  required List<CurriculumTrack> tracks,
  required UserDatabase db,
}) {
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(_kProfileId),
      userDatabaseProvider.overrideWith((ref) => db),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ...perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
      curriculumActivationServiceProvider.overrideWith(
        (ref) => _buildActivationService(db, _kProfileId),
      ),
    ],
    child: MaterialApp(
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
        child: const TrackManagementHubScreen(),
      ),
    ),
  );
}

// ─── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakePageRouteInfo());
  });

  late MockStackRouter router;

  setUp(() {
    router = MockStackRouter();
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

  // ── TRK-HUB-04: last-curriculum guard ──────────────────────────────────────

  group('TRK-HUB-04: last-curriculum guard on hub delete dialog', () {
    testWidgets(
      'dialog for LAST active track shows explanation and NO Archive/Delete '
      'buttons — guard applied up-front (TS-16)',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        final track = buildTrack(id: trackId);

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track], db: db),
        );
        await settle(tester);

        // Trigger delete dialog via long-press.
        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // TS-16: destructive actions must NOT be offered for the last curriculum.
        expect(
          find.text('Archive (keep history)'),
          findsNothing,
          reason:
              'TS-16: Archive button must not appear for last active curriculum',
        );
        expect(
          find.text('Delete and wipe history'),
          findsNothing,
          reason:
              'TS-16: Delete button must not appear for last active curriculum',
        );

        // The dialog must show the explanation text instead.
        expect(
          find.textContaining('At least one curriculum must remain active'),
          findsOneWidget,
          reason: 'TS-16: dialog must explain why actions are blocked',
        );

        // Dismiss the dialog.
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // EXPECTATION: the track must still be active (never touched).
        final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
        expect(
          active.any((t) => t.id == trackId),
          isTrue,
          reason:
              'TS-16: last active curriculum must remain active — '
              'no destructive action was offered.',
        );

        await db.close();
        await teardown(tester);
      },
    );

    testWidgets(
      'dialog for LAST active track has only Cancel — wipe option hidden (TS-16)',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        final track = buildTrack(id: trackId);

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track], db: db),
        );
        await settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // TS-16: 'Delete and wipe history' must not be present.
        expect(find.text('Delete and wipe history'), findsNothing);

        // Only Cancel is available.
        expect(find.text('Cancel'), findsOneWidget);

        // Dismiss.
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Track row still exists and is active.
        final trackRow = await db.trackDao.getTrackById(trackId);
        expect(
          trackRow,
          isNotNull,
          reason: 'TS-16: track row must still exist',
        );
        expect(trackRow!.state, equals('active'));

        await db.close();
        await teardown(tester);
      },
    );

    testWidgets(
      'archiving one of TWO active tracks succeeds and removes the track from active list',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId1 = await seedTrack(
          db,
          profileId: _kProfileId,
          curriculumId: 'mishnayos',
        );
        // Two curricula — mishnayos and bavli.
        await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');
        final track1 = buildTrack(id: trackId1, curriculumId: 'mishnayos');

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track1], db: db),
        );
        await settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Archive (keep history)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // With 2 curricula, the archive should succeed (no snackbar guard).
        // The mishnayos track should no longer be active.
        final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
        expect(
          active.any((t) => t.id == trackId1),
          isFalse,
          reason:
              'Archive is safe when another curriculum remains active — '
              'the archived track must no longer be active.',
        );

        await db.close();
        await teardown(tester);
      },
    );
  });
}
