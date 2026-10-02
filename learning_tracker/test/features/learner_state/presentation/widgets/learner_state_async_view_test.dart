// Mirror test for
// `lib/features/learner_state/presentation/widgets/learner_state_async_view.dart`
// (DNI-474 AC-1: loading, source failure and retry).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/widgets/learner_state_async_view.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/pump_app.dart';

Widget _content(BuildContext context, LearnerState? state) =>
    Text('curricula: ${state?.curricula.length}');

void main() {
  testWidgets('loading uses the shared LoadingIndicator', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, scope) => const Stream.empty(),
          ),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingIndicator), findsOneWidget);
  });

  testWidgets('a source failure renders AppErrorView; retry re-reads the '
      'failed dependency and recovers', (tester) async {
    var reads = 0;
    final now = DateTime.utc(2026, 9, 1);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learningEventRepositoryProvider.overrideWith((ref) async {
            reads++;
            if (reads == 1) throw StateError('events unreadable');
            return null;
          }),
          learnerStateProvider.overrideWith((ref, scope) async* {
            await ref.watch(learningEventRepositoryProvider.future);
            yield LearnerState.empty(now);
          }),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(reads, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(reads, 2, reason: 'retry re-read the failed repository');
    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text('curricula: 0'), findsOneWidget);
  });

  testWidgets('inline sections use InlineAsyncError', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, scope) => Stream.error(StateError('engine failed')),
          ),
        ],
        child: const Scaffold(
          body: LearnerStateAsyncView(inline: true, builder: _content),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InlineAsyncError), findsOneWidget);
  });

  testWidgets('no active learner builds with null', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('curricula: null'), findsOneWidget);
  });
}
