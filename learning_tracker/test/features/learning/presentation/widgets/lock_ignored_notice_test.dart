// DNI-504 AC-9: the Learn tab's "kept, not counted" notice, per learner.
// The end-to-end path (a synced lock-stamped event through the real
// engine) is test/features/learning/domain/lock_ignored_event_test.dart.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/data/repositories/lock_ignored_notice_store.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/lock_ignored_notice.dart';

import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final _a = LearnerScope(ownerUid: 'owner', profileId: ulidA);
final _b = LearnerScope(ownerUid: 'owner', profileId: ulidB);

const _snackbar =
    'Some learning was kept, not counted — it was recorded during Shabbos.';

final class _MemoryStore implements LockIgnoredNoticeStore {
  final Map<LearnerScope, Set<String>> byScope = {};

  @override
  Future<Set<String>> announced(LearnerScope scope) async => {
    ...?byScope[scope],
  };

  @override
  Future<void> setAnnounced(LearnerScope scope, Set<String> ids) async =>
      byScope[scope] = {...ids};
}

Future<void> _pump(
  WidgetTester tester, {
  required LearnerScope? scope,
  required Set<String> ignored,
  required _MemoryStore store,
}) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...learnerStateOverrides(
          scope: scope,
          state: fakeLearnerState(lockIgnoredEventIds: ignored),
        ),
        lockIgnoredNoticeStoreProvider.overrideWithValue(store),
      ],
      child: const Scaffold(body: LockIgnoredNotice()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('announces a learner\'s lock-ignored events once', (
    tester,
  ) async {
    final store = _MemoryStore();
    await _pump(tester, scope: _a, ignored: {'e1'}, store: store);
    expect(find.text(_snackbar), findsOneWidget);
    expect(store.byScope[_a], {'e1'});

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, scope: _a, ignored: {'e1'}, store: store);
    expect(find.text(_snackbar), findsNothing);
  });

  testWidgets('another learner on the same device is announced on its own', (
    tester,
  ) async {
    final store = _MemoryStore()..byScope[_a] = {'e1'};
    await _pump(tester, scope: _b, ignored: {'e1'}, store: store);
    expect(find.text(_snackbar), findsOneWidget);
    expect(store.byScope[_b], {'e1'});
  });

  testWidgets('a new event for a learner already told about others is '
      'announced', (tester) async {
    final store = _MemoryStore()..byScope[_a] = {'e1'};
    await _pump(tester, scope: _a, ignored: {'e1', 'e2'}, store: store);
    expect(find.text(_snackbar), findsOneWidget);
  });

  testWidgets('no active learner: nothing', (tester) async {
    final store = _MemoryStore();
    await _pump(tester, scope: null, ignored: {'e1'}, store: store);
    expect(find.text(_snackbar), findsNothing);
    expect(store.byScope, isEmpty);
  });
}
