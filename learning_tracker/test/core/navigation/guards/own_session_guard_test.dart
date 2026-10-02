/// DNI-513 AC-1: [OwnSessionGuard] keeps a tutor's device acting for a
/// talmid out of parent-only views (the parent Change history), even by
/// deep link, and fails closed.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/own_session_guard.dart';
import 'package:mocktail/mocktail.dart';

class _Resolver extends Mock implements NavigationResolver {}

class _Router extends Mock implements StackRouter {}

Future<bool?> _decide(OwnSessionGuard guard) async {
  final resolver = _Resolver();
  bool? decision;
  when(() => resolver.isResolved).thenAnswer((_) => decision != null);
  when(() => resolver.next(any())).thenAnswer((call) {
    decision = call.positionalArguments.first as bool;
  });
  await guard.onNavigation(resolver, _Router());
  return decision;
}

void main() {
  test('lets an own (non-tutored) session through', () async {
    expect(
      await _decide(OwnSessionGuard(isTutoredSession: () => false)),
      isTrue,
    );
  });

  test('refuses a tutored session', () async {
    expect(
      await _decide(OwnSessionGuard(isTutoredSession: () => true)),
      isFalse,
    );
  });

  test('fails closed when the session cannot be resolved', () async {
    expect(
      await _decide(
        OwnSessionGuard(isTutoredSession: () => throw StateError('x')),
      ),
      isFalse,
    );
  });

  test('denyAll refuses every navigation', () async {
    expect(await _decide(OwnSessionGuard.denyAll()), isFalse);
  });
}
