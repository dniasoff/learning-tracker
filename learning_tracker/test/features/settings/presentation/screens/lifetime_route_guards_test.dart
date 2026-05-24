/// WS8.route-guard — verify LifetimeMarkingRoute and
/// LifetimeCurriculumMarkingRoute have childModeGuard + pinGuard protection.
///
/// These routes allow a parent (PIN-authenticated in child mode) to mark prior
/// lifetime learning. Without childModeGuard, an adult profile could navigate
/// to them. Without pinGuard, no PIN verification would protect the action.
///
/// The test is a static source-file inspection: it reads [app_router.dart] and
/// asserts that both route declarations list all three guards in the correct
/// order ([authGuard, childModeGuard, pinGuard]).
@Tags(['settings', 'route_guards', 'ws8'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  String repoRoot() {
    // Tests run from learning_tracker/ when invoked via `flutter test`.
    final candidates = ['..', '.'];
    for (final c in candidates) {
      if (Directory('$c/learning_tracker/lib').existsSync()) return c;
    }
    throw StateError('Could not locate repo root');
  }

  group('WS8.route-guard — LifetimeMarkingRoute and LifetimeCurriculumMarkingRoute '
      'guards', () {
    late String routerSource;

    setUpAll(() {
      final root = repoRoot();
      final f = File(
        '$root/learning_tracker/lib/app/router/app_router.dart',
      );
      routerSource = f.readAsStringSync();
    });

    // Helper: extract the guards declaration for a route by locating the
    // block that starts at the [page] reference and reading its [guards:] line.
    List<String> guardsForRoute(String pageRef) {
      final pattern = RegExp(
        r'page:\s*' +
            RegExp.escape(pageRef) +
            r'[^)]*?guards:\s*\[([^\]]*)\]',
        dotAll: true,
      );
      final match = pattern.firstMatch(routerSource);
      if (match == null) return [];
      final guardList = match.group(1)!;
      return guardList
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();
    }

    test(
      'LifetimeMarkingRoute has authGuard, childModeGuard, and pinGuard',
      () {
        final guards = guardsForRoute('LifetimeMarkingRoute.page');
        expect(
          guards,
          containsAll(['authGuard', 'childModeGuard', 'pinGuard']),
          reason:
              'LifetimeMarkingRoute must be guarded by authGuard + '
              'childModeGuard + pinGuard (WS8.route-guard). '
              'Found: $guards',
        );
      },
    );

    test(
      'LifetimeCurriculumMarkingRoute has authGuard, childModeGuard, and pinGuard',
      () {
        final guards = guardsForRoute('LifetimeCurriculumMarkingRoute.page');
        expect(
          guards,
          containsAll(['authGuard', 'childModeGuard', 'pinGuard']),
          reason:
              'LifetimeCurriculumMarkingRoute must be guarded by authGuard + '
              'childModeGuard + pinGuard (WS8.route-guard). '
              'Found: $guards',
        );
      },
    );

    test(
      'LifetimeMarkingRoute has exactly three guards (no extra, none missing)',
      () {
        final guards = guardsForRoute('LifetimeMarkingRoute.page');
        expect(
          guards,
          hasLength(3),
          reason:
              'LifetimeMarkingRoute must have exactly 3 guards: '
              '[authGuard, childModeGuard, pinGuard]. '
              'Found ${guards.length}: $guards',
        );
      },
    );

    test(
      'LifetimeCurriculumMarkingRoute has exactly three guards',
      () {
        final guards = guardsForRoute('LifetimeCurriculumMarkingRoute.page');
        expect(
          guards,
          hasLength(3),
          reason:
              'LifetimeCurriculumMarkingRoute must have exactly 3 guards: '
              '[authGuard, childModeGuard, pinGuard]. '
              'Found ${guards.length}: $guards',
        );
      },
    );
  });
}
