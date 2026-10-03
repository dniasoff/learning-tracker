// Story 4.3 (DNI-511) AC-7 (unit): one row's engine timeout does not fail
// the roster. The timed-out row alone shows its retry, a retry can recover,
// and the Crashlytics non-fatal carries enums only.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';

import '../../../helpers/dashboard/forecast_fixtures.dart';
import '../talmidim_fixtures.dart';

const _timeout = Duration(milliseconds: 40);

final _onTrack = forecastState([
  forecastCurriculumState(
    projection: const Projection(status: ProjectionStatus.onTrack),
    dailyTarget: 3,
  ),
]);

final class _RecordingCrashlytics implements CrashlyticsService {
  final errors = <Object>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    expect(fatal, isFalse);
    errors.add(error);
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserIdentifier(String? profileId) async {}
}

void main() {
  late FakeTalmidInputs inputs;
  late ProviderContainer container;

  ProviderContainer build({List<Override> extra = const []}) {
    container = ProviderContainer(
      overrides: [
        ...inputs.overrides,
        talmidRowLoadTimeoutProvider.overrideWithValue(_timeout),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => inputs = FakeTalmidInputs());

  test('the slow row alone times out; the others stay ready', () async {
    final diagnostics = RecordingTalmidRowDiagnostics();
    inputs.states[talmidScope(1)] = AsyncData(_onTrack);
    inputs.states[talmidScope(3)] = AsyncData(_onTrack);
    build(extra: [talmidRowDiagnosticsProvider.overrideWithValue(diagnostics)]);
    for (final n in [1, 2, 3]) {
      container.listen(talmidRowStateProvider(talmidScope(n)), (_, _) {});
    }
    expect(
      container.read(talmidRowStateProvider(talmidScope(2))),
      const TalmidRowLoading(),
    );

    await Future<void>.delayed(_timeout * 3);

    expect(
      container.read(talmidRowStateProvider(talmidScope(2))),
      const TalmidRowTimedOut(identityVisible: true),
    );
    for (final n in [1, 3]) {
      expect(
        container.read(talmidRowStateProvider(talmidScope(n))),
        isA<TalmidRowReady>().having((r) => r.status, 'status', isNotNull),
      );
    }
    expect(diagnostics.timeouts, [TalmidLoadStage.engine]);
  });

  test('a retry re-reads the row and can recover', () async {
    build(
      extra: [
        talmidRowDiagnosticsProvider.overrideWithValue(
          RecordingTalmidRowDiagnostics(),
        ),
      ],
    );
    final scope = talmidScope(2);
    container.listen(talmidRowStateProvider(scope), (_, _) {});
    await Future<void>.delayed(_timeout * 3);
    expect(
      container.read(talmidRowStateProvider(scope)),
      isA<TalmidRowTimedOut>(),
    );

    inputs.states[scope] = AsyncData(_onTrack);
    container.read(talmidRowTimedOutProvider(scope).notifier).retry();
    expect(
      container.read(talmidRowStateProvider(scope)),
      isA<TalmidRowReady>(),
    );
  });

  test('the non-fatal holds enums only: no learner id, name or ref', () async {
    final crashlytics = _RecordingCrashlytics();
    build(extra: [crashlyticsServiceProvider.overrideWithValue(crashlytics)]);
    final scope = talmidScope(4);
    container.listen(talmidRowStateProvider(scope), (_, _) {});
    await Future<void>.delayed(_timeout * 3);

    expect(crashlytics.errors, hasLength(1));
    final error = crashlytics.errors.single;
    expect(error, isA<TalmidEngineLoadTimeoutError>());
    final text = error.toString();
    expect(text, 'TalmidEngineLoadTimeout(stage: engine)');
    expect(text, isNot(contains(scope.profileId)));
    expect(text, isNot(contains(scope.ownerUid)));
  });

  test(
    'a lock still unknown at the timeout keeps the identity hidden',
    () async {
      inputs.defaultLock = const AsyncLoading<bool>();
      final diagnostics = RecordingTalmidRowDiagnostics();
      build(
        extra: [talmidRowDiagnosticsProvider.overrideWithValue(diagnostics)],
      );
      final scope = talmidScope(5);
      container.listen(talmidRowStateProvider(scope), (_, _) {});
      expect(
        container.read(talmidRowStateProvider(scope)),
        const TalmidRowPending(),
      );
      await Future<void>.delayed(_timeout * 3);
      expect(
        container.read(talmidRowStateProvider(scope)),
        const TalmidRowTimedOut(identityVisible: false),
      );
      expect(diagnostics.timeouts, [TalmidLoadStage.lock]);
    },
  );
}
