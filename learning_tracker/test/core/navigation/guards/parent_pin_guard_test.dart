import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class MockPinService extends Mock implements PinService {}

class FakePageRouteInfo extends Fake implements PageRouteInfo {}

void main() {
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;
  late MockPinService mockPinService;

  const testProfileId = 42;

  setUpAll(() {
    registerFallbackValue(FakePageRouteInfo());
  });

  setUp(() {
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();
    mockPinService = MockPinService();
    when(() => mockRouter.push<bool>(any())).thenAnswer((_) async => true);
  });

  group('ParentPinGuard', () {
    test('blocks navigation when no active profile is selected', () async {
      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => '1234',
        getProfileId: () => null,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(false)).called(1);
    });

    test('pushes PIN setup when profile has no PIN yet', () async {
      when(
        () => mockPinService.hasProfilePin(testProfileId),
      ).thenAnswer((_) async => false);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => null,
        getProfileId: () => testProfileId,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockRouter.push<bool>(any())).called(1);
      verify(() => mockResolver.next(true)).called(1);
    });

    test('blocks navigation and triggers PIN prompt when PIN is set', () async {
      var promptCalled = false;

      when(
        () => mockPinService.hasProfilePin(testProfileId),
      ).thenAnswer((_) async => true);
      when(
        () => mockPinService.verifyProfilePin(testProfileId, any()),
      ).thenAnswer((_) async => false);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async {
          promptCalled = true;
          return '0000';
        },
        getProfileId: () => testProfileId,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      expect(promptCalled, isTrue);
      verify(() => mockResolver.next(false)).called(1);
    });

    test('allows navigation after successful PIN prompt', () async {
      when(
        () => mockPinService.hasProfilePin(testProfileId),
      ).thenAnswer((_) async => true);
      when(
        () => mockPinService.verifyProfilePin(testProfileId, '1234'),
      ).thenAnswer((_) async => true);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => '1234',
        getProfileId: () => testProfileId,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(true)).called(1);
    });

    test('blocks navigation when user cancels the PIN prompt', () async {
      when(
        () => mockPinService.hasProfilePin(testProfileId),
      ).thenAnswer((_) async => true);

      final guard = ParentPinGuard(
        pinService: mockPinService,
        promptForPin: () async => null,
        getProfileId: () => testProfileId,
      );

      await guard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next(false)).called(1);
    });
  });
}
