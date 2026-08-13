/// Unit tests for [FirestoreCompletionPointsAwarder] — the Firestore-backed
/// [CompletionPointsPort] implementation `CompletionOrchestrator` is wired
/// against today.
///
/// Replaces the Drift-era `DriftCompletionPointsAwarder` test file (removed:
/// that class, `UserDatabase`, and `SyncWriteFacade` no longer exist —
/// `docs/firestore-rewrite-map.md`, owner decision 1). This file focuses on
/// `calculatePoints`' point-value branch (D-E, `docs/planning/phase3-wave-
/// plan.md`'s point_configs restoration spec):
///   Branch A — `firestorePointConfigRepositoryProvider` resolves null: THROW.
///   Branch B — resolved, no override document: fall back to the ladder.
///   configured — resolved, override document present: return it.
/// plus the pre-existing child-profile / reward-eligibility gates.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_points_awarder.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

import '../../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

/// [FirestoreCompletionPointsAwarder] takes a [Ref], not a [WidgetRef] or a
/// bare [ProviderContainer] — wrapping it in a top-level provider and
/// reading it back is the established pattern for handing a real `Ref` to a
/// `Ref`-only constructor from a test (mirrors
/// `firestore_streak_state_repository_test.dart`'s `adapterProvider`).
final _awarderProvider = Provider<FirestoreCompletionPointsAwarder>(
  (ref) => FirestoreCompletionPointsAwarder(ref: ref),
);

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  Future<void> seedProfile({required ProfileMode mode}) async {
    final now = DateTimeFactory.nowUtc();
    final profile = LearnerProfileEntity(
      profileId: _profileId,
      displayName: 'Test',
      mode: mode,
      createdAt: now,
      updatedAt: now,
    );
    await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .set(profile.toFirestore());
  }

  Future<void> seedGoal(CurriculumId curriculumId) async {
    await FirestoreGoalRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    ).createGoal(curriculumId: curriculumId, targetPercent: 100);
  }

  /// Builds a real [FirestoreCompletionPointsAwarder] wired against
  /// [firestore], with `firestorePointConfigRepositoryProvider` overridden
  /// to [pointConfigRepo] (pass `null` to exercise Branch A) and
  /// `firestoreGoalRepositoryProvider` overridden to [goalRepo] (defaults
  /// to the real repository against the same fake instance).
  FirestoreCompletionPointsAwarder buildAwarder({
    FirestorePointConfigRepository? Function()? pointConfigRepo,
    FirestoreGoalRepository? Function()? goalRepo,
    bool pointConfigRepoNotReady = false,
    bool goalRepoNotReady = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        firestoreLearnerProfileRepositoryProvider.overrideWith(
          (ref) async => FirestoreLearnerProfileRepository(
            firestore: firestore,
            uid: _uid,
          ),
        ),
        firestoreGoalRepositoryProvider.overrideWith(
          (ref) async =>
              goalRepoNotReady
                  ? null
                  : goalRepo?.call() ??
                      FirestoreGoalRepository(
                        firestore: firestore,
                        uid: _uid,
                        profileId: _profileId,
                      ),
        ),
        firestorePointConfigRepositoryProvider.overrideWith(
          (ref) async =>
              pointConfigRepoNotReady
                  ? null
                  : pointConfigRepo?.call() ??
                      FirestorePointConfigRepository(
                        firestore: firestore,
                        uid: _uid,
                        profileId: _profileId,
                      ),
        ),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    addTearDown(container.dispose);
    return container.read(_awarderProvider);
  }

  group('calculatePoints — gates', () {
    test('returns 0 for an adult profile — points are child-only', () async {
      await seedProfile(mode: ProfileMode.adult);
      await seedGoal(CurriculumId.mishnayos);
      final awarder = buildAwarder();

      final points = await awarder.calculatePoints(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
        profileId: _profileId,
      );

      expect(points, 0);
    });

    test('returns 0 for a child profile with no goal for the curriculum '
        '(not reward-eligible)', () async {
      await seedProfile(mode: ProfileMode.child);
      final awarder = buildAwarder();

      final points = await awarder.calculatePoints(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
        profileId: _profileId,
      );

      expect(points, 0);
    });
  });

  group('calculatePoints — point value (D-E)', () {
    test('returns the default fallback ladder (10/5/3/1) for an eligible '
        'child when no point_configs override exists', () async {
      await seedProfile(mode: ProfileMode.child);
      await seedGoal(CurriculumId.mishnayos);
      final awarder = buildAwarder();

      final points = <int, int>{};
      for (final stageOrder in [1, 2, 3, 4]) {
        points[stageOrder] = await awarder.calculatePoints(
          curriculumId: CurriculumId.mishnayos.storageKey,
          stageOrder: stageOrder,
          profileId: _profileId,
        );
      }

      expect(points[1], 10, reason: 'Learn');
      expect(points[2], 5, reason: 'Chazara 1');
      expect(points[3], 3, reason: 'Chazara 2');
      expect(points[4], 1, reason: 'any additional stage');
    });

    test('returns the configured point_configs override, not the ladder', () async {
      await seedProfile(mode: ProfileMode.child);
      await seedGoal(CurriculumId.mishnayos);
      await FirestorePointConfigRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ).upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 99,
      );
      final awarder = buildAwarder();

      final points = await awarder.calculatePoints(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
        profileId: _profileId,
      );

      expect(points, 99);
    });

    test(
      'Branch A: THROWS instead of silently falling back to the ladder '
      'when the point_configs repository resolves to null — a not-ready '
      'backend is contradictory here (an active account/profile is '
      'provably present), not "no override configured"',
      () async {
        await seedProfile(mode: ProfileMode.child);
        await seedGoal(CurriculumId.mishnayos);
        final awarder = buildAwarder(pointConfigRepoNotReady: true);

        expect(
          () => awarder.calculatePoints(
            curriculumId: CurriculumId.mishnayos.storageKey,
            stageOrder: 1,
            profileId: _profileId,
          ),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test(
      'Branch A (goal repository): THROWS when the goal repository '
      'resolves to null, same reasoning as the point_configs branch',
      () async {
        await seedProfile(mode: ProfileMode.child);
        final awarder = buildAwarder(goalRepoNotReady: true);

        expect(
          () => awarder.calculatePoints(
            curriculumId: CurriculumId.mishnayos.storageKey,
            stageOrder: 1,
            profileId: _profileId,
          ),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });
}
