// Story 1.24 (DNI-486) AC-8 — the tutor and the parent edit the same
// main-track field at about the same time. Both commit; the later SERVER
// commit wins for that field (LWW per field by commit order, NFR-4, AD-38),
// both change_log entries remain, and the tutor's next read shows the
// winning value with no merge prompt: the tutor write path carries no
// conflict signal back to the form.
//
// The callable side is an in-memory stand-in for writeWithChangeLog's
// contract (field-level merge, one change_log entry per action, commit
// order = call order); the real transaction is covered by the Story 1.10
// emulator tests.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/tutoring/tutor_learning_harness.dart';

/// A governed doc store applying field-level merges in commit order and
/// logging one change_log entry per action.
final class _Server {
  final docs = <String, Map<String, Object?>>{};
  final changeLog =
      <({String actionId, String actor, Map<String, Object?> after})>[];

  Map<String, Object?> commit({
    required String actor,
    required String actionId,
    required String docId,
    required Map<String, Object?> fields,
  }) {
    final doc = docs.putIfAbsent(docId, () => {});
    doc.addAll(fields); // LWW per field: this commit is the latest.
    changeLog.add((actionId: actionId, actor: actor, after: {...fields}));
    return {
      'success': true,
      'action_id': actionId,
      'change_ids': [actionId],
      'replayed': false,
    };
  }

  /// The "next read" of a doc.
  Map<String, Object?> read(String docId) => {...?docs[docId]};
}

void main() {
  const goalId = 'mishnayos_1727740800000';

  late _Server server;
  late TutorHarness h;

  setUp(() {
    server = _Server();
    h = TutorHarness();
    h.invoker.respond = (call) => server.commit(
      actor: 'tutor',
      actionId: call.args['actionId'] as String,
      docId: call.args['goalId'] as String,
      fields: Map<String, Object?>.of(
        call.args['goalData'] as Map<String, Object?>,
      ),
    );
  });
  tearDown(() => h.dispose());

  void parentCommit(String description) => server.commit(
    actor: 'parent',
    actionId: '01ARZ3NDEKTSV4RRFFQ69GPA${server.changeLog.length}0',
    docId: goalId,
    fields: {'description': description},
  );

  test('the parent commits after the tutor: the parent value wins, both '
      'entries remain, the tutor write completed without a prompt', () async {
    await h.governed.upsertGoal(
      goalId: goalId,
      data: const {'description': 'Tutor: 2 per day', 'pace_value': 2},
    );
    parentCommit('Parent: 1 per day');

    final next = server.read(goalId);
    expect(next['description'], 'Parent: 1 per day');
    // Only the conflicting field resolves by commit order.
    expect(next['pace_value'], 2);
    expect(server.changeLog.map((e) => e.actor), ['tutor', 'parent']);
    expect(server.changeLog.map((e) => e.actionId).toSet(), hasLength(2));
  });

  test('the tutor commits after the parent: the tutor value wins and both '
      'entries remain', () async {
    parentCommit('Parent: 1 per day');
    await h.governed.upsertGoal(
      goalId: goalId,
      data: const {'description': 'Tutor: 2 per day'},
    );

    expect(server.read(goalId)['description'], 'Tutor: 2 per day');
    expect(server.changeLog.map((e) => e.actor), ['parent', 'tutor']);
  });

  test('each tutor edit is its own action (fresh client ULID), so a later '
      'tutor commit is never swallowed as a replay', () async {
    await h.governed.upsertGoal(
      goalId: goalId,
      data: const {'description': 'a'},
    );
    await h.governed.upsertGoal(
      goalId: goalId,
      data: const {'description': 'b'},
    );

    expect(server.read(goalId)['description'], 'b');
    expect(
      h.invoker.calls.map((c) => c.args['actionId']).toSet(),
      hasLength(2),
    );
  });
}
