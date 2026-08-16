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
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
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
  DateTime? stateChangedAt,
  DateTime? paceResetDate,
}) async {
  final track = CurriculumTrackEntity(
    curriculumId: curriculumId,
    state: state,
    stateChangedAt: _fixtureTime(stateChangedAt ?? activatedAt),
    activatedAt: _fixtureTime(activatedAt),
    paceResetDate: paceResetDate,
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

/// Seeds one immutable completion in the profile's `completions` collection.
///
/// The document id is derived by [DocIds.completionDocIdForProfile], exactly
/// as [FirestoreCompletionRepository] derives it. [completedAt] stays a raw
/// [DateTime] because the Firestore rules require a timestamp, not an ISO
/// string. Returns the doc-id so a caller can read the exact document back
/// without re-deriving the formula itself.
///
/// [source] rejects [CompletionSource.lifetimeOnly] — [FirestoreCompletion
/// Repository.recordCompletion] throws on it too (a lifetimeOnly mark writes
/// only a `learning_ledger` entry, via [seedLedgerEntry], never a
/// `completions` document), so seeding one here would write a document no
/// production path can create.
Future<String> seedCompletion(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  CurriculumId curriculumId = CurriculumId.mishnayos,
  String sefariaRef = 'Mishnah 1',
  int stageId = 1,
  String trackType = 'personal',
  CompletionSource source = CompletionSource.live,
  DateTime? completedAt,
  int points = 0,
  DateTime? purgedAt,
}) async {
  if (source == CompletionSource.lifetimeOnly) {
    throw ArgumentError(
      'CompletionSource.lifetimeOnly must never be written to the '
      'completions collection — use seedLedgerEntry instead (see '
      'FirestoreCompletionRepository.recordCompletion\'s matching guard).',
    );
  }
  final completion = CompletionEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: trackType,
    source: source,
    completedAt: _fixtureTime(completedAt),
    points: points,
    purgedAt: purgedAt,
  );
  final docId = DocIds.completionDocIdForProfile(
    profileId,
    completion.toFirestore(),
  );
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('completions')
      .doc(docId)
      .set(completion.toFirestore());
  return docId;
}

/// Seeds one append-only learning-ledger entry at `learning_ledger/{ulid}`.
///
/// [ulid] is required because it is the entry's real identity and doc-id;
/// this helper does not mint or substitute an integer id. [markedBy] defaults
/// to the profile ULID because that is the current profile identity field.
Future<void> seedLedgerEntry(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required String ulid,
  CurriculumId curriculumId = CurriculumId.mishnayos,
  String entryScope = 'masechta',
  String unitIdentifier = 'unit-1',
  String unitDisplayNameHe = 'שם',
  String unitDisplayNameEn = 'Unit 1',
  String trackType = 'personal',
  DateTime? completedAt,
  int completionNumber = 1,
  String? markedBy,
  bool isManual = false,
  CompletionSource source = CompletionSource.live,
  DateTime? purgedAt,
}) async {
  final entry = LearningLedgerEntry(
    ulid: ulid,
    curriculumId: curriculumId,
    entryScope: entryScope,
    unitIdentifier: unitIdentifier,
    unitDisplayNameHe: unitDisplayNameHe,
    unitDisplayNameEn: unitDisplayNameEn,
    trackType: trackType,
    completedAt: _fixtureTime(completedAt),
    completionNumber: completionNumber,
    markedBy: markedBy ?? profileId,
    isManual: isManual,
    source: source,
    purgedAt: purgedAt,
  );
  // [ulid] is `required`, so DocIds.learningLedgerDocId's nullable-payload
  // fallback is never reached — force-unwrapped into a local rather than
  // inline, matching FirestoreLearningLedgerRepository._doc's own discipline
  // (`.doc()` itself silently accepts null, falling back to a random id,
  // which would break this collection's append-only idempotency).
  final docId = DocIds.learningLedgerDocId({'ulid': ulid})!;
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('learning_ledger')
      .doc(docId)
      .set(entry.toFirestore());
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
  double targetPercent = 100,
  DateTime? targetDate,
  String description = 'Test goal',
  String dateType = 'gregorian',
  String goalType = 'none',
  int? paceValue,
  String? pacePeriod,
  PaceGranularity? paceGranularity,
  String? rawLearningUnit,
  DateTime? createdAt,
  DateTime? updatedAt,
}) async {
  final goal = GoalEntity(
    curriculumId: curriculumId,
    targetPercent: targetPercent,
    targetDate: targetDate,
    description: description,
    dateType: dateType,
    goalType: goalType,
    paceValue: paceValue,
    pacePeriod: pacePeriod,
    paceGranularity: paceGranularity,
    rawLearningUnit: rawLearningUnit,
    createdAt: _fixtureTime(createdAt),
    updatedAt: _fixtureTime(updatedAt ?? createdAt),
  );
  final docId = DocIds.goalDocId({'id': goal.firestoreId});
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

/// Seeds one curriculum bookmark at the canonical curriculum-id doc-id.
Future<void> seedBookmark(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String profileId,
  required CurriculumId curriculumId,
  String sefariaRef = 'Mishnah 1',
  DateTime? updatedAt,
}) async {
  final bookmark = BookmarkEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    updatedAt: _fixtureTime(updatedAt),
  );
  await firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('bookmarks')
      .doc(DocIds.bookmarkDocId({'curriculum_id': curriculumId.storageKey}))
      .set(bookmark.toFirestore());
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
  DateTime? updatedAt,
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
  final timestamp = _fixtureTime(updatedAt);
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
      definition.toFirestore(updatedAt: timestamp),
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
