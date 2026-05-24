/// WS5.two-layers — Widget tests for the device-level OS notification toggle.
///
/// DEC-27: two notification layers:
///   1. Device-level OS toggle (available even on empty-login surface)
///   2. Per-profile reminder schedules (layer 2, shown in NotificationsScreen)
///
/// These tests verify layer 1 (DeviceNotificationToggle) exists and is
/// structurally separate from per-profile reminder controls.
@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/features/notifications/presentation/widgets/device_notification_toggle.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationGateway extends Mock implements NotificationGateway {}

Widget _buildWithProviders({
  required Widget child,
  NotificationGateway? gatewayOverride,
}) {
  return ProviderScope(
    overrides: [
      if (gatewayOverride != null)
        notificationServiceProvider.overrideWithValue(gatewayOverride),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WS5.two-layers — DeviceNotificationToggle widget', () {
    testWidgets('DeviceNotificationToggle renders with key device_notification_toggle',
        (tester) async {
      final mockGateway = MockNotificationGateway();
      when(() => mockGateway.hasPermission()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildWithProviders(
          gatewayOverride: mockGateway,
          child: const Scaffold(body: DeviceNotificationToggle()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('device_notification_toggle')), findsOneWidget);
    });

    testWidgets('DeviceNotificationToggle is a SwitchListTile', (tester) async {
      final mockGateway = MockNotificationGateway();
      when(() => mockGateway.hasPermission()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildWithProviders(
          gatewayOverride: mockGateway,
          child: const Scaffold(body: DeviceNotificationToggle()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });

  group('WS5.two-layers — NotificationsScreen contains both layers', () {
    testWidgets(
        'NotificationsScreen shows device toggle (layer 1) AND per-profile toggles (layer 2)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockGateway = MockNotificationGateway();
      when(() => mockGateway.hasPermission()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildWithProviders(
          gatewayOverride: mockGateway,
          child: const NotificationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Layer 1: device toggle.
      expect(
        find.byKey(const Key('device_notification_toggle')),
        findsOneWidget,
      );

      // Layer 2: per-profile toggles (daily reminder + streak alert).
      expect(find.byKey(const Key('reminder_toggle')), findsOneWidget);
      expect(find.byKey(const Key('streak_alert_toggle')), findsOneWidget);

      // The two layers are distinct widgets.
      expect(
        find.byKey(const Key('device_notification_toggle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reminder_toggle')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
