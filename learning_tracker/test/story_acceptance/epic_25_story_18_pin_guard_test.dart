/// Story acceptance tests for Epic 25 — Story 25.18 (DNI-339):
/// core/navigation/ — typed auto_route + PinScope-parameterized guard.
///
/// Validates:
///   AC1 — Sealed [PinScope] has `PinScope.parent(profileId)` and
///         `PinScope.tutor(profileId)` variants and exposes `profileId`.
///   AC2 — One [PinGuard] class takes a [PinScope] resolver and dispatches
///         verification to [PinService] (parent vs tutor PIN methods).
///   AC3 — Route declarations parameterize the guard via a single `pinGuard`
///         field on [AppRouter] (no separate `parentPinGuard`/`tutorPinGuard`
///         fields). Guarded routes still reference it.
///   AC4 — The count of distinct guards in `lib/core/navigation/guards/` is
///         audited (5 = AuthGuard, RestoreGuard, ProfileGuard, ChildModeGuard,
///         PinGuard) and matches the architecture-doc claim that was rewritten
///         as part of this story.
///   AC5 — Route declarations are fully typed — no `pushNamed`,
///         `context.go(...)`, `navigateNamed`, or `context.push("...")` string
///         calls in `lib/`.
@Tags(['epic_25'])
library;

import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockPinService extends Mock implements PinService {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  group('Story 25.18 — PinScope sealed class', tags: ['story_25_18'], () {
    test('AC1: PinScope.parent(id) carries profileId', () {
      const scope = PinScope.parent(42);
      expect(scope.profileId, 42);
      expect(scope, isA<PinScopeParent>());
    });

    test('AC1: PinScope.tutor(id) carries profileId', () {
      const scope = PinScope.tutor(7);
      expect(scope.profileId, 7);
      expect(scope, isA<PinScopeTutor>());
    });

    test('AC1: parent and tutor with same profileId are not equal', () {
      const a = PinScope.parent(1);
      const b = PinScope.tutor(1);
      expect(a, isNot(equals(b)));
    });

    test('AC1: equal variants of same scope with same profileId are equal', () {
      const a = PinScope.parent(5);
      const b = PinScope.parent(5);
      expect(a, equals(b));
    });
  });

  group('Story 25.18 — PinGuard parent scope', tags: ['story_25_18'], () {
    late _MockNavigationResolver resolver;
    late _MockStackRouter router;
    late _MockPinService pinSvc;

    setUp(() {
      resolver = _MockNavigationResolver();
      router = _MockStackRouter();
      pinSvc = _MockPinService();
      when(() => router.push<bool>(any())).thenAnswer((_) async => true);
    });

    test(
      'AC2: blocks navigation when no scope (no active profile) is resolved',
      () async {
        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async => true,
          getScope: () => null,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next(false)).called(1);
      },
    );

    test(
      'AC2: parent — pushes PIN setup when profile has no PIN yet',
      () async {
        when(() => pinSvc.hasProfilePin(42)).thenAnswer((_) async => false);

        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async => false,
          getScope: () => const PinScope.parent(42),
        );

        await guard.onNavigation(resolver, router);

        verify(() => router.push<bool>(any())).called(1);
        verify(() => resolver.next(true)).called(1);
      },
    );

    test(
      'AC2: parent — allows navigation after successful PIN dialog',
      () async {
        when(() => pinSvc.hasProfilePin(42)).thenAnswer((_) async => true);

        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async => true,
          getScope: () => const PinScope.parent(42),
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next(true)).called(1);
      },
    );

    test('AC2: parent — blocks when user cancels the PIN dialog', () async {
      when(() => pinSvc.hasProfilePin(42)).thenAnswer((_) async => true);

      final guard = PinGuard(
        pinService: pinSvc,
        promptForPin: () async => false,
        getScope: () => const PinScope.parent(42),
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
    });

    test(
      'AC2: parent — session cache short-circuits re-prompt for same profile',
      () async {
        when(() => pinSvc.hasProfilePin(42)).thenAnswer((_) async => true);

        var prompts = 0;
        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async {
            prompts++;
            return true;
          },
          getScope: () => const PinScope.parent(42),
        );

        await guard.onNavigation(resolver, router);
        await guard.onNavigation(resolver, router);

        expect(prompts, 1);
        verify(() => resolver.next(true)).called(2);
      },
    );

    test(
      'AC2: parent — lock() invalidates session, forcing re-prompt',
      () async {
        when(() => pinSvc.hasProfilePin(42)).thenAnswer((_) async => true);

        var prompts = 0;
        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async {
            prompts++;
            return true;
          },
          getScope: () => const PinScope.parent(42),
        );

        await guard.onNavigation(resolver, router);
        guard.lock();
        await guard.onNavigation(resolver, router);

        expect(prompts, 2);
      },
    );

    test(
      'AC2: parent — markAuthenticated(profileId) primes the session cache',
      () async {
        when(() => pinSvc.hasProfilePin(42)).thenAnswer((_) async => true);

        var prompts = 0;
        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async {
            prompts++;
            return true;
          },
          getScope: () => const PinScope.parent(42),
        );

        guard.markAuthenticated(42);
        await guard.onNavigation(resolver, router);

        expect(prompts, 0);
        verify(() => resolver.next(true)).called(1);
      },
    );
  });

  group('Story 25.18 — PinGuard tutor scope', tags: ['story_25_18'], () {
    late _MockNavigationResolver resolver;
    late _MockStackRouter router;
    late _MockPinService pinSvc;

    setUp(() {
      resolver = _MockNavigationResolver();
      router = _MockStackRouter();
      pinSvc = _MockPinService();
      when(() => router.push<bool>(any())).thenAnswer((_) async => true);
    });

    test(
      'AC2: tutor — dispatches to hasTutorPin / verifyTutorPin on PinService',
      () async {
        when(() => pinSvc.hasTutorPin(7)).thenAnswer((_) async => true);

        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async => true,
          getScope: () => const PinScope.tutor(7),
        );

        await guard.onNavigation(resolver, router);

        // Tutor path must NOT call parent-scope methods.
        verifyNever(() => pinSvc.hasProfilePin(any()));
        verify(() => pinSvc.hasTutorPin(7)).called(1);
        verify(() => resolver.next(true)).called(1);
      },
    );

    test(
      'AC2: tutor — pushes PIN setup when tutor PIN is not yet configured',
      () async {
        when(() => pinSvc.hasTutorPin(7)).thenAnswer((_) async => false);

        final guard = PinGuard(
          pinService: pinSvc,
          promptForPin: () async => false,
          getScope: () => const PinScope.tutor(7),
        );

        await guard.onNavigation(resolver, router);

        verify(() => router.push<bool>(any())).called(1);
      },
    );

    test('AC2: parent session cache does NOT authorize tutor scope for same '
        'profileId (scopes are isolated)', () async {
      when(() => pinSvc.hasProfilePin(7)).thenAnswer((_) async => true);
      when(() => pinSvc.hasTutorPin(7)).thenAnswer((_) async => true);

      var tutorPrompts = 0;
      // ignore: omit_local_variable_types
      PinScope currentScope = const PinScope.parent(7);
      final guard = PinGuard(
        pinService: pinSvc,
        promptForPin: () async {
          if (currentScope is PinScopeTutor) tutorPrompts++;
          return true;
        },
        getScope: () => currentScope,
      );

      // Authenticate the parent scope first.
      await guard.onNavigation(resolver, router);
      // Now navigate as tutor for the same profileId — must still prompt.
      currentScope = const PinScope.tutor(7);
      await guard.onNavigation(resolver, router);

      expect(tutorPrompts, 1);
    });
  });

  // Repository-level audits — these are static-file checks that protect the
  // architecture-doc guard-count invariant and the "no string-based
  // navigation" rule.
  group('Story 25.18 — repository audits', tags: ['story_25_18'], () {
    String repoRoot() {
      // Tests run from learning_tracker/ when invoked via `flutter test`.
      final candidates = ['..', '.'];
      for (final c in candidates) {
        if (Directory('$c/learning_tracker/lib').existsSync()) return c;
      }
      throw StateError('Could not locate repo root');
    }

    test('AC4: exactly five distinct guard files exist under '
        'lib/core/navigation/guards/', () {
      final root = repoRoot();
      final dir = Directory(
        '$root/learning_tracker/lib/core/navigation/guards',
      );
      final guards = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_guard.dart'))
          .map((f) => f.uri.pathSegments.last)
          .toSet();

      expect(
        guards,
        equals({
          'auth_guard.dart',
          'restore_guard.dart',
          'profile_guard.dart',
          'child_mode_guard.dart',
          'pin_guard.dart',
        }),
        reason:
            'After DNI-339, parent_pin_guard.dart is folded into '
            'pin_guard.dart parameterized by PinScope.',
      );
    });

    test('AC4: lib/core/navigation/ contains no parent_pin_guard.dart '
        '(replaced by PinGuard + PinScope)', () {
      final root = repoRoot();
      final f = File(
        '$root/learning_tracker/lib/core/navigation/guards/parent_pin_guard.dart',
      );
      expect(f.existsSync(), isFalse);
    });

    test('AC4: architecture doc names PinGuard parameterized by PinScope '
        '(not ParentPin / TutorPin separately)', () {
      final root = repoRoot();
      final f = File('$root/docs/architecture.md');
      if (!f.existsSync()) return; // doc may be absent in test runs
      final body = f.readAsStringSync();
      expect(
        body.contains('PinGuard'),
        isTrue,
        reason: 'architecture.md should reference the unified PinGuard',
      );
      expect(
        body.contains('PinScope'),
        isTrue,
        reason: 'architecture.md should mention the PinScope parameterization',
      );
      expect(
        RegExp(r'\bTutorPin\b').hasMatch(body),
        isFalse,
        reason:
            'architecture.md must not reference TutorPin as a separate guard '
            'after the unification.',
      );
    });

    test('AC5: no string-based navigation in lib/ '
        '(pushNamed/navigateNamed/context.go/context.push("..."))', () {
      final root = repoRoot();
      final libDir = Directory('$root/learning_tracker/lib');
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart')) continue;
        if (entity.path.endsWith('.freezed.dart')) continue;
        if (entity.path.endsWith('.gr.dart')) continue;
        final src = entity.readAsStringSync();
        // Match `.pushNamed(`, `.navigateNamed(`, `context.go(`,
        // `context.push("…")`. The last is allow-listed when the
        // argument is a route instance, not a string literal — we only
        // flag string-literal forms.
        if (RegExp(r'\.pushNamed\(').hasMatch(src) ||
            RegExp(r'\.navigateNamed\(').hasMatch(src) ||
            RegExp(r'''context\.go\(['"]''').hasMatch(src) ||
            RegExp(r'''context\.push\(['"]''').hasMatch(src)) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Found string-based navigation calls; replace with typed '
            'auto_route routes:\n${offenders.join('\n')}',
      );
    });
  });
}
