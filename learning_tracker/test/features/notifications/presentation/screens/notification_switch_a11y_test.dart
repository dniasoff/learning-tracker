// Regression test for ST-3: notification switch controls expose no a11y labels.
//
// SYMPTOM: The Daily Reminder, Streak Alert, and Reward Notifications switches
// on the Notifications screen lack Semantics labels attached directly to the
// Switch node.  The label text lives in a sibling node, so screen readers
// announce the switch as unlabeled ("Switch, on/off" with no name).
//
// ROOT CAUSE: _NotificationSwitchRow renders a bare Switch() widget with no
// wrapping Semantics(label:) or tooltipMessage.  The semantic tree has the
// title Text in a separate leaf so assistive tech cannot associate them.
//
// FIX UNDER TEST: Each Switch must be wrapped in a Semantics widget whose
// [label] is set to the row title, so the accessibility node reads
// "Daily Reminder, Switch, on" etc.
//
// TESTS:
//   A1. Daily Reminder switch has a non-empty semantics label.
//   A2. Streak Alert switch has a non-empty semantics label.
//   A3. Reward Notifications switch has a non-empty semantics label.

@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Returns the Semantics label of the Switch that is a descendant of [ancestor].
/// Returns null if no Semantics node with a label is found.
String? _switchLabel(WidgetTester tester, Finder ancestor) {
  final switchFinder = find.descendant(
    of: ancestor,
    matching: find.byType(Switch),
  );
  if (switchFinder.evaluate().isEmpty) return null;

  // Walk the semantic tree to find the label on the Switch's Semantics node.
  final semantics = tester.getSemantics(switchFinder);
  return semantics.label.isNotEmpty ? semantics.label : null;
}

void main() {
  late _MockNotificationGateway mockService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockService = _MockNotificationGateway();
    when(() => mockService.hasPermission()).thenAnswer((_) async => true);
    when(() => mockService.requestPermission()).thenAnswer((_) async => true);
  });

  // -------------------------------------------------------------------------
  // A1. Daily Reminder switch has a semantics label.
  // -------------------------------------------------------------------------
  testWidgets(
    'A1. Daily Reminder switch exposes a non-empty accessibility label',
    (tester) async {
      await tester.pumpWidget(_buildSubject(mockService: mockService));
      await tester.pumpAndSettle();

      final label = _switchLabel(
        tester,
        find.byKey(const Key('reminder_toggle')),
      );

      expect(
        label,
        isNotNull,
        reason:
            'Daily Reminder switch must have a Semantics label so screen '
            'readers can identify it',
      );
      expect(
        label!.toLowerCase(),
        contains('reminder'),
        reason:
            'The label should reference "reminder" so users know which toggle '
            'they are operating',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // A2. Streak Alert switch has a semantics label.
  // -------------------------------------------------------------------------
  testWidgets(
    'A2. Streak Alert switch exposes a non-empty accessibility label',
    (tester) async {
      await tester.pumpWidget(_buildSubject(mockService: mockService));
      await tester.pumpAndSettle();

      final label = _switchLabel(
        tester,
        find.byKey(const Key('streak_alert_toggle')),
      );

      expect(
        label,
        isNotNull,
        reason:
            'Streak Alert switch must have a Semantics label so screen '
            'readers can identify it',
      );
      expect(
        label!.toLowerCase(),
        contains('streak'),
        reason:
            'The label should reference "streak" so users know which toggle '
            'they are operating',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // A3. Reward Notifications switch has a semantics label.
  // -------------------------------------------------------------------------
  testWidgets(
    'A3. Reward Notifications switch exposes a non-empty accessibility label',
    (tester) async {
      await tester.pumpWidget(_buildSubject(mockService: mockService));
      await tester.pumpAndSettle();

      final label = _switchLabel(
        tester,
        find.byKey(const Key('reward_notification_toggle')),
      );

      expect(
        label,
        isNotNull,
        reason:
            'Reward Notifications switch must have a Semantics label so screen '
            'readers can identify it',
      );
      expect(
        label!.toLowerCase(),
        anyOf(contains('reward'), contains('notification')),
        reason:
            'The label should reference "reward" or "notification" so users '
            'know which toggle they are operating',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
