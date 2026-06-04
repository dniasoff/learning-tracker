// Unit tests for connectivityStreamProvider — debounce + self-healing recovery.
//
// The provider applies a 300 ms debounce to "offline" signals from
// InternetConnectionChecker.onStatusChange (suppresses the transient
// ConnectivityResult.none event that connectivity_plus fires on cold-start —
// the ~1 s offline-banner flicker), AND runs an active hasConnection re-probe
// loop while offline so the banner self-heals to online without a manual
// refresh (the stuck-offline bug).
//
// Test strategy:
//   • Override internetConnectionCheckerProvider with a fake checker whose
//     onStatusChange is driven by an injected StreamController and whose
//     hasConnection reads a mutable _NetworkState oracle (so a test can flip
//     the network mid-run to simulate recovery).
//   • hasConnection is made instant by a mock http.Client (HTTP 200 / throw).
//   • Use ProviderContainer.listen + real async delays. The recovery probe
//     interval is shrunk via debugSetOfflineRecoveryProbeInterval so the loop
//     runs in ~100 ms instead of 5 s.
//
// Coverage:
//   1. Initial online → provider emits true quickly.
//   2. Transient offline blip (<300 ms, then back online) → no false emitted.
//   3. Persistent offline (≥300 ms) → provider emits false.
//   4. Online signal cancels pending offline debounce immediately.
//   5. Online signal forwarded without debounce delay.
//   6. SELF-HEAL: offline → network returns (no platform event) → auto-recovers.
//   7. SELF-HEAL: re-probe loop stops once recovered (no offline flip-back).
//   8. SELF-HEAL: a status-stream error does NOT latch the provider offline.
//   9. SELF-HEAL: cold-start offline auto-recovers when the network returns.

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

/// A mutable connectivity oracle the fake checker's [hasConnection] consults on
/// every probe. Flip [online] mid-test to simulate the network returning.
class _NetworkState {
  _NetworkState(this.online);
  bool online;
}

/// Creates a fake [InternetConnectionChecker] whose:
///   • [hasConnection] returns the CURRENT value of [network] quickly (the mock
///     http.Client returns HTTP 200 when online, throws when offline).
///   • [onStatusChange] is driven by [statusController].
///
/// Because the mock reads [network] live, a test can flip `network.online`
/// between probes to simulate connectivity recovery — exercising the provider's
/// self-healing re-probe loop.
///
/// The [connectivity_plus] platform stream is bypassed — [_startMonitoring]
/// subscribes to it via the real [Connectivity] instance, but the binding is
/// initialised so the EventChannel doesn't crash.
InternetConnectionChecker _fakeChecker({
  required StreamController<InternetConnectionStatus> statusController,
  required _NetworkState network,
}) {
  final mockHttp = _MockHttpClient();
  when(() => mockHttp.head(any(), headers: any(named: 'headers'))).thenAnswer((
    _,
  ) async {
    if (network.online) return http.Response('', 200);
    throw Exception('no network');
  });
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
    debugResetOfflineRecoveryProbeInterval();
  });

  // The provider emits the initial hasConnection result quickly.
  test('initial online → emits true', () async {
    final sc = StreamController<InternetConnectionStatus>.broadcast();
    addTearDown(sc.close);

    final (:container, :emissions) = _setup(
      _fakeChecker(statusController: sc, network: _NetworkState(true)),
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
          _fakeChecker(statusController: sc, network: _NetworkState(true)),
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
        _fakeChecker(statusController: sc, network: _NetworkState(true)),
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
          _fakeChecker(statusController: sc, network: _NetworkState(true)),
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
        _fakeChecker(statusController: sc, network: _NetworkState(true)),
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

  // ── Self-healing recovery (stuck-offline fix) ──────────────────────────────
  //
  // Once the provider believes it is offline it must recover to online on its
  // OWN — within a few seconds of the connection returning — WITHOUT any
  // external invalidation or manual pull-to-refresh.  This is the bug the user
  // hit: the banner got stuck offline and only a refresh cleared it.  The
  // provider now runs an active hasConnection re-probe on a short interval while
  // offline; the moment one succeeds it emits true.
  group('self-healing recovery (stuck-offline fix)', () {
    const kSettle = Duration(milliseconds: 200);
    const kDebounce = Duration(milliseconds: 300);
    // Shrink the recovery probe interval so the loop runs quickly in tests.
    const kProbe = Duration(milliseconds: 100);

    setUp(() {
      debugSetOfflineRecoveryProbeInterval(kProbe);
    });

    test(
      'recovers to online via the re-probe loop without external invalidation',
      () async {
        final sc = StreamController<InternetConnectionStatus>.broadcast();
        addTearDown(sc.close);

        // The mutable network: starts online, then we take it offline, then
        // bring it back — all WITHOUT re-running the provider or refreshing.
        final network = _NetworkState(true);
        final (:container, :emissions) = _setup(
          _fakeChecker(statusController: sc, network: network),
        );
        addTearDown(container.dispose);

        await Future<void>.delayed(kSettle);

        // Go offline: flip the oracle AND emit the platform disconnected event.
        network.online = false;
        sc.add(InternetConnectionStatus.disconnected);
        await Future<void>.delayed(
          kDebounce + const Duration(milliseconds: 50),
        );

        expect(
          emissions.whereType<bool>(),
          contains(false),
          reason: 'provider must surface offline after the debounce window',
        );
        final emittedBeforeRecovery = emissions.whereType<bool>().length;

        // Now the network returns — but NO platform event is emitted (this is
        // the stuck scenario: connectivity_plus never fires the recovery event,
        // or the package's flaky internal poll keeps failing). The provider's
        // OWN re-probe loop must detect the recovery.
        network.online = true;

        // Wait a few probe intervals — recovery must happen on its own.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(
          container.read(connectivityStreamProvider).value,
          isTrue,
          reason:
              'provider must auto-recover to online via its re-probe loop — '
              'no manual refresh / invalidation needed',
        );
        expect(
          emissions.whereType<bool>().skip(emittedBeforeRecovery),
          contains(true),
          reason: 'the recovery to online must be emitted downstream',
        );
      },
    );

    test(
      're-probe loop stops once recovered (no further offline emissions)',
      () async {
        final sc = StreamController<InternetConnectionStatus>.broadcast();
        addTearDown(sc.close);

        final network = _NetworkState(true);
        final (:container, :emissions) = _setup(
          _fakeChecker(statusController: sc, network: network),
        );
        addTearDown(container.dispose);

        await Future<void>.delayed(kSettle);

        // Offline, then recover.
        network.online = false;
        sc.add(InternetConnectionStatus.disconnected);
        await Future<void>.delayed(
          kDebounce + const Duration(milliseconds: 50),
        );
        network.online = true;
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Confirm online.
        expect(container.read(connectivityStreamProvider).value, isTrue);
        final lenAfterRecovery = emissions.whereType<bool>().length;

        // Let several more probe intervals elapse — the loop must have stopped,
        // so no spurious offline re-probe flips the state back.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(
          container.read(connectivityStreamProvider).value,
          isTrue,
          reason:
              'once recovered, the provider must stay online (loop stopped)',
        );
        expect(
          emissions.whereType<bool>().skip(lenAfterRecovery),
          isNot(contains(false)),
          reason: 'no offline re-probe should fire after recovery',
        );
      },
    );

    test('a status-stream error does NOT latch the provider offline', () async {
      final sc = StreamController<InternetConnectionStatus>.broadcast();
      addTearDown(sc.close);

      final network = _NetworkState(true);
      final (:container, :emissions) = _setup(
        _fakeChecker(statusController: sc, network: network),
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(kSettle);

      // Inject an error on the status stream.
      sc.addError(Exception('status stream blew up'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The provider may surface AsyncError, but it must NEVER have emitted a
      // false value (offline) as a result of the error — app_shell treats
      // error/loading as assume-online, so the banner must not latch offline.
      expect(
        emissions.whereType<bool>(),
        isNot(contains(false)),
        reason:
            'an error on the status stream must not cause an offline emission '
            '(error/loading is assume-online, not stuck-offline)',
      );
    });

    test('cold-start offline auto-recovers when the network returns', () async {
      final sc = StreamController<InternetConnectionStatus>.broadcast();
      addTearDown(sc.close);

      // Start genuinely offline (cold start with no connection).
      final network = _NetworkState(false);
      final (:container, :emissions) = _setup(
        _fakeChecker(statusController: sc, network: network),
      );
      addTearDown(container.dispose);

      // Allow the initial probe to resolve to offline.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        emissions.whereType<bool>(),
        contains(false),
        reason: 'a genuine cold-start offline must surface offline',
      );

      // Network returns — recovery loop (running since startup) must pick it up.
      network.online = true;
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        container.read(connectivityStreamProvider).value,
        isTrue,
        reason:
            'cold-start offline must auto-recover to online once the network '
            'returns — without a manual refresh',
      );
    });
  });
}
