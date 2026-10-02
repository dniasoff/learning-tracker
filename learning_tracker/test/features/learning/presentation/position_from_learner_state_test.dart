// DNI-478 AC-2: every position consumer reads the scope-keyed engine output.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';

class _PositionSurface extends ConsumerWidget {
  const _PositionSurface({required this.label, required this.scope});

  final String label;
  final LearnerScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(learnerStateProvider(scope))
        .when(
          data: (state) => Text(
            '$label: ${state[engineCurriculum]?.mainTrackPosition ?? 'none'}',
          ),
          error: (error, stack) => Text('$label: error'),
          loading: () => Text('$label: loading'),
        );
  }
}

void main() {
  testWidgets('learner and tutor scope consumers show the same derived '
      'position and update after a learner event', (tester) async {
    final events = StreamController<List<LearningEvent>>();
    addTearDown(events.close);
    final scope = c0Scope();
    const engine = LearnerStateEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerStateProvider.overrideWith((ref, requestedScope) {
            expect(requestedScope, scope);
            return events.stream.map(
              (items) => engine.run(engineInputs(events: items)),
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _PositionSurface(label: 'Learner', scope: scope),
                _PositionSurface(label: 'Tutor', scope: scope),
              ],
            ),
          ),
        ),
      ),
    );

    events.add(const []);
    await tester.pump();
    expect(find.text('Learner: Mishnah Berakhot 1:1'), findsOneWidget);
    expect(find.text('Tutor: Mishnah Berakhot 1:1'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.textContaining('bookmark'), findsNothing);

    events.add([engineLearn(1, 'Mishnah Berakhot 1:1', stage: 1)]);
    await tester.pump();
    expect(find.text('Learner: Mishnah Berakhot 1:2'), findsOneWidget);
    expect(find.text('Tutor: Mishnah Berakhot 1:2'), findsOneWidget);
  });
}
