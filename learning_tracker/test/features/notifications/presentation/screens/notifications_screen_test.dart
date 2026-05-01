@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationsScreen(),
      ),
    );
  }

  testWidgets('shows reminder toggle and time', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Daily Reminder'), findsOneWidget);
    expect(find.text('Reminder Time'), findsOneWidget);
    expect(find.byKey(const Key('reminder_toggle')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('shows streak alert toggle and time', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Streak Alert'), findsOneWidget);
    expect(find.text('Streak Alert Time'), findsOneWidget);
    expect(find.byKey(const Key('streak_alert_toggle')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('shows reward notification toggle', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Reward Notifications'), findsOneWidget);
    expect(find.byKey(const Key('reward_notification_toggle')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('shows Shabbos mode toggle with explanation', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.textContaining('Shabbos'), findsWidgets);
    expect(find.byKey(const Key('shabbos_mode_toggle')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('time pickers for reminder and streak alert times', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap reminder time (key appears on both the row widget and inner ListTile)
    await tester.tap(find.byKey(const Key('reminder_time')).last);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);

    // Dismiss
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('toggle requests permission on Android 13+', (tester) async {
    when(() => mockService.requestPermission()).thenAnswer((_) async => true);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final reminderSwitch = find.descendant(
      of: find.byKey(const Key('reminder_toggle')),
      matching: find.byType(Switch),
    );

    // Toggle off first (default is on)
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    // Toggle back on → should request permission
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    verify(() => mockService.requestPermission()).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Shabbos mode toggle reveals configuration options', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Enable Shabbos mode by tapping the toggle
    await tester.tap(find.byKey(const Key('shabbos_mode_toggle')).last);
    await tester.pumpAndSettle();

    // Sub-options should be visible when Shabbos mode is enabled
    expect(
      find.byKey(const Key('shabbos_use_location_toggle')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
