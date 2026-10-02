// Mirror test for
// `lib/domain/learner_state/ports/change_log_repository.dart`
// (C0, DNI-524 AC-6: GovernedBatch validation).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';

import '../../../helpers/learner_state_fixtures.dart';

void main() {
  ChangeLogEntry entry(
    Map<String, Object?> after, {
    GovernedEntity entity = GovernedEntity.mainTrackOrder,
    String entityId = 'mishnayos',
  }) => ChangeLogEntry(
    id: ulidD,
    entity: entity,
    entityId: entityId,
    actionId: ulidD,
    before: {for (final k in after.keys) k: null},
    after: after,
    at: t1,
    actor: parentActor,
  );

  const orderA = GovernedDocMerge(
    collection: 'track_learning_order',
    docId: 'mishnayos_masechta_a',
    fields: {'user_sort_order': 2},
  );
  const orderB = GovernedDocMerge(
    collection: 'track_learning_order',
    docId: 'mishnayos_masechta_b',
    fields: {'user_sort_order': 1, 'ended_at': null},
  );
  final matchingAfter = <String, Object?>{
    'track_learning_order/mishnayos_masechta_a.user_sort_order': 2,
    'track_learning_order/mishnayos_masechta_b.user_sort_order': 1,
    'track_learning_order/mishnayos_masechta_b.ended_at': null,
  };

  test('intentHistoryEntities is the AD-37 intent set', () {
    expect(intentHistoryEntities, {
      GovernedEntity.learnerSettings,
      GovernedEntity.mainTrackOrder,
      GovernedEntity.mainTrackProgram,
      GovernedEntity.mainTrackStages,
      GovernedEntity.mainTrackStudyDays,
    });
  });

  test('toMergePatch adds last_change_id', () {
    expect(orderB.toMergePatch(ulidD), {
      'user_sort_order': 1,
      'ended_at': null,
      'last_change_id': ulidD,
    });
  });

  group('GovernedBatch validation', () {
    test('accepts merges that match entry.after exactly', () {
      final batch = GovernedBatch(
        entry: entry(matchingAfter),
        merges: const [orderA, orderB],
      );
      expect(batch.merges, const [orderA, orderB]);
      expect(
        batch,
        GovernedBatch(
          entry: entry(matchingAfter),
          merges: const [orderA, orderB],
        ),
      );
    });

    test('rejects a missing or extra entry.after key', () {
      expect(
        () =>
            GovernedBatch(entry: entry(matchingAfter), merges: const [orderA]),
        throwsArgumentError,
      );
      expect(
        () => GovernedBatch(
          entry: entry({...matchingAfter, 'track_learning_order/x.y': 1}),
          merges: const [orderA, orderB],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an entry.after value that differs from the merge', () {
      expect(
        () => GovernedBatch(
          entry: entry({
            ...matchingAfter,
            'track_learning_order/mishnayos_masechta_a.user_sort_order': 3,
          }),
          merges: const [orderA, orderB],
        ),
        throwsArgumentError,
      );
    });

    test('rejects more than 10 docs (AD-54)', () {
      final merges = [
        for (var i = 0; i < 11; i++)
          GovernedDocMerge(
            collection: 'track_learning_order',
            docId: 'mishnayos_masechta_$i',
            fields: const {'user_sort_order': 1},
          ),
      ];
      final after = {
        for (var i = 0; i < 11; i++)
          'track_learning_order/mishnayos_masechta_$i.user_sort_order': 1,
      };
      expect(
        () => GovernedBatch(entry: entry(after), merges: merges),
        throwsArgumentError,
      );
      expect(
        GovernedBatch(
          entry: entry(Map.fromEntries(after.entries.take(10))),
          merges: merges.take(10).toList(),
        ).merges,
        hasLength(GovernedBatch.maxDocs),
      );
    });

    test('rejects a repeated doc and a merge that sets last_change_id', () {
      expect(
        () => GovernedBatch(
          entry: entry(matchingAfter),
          merges: const [orderA, orderA, orderB],
        ),
        throwsArgumentError,
      );
      const sneaky = GovernedDocMerge(
        collection: 'track_learning_order',
        docId: 'mishnayos_masechta_a',
        fields: {'last_change_id': ulidD},
      );
      expect(
        () => GovernedBatch(
          entry: entry({
            'track_learning_order/mishnayos_masechta_a.last_change_id': ulidD,
          }),
          merges: const [sneaky],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a subTrack entry', () {
      const merge = GovernedDocMerge(
        collection: 'sub_tracks',
        docId: ulidB,
        fields: {'rate_per_week': 5},
      );
      expect(
        () => GovernedBatch(
          entry: entry(
            {'sub_tracks/$ulidB.rate_per_week': 5},
            entity: GovernedEntity.subTrack,
            entityId: ulidB,
          ),
          merges: const [merge],
        ),
        throwsArgumentError,
      );
    });
  });
}
