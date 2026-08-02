// Unit tests for connectivityStreamProvider — debounce + self-healing
// recovery, now driven by connectivity_plus PLATFORM EVENTS (Story 1.4 /
// AD-11 / E-1) instead of a package-internal poll.
//
// The provider applies a 300 ms debounce to "offline" signals (suppresses
// the transient `ConnectivityResult.none` blip some OSes fire before
// finishing NIC association on cold start — the startup-flicker fix), AND
// self-heals via real platform events — connectivity_plus fires a genuine OS
// callback the instant the interface actually reconnects (airplane mode
// toggled off, WiFi re-associates) — so the banner clears on its own without
// a manual refresh, with NO fast Timer.periodic re-probe loop anywhere in
// this provider (the pre-fix redundant 5 s offline-recovery loop is gone).
//
// Test strategy:
//   • Fake connectivity_plus at the platform-interface layer
//     (`ConnectivityPlatform.instance =`) — the standard federated-plugin
//     test seam — so platform transitions can be injected via a plain
//     StreamController without touching the real EventChannel.
//   • Override internetConnectionCheckerProvider with a REAL
//     InternetConnectionChecker constructed with a mocked http.Client, so
//     `hasConnection` (the on-demand probe fired on every transition/resume)
//     reads a mutable _NetworkState oracle a test can flip mid-run.
//   • Use ProviderContainer.listen + real async delays.
//
// Coverage:
//   1. Initial online → provider emits true quickly.
//   2. Transient offline blip (<300 ms, then back online) → no false emitted.
//   3. Persistent offline (>= 300 ms) → provider emits false.
//   4. Online signal cancels a pending offline debounce immediately.
//   5. Online signal forwarded without debounce delay.
//   6. AIRPLANE-MODE TOGGLE: none → (has interface) → recovers to online.
//   7. SELF-HEAL: offline → a platform event fires → auto-recovers, no
//      manual refresh / invalidation.
//   8. SELF-HEAL: once recovered, further "still online" platform events do
//      not flip the state back to offline.
//   9. SELF-HEAL: a platform-stream error does NOT latch the provider
//      offline.
//   10. COLD-START-GENUINELY-OFFLINE: starts offline, no false-offline
//       *flash* beyond the genuine signal, then auto-recovers when the
//       network returns via a platform event.

@Tags(['unit', 'connectivity', 'account'])
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart'
    show ConnectivityPlatform;
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

/// Fakes the `connectivity_plus` platform layer so tests can inject platform
/// connectivity transitions via a plain, test-owned [StreamController] — the
/// standard federated-plugin test seam (`extends` rather than `implements`
/// so `PlatformInterface`'s token check passes without a mixin).
class _FakeConnectivityPlatform extends ConnectivityPlatform {
  _FakeConnectivityPlatform(this._controller);

  final StreamController<List<ConnectivityResult>> _controller;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
}

/// Creates a fake [InternetConnectionChecker] whose [hasConnection] returns
/// the CURRENT value of [network] quickly (the mock http.Client returns HTTP
/// 200 when online, throws when offline). Because the mock reads [network]
/// live, a test can flip `network.online` between probes to simulate
/// connectivity recovery.
InternetConnectionChecker _fakeChecker({required _NetworkState network}) {
  final mockHttp = _MockHttpClient();
  when(() => mockHttp.head(any(), headers: any(named: 'headers'))).thenAnswer((
    _,
  ) async {
    if (network.online) return http.Response('', 200);
    throw Exception('no network');
  });
  return InternetConnectionChecker.createInstance(
    httpClient: mockHttp,
    addresses: [AddressCheckOption(uri: Uri.parse('https://example.com'))],
  );
}

/// Creates a [ProviderContainer] with [internetConnectionCheckerProvider]
/// replaced by a fake checker driven by [network], wires up a fake
/// connectivity_plus platform, subscribes to [connectivityStreamProvider] so
/// it starts, and returns the container + a live list of all emitted bool
/// values + the platform-event controller a test injects transitions on.
({
  ProviderContainer container,
  List<bool?> emissions,
  StreamController<List<ConnectivityResult>> platformEvents,
})
_setup(_NetworkState network) {
  // ignore: close_sinks — closed by the caller via addTearDown(platformEvents.close).
  final platformEvents = StreamController<List<ConnectivityResult>>.broadcast();
  ConnectivityPlatform.instance = _FakeConnectivityPlatform(platformEvents);

  final emissions = <bool?>[];
  final container = ProviderContainer(
    overrides: [
      internetConnectionCheckerProvider.overrideWithValue(
        _fakeChecker(network: network),
      ),
    ],
  );
  container.listen<AsyncValue<bool>>(connectivityStreamProvider, (_, next) {
    emissions.add(next.value);
  }, fireImmediately: true);
  return (
    container: container,
    emissions: emissions,
    platformEvents: platformEvents,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Required for the connectivity_plus EventChannel binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  tearDown(debugResetLastKnownOnline);

  // The provider emits the initial hasConnection result quickly.
  test('initial online → emits true', () async {
    final (:container, :emissions, :platformEvents) = _setup(
      _NetworkState(true),
    );
    addTearDown(container.dispose);
    addTearDown(platformEvents.close);

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
        final network = _NetworkState(true);
        final (:container, :emissions, :platformEvents) = _setup(network);
        addTearDown(container.dispose);
        addTearDown(platformEvents.close);

        await Future<void>.delayed(kSettle);
        final emissionsBeforeBlip = emissions.whereType<bool>().toList();

        // Inject the transient platform "no interface" noise.
        platformEvents.add([ConnectivityResult.none]);

        // Wait only 100 ms — inside the 300 ms debounce window.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Recover online before the debounce fires (interface reassociates).
        platformEvents.add([ConnectivityResult.wifi]);
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
      final network = _NetworkState(true);
      final (:container, :emissions, :platformEvents) = _setup(network);
      addTearDown(container.dispose);
      addTearDown(platformEvents.close);

      await Future<void>.delayed(kSettle);

      // Inject "no interface" and wait past the debounce window.
      platformEvents.add([ConnectivityResult.none]);
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
        final network = _NetworkState(true);
        final (:container, :emissions, :platformEvents) = _setup(network);
        addTearDown(container.dispose);
        addTearDown(platformEvents.close);

        await Future<void>.delayed(kSettle);

        // Start the offline debounce timer.
        platformEvents.add([ConnectivityResult.none]);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Cancel with an online recovery before it fires.
        platformEvents.add([ConnectivityResult.wifi]);
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
      final network = _NetworkState(true);
      final (:container, :emissions, :platformEvents) = _setup(network);
      addTearDown(container.dispose);
      addTearDown(platformEvents.close);

      await Future<void>.delayed(kSettle);

      // Device already online; a "still have an interface" event confirms
      // via one on-demand probe (network.online is still true).
      platformEvents.add([ConnectivityResult.wifi]);

      // Short wait — online must arrive without waiting for the debounce.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final latest = emissions.whereType<bool>().lastOrNull;
      expect(
        latest,
        isTrue,
        reason: 'online signal must be forwarded immediately, without debounce',
      );
    });
  });

  // ── Self-healing recovery (stuck-offline fix) — now platform-event-driven ──
  //
  // Once the provider believes it is offline it must recover to online on its
  // OWN — WITHOUT any external invalidation or manual pull-to-refresh — the
  // instant a real platform event reports the interface returned. There is no
  // Timer.periodic re-probe loop anywhere in this provider (Story 1.4 removed
  // it): recovery is driven purely by connectivity_plus events (+ the
  // long-interval background safety net, not exercised here) + app resume.
  group('self-healing recovery (stuck-offline fix)', () {
    const kSettle = Duration(milliseconds: 200);
    const kDebounce = Duration(milliseconds: 300);

    test('AIRPLANE-MODE TOGGLE: none → interface returns → recovers to online '
        'via the platform event, no manual refresh', () async {
      final network = _NetworkState(true);
      final (:container, :emissions, :platformEvents) = _setup(network);
      addTearDown(container.dispose);
      addTearDown(platformEvents.close);

      await Future<void>.delayed(kSettle);

      // Airplane mode ON: interface drops entirely.
      network.online = false;
      platformEvents.add([ConnectivityResult.none]);
      await Future<void>.delayed(kDebounce + const Duration(milliseconds: 50));
      expect(
        emissions.whereType<bool>(),
        contains(false),
        reason: 'provider must surface offline after airplane mode is on',
      );
      final emittedBeforeRecovery = emissions.whereType<bool>().length;

      // Airplane mode OFF: the OS fires a genuine reconnect event — NOT a
      // manual refresh/invalidation.
      network.online = true;
      platformEvents.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(
        container.read(connectivityStreamProvider).value,
        isTrue,
        reason:
            'provider must auto-recover to online on the platform event — '
            'no manual refresh / invalidation needed',
      );
      expect(
        emissions.whereType<bool>().skip(emittedBeforeRecovery),
        contains(true),
        reason: 'the recovery to online must be emitted downstream',
      );
    });

    test('once recovered, further "still online" platform events do not flip '
        'the state back to offline', () async {
      final network = _NetworkState(true);
      final (:container, :emissions, :platformEvents) = _setup(network);
      addTearDown(container.dispose);
      addTearDown(platformEvents.close);

      await Future<void>.delayed(kSettle);

      // Offline, then recover via a platform event.
      network.online = false;
      platformEvents.add([ConnectivityResult.none]);
      await Future<void>.delayed(kDebounce + const Duration(milliseconds: 50));
      network.online = true;
      platformEvents.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(container.read(connectivityStreamProvider).value, isTrue);
      final lenAfterRecovery = emissions.whereType<bool>().length;

      // Several more "still connected" platform events (e.g. a Wi-Fi
      // signal-strength change that doesn't affect association) — must
      // not produce a spurious offline flip.
      platformEvents.add([ConnectivityResult.wifi]);
      platformEvents.add([ConnectivityResult.wifi]);
      platformEvents.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        container.read(connectivityStreamProvider).value,
        isTrue,
        reason: 'must stay online across duplicate "still connected" events',
      );
      expect(
        emissions.whereType<bool>().skip(lenAfterRecovery),
        isNot(contains(false)),
        reason: 'no spurious offline emission from a duplicate online event',
      );
    });

    test(
      'a platform-stream error does NOT latch the provider offline',
      () async {
        final network = _NetworkState(true);
        final (:container, :emissions, :platformEvents) = _setup(network);
        addTearDown(container.dispose);
        addTearDown(platformEvents.close);

        await Future<void>.delayed(kSettle);

        // Inject an error on the platform connectivity stream.
        platformEvents.addError(Exception('platform channel blew up'));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // The provider must NEVER have emitted a false value (offline) as a
        // result of the error — app_shell treats error/loading as
        // assume-online, so the banner must not latch offline.
        expect(
          emissions.whereType<bool>(),
          isNot(contains(false)),
          reason:
              'an error on the platform stream must not cause an offline '
              'emission (error/loading is assume-online, not stuck-offline)',
        );
      },
    );

    test(
      'COLD-START-GENUINELY-OFFLINE: surfaces offline immediately, then '
      'auto-recovers when a platform event reports the network returned',
      () async {
        // Start genuinely offline (cold start with no connection).
        final network = _NetworkState(false);
        final (:container, :emissions, :platformEvents) = _setup(network);
        addTearDown(container.dispose);
        addTearDown(platformEvents.close);

        // Allow the initial probe to resolve to offline. The initial seed
        // (unlike a mid-session platform event) is NOT debounced, so a
        // genuinely-offline cold start is surfaced promptly and honestly —
        // no false-offline *flash* masking it, and no false *online* flash
        // either.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(
          emissions.whereType<bool>(),
          contains(false),
          reason: 'a genuine cold-start offline must surface offline',
        );
        expect(
          emissions.whereType<bool>().first,
          isFalse,
          reason: 'the very first emission must already be honestly offline',
        );

        // Network returns — the platform fires a genuine reconnect event
        // (no manual refresh).
        network.online = true;
        platformEvents.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          container.read(connectivityStreamProvider).value,
          isTrue,
          reason:
              'cold-start offline must auto-recover to online once the '
              'network returns — without a manual refresh',
        );
      },
    );
  });
}
