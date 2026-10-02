/// DNI-470 AC-3: the `ownerOversizedGovernedWrite` adapter encodes the
/// complete ordered action on the callable's wire shape and maps "no
/// connection" to OnlineRequiredException. The callable itself is
/// verified by Story 1.10 (DNI-472), not here.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/callable_oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

final _request = OversizedGovernedWrite(
  actionId: ulidA,
  actorRole: ActorRole.child,
  revertsActionId: ulidC,
  entries: [
    const OversizedGovernedEntry(
      entryId: ulidA,
      change: GovernedEntityChange(
        entity: GovernedEntity.mainTrackOrder,
        entityId: 'mishnayos',
        docs: [
          GovernedDocPatch(
            collection: 'track_learning_order',
            docId: 'o1',
            fields: {'user_sort_order': 2, 'curriculum_id': 'mishnayos'},
            mode: DocMode.create,
          ),
        ],
      ),
    ),
    OversizedGovernedEntry(
      entryId: ulidB,
      change: GovernedEntityChange(
        entity: GovernedEntity.goal,
        entityId: 'g',
        docs: [
          GovernedDocPatch(
            collection: 'goals',
            docId: 'g',
            fields: {'ended_at': t1, 'pace_value': null},
          ),
        ],
      ),
    ),
  ],
);

void main() {
  test('encodes the complete ordered action; a tombstone is `true`; '
      'ownerUid is never sent', () async {
    Map<String, Object?>? sent;
    final port = CallableOversizedGovernedWritePort.withInvoker((payload) async {
      sent = payload;
      return {
        'success': true,
        'action_id': ulidA,
        'change_ids': [ulidA, ulidB],
        'at': '2026-09-02T09:00:00.000Z',
        'replayed': true,
        'noop': false,
      };
    });

    final receipt = await port.write(c0Scope(), _request);

    expect(sent, {
      'profileId': profileUlid,
      'actorRole': 'child',
      'actionId': ulidA,
      'revertsActionId': ulidC,
      'entries': [
        {
          'id': ulidA,
          'entity': 'mainTrackOrder',
          'entityId': 'mishnayos',
          'docs': [
            {
              'collection': 'track_learning_order',
              'docId': 'o1',
              'fields': {'user_sort_order': 2, 'curriculum_id': 'mishnayos'},
              'mode': 'create',
            },
          ],
        },
        {
          'id': ulidB,
          'entity': 'goal',
          'entityId': 'g',
          'docs': [
            {
              'collection': 'goals',
              'docId': 'g',
              'fields': {'ended_at': true, 'pace_value': null},
              'mode': 'upsert',
            },
          ],
        },
      ],
    });
    expect(receipt.actionId, ulidA);
    expect(receipt.changeIds, [ulidA, ulidB]);
    expect(receipt.at, t1);
    expect(receipt.replayed, isTrue);
    expect(receipt.noop, isFalse);
  });

  test('no connection is OnlineRequiredException; any other callable error '
      'is a PermanentWriteRejection with its code', () async {
    for (final code in CallableOversizedGovernedWritePort.offlineCodes) {
      final port = CallableOversizedGovernedWritePort.withInvoker(
        (_) async => throw FirebaseFunctionsException(message: 'x', code: code),
      );
      await expectLater(
        port.write(c0Scope(), _request),
        throwsA(isA<OnlineRequiredException>()),
      );
    }
    final port = CallableOversizedGovernedWritePort.withInvoker(
      (_) async => throw FirebaseFunctionsException(
        message: 'x',
        code: 'permission-denied',
      ),
    );
    await expectLater(
      port.write(c0Scope(), _request),
      throwsA(
        isA<PermanentWriteRejection>().having(
          (r) => r.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });
}
