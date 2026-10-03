/// Story 2.7 (DNI-498) AC-4 and edge cases: `editSubTrack` with
/// `SubTrackEdit.appendGround` — the ground picker's write. One governed
/// batch (the whole new `ground` plus one `change_log` entry), appended in
/// tree order after the latest stored ground, never duplicating covered
/// ground, never accepting another curriculum's node, and a no-op replay.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/sub_tracks/latest_write_sub_track_repository.dart';

const _today = '2026-10-01';
final _now = DateTime.utc(2026, 10, 1, 9);
const _peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');
const _shabbat1 = NodeEntry(level: 'chapter', ref: 'Mishnah Shabbat 1');

const _childActor = Actor(
  uid: 'uid-1',
  role: ActorRole.child,
  displayName: 'Child',
);

SubTrack _school({
  List<NodeEntry> ground = const [],
  bool ended = false,
  String curriculumId = engineCurriculum,
}) => SubTrack(
  id: ulidA,
  curriculumId: curriculumId,
  name: 'School',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 10,
  weeksPerYear: 39,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidE,
  endedAt: ended ? t1 : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

String Function() _ids({String prefix = '01JTEST0000000000000'}) {
  var n = 0;
  return () => '${prefix}00${(++n).toString().padLeft(4, '0')}';
}

LearnerIntent _intent() => LearnerIntent(
  settings: c0Settings,
  mainTracks: {
    engineCurriculum: MainTrackIntent(
      curriculumId: engineCurriculum,
      track: MainTrack(
        curriculumId: engineCurriculum,
        state: MainTrackState.active,
      ),
    ),
  },
  goals: const {},
);

void main() {
  final scope = c0Scope();
  final corpus = mishnayosCorpus();
  late InMemorySubTrackRepository repo;
  late InMemoryGovernedIntentRepository intent;
  late SubTrackCommands commands;

  SubTrackCommands build({
    Actor actor = parentActor,
    Future<Corpus?> Function(String)? corpusOf,
    SubTrackRepository? subTracks,
    String Function()? newId,
  }) => SubTrackCommands(
    scope: scope,
    actor: actor,
    // Like FirestoreSubTrackRepository, the default device commits an
    // append as a latest-row (server) write; its cache is the server.
    subTracks: subTracks ?? LatestWriteSubTrackRepository(repo),
    intent: intent,
    today: () => _today,
    nowUtc: () => _now,
    newId: newId ?? _ids(),
    corpusOf: corpusOf ?? (id) async => id == engineCurriculum ? corpus : null,
    ackTimeout: const Duration(milliseconds: 50),
    readTimeout: const Duration(seconds: 2),
  );

  setUp(() {
    repo = InMemorySubTrackRepository();
    intent = InMemoryGovernedIntentRepository()..emit(scope, _intent());
    commands = build();
  });

  tearDown(() async {
    await commands.dispose();
    await repo.dispose();
    await intent.dispose();
  });

  Future<CaptureResult> add(List<NodeEntry> nodes, {SubTrackCommands? via}) =>
      (via ?? commands).editSubTrack(ulidA, SubTrackEdit(appendGround: nodes));

  List<NodeEntry> storedGround() => repo.tracksOf(scope).single.ground;

  List<Map<String, Object?>> stored(List<NodeEntry> ground) => [
    for (final n in ground) {'level': n.level, 'ref': n.ref},
  ];

  group('AC-4 append', () {
    test('a groundless sub-track gets the picked nodes in tree order: one '
        'batch, one change-log entry', () async {
      repo.seed(scope, [_school()]);
      final result = await add(const [_shabbat1, berakhot2, _peah1]);
      expect(repo.entries, hasLength(1));
      final entry = repo.entries.single.$2;
      expect(
        result,
        CaptureResult.success(changeIds: [entry.id], actionId: entry.id),
      );
      expect(entry.entity, GovernedEntity.subTrack);
      expect(entry.entityId, ulidA);
      expect(entry.actor, parentActor);
      const key = 'sub_tracks/$ulidA.ground';
      expect(entry.before, {key: <Object?>[]});
      expect(entry.after, {
        key: stored(const [berakhot2, _peah1, _shabbat1]),
      });
      expect(repo.calls.single.$2.changedFields.keys, ['ground']);
      expect(storedGround(), const [berakhot2, _peah1, _shabbat1]);
      expect(repo.tracksOf(scope).single.lastChangeId, entry.id);
    });

    test('new entries go to the end of the stored ground, which is kept as '
        'entered', () async {
      repo.seed(scope, [
        _school(ground: const [_shabbat1, berakhot2]),
      ]);
      await add(const [berakhot1]);
      expect(storedGround(), const [_shabbat1, berakhot2, berakhot1]);
      final entry = repo.entries.single.$2;
      expect(entry.before['sub_tracks/$ulidA.ground'], [
        ...stored(const [_shabbat1, berakhot2]),
      ]);
    });

    test('ground already covered by an existing entry is not duplicated; '
        'all-covered writes nothing', () async {
      repo.seed(scope, [
        _school(ground: const [berakhot]),
      ]);
      final result = await add(const [berakhot1, berakhot2]);
      expect(result, const CaptureResult.success());
      expect(repo.calls, isEmpty);
      expect(storedGround(), const [berakhot]);
    });

    test(
      'an ancestor of stored ground appends only its uncovered part',
      () async {
        repo.seed(scope, [
          _school(ground: const [berakhot1]),
        ]);
        await add(const [zeraim]);
        expect(storedGround(), const [berakhot1, berakhot2, peah]);
      },
    );

    test(
      'a node of another curriculum is refused and nothing is written',
      () async {
        repo.seed(scope, [_school()]);
        const foreign = NodeEntry(level: 'masechta', ref: 'Shabbat');
        final result = await add(const [berakhot1, foreign]);
        expect(
          result,
          const CaptureResult.rejected(
            CaptureRejection.invalid,
            violations: [
              SubTrackViolation(
                SubTrackLimit.crossCurriculumGround,
                subject: 'Shabbat',
              ),
            ],
          ),
        );
        expect(repo.calls, isEmpty);
      },
    );

    test('a corpus of another curriculum is refused (ref collisions across '
        'curricula never pass)', () async {
      repo.seed(scope, [_school(curriculumId: 'bavli')]);
      final sameRefs = build(corpusOf: (_) async => corpus);
      final result = await add(const [berakhot1], via: sameRefs);
      expect(result, isA<CaptureRejected>());
      expect(
        (result as CaptureRejected).violations.single.limit,
        SubTrackLimit.crossCurriculumGround,
      );
      expect(repo.calls, isEmpty);
      await sameRefs.dispose();
    });
  });

  group('edge: stale, replay and refusals', () {
    test('re-reads the latest ground before deriving the whole list', () async {
      // The picker opened on a groundless sub-track; another device then
      // added Peah perek 1. The append lands after it, not over it.
      repo.seed(scope, [_school()]);
      await commands.editSubTrack(ulidA, const SubTrackEdit(ground: [_peah1]));
      await add(const [berakhot1]);
      expect(storedGround(), const [_peah1, berakhot1]);
      expect(repo.entries, hasLength(2));
      expect(repo.entries.last.$2.before['sub_tracks/$ulidA.ground'], [
        ...stored(const [_peah1]),
      ]);
    });

    test('a replayed append writes no second entry and no duplicate', () async {
      repo.seed(scope, [_school()]);
      await add(const [berakhot1, _shabbat1]);
      final replay = await add(const [berakhot1, _shabbat1]);
      expect(replay, const CaptureResult.success());
      expect(repo.entries, hasLength(1));
      expect(storedGround(), const [berakhot1, _shabbat1]);
    });

    test('a child session cannot append', () async {
      repo.seed(scope, [_school()]);
      final child = build(actor: _childActor);
      expect(
        await add(const [berakhot1], via: child),
        isA<CaptureChildLimit>(),
      );
      expect(repo.calls, isEmpty);
      await child.dispose();
    });

    test('an unknown sub-track is not found', () async {
      final result = await add(const [berakhot1]);
      expect(
        result,
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
    });

    test('an ended sub-track, a missing corpus or a whole-ground replace '
        'with an append is refused', () async {
      repo.seed(scope, [_school(ended: true)]);
      expect(
        await add(const [berakhot1]),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      repo.seed(scope, [_school()]);
      final noCorpus = build(corpusOf: (_) async => null);
      expect(
        await add(const [berakhot1], via: noCorpus),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      await noCorpus.dispose();
      expect(
        await commands.editSubTrack(
          ulidA,
          const SubTrackEdit(ground: [peah], appendGround: [berakhot1]),
        ),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(repo.calls, isEmpty);
    });

    test('a repository without a latest-row write refuses the append as '
        'online-required and writes nothing', () async {
      repo.seed(scope, [_school()]);
      final plain = build(subTracks: repo);
      addTearDown(plain.dispose);
      expect(
        await add(const [berakhot1], via: plain),
        const CaptureResult.onlineRequired(),
      );
      expect(repo.calls, isEmpty);
      expect(storedGround(), isEmpty);
    });

    test('an empty pick writes nothing', () async {
      repo.seed(scope, [_school()]);
      expect(await add(const []), const CaptureResult.success());
      expect(repo.calls, isEmpty);
    });
  });

  group('edge: two devices append at once (latest-row write)', () {
    // Both devices opened the picker on the same groundless School; each
    // device's cache still shows it groundless when it confirms. The
    // append is derived from the row the server holds at commit time, so
    // neither device's nodes are lost.
    late LatestWriteSubTrackRepository phone;
    late LatestWriteSubTrackRepository tablet;
    late SubTrackCommands onPhone;
    late SubTrackCommands onTablet;

    setUp(() {
      repo.seed(scope, [_school()]);
      phone = LatestWriteSubTrackRepository(repo)..freezeCache(scope);
      tablet = LatestWriteSubTrackRepository(repo)..freezeCache(scope);
      onPhone = build(subTracks: phone);
      // Each device mints its own ULIDs.
      onTablet = build(
        subTracks: tablet,
        newId: _ids(prefix: '01JTAB00000000000000'),
      );
    });

    tearDown(() async {
      await onPhone.dispose();
      await onTablet.dispose();
    });

    test('both appends survive, each with its own change-log entry whose '
        'before is the ground the server held', () async {
      final first = await add(const [berakhot1], via: onPhone);
      final second = await add(const [_peah1], via: onTablet);
      expect(first, isA<CaptureSuccess>());
      expect(second, isA<CaptureSuccess>());
      expect((second as CaptureSuccess).queued, isFalse);
      expect(storedGround(), const [berakhot1, _peah1]);
      expect(repo.entries, hasLength(2));
      const key = 'sub_tracks/$ulidA.ground';
      expect(repo.entries.first.$2.before[key], <Object?>[]);
      expect(repo.entries.last.$2.before[key], stored(const [berakhot1]));
      expect(
        repo.entries.last.$2.after[key],
        stored(const [berakhot1, _peah1]),
      );
      expect(repo.tracksOf(scope).single.lastChangeId, second.changeIds.single);
    });

    test('nodes the other device already added are not added twice; '
        'nothing left to add writes nothing', () async {
      await add(const [berakhot1, _peah1], via: onPhone);
      final overlap = await add(const [_peah1, _shabbat1], via: onTablet);
      expect(overlap, isA<CaptureSuccess>());
      expect(storedGround(), const [berakhot1, _peah1, _shabbat1]);
      final none = await add(const [berakhot1], via: onTablet);
      expect(none, const CaptureResult.success());
      expect(repo.entries, hasLength(2));
    });

    test('a sub-track the other device ended meanwhile is refused and '
        'nothing is written', () async {
      expect(await onPhone.endSubTrack(ulidA), isA<CaptureSuccess>());
      final result = await add(const [berakhot1], via: onTablet);
      expect(result, const CaptureResult.rejected(CaptureRejection.invalid));
      expect(storedGround(), isEmpty);
      expect(repo.entries, hasLength(1));
    });

    test('offline the append is refused as online-required: no stale '
        'whole-list batch is queued from the cached row', () async {
      repo.offline = true;
      final result = await add(const [berakhot1], via: onTablet);
      expect(result, const CaptureResult.onlineRequired());
      expect(tablet.builds, 0);
      expect(repo.heldCount, 0);
      expect(repo.calls, isEmpty);
      expect(storedGround(), isEmpty);
    });

    test('a device that was offline cannot later overwrite an append the '
        'other device made meanwhile', () async {
      // The tablet's attempt while offline left nothing behind to replay.
      repo.offline = true;
      expect(
        await add(const [berakhot1], via: onTablet),
        const CaptureResult.onlineRequired(),
      );
      repo.offline = false;
      await add(const [_peah1], via: onPhone);
      // Back online, the tablet (cache still stale) appends to the
      // server's row: both survive.
      expect(
        await add(const [berakhot1], via: onTablet),
        isA<CaptureSuccess>(),
      );
      expect(storedGround(), const [_peah1, berakhot1]);
      expect(repo.entries, hasLength(2));
    });
  });
}
