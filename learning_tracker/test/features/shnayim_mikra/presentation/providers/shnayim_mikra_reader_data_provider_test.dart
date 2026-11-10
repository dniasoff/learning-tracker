import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_reader_data_provider.dart';

class _EventRepository implements LearningEventRepository {
  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) =>
      Stream.value(CompleteReadReady<LearningEvent>([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('reader event provider publishes the complete event log', () async {
    final scope = LearnerScope(
      ownerUid: 'owner',
      profileId: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
    );
    final container = ProviderContainer(
      overrides: [
        learningEventRepositoryProvider.overrideWith(
          (ref) async => _EventRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final eventsProvider = shnayimMikraReaderEventsProvider(scope);
    final subscription = container.listen(eventsProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(await container.read(eventsProvider.future), isEmpty);
  });
}
