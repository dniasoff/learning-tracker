/// Direct tests of `SubTrackCommands` (Story 2.1 / DNI-492 and follow-ups):
/// the rollover, edit-semantics, ledger and static-helper surface that the
/// facade-level `learning_commands_sub_track_test.dart` does not pin.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _berakhot = NodeEntry(level: 'masechta', ref: 'Berakhot');
const _shabbat = NodeEntry(level: 'masechta', ref: 'Shabbat');
final _now = DateTime.utc(2026, 10, 1, 9);

String Function() _ids() {
  var n = 0;
  return () => '01JTEST000000000000000${(++n).toString().padLeft(4, '0')}';
}

SubTrackDraft _draft({
  String curriculumId = 'shas',
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String windowStart = '2026-09-01',
  String? windowEnd,
}) => SubTrackDraft(
  curriculumId: curriculumId,
  name: 'Night seder',
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [_berakhot],
);

SubTrack _stored(
  String id, {
  String curriculumId = 'shas',
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String? windowEnd,
  bool ended = false,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: 'Stored $id',
  type: type,
  academicYear: academicYear,
  windowStart: '2026-09-01',
  windowEnd: windowEnd,
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [_berakhot],
  lastChangeId: ulidE,
  endedAt: ended ? t1 : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

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
  late SubTrackCommands commands;

  SubTrackCommands build({SubTrackWriteLedger? ledger}) => SubTrackCommands(
    scope: scope,
    actor: parentActor,
    subTracks: repo,
    intent: intent,
    today: () => '2026-10-01',
    nowUtc: () => _now,
    newId: _ids(),
    ledger: ledger,
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

  group('create', () {
    test(
      'an existing id is refused as invalid and nothing is written',
      () async {
        repo.seed(scope, [_stored(ulidA)]);
        expect(
          await commands.createSubTrack(_draft(), subTrackId: ulidA),
          const CaptureResult.rejected(CaptureRejection.invalid),
        );
        expect(repo.entries, isEmpty);
      },
    );

    test('a parent create is written and not queued online', () async {
      final result = await commands.createSubTrack(_draft());
      expect(result, isA<CaptureSuccess>());
      expect((result as CaptureSuccess).queued, isFalse);
      expect(repo.tracksOf(scope), hasLength(1));
    });

    test('a candidate the storage codec rejects is invalid', () async {
      // An ongoing track must not carry an academic year (AD-52).
      final result = await commands.createSubTrack(_draft(academicYear: 2026));
      expect(result, isA<CaptureRejected>());
      expect(repo.entries, isEmpty);
    });
  });

  group('Add next year (nextYearOf)', () {
    test('a missing source is targetNotFound', () async {
      expect(
        await commands.createSubTrack(
          _draft(
            type: SubTrackType.schoolYear,
            academicYear: 2027,
            windowEnd: '2027-06-30',
          ),
          nextYearOf: ulidD,
        ),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(repo.entries, isEmpty);
    });

    test(
      'an ended, non-school-year or foreign source is targetNotFound',
      () async {
        repo.seed(scope, [
          _stored(
            ulidA,
            type: SubTrackType.schoolYear,
            academicYear: 2026,
            windowEnd: '2027-06-30',
            ended: true,
          ),
          _stored(ulidB),
        ]);
        for (final source in [ulidA, ulidB]) {
          expect(
            await commands.createSubTrack(
              _draft(
                type: SubTrackType.schoolYear,
                academicYear: 2027,
                windowEnd: '2027-06-30',
              ),
              nextYearOf: source,
            ),
            const CaptureResult.rejected(CaptureRejection.targetNotFound),
            reason: source,
          );
        }
        expect(repo.entries, isEmpty);
      },
    );

    test('a live school-year source is never written', () async {
      repo.seed(scope, [
        _stored(
          ulidA,
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowEnd: '2027-06-30',
        ),
      ]);
      final result = await commands.createSubTrack(
        _draft(
          type: SubTrackType.schoolYear,
          academicYear: 2027,
          windowStart: '2027-09-01',
          windowEnd: '2028-06-30',
        ),
        nextYearOf: ulidA,
      );
      expect(result, isA<CaptureSuccess>());
      expect(repo.entries.single.$2.entityId, isNot(ulidA));
      expect(
        repo.tracksOf(scope).firstWhere((t) => t.id == ulidA).name,
        'Stored $ulidA',
      );
    });
  });

  group('edit', () {
    test(
      'turning a school year ongoing clears academic_year and logs null',
      () async {
        repo.seed(scope, [
          _stored(
            ulidA,
            type: SubTrackType.schoolYear,
            academicYear: 2026,
            windowEnd: '2027-06-30',
          ),
        ]);
        final result = await commands.editSubTrack(
          ulidA,
          const SubTrackEdit(
            type: SubTrackType.ongoing,
            clearAcademicYear: true,
            clearWindowEnd: true,
          ),
        );
        expect(result, isA<CaptureSuccess>());
        final entry = repo.entries.single.$2;
        expect(entry.after['sub_tracks/$ulidA.academic_year'], isNull);
        expect(entry.before['sub_tracks/$ulidA.academic_year'], 2026);
        expect(entry.after['sub_tracks/$ulidA.type'], 'ongoing');
        final stored = repo.tracksOf(scope).single;
        expect(stored.academicYear, isNull);
        expect(stored.windowEnd, isNull);
      },
    );

    test(
      'a ground edit that equals the stored ground writes nothing',
      () async {
        repo.seed(scope, [_stored(ulidA)]);
        expect(
          await commands.editSubTrack(
            ulidA,
            const SubTrackEdit(ground: [_berakhot]),
          ),
          const CaptureResult.success(),
        );
        expect(repo.entries, isEmpty);
      },
    );

    test(
      'an appendGround edit with no corpus is invalid, nothing written',
      () async {
        repo.seed(scope, [_stored(ulidA)]);
        expect(
          await commands.editSubTrack(
            ulidA,
            const SubTrackEdit(appendGround: [_shabbat]),
          ),
          const CaptureResult.rejected(CaptureRejection.invalid),
        );
        expect(repo.entries, isEmpty);
      },
    );

    test('appendGround together with ground is invalid', () async {
      repo.seed(scope, [_stored(ulidA)]);
      expect(
        await commands.editSubTrack(
          ulidA,
          const SubTrackEdit(ground: [_shabbat], appendGround: [_shabbat]),
        ),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
    });
  });

  group('static helpers', () {
    test('intentFieldsOf lists every governed field but the tombstone', () {
      final fields = SubTrackCommands.intentFieldsOf(_stored(ulidA));
      expect(
        fields.keys,
        containsAll(<String>[
          'curriculum_id',
          'name',
          'type',
          'academic_year',
          'window_start',
          'window_end',
          'rate_per_week',
          'weeks_per_year',
          'learns_on_shabbos',
          'ground',
        ]),
      );
      expect(fields.keys, isNot(contains('ended_at')));
      expect(fields.keys, isNot(contains('end_reason')));
      expect(fields['ground'], [
        {'level': 'masechta', 'ref': 'Berakhot'},
      ]);
    });

    test('applyEdit changes only what the edit names and keeps identity', () {
      final track = _stored(ulidA, ended: true);
      final edited = SubTrackCommands.applyEdit(
        track,
        const SubTrackEdit(name: 'Renamed', ratePerWeek: 9),
      );
      expect(edited.name, 'Renamed');
      expect(edited.ratePerWeek, 9);
      expect(edited.weeksPerYear, track.weeksPerYear);
      expect(edited.id, track.id);
      expect(edited.curriculumId, track.curriculumId);
      expect(edited.endedAt, track.endedAt);
      expect(edited.lastChangeId, track.lastChangeId);
    });

    test('applyEdit replaces ground whole and can clear the window end', () {
      final track = _stored(ulidA, windowEnd: '2027-01-01');
      final edited = SubTrackCommands.applyEdit(
        track,
        const SubTrackEdit(ground: [_shabbat], clearWindowEnd: true),
      );
      expect(edited.ground, [_shabbat]);
      expect(edited.windowEnd, isNull);
    });
  });

  group('pending failures and confirmation', () {
    Future<String> queuedRefusedCreate(SubTrackCommands target) async {
      repo
        ..offline = true
        ..failNextWith(const PermanentWriteRejection('permission-denied'));
      final result = await target.createSubTrack(_draft(), subTrackId: ulidD);
      final id = (result as CaptureSuccess).changeIds.single;
      repo.settleHeld();
      await Future<void>.delayed(Duration.zero);
      repo.offline = false;
      return id;
    }

    test(
      'whenConfirmed is true for an unknown or acknowledged change',
      () async {
        expect(await commands.whenConfirmed('never-queued'), isTrue);
        final result = await commands.createSubTrack(_draft());
        expect(
          await commands.whenConfirmed(
            (result as CaptureSuccess).changeIds.single,
          ),
          isTrue,
        );
      },
    );

    test(
      'whenConfirmed waits for a queued write and reports acceptance',
      () async {
        repo.offline = true;
        final result = await commands.createSubTrack(_draft());
        final id = (result as CaptureSuccess).changeIds.single;
        var settled = false;
        final confirmed = commands.whenConfirmed(id);
        confirmed.then((_) => settled = true).ignore();
        await Future<void>.delayed(Duration.zero);
        expect(settled, isFalse);
        repo.settleHeld();
        expect(await confirmed, isTrue);
      },
    );

    test(
      'a refused queued write is a pending failure and unconfirmed',
      () async {
        final id = await queuedRefusedCreate(commands);
        expect(commands.hasPendingFailure(id), isTrue);
        expect(await commands.whenConfirmed(id), isFalse);
        expect(commands.hasPendingFailure('other'), isFalse);
      },
    );

    test('retry of an unknown id is targetNotFound', () async {
      expect(
        await commands.retry('missing'),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
    });

    test('a successful retry clears the pending failure', () async {
      final id = await queuedRefusedCreate(commands);
      expect(await commands.retry(id), isA<CaptureSuccess>());
      expect(commands.hasPendingFailure(id), isFalse);
      expect(await commands.watchPendingFailures().first, isEmpty);
    });

    test('a shared ledger keeps the retry across a rebuilt commands', () async {
      final ledger = SubTrackWriteLedger();
      addTearDown(ledger.dispose);
      final first = build(ledger: ledger);
      final id = await queuedRefusedCreate(first);
      await first.dispose(); // does not own the ledger: stays open

      final second = build(ledger: ledger);
      expect(second.hasPendingFailure(id), isTrue);
      expect(await second.watchPendingFailures().first, hasLength(1));
      expect(await second.retry(id), isA<CaptureSuccess>());
      expect(repo.tracksOf(scope).single.id, ulidD);
    });
  });
}
