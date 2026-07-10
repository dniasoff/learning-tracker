// L1 widget test — SyncStatusIndicator
//
// Covers every SyncStatus variant (7 states):
//   • localOnly  — smartphone icon, grey, 'Local only' tooltip
//   • synced     — cloud_done icon, green, 'Synced' tooltip
//   • syncing    — sync icon (spinning), primary colour, 'Syncing' tooltip
//   • pending    — schedule icon, orange, '$n pending' label
//   • offline    — cloud_off icon, grey, 'Offline' / '$n queued' label
//   • error      — warning_amber icon, red, 'Sync error' tooltip
//   • degraded   — sync_problem_rounded icon, orange, 'Sync paused' / '… queued'
//
// Both showLabel=false (tooltip-only) and showLabel=true (icon + text) are
// exercised.
//
// The widget watches [syncStatusProvider] (a plain Provider<SyncStatus>).
// We override it with overrideWithValue() so each test gets a deterministic
// state without touching any real infrastructure.

@Tags(['sync', 'sync_status_indicator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/widgets/sync_status_indicator.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a full ProviderScope+MaterialApp with only [syncStatusProvider]
/// overridden to [status]. [showLabel] controls which rendering mode is tested.
Widget _buildApp(SyncStatus status, {bool showLabel = false}) {
  return ProviderScope(
    overrides: [syncStatusProvider.overrideWithValue(status)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SyncStatusIndicator(showLabel: showLabel)),
    ),
  );
}

/// Pumps the widget and lets micro-tasks settle without pumpAndSettle (which
/// can hang if spinning animations are running).
Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Convenience teardown — disposes open timers / AnimationControllers before
/// the next test starts.
Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Icon colour helper ────────────────────────────────────────────────────────

/// Returns the [Color] of the first [Icon] widget whose [iconData] matches.
Color? _iconColor(WidgetTester tester, IconData iconData) {
  final iconWidget = tester.widget<Icon>(find.byIcon(iconData));
  return iconWidget.color;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // GoogleFonts offline mode is handled globally by flutter_test_config.dart.

  // ── showLabel=false (tooltip mode) ─────────────────────────────────────────

  group('SyncStatusIndicator (showLabel=false)', () {
    testWidgets(
      'localOnly — smartphone icon, grey colour, tooltip "Local only"',
      (tester) async {
        const status = SyncStatus.localOnly();
        await _pump(tester, _buildApp(status));

        expect(find.byIcon(Icons.smartphone), findsOneWidget);
        expect(_iconColor(tester, Icons.smartphone), Colors.grey);

        // Tooltip message is set even in icon-only mode
        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Local only');

        await _tearDown(tester);
      },
    );

    testWidgets('synced — cloud_done icon, green colour, tooltip "Synced"', (
      tester,
    ) async {
      final status = SyncStatus.synced(lastSyncedAt: DateTime(2025));
      await _pump(tester, _buildApp(status));

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(_iconColor(tester, Icons.cloud_done), Colors.green);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Synced');

      await _tearDown(tester);
    });

    testWidgets(
      'syncing — sync icon inside spinning widget, tooltip "Syncing"',
      (tester) async {
        final status = SyncStatus.syncing(startedAt: DateTime(2025));
        await _pump(tester, _buildApp(status));

        // The icon lives inside _SpinningIcon → RotationTransition.
        // We verify the sync icon is present; the RotationTransition wraps it.
        expect(find.byIcon(Icons.sync), findsOneWidget);
        // At least one RotationTransition is present in the widget tree
        // (there may be more from the MaterialApp scaffold animation).
        expect(find.byType(RotationTransition), findsWidgets);
        // Confirm RotationTransition is an ancestor of the sync Icon.
        expect(
          find.ancestor(
            of: find.byIcon(Icons.sync),
            matching: find.byType(RotationTransition),
          ),
          findsOneWidget,
          reason:
              'sync Icon must be wrapped in a RotationTransition (spinning)',
        );

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Syncing');

        await _tearDown(tester);
      },
    );

    testWidgets('pending — schedule icon, orange colour, tooltip "3 pending"', (
      tester,
    ) async {
      const status = SyncStatus.pending(pendingChanges: 3);
      await _pump(tester, _buildApp(status));

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(_iconColor(tester, Icons.schedule), Colors.orange);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, '3 pending');

      await _tearDown(tester);
    });

    testWidgets(
      'offline (0 queued) — cloud_off icon, grey, tooltip "Offline"',
      (tester) async {
        const status = SyncStatus.offline(pendingChanges: 0);
        await _pump(tester, _buildApp(status));

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(_iconColor(tester, Icons.cloud_off), Colors.grey);

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Offline');

        await _tearDown(tester);
      },
    );

    testWidgets(
      'offline (5 queued) — cloud_off icon, grey, tooltip "5 queued"',
      (tester) async {
        const status = SyncStatus.offline(pendingChanges: 5);
        await _pump(tester, _buildApp(status));

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, '5 queued');

        await _tearDown(tester);
      },
    );

    testWidgets(
      'error — warning_amber icon, red colour, tooltip "Sync error"',
      (tester) async {
        final status = SyncStatus.error(
          code: SyncErrorCode.permissionDenied,
          failedAt: DateTime(2025),
        );
        await _pump(tester, _buildApp(status));

        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(_iconColor(tester, Icons.warning_amber), Colors.red);

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Sync error');

        await _tearDown(tester);
      },
    );

    testWidgets('degraded (0 pending) — sync_problem_rounded icon, orange, '
        'tooltip "Sync paused"', (tester) async {
      const status = SyncStatus.degraded(pendingChanges: 0, reason: 'quota');
      await _pump(tester, _buildApp(status));

      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
      expect(_iconColor(tester, Icons.sync_problem_rounded), Colors.orange);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Sync paused');

      await _tearDown(tester);
    });

    testWidgets('degraded (4 pending) — sync_problem_rounded icon, orange, '
        'tooltip "Sync paused — 4 queued"', (tester) async {
      const status = SyncStatus.degraded(pendingChanges: 4, reason: 'quota');
      await _pump(tester, _buildApp(status));

      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Sync paused — 4 queued');

      await _tearDown(tester);
    });
  });

  // ── showLabel=true (icon + text mode) ──────────────────────────────────────

  group('SyncStatusIndicator (showLabel=true)', () {
    testWidgets('localOnly — text "Local only" visible, no Tooltip wrapper', (
      tester,
    ) async {
      const status = SyncStatus.localOnly();
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('Local only'), findsOneWidget);
      // In label mode the widget renders a Row, NOT a Tooltip.
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(Row), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('synced — text "Synced" visible in green', (tester) async {
      final status = SyncStatus.synced(lastSyncedAt: DateTime(2025));
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('Synced'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Synced'));
      expect(textWidget.style?.color, Colors.green);

      await _tearDown(tester);
    });

    testWidgets(
      'syncing — text "Syncing" visible + RotationTransition present',
      (tester) async {
        final status = SyncStatus.syncing(startedAt: DateTime(2025));
        await _pump(tester, _buildApp(status, showLabel: true));

        expect(find.text('Syncing'), findsOneWidget);
        // At least one RotationTransition must be present, wrapping the icon.
        expect(find.byType(RotationTransition), findsWidgets);
        expect(
          find.ancestor(
            of: find.byIcon(Icons.sync),
            matching: find.byType(RotationTransition),
          ),
          findsOneWidget,
          reason:
              'sync Icon must be wrapped in a RotationTransition (spinning)',
        );

        await _tearDown(tester);
      },
    );

    testWidgets('pending — text "7 pending" visible in orange', (tester) async {
      const status = SyncStatus.pending(pendingChanges: 7);
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('7 pending'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('7 pending'));
      expect(textWidget.style?.color, Colors.orange);

      await _tearDown(tester);
    });

    testWidgets('offline (0) — text "Offline" visible in grey', (tester) async {
      const status = SyncStatus.offline(pendingChanges: 0);
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('Offline'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Offline'));
      expect(textWidget.style?.color, Colors.grey);

      await _tearDown(tester);
    });

    testWidgets('offline (2) — text "2 queued" visible', (tester) async {
      const status = SyncStatus.offline(pendingChanges: 2);
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('2 queued'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('error — text "Sync error" visible in red', (tester) async {
      final status = SyncStatus.error(
        code: SyncErrorCode.unknown,
        failedAt: DateTime(2025),
      );
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('Sync error'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Sync error'));
      expect(textWidget.style?.color, Colors.red);

      await _tearDown(tester);
    });

    testWidgets('degraded (0) — text "Sync paused" visible in orange', (
      tester,
    ) async {
      const status = SyncStatus.degraded(pendingChanges: 0, reason: 'quota');
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('Sync paused'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Sync paused'));
      expect(textWidget.style?.color, Colors.orange);

      await _tearDown(tester);
    });

    testWidgets('degraded (3) — text "Sync paused — 3 queued" visible', (
      tester,
    ) async {
      const status = SyncStatus.degraded(pendingChanges: 3, reason: 'quota');
      await _pump(tester, _buildApp(status, showLabel: true));

      expect(find.text('Sync paused — 3 queued'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── State-change reactivity ─────────────────────────────────────────────────

  group('SyncStatusIndicator — provider reactivity', () {
    testWidgets(
      'rebuilds when syncStatusProvider changes from localOnly to synced',
      (tester) async {
        // Start with localOnly.
        final container = ProviderContainer(
          overrides: [
            syncStatusProvider.overrideWithValue(const SyncStatus.localOnly()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SyncStatusIndicator(showLabel: true)),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Local only'), findsOneWidget);

        // Transition to synced.
        container.updateOverrides([
          syncStatusProvider.overrideWithValue(
            SyncStatus.synced(lastSyncedAt: DateTime(2025)),
          ),
        ]);
        await tester.pump();

        expect(find.text('Synced'), findsOneWidget);
        expect(find.text('Local only'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── Hardcoded string audit ──────────────────────────────────────────────────
  //
  // All user-facing strings in SyncStatusIndicator are hardcoded English inside
  // the widget's switch expression (not sourced from AppLocalizations ARB).
  // This is a flag for future i18n work but is not a functional bug, so no
  // test is skipped — we document the finding here instead.
  //
  // Hardcoded strings found in sync_status_indicator.dart:
  //   'Local only', 'Synced', 'Syncing', '$n pending', '$n queued', 'Offline',
  //   'Sync error', 'Sync paused', 'Sync paused — $n queued'
}
