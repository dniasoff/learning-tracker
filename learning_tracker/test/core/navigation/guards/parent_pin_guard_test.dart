import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:mocktail/mocktail.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;

  setUp(() {
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();
  });

  group('ParentPinGuard', () {
    test('allows navigation when PIN is already verified', () async {
      final guard = ParentPinGuard(
        isPinVerified: () => true,
        promptForPin: () async => false,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(true)).called(1);
    });

    test(
      'blocks navigation and triggers PIN prompt when not verified',
      () async {
        var promptCalled = false;

        final guard = ParentPinGuard(
          isPinVerified: () => false,
          promptForPin: () async {
            promptCalled = true;
            return false;
          },
        );

        await guard.onNavigation(mockResolver, mockRouter);

        expect(promptCalled, isTrue);
        verify(() => mockResolver.next(false)).called(1);
      },
    );

    test('allows navigation after successful PIN prompt', () async {
      final guard = ParentPinGuard(
        isPinVerified: () => false,
        promptForPin: () async => true,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(true)).called(1);
    });
  });
}
