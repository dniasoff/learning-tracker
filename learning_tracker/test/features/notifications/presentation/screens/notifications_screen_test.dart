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

  testWidgets('time tile opens time picker when enabled', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder_time')));
    await tester.pumpAndSettle();

    // Time picker dialog should appear
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
