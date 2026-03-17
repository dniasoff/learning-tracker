@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockNotificationService mockService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockService = MockNotificationService();
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [notificationServiceProvider.overrideWithValue(mockService)],
      child: const MaterialApp(home: NotificationsScreen()),
    );
  }

  testWidgets('shows reminder toggle and time', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Daily Reminder'), findsOneWidget);
    expect(find.text('Reminder Time'), findsOneWidget);
    expect(find.byKey(const Key('reminder_toggle')), findsOneWidget);
  });

  testWidgets('shows streak alert toggle and time', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Streak Alert'), findsOneWidget);
    expect(find.text('Streak Alert Time'), findsOneWidget);
    expect(find.byKey(const Key('streak_alert_toggle')), findsOneWidget);
  });

  testWidgets('shows reward notification toggle', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Reward Notifications'), findsOneWidget);
    expect(find.byKey(const Key('reward_notification_toggle')), findsOneWidget);
  });

  testWidgets('shows Shabbos mode toggle with explanation', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Shabbos / Yom Tov Mode'), findsOneWidget);
    expect(
      find.text('Suppress all notifications during Shabbos and Yom Tov'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shabbos_mode_toggle')), findsOneWidget);
  });

  testWidgets('time pickers for reminder and streak alert times', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap reminder time
    await tester.tap(find.byKey(const Key('reminder_time')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);

    // Dismiss
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('toggle requests permission on Android 13+', (tester) async {
    when(() => mockService.requestPermission()).thenAnswer((_) async => true);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Toggle off first (default is on)
    await tester.tap(find.byKey(const Key('reminder_toggle')));
    await tester.pumpAndSettle();

    // Toggle back on → should request permission
    await tester.tap(find.byKey(const Key('reminder_toggle')));
    await tester.pumpAndSettle();

    verify(() => mockService.requestPermission()).called(1);
  });

  testWidgets('Shabbos mode toggle reveals configuration options', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(mockService),
          shabbosModeEnabledProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Sub-options should be visible when Shabbos mode is enabled
    expect(
      find.byKey(const Key('shabbos_use_location_toggle')),
      findsOneWidget,
    );

    // Scroll down to reveal time pickers
    await tester.scrollUntilVisible(
      find.byKey(const Key('shabbos_start_time')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('shabbos_start_time')), findsOneWidget);
    expect(find.byKey(const Key('shabbos_end_time')), findsOneWidget);
  });
}
