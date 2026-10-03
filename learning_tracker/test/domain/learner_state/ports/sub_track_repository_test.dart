/// Unit tests for [SubTrackChange] — the governed sub-track write value
/// the [SubTrackRepository] port accepts.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../../helpers/learner_state_fixtures.dart';

ChangeLogEntry _entry(
  Map<String, Object?> after, {
  GovernedEntity? entity,
  String entityId = ulidB,
}) => ChangeLogEntry(
  id: ulidA,
  entity: entity ?? GovernedEntity.subTrack,
  entityId: entityId,
  actionId: ulidA,
  before: {for (final k in after.keys) k: null},
  after: after,
  at: t0,
  actor: parentActor,
);

void main() {
  test('field change: merge patch = changed fields + last_change_id', () {
    final change = SubTrackChange.fields(
      subTrackId: ulidB,
      changedFields: {'rate_per_week': 9},
      entry: _entry({'sub_tracks/$ulidB.rate_per_week': 9}),
    );
    expect(change.toMergePatch(), {
      'rate_per_week': 9,
      'last_change_id': ulidA,
    });
  });

  test('snapshots changed fields: later source-map mutation cannot '
      'desync the merge patch from entry.after', () {
    final source = <String, Object?>{'rate_per_week': 9};
    final change = SubTrackChange.fields(
      subTrackId: ulidB,
      changedFields: source,
      entry: _entry({'sub_tracks/$ulidB.rate_per_week': 9}),
    );
    source['rate_per_week'] = 1;
    source['name'] = 'x';
    expect(change.toMergePatch(), {
      'rate_per_week': 9,
      'last_change_id': ulidA,
    });
    expect(change.entry.after, {'sub_tracks/$ulidB.rate_per_week': 9});
  });

  group('create (DNI-482: AD-49 replay writes sub-tracks under fresh ids)', () {
    test('is a create with an all-null baseline', () {
      final change = SubTrackChange.create(
        subTrackId: ulidB,
        changedFields: {'name': 'Shiur'},
        entry: _entry({'sub_tracks/$ulidB.name': 'Shiur'}),
      );
      expect(change.isCreate, isTrue);
      expect(
        SubTrackChange.fields(
          subTrackId: ulidB,
          changedFields: {'name': 'Shiur'},
          entry: _entry({'sub_tracks/$ulidB.name': 'Shiur'}),
        ).isCreate,
        isFalse,
      );
    });

    test('rejects a non-null before and a tombstone', () {
      expect(
        () => SubTrackChange.create(
          subTrackId: ulidB,
          changedFields: {'name': 'Shiur'},
          entry: ChangeLogEntry(
            id: ulidA,
            entity: GovernedEntity.subTrack,
            entityId: ulidB,
            actionId: ulidA,
            before: {'sub_tracks/$ulidB.name': 'Old'},
            after: {'sub_tracks/$ulidB.name': 'Shiur'},
            at: t0,
            actor: parentActor,
          ),
        ),
        throwsA(isA<StorageFormatException>()),
      );
      expect(
        () => SubTrackChange.create(
          subTrackId: ulidB,
          changedFields: {'ended_at': t1, 'end_reason': 'ended'},
          entry: _entry({
            'sub_tracks/$ulidB.ended_at': t1,
            'sub_tracks/$ulidB.end_reason': 'ended',
          }),
        ),
        throwsA(isA<StorageFormatException>()),
      );
    });
  });

  test('tombstone sets ended_at and end_reason together', () {
    final change = SubTrackChange.tombstone(
      subTrackId: ulidB,
      endedAt: t1,
      reason: SubTrackEndReason.deleted,
      entry: _entry({
        'sub_tracks/$ulidB.ended_at': t1,
        'sub_tracks/$ulidB.end_reason': 'deleted',
      }),
    );
    expect(change.toMergePatch(), {
      'ended_at': t1,
      'end_reason': 'deleted',
      'last_change_id': ulidA,
    });
  });

  test('re-activation clears both together', () {
    final change = SubTrackChange.fields(
      subTrackId: ulidB,
      changedFields: {'ended_at': null, 'end_reason': null},
      entry: _entry({
        'sub_tracks/$ulidB.ended_at': null,
        'sub_tracks/$ulidB.end_reason': null,
      }),
    );
    expect(change.toMergePatch()['ended_at'], isNull);
  });

  test('rejects inconsistent tombstones, mismatched entries, bad fields', () {
    final cases = <String, SubTrackChange Function()>{
      'ended_at without end_reason': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'ended_at': t1},
        entry: _entry({'sub_tracks/$ulidB.ended_at': t1}),
      ),
      'ended_at set but end_reason cleared': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'ended_at': t1, 'end_reason': null},
        entry: _entry({
          'sub_tracks/$ulidB.ended_at': t1,
          'sub_tracks/$ulidB.end_reason': null,
        }),
      ),
      'entry for another entity': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'name': 'x'},
        entry: ChangeLogEntry(
          id: ulidA,
          entity: GovernedEntity.goal,
          entityId: ulidB,
          actionId: ulidA,
          before: const {'goals/x.name': null},
          after: const {'goals/x.name': 'x'},
          at: t0,
          actor: parentActor,
        ),
      ),
      'entry for another sub-track': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'name': 'x'},
        entry: _entry({'sub_tracks/$ulidC.name': 'x'}, entityId: ulidC),
      ),
      'entry fields differ from change': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'name': 'x', 'rate_per_week': 2},
        entry: _entry({'sub_tracks/$ulidB.name': 'x'}),
      ),
      'entry value differs': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'name': 'x'},
        entry: _entry({'sub_tracks/$ulidB.name': 'y'}),
      ),
      'last_change_id set directly': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {'last_change_id': ulidC},
        entry: _entry({'sub_tracks/$ulidB.last_change_id': ulidC}),
      ),
      'no fields': () => SubTrackChange.fields(
        subTrackId: ulidB,
        changedFields: {},
        entry: _entry({'sub_tracks/$ulidB.name': 'x'}),
      ),
      'non-ULID id': () => SubTrackChange.fields(
        subTrackId: 'x',
        changedFields: {'name': 'x'},
        entry: _entry({'sub_tracks/x.name': 'x'}, entityId: 'x'),
      ),
    };
    for (final entry in cases.entries) {
      expect(
        entry.value,
        throwsA(isA<StorageFormatException>()),
        reason: entry.key,
      );
    }
  });
}
