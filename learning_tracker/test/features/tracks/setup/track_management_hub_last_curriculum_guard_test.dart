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
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/drift_memory.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

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

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Fixture ──────────────────────────────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

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
  required _MockStackRouter router,
  required List<CurriculumTrack> tracks,
  required UserDatabase db,
}) {
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(_kProfileId),
      userDatabaseProvider.overrideWith((ref) => db),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─── Tests ─────────────────────────────────────────────────────────────────────

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

  // ── TRK-HUB-04: last-curriculum guard ──────────────────────────────────────

  group('TRK-HUB-04: last-curriculum guard on hub delete dialog', () {
    testWidgets(
      'archiving the LAST active track shows "cannot remove" error snackbar '
      'and keeps the track active in DB (guard prevents dead-end)',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        final track = _track(id: trackId);

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track], db: db),
        );
        await _settle(tester);

        // Trigger delete dialog via long-press.
        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Choose Archive (soft-delete).
        await tester.tap(find.text('Archive (keep history)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // EXPECTATION AFTER FIX: an error snackbar must appear.
        // The snackbar text should contain the "cannot deactivate last" key.
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason:
              'Hub must show a guard snackbar when user tries to archive the '
              'last active curriculum.',
        );

        // EXPECTATION AFTER FIX: the track must still be active.
        final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
        expect(
          active.any((t) => t.id == trackId),
          isTrue,
          reason:
              'Archive of the last active curriculum must be blocked — '
              'track must remain active.',
        );

        await db.close();
        await _teardown(tester);
      },
    );

    testWidgets(
      'wiping the LAST active track shows "cannot remove" error snackbar '
      'and keeps the track active in DB (wipe path also guarded)',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        final track = _track(id: trackId);

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track], db: db),
        );
        await _settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Delete and wipe history'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // EXPECTATION AFTER FIX: guard snackbar shown.
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason:
              'Hub must show a guard snackbar when user tries to wipe the '
              'last active curriculum.',
        );

        // EXPECTATION AFTER FIX: track row still exists.
        final trackRow = await db.trackDao.getTrackById(trackId);
        expect(
          trackRow,
          isNotNull,
          reason:
              'Wipe of the last active curriculum must be blocked — '
              'track row must still exist.',
        );
        expect(trackRow!.state, equals('active'));

        await db.close();
        await _teardown(tester);
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
        final track1 = _track(id: trackId1, curriculumId: 'mishnayos');

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track1], db: db),
        );
        await _settle(tester);

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
        await _teardown(tester);
      },
    );
  });
}
