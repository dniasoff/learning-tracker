// Story 4.3 (DNI-511) T2: the row provider's lock privacy and failure
// states (AC-4, AC-6, AD-36), and the lock judged on the TALMID's own
// settings history.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../talmidim_fixtures.dart';

final _onTrack = forecastState([
  forecastCurriculumState(
    projection: const Projection(status: ProjectionStatus.onTrack),
    dailyTarget: 3,
  ),
]);

void main() {
  late FakeTalmidInputs inputs;

  ProviderContainer containerFor() {
    final container = ProviderContainer(overrides: inputs.overrides);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => inputs = FakeTalmidInputs());

  TalmidRowState read(ProviderContainer c, int n) {
    c.listen(talmidRowStateProvider(talmidScope(n)), (_, _) {});
    return c.read(talmidRowStateProvider(talmidScope(n)));
  }

  test('a locked talmid is redacted and inert, the next one stays live', () {
    inputs
      ..states[talmidScope(1)] = AsyncData(_onTrack)
      ..states[talmidScope(2)] = AsyncData(_onTrack)
      ..locks[talmidScope(1)] = const AsyncData(true);
    final c = containerFor();

    final locked = read(c, 1);
    expect(locked, const TalmidRowLocked());
    expect(locked.identityVisible, isFalse);
    expect(locked.opensLearner, isFalse);

    final open = read(c, 2);
    expect(open, isA<TalmidRowReady>());
    expect(open.opensLearner, isTrue);
  });

  test('no identity until the lock is known open (fail closed)', () {
    inputs
      ..states[talmidScope(1)] = AsyncData(_onTrack)
      ..locks[talmidScope(1)] = const AsyncLoading<bool>();
    expect(read(containerFor(), 1), const TalmidRowPending());
  });

  test('an unreadable lock is a failed row without identity', () {
    inputs
      ..states[talmidScope(1)] = AsyncData(_onTrack)
      ..locks[talmidScope(1)] = AsyncError<bool>(
        StateError('settings'),
        StackTrace.empty,
      );
    final row = read(containerFor(), 1);
    expect(row, const TalmidRowFailed(TalmidRowFailure.loadFailed));
    expect(row.identityVisible, isFalse);
  });

  test('a revoked grant ends the row, whatever the lock', () {
    final scope = talmidScope(1);
    inputs
      ..states[scope] = AsyncError<LearnerState>(
        TutorScopeAccessDeniedException(
          scope,
          TutorScopeDenialReason.grantNotActive,
        ),
        StackTrace.empty,
      )
      ..locks[scope] = const AsyncData(true);
    expect(
      read(containerFor(), 1),
      const TalmidRowFailed(TalmidRowFailure.accessEnded),
    );
  });

  test('an engine failure on an open row is retryable and named', () {
    inputs.states[talmidScope(1)] = AsyncError<LearnerState>(
      StateError('engine'),
      StackTrace.empty,
    );
    final row = read(containerFor(), 1) as TalmidRowFailed;
    expect(row.retryable, isTrue);
    expect(row.identityVisible, isTrue);
  });

  group('talmidLockProvider', () {
    test("judges the talmid's own settings with the shared gate", () {
      final gate = FakeCaptureGate.locked(
        LockWindow(DateTime.utc(2026, 9, 4, 17), DateTime.utc(2026, 9, 5, 19)),
      );
      final history = c0SettingsHistory();
      final container = ProviderContainer(
        overrides: [
          learnerLockSettingsProvider.overrideWith(
            (ref, _) => Stream.value(history),
          ),
          captureGateProvider.overrideWithValue(gate),
          learningCommandClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 5, 12),
          ),
        ],
      );
      addTearDown(container.dispose);
      final scope = talmidScope(1);
      container.listen(talmidLockProvider(scope), (_, _) {});
      return Future<void>.delayed(Duration.zero, () {
        expect(
          container.read(talmidLockProvider(scope)),
          const AsyncData(true),
        );
        expect(gate.checks.single.$1, same(history));
        gate.decision = FakeCaptureGate.open().decision;
        container.invalidate(talmidLockProvider(scope));
        expect(
          container.read(talmidLockProvider(scope)),
          const AsyncData(false),
        );
      });
    });
  });
}
