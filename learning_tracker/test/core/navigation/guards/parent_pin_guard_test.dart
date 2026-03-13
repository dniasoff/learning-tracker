import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class MockPinService extends Mock implements PinService {}

void main() {
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;
  late MockPinService mockPinService;

  setUp(() {
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();
    mockPinService = MockPinService();
  });

  group('ParentPinGuard', () {
    test('allows navigation when no parent PIN has been set', () async {
      when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => null,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(true)).called(1);
    });

    test('blocks navigation and triggers PIN prompt when PIN is set', () async {
      var promptCalled = false;

      when(() => mockPinService.hasParentPin()).thenAnswer((_) async => true);
      when(
        () => mockPinService.verifyParentPin(any()),
      ).thenAnswer((_) async => false);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async {
          promptCalled = true;
          return '0000';
        },
      );

      await guard.onNavigation(mockResolver, mockRouter);

      expect(promptCalled, isTrue);
      verify(() => mockResolver.next(false)).called(1);
    });

    test('allows navigation after successful PIN prompt', () async {
      when(() => mockPinService.hasParentPin()).thenAnswer((_) async => true);
      when(
        () => mockPinService.verifyParentPin('1234'),
      ).thenAnswer((_) async => true);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => '1234',
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(true)).called(1);
    });

    test('blocks navigation when user cancels the PIN prompt', () async {
      when(() => mockPinService.hasParentPin()).thenAnswer((_) async => true);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => null, // cancelled
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(false)).called(1);
    });
  });
}
