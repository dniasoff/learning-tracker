/// Firestore-native L1 coverage for ParentTrackManagementScreen.
@Tags(['profiles', 'parent_track_management'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FixedActiveProfileDocId extends ActiveProfileDocId {
  _FixedActiveProfileDocId(this._id);
  final String _id;

  @override
  String? build() => _id;
}

const _uid = 'uid-parent-track-management';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

CurriculumTrackEntity _track({required CurriculumId curriculumId}) =>
    CurriculumTrackEntity(
      curriculumId: curriculumId,
      state: 'active',
      stateChangedAt: DateTime.utc(2026, 1, 1),
      activatedAt: DateTime.utc(2026, 1, 1),
    );

List<Override> _perTrackOverrides(List<CurriculumTrackEntity> tracks) => [
  dashboardActiveCurriculaProvider.overrideWith(
    (ref) async => tracks.map((track) => track.curriculumId).toList(),
  ),
  for (final track in tracks) ...[
    dashboardTrackCompletionPercentageProvider(
      track.curriculumId,
    ).overrideWith((ref) async => 0.0),
    trackHasChazaraProvider(
      track.curriculumId,
    ).overrideWith((ref) async => false),
  ],
  dashboardHasProgramEnrollmentProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) async => false),
];

Widget _buildApp({
  required _MockStackRouter router,
  required FakeFirebaseFirestore firestore,
  required List<CurriculumTrackEntity> tracks,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Stream<List<CurriculumTrackEntity>>? tracksStream,
  bool useFirestoreTracks = false,
}) {
  return pumpApp(
    locale: locale,
    theme: theme,
    overrides: [
      activeProfileIdProvider.overrideWithValue(_profileId),
      activeProfileDocIdProvider.overrideWith(
        () => _FixedActiveProfileDocId(_profileId),
      ),
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => AccountFirebaseHandles(
          app: _MockFirebaseApp(),
          firestore: firestore,
          auth: _MockFirebaseAuth(),
          uid: _uid,
        ),
      ),
      curriculumTrackRepositoryAdapterProvider.overrideWith(
        (ref) => FirestoreCurriculumTrackRepositoryAdapter(
          ref: ref,
          functions: _MockFirebaseFunctions(),
        ),
      ),
      if (!useFirestoreTracks)
        activeTracksProvider.overrideWith(
          (ref) => tracksStream ?? Stream.value(tracks),
        ),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    ],
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const ParentTrackManagementScreen(),
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

  testWidgets('empty state shows heading and Add Track action', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: const []),
    );
    await _settle(tester);
    expect(find.text('No active tracks'), findsOneWidget);
    expect(find.text('Add Track'), findsOneWidget);
    expect(find.text('ADD TRACK'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('populated state shows active track and count', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final track = _track(curriculumId: CurriculumId.mishnayos);
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: [track]),
    );
    await _settle(tester);
    expect(find.text('Active Tracks'), findsOneWidget);
    expect(find.textContaining('1 RUNNING'), findsOneWidget);
    expect(find.text('ADD TRACK'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('last active curriculum offers Cancel only', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    final track = _track(curriculumId: CurriculumId.mishnayos);
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tracks: [track],
        useFirestoreTracks: true,
      ),
    );
    await _settle(tester);
    await tester.longPress(find.byType(LearningTrackCard).first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Archive (keep history)'), findsNothing);
    expect(find.text('Delete and wipe history'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await _teardown(tester);
  });

  testWidgets('empty state Add Track action opens the add-track flow', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: const []),
    );
    await _settle(tester);
    await tester.tap(find.text('Add Track'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No active tracks'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('populated screen navigation and Add Track FAB are wired', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final track = _track(curriculumId: CurriculumId.mishnayos);
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: [track]),
    );
    await _settle(tester);
    expect(find.text('ADD TRACK'), findsOneWidget);

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await tester.tap(find.text('ADD TRACK'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tracks & Goals'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('cancel leaves a seeded active track unchanged', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    final track = _track(curriculumId: CurriculumId.mishnayos);
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tracks: [track],
        tracksStream: Stream.value([track]),
      ),
    );
    await _settle(tester);
    await tester.longPress(find.byType(LearningTrackCard).first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('curriculum_tracks')
        .doc(
          DocIds.curriculumTrackDocId({
            'curriculum_id': CurriculumId.mishnayos.storageKey,
          }),
        )
        .get();
    expect(snapshot.data(), containsPair('state', 'active'));

    // Cancel must be a pure UI dismissal. Read the separately-seeded Bavli
    // track too so this test proves the action did not mutate any sibling
    // curriculum, rather than leaving that fixture dead.
    final bavliSnapshot = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('curriculum_tracks')
        .doc(
          DocIds.curriculumTrackDocId({
            'curriculum_id': CurriculumId.bavli.storageKey,
          }),
        )
        .get();
    expect(bavliSnapshot.data(), containsPair('state', 'active'));
    await _teardown(tester);
  });

  testWidgets('error state renders an error view without a FAB', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tracks: const [],
        tracksStream: Stream<List<CurriculumTrackEntity>>.error(
          StateError('track read failed'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('ADD TRACK'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('archive changes the seeded Firestore track state', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    final track = _track(curriculumId: CurriculumId.mishnayos);
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: [track]),
    );
    await _settle(tester);
    await tester.longPress(find.byType(LearningTrackCard).first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Archive (keep history)'));
    await tester.pump(const Duration(milliseconds: 300));

    final snapshot = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('curriculum_tracks')
        .doc(
          DocIds.curriculumTrackDocId({
            'curriculum_id': CurriculumId.mishnayos.storageKey,
          }),
        )
        .get();
    expect(snapshot.data(), containsPair('state', 'archived'));
    await _teardown(tester);
  });

  // Possible production gap: deleteCurriculumTrack is Cloud-Function-owned;
  // the local fake cannot execute that callable. Restore with emulator cover.
  testWidgets(
    'permanent wipe remains a Cloud Function-owned operation',
    (tester) async {},
    skip: true,
  );

  testWidgets('loading state renders without throwing', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          activeProfileDocIdProvider.overrideWith(
            () => _FixedActiveProfileDocId(_profileId),
          ),
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => AccountFirebaseHandles(
              app: _MockFirebaseApp(),
              firestore: firestore,
              auth: _MockFirebaseAuth(),
              uid: _uid,
            ),
          ),
          activeTracksProvider.overrideWith(
            (ref) => const Stream<List<CurriculumTrackEntity>>.empty(),
          ),
          useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
        ],
        child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const ParentTrackManagementScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('Hebrew locale renders without overflow', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tracks: [_track(curriculumId: CurriculumId.mishnayos)],
        locale: const Locale('he'),
      ),
    );
    await _settle(tester);
    expect(find.byType(Scaffold), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('Hebrew and dark mode preserve localized track UI', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final track = _track(curriculumId: CurriculumId.mishnayos);
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tracks: [track],
        locale: const Locale('he'),
        theme: AppTheme.darkTheme(),
      ),
    );
    await _settle(tester);
    expect(find.text('מסלולים פעילים'), findsOneWidget);
    expect(find.textContaining('RUNNING'), findsNothing);
    final onAccent = AppTheme.darkTheme().colorScheme.onPrimary;
    expect(onAccent, isNot(Colors.white));
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .foregroundColor,
      onAccent,
    );
    await _teardown(tester);
  });
}
