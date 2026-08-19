import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'uid-lifecycle-test';
const _profileId = 'profile-ulid-lifecycle-test';

class _NoOpBookmarkRepository extends Fake implements BookmarkRepository {
  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {}
}

class _NoOpCompletionRepository extends Fake implements CompletionRepository {}

class _NoOpContentRepository extends Fake implements ContentRepository {}

class _NoOpLearningLedgerRepository extends Fake
    implements LearningLedgerRepository {}

class _NoOpDetectionService extends CompletionDetectionService {
  _NoOpDetectionService()
    : super(
        completionRepository: _NoOpCompletionRepository(),
        contentRepository: _NoOpContentRepository(),
        ledgerRepository: _NoOpLearningLedgerRepository(),
      );

  @override
  Future<void> checkAndRecordCompletions({
    required String curriculumId,
    required String sefariaRef,
    required String trackType,
    int? trackId,
    CompletionSource source = CompletionSource.live,
    bool includeUnitLevelCheck = true,
    bool includeAggregateLevelCheck = true,
  }) async {}
}

Future<void> _seedChildProfileAndGoal(FakeFirebaseFirestore firestore) async {
  final now = DateTimeFactory.nowUtc();
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .set(
        LearnerProfileEntity(
          profileId: _profileId,
          displayName: 'Lifecycle test child',
          mode: ProfileMode.child,
          createdAt: now,
          updatedAt: now,
        ).toFirestore(),
      );

  await FirestoreGoalRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  ).createGoal(curriculumId: CurriculumId.mishnayos, targetPercent: 100);
}

void main() {
  test(
    'one-shot mark completion survives an async gap and writes to Firestore',
    () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      await _seedChildProfileAndGoal(firestore);

      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          analyticsServiceProvider.overrideWithValue(
            const NullAnalyticsService(),
          ),
          contentRepositoryProvider.overrideWithValue(_NoOpContentRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            _NoOpBookmarkRepository(),
          ),
          learningLedgerRepositoryProvider.overrideWithValue(
            _NoOpLearningLedgerRepository(),
          ),
          completionDetectionServiceProvider.overrideWithValue(
            _NoOpDetectionService(),
          ),
          firestoreCompletionRepositoryProvider.overrideWith(
            (ref) async => FirestoreCompletionRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestoreLearnerProfileRepositoryProvider.overrideWith(
            (ref) async => FirestoreLearnerProfileRepository(
              firestore: firestore,
              uid: _uid,
            ),
          ),
          firestoreGoalRepositoryProvider.overrideWith(
            (ref) async => FirestoreGoalRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestorePointConfigRepositoryProvider.overrideWith(
            (ref) async => FirestorePointConfigRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestorePointsLedgerRepositoryProvider.overrideWith(
            (ref) async => FirestorePointsLedgerRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestoreStreakEventRepositoryProvider.overrideWith(
            (ref) async => FirestoreStreakEventRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeProfileDocIdProvider.notifier).set(_profileId);

      // This is intentionally a one-shot read: no listener is retained while
      // the completion awaits its Firestore round-trip.
      final markCompletion = container.read(markCompletionUseCaseProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final result = await markCompletion(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah_Berakhot.1.1',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      expect(result.isNew, isTrue);
      final completions = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('completions')
          .get();
      expect(completions.docs, hasLength(1));
      expect(completions.docs.single.data()['points'], 10);

      final pointsLedger = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('points_ledger')
          .get();
      expect(pointsLedger.docs, hasLength(1));
      expect(pointsLedger.docs.single.data()['delta'], 10);
    },
  );
}
