/// Contract test for the [LearningEventRepository] port: an in-memory
/// implementation satisfies the documented create-only/idempotent shape.
/// (The Firestore implementation is covered by
/// `test/data/repositories/firestore_learning_event_repository_test.dart`.)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';

import '../../../helpers/learner_state_fixtures.dart';

final class _InMemory implements LearningEventRepository {
  final Map<String, Map<String, Object?>> docs = {};

  @override
  Future<void> create(LearnerScope scope, LearningEvent event) async {
    final payload = event.toStorage();
    docs[event.id] = payload;
  }

  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) async* {
    yield const CompleteReadLoading();
    yield CompleteReadReady([
      for (final e in docs.entries) LearningEvent.fromStorage(e.key, e.value),
    ]);
  }
}

void main() {
  test('create is keyed by the event id; replay is identical', () async {
    final repo = _InMemory();
    final scope = LearnerScope(ownerUid: 'o', profileId: profileUlid);
    await repo.create(scope, datedLearn());
    await repo.create(scope, datedLearn());
    expect(repo.docs.keys, [ulidA]);
    expect(await repo.watchAll(scope).toList(), [
      const CompleteReadLoading<LearningEvent>(),
      CompleteReadReady([datedLearn()]),
    ]);
  });
}
