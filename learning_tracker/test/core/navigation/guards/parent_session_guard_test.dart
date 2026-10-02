import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:mocktail/mocktail.dart';

class _Resolver extends Mock implements NavigationResolver {}

class _Router extends Mock implements StackRouter {}

class _FakeRoute extends Fake implements PageRouteInfo {}

Future<(bool?, _Router)> _decide(ParentSessionGuard guard) async {
  final resolver = _Resolver();
  final router = _Router();
  bool? decision;
  when(() => resolver.isResolved).thenAnswer((_) => decision != null);
  when(() => resolver.next(any())).thenAnswer((call) {
    decision = call.positionalArguments.first as bool;
  });
  when(() => router.navigate(any())).thenAnswer((_) async {});
  await guard.onNavigation(resolver, router);
  return (decision, router);
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeRoute()));

  test('lets a parent session through', () async {
    final (decision, _) = await _decide(
      ParentSessionGuard(isParentSession: () async => true),
    );
    expect(decision, isTrue);
  });

  test('refuses a child session (direct route or deep link)', () async {
    final (decision, router) = await _decide(
      ParentSessionGuard(isParentSession: () async => false),
    );
    expect(decision, isFalse);
    verifyNever(() => router.navigate(any()));
  });

  test('fails closed when the session cannot be resolved', () async {
    final (decision, _) = await _decide(
      ParentSessionGuard(isParentSession: () async => throw StateError('x')),
    );
    expect(decision, isFalse);
  });

  test('denyAll refuses every navigation', () async {
    final (decision, _) = await _decide(ParentSessionGuard.denyAll());
    expect(decision, isFalse);
  });

  group('redirectingTo (DNI-517 AC-2)', () {
    test('a refused navigation lands on the given page', () async {
      final (decision, router) = await _decide(
        ParentSessionGuard(
          isParentSession: () async => false,
        ).redirectingTo(() => const LifetimeKnowledgeRoute()),
      );
      expect(decision, isFalse);
      final landed =
          verify(() => router.navigate(captureAny())).captured.single
              as PageRouteInfo;
      expect(landed.routeName, LifetimeKnowledgeRoute.name);
    });

    test('so does a session that cannot be resolved', () async {
      final (decision, router) = await _decide(
        ParentSessionGuard(
          isParentSession: () async => throw StateError('x'),
        ).redirectingTo(() => const LifetimeKnowledgeRoute()),
      );
      expect(decision, isFalse);
      verify(() => router.navigate(any())).called(1);
    });

    test('an allowed navigation is not redirected', () async {
      final (decision, router) = await _decide(
        ParentSessionGuard(
          isParentSession: () async => true,
        ).redirectingTo(() => const LifetimeKnowledgeRoute()),
      );
      expect(decision, isTrue);
      verifyNever(() => router.navigate(any()));
    });
  });
}
