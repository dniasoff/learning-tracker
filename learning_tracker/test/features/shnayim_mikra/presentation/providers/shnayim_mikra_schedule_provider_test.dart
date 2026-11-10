import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_schedule_provider.dart';

void main() {
  test('no active learner has no Shnayim Mikra schedule', () async {
    final container = ProviderContainer(
      overrides: [activeLearnerScopeProvider.overrideWith((ref) async => null)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(shnayimMikraScheduleProjectionProvider.future),
      isNull,
    );
  });
}
