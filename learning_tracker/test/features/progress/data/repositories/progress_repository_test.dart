import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_progress_repository_adapter.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'progress-repository-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreProgressRepositoryAdapter repository;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    final handles = AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );
    container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => handles),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    final adapterProvider = Provider<FirestoreProgressRepositoryAdapter>(
      (ref) => FirestoreProgressRepositoryAdapter(ref: ref),
    );
    repository = container.read(adapterProvider);
  });

  tearDown(() => container.dispose());

  Future<void> seedCompletionFor(
    CurriculumId curriculum,
    String sefariaRef, {
    int stageId = 1,
    String trackType = 'personal',
    CompletionSource source = CompletionSource.live,
    int points = 10,
  }) async {
    await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      source: source,
      completedAt: DateTime.utc(2026, 1, 1),
      points: points,
    );
  }

  group('ProgressRepository', () {
    group('getTrackBreakdown', () {
      test('returns Map<String, int> with correct counts per track', () async {
        await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
        await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2b');
        await seedCompletionFor(CurriculumId.bavli, 'Berakhot.3a');

        final breakdown = await repository.getTrackBreakdown('bavli');

        expect(breakdown['personal'], 3);
      });

      test(
        'returns zero counts for inactive tracks that have no completions',
        () async {
          await seedTrack(
            firestore,
            uid: _uid,
            profileId: _profileId,
            curriculumId: CurriculumId.bavli,
            state: CurriculumTrackState.retired.storageKey,
          );
          await seedProfile(firestore, uid: _uid, profileId: _profileId);

          final breakdown = await repository.getTrackBreakdown('bavli');
          final tracks = await repository.getAllTracks();

          expect(tracks.single.state, CurriculumTrackState.retired.storageKey);
          expect(breakdown, isEmpty);
        },
      );

      test(
        'includes completions from deactivated tracks (data preserved)',
        () async {
          await seedTrack(
            firestore,
            uid: _uid,
            profileId: _profileId,
            curriculumId: CurriculumId.bavli,
            state: CurriculumTrackState.archived.storageKey,
          );
          await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
          await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2b');

          final breakdown = await repository.getTrackBreakdown('bavli');
          final tracks = await repository.getAllTracks();

          expect(tracks.single.state, CurriculumTrackState.archived.storageKey);
          expect(breakdown['personal'], 2);
        },
      );

      test('returns empty breakdown when no completions exist', () async {
        await seedProfile(firestore, uid: _uid, profileId: _profileId);

        final breakdown = await repository.getTrackBreakdown('bavli');

        expect(breakdown, isEmpty);
      });

      test('filters by curriculum correctly', () async {
        await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
        await seedCompletionFor(CurriculumId.mishnayos, 'Berakhot.1.1');

        final bavliBreakdown = await repository.getTrackBreakdown('bavli');
        final mishnaBreakdown = await repository.getTrackBreakdown('mishnayos');

        expect(bavliBreakdown['personal'], 1);
        expect(mishnaBreakdown['personal'], 1);
      });
    });

    group('getAggregateCount', () {
      test(
        'returns sum across all tracks, matching individual track counts',
        () async {
          await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
          await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2b');
          await seedCompletionFor(CurriculumId.bavli, 'Berakhot.3a');

          final breakdown = await repository.getTrackBreakdown('bavli');
          final aggregate = await repository.getAggregateCount('bavli');
          final expectedTotal = breakdown.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );

          expect(aggregate, expectedTotal);
          expect(aggregate, 3);
        },
      );

      test('returns 0 when no completions exist', () async {
        await seedProfile(firestore, uid: _uid, profileId: _profileId);

        final aggregate = await repository.getAggregateCount('bavli');

        expect(aggregate, 0);
      });

      test('filters by curriculum correctly', () async {
        await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
        await seedCompletionFor(CurriculumId.mishnayos, 'Berakhot.1.1');

        final bavliCount = await repository.getAggregateCount('bavli');
        final mishnaCount = await repository.getAggregateCount('mishnayos');

        expect(bavliCount, 1);
        expect(mishnaCount, 1);
      });
    });

    group('getCompletionsByCurriculum', () {
      test('returns CompletionEntity records scoped to the curriculum and '
          'profile', () async {
        await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
        await seedCompletionFor(
          CurriculumId.mishnayos,
          'Berakhot.1.1',
          points: 5,
        );

        final completions = await repository.getCompletionsByCurriculum(
          'bavli',
        );

        expect(completions, hasLength(1));
        expect(completions.single.sefariaRef, 'Berakhot.2a');
        expect(completions.single.curriculumId, CurriculumId.bavli);
        expect(completions.single.points, 10);
      });

      test('returns an empty list when no completions exist', () async {
        await seedProfile(firestore, uid: _uid, profileId: _profileId);

        final completions = await repository.getCompletionsByCurriculum(
          'bavli',
        );
        expect(completions, isEmpty);
      });
    });

    group('getAllCompletions', () {
      test(
        'returns CompletionEntity records across every curriculum',
        () async {
          await seedCompletionFor(CurriculumId.bavli, 'Berakhot.2a');
          await seedCompletionFor(
            CurriculumId.mishnayos,
            'Berakhot.1.1',
            points: 5,
          );

          final completions = await repository.getAllCompletions();

          expect(completions, hasLength(2));
          expect(
            completions.map((c) => c.sefariaRef),
            containsAll(['Berakhot.2a', 'Berakhot.1.1']),
          );
        },
      );

      test('returns an empty list when no completions exist', () async {
        await seedProfile(firestore, uid: _uid, profileId: _profileId);

        final completions = await repository.getAllCompletions();
        expect(completions, isEmpty);
      });
    });
  });
}
