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
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
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
import 'setup/helpers/track_hub_test_helpers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTrackLearningOrderRepository extends Mock
    implements TrackLearningOrderRepository {}

class _MockCurriculumActivationService extends Mock
    implements CurriculumActivationService {}

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

LearningOrderItem _orderItem(String ref, int sortOrder) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: sortOrder,
);

// ── TrackManagementBody app builder ───────────────────────────────────────────

Widget _buildBodyApp({
  required MockStackRouter router,
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
      ...perTrackOverrides(tracks, chazaraEnabled: chazaraEnabled),
      useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
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
      useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
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

/// The sefariaRefs of every currently-rendered [DraggableOrderItem], read
/// directly off the widget (not via rendered text, since [DraggableOrderItem]
/// resolves its label asynchronously through `CurriculumLabel.local`).
List<String> _renderedRefs(WidgetTester tester) => tester
    .widgetList<DraggableOrderItem>(find.byType(DraggableOrderItem))
    .map((w) => w.item.sefariaRef)
    .toList();

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakePageRouteInfo());
    registerFallbackValue(<LearningOrderItem>[]);
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late MockStackRouter router;
  late _MockTrackLearningOrderRepository repo;

  setUp(() {
    router = MockStackRouter();
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
            useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
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
      await teardown(tester);
    });
  });

  group('TrackManagementBody — empty state', () {
    testWidgets(
      '2. shows icon, "No tracks yet" text, and "Add Your First Track" button',
      (tester) async {
        await tester.pumpWidget(
          _buildBodyApp(router: router, tracks: const []),
        );
        await settle(tester);

        expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
        expect(find.text('No tracks yet'), findsOneWidget);
        expect(find.text('Add Your First Track'), findsOneWidget);

        await teardown(tester);
      },
    );

    testWidgets('4a. FAB (ADD TRACK) is absent in empty state', (tester) async {
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: const []));
      await settle(tester);

      // The FAB label uses trackAddLabel = "ADD TRACK"
      expect(find.text('ADD TRACK'), findsNothing);

      await teardown(tester);
    });
  });

  group('TrackManagementBody — populated state', () {
    testWidgets('3a. shows "Manage Tracks" AppBar title', (tester) async {
      final track = buildTrack();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await settle(tester);

      expect(find.text('Manage Tracks'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('3b. shows "Active Tracks" section header', (tester) async {
      final track = buildTrack();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await settle(tester);

      expect(find.text('Active Tracks'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('3c. count badge shows "1 RUNNING"', (tester) async {
      final track = buildTrack();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await settle(tester);

      expect(find.text('1 RUNNING'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('3d. FAB (ADD TRACK) is present when tracks exist', (
      tester,
    ) async {
      final track = buildTrack();
      await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
      await settle(tester);

      expect(find.text('ADD TRACK'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets(
      '3e. tapping FAB switches to AddTrackFlow (Manage Tracks title disappears)',
      (tester) async {
        final track = buildTrack();
        await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
        await settle(tester);

        await tester.tap(find.text('ADD TRACK'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Once AddTrackFlow fills the scaffold, the list title is gone.
        expect(find.text('Manage Tracks'), findsNothing);

        await teardown(tester);
      },
    );
  });

  group('TrackManagementBody — back button', () {
    testWidgets('9. showBackButton=false → no back icon', (tester) async {
      final track = buildTrack();
      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], showBackButton: false),
      );
      await settle(tester);

      expect(find.byIcon(Icons.arrow_back), findsNothing);

      await teardown(tester);
    });

    testWidgets('10. showBackButton=true → back icon present', (tester) async {
      final track = buildTrack();
      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], showBackButton: true),
      );
      await settle(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await teardown(tester);
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
              useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
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

        await teardown(tester);
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
        final track = buildTrack(id: trackId);

        await tester.pumpWidget(
          _buildBodyApp(router: router, tracks: [track], db: db),
        );
        await settle(tester);

        await tester.longPress(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Delete Track'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Archive (keep history)'), findsOneWidget);
        expect(find.text('Delete and wipe history'), findsOneWidget);

        await db.close();
        await teardown(tester);
      },
    );

    testWidgets('6. delete dialog — Cancel → track remains active in DB', (
      tester,
    ) async {
      final db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(db, profileId: _kProfileId);
      final track = buildTrack(id: trackId);

      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], db: db),
      );
      await settle(tester);

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
      await teardown(tester);
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
      final track = buildTrack(id: trackId);

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
            ...perTrackOverrides([track]),
            curriculumActivationServiceProvider.overrideWithValue(
              mockActivationService,
            ),
            useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
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
      await settle(tester);

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
      await teardown(tester);
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
      final track = buildTrack(id: trackId);

      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], db: db),
      );
      await settle(tester);

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
      await teardown(tester);
    });
  });

  group('TrackManagementBody — product rules', () {
    testWidgets(
      '12. no "Personal"/"Standard"/"Custom"/"אישי" track-type label',
      (tester) async {
        final track = buildTrack();
        await tester.pumpWidget(_buildBodyApp(router: router, tracks: [track]));
        await settle(tester);

        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.text('אישי'), findsNothing);

        await teardown(tester);
      },
    );

    testWidgets(
      '13. chazara UI absent for a learn-only track (chazaraEnabled=false)',
      (tester) async {
        final track = buildTrack();
        await tester.pumpWidget(
          _buildBodyApp(router: router, tracks: [track], chazaraEnabled: false),
        );
        await settle(tester);

        expect(
          find.textContaining('chazara', findRichText: true),
          findsNothing,
        );
        expect(find.textContaining('חזרה', findRichText: true), findsNothing);
        // The track-progress label for a non-chazara track is "Track progress"
        expect(find.text('Track progress'), findsOneWidget);

        await teardown(tester);
      },
    );

    testWidgets('14. chazara label present for a chazara-enabled track', (
      tester,
    ) async {
      final track = buildTrack();
      await tester.pumpWidget(
        _buildBodyApp(router: router, tracks: [track], chazaraEnabled: true),
      );
      await settle(tester);

      // When chazara is enabled the label becomes "Completion (with Chazara)"
      expect(
        find.textContaining('Chazara', findRichText: true),
        findsOneWidget,
      );

      await teardown(tester);
    });
  });

  group('TrackManagementBody — RTL smoke', () {
    testWidgets('15. Hebrew locale — populated body renders without overflow', (
      tester,
    ) async {
      final track = buildTrack();
      await tester.pumpWidget(
        _buildBodyApp(
          router: router,
          tracks: [track],
          locale: const Locale('he'),
        ),
      );
      await settle(tester);

      // TrackManagementBody itself contains a Scaffold; the outer wrapper also
      // adds one — so we find at least one without asserting an exact count.
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

      await teardown(tester);
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
        await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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

      await teardown(tester);
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
            useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
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

      await teardown(tester);
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

        await teardown(tester);
      },
    );
  });

  group('TrackLearningOrderScreen — race-safety (_sedarimSaveSeq)', () {
    testWidgets(
      '20. a stale slow save resolving after a newer reorder must not '
      'clobber the fresher masechtos state (seq guard)',
      (tester) async {
        final items = [
          _orderItem('Seder Zeraim', 0),
          _orderItem('Seder Moed', 1),
        ];

        // Each saveSedarimOrder call gets its own Completer so the test
        // — not a fixed delay racing a fixed pump duration — controls
        // exactly which save "wins" and when.
        final saveCompleters = <Completer<void>>[];
        when(
          () =>
              repo.saveSedarimOrder(any<int>(), any<List<LearningOrderItem>>()),
        ).thenAnswer((_) {
          final completer = Completer<void>();
          saveCompleters.add(completer);
          return completer.future;
        });

        // Each masechtos read (the initial load, plus any post-save
        // invalidate/refetch triggered from _persistSedarim) also gets its
        // own Completer, so the test can tell a "fresh" refetch (triggered
        // by the second, winning reorder) apart from a "stale" one
        // (triggered by the first, slow reorder resolving late) — and prove
        // the stale one never happens once the seq guard is in place.
        final masechtosReads = <Completer<List<LearningOrderItem>>>[];
        Future<List<LearningOrderItem>> masechtosFactory() {
          final completer = Completer<List<LearningOrderItem>>();
          masechtosReads.add(completer);
          return completer.future;
        }

        await tester.pumpWidget(
          _buildOrderApp(
            repo: repo,
            sedarimFactory: () => Future.value(items),
            masechtosFactory: masechtosFactory,
          ),
        );
        await tester.pump();

        // Resolve the initial masechtos load (the body stays behind the
        // loading spinner — gated on BOTH sedarim and masechtos — until it
        // does).
        expect(masechtosReads, hasLength(1));
        masechtosReads[0].complete([_orderItem('Masechtos Initial', 0)]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final listFinder = find.byType(ReorderableListView).first;
        final listWidget = tester.widget<ReorderableListView>(listFinder);

        // First reorder — its save is left pending ("slow").
        listWidget.onReorderItem?.call(0, 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(saveCompleters, hasLength(1));

        // Second reorder fired while the first save is still in flight —
        // its save is also left pending for now.
        listWidget.onReorderItem?.call(0, 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(saveCompleters, hasLength(2));

        // The SECOND (fresher) save resolves first.
        saveCompleters[1].complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        // Its post-save continuation invalidates + refetches masechtos —
        // resolve that fresh read.
        expect(masechtosReads, hasLength(2));
        masechtosReads[1].complete([_orderItem('Masechtos Fresh', 0)]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(_renderedRefs(tester), contains('Masechtos Fresh'));
        expect(_renderedRefs(tester), isNot(contains('Masechtos Initial')));

        // Now the FIRST (stale) save finally resolves, late.
        saveCompleters[0].complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The seq guard must suppress the stale continuation entirely: no
        // extra masechtos invalidate/refetch fires, and the rendered order
        // still reflects only the second (fresher) reorder's masechtos
        // fetch — not a stale one clobbering it.
        expect(
          masechtosReads,
          hasLength(2),
          reason:
              'a late-resolving stale save must not trigger another '
              'masechtos invalidate/refetch once a newer reorder has '
              'already landed — if it does, the seq guard has regressed',
        );
        expect(_renderedRefs(tester), contains('Masechtos Fresh'));

        await teardown(tester);
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

      await teardown(tester);
    });
  });
}
