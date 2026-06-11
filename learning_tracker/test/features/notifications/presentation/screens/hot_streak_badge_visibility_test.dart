// Regression test for ST-2: HOT STREAK badge stays shown when Streak Alert
// toggle is OFF.
//
// SYMPTOM: The "HOT STREAK" badge is a static label that remains visible even
// when the Streak Alert toggle is OFF and the time row is greyed out.  The
// badge falsely implies the streak alert is active.
//
// ROOT CAUSE: The badge is passed unconditionally as [trailingTopBadge] to
// _NotificationSwitchRow regardless of [streakAlertEnabled].
//
// FIX UNDER TEST: Show the badge only when [streakAlertEnabled] is true;
// hide/omit it when the toggle is OFF.
//
// TESTS:
//   S1. Badge visible when Streak Alert is ON (default).
//   S2. Badge hidden when Streak Alert is OFF (pre-stored pref = false).
//   S3. Badge disappears after the user taps the Streak Alert toggle to OFF.

@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNotificationGateway extends Mock implements NotificationGateway {}

Widget _buildSubject({required NotificationGateway mockService}) {
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

void main() {
  late _MockNotificationGateway mockService;

  setUp(() {
    mockService = _MockNotificationGateway();
    when(() => mockService.hasPermission()).thenAnswer((_) async => true);
    when(() => mockService.requestPermission()).thenAnswer((_) async => true);
  });

  // The l10n key is notifHotStreakBadge = "HOT STREAK".
  const badgeText = 'HOT STREAK';

  // -------------------------------------------------------------------------
  // S1. Badge visible when Streak Alert is ON (default: true).
  // -------------------------------------------------------------------------
  testWidgets('S1. HOT STREAK badge is visible when streak alert is ON', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_buildSubject(mockService: mockService));
    await tester.pumpAndSettle();

    expect(
      find.text(badgeText),
      findsOneWidget,
      reason: 'Badge must be visible when streak alert toggle is ON (default)',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // -------------------------------------------------------------------------
  // S2. Badge hidden when Streak Alert pref is pre-stored as false.
  // -------------------------------------------------------------------------
  testWidgets(
    'S2. HOT STREAK badge is hidden when streak alert pref is stored as OFF',
    (tester) async {
      // Profile 0 (default test container) has streak alert disabled.
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.streakAlertEnabledKey(0): false,
      });

      await tester.pumpWidget(_buildSubject(mockService: mockService));
      // Wait for async pref load to propagate.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.text(badgeText),
        findsNothing,
        reason:
            'Badge must be hidden when streak alert is OFF (stored pref = false)',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // S3. Badge disappears when the user taps the toggle to OFF.
  // -------------------------------------------------------------------------
  testWidgets(
    'S3. HOT STREAK badge disappears when user toggles streak alert OFF',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSubject(mockService: mockService));
      await tester.pumpAndSettle();

      // Confirm badge is initially visible.
      expect(
        find.text(badgeText),
        findsOneWidget,
        reason: 'Badge should be visible initially (streak alert ON)',
      );

      // Tap the streak alert toggle to turn it OFF.
      final streakSwitch = find.descendant(
        of: find.byKey(const Key('streak_alert_toggle')),
        matching: find.byType(Switch),
      );
      await tester.tap(streakSwitch);
      await tester.pumpAndSettle();

      expect(
        find.text(badgeText),
        findsNothing,
        reason: 'Badge must disappear after user turns streak alert OFF',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
