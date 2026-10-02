/// Unit tests for [ChangeLogEntry] and [ChangedFieldKey].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

ChangeLogEntry _entry({
  GovernedEntity entity = GovernedEntity.subTrack,
  Map<String, Object?>? before,
  Map<String, Object?>? after,
  String actionId = ulidD,
}) => ChangeLogEntry(
  id: ulidA,
  entity: entity,
  entityId: ulidB,
  actionId: actionId,
  before: before ?? {'sub_tracks/$ulidB.name': null},
  after: after ?? {'sub_tracks/$ulidB.name': 'Shiur'},
  at: t0,
  actor: parentActor,
);

void main() {
  test('entity enum maps each AD-38 entity to its collection', () {
    expect(
      {for (final e in GovernedEntity.values) e.storage: e.collection},
      {
        'subTrack': 'sub_tracks',
        'goal': 'goals',
        'mainTrack': 'curriculum_tracks',
        'mainTrackOrder': 'track_learning_order',
        'mainTrackProgram': 'profile_programs',
        'mainTrackStudyDays': 'study_day_configs',
        'mainTrackStages': 'stage_definitions',
        'mainTrackScope': 'curriculum_scopes',
        'learnerSettings': 'learner_profiles',
      },
    );
  });

  test('ChangedFieldKey parses {collection}/{docId}.{field}', () {
    final key = ChangedFieldKey.tryParse(
      'track_learning_order/mishnayos_perek_Mishnah Peah 1.user_sort_order',
    )!;
    expect(key.collection, 'track_learning_order');
    expect(key.docId, 'mishnayos_perek_Mishnah Peah 1');
    expect(key.field, 'user_sort_order');
    expect(key.key, contains('.user_sort_order'));
    for (final bad in ['no_slash.field', '/doc.f', 'c/.f', 'c/doc.', 'c/doc']) {
      expect(ChangedFieldKey.tryParse(bad), isNull, reason: bad);
    }
  });

  test('round-trips and keeps changedKeys parsed', () {
    final entry = _entry();
    expect(ChangeLogEntry.fromStorage(ulidA, entry.toStorage()), entry);
    expect(entry.changedKeys.single.field, 'name');
  });

  test('rejects empty after, non-ULID action id, cross-collection keys', () {
    expect(
      () => _entry(before: {}, after: {}).toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => _entry(actionId: 'x').toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => _entry(entity: GovernedEntity.goal).toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('rejects a changed field on a document other than entity_id for '
      'single-doc entities (subTrack, goal, learnerSettings)', () {
    // Claims sub-track B, but the changed field addresses sub-track C.
    expect(
      () => _entry(
        before: {'sub_tracks/$ulidC.name': null},
        after: {'sub_tracks/$ulidC.name': 'Shiur'},
      ).toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
    // Mixed: one key on the entity doc, one on another doc.
    expect(
      () => _entry(
        before: {'sub_tracks/$ulidB.name': null, 'sub_tracks/$ulidC.name': 'x'},
        after: {'sub_tracks/$ulidB.name': 'a', 'sub_tracks/$ulidC.name': 'y'},
      ).toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => _entry(
        entity: GovernedEntity.goal,
        before: {'goals/other_deadline.target': null},
        after: {'goals/other_deadline.target': 1},
      ).toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => ChangeLogEntry(
        id: ulidA,
        entity: GovernedEntity.learnerSettings,
        entityId: profileUlid,
        actionId: ulidA,
        before: {'learner_profiles/$ulidC.time_zone': null},
        after: {'learner_profiles/$ulidC.time_zone': 'Asia/Jerusalem'},
        at: t0,
        actor: parentActor,
      ).toStorage(),
      throwsA(isA<StorageFormatException>()),
    );
    // Decode is strict too: a stored mismatched entry does not decode.
    final stored = _entry().toStorage()..[ChangeLogEntry.kEntityId] = ulidC;
    expect(
      () => ChangeLogEntry.fromStorage(ulidA, stored),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('mainTrack* entries key by curriculumId and may cover several docs '
      'of their collection', () {
    final entry = ChangeLogEntry(
      id: ulidA,
      entity: GovernedEntity.mainTrackOrder,
      entityId: 'mishnayos',
      actionId: ulidA,
      before: {
        'track_learning_order/mishnayos_perek_1.user_sort_order': 1,
        'track_learning_order/mishnayos_perek_2.user_sort_order': 2,
      },
      after: {
        'track_learning_order/mishnayos_perek_1.user_sort_order': 2,
        'track_learning_order/mishnayos_perek_2.user_sort_order': 1,
      },
      at: t0,
      actor: parentActor,
    );
    expect(ChangeLogEntry.fromStorage(ulidA, entry.toStorage()), entry);
  });

  test('learnerSettings entries use learner_profiles keys', () {
    final entry = ChangeLogEntry(
      id: ulidA,
      entity: GovernedEntity.learnerSettings,
      entityId: profileUlid,
      actionId: ulidA,
      before: {'learner_profiles/$profileUlid.time_zone': null},
      after: {'learner_profiles/$profileUlid.time_zone': 'Asia/Jerusalem'},
      at: t0,
      actor: parentActor,
    );
    expect(entry.toStorage()['entity'], 'learnerSettings');
  });
}
