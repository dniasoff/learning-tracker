/// Small Firestore-native fixtures for tests during the Drift migration.
///
/// These helpers deliberately write the same raw document shapes used by the
/// Firestore repositories. They keep test setup independent of the archived
/// Drift database while leaving the repository tests free to use their normal
/// loose `FakeFirebaseFirestore` setup.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/points_ledger_entry.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

final _defaultFixtureTime = DateTime.utc(2026, 1, 1, 12);

DateTime _fixtureTime(DateTime? value) => value ?? _defaultFixtureTime;

/// Seeds the account document at `users/{uid}`.
///
/// Accounts are scoped directly by the Firebase uid, so this fixture has no
/// profile-id parameter. The document body comes from [AccountEntity] rather
/// than duplicating its timestamp and field-name conventions here.
Future<void> seedAccount(
  FakeFirebaseFirestore firestore, {
  required String uid,
  String? email = 'test@example.com',
  String displayName = 'Test User',
  DateTime? createdAt,
  DateTime? updatedAt,
}) async {
  final account = AccountEntity(
    uid: uid,
    email: email,
    displayName: displayName,
    createdAt: _fixtureTime(createdAt),
    updatedAt: _fixtureTime(updatedAt ?? createdAt),
  );
  await firestore.collection('users').doc(uid).set(account.toFirestore());
}

/// Seeds `users/{uid}/learner_profiles/{profileId}` with a ULID profile id.
///
/// [profileId] is the document identity (AD-24); it is intentionally not
/// copied into the payload. This mirrors [FirestoreLearnerProfileRepository]
/// and prevents Drift-era integer identity from entering new fixtures.
Future<void> seedProfile(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  String displayName = 'Test User',
  ProfileMode mode = ProfileMode.adult,
  String avatar = '',
  DateTime? createdAt,
  DateTime? updatedAt,
}) async {
  final profile = LearnerProfileEntity(
    profileId: profileId,
    displayName: displayName,
    mode: mode,
    avatar: avatar,
    createdAt: _fixtureTime(createdAt),
    updatedAt: _fixtureTime(updatedAt ?? createdAt),
  );
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .set(profile.toFirestore());
}

/// Seeds one curriculum track at the canonical curriculum-id document id.
///
/// Track identity is [curriculumId] within the profile path. The default
/// state and timestamp match the repository's [activateTrack] write shape;
/// callers can override them when a test needs a retired or archived track.
Future<void> seedTrack(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required CurriculumId curriculumId,
  String state = 'active',
  DateTime? activatedAt,
}) async {
  final track = CurriculumTrackEntity(
    curriculumId: curriculumId,
    state: state,
    activatedAt: _fixtureTime(activatedAt),
  );
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('curriculum_tracks')
      .doc(
        DocIds.curriculumTrackDocId({'curriculum_id': curriculumId.storageKey}),
      )
      .set(track.toFirestore());
}

/// Seeds the profile's current bookmark for [curriculumId].
Future<void> seedBookmark(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required CurriculumId curriculumId,
  String? sefariaRef,
  DateTime? updatedAt,
}) async {
  final data = <String, dynamic>{
    'profile_id': profileId,
    'curriculum_id': curriculumId.storageKey,
    'updated_at': _fixtureTime(updatedAt).toIso8601String(),
    if (sefariaRef != null) 'sefaria_ref': sefariaRef,
  };
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('bookmarks')
      .doc(DocIds.bookmarkDocId(data))
      .set(data);
}

/// Seeds one goal and returns its deterministic Firestore document id.
///
/// Goal documents use the entity's `(curriculumId, createdAt)`-based natural
/// id. Returning that id lets a test read the exact document without
/// reimplementing the formula in its own setup code.
Future<String> seedGoal(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required CurriculumId curriculumId,
  DateTime? targetDate,
  String description = 'Test goal',
  String dateType = 'gregorian',
  String goalType = 'none',
  int? paceValue,
  String? pacePeriod,
  PaceGranularity? paceGranularity,
  String? rawLearningUnit,
  DateTime? createdAt,
}) async {
  final goal = GoalEntity(
    curriculumId: curriculumId,
    targetDate: targetDate,
    description: description,
    dateType: dateType,
    goalType: goalType,
    paceValue: paceValue,
    pacePeriod: pacePeriod,
    paceGranularity: paceGranularity,
    rawLearningUnit: rawLearningUnit,
    createdAt: _fixtureTime(createdAt),
  );
  final docId = goal.firestoreId;
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('goals')
      .doc(docId)
      .set(goal.toFirestore());
  return docId;
}

/// Seeds the supplied stage definitions, or the repository's three defaults
/// (לימוד/0, חזרה א׳/1, חזרה ב׳/7 — byte-identical to
/// `FirestoreStageDefinitionRepository`'s own `_defaultStages`, so a test
/// relying on the built-in defaults exercises the SAME due-date math
/// (`delayDays`) the real app computes, not a fictional schedule).
///
/// The [StageDefinition.id] value is decode-only legacy baggage and is never
/// written. Firestore identity is `(curriculumId, stageOrder)`, so callers
/// provide definitions by entity shape while this helper uses [DocIds] for
/// every document path. A batch mirrors the repository's initialization write.
Future<void> seedStageDefinitions(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required CurriculumId curriculumId,
  List<StageDefinition>? stages,
}) async {
  final definitions =
      stages ??
      [
        for (final stage in [
          (1, kLimudStageName, 0),
          (2, 'חזרה א׳', 1),
          (3, 'חזרה ב׳', 7),
        ])
          StageDefinition(
            curriculumId: curriculumId,
            stageOrder: stage.$1,
            stageName: stage.$2,
            delayDays: stage.$3,
            isDefault: true,
            scheduleType: ScheduleType.delay,
          ),
      ];
  final batch = firestore.batch();
  for (final definition in definitions) {
    if (definition.curriculumId != curriculumId) {
      throw ArgumentError(
        'Every stage definition must use the seed curriculumId',
      );
    }
    batch.set(
      firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileId)
          .collection('stage_definitions')
          .doc(
            DocIds.stageDefinitionDocId({
              'curriculum_id': curriculumId.storageKey,
              'stage_order': definition.stageOrder,
            }),
          ),
      definition.toFirestore(),
    );
  }
  await batch.commit();
}

/// Seeds one append-only points-ledger entry at
/// `users/{uid}/learner_profiles/{profileId}/points_ledger/{ulid}`.
///
/// [ulid] is the entry's real identity and Firestore document id. [delta] is
/// the signed amount applied to the derived balance; [entryKind] defaults to
/// the parent adjustment kind used for a starting balance. Optional
/// [note]/[redemptionUlid] values are encoded only when supplied, matching
/// [PointsLedgerEntry.toFirestore].
Future<void> seedPointsLedgerEntry(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required String ulid,
  String entryKind = 'parent_add',
  required int delta,
  String? note,
  String? redemptionUlid,
  DateTime? createdAt,
  CompletionSource source = CompletionSource.live,
}) async {
  final entry = PointsLedgerEntry(
    ulid: ulid,
    entryKind: entryKind,
    delta: delta,
    note: note,
    redemptionUlid: redemptionUlid,
    createdAt: _fixtureTime(createdAt),
    source: source,
  );
  final docId = DocIds.pointsLedgerDocId({'ulid': ulid})!;
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('points_ledger')
      .doc(docId)
      .set(entry.toFirestore());
}

/// Seeds one reward-redemption request at
/// `users/{uid}/learner_profiles/{profileId}/reward_redemptions/{ulid}`.
///
/// [status] uses the repository's state-machine values:
/// [RewardRedemptionStatus.pendingFulfilment],
/// [RewardRedemptionStatus.fulfilled], or
/// [RewardRedemptionStatus.declined]. [resolvedAt] is optional so pending
/// fixtures match the production create shape while resolved fixtures can
/// mirror the parent's fulfil/decline update.
Future<void> seedRewardRedemption(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required String ulid,
  String rewardTitle = 'Test Reward',
  int iconIndex = 0,
  int pointsCost = 10,
  String status = RewardRedemptionStatus.pendingFulfilment,
  DateTime? createdAt,
  DateTime? resolvedAt,
}) async {
  final redemption = RewardRedemptionEntity(
    ulid: ulid,
    rewardTitle: rewardTitle,
    iconIndex: iconIndex,
    pointsCost: pointsCost,
    status: status,
    createdAt: _fixtureTime(createdAt),
    resolvedAt: resolvedAt,
  );
  final docId = DocIds.rewardRedemptionDocId({'ulid': ulid})!;
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('reward_redemptions')
      .doc(docId)
      .set(redemption.toFirestore());
}
