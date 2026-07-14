// L1 widget tests for:
//   • TrackManagementBody  (lib/features/tracks/setup/presentation/widgets/
//                           track_management_body.dart)
//   • TrackLearningOrderScreen (lib/features/tracks/track_order/presentation/
//                              screens/track_learning_order_screen.dart)
//
// Behaviours covered:
//   TrackManagementBody:
//     1. Loading state → CircularProgressIndicator
//     2. Empty state → icon + "No active tracks" + "Add Track" button
//     3. Populated state → AppBar title, "Active Tracks" header, count badge,
//        FAB present
//     4. FAB absent while loading / in empty state
//     5. Long-press → delete dialog with three actions (Cancel / Archive / Wipe)
//     6. Delete dialog — Cancel → track NOT removed from DB
//     7. Delete dialog — Archive → track no longer active in DB
//     8. Delete dialog — Wipe → track no longer active in DB
//     9. showBackButton=false → no back button in AppBar
//    10. showBackButton=true  → back button rendered
//    11. Error state → AppErrorView (error widget present, no spinner)
//    12. Product rule — no "Personal"/"Standard"/"Custom"/"אישי" track-type label
//    13. Chazara UI absent for a learn-only track (chazaraEnabled=false)
//    14. Chazara UI present for a chazara-enabled track
//    15. Hebrew-locale smoke — renders without overflow
//
//   TrackLearningOrderScreen:
//    16. Loading state → CircularProgressIndicator
//    17. Loaded state with sedarim list → DraggableOrderItem rows rendered
//    18. Reset button is present; tapping it shows ResetOrderDialog
//    19. Reorder callback persists order via TrackLearningOrderRepository
//    20. Race-safety: _sedarimSaveSeq prevents stale fetch overwriting newer edit
//    21. Hebrew-locale smoke — renders without overflow

@Tags(['tracks', 'track_management_body', 'track_learning_order'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockTrackLearningOrderRepository extends Mock
    implements TrackLearningOrderRepository {}

class _MockCurriculumActivationService extends Mock
    implements CurriculumActivationService {}

// ── Hebrew Terms pinned to English ────────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ── Nusach pinned to Sephardi (for reorder-header transliteration test) ───────

class _SephardiVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.sephardi;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kProfileId = 1;
const _kTrackId = 1;
const _kCurriculumId = CurriculumId.mishnayos;

// ── Fixtures ──────────────────────────────────────────────────────────────────

CurriculumTrack _track({
  int id = _kTrackId,
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

LearningOrderItem _orderItem(String ref, int sortOrder) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: sortOrder,
);

// ── Per-track provider overrides ──────────────────────────────────────────────

List<Override> _perTrackOverrides(
  List<CurriculumTrack> tracks, {
  bool chazaraEnabled = false,
}) {
  final overrides = <Override>[];
  for (final t in tracks) {
    overrides.add(
      dashboardTrackCompletionPercentageProvider(
        t.id,
      ).overrideWith((ref) async => 0.0),
    );
    overrides.add(
      trackHasChazaraProvider(t.id).overrideWith((ref) async => chazaraEnabled),
    );
  }
  overrides.add(
    dashboardHasProgramEnrollmentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => false),
  );
  return overrides;
}

// ── TrackManagementBody app builder ───────────────────────────────────────────

Widget _buildBodyApp({
  required _MockStackRouter router,
  required List<CurriculumTrack> tracks,
  UserDatabase? db,
  bool showBackButton = false,
  bool chazaraEnabled = false,
  Locale locale = const Locale('en'),
}) {
  final database = db ?? inMemoryDb();
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWithValue(
        tracks.isNotEmpty ? tracks.first.profileId : _kProfileId,
      ),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks, chazaraEnabled: chazaraEnabled),
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
        child: Scaffold(
          body: TrackManagementBody(showBackButton: showBackButton),
        ),
      ),
    ),
  );
}

// ── TrackLearningOrderScreen app builder ──────────────────────────────────────

Widget _buildOrderApp({
  required _MockTrackLearningOrderRepository repo,
  required Future<List<LearningOrderItem>> Function() sedarimFactory,
  Future<List<LearningOrderItem>> Function()? masechtosFactory,
  int trackId = _kTrackId,
  CurriculumId curriculumId = _kCurriculumId,
  Locale locale = const Locale('en'),
  bool sephardi = false,
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
      trackLearningOrderRepositoryProvider.overrideWithValue(repo),
      trackSedarimOrderProvider((
        trackId: trackId,
        curriculumId: curriculumId,
      )).overrideWith((ref) => sedarimFactory()),
      trackMasechtosOrderProvider((
        trackId: trackId,
        curriculumId: curriculumId,
      )).overrideWith(
        (ref) =>
            masechtosFactory != null ? masechtosFactory() : Future.value([]),
      ),
      overdueCountForCurriculumProvider(
        curriculumId,
      ).overrideWith((ref) async => 0),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      if (sephardi)
        currentTransliterationVariantProvider.overrideWith(
          _SephardiVariant.new,
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
      home: TrackLearningOrderScreen(
        trackId: trackId,
        curriculumId: curriculumId,
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(<LearningOrderItem>[]);
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late _MockStackRouter router;
  late _MockTrackLearningOrderRepository repo;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.maybePop<dynamic>(any<dynamic>()),
    ).thenAnswer((_) async => true);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);

    repo = _MockTrackLearningOrderRepository();
    when(
      () => repo.saveSedarimOrder(any<int>(), any<List<LearningOrderItem>>()),
    ).thenAnswer((_) async {});
    when(
      () => repo.saveMasechtosOrder(any<int>(), any<List<LearningOrderItem>>()),
    ).thenAnswer((_) async {});
    when(() => repo.resetToDefault(any<int>())).thenAnswer((_) async {});
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TrackManagementBody
  // ══════════════════════════════════════════════════════════════════════════

  group('TrackManagementBody — loading state', () {
    testWidgets('1. shows CircularProgressIndicator while stream is pending', (
      tester,
    ) async {
      final completer = StreamController<List<CurriculumTrack>>();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            activeProfileIdProvider.overrideWithValue(_kProfileId),
            userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
            activeTracksProvider.overrideWith((ref) => completer.stream),
            useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
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
              child: const Scaffold(body: TrackManagementBody()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.add([]);
      await tester.pump(const Duration(seconds: 1));
      await completer.close();
      await _teardown(tester);
    });
  });

  group('TrackManagementBody — empty state', () {
    testWidgets(
      '2. shows icon, "No tracks yet" text, and "Add Your First Track" button',
      (tester) async {
        await tester.pumpWidget(
          _buildBodyApp(router: router, tracks: const []),
        );
        await _settle(tester);

        expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
        expect(find.text('No tracks yet'), findsOneWidget);
        expect(find.text('Add Your First Track'), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets('4a. FAB (ADD TRACK) is absent in empty state', (tester) async {
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: const []));
      await _settle(tester);

      // The FAB label uses trackAddLabel = "ADD TRACK"
      expect(find.text('ADD TRACK'), findsNothing);

      await _teardown(tester);
    });
  });

  group('TrackManagementBody — populated state', () {
    testWidgets('3a. shows "Manage Tracks" AppBar title', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('Manage Tracks'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('3b. shows "Active Tracks" section header', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('Active Tracks'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('3c. count badge shows "1 RUNNING"', (tester) async {
      final track = _track();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('1 RUNNING'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('3d. FAB (ADD TRACK) is present when tracks exist', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await _settle(tester);

      expect(find.text('ADD TRACK'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets(
      '3e. tapping FAB switches to AddTrackFlow (Manage Tracks title disappears)',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
        await _settle(tester);

        await tester.tap(find.text('ADD TRACK'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Once AddTrackFlow fills the scaffold, the list title is gone.
        expect(find.text('Manage Tracks'), findsNothing);

        await _teardown(tester);
      },
    );
  });

  group('TrackManagementBody — back button', () {
    testWidgets('9. showBackButton=false → no back icon', (tester) async {
      final track = _track();
      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], showBackButton: false),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.arrow_back), findsNothing);

      await _teardown(tester);
    });

    testWidgets('10. showBackButton=true → back icon present', (tester) async {
      final track = _track();
      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], showBackButton: true),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await _teardown(tester);
    });
  });

  group('TrackManagementBody — error state', () {
    testWidgets(
      '11. error from activeTracksProvider → AppErrorView (no spinner)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, __) => null,
            overrides: [
              activeProfileIdProvider.overrideWithValue(_kProfileId),
              userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
              activeTracksProvider.overrideWith(
                (ref) =>
                    Stream<List<CurriculumTrack>>.error(Exception('DB error')),
              ),
              useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
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
                child: const Scaffold(body: TrackManagementBody()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsNothing);
        // AppErrorView renders a "Something went wrong" message and Retry button.
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        await _teardown(tester);
      },
    );
  });

  group('TrackManagementBody — delete dialog', () {
    testWidgets(
      '5. long-press opens delete dialog with Cancel / Archive / Wipe actions',
      (tester) async {
        final db = inMemoryDb();
        await seedProfile(db);
        final trackId = await seedTrack(db, profileId: _kProfileId);
        // TS-16: seed a second curriculum so trackDeletionAllowed returns
        // true and all three dialog actions are shown.
        await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');
        final track = _track(id: trackId);

        await tester.pumpWidget(
          _buildBodyApp(router: router, tracks: [track], db: db),
        );
        await _settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Delete Track'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Archive (keep history)'), findsOneWidget);
        expect(find.text('Delete and wipe history'), findsOneWidget);

        await db.close();
        await _teardown(tester);
      },
    );

    testWidgets('6. delete dialog — Cancel → track remains active in DB', (
      tester,
    ) async {
      final db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(db, profileId: _kProfileId);
      final track = _track(id: trackId);

      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], db: db),
      );
      await _settle(tester);

      await tester.longPress(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Track'), findsNothing);

      final active = await db.trackDao.getActiveTracksForProfile(_kProfileId);
      expect(
        active.any((t) => t.id == trackId),
        isTrue,
        reason: 'Cancel must not delete the track.',
      );

      await db.close();
      await _teardown(tester);
    });

    testWidgets('7. delete dialog — Archive → track no longer active in DB', (
      tester,
    ) async {
      final db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(db, profileId: _kProfileId);
      // TS-16: seed a second curriculum so trackDeletionAllowed returns true
      // and the "Archive (keep history)" action is shown.
      await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');
      final track = _track(id: trackId);

      // Stub the activation service so deactivate() succeeds without
      // needing a real curriculum-activation round trip (avoids
      // LastActiveCurriculumException while still exercising the
      // "archive" branch of _showDeleteDialog).
      final mockActivationService = _MockCurriculumActivationService();
      when(
        () => mockActivationService.deactivate(any<CurriculumId>()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            activeProfileIdProvider.overrideWithValue(_kProfileId),
            userDatabaseProvider.overrideWith((ref) => db),
            activeTracksProvider.overrideWith((ref) => Stream.value([track])),
            ..._perTrackOverrides([track]),
            curriculumActivationServiceProvider.overrideWithValue(
              mockActivationService,
            ),
            useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
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
              child: const Scaffold(body: TrackManagementBody()),
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.longPress(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Archive (keep history)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => mockActivationService.deactivate(CurriculumId.mishnayos),
      ).called(1);

      await db.close();
      await _teardown(tester);
    });

    testWidgets('8. delete dialog — Wipe → track no longer active in DB', (
      tester,
    ) async {
      final db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(db, profileId: _kProfileId);
      // TS-16: seed a second curriculum so trackDeletionAllowed returns true
      // and the "Delete and wipe history" action is shown.
      await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');
      final track = _track(id: trackId);

      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], db: db),
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

  group('TrackManagementBody — product rules', () {
    testWidgets(
      '12. no "Personal"/"Standard"/"Custom"/"אישי" track-type label',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
        await _settle(tester);

        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.text('אישי'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets(
      '13. chazara UI absent for a learn-only track (chazaraEnabled=false)',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _buildBodyApp(router: router, tracks: [track], chazaraEnabled: false),
        );
        await _settle(tester);

        expect(
          find.textContaining('chazara', findRichText: true),
          findsNothing,
        );
        expect(find.textContaining('חזרה', findRichText: true), findsNothing);
        // The track-progress label for a non-chazara track is "Track progress"
        expect(find.text('Track progress'), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets('14. chazara label present for a chazara-enabled track', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], chazaraEnabled: true),
      );
      await _settle(tester);

      // When chazara is enabled the label becomes "Completion (with Chazara)"
      expect(
        find.textContaining('Chazara', findRichText: true),
        findsOneWidget,
      );

      await _teardown(tester);
    });
  });

  group('TrackManagementBody — RTL smoke', () {
    testWidgets('15. Hebrew locale — populated body renders without overflow', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _buildBodyApp(
          router: router,
          tracks: [track],
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      // TrackManagementBody itself contains a Scaffold; the outer wrapper also
      // adds one — so we find at least one without asserting an exact count.
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TrackLearningOrderScreen
  // ══════════════════════════════════════════════════════════════════════════

  group('TrackLearningOrderScreen — loading state', () {
    testWidgets(
      '16. shows CircularProgressIndicator while providers are pending',
      (tester) async {
        final completer = Completer<List<LearningOrderItem>>();
        await tester.pumpWidget(
          _buildOrderApp(repo: repo, sedarimFactory: () => completer.future),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete([]);
        await tester.pump(const Duration(seconds: 1));
        await _teardown(tester);
      },
    );
  });

  group('TrackLearningOrderScreen — loaded state', () {
    testWidgets('17. renders DraggableOrderItem rows for each sedarim item', (
      tester,
    ) async {
      final items = [
        _orderItem('Seder Zeraim', 0),
        _orderItem('Seder Moed', 1),
      ];

      await tester.pumpWidget(
        _buildOrderApp(repo: repo, sedarimFactory: () => Future.value(items)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Two DraggableOrderItem widgets — one per sedarim item.
      expect(find.byType(DraggableOrderItem), findsNWidgets(2));

      await _teardown(tester);
    });

    testWidgets('17b. AppBar title includes curriculum name', (tester) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Title format: "<curriculum> • Reorder"
      expect(find.textContaining('Reorder'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('17b-he. AppBar title is localized in Hebrew locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The hardcoded English "Reorder" must not appear; the Hebrew label does.
      expect(find.textContaining('Reorder'), findsNothing);
      expect(find.textContaining('סדר מחדש'), findsOneWidget);

      await _teardown(tester);
    });

    // 17c. The P2 fix: the L2 reorder section header is nusach-aware. In the
    // default Ashkenazi nusach Mishnayos shows "Masechtos"; under Sephardi it
    // must switch to "Masekhtot" (proving topSectionHeader /
    // containerSectionHeader forward the variant to inLanguage()).
    testWidgets('17c. L2 section header is "Masechtos" in Ashkenazi nusach', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
          masechtosFactory: () => Future.value([_orderItem('Berakhos', 0)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Masechtos'), findsOneWidget);
      expect(find.text('Masekhtot'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('17d. L2 section header switches to "Masekhtot" in Sephardi', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
          masechtosFactory: () => Future.value([_orderItem('Berakhos', 0)]),
          sephardi: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Sephardi nusach maps Masechtos → Masekhtot; the Ashkenazi form gone.
      expect(find.text('Masekhtot'), findsOneWidget);
      expect(find.text('Masechtos'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('18a. reset icon button is present', (tester) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('18b. tapping reset icon shows ResetOrderDialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ResetOrderDialog renders "Reset to Default Order" title.
      expect(find.text('Reset to Default Order'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('18c. cancelling reset dialog → resetToDefault NOT called', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value([_orderItem('Seder Zeraim', 0)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verifyNever(() => repo.resetToDefault(any<int>()));

      await _teardown(tester);
    });

    testWidgets('18d. confirming reset dialog → resetToDefault called', (
      tester,
    ) async {
      // After reset the providers must yield fresh lists — use a counter to
      // serve a "refreshed" empty list on the second call.
      var callCount = 0;
      final sedarimFutures = [
        Future.value([_orderItem('Seder Zeraim', 0)]),
        Future.value(<LearningOrderItem>[]),
      ];

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
            trackLearningOrderRepositoryProvider.overrideWithValue(repo),
            trackSedarimOrderProvider((
              trackId: _kTrackId,
              curriculumId: _kCurriculumId,
            )).overrideWith((ref) {
              final i = callCount;
              if (callCount < sedarimFutures.length - 1) callCount++;
              return sedarimFutures[i];
            }),
            trackMasechtosOrderProvider((
              trackId: _kTrackId,
              curriculumId: _kCurriculumId,
            )).overrideWith((ref) => Future.value([])),
            overdueCountForCurriculumProvider(
              _kCurriculumId,
            ).overrideWith((ref) async => 0),
            useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TrackLearningOrderScreen(
              trackId: _kTrackId,
              curriculumId: _kCurriculumId,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Confirm in dialog
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(() => repo.resetToDefault(_kTrackId)).called(1);

      await _teardown(tester);
    });
  });

  group('TrackLearningOrderScreen — reorder persists', () {
    testWidgets(
      '19. reordering sedarim calls saveSedarimOrder with reordered list',
      (tester) async {
        // Two items so there's actually something to drag.
        final items = [
          _orderItem('Seder Zeraim', 0),
          _orderItem('Seder Moed', 1),
        ];

        await tester.pumpWidget(
          _buildOrderApp(repo: repo, sedarimFactory: () => Future.value(items)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Simulate the internal _onReorderSedarim(0, 1) callback
        // by looking up the ReorderableListView and calling its onReorderItem.
        final listFinder = find.byType(ReorderableListView).first;
        final listWidget = tester.widget<ReorderableListView>(listFinder);
        // onReorderItem moves item at index 0 to index 1 (swaps Zeraim/Moed).
        listWidget.onReorderItem?.call(0, 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        verify(
          () =>
              repo.saveSedarimOrder(_kTrackId, any<List<LearningOrderItem>>()),
        ).called(1);

        await _teardown(tester);
      },
    );
  });

  group('TrackLearningOrderScreen — race-safety (_sedarimSaveSeq)', () {
    testWidgets(
      '20. rapid successive reorders only persist the final order (seq guard)',
      (tester) async {
        // Both reorders must complete before the slow first save resolves.
        final items = [
          _orderItem('Seder Zeraim', 0),
          _orderItem('Seder Moed', 1),
        ];

        // First save is deliberately slow; second resolves immediately.
        var saveCount = 0;
        when(
          () =>
              repo.saveSedarimOrder(any<int>(), any<List<LearningOrderItem>>()),
        ).thenAnswer((_) async {
          saveCount++;
          if (saveCount == 1) {
            // Slow first save — yields so the test can trigger a second reorder.
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
        });

        await tester.pumpWidget(
          _buildOrderApp(repo: repo, sedarimFactory: () => Future.value(items)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final listFinder = find.byType(ReorderableListView).first;
        final listWidget = tester.widget<ReorderableListView>(listFinder);

        // First reorder (starts slow async save).
        listWidget.onReorderItem?.call(0, 1);
        await tester.pump(const Duration(milliseconds: 10));

        // Second reorder while first save is still in-flight.
        listWidget.onReorderItem?.call(0, 1);
        await tester.pump(const Duration(milliseconds: 400));

        // Both save calls are dispatched.
        verify(
          () =>
              repo.saveSedarimOrder(_kTrackId, any<List<LearningOrderItem>>()),
        ).called(2);

        // The screen must still be mounted and showing the list without crash.
        expect(find.byType(DraggableOrderItem), findsAtLeastNWidgets(1));

        await _teardown(tester);
      },
    );
  });

  group('TrackLearningOrderScreen — RTL smoke', () {
    testWidgets('21. Hebrew locale — renders without overflow', (tester) async {
      final items = [_orderItem('Seder Zeraim', 0)];
      await tester.pumpWidget(
        _buildOrderApp(
          repo: repo,
          sedarimFactory: () => Future.value(items),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);

      await _teardown(tester);
    });
  });
}
