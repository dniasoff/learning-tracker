/// Story 2.8 (DNI-499): the sub-track lifecycle through the governed
/// `SubTrackCommands` behind `LearningCommands` — *Add next year* (AC-1),
/// delete (AC-3) and end (AC-4) — over the in-memory ports, plus the AD-47
/// `subtrack_lifecycle` analytics of those explicit actions (T6).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

const _berakhot = NodeEntry(level: 'masechta', ref: 'Berakhot');
const _today = '2026-10-01';
final _now = DateTime.utc(2026, 10, 1, 9);

/// The 2026–27 school year the parent set up: Sep–Jul, 8 a week.
SubTrack _school({
  String id = ulidA,
  String curriculumId = 'shas',
  int academicYear = 2026,
  String windowStart = '2026-09-01',
  String? windowEnd = '2027-07-31',
  SubTrackEndReason? endReason,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: 8,
  weeksPerYear: 36,
  learnsOnShabbos: true,
  ground: const [_berakhot],
  lastChangeId: ulidE,
  endedAt: endReason == null ? null : _now,
  endReason: endReason,
);

/// The 2027–28 draft *Add next year* saves (prefill, unedited).
const _nextYear = SubTrackDraft(
  curriculumId: 'shas',
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: 2027,
  windowStart: '2027-09-01',
  windowEnd: '2028-07-31',
  ratePerWeek: 8,
  weeksPerYear: 36,
  learnsOnShabbos: true,
  ground: [],
);

/// `01JTEST…` + a counter: valid, distinct ULIDs.
String Function() _ids() {
  var n = 0;
  return () => '01JTEST000000000000000${(++n).toString().padLeft(4, '0')}';
}

LearnerIntent _intent() => LearnerIntent(
  settings: c0Settings,
  mainTracks: {
    'shas': MainTrackIntent(
      curriculumId: 'shas',
      track: MainTrack(curriculumId: 'shas', state: MainTrackState.active),
    ),
  },
  goals: const {},
);

void main() {
  final scope = c0Scope();
  late InMemorySubTrackRepository repo;
  late InMemoryGovernedIntentRepository intent;
  late RecordingLearningAnalytics analytics;
  late SubTrackCommands commands;

  setUp(() {
    repo = InMemorySubTrackRepository()..seed(scope, [_school()]);
    intent = InMemoryGovernedIntentRepository()..emit(scope, _intent());
    analytics = RecordingLearningAnalytics();
    commands = SubTrackCommands(
      scope: scope,
      actor: parentActor,
      subTracks: repo,
      intent: intent,
      today: () => _today,
      nowUtc: () => _now,
      newId: _ids(),
      analytics: analytics,
      ackTimeout: const Duration(milliseconds: 50),
      readTimeout: const Duration(seconds: 2),
    );
  });

  tearDown(() async {
    await commands.dispose();
    await repo.dispose();
    await intent.dispose();
  });

  group('T6 subtrack_lifecycle for the explicit lifecycle actions (AD-47)', () {
    test('Add next year reports add_next_year, not create', () async {
      await commands.createSubTrack(_nextYear, nextYearOf: ulidA);
      expect(analytics.lifecycles, [
        (
          curriculumId: 'shas',
          type: SubTrackType.schoolYear,
          action: SubTrackLifecycleAction.addNextYear,
          groundEntries: 0,
        ),
      ]);
      expect(SubTrackLifecycleAction.addNextYear.storage, 'add_next_year');
    });

    test('end and delete report end and delete', () async {
      repo.seed(scope, [_school(id: ulidB, academicYear: 2027)]);
      await commands.endSubTrack(ulidA);
      await commands.deleteSubTrack(ulidB);
      expect(analytics.lifecycles.map((e) => e.action), [
        SubTrackLifecycleAction.end,
        SubTrackLifecycleAction.delete,
      ]);
    });

    test('a refused Add next year emits nothing', () async {
      // 2026–27 is already held: the copy is a duplicate academic year.
      await commands.createSubTrack(
        const SubTrackDraft(
          curriculumId: 'shas',
          name: 'School',
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowStart: '2026-09-01',
          windowEnd: '2027-07-31',
          ratePerWeek: 8,
          weeksPerYear: 36,
          learnsOnShabbos: true,
          ground: [],
        ),
        nextYearOf: ulidA,
      );
      expect(analytics.lifecycles, isEmpty);
    });

    test('the payload carries no name, ref, date or ULID', () {
      final sent = <Map<String, Object>>[];
      SinkLearningAnalytics(
        (_, parameters) => sent.add(parameters),
      ).subTrackLifecycle(
        curriculumId: 'shas',
        type: SubTrackType.schoolYear,
        action: SubTrackLifecycleAction.addNextYear,
        groundEntries: 0,
      );
      expect(sent.single, {
        'curriculum_id': 'shas',
        'track_type': 'school_year',
        'action': 'add_next_year',
        'ground_entries': 0,
      });
    });
  });

  group('AC-1 save next-year school track', () {
    test('one new doc and one subTrack entry; the source and its ground are '
        'unchanged; the copied values survive the codec', () async {
      final source = repo.tracksOf(scope).single;
      final result = await commands.createSubTrack(
        nextYearSubTrackDraft(source),
        nextYearOf: ulidA,
      );
      expect(result, isA<CaptureSuccess>());
      final entry = repo.entries.single.$2;
      expect(entry.entity, GovernedEntity.subTrack);
      expect(entry.before.values, everyElement(isNull));
      final created = repo.tracksOf(scope).firstWhere((t) => t.id != ulidA);
      expect(entry.entityId, created.id);
      expect(created.id, isNot(source.id));
      expect(repo.tracksOf(scope).firstWhere((t) => t.id == ulidA), source);
      expect(source.ground, const [_berakhot]);
      expect(created.name, source.name);
      expect(created.academicYear, 2027);
      expect(created.windowStart, '2027-09-01');
      expect(created.windowEnd, '2028-07-31');
      expect(created.ratePerWeek, 8);
      expect(created.weeksPerYear, 36);
      expect(created.learnsOnShabbos, isTrue);
      expect(created.ground, isEmpty);
      expect(
        SubTrack.fromStorage(created.id, created.toStorage()),
        created,
        reason: 'codec round-trip',
      );
    });

    test('a leap-February end copies to the leap day and saves', () async {
      repo.seed(scope, [
        _school(
          id: ulidB,
          academicYear: 2025,
          windowStart: '2025-09-01',
          windowEnd: '2026-02-28',
        ),
      ]);
      // A 2026–27 School already exists, so roll the 2025–26 one only into
      // a free year: drop the live 2026 one first.
      await commands.deleteSubTrack(ulidA);
      final source = repo.tracksOf(scope).firstWhere((t) => t.id == ulidB);
      final draft = nextYearSubTrackDraft(source);
      expect(draft.windowEnd, '2027-02-28');
      final leap = nextYearSubTrackDraft(
        _school(academicYear: 2026, windowEnd: '2027-02-28'),
      );
      expect(leap.windowEnd, '2028-02-29');
      expect(
        await commands.createSubTrack(draft, nextYearOf: ulidB),
        isA<CaptureSuccess>(),
      );
    });

    test('Y+1 taken by another device after render is refused before any '
        'write', () async {
      repo.seed(scope, [
        _school(
          id: ulidB,
          academicYear: 2027,
          windowStart: '2027-09-01',
          windowEnd: '2028-07-31',
        ),
      ]);
      final result = await commands.createSubTrack(
        nextYearSubTrackDraft(_school()),
        nextYearOf: ulidA,
      );
      expect(result, isA<CaptureRejected>());
      expect(repo.calls, isEmpty);
      expect(repo.entries, isEmpty);
    });

    for (final (label, reason) in [
      ('ended', SubTrackEndReason.ended),
      ('deleted', SubTrackEndReason.deleted),
    ]) {
      test('a source $label on another device after the form opened refuses '
          'Add next year before any write; the tombstone stays', () async {
        final draft = nextYearSubTrackDraft(_school());
        // The other device's tombstone reaches the read between render
        // and save.
        final tombstoned = _school(endReason: reason);
        repo.seed(scope, [tombstoned]);
        final result = await commands.createSubTrack(draft, nextYearOf: ulidA);
        expect(
          result,
          isA<CaptureRejected>().having(
            (r) => r.reason,
            'reason',
            CaptureRejection.targetNotFound,
          ),
        );
        expect(repo.calls, isEmpty);
        expect(repo.entries, isEmpty);
        expect(repo.tracksOf(scope).single, tombstoned);
        expect(analytics.lifecycles, isEmpty);
      });
    }

    test('a missing source, or one of another curriculum or type, refuses '
        'Add next year before any write', () async {
      final draft = nextYearSubTrackDraft(_school());
      expect(
        await commands.createSubTrack(draft, nextYearOf: ulidB),
        isA<CaptureRejected>().having(
          (r) => r.reason,
          'reason',
          CaptureRejection.targetNotFound,
        ),
      );
      final otherCurriculum = _school(id: ulidC, curriculumId: 'other');
      repo.seed(scope, [otherCurriculum]);
      expect(
        await commands.createSubTrack(draft, nextYearOf: ulidC),
        isA<CaptureRejected>(),
      );
      expect(repo.calls, isEmpty);
      expect(repo.entries, isEmpty);
    });

    test('a complete read with an undecodable row (AD-35) refuses Add next '
        'year, end, delete and edit before any write', () async {
      // The rejected row may be the 2027 sibling that would refuse Y+1.
      repo.seedRejected(scope, const [
        RejectedRow(ulidB, FormatException('bad academic_year')),
      ]);
      final results = [
        await commands.createSubTrack(
          nextYearSubTrackDraft(_school()),
          nextYearOf: ulidA,
        ),
        await commands.endSubTrack(ulidA),
        await commands.deleteSubTrack(ulidA),
        await commands.editSubTrack(ulidA, const SubTrackEdit(name: 'Shiur')),
      ];
      // DNI-497's fail-closed refusal: rejected(invalid) with no violation,
      // which the lifecycle UI reports as its generic "not saved".
      expect(
        results,
        everyElement(
          isA<CaptureRejected>()
              .having((r) => r.reason, 'reason', CaptureRejection.invalid)
              .having((r) => r.violations, 'violations', isEmpty),
        ),
      );
      expect(repo.calls, isEmpty);
      expect(repo.entries, isEmpty);
      expect(analytics.lifecycles, isEmpty);

      // Once the read is clean again the same Add next year saves.
      repo.seedRejected(scope, const []);
      expect(
        await commands.createSubTrack(
          nextYearSubTrackDraft(_school()),
          nextYearOf: ulidA,
        ),
        isA<CaptureSuccess>(),
      );
    });

    test('two offline Add next year creates that both synced (AD-45 '
        'tolerated excess): both rows show, a third is refused, and '
        'Delete on one resolves it', () async {
      SubTrack dup(String id) => _school(
        id: id,
        academicYear: 2027,
        windowStart: '2027-09-01',
        windowEnd: '2028-07-31',
      );
      repo.seed(scope, [dup(ulidB), dup(ulidC)]);
      final groups = groupSubTracksByLifecycle(repo.tracksOf(scope), _today);
      expect(groups.active.map((t) => t.id).toSet(), {ulidA, ulidB, ulidC});
      expect(
        await commands.createSubTrack(
          nextYearSubTrackDraft(_school()),
          nextYearOf: ulidA,
        ),
        isA<CaptureRejected>(),
      );
      expect(repo.calls, isEmpty);
      expect(await commands.deleteSubTrack(ulidC), isA<CaptureSuccess>());
      final live = groupSubTracksByLifecycle(repo.tracksOf(scope), _today);
      expect(live.active.map((t) => t.id).toSet(), {ulidA, ulidB});
    });
  });

  group('AC-3 / AC-4 tombstones only the sub-track', () {
    for (final (name, reason) in [
      ('delete', SubTrackEndReason.deleted),
      ('end', SubTrackEndReason.ended),
    ]) {
      test('$name changes and logs only ended_at and end_reason', () async {
        final result = reason == SubTrackEndReason.deleted
            ? await commands.deleteSubTrack(ulidA)
            : await commands.endSubTrack(ulidA);
        expect(result, isA<CaptureSuccess>());
        final change = repo.calls.single.$2;
        expect(change.isCreate, isFalse);
        expect(change.changedFields.keys.toSet(), {'ended_at', 'end_reason'});
        expect(change.changedFields['end_reason'], reason.storage);
        final entry = repo.entries.single.$2;
        expect(entry.entityId, ulidA);
        expect(entry.after.keys.toSet(), {
          'sub_tracks/$ulidA.ended_at',
          'sub_tracks/$ulidA.end_reason',
        });
        final stored = repo.tracksOf(scope).single;
        expect(stored.endReason, reason);
        expect(stored.endedAt, _now);
        // The stored name is still the source label of its events (FR-8).
        expect(stored.name, 'School');
        expect(stored.ground, const [_berakhot]);
      });
    }

    test('a retry after a refusal logs exactly once; a second delete writes '
        'nothing', () async {
      repo.failNextWith(const PermanentWriteRejection('permission-denied'));
      expect(await commands.deleteSubTrack(ulidA), isA<CaptureRejected>());
      expect(repo.entries, isEmpty);
      expect(repo.tracksOf(scope).single.endedAt, isNull);
      expect(analytics.lifecycles, isEmpty);

      expect(await commands.deleteSubTrack(ulidA), isA<CaptureSuccess>());
      expect(await commands.deleteSubTrack(ulidA), isA<CaptureSuccess>());
      expect(await commands.endSubTrack(ulidA), isA<CaptureSuccess>());
      expect(repo.entries, hasLength(1));
      expect(analytics.lifecycles, hasLength(1));
      expect(repo.tracksOf(scope).single.endReason, SubTrackEndReason.deleted);
    });

    test('offline: the delete is queued, applied locally and acknowledged '
        'once', () async {
      repo.offline = true;
      final result = await commands.deleteSubTrack(ulidA);
      expect(result, isA<CaptureSuccess>());
      expect((result as CaptureSuccess).queued, isTrue);
      expect(repo.tracksOf(scope).single.endReason, SubTrackEndReason.deleted);
      repo.settleHeld();
      expect(repo.entries, hasLength(1));
    });

    test('offline: a queued end reports no analytics until the server '
        'accepts it, and whenConfirmed completes true', () async {
      repo.offline = true;
      final result = await commands.endSubTrack(ulidA) as CaptureSuccess;
      expect(result.queued, isTrue);
      expect(analytics.lifecycles, isEmpty, reason: 'queued is not accepted');
      final confirmed = commands.whenConfirmed(result.changeIds.single);
      repo.settleHeld();
      expect(await confirmed, isTrue);
      expect(analytics.lifecycles, hasLength(1));
      expect(analytics.lifecycles.single.action, SubTrackLifecycleAction.end);
      // Settled: a later ask answers at once.
      expect(await commands.whenConfirmed(result.changeIds.single), isTrue);
    });

    test(
      'offline: a queued delete the server refuses completes false, '
      'reports nothing, and its retry is accepted and reported once',
      () async {
        repo
          ..offline = true
          ..failNextWith(const PermanentWriteRejection('permission-denied'));
        final result = await commands.deleteSubTrack(ulidA) as CaptureSuccess;
        final changeId = result.changeIds.single;
        final confirmed = commands.whenConfirmed(changeId);
        repo.settleHeld();
        expect(await confirmed, isFalse);
        expect(repo.tracksOf(scope).single.endedAt, isNull, reason: 'reverted');
        expect(analytics.lifecycles, isEmpty);
        expect(commands.hasPendingFailure(changeId), isTrue);
        expect(await commands.whenConfirmed(changeId), isFalse);

        repo.offline = false;
        expect(await commands.retry(changeId), isA<CaptureSuccess>());
        expect(commands.hasPendingFailure(changeId), isFalse);
        expect(await commands.whenConfirmed(changeId), isTrue);
        expect(
          repo.tracksOf(scope).single.endReason,
          SubTrackEndReason.deleted,
        );
        expect(analytics.lifecycles, hasLength(1));
        expect(
          analytics.lifecycles.single.action,
          SubTrackLifecycleAction.delete,
        );
      },
    );

    test('a rebuild of the commands for the same learner keeps a queued write: '
        'it still settles, its refusal is a pending failure of the new '
        'commands, and the new commands retry it', () async {
      final ledger = SubTrackWriteLedger();
      SubTrackCommands build() => SubTrackCommands(
        scope: scope,
        actor: parentActor,
        subTracks: repo,
        intent: intent,
        today: () => _today,
        nowUtc: () => _now,
        newId: _ids(),
        analytics: analytics,
        ledger: ledger,
        ackTimeout: const Duration(milliseconds: 50),
        readTimeout: const Duration(seconds: 2),
      );
      final before = build();
      repo
        ..offline = true
        ..failNextWith(const PermanentWriteRejection('permission-denied'));
      final result = await before.deleteSubTrack(ulidA) as CaptureSuccess;
      final changeId = result.changeIds.single;
      final confirmed = before.whenConfirmed(changeId);
      await before.dispose();

      final after = build();
      final failures = after.watchPendingFailures();
      repo.settleHeld();
      expect(await confirmed, isFalse);
      expect(after.hasPendingFailure(changeId), isTrue);
      expect(
        (await failures.firstWhere((f) => f.isNotEmpty)).single.id,
        changeId,
      );
      expect(await after.whenConfirmed(changeId), isFalse);

      repo.offline = false;
      expect(await after.retry(changeId), isA<CaptureSuccess>());
      expect(after.hasPendingFailure(changeId), isFalse);
      expect(repo.tracksOf(scope).single.endReason, SubTrackEndReason.deleted);
      expect(analytics.lifecycles, hasLength(1));
      await after.dispose();
      await ledger.dispose();
    });

    test('offline: a queued Add next year reports add_next_year only once '
        'acknowledged', () async {
      repo.offline = true;
      final result =
          await commands.createSubTrack(_nextYear, nextYearOf: ulidA)
              as CaptureSuccess;
      expect(result.queued, isTrue);
      expect(analytics.lifecycles, isEmpty);
      repo.settleHeld();
      expect(await commands.whenConfirmed(result.changeIds.single), isTrue);
      expect(
        analytics.lifecycles.single.action,
        SubTrackLifecycleAction.addNextYear,
      );
    });

    test(
      'an already-ended source: a later delete writes nothing new',
      () async {
        repo.seed(scope, [
          _school(
            id: ulidB,
            academicYear: 2027,
            windowStart: '2027-09-01',
            windowEnd: '2028-07-31',
          ),
        ]);
        await commands.endSubTrack(ulidB);
        repo.calls.clear();
        expect(await commands.deleteSubTrack(ulidB), isA<CaptureSuccess>());
        expect(repo.calls, isEmpty);
      },
    );
  });

  group('LearningCommands surfaces a late sub-track rejection (AD-54)', () {
    late DefaultLearningCommands facade;

    setUp(() {
      facade = DefaultLearningCommands(
        scope: scope,
        actor: parentActor,
        reads: FakeLearningCommandReads(history: c0SettingsHistory()),
        writePort: InMemoryLearningWritePort(),
        gate: const LockWindowCaptureGate(),
        analytics: analytics,
        failureReporter: RecordingLearningFailureReporter(),
        clock: () => _now,
        newUlid: (_) => ulidD,
        subTrackCommands: commands,
      );
    });

    tearDown(() => facade.dispose());

    test('the refused queued end is a pending failure of the facade, its '
        'retry routes to the sub-track commands, and whenConfirmed tracks '
        'it', () async {
      final failures = <List<PendingFailure>>[];
      final sub = facade.watchPendingFailures().listen(failures.add);
      repo
        ..offline = true
        ..failNextWith(const PermanentWriteRejection('failed-precondition'));
      final result = await facade.endSubTrack(ulidA) as CaptureSuccess;
      expect(result.queued, isTrue);
      final changeId = result.changeIds.single;
      final confirmed = facade.whenSubTrackChangeConfirmed(changeId);
      repo.settleHeld();
      expect(await confirmed, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect([for (final f in failures.last) f.id], [changeId]);

      repo.offline = false;
      expect(await facade.retry(changeId), isA<CaptureSuccess>());
      await Future<void>.delayed(Duration.zero);
      expect(failures.last, isEmpty);
      expect(await facade.whenSubTrackChangeConfirmed(changeId), isTrue);
      expect(repo.tracksOf(scope).single.endReason, SubTrackEndReason.ended);
      expect(analytics.lifecycles, hasLength(1));
      await sub.cancel();
    });
  });

  group('engine: an explicit end returns ground and keeps every event', () {
    SubTrack sub(SubTrackEndReason? reason) => SubTrack(
      id: engineUlid(10),
      curriculumId: engineCurriculum,
      name: 'School',
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: 2,
      weeksPerYear: 40,
      learnsOnShabbos: false,
      ground: const [berakhot2],
      lastChangeId: engineUlid(11),
      endedAt: reason == null ? null : engineAt(5),
      endReason: reason,
    );

    test('delete/end both recompute the schedule; the event still counts', () {
      final events = [
        engineLearn(1, 'Mishnah Berakhot 2:1', source: engineUlid(10)),
      ];
      final before = List<LearningEvent>.of(events);
      final live = const LearnerStateEngine().run(
        engineInputs(events: events, subTracks: [sub(null)]),
      );
      expect(
        live[engineCurriculum]!.schedulableRefs,
        isNot(contains('Mishnah Berakhot 2:2')),
      );
      for (final reason in [
        SubTrackEndReason.deleted,
        SubTrackEndReason.ended,
      ]) {
        final ended = const LearnerStateEngine().run(
          engineInputs(events: events, subTracks: [sub(reason)]),
        );
        final state = ended[engineCurriculum]!;
        expect(state.schedulableRefs, contains('Mishnah Berakhot 2:2'));
        expect(state.schedulableRefs, isNot(contains('Mishnah Berakhot 2:1')));
        expect(
          state.mainTrackRemaining,
          live[engineCurriculum]!.mainTrackRemaining + 1,
        );
        expect(ended.countedEventIds, {engineUlid(1)});
      }
      expect(events, before);
    });
  });
}
