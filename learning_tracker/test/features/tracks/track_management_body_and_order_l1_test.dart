/// Firestore-native L1 coverage for track management and content ordering.
@Tags(['tracks', 'track_management', 'track_order'])
library;
// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_fixtures.dart';

class _Router extends Mock implements StackRouter {}

class _OrderRepo extends Mock implements TrackLearningOrderRepository {}

const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY9';

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

Widget _body(
  _Router router,
  List<CurriculumTrackEntity> tracks, {
  required FakeFirebaseFirestore firestore,
  Stream<List<CurriculumTrackEntity>>? activeStream,
  bool showBackButton = false,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  retry: (_, __) => null,
  overrides: [
    activeProfileIdProvider.overrideWithValue(_profileId),
    firestoreCurriculumTrackRepositoryProvider.overrideWith(
      (ref) async => FirestoreCurriculumTrackRepository(
        firestore: firestore,
        uid: 'track-body-test-uid',
        profileId: _profileId,
      ),
    ),
    firestoreStudyDayConfigRepositoryProvider.overrideWith(
      (ref) async => FirestoreStudyDayConfigRepository(
        firestore: firestore,
        uid: 'track-body-test-uid',
        profileId: _profileId,
      ),
    ),
    if (activeStream != null)
      activeTracksProvider.overrideWith((ref) => activeStream)
    else
      activeTracksProvider.overrideWith(
        (ref) => FirestoreCurriculumTrackRepository(
          firestore: firestore,
          uid: 'track-body-test-uid',
          profileId: _profileId,
        ).watchActiveTracks(),
      ),
    dashboardTrackCompletionPercentageProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => 0),
    trackHasChazaraProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => false),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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

void main() {
  setUpAll(() {
    registerFallbackValue(<LearningOrderItem>[]);
    registerFallbackValue(CurriculumId.mishnayos);
  });

  testWidgets('body renders the empty state from the active-track stream', (
    tester,
  ) async {
    await tester.pumpWidget(
      _body(
        _Router(),
        const [],
        firestore: createFakeFirestore(authenticatedUid: 'track-body-test-uid'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No tracks yet'), findsOneWidget);
  });

  testWidgets('body renders the Firestore-shaped curriculum track', (
    tester,
  ) async {
    final firestore = createFakeFirestore(
      authenticatedUid: 'track-body-test-uid',
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await tester.pumpWidget(_body(_Router(), [_track()], firestore: firestore));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Active Tracks'), findsOneWidget);
    expect(find.textContaining('1 RUNNING'), findsOneWidget);
  });

  testWidgets('order screen renders repository-provided items', (tester) async {
    final repo = _OrderRepo();
    final items = [
      const LearningOrderItem(
        sefariaRef: 'Mishnah 1',
        displayNameHe: 'משנה א',
        displayNameEn: 'Mishnah 1',
        userSortOrder: 0,
      ),
    ];
    when(() => repo.saveSedarimOrder(any(), any())).thenAnswer((_) async {});
    when(() => repo.saveMasechtosOrder(any(), any())).thenAnswer((_) async {});
    when(() => repo.resetToDefault(any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentIndexProvider.overrideWith(
            (ref) async => ContentIndex.fromCurricula({
              CurriculumId.mishnayos: const [
                ContentItem(
                  curriculumId: 'mishnayos',
                  level1: 'Seder Zeraim',
                  level2: 'Mishnah Berakhot',
                  level3: '1',
                  displayNameHe: 'משנה א',
                  displayNameEn: 'Mishnah Berakhot 1',
                  sefariaRef: 'Mishnah Berakhot 1',
                  sortOrder: 0,
                  isLeaf: true,
                ),
              ],
            }),
          ),
          useHebrewTermsProvider.overrideWithValue(false),
          trackLearningOrderRepositoryProvider.overrideWithValue(repo),
          trackSedarimOrderProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => items),
          trackMasechtosOrderProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackLearningOrderScreen(curriculumId: CurriculumId.mishnayos),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mishnah 1'), findsWidgets);
  });

  testWidgets('long-press opens the Firestore-backed delete dialog', (
    tester,
  ) async {
    final firestore = createFakeFirestore(
      authenticatedUid: 'track-body-test-uid',
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    await tester.pumpWidget(_body(_Router(), [_track()], firestore: firestore));
    await tester.pump(const Duration(milliseconds: 300));
    final mishnayosCard = find.byWidgetPredicate(
      (widget) =>
          widget is LearningTrackCard &&
          widget.track.curriculumId == CurriculumId.mishnayos,
    );
    expect(mishnayosCard, findsOneWidget);
    final mishnayosInkWell = find.descendant(
      of: mishnayosCard,
      matching: find.byType(InkWell),
    );
    expect(mishnayosInkWell, findsOneWidget);
    await tester.longPress(mishnayosInkWell);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Delete Track'), findsOneWidget);
    expect(find.text('Archive (keep history)'), findsOneWidget);
    expect(find.text('Delete and wipe history'), findsOneWidget);
  });

  testWidgets('archive action changes the selected Firestore track state', (
    tester,
  ) async {
    final firestore = createFakeFirestore(
      authenticatedUid: 'track-body-test-uid',
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    await tester.pumpWidget(_body(_Router(), [_track()], firestore: firestore));
    await tester.pump(const Duration(milliseconds: 300));
    final mishnayosCard = find.byWidgetPredicate(
      (widget) =>
          widget is LearningTrackCard &&
          widget.track.curriculumId == CurriculumId.mishnayos,
    );
    expect(mishnayosCard, findsOneWidget);
    final mishnayosInkWell = find.descendant(
      of: mishnayosCard,
      matching: find.byType(InkWell),
    );
    expect(mishnayosInkWell, findsOneWidget);
    await tester.longPress(mishnayosInkWell);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Archive (keep history)'));
    await tester.pump(const Duration(milliseconds: 500));

    final stored = await FirestoreCurriculumTrackRepository(
      firestore: firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
    ).getTrack(CurriculumId.mishnayos);
    expect(stored?.isActive, isFalse);
    expect(stored?.state, 'retired');
  });

  testWidgets('pending active-track stream shows loading state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _body(
        _Router(),
        const [],
        firestore: createFakeFirestore(authenticatedUid: 'track-body-test-uid'),
        activeStream: const Stream<List<CurriculumTrackEntity>>.empty(),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('active-track stream error shows a localized retry surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _body(
        _Router(),
        const [],
        firestore: createFakeFirestore(authenticatedUid: 'track-body-test-uid'),
        activeStream: Stream<List<CurriculumTrackEntity>>.error(
          Exception('backend detail'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('backend detail'), findsNothing);
  });

  testWidgets('back affordance and Hebrew body remain available', (
    tester,
  ) async {
    final firestore = createFakeFirestore(
      authenticatedUid: 'track-body-test-uid',
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await tester.pumpWidget(
      _body(
        _Router(),
        [_track()],
        firestore: firestore,
        showBackButton: true,
        locale: const Locale('he'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back affordance invokes the router navigation path', (
    tester,
  ) async {
    final router = _Router();
    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.maybePop<Object?>(isNull),
    ).thenAnswer((_) => Future<bool>.value(true));
    final firestore = createFakeFirestore(
      authenticatedUid: 'track-body-test-uid',
    );
    await seedTrack(
      firestore,
      uid: 'track-body-test-uid',
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await tester.pumpWidget(
      _body(router, [_track()], firestore: firestore, showBackButton: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.arrow_back));
    verify(() => router.maybePop<Object?>(isNull)).called(1);
  });

  testWidgets('order reset action calls the repository', (tester) async {
    final repo = _OrderRepo();
    const item = LearningOrderItem(
      sefariaRef: 'Mishnah 1',
      displayNameHe: 'משנה א',
      displayNameEn: 'Mishnah 1',
      userSortOrder: 0,
    );
    when(() => repo.resetToDefault(any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackLearningOrderRepositoryProvider.overrideWithValue(repo),
          trackSedarimOrderProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => [item]),
          trackMasechtosOrderProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => const []),
          useHebrewTermsProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackLearningOrderScreen(curriculumId: CurriculumId.mishnayos),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DraggableOrderItem), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.text('Reset to Default Order'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pump(const Duration(milliseconds: 200));
    verify(() => repo.resetToDefault(CurriculumId.mishnayos)).called(1);
  });

  testWidgets('reordering sedarim persists the updated order', (tester) async {
    final repo = _OrderRepo();
    const items = [
      LearningOrderItem(
        sefariaRef: 'Seder 1',
        displayNameHe: 'סדר א',
        displayNameEn: 'Seder 1',
        userSortOrder: 0,
      ),
      LearningOrderItem(
        sefariaRef: 'Seder 2',
        displayNameHe: 'סדר ב',
        displayNameEn: 'Seder 2',
        userSortOrder: 1,
      ),
    ];
    when(() => repo.saveSedarimOrder(any(), any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackLearningOrderRepositoryProvider.overrideWithValue(repo),
          trackSedarimOrderProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => items),
          trackMasechtosOrderProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => const []),
          overdueCountForCurriculumProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => 0),
          useHebrewTermsProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackLearningOrderScreen(curriculumId: CurriculumId.mishnayos),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<SliverReorderableList>(
      find.byType(SliverReorderableList),
    );
    list.onReorderItem?.call(0, 1);
    await tester.pump(const Duration(milliseconds: 200));
    verify(() => repo.saveSedarimOrder(any(), any())).called(1);
  });
}
