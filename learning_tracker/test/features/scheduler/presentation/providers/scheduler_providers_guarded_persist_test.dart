// Regression test for AUD-core-preferences-04 (EH-2).
//
// `SkippedTasks.skip` (and, identically, `undoSkip`) previously assigned
// `state = {...state, sefariaRef}` optimistically and then `await`ed the
// SharedPreferences write with NO enclosing try/catch: a write failure was
// an unobserved Future rejection, and the skip silently reverted on next
// launch with zero diagnostic trail (the dismissed task would reappear).
//
// BEFORE the fix: a failing SharedPreferences write left `state` containing
// the never-persisted skip — this test would see `state` NOT roll back.
// AFTER the fix (`guardedPersist`): a write failure logs + rolls `state`
// back to the last successfully-persisted set.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../../../helpers/throwing_shared_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SkippedTasks.skip — AUD-core-preferences-04 (EH-2)', () {
    late SharedPreferencesStorePlatform originalStore;

    setUp(() {
      originalStore = SharedPreferencesStorePlatform.instance;
    });

    tearDown(() {
      SharedPreferencesStorePlatform.instance = originalStore;
    });

    test('a failing SharedPreferences write rolls back the optimistic skip '
        'and the returned Future never rejects unobserved', () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': <String>[],
      });
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith((ref) => DateTime.utc(2026, 5, 29)),
        ],
      );
      addTearDown(container.dispose);

      // Keep the provider alive with a listener and wait for the initial
      // _loadFromPrefs load to settle before swapping in the throwing store.
      container.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await container.read(skippedTasksProvider.notifier).debugReadyForTest;
      expect(container.read(skippedTasksProvider), isEmpty);

      SharedPreferencesStorePlatform.instance = ThrowingSharedPreferencesStore(
        {},
      );

      Object? caughtError;
      await runZonedGuarded(() async {
        await container.read(skippedTasksProvider.notifier).skip('ref_A');
      }, (error, stack) => caughtError = error);

      expect(
        caughtError,
        isNull,
        reason:
            'skip() must not let the SharedPreferences write failure '
            'escape as an unobserved Future rejection (got: $caughtError)',
      );
      expect(
        container.read(skippedTasksProvider),
        isEmpty,
        reason:
            'state must roll back to the last successfully-persisted set '
            '(empty, here) on a write failure — otherwise the dismissed '
            'task disappears from the UI but silently reappears on next '
            'launch with no explanation',
      );
    });

    test('a successful write still updates state normally (control case — the '
        'guard must not mask a genuine successful persist)', () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': <String>[],
      });
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith((ref) => DateTime.utc(2026, 5, 29)),
        ],
      );
      addTearDown(container.dispose);

      container.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await container.read(skippedTasksProvider.notifier).debugReadyForTest;

      await container.read(skippedTasksProvider.notifier).skip('ref_A');

      expect(container.read(skippedTasksProvider), contains('ref_A'));
    });
  });
}
