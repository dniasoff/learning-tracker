import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class _Resolver extends Mock implements NavigationResolver {}

class _Router extends Mock implements StackRouter {}

class _PinService extends Mock implements PinService {}

class _Route extends Fake implements PageRouteInfo {}

LearnerProfileEntity _child() => LearnerProfileEntity(
  profileId: 'child-1',
  displayName: 'Child',
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(() => registerFallbackValue(_Route()));

  test(
    'a child cannot open hidden content without a verified parent PIN',
    () async {
      final childMode = ChildModeGuard(
        getProfileById: (_) async => _child(),
        getSelectedProfileId: () => 'child-1',
      );
      final pinService = _PinService();
      when(
        () => pinService.hasProfilePin('child-1'),
      ).thenAnswer((_) async => true);
      final pin = PinGuard(
        pinService: pinService,
        promptForPin: () async => false,
        getScope: () => const PinScopeParent('child-1'),
        pinSetupRoute: () => _Route(),
      );
      final resolver = _Resolver();
      final router = _Router();
      when(() => resolver.isResolved).thenReturn(false);

      await childMode.onNavigation(resolver, router);
      await pin.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verify(() => resolver.next(false)).called(1);
    },
  );

  test('parent PIN entry is accepted for the hidden-content route', () async {
    final pinService = _PinService();
    when(
      () => pinService.hasProfilePin('child-1'),
    ).thenAnswer((_) async => true);
    final pin = PinGuard(
      pinService: pinService,
      promptForPin: () async => true,
      getScope: () => const PinScopeParent('child-1'),
      pinSetupRoute: () => _Route(),
    );
    final resolver = _Resolver();
    final router = _Router();
    when(() => resolver.isResolved).thenReturn(false);

    await pin.onNavigation(resolver, router);

    verify(() => resolver.next(true)).called(1);
  });

  test(
    'active tutor PIN entry is accepted for the hidden-content route',
    () async {
      final pinService = _PinService();
      when(
        () => pinService.hasTutorPin('tutor-1'),
      ).thenAnswer((_) async => true);
      final pin = PinGuard(
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => const PinScopeTutor('tutor-1'),
        pinSetupRoute: () => _Route(),
      );
      final resolver = _Resolver();
      final router = _Router();
      when(() => resolver.isResolved).thenReturn(false);

      await pin.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
    },
  );
}
