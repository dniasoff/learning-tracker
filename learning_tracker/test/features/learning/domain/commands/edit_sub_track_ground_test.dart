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
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

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

String Function() _ids() {
  var n = 0;
  return () => '01JTEST000000000000000${(++n).toString().padLeft(4, '0')}';
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
  }) => SubTrackCommands(
    scope: scope,
    actor: actor,
    subTracks: repo,
    intent: intent,
    today: () => _today,
    nowUtc: () => _now,
    newId: _ids(),
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

    test('an empty pick writes nothing', () async {
      repo.seed(scope, [_school()]);
      expect(await add(const []), const CaptureResult.success());
      expect(repo.calls, isEmpty);
    });
  });
}
