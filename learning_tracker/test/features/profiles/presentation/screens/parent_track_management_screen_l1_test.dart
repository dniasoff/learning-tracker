/// L1 widget tests for ParentTrackManagementScreen.
///
/// Covers:
///   • Empty state — "No active tracks" + "Add Track" button shown; FAB absent
///   • Populated state — LearningTrackCard(s) rendered; "Active Tracks" header;
///     count badge; FAB present
///   • Tap track card → router.push called
///   • Long-press → _showDeleteDialog — cancel: no DAO side-effect
///   • Long-press → _showDeleteDialog — "Archive" choice: track soft-deleted
///   • Long-press → _showDeleteDialog — "Wipe" choice: track purged
///   • Product rule — no "Personal"/"Standard"/"Custom"/"אישי" track-type label
///   • he-RTL smoke — populated + empty both render without overflow
@Tags(['profiles', 'parent_track_management'])
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
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Pin UseHebrewTerms to English ───────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ─── Fixture helpers ─────────────────────────────────────────────────────────

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

// ─── Provider overrides ───────────────────────────────────────────────────────

/// Per-track family provider overrides so [LearningTrackCard] resolves
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
  Locale locale = const Locale('en'),
}) {
  final database = db ?? inMemoryDb();

  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(
        tracks.isNotEmpty ? tracks.first.profileId : _kProfileId,
      ),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
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

/// Builds the app with the [activeTracksProvider] overridden to stay in the
/// loading state (stream never emits).
Widget _buildAppLoading({
  required _MockStackRouter router,
  Locale locale = const Locale('en'),
}) {
  final database = inMemoryDb();

  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(_kProfileId),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith(
        // A stream that never emits keeps the provider in the loading state.
        (ref) => const Stream<List<CurriculumTrack>>.empty(),
      ),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
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

/// Builds the app with the [activeTracksProvider] overridden to immediately
/// emit an error.
Widget _buildAppError({
  required _MockStackRouter router,
  Locale locale = const Locale('en'),
}) {
  final database = inMemoryDb();

  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(_kProfileId),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith(
        (ref) => Stream<List<CurriculumTrack>>.error(
          Exception('db error'),
          StackTrace.empty,
        ),
      ),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
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

// ─── Pump helpers ────────────────────────────────────────────────────────────

/// Pump until async stream providers resolve without pumpAndSettle on open
/// streams.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Clean teardown: dispose all widgets so Drift stream cleanup fires before the
/// test framework inspects pending timers.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

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

  // ── Empty state ───────────────────────────────────────────────────────────

  group('Empty state', () {
    testWidgets('shows "No active tracks" heading', (tester) async {
      await tester.pumpWidget(_buildApp(router: router, tracks: const []));
      await _settle(tester);

      expect(find.text('No active tracks'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('shows "Add Track" button in empty state', (tester) async {
      await tester.pumpWidget(_buildApp(router: router, tracks: const []));
      await _settle(tester);

      expect(find.text('Add Track'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('FAB (ADD TRACK) is absent in empty state', (tester) async {
      await tester.pumpWidget(_buildApp(router: router, tracks: const []));
      await _settle(tester);

      expect(find.text('ADD TRACK'), findsNothing);
      await _teardown(tester);
    });

    testWidgets(
      'tapping "Add Track" switches to AddTrackFlow (empty-state copy gone)',
      (tester) async {
        await tester.pumpWidget(_buildApp(router: router, tracks: const []));
        await _settle(tester);

        await tester.tap(find.text('Add Track'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Once AddTrackFlow is showing, the empty-state heading disappears
        expect(find.text('No active tracks'), findsNothing);
        await _teardown(tester);
      },
    );
  });

  // ── Populated state ───────────────────────────────────────────────────────

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

    testWidgets('FAB (ADD TRACK) is present when tracks exist', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('ADD TRACK'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('count badge shows "1 RUNNING" when one track active', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.textContaining('1 RUNNING'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('two tracks → count badge shows "2 RUNNING"', (tester) async {
      final tracks = [
        _track(id: 1, curriculumId: 'mishnayos'),
        _track(id: 2, curriculumId: 'bavli'),
      ];
      await tester.pumpWidget(_buildApp(router: router, tracks: tracks));
      await _settle(tester);

      expect(find.textContaining('2 RUNNING'), findsOneWidget);
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

    testWidgets('tapping a track card calls router.push once', (tester) async {
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

  // ── Delete dialog — cancel ────────────────────────────────────────────────

  group('Delete dialog — cancel', () {
    testWidgets('dismisses dialog without modifying the track in DB', (
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
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('Delete Track'), findsNothing);

      // Track still active in DB
      final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
      expect(
        active.any((t) => t.id == trackId),
        isTrue,
        reason: 'Cancel must be a no-op — track must remain active.',
      );

      await db.close();
      await _teardown(tester);
    });
  });

  // ── Delete dialog — archive ───────────────────────────────────────────────

  group('Delete dialog — archive', () {
    testWidgets(
      '"Archive (keep history)" soft-deletes track (no longer active)',
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

  // ── Delete dialog — wipe ──────────────────────────────────────────────────

  group('Delete dialog — wipe', () {
    testWidgets('"Delete and wipe history" purges track (no longer active)', (
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

      await tester.tap(find.text('Delete and wipe history'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
      expect(
        active.any((t) => t.id == trackId),
        isFalse,
        reason: 'Wipe must purge the track from the active list.',
      );

      await db.close();
      await _teardown(tester);
    });
  });

  // ── Product rules ─────────────────────────────────────────────────────────

  group('Product rules', () {
    testWidgets(
      'no "Personal" / "Standard" / "Custom" / "אישי" track-type label',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
        await _settle(tester);

        // feedback_no_track_types: these labels are banned everywhere
        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.text('אישי'), findsNothing);
        await _teardown(tester);
      },
    );

    testWidgets('no chazara reference for a learn-only track', (tester) async {
      // trackHasChazaraProvider stubbed to false in _perTrackOverrides
      final track = _track();
      await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
      await _settle(tester);

      // feedback_chazara_conditional_rendering: no chazara copy for learn-only
      expect(find.textContaining('chazara', findRichText: true), findsNothing);
      expect(find.textContaining('חזרה', findRichText: true), findsNothing);
      await _teardown(tester);
    });

    testWidgets(
      'hardcoded "Active Tracks" header is flagged — uses literal string, not l10n key',
      (tester) async {
        // BUG NOTE (not a skip): "Active Tracks" is a hardcoded English string
        // in _buildActiveHeader (line ~145 of the screen).  This test verifies
        // the header IS visible so we can detect if it ever disappears, but the
        // companion bugsFound entry documents the hardcoding.
        final track = _track();
        await tester.pumpWidget(_buildApp(router: router, tracks: [track]));
        await _settle(tester);

        expect(find.text('Active Tracks'), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  // ── R6-5 regression: loading + error states must not throw ───────────────
  //
  // Before the fix, `activeAsync.asData?.value.isNotEmpty` would evaluate
  // `.value` as null when asData was null (loading/error), causing a
  // NullPointerException on line 51.  The fix adds `?.` before `.isNotEmpty`.

  group('R6-5 — activeTracksProvider in loading/error state', () {
    testWidgets(
      'loading state: screen renders without throwing (shows spinner, no FAB)',
      (tester) async {
        await tester.pumpWidget(_buildAppLoading(router: router));
        // One pump materialises the ProviderScope; the loading indicator
        // should appear and the FAB must be absent (showAddTrackFab = false).
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // FAB must not be present while loading
        expect(find.text('ADD TRACK'), findsNothing);
        await _teardown(tester);
      },
    );

    testWidgets(
      'error state: screen renders without throwing (shows error view, no FAB)',
      (tester) async {
        await tester.pumpWidget(_buildAppError(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        // FAB must not be present on error
        expect(find.text('ADD TRACK'), findsNothing);
        // Scaffold must still be present (screen didn't crash)
        expect(find.byType(Scaffold), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  // ── RTL / Hebrew locale smoke ─────────────────────────────────────────────

  group('RTL smoke', () {
    testWidgets('Hebrew locale — populated screen renders without overflow', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _buildApp(router: router, tracks: [track], locale: const Locale('he')),
      );
      await _settle(tester);

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
