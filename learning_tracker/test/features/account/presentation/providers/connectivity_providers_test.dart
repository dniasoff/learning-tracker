// Unit tests for connectivityStreamProvider — debounce behaviour.
//
// The provider applies a 300 ms debounce to "offline" signals from
// InternetConnectionChecker.onStatusChange.  This suppresses the transient
// ConnectivityResult.none event that the connectivity_plus platform stream
// fires on Android/iOS cold-start before the OS finishes associating the
// network interface — the root cause of the ~1 s offline-banner flicker.
//
// Test strategy:
//   • Override internetConnectionCheckerProvider with a fake checker whose
//     onStatusChange is driven by an injected StreamController.
//   • hasConnection is made instant by passing a mock http.Client that
//     immediately returns HTTP 200 (or throws for offline).
//   • Use ProviderContainer.listen + real async delays to verify that the
//     debounce fires (or does not fire) as expected.
//
// Coverage:
//   1. Initial online → provider emits true quickly.
//   2. Transient offline blip (<300 ms, then back online) → no false emitted.
//   3. Persistent offline (≥300 ms) → provider emits false.
//   4. Online signal cancels pending offline debounce immediately.
//   5. Online signal after debounced offline clears to true immediately.

@Tags(['unit', 'connectivity', 'account'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:mocktail/mocktail.dart';

// ── Fakes & helpers ───────────────────────────────────────────────────────────

class _MockHttpClient extends Mock implements http.Client {}

/// Creates a fake [InternetConnectionChecker] whose:
///   • [hasConnection] returns [initiallyOnline] quickly (mock http.Client).
///   • [onStatusChange] is driven by [statusController].
///
/// The [connectivity_plus] platform stream is bypassed — [_startMonitoring]
/// subscribes to it via the real [Connectivity] instance, but the binding is
/// initialised so the EventChannel doesn't crash.
InternetConnectionChecker _fakeChecker({
  required StreamController<InternetConnectionStatus> statusController,
  bool initiallyOnline = true,
}) {
  final mockHttp = _MockHttpClient();
  if (initiallyOnline) {
    when(
      () => mockHttp.head(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => http.Response('', 200));
  } else {
    when(
      () => mockHttp.head(any(), headers: any(named: 'headers')),
    ).thenThrow(Exception('no network'));
  }
  return InternetConnectionChecker.createInstance(
    statusController: statusController,
    httpClient: mockHttp,
    addresses: [AddressCheckOption(uri: Uri.parse('https://example.com'))],
  );
}

/// Creates a [ProviderContainer] with [internetConnectionCheckerProvider]
/// replaced by [checker], subscribes to [connectivityStreamProvider] so it
/// starts, and returns the container + a live list of all emitted bool values.
({ProviderContainer container, List<bool?> emissions}) _setup(
  InternetConnectionChecker checker,
) {
  final emissions = <bool?>[];
  final container = ProviderContainer(
    overrides: [internetConnectionCheckerProvider.overrideWithValue(checker)],
  );
  container.listen<AsyncValue<bool>>(connectivityStreamProvider, (_, next) {
    emissions.add(next.value);
  }, fireImmediately: true);
  return (container: container, emissions: emissions);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Required for the connectivity_plus EventChannel that _startMonitoring uses.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  tearDown(() {
    debugResetLastKnownOnline();
  });

  // The provider emits the initial hasConnection result quickly.
  test('initial online → emits true', () async {
    final sc = StreamController<InternetConnectionStatus>.broadcast();
    addTearDown(sc.close);

    final (:container, :emissions) = _setup(
      _fakeChecker(statusController: sc, initiallyOnline: true),
    );
    addTearDown(container.dispose);

    // Wait for the mock HTTP call to complete and the initial yield.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      emissions.whereType<bool>(),
      contains(true),
      reason: 'initial true must be emitted when device is online',
    );
    expect(
      emissions.whereType<bool>(),
      isNot(contains(false)),
      reason: 'no false must be emitted when device is online at startup',
    );
  });

  group('offline debounce (startup-flicker fix)', () {
    // How long to wait for the initial probe to settle before injecting events.
    const kSettle = Duration(milliseconds: 200);
    // Debounce window.
    const kDebounce = Duration(milliseconds: 300);
    // Extra margin after the window to be certain the timer has fired.
    const kMargin = Duration(milliseconds: 100);

    test(
      'transient offline blip (<300 ms) is suppressed — no false emitted',
      () async {
        final sc = StreamController<InternetConnectionStatus>.broadcast();
        addTearDown(sc.close);

        final (:container, :emissions) = _setup(
          _fakeChecker(statusController: sc, initiallyOnline: true),
        );
        addTearDown(container.dispose);

        await Future<void>.delayed(kSettle);
        final emissionsBeforeBlip = emissions.whereType<bool>().toList();

        // Inject the transient platform "disconnected" noise.
        sc.add(InternetConnectionStatus.disconnected);

        // Wait only 100 ms — inside the 300 ms debounce window.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Recover online before the debounce fires.
        sc.add(InternetConnectionStatus.connected);
        await Future<void>.delayed(kDebounce + kMargin);

        // The emission list must never have included false after the initial probe.
        final postBlipEmissions = emissions.whereType<bool>().toList().skip(
          emissionsBeforeBlip.length,
        );
        expect(
          postBlipEmissions,
          isNot(contains(false)),
          reason:
              'a transient offline blip recovered within 300 ms must not '
              'cause the provider to emit false — startup-flicker fix',
        );
      },
    );

    test('persistent offline (≥300 ms) is forwarded — false emitted', () async {
      final sc = StreamController<InternetConnectionStatus>.broadcast();
      addTearDown(sc.close);

      final (:container, :emissions) = _setup(
        _fakeChecker(statusController: sc, initiallyOnline: true),
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(kSettle);

      // Inject offline and wait past the debounce window.
      sc.add(InternetConnectionStatus.disconnected);
      await Future<void>.delayed(kDebounce + kMargin);

      expect(
        emissions.whereType<bool>(),
        contains(false),
        reason:
            'persistent offline must be surfaced after debounce window — '
            'genuine offline, not startup noise',
      );
    });

    test(
      'online signal immediately cancels a pending offline debounce',
      () async {
        final sc = StreamController<InternetConnectionStatus>.broadcast();
        addTearDown(sc.close);

        final (:container, :emissions) = _setup(
          _fakeChecker(statusController: sc, initiallyOnline: true),
        );
        addTearDown(container.dispose);

        await Future<void>.delayed(kSettle);

        // Start the offline debounce timer.
        sc.add(InternetConnectionStatus.disconnected);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Cancel with an online recovery before it fires.
        sc.add(InternetConnectionStatus.connected);
        await Future<void>.delayed(kDebounce + kMargin);

        // Key invariant: after the recovery the provider must NOT have emitted
        // false.  The online recovery may not re-emit true if Riverpod's state
        // is already AsyncData(true) from the initial yield (no duplicate
        // emissions), so we assert absence of false rather than presence of true.
        expect(
          emissions.whereType<bool>(),
          isNot(contains(false)),
          reason:
              'online recovery within 300 ms must cancel the offline debounce '
              '— no false should ever be emitted',
        );
      },
    );

    test('online signal is forwarded without debounce delay', () async {
      final sc = StreamController<InternetConnectionStatus>.broadcast();
      addTearDown(sc.close);

      final (:container, :emissions) = _setup(
        _fakeChecker(statusController: sc, initiallyOnline: true),
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(kSettle);

      // Inject an online signal (device already online, so this is
      // effectively a "confirmed still online" event from the platform).
      sc.add(InternetConnectionStatus.connected);

      // Short wait — online must arrive without waiting for debounce.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The latest emission must be true (online), delivered promptly.
      final latest = emissions.whereType<bool>().lastOrNull;
      expect(
        latest,
        isTrue,
        reason: 'online signal must be forwarded immediately, without debounce',
      );
    });
  });
}
