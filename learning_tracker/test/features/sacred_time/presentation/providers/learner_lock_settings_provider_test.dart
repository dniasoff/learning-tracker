// Mirror test for
// `lib/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart`
// (C0, DNI-524 AC-5; filled by DNI-470 AC-7).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/learner_state_fixtures.dart';

/// A [LearnerSettingsReader] driven by the test.
final class _Reader implements LearnerSettingsReader {
  // Closed by each test's teardown.
  // ignore: close_sinks
  final controller = StreamController<LearnerSettings>.broadcast();
  LearnerScope? watched;

  @override
  Stream<LearnerSettings> watch(LearnerScope scope) {
    watched = scope;
    return controller.stream;
  }
}

String _key(String field) => 'learner_profiles/$profileUlid.$field';

ChangeLogEntry _settingsEntry(
  String id,
  DateTime at,
  Map<String, Object?> before,
  Map<String, Object?> after,
) => ChangeLogEntry(
  id: id,
  entity: GovernedEntity.learnerSettings,
  entityId: profileUlid,
  actionId: id,
  before: {for (final e in before.entries) _key(e.key): e.value},
  after: {for (final e in after.entries) _key(e.key): e.value},
  at: at,
  actor: parentActor,
);

const _jerusalem = LearnerSettings(
  profileId: profileUlid,
  timeZone: 'Asia/Jerusalem',
  inIsrael: true,
  lastChangeId: ulidB,
);

void main() {
  final seed = _settingsEntry(
    ulidA,
    t2,
    {'time_zone': null, 'in_israel': null},
    {'time_zone': 'UTC', 'in_israel': false},
  );
  final move = _settingsEntry(
    ulidB,
    t1,
    {'time_zone': 'UTC', 'in_israel': false},
    {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
  );

  group('learnerLockSettingsProvider', () {
    test('reconstructs the current doc and the learnerSettings history of '
        'the scope', () async {
      final reader = _Reader();
      addTearDown(reader.controller.close);
      final changeLog = InMemoryChangeLogRepository()
        ..seed(c0Scope(), [seed, move]);
      final container = ProviderContainer.test(
        overrides: [
          learnerSettingsReaderProvider.overrideWith((ref) async => reader),
          changeLogRepositoryProvider.overrideWith((ref) async => changeLog),
        ],
      );
      final sub = container.listen(
        learnerLockSettingsProvider(c0Scope()),
        (_, _) {},
      );
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(sub.read().isLoading, isTrue, reason: 'no settings yet');

      reader.controller.add(_jerusalem);
      await pumpEventQueue();

      expect(reader.watched, c0Scope());
      final history = sub.read().value!;
      expect(
        history,
        LearnerSettingsHistory.reconstruct(
          current: _jerusalem,
          entries: [seed, move],
        ),
      );
      expect(history.at(DateTime.utc(2000)).timeZone, 'UTC');
      expect(history.at(t1).timeZone, 'Asia/Jerusalem');
    });

    test('loading while the account is not ready', () async {
      final container = ProviderContainer.test(
        overrides: [
          learnerSettingsReaderProvider.overrideWith((ref) async => null),
          changeLogRepositoryProvider.overrideWith((ref) async => null),
        ],
      );
      final value = await settledAsync(
        container,
        learnerLockSettingsProvider(c0Scope()),
      );
      expect(value.isLoading, isTrue);
    });

    test(
      'an unreadable profile is an error (lock readers fail closed)',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            learnerSettingsReaderProvider.overrideWith(
              (ref) async => _ErrorReader(),
            ),
            changeLogRepositoryProvider.overrideWith(
              (ref) async => InMemoryChangeLogRepository(),
            ),
          ],
        );
        final value = await settledAsync(
          container,
          learnerLockSettingsProvider(c0Scope()),
        );
        expect(value, isA<AsyncError<LearnerSettingsHistory>>());
      },
    );

    test('an override is read per scope', () async {
      final history = c0SettingsHistory();
      final container = ProviderContainer.test(
        overrides: [
          learnerLockSettingsProvider.overrideWith(
            (ref, scope) => Stream.value(history),
          ),
        ],
      );
      final value = await settledAsync(
        container,
        learnerLockSettingsProvider(c0Scope()),
      );
      expect(value.value, same(history));
    });
  });

  group('watchLearnerSettingsHistory', () {
    test('emits only once both inputs delivered, ignores a loading history '
        'and de-duplicates', () async {
      final settings = StreamController<LearnerSettings>();
      final history = StreamController<CompleteRead<ChangeLogEntry>>();
      addTearDown(settings.close);
      addTearDown(history.close);
      final seen = <LearnerSettingsHistory>[];
      final sub = watchLearnerSettingsHistory(
        settings.stream,
        history.stream,
      ).listen(seen.add);
      addTearDown(sub.cancel);

      settings.add(_jerusalem);
      history.add(const CompleteReadLoading());
      await pumpEventQueue();
      expect(seen, isEmpty, reason: 'never a partial history');

      history.add(CompleteReadReady([seed, move]));
      await pumpEventQueue();
      expect(seen, hasLength(1));

      settings.add(_jerusalem); // unchanged
      await pumpEventQueue();
      expect(seen, hasLength(1));

      history.add(CompleteReadReady(const []));
      await pumpEventQueue();
      expect(seen.last, LearnerSettingsHistory.constant(_jerusalem));
    });

    test('a history with an undecodable row fails closed: an error, no '
        'reconstructed settings, until a clean history arrives', () async {
      final settings = StreamController<LearnerSettings>();
      final history = StreamController<CompleteRead<ChangeLogEntry>>();
      addTearDown(settings.close);
      addTearDown(history.close);
      final events = <Object>[];
      final sub = watchLearnerSettingsHistory(
        settings.stream,
        history.stream,
      ).listen(events.add, onError: events.add);
      addTearDown(sub.cancel);

      settings.add(_jerusalem);
      history.add(
        CompleteReadReady(
          [seed, move],
          rejected: [RejectedRow(ulidC, StateError('bad'))],
        ),
      );
      await pumpEventQueue();
      expect(events, [
        isA<UnreadableSettingsHistoryException>().having(
          (e) => e.rows.map((r) => r.docId),
          'rows',
          [ulidC],
        ),
      ]);

      settings.add(
        const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'Asia/Jerusalem',
          inIsrael: false,
          lastChangeId: ulidC,
        ),
      );
      await pumpEventQueue();
      expect(events, hasLength(1), reason: 'nothing published meanwhile');

      history.add(CompleteReadReady([seed, move]));
      await pumpEventQueue();
      expect(events.last, isA<LearnerSettingsHistory>());
    });

    test('forwards input and reconstruct errors, then recovers', () async {
      final settings = StreamController<LearnerSettings>();
      final history = StreamController<CompleteRead<ChangeLogEntry>>();
      addTearDown(settings.close);
      addTearDown(history.close);
      final events = <Object>[];
      final sub = watchLearnerSettingsHistory(
        settings.stream,
        history.stream,
      ).listen(events.add, onError: (Object e) => events.add('error'));
      addTearDown(sub.cancel);

      settings.addError(StateError('offline'));
      await pumpEventQueue();
      expect(events, ['error']);

      settings.add(_jerusalem);
      history.add(
        CompleteReadReady([
          seed,
          _settingsEntry(ulidB, t1, {'time_zone': 42}, {'time_zone': 'UTC'}),
        ]),
      );
      await pumpEventQueue();
      expect(events, ['error', 'error'], reason: 'malformed entry');

      history.add(CompleteReadReady([seed]));
      await pumpEventQueue();
      expect(events.last, isA<LearnerSettingsHistory>());
    });
  });
}

/// A reader whose profile cannot be decoded.
final class _ErrorReader implements LearnerSettingsReader {
  @override
  Stream<LearnerSettings> watch(LearnerScope scope) =>
      Stream.error(const FormatException('no time_zone'));
}
