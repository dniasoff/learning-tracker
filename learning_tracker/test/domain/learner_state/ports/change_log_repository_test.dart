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

  final orderA = GovernedDocMerge(
    collection: 'track_learning_order',
    docId: 'mishnayos_masechta_a',
    fields: {'user_sort_order': 2},
  );
  final orderB = GovernedDocMerge(
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
        merges: [orderA, orderB],
      );
      expect(batch.merges, [orderA, orderB]);
      expect(
        batch,
        GovernedBatch(entry: entry(matchingAfter), merges: [orderA, orderB]),
      );
    });

    test('rejects a missing or extra entry.after key', () {
      expect(
        () => GovernedBatch(entry: entry(matchingAfter), merges: [orderA]),
        throwsArgumentError,
      );
      expect(
        () => GovernedBatch(
          entry: entry({...matchingAfter, 'track_learning_order/x.y': 1}),
          merges: [orderA, orderB],
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
          merges: [orderA, orderB],
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
          merges: [orderA, orderA, orderB],
        ),
        throwsArgumentError,
      );
      final sneaky = GovernedDocMerge(
        collection: 'track_learning_order',
        docId: 'mishnayos_masechta_a',
        fields: {'last_change_id': ulidD},
      );
      expect(
        () => GovernedBatch(
          entry: entry({
            'track_learning_order/mishnayos_masechta_a.last_change_id': ulidD,
          }),
          merges: [sneaky],
        ),
        throwsArgumentError,
      );
    });

    test('snapshots merge fields: mutating the source map after '
        'construction does not change the validated batch', () {
      final ended = DateTime.utc(2026, 3, 1);
      final source = <String, Object?>{
        'user_sort_order': 2,
        'stages': <Object?>[
          <String, Object?>{'id': 's1', 'ended_at': ended},
        ],
      };
      final merge = GovernedDocMerge(
        collection: 'track_learning_order',
        docId: 'mishnayos_masechta_a',
        fields: source,
      );
      final after = <String, Object?>{
        'track_learning_order/mishnayos_masechta_a.user_sort_order': 2,
        'track_learning_order/mishnayos_masechta_a.stages': [
          {'id': 's1', 'ended_at': ended},
        ],
      };
      final batch = GovernedBatch(entry: entry(after), merges: [merge]);

      // Mutate the caller's maps and lists, top level and nested, after
      // the merge and the batch were built.
      source['user_sort_order'] = 99;
      source['sneaky'] = 'x';
      final stages = source['stages']! as List<Object?>;
      (stages.single! as Map<String, Object?>)['id'] = 'tampered';
      stages.add('extra');
      after['track_learning_order/mishnayos_masechta_a.user_sort_order'] = 7;

      final patch = batch.merges.single.toMergePatch(batch.entry.id);
      expect(patch, {
        'user_sort_order': 2,
        'stages': [
          {'id': 's1', 'ended_at': ended},
        ],
        'last_change_id': ulidD,
      });
      // The applied write still matches the audit entry exactly.
      batch.merges.single.fields.forEach((field, value) {
        final key = 'track_learning_order/mishnayos_masechta_a.$field';
        expect(batch.entry.after[key], value);
      });
      expect(batch.entry.after, hasLength(2));
    });

    test('merge fields and entry.after are deeply unmodifiable', () {
      final merge = GovernedDocMerge(
        collection: 'track_learning_order',
        docId: 'mishnayos_masechta_a',
        fields: {
          'user_sort_order': 2,
          'stages': <Object?>[
            <String, Object?>{'id': 's1'},
          ],
        },
      );
      final batch = GovernedBatch(
        entry: entry({
          'track_learning_order/mishnayos_masechta_a.user_sort_order': 2,
          'track_learning_order/mishnayos_masechta_a.stages': [
            {'id': 's1'},
          ],
        }),
        merges: [merge],
      );
      final fields = batch.merges.single.fields;
      expect(() => fields['user_sort_order'] = 3, throwsUnsupportedError);
      final stages = fields['stages']! as List<Object?>;
      expect(() => stages.add('x'), throwsUnsupportedError);
      expect(
        () => (stages.single! as Map<String, Object?>)['id'] = 'x',
        throwsUnsupportedError,
      );
      final afterStages =
          batch.entry.after['track_learning_order/mishnayos_masechta_a.stages']!
              as List<Object?>;
      expect(() => afterStages.add('x'), throwsUnsupportedError);
      expect(() => batch.merges.add(merge), throwsUnsupportedError);
    });

    test('rejects a subTrack entry', () {
      final merge = GovernedDocMerge(
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
          merges: [merge],
        ),
        throwsArgumentError,
      );
    });
  });
}
