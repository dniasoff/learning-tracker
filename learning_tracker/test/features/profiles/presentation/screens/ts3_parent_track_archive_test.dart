/// TS-3 regression: Archive (keep history) preserves profile track data.
@Tags(['profiles', 'ts3'])
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
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/point_config.dart';
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

const _uid = 'uid-ts3';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

CurriculumTrackEntity _track(CurriculumId curriculumId) =>
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
}) {
  return pumpApp(
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
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
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

  testWidgets('archive keeps the seeded Firestore goal and stage definitions', (
    tester,
  ) async {
    final router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.maybePop<dynamic>(any<dynamic>()),
    ).thenAnswer((_) async => true);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);

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
    final goalId = await seedGoal(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      description: 'Archive me',
    );
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );

    final profileRef = firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId);
    final stageCollection = profileRef.collection('stage_definitions');
    final stagesBefore = await stageCollection.get();
    final stagesBeforeById = {
      for (final doc in stagesBefore.docs) doc.id: doc.data(),
    };

    // Point-config overrides are configuration-shaped data and are not
    // recreated by archive. Seed one through the production entity codec so
    // the archive transition proves it remains byte-for-byte intact.
    const pointConfig = PointConfigEntity(
      curriculumId: CurriculumId.mishnayos,
      stageOrder: 2,
      points: 17,
    );
    final pointConfigRef = profileRef
        .collection('point_configs')
        .doc(
          DocIds.pointConfigDocId({
            'curriculum_id': CurriculumId.mishnayos.storageKey,
            'stage_order': pointConfig.stageOrder,
          }),
        );
    await pointConfigRef.set(
      pointConfig.toFirestore(updatedAt: DateTime.utc(2026, 1, 1)),
    );
    final pointConfigBefore = (await pointConfigRef.get()).data();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
      ),
    );
    await _settle(tester);
    await tester.longPress(find.byType(LearningTrackCard).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Archive (keep history)'), findsOneWidget);

    await tester.tap(find.text('Archive (keep history)'));
    await tester.pump(const Duration(milliseconds: 500));

    final trackDoc = await firestore
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
    expect(trackDoc.data(), containsPair('state', 'archived'));

    final goalDoc = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('goals')
        .doc(goalId)
        .get();
    expect(goalDoc.exists, isTrue);
    expect(goalDoc.data(), containsPair('description', 'Archive me'));

    final stagesAfter = await stageCollection.get();
    final stagesAfterById = {
      for (final doc in stagesAfter.docs) doc.id: doc.data(),
    };
    expect(stagesAfterById.keys, unorderedEquals(stagesBeforeById.keys));
    for (final entry in stagesBeforeById.entries) {
      final before = entry.value;
      final after = stagesAfterById[entry.key];
      expect(after, equals(before));
      expect(after, containsPair('stage_order', before['stage_order']));
      expect(after, containsPair('stage_name', before['stage_name']));
      expect(after, containsPair('delay_days', before['delay_days']));
    }

    final pointConfigAfter = (await pointConfigRef.get()).data();
    expect(pointConfigAfter, equals(pointConfigBefore));
    await _teardown(tester);
  });
}
