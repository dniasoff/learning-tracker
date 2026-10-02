/// Story 2.1 (DNI-492) AC-2..AC-6: the governed sub-track lifecycle
/// commands (`SubTrackCommands`, delegated to by `LearningCommands`).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _berakhot = NodeEntry(level: 'masechta', ref: 'Berakhot');
const _shabbat = NodeEntry(level: 'masechta', ref: 'Shabbat');
const _today = '2026-10-01';
final _now = DateTime.utc(2026, 10, 1, 9);

SubTrackDraft _draft({
  String curriculumId = 'shas',
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String windowStart = '2026-09-01',
  String? windowEnd,
  double rate = 5,
  double weeks = 40,
  List<NodeEntry> ground = const [_berakhot],
}) => SubTrackDraft(
  curriculumId: curriculumId,
  name: 'Night seder',
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: rate,
  weeksPerYear: weeks,
  learnsOnShabbos: false,
  ground: ground,
);

SubTrack _stored(
  String id, {
  String curriculumId = 'shas',
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String windowStart = '2026-09-01',
  String? windowEnd,
  List<NodeEntry> ground = const [_berakhot],
  bool ended = false,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: 'Stored $id',
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidE,
  endedAt: ended ? t1 : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

/// `01JTEST…` + a counter: valid, distinct ULIDs.
String Function() _ids() {
  var n = 0;
  return () => '01JTEST000000000000000${(++n).toString().padLeft(4, '0')}';
}

LearnerIntent _intent({String? programId}) => LearnerIntent(
  settings: c0Settings,
  mainTracks: {
    'shas': MainTrackIntent(
      curriculumId: 'shas',
      track: MainTrack(curriculumId: 'shas', state: MainTrackState.active),
      program: programId == null
          ? null
          : MainTrackProgram(
              curriculumId: 'shas',
              programId: programId,
              trackingStartDate: '2026-01-01',
            ),
    ),
  },
  goals: const {},
);

void main() {
  final scope = c0Scope();
  late InMemorySubTrackRepository repo;
  late InMemoryGovernedIntentRepository intent;
  late SubTrackCommands commands;

  SubTrackCommands build({
    Actor actor = parentActor,
    Future<Corpus?> Function(String)? corpusOf,
    Duration readTimeout = const Duration(seconds: 2),
  }) => SubTrackCommands(
    scope: scope,
    actor: actor,
    subTracks: repo,
    intent: intent,
    today: () => _today,
    nowUtc: () => _now,
    newId: _ids(),
    corpusOf: corpusOf,
    ackTimeout: const Duration(milliseconds: 50),
    readTimeout: readTimeout,
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

  ChangeLogEntry onlyEntry() {
    expect(repo.entries, hasLength(1));
    return repo.entries.single.$2;
  }

  group('AC-2 create', () {
    test(
      'one batch: the doc and one entry with null before per field',
      () async {
        final result = await commands.createSubTrack(_draft());
        final entry = onlyEntry();
        final id = entry.entityId;
        expect(
          result,
          CaptureResult.success(changeIds: [entry.id], actionId: entry.id),
        );
        expect(entry.entity, GovernedEntity.subTrack);
        expect(entry.actionId, entry.id);
        expect(entry.actor, parentActor);
        expect(entry.at, _now);
        String k(String f) => 'sub_tracks/$id.$f';
        expect(entry.after, {
          k('curriculum_id'): 'shas',
          k('name'): 'Night seder',
          k('type'): 'ongoing',
          k('window_start'): '2026-09-01',
          k('rate_per_week'): 5.0,
          k('weeks_per_year'): 40.0,
          k('learns_on_shabbos'): false,
          k('ground'): [
            {'level': 'masechta', 'ref': 'Berakhot'},
          ],
        });
        // AD-38 Create: every before is null; absent optionals are not logged.
        expect(entry.before.keys, entry.after.keys);
        expect(entry.before.values, everyElement(isNull));
        final change = repo.calls.single.$2;
        expect(change.isCreate, isTrue);
        expect(change.toMergePatch()['last_change_id'], entry.id);
        final stored = repo.tracksOf(scope).single;
        expect(stored.id, id);
        expect(stored.lastChangeId, entry.id);
        expect(stored.windowEnd, isNull);
      },
    );

    test('a caller-supplied ULID becomes the doc id and entity_id', () async {
      await commands.createSubTrack(_draft(), subTrackId: ulidD);
      expect(onlyEntry().entityId, ulidD);
      expect(repo.tracksOf(scope).single.id, ulidD);
    });

    test('school-year create logs academic_year and window_end', () async {
      await commands.createSubTrack(
        _draft(
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowEnd: '2027-06-30',
        ),
      );
      final entry = onlyEntry();
      final id = entry.entityId;
      expect(entry.after['sub_tracks/$id.academic_year'], 2026);
      expect(entry.after['sub_tracks/$id.window_end'], '2027-06-30');
    });

    test('a child session cannot create, edit, end or delete', () async {
      repo.seed(scope, [_stored(ulidA)]);
      final child = build(
        actor: const Actor(
          uid: 'owner-uid',
          role: ActorRole.child,
          displayName: 'Yossi',
        ),
      );
      expect(
        await child.createSubTrack(_draft()),
        const CaptureResult.childLimit(),
      );
      expect(
        await child.editSubTrack(ulidA, const SubTrackEdit(name: 'x')),
        const CaptureResult.childLimit(),
      );
      expect(await child.endSubTrack(ulidA), const CaptureResult.childLimit());
      expect(
        await child.deleteSubTrack(ulidA),
        const CaptureResult.childLimit(),
      );
      expect(repo.calls, isEmpty);
      await child.dispose();
    });
  });

  group('AC-3 / AC-4 / AC-5 validation rejects before any write', () {
    Future<void> expectRejected(
      Future<CaptureResult> command,
      List<SubTrackLimit> limits,
    ) async {
      final result = await command;
      expect(result, isA<CaptureRejected>());
      final rejected = result as CaptureRejected;
      expect(rejected.reason, CaptureRejection.invalid);
      expect(rejected.violations.map((v) => v.limit).toSet(), limits.toSet());
      expect(repo.calls, isEmpty, reason: 'nothing is written');
    }

    test('a sixth counting ongoing sub-track names ongoing_limit', () async {
      repo.seed(scope, [
        for (final id in [ulidA, ulidB, ulidC, ulidD, ulidE]) _stored(id),
      ]);
      await expectRejected(commands.createSubTrack(_draft()), [
        SubTrackLimit.ongoingLimit,
      ]);
    });

    test('ended and passed-window sub-tracks do not count', () async {
      repo.seed(scope, [
        for (final id in [ulidA, ulidB, ulidC]) _stored(id),
        _stored(ulidD, ended: true),
        _stored(ulidE, windowEnd: '2026-09-30'),
        _stored('01JTEST0000000000000000099'),
      ]);
      final result = await commands.createSubTrack(_draft());
      expect(result, isA<CaptureSuccess>());
    });

    test('a second school year for one academic_year is rejected', () async {
      repo.seed(scope, [
        _stored(
          ulidA,
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowEnd: '2027-06-30',
        ),
      ]);
      await expectRejected(
        commands.createSubTrack(
          _draft(
            type: SubTrackType.schoolYear,
            academicYear: 2026,
            windowStart: '2026-10-01',
            windowEnd: '2027-06-30',
          ),
        ),
        [SubTrackLimit.schoolYearDuplicate, SubTrackLimit.schoolYearOverlap],
      );
    });

    test('a calendar-program curriculum rejects a create (AC-4)', () async {
      intent.emit(scope, _intent(programId: 'daf_yomi'));
      await expectRejected(commands.createSubTrack(_draft()), [
        SubTrackLimit.calendarProgramCurriculum,
      ]);
    });

    test('malformed intent is typed (AC-5)', () async {
      await expectRejected(
        commands.createSubTrack(
          _draft(
            ground: const [_berakhot, _berakhot],
            windowStart: '2026-12-02',
            windowEnd: '2026-12-01',
            rate: 0,
            weeks: -1,
          ),
        ),
        [
          SubTrackLimit.duplicateGround,
          SubTrackLimit.windowReversed,
          SubTrackLimit.nonPositiveRate,
          SubTrackLimit.nonPositiveWeeks,
        ],
      );
    });

    test('a ground node from another curriculum is rejected', () async {
      final shas = InMemoryCorpus('shas', const [CorpusNode(_berakhot)]);
      final withCorpus = build(
        corpusOf: (c) async => c == 'shas' ? shas : null,
      );
      await expectRejected(
        withCorpus.createSubTrack(_draft(ground: const [_berakhot, _shabbat])),
        [SubTrackLimit.crossCurriculumGround],
      );
      await withCorpus.dispose();
    });

    test('an edit into a school-year collision is rejected', () async {
      repo.seed(scope, [
        _stored(
          ulidA,
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowEnd: '2026-12-31',
        ),
        _stored(
          ulidB,
          type: SubTrackType.schoolYear,
          academicYear: 2027,
          windowStart: '2027-01-01',
          windowEnd: '2027-06-30',
        ),
      ]);
      await expectRejected(
        commands.editSubTrack(ulidB, const SubTrackEdit(academicYear: 2026)),
        [SubTrackLimit.schoolYearDuplicate],
      );
    });
  });

  group('AC-2 edit', () {
    setUp(() => repo.seed(scope, [_stored(ulidA)]));

    test('writes and logs only the changed fields', () async {
      final result = await commands.editSubTrack(
        ulidA,
        const SubTrackEdit(ratePerWeek: 7, name: 'Stored $ulidA'),
      );
      final entry = onlyEntry();
      expect(result, isA<CaptureSuccess>());
      expect(entry.entityId, ulidA);
      expect(entry.before, {'sub_tracks/$ulidA.rate_per_week': 5.0});
      expect(entry.after, {'sub_tracks/$ulidA.rate_per_week': 7.0});
      expect(repo.calls.single.$2.changedFields, {'rate_per_week': 7.0});
      final stored = repo.tracksOf(scope).single;
      expect(stored.ratePerWeek, 7);
      expect(stored.name, 'Stored $ulidA');
      expect(stored.lastChangeId, entry.id);
    });

    test('ground is replaced whole, as an ordered list', () async {
      await commands.editSubTrack(
        ulidA,
        const SubTrackEdit(ground: [_shabbat, _berakhot]),
      );
      final entry = onlyEntry();
      expect(entry.after.keys, ['sub_tracks/$ulidA.ground']);
      expect(entry.before['sub_tracks/$ulidA.ground'], [
        {'level': 'masechta', 'ref': 'Berakhot'},
      ]);
      expect(entry.after['sub_tracks/$ulidA.ground'], [
        {'level': 'masechta', 'ref': 'Shabbat'},
        {'level': 'masechta', 'ref': 'Berakhot'},
      ]);
      expect(repo.tracksOf(scope).single.ground, [_shabbat, _berakhot]);
    });

    test('clearing window_end logs the old value and null', () async {
      repo.seed(scope, [_stored(ulidB, windowEnd: '2027-01-01')]);
      await commands.editSubTrack(
        ulidB,
        const SubTrackEdit(clearWindowEnd: true),
      );
      final entry = onlyEntry();
      expect(entry.before, {'sub_tracks/$ulidB.window_end': '2027-01-01'});
      expect(entry.after, {'sub_tracks/$ulidB.window_end': null});
      expect(repo.tracksOf(scope).last.windowEnd, isNull);
    });

    test('an edit that changes nothing writes nothing', () async {
      final result = await commands.editSubTrack(
        ulidA,
        const SubTrackEdit(ratePerWeek: 5, ground: [_berakhot]),
      );
      expect(result, const CaptureResult.success());
      expect(repo.calls, isEmpty);
    });

    test('an unknown sub-track is targetNotFound', () async {
      expect(
        await commands.editSubTrack(ulidD, const SubTrackEdit(name: 'x')),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(repo.calls, isEmpty);
    });
  });

  group('AC-2 end and delete are tombstones', () {
    setUp(() => repo.seed(scope, [_stored(ulidA), _stored(ulidB)]));

    for (final (name, reason) in [
      ('endSubTrack', SubTrackEndReason.ended),
      ('deleteSubTrack', SubTrackEndReason.deleted),
    ]) {
      test('$name writes ended_at + end_reason ${reason.storage}', () async {
        final result = reason == SubTrackEndReason.ended
            ? await commands.endSubTrack(ulidA)
            : await commands.deleteSubTrack(ulidA);
        expect(result, isA<CaptureSuccess>());
        final entry = onlyEntry();
        expect(entry.before, {
          'sub_tracks/$ulidA.ended_at': null,
          'sub_tracks/$ulidA.end_reason': null,
        });
        expect(entry.after, {
          'sub_tracks/$ulidA.ended_at': _now,
          'sub_tracks/$ulidA.end_reason': reason.storage,
        });
        final stored = repo.tracksOf(scope).first;
        expect(stored.endedAt, _now);
        expect(stored.endReason, reason);
        // Still present: a tombstone, never a hard delete.
        expect(repo.tracksOf(scope), hasLength(2));
      });
    }

    test('ending or deleting an ended sub-track writes nothing', () async {
      await commands.endSubTrack(ulidA);
      expect(await commands.endSubTrack(ulidA), const CaptureResult.success());
      expect(
        await commands.deleteSubTrack(ulidA),
        const CaptureResult.success(),
      );
      expect(repo.entries, hasLength(1));
      expect(repo.tracksOf(scope).first.endReason, SubTrackEndReason.ended);
    });

    test('end of an unknown sub-track is targetNotFound', () async {
      expect(
        await commands.deleteSubTrack(ulidD),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
    });
  });

  group('AC-6 offline', () {
    test(
      'a create is queued and visible at once from the local cache',
      () async {
        repo.offline = true;
        final seen = <List<String>>[];
        final sub = repo.watchAll(scope).listen((r) {
          if (r case CompleteReadReady(:final items)) {
            seen.add([for (final t in items) t.id]);
          }
        });
        final result = await commands.createSubTrack(
          _draft(),
          subTrackId: ulidD,
        );
        expect(result, isA<CaptureSuccess>());
        expect((result as CaptureSuccess).queued, isTrue);
        expect(seen.last, [ulidD]);
        // One batch = one doc + one entry (2 writes, 2 Rules access calls).
        expect(repo.calls, hasLength(1));
        expect(repo.heldCount, 1);
        repo.settleHeld(); // reconnect: syncs without loss
        await Future<void>.delayed(Duration.zero);
        expect(repo.tracksOf(scope).single.id, ulidD);
        expect(repo.entries, hasLength(1));
        await sub.cancel();
      },
    );

    test('a queued batch refused for good becomes a retry entry', () async {
      repo
        ..offline = true
        ..failNextWith(const PermanentWriteRejection('permission-denied'));
      final failures = <List<PendingFailure>>[];
      final sub = commands.watchPendingFailures().listen(failures.add);
      final result = await commands.createSubTrack(_draft(), subTrackId: ulidD);
      expect((result as CaptureSuccess).queued, isTrue);
      final entryId = result.changeIds.single;
      repo.settleHeld();
      await Future<void>.delayed(Duration.zero);
      expect(repo.tracksOf(scope), isEmpty, reason: 'the local write reverts');
      expect(failures.last, [
        PendingFailure(
          id: entryId,
          eventIds: const [],
          changeIds: [entryId],
          reason: PendingFailureReason.permissionDenied,
        ),
      ]);
      // Retry re-sends the identical batch (same entry id and `at`).
      repo.offline = false;
      final retried = await commands.retry(entryId);
      expect(
        retried,
        CaptureResult.success(changeIds: [entryId], actionId: entryId),
      );
      await Future<void>.delayed(Duration.zero);
      expect(failures.last, isEmpty);
      expect(repo.tracksOf(scope).single.id, ulidD);
      expect(repo.calls.first.$2.entry, repo.calls.last.$2.entry);
      await sub.cancel();
    });

    test(
      'an online refusal is returned at once, without a retry entry',
      () async {
        repo.failNextWith(const PermanentWriteRejection('invalid-argument'));
        expect(
          await commands.createSubTrack(_draft()),
          const CaptureResult.rejected(CaptureRejection.invalid),
        );
        expect(await commands.watchPendingFailures().first, isEmpty);
        expect(
          await commands.retry(ulidA),
          const CaptureResult.rejected(CaptureRejection.targetNotFound),
        );
      },
    );

    test(
      'no complete read in time → onlineRequired, nothing written',
      () async {
        final noIntent = InMemoryGovernedIntentRepository();
        final cold = SubTrackCommands(
          scope: scope,
          actor: parentActor,
          subTracks: repo,
          intent: noIntent,
          today: () => _today,
          nowUtc: () => _now,
          newId: _ids(),
          readTimeout: const Duration(milliseconds: 20),
        );
        expect(
          await cold.createSubTrack(_draft()),
          const CaptureResult.onlineRequired(),
        );
        expect(repo.calls, isEmpty);
        await cold.dispose();
        await noIntent.dispose();
      },
    );
  });

  test('LearningCommands declares the four sub-track commands', () async {
    final LearningCommands fake = FakeLearningCommands();
    await fake.createSubTrack(_draft());
    await fake.editSubTrack(ulidA, const SubTrackEdit(name: 'x'));
    await fake.endSubTrack(ulidA);
    await fake.deleteSubTrack(ulidA);
    expect((fake as FakeLearningCommands).calls.map((c) => c.name), [
      'createSubTrack',
      'editSubTrack',
      'endSubTrack',
      'deleteSubTrack',
    ]);
    unawaited(fake.dispose());
  });
}
