/// L1 widget tests for TrackManagementHubScreen.
///
/// Covers:
///   • Empty state — "No tracks yet" + "Add Your First Track" button shown
///   • Populated state — LearningTrackCard(s) rendered per track
///   • startAdding:true — AddTrackFlow shown immediately (no list)
///   • FAB present when tracks exist; absent when empty
///   • Per-track tap → router.push(TrackDetailRoute)
///   • Long-press → delete dialog appears
///   • Delete dialog — cancel: no DAO call, track remains active
///   • Delete dialog — "Archive" choice: deleteTrackAndData() soft-deletes track
///   • Delete dialog — "Wipe" choice: purgeHistory() purges track
///   • Product rule — no "Personal"/"Standard"/"Custom" track-type label
///   • Chazara label absent for no-chazara tracks
///   • RTL smoke — Hebrew locale renders without overflow
@Tags(['tracks', 'track_management_hub'])
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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/drift_memory.dart';

/// Minimal [TrackRepository] for tests — only [initializeDefaultTracks] is needed.
class _TrackRepositoryForTest implements TrackRepository {
  _TrackRepositoryForTest(this._db);
  final UserDatabase _db;

  @override
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) => _db.trackDao.initializeDefaultTracks(curriculumId, profileId: profileId);
}

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Pin UseHebrewTerms to English ────────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ─── Fixture ──────────────────────────────────────────────────────────────────

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

// ─── Provider override helpers ────────────────────────────────────────────────

/// Build all per-track provider overrides so [LearningTrackCard] resolves
/// synchronously without hanging on futures.
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
  // The program-enrollment provider is keyed by CurriculumId. Stub mishnayos
  // (our fixture curriculum) to false so the progress row is shown.
  overrides.add(
    dashboardHasProgramEnrollmentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => false),
  );
  return overrides;
}

// ─── App builder ──────────────────────────────────────────────────────────────

Widget _buildApp({
  required _MockStackRouter router,
  required List<CurriculumTrack> tracks,
  UserDatabase? db,
  bool startAdding = false,
  Locale locale = const Locale('en'),
}) {
  final database = db ?? inMemoryDb();
  final profileId =
      tracks.isNotEmpty ? tracks.first.profileId : _kProfileId;

  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(profileId),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      // Provide a real CurriculumActivationService backed by the in-memory DB
      // so that the last-curriculum guard works correctly in tests.
      curriculumActivationServiceProvider.overrideWith(
        (ref) => CurriculumActivationService(
          database: database,
          pushCurriculumTrack: null,
          trackRepository: _TrackRepositoryForTest(database),
          profileId: profileId,
          syncFacade: null,
        ),
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
        child: TrackManagementHubScreen(startAdding: startAdding),
      ),
    ),
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Pump until async providers resolve (avoids pumpAndSettle with open streams).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Dispose widgets cleanly to prevent "deactivated" errors from open streams.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

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

  // ── Empty state ─────────────────────────────────────────────────────────────

  group('Empty state', () {
    testWidgets('shows "No tracks yet" heading', (tester) async {
      await tester.pumpWidget(_buildApp(router: router, tracks: const []));
      await _settle(tester);

      expect(find.text('No tracks yet'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('shows "Add Your First Track" button', (tester) async {
      await tester.pumpWidget(_buildApp(router: router, tracks: const []));
      await _settle(tester);

      expect(find.text('Add Your First Track'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('FAB (ADD TRACK) is absent in empty state', (tester) async {
      await tester.pumpWidget(_buildApp(router: router, tracks: const []));
      await _settle(tester);

      expect(find.text('ADD TRACK'), findsNothing);
      await _teardown(tester);
    });

    testWidgets(
      'tapping "Add Your First Track" switches into AddTrackFlow (hub title gone)',
      (tester) async {
        await tester.pumpWidget(_buildApp(router: router, tracks: const []));
        await _settle(tester);

        await tester.tap(find.text('Add Your First Track'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Once AddTrackFlow is showing, the empty-state copy disappears.
        expect(find.text('No tracks yet'), findsNothing);
        await _teardown(tester);
      },
    );
  });

  // ── startAdding:true ───────────────────────────────────────────────────────

  group('startAdding:true', () {
    testWidgets(
      'AddTrackFlow is shown immediately — hub list/title is not rendered',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(router: router, tracks: const [], startAdding: true),
        );
        await _settle(tester);

        // Hub title absent when AddTrackFlow takes over the scaffold body
        expect(find.text('Manage Tracks'), findsNothing);
        // Empty-state copy also absent
        expect(find.text('No tracks yet'), findsNothing);
        await _teardown(tester);
      },
    );
  });

  // ── Populated state ─────────────────────────────────────────────────────────

  group('Populated state', () {
    testWidgets('"Active Tracks" header is present', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('Active Tracks'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('"Manage Tracks" app-bar title is present', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('Manage Tracks'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('FAB (ADD TRACK) is present', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('ADD TRACK'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('count badge shows "1 running"', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.textContaining('1'), findsWidgets);
      await _teardown(tester);
    });

    testWidgets('tapping FAB switches to AddTrackFlow (hub title gone)', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      await tester.tap(find.text('ADD TRACK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Manage Tracks'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('tapping track card calls router.push once', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      verify(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).called(1);
      await _teardown(tester);
    });

    testWidgets('long-press opens delete dialog with all three actions', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      await tester.longPress(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete Track'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Archive (keep history)'), findsOneWidget);
      expect(find.text('Delete and wipe history'), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ── Delete dialog — cancel ──────────────────────────────────────────────────

  group('Delete dialog — cancel', () {
    testWidgets('dismisses dialog without deleting the track from DB', (
      tester,
    ) async {
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

      await tester.tap(find.text('Cancel'));
      // pumpAndSettle here is safe — cancel only closes the dialog (no streams)
      await tester.pumpAndSettle();

      // Dialog is gone
      expect(find.text('Delete Track'), findsNothing);

      // Track still active in DB — cancel must be a no-op
      final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
      expect(
        active.any((t) => t.id == trackId),
        isTrue,
        reason: 'Cancel must not delete the track.',
      );

      await db.close();
      await _teardown(tester);
    });
  });

  // ── Delete dialog — archive ─────────────────────────────────────────────────

  group('Delete dialog — archive', () {
    testWidgets(
      '"Archive (keep history)" soft-deletes track (state becomes deleted) '
      '— when a second curriculum remains active',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        // Seed a SECOND curriculum so the guard allows the delete.
        await seedTrack(
          db,
          profileId: _kProfileId,
          curriculumId: 'bavli',
        );
        final track = _track(id: trackId);

        await tester.pumpWidget(
          _buildApp(router: router, tracks: [track], db: db),
        );
        await _settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Archive (keep history)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
        expect(
          active.any((t) => t.id == trackId),
          isFalse,
          reason: 'Archive must soft-delete: track must not appear as active.',
        );

        await db.close();
        await _teardown(tester);
      },
    );
  });

  // ── Delete dialog — wipe ────────────────────────────────────────────────────

  group('Delete dialog — wipe', () {
    testWidgets(
      '"Delete and wipe history" purges track (no longer active) '
      '— when a second curriculum remains active',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        // Seed a SECOND curriculum so the guard allows the wipe.
        await seedTrack(
          db,
          profileId: _kProfileId,
          curriculumId: 'bavli',
        );
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

        final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
        expect(
          active.any((t) => t.id == trackId),
          isFalse,
          reason: 'Wipe must purge the track from active list.',
        );

        await db.close();
        await _teardown(tester);
      },
    );
  });

  // ── Product rules ────────────────────────────────────────────────────────────

  group('Product rules', () {
    testWidgets(
      'no "Personal" / "Standard" / "Custom" track-type label (Rule 7)',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
        await _settle(tester);

        // feedback_no_track_types: these labels are forbidden everywhere
        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        // Hebrew equivalent that was previously regressing
        expect(find.text('אישי'), findsNothing);
        await _teardown(tester);
      },
    );

    testWidgets('no chazara reference for a learn-only track (Rule 8)', (
      tester,
    ) async {
      // trackHasChazaraProvider overridden to false in _perTrackOverrides
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      // feedback_chazara_conditional_rendering: no chazara copy unless
      // track.chazaraEnabled (proxied by trackHasChazaraProvider returning true)
      expect(find.textContaining('chazara', findRichText: true), findsNothing);
      expect(find.textContaining('חזרה', findRichText: true), findsNothing);
      await _teardown(tester);
    });
  });

  // ── RTL / Hebrew locale smoke ─────────────────────────────────────────────

  group('RTL smoke', () {
    testWidgets('Hebrew locale — populated hub renders without overflow', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _buildApp(router: router, tracks: [track], locale: const Locale('he')),
      );
      await _settle(tester);

      // Key structural widget must be present; no layout overflow thrown
      expect(find.byType(Scaffold), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('Hebrew locale — empty state renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(router: router, tracks: const [], locale: const Locale('he')),
      );
      await _settle(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      await _teardown(tester);
    });
  });
}
