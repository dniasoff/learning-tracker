// Story 1.4 red-demo requirement (docs/planning/epics-firestore-migration-phase0.md
// "Story 1.4"; finding E-1, docs/reports/sync-reliability-efficiency-review-2026-07-29.md).
//
// Each test below is written to FAIL against the pre-fix
// `connectivity_providers.dart` — `InternetConnectionChecker.createInstance()`
// with NO overrides (package default: a 5 s poll against 3 third-party demo
// hosts `dummyapi.online`/`jsonplaceholder.typicode.com`/`fakestoreapi.com`,
// plus a factually-wrong "event-driven instead of polling, so idle CPU cost
// is ~0" comment) — and PASS against the post-fix version:
//
//   (a) connectivity is sourced from the hardened stream / platform events,
//       backed by a direct `connectivity_plus` dependency.
//   (b) no 5 s demo-host poll loop remains: the checker probes exactly ONE
//       first-party host on a long (>= 3 min) interval.
//   (c) the false "idle CPU cost is ~0" comment is gone, replaced by a
//       description of the real cost model.
@Tags(['unit', 'connectivity', 'account'])
library;

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';

const _sourcePath =
    'lib/features/account/presentation/providers/connectivity_providers.dart';

void main() {
  test('(a) connectivity is sourced from platform events: '
      'connectivityPlusProvider exposes a real connectivity_plus Connectivity, '
      'and connectivity_plus is a direct dependency (not merely transitive '
      'through internet_connection_checker)', () {
    // Pre-fix: this provider did not exist — there was no direct use of
    // connectivity_plus anywhere in this module, only the transitive copy
    // internet_connection_checker pulls in internally. Its existence with
    // the correct type is the platform-events source the story requires.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final connectivity = container.read(connectivityPlusProvider);
    expect(connectivity, isA<Connectivity>());

    final pubspec = File('pubspec.yaml').readAsStringSync();
    final directDepsSection = pubspec.split('dev_dependencies:').first;
    expect(
      directDepsSection,
      contains('connectivity_plus:'),
      reason:
          'connectivity_plus must be promoted to a direct dependency in '
          'pubspec.yaml, not left transitive-only in the lock',
    );
  });

  test('(b) no 5 s demo-host poll loop remains: the checker probes exactly ONE '
      'first-party host on a long (>= 3 min) interval', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final checker = container.read(internetConnectionCheckerProvider);

    // Pre-fix: InternetConnectionChecker.createInstance() with NO
    // overrides defaulted to 3 addresses (the demo hosts) and a 5 s
    // checkInterval — every assertion below fails against that code.
    expect(
      checker.addresses,
      hasLength(1),
      reason:
          'must probe exactly one host, never the package default of 3 '
          'demo hosts',
    );
    final host = checker.addresses.single.uri.host;
    const demoHosts = [
      'dummyapi.online',
      'jsonplaceholder.typicode.com',
      'fakestoreapi.com',
    ];
    expect(
      demoHosts,
      isNot(contains(host)),
      reason: 'must never be one of the 3 third-party demo hosts',
    );
    expect(
      host,
      'www.gstatic.com',
      reason: 'must be a single first-party/Google reachability endpoint',
    );
    expect(
      checker.checkInterval,
      greaterThanOrEqualTo(const Duration(minutes: 3)),
      reason:
          'must never default to (or be configured with) the package '
          "5 s interval — this is the '3-5 min' band the story requires",
    );
    expect(
      checker.checkInterval,
      lessThanOrEqualTo(const Duration(minutes: 5)),
      reason: "the interval must stay inside the story's '3-5 min' band",
    );
  });

  test(
    '(c) the false "idle CPU cost is ~0" comment is gone, replaced by a real '
    'cost-model description',
    () {
      final source = File(_sourcePath).readAsStringSync();

      expect(
        source,
        isNot(contains('idle CPU cost is ~0')),
        reason: 'the factually-wrong claim must be removed, not just moved',
      );
      expect(
        source,
        isNot(contains('event-driven instead of polling, so idle CPU cost')),
        reason: 'the specific false sentence must not survive verbatim',
      );
      // The corrected comment must describe the REAL cost model (the
      // pre-fix ~51,840 req/day figure and the ~99% post-fix reduction) —
      // not silently drop the sentence and leave no cost-model doc at all.
      expect(
        source,
        contains('51,840'),
        reason: 'the corrected comment must cite the real pre-fix cost',
      );
      expect(
        source,
        contains('99%'),
        reason: 'the corrected comment must cite the expected reduction',
      );
    },
  );
}
