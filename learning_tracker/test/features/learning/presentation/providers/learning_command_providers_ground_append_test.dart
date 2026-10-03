// Story 2.7 (DNI-498): a ground-picker append through the production
// `learningCommandsProvider` graph, over the real
// `FirestoreSubTrackRepository` (no latest-write fake). The provider must
// wire `SubTrackCommands` and its sub-track adapter must forward
// `SubTrackLatestWrite`, or every online "Use as ground" answers
// onlineRequired and rolls back.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/sub_tracks/merge_transaction_firestore.dart';

const _peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');

final class _FixedPoints implements PointsAmountReader {
  @override
  Future<int> pointsAmount(LearnerScope s, String c, int? stage) async => 7;
}

Map<String, Object?> _school({List<Map<String, String>> ground = const []}) => {
  'curriculum_id': engineCurriculum,
  'name': 'School',
  'type': 'ongoing',
  'window_start': '2026-09-01',
  'rate_per_week': 10,
  'weeks_per_year': 39,
  'learns_on_shabbos': false,
  'ground': ground,
  'last_change_id': ulidE,
};

void main() {
  final scope = c0Scope();
  late MergeTransactionFirestore firestore;
  late FirestoreSubTrackRepository repo;
  late InMemoryGovernedIntentRepository intent;

  List<Override> ready({required SubTrackRepository subTracks}) => [
    learningCommandClockProvider.overrideWithValue(() => engineAt(600)),
    activeLearnerScopeProvider.overrideWith((ref) async => scope),
    activeAuthUidProvider.overrideWith((ref) async => 'auth-uid'),
    learningWritePortProvider.overrideWith(
      (ref) async => InMemoryLearningWritePort(),
    ),
    changeLogRepositoryProvider.overrideWith(
      (ref) async => InMemoryChangeLogRepository(),
    ),
    governedDocReaderProvider.overrideWith(
      (ref) async => InMemoryChangeLogRepository(),
    ),
    oversizedGovernedWritePortProvider.overrideWith(
      (ref) async => FakeOversizedGovernedWritePort(),
    ),
    pointsAmountReaderProvider.overrideWith((ref) async => _FixedPoints()),
    learningEventRepositoryProvider.overrideWith(
      (ref) async => InMemoryLearningEventRepository(),
    ),
    subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
    governedIntentRepositoryProvider.overrideWith((ref) async => intent),
    activeProfileProvider.overrideWith(
      (ref) async => LearnerProfileEntity(
        profileId: profileUlid,
        displayName: 'Dovi',
        mode: ProfileMode.adult,
        createdAt: t2,
        updatedAt: t2,
      ),
    ),
    corporaProvider.overrideWith(
      (ref) async => <String, Corpus>{engineCurriculum: mishnayosCorpus()},
    ),
    learnerLockSettingsProvider.overrideWith(
      (ref, _) => Stream.value(c0SettingsHistory()),
    ),
  ];

  Future<LearningCommands> commandsOver(SubTrackRepository subTracks) async {
    final container = ProviderContainer.test(
      overrides: ready(subTracks: subTracks),
    );
    return (await settledAsync(container, learningCommandsProvider)).value!;
  }

  setUp(() async {
    firestore = MergeTransactionFirestore();
    repo = FirestoreSubTrackRepository(firestore: firestore);
    intent = InMemoryGovernedIntentRepository()
      ..emit(
        scope,
        LearnerIntent(
          settings: c0Settings,
          mainTracks: {engineCurriculum: engineIntent()},
          goals: const {},
        ),
      );
    addTearDown(intent.dispose);
    await repo.collectionFor(scope).doc(ulidA).set(_school());
  });

  test('an online append commits through the Firestore latest-row '
      'transaction: the ground and its change-log entry are saved, not '
      'answered onlineRequired', () async {
    final commands = await commandsOver(repo);
    // Another device appended Berakhot 1 after this one read the row; the
    // transaction derives from the server row and keeps it.
    firestore.beforeAttempt = () async {
      firestore.beforeAttempt = null;
      await repo
          .collectionFor(scope)
          .doc(ulidA)
          .set(
            _school(
              ground: [
                {'level': berakhot1.level, 'ref': berakhot1.ref},
              ],
            ),
          );
    };

    final result = await commands.editSubTrack(
      ulidA,
      const SubTrackEdit(appendGround: [_peah1]),
    );

    expect(result, isA<CaptureSuccess>());
    final success = result as CaptureSuccess;
    expect(success.queued, isFalse);
    expect(success.changeIds, hasLength(1));
    final stored = await repo.collectionFor(scope).doc(ulidA).get();
    expect(stored.data()!['ground'], [
      {'level': berakhot1.level, 'ref': berakhot1.ref},
      {'level': _peah1.level, 'ref': _peah1.ref},
    ]);
    expect(stored.data()!['last_change_id'], success.changeIds.single);
    final entry = await firestore
        .collection('users')
        .doc(scope.ownerUid)
        .collection('learner_profiles')
        .doc(scope.profileId)
        .collection(kChangeLogCollection)
        .doc(success.changeIds.single)
        .get();
    expect(entry.exists, isTrue);
    expect(entry.data()!['entity_id'], ulidA);
    expect((entry.data()!['actor'] as Map)['role'], ActorRole.parent.name);
    expect(
      firestore.ops.where((op) => op.startsWith('set ')),
      hasLength(2),
      reason: 'the doc patch and its entry, in the one transaction',
    );
  });

  test('when the server cannot be reached the append answers '
      'onlineRequired and writes nothing', () async {
    final commands = await commandsOver(repo);
    firestore.failWith = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    final result = await commands.editSubTrack(
      ulidA,
      const SubTrackEdit(appendGround: [_peah1]),
    );

    expect(result, const CaptureResult.onlineRequired());
    final stored = await repo.collectionFor(scope).doc(ulidA).get();
    expect(stored.data()!['ground'], isEmpty);
  });

  test('a sub-track repository with no latest-row write never queues the '
      'append: onlineRequired, nothing written', () async {
    final plain = InMemorySubTrackRepository()
      ..seed(scope, [SubTrack.fromStorage(ulidA, _school())]);
    addTearDown(plain.dispose);
    final commands = await commandsOver(plain);

    final result = await commands.editSubTrack(
      ulidA,
      const SubTrackEdit(appendGround: [_peah1]),
    );

    expect(result, const CaptureResult.onlineRequired());
    expect(plain.entries, isEmpty);
    expect(plain.tracksOf(scope).single.ground, isEmpty);
  });
}
