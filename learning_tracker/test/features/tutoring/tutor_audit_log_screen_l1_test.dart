// L1 widget test — TutorAuditLogScreen
//
// Tests the visual behaviour of the audit log screen:
//   - loading state while the FutureProvider is pending
//   - empty state (no entries at all)
//   - empty-filtered state (entries exist but all filtered out)
//   - data state: entries rendered as tiles
//   - filter chips appear for each TutorAuditAction
//   - filter chip selection filters the list
//   - clear-filters button appears only when filters are active
//   - error state shows AppErrorView
//   - before/after values rendered in a tile when present
//
// HARDCODED STRINGS AUDIT:
//   No hardcoded English user-facing strings found in tutor_audit_log_screen.dart —
//   all visible strings come from AppLocalizations.
//   Timestamp formatting uses dd/mm and HH:mm directly (no l10n, intentionally).

@Tags(['l1', 'tutor_mode', 'audit_log'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/audit_log_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_audit_log_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

const _grantId = 'grant-abc-123';
const _tutorEmail = 'tutor@example.com';

/// Wraps the screen with the canonical ProviderScope + MaterialApp pump rig.
Widget _buildApp({required AsyncValue<List<TutorAuditLogEntry>> value}) {
  return ProviderScope(
    overrides: [
      tutorAuditLogProvider(_grantId).overrideWith(
        (ref) => switch (value) {
          AsyncData(:final value) => Future.value(value),
          AsyncError(:final error, :final stackTrace) => Future.error(
            error,
            stackTrace,
          ),
          _ => Future.delayed(const Duration(hours: 1)), // never completes
        },
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TutorAuditLogScreen(grantId: _grantId, tutorEmail: _tutorEmail),
    ),
  );
}

/// Canonical pump: initial frame + 1 second for async.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Tear-down helper to drain pending timers.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Factory helpers ───────────────────────────────────────────────────────────

TutorAuditLogEntry _entry({
  String entryId = 'e1',
  String tutorUid = 'uid-1',
  String tutorNameSnapshot = 'Rabbi Tutor',
  TutorAuditAction action = TutorAuditAction.goalChanged,
  String target = 'goal/g1.targetDate',
  DateTime? timestamp,
  String? beforeValue,
  String? afterValue,
}) {
  return TutorAuditLogEntry(
    entryId: entryId,
    tutorUid: tutorUid,
    tutorNameSnapshot: tutorNameSnapshot,
    action: action,
    target: target,
    timestamp:
        timestamp ?? DateTime(2024, 3, 15, 10, 30), // today-agnostic fixed date
    beforeValue: beforeValue,
    afterValue: afterValue,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // flutter_test_config.dart already sets GoogleFonts.config.allowRuntimeFetching = false

  // ── App bar ───────────────────────────────────────────────────────────────

  group('App bar', () {
    testWidgets('shows "Audit Log" title', (tester) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(find.text('Audit Log'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('shows tutor email as subtitle', (tester) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(find.text(_tutorEmail), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('clear-filters button NOT shown when no filters active', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(find.byIcon(Icons.filter_alt_off_rounded), findsNothing);

      await _teardown(tester);
    });
  });

  // ── Loading state ─────────────────────────────────────────────────────────

  group('Loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      // Use a Completer so the future genuinely never resolves during the test.
      final completer = Completer<List<TutorAuditLogEntry>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorAuditLogProvider(
              _grantId,
            ).overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TutorAuditLogScreen(
              grantId: _grantId,
              tutorEmail: _tutorEmail,
            ),
          ),
        ),
      );
      // One pump — Riverpod has submitted the future but it hasn't completed.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future so teardown is clean.
      completer.complete([]);
      await _teardown(tester);
    });
  });

  // ── Empty state (no filters) ──────────────────────────────────────────────

  group('Empty state — no entries', () {
    testWidgets('shows "No audit entries" heading', (tester) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(find.text('No audit entries'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('shows body copy about tutor actions appearing', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(
        find.textContaining('Tutor actions will appear here'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('shows history icon (not filter icon)', (tester) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(find.byIcon(Icons.history_rounded), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── Filter chips present ──────────────────────────────────────────────────

  group('Filter chips', () {
    testWidgets('all action filter chips are rendered', (tester) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      // Check a representative subset of chip labels.
      expect(find.text('Config'), findsOneWidget);
      expect(find.text('Bulk Prior'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Stage'), findsOneWidget);
      expect(find.text('Reward'), findsOneWidget);
      expect(find.text('Study Day'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('"From" and "To" date chips are present', (tester) async {
      await tester.pumpWidget(_buildApp(value: const AsyncData([])));
      await _pump(tester);

      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── Data state — list rendering ───────────────────────────────────────────

  group('Data state — list of entries', () {
    testWidgets('renders a tile for each entry', (tester) async {
      final entries = [
        _entry(
          entryId: 'e1',
          tutorNameSnapshot: 'Rabbi A',
          action: TutorAuditAction.goalChanged,
          target: 'goal/g1.targetDate',
        ),
        _entry(
          entryId: 'e2',
          tutorNameSnapshot: 'Rabbi B',
          action: TutorAuditAction.configChanged,
          target: 'config/points',
        ),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      expect(find.text('Rabbi A'), findsOneWidget);
      expect(find.text('Rabbi B'), findsOneWidget);
      expect(find.text('goal/g1.targetDate'), findsOneWidget);
      expect(find.text('config/points'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('action label badge is shown in each tile', (tester) async {
      final entries = [
        _entry(action: TutorAuditAction.goalChanged, target: 'goal/g1'),
        _entry(
          entryId: 'e2',
          action: TutorAuditAction.completionReset,
          target: 'completion/reset',
        ),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      expect(find.text('Goal changed'), findsOneWidget);
      expect(find.text('Reset'), findsAtLeastNWidgets(1)); // chip + tile badge

      await _teardown(tester);
    });

    testWidgets('no empty-state widget shown when data present', (
      tester,
    ) async {
      final entries = [_entry()];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      expect(find.text('No audit entries'), findsNothing);

      await _teardown(tester);
    });
  });

  // ── Before / after values ─────────────────────────────────────────────────

  group('Before/after values', () {
    testWidgets('renders before and after labels when values present', (
      tester,
    ) async {
      final entry = _entry(beforeValue: '"old_val"', afterValue: '"new_val"');
      await tester.pumpWidget(_buildApp(value: AsyncData([entry])));
      await _pump(tester);

      // The _BeforeAfterRow uses Text.rich with 'before: ' and 'after: ' spans.
      expect(find.textContaining('before: '), findsOneWidget);
      expect(find.textContaining('after: '), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('no before/after section shown when values are null', (
      tester,
    ) async {
      final entry = _entry(); // no beforeValue / afterValue
      await tester.pumpWidget(_buildApp(value: AsyncData([entry])));
      await _pump(tester);

      expect(find.textContaining('before: '), findsNothing);
      expect(find.textContaining('after: '), findsNothing);

      await _teardown(tester);
    });
  });

  // ── Filter chip interaction ───────────────────────────────────────────────

  group('Action filter chip interaction', () {
    testWidgets('selecting a chip hides entries with a different action', (
      tester,
    ) async {
      final entries = [
        _entry(
          entryId: 'e1',
          action: TutorAuditAction.goalChanged,
          target: 'target/goal',
        ),
        _entry(
          entryId: 'e2',
          action: TutorAuditAction.configChanged,
          target: 'target/config',
        ),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      // Tap the 'Goal' filter chip.
      await tester.tap(find.text('Goal'));
      await tester.pump();

      // Only the goalChanged entry should remain visible.
      expect(find.text('target/goal'), findsOneWidget);
      expect(find.text('target/config'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('clear-filters button appears after chip selection', (
      tester,
    ) async {
      final entries = [
        _entry(entryId: 'e1', action: TutorAuditAction.goalChanged),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      // No clear-filters button before selecting a chip.
      expect(find.byIcon(Icons.filter_alt_off_rounded), findsNothing);

      // Select the 'Goal' chip.
      await tester.tap(find.text('Goal'));
      await tester.pump();

      expect(find.byIcon(Icons.filter_alt_off_rounded), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('tapping clear-filters button removes chip selection', (
      tester,
    ) async {
      final entries = [
        _entry(
          entryId: 'e1',
          action: TutorAuditAction.goalChanged,
          target: 'goal-target',
        ),
        _entry(
          entryId: 'e2',
          action: TutorAuditAction.configChanged,
          target: 'config-target',
        ),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      // Select the 'Config' chip → config-target visible, goal-target hidden.
      await tester.tap(find.text('Config'));
      await tester.pump();
      expect(find.text('goal-target'), findsNothing);

      // Tap clear-filters.
      await tester.tap(find.byIcon(Icons.filter_alt_off_rounded));
      await tester.pump();

      // Both entries visible again.
      expect(find.text('goal-target'), findsOneWidget);
      expect(find.text('config-target'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('filtered-empty state shows "No entries match the filters"', (
      tester,
    ) async {
      // One entry with goalChanged; select configChanged chip → zero matches.
      final entries = [
        _entry(entryId: 'e1', action: TutorAuditAction.goalChanged),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      await tester.tap(find.text('Config'));
      await tester.pump();

      expect(find.text('No entries match the filters'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets(
      'filtered-empty state shows "Clear filters to see all entries."',
      (tester) async {
        final entries = [
          _entry(entryId: 'e1', action: TutorAuditAction.goalChanged),
        ];
        await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
        await _pump(tester);

        await tester.tap(find.text('Config'));
        await tester.pump();

        expect(find.text('Clear filters to see all entries.'), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets('deselecting a chip by tapping it again restores full list', (
      tester,
    ) async {
      final entries = [
        _entry(
          entryId: 'e1',
          action: TutorAuditAction.goalChanged,
          target: 'goal-t',
        ),
        _entry(
          entryId: 'e2',
          action: TutorAuditAction.configChanged,
          target: 'config-t',
        ),
      ];
      await tester.pumpWidget(_buildApp(value: AsyncData(entries)));
      await _pump(tester);

      // Select 'Goal' chip.
      await tester.tap(find.text('Goal'));
      await tester.pump();
      expect(find.text('config-t'), findsNothing);

      // Deselect by tapping again.
      await tester.tap(find.text('Goal'));
      await tester.pump();
      expect(find.text('config-t'), findsOneWidget);
      expect(find.text('goal-t'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── Error state ───────────────────────────────────────────────────────────
  //
  // BUG NOTE: Riverpod 2.x FutureProvider transitions to
  // AsyncLoading(hasError: true) rather than AsyncError on first-load failure.
  // The screen's `entriesAsync.when(error: ...)` callback never fires on the
  // initial load because `.when()` routes `AsyncLoading` → `loading:` callback
  // regardless of whether an error is also present.
  // The AppErrorView is referenced in the code but unreachable on first-load failure.

  group('Error state', () {
    // RP3-RETRY (fixed): with Riverpod 3 provider retry disabled app-wide
    // (bootstrap) and in the test ProviderScope below, a first-load error
    // surfaces AsyncError, so entriesAsync.when(error:) renders AppErrorView.
    testWidgets('shows AppErrorView on provider error', (tester) async {
      // AppErrorView maps generic Exception → "Something went wrong" title.
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            tutorAuditLogProvider(_grantId).overrideWith(
              (ref) => Future.error(
                Exception('Firestore unavailable'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TutorAuditLogScreen(
              grantId: _grantId,
              tutorEmail: _tutorEmail,
            ),
          ),
        ),
      );
      await _pump(tester);

      // AppErrorView shows a generic title for non-AppException errors.
      expect(find.text('Something went wrong'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('error state includes a Retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            tutorAuditLogProvider(_grantId).overrideWith(
              (ref) => Future.error(Exception('boom'), StackTrace.empty),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TutorAuditLogScreen(
              grantId: _grantId,
              tutorEmail: _tutorEmail,
            ),
          ),
        ),
      );
      await _pump(tester);

      // AppErrorView shows a retry button for generic errors when onRetry != null.
      expect(find.text('Retry'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── P2: RTL leading filter-chip not clipped ─────────────────────────────────

  group('filter-chip row leading visibility', () {
    Widget buildLocalized({required Locale locale}) {
      return ProviderScope(
        overrides: [
          tutorAuditLogProvider(
            _grantId,
          ).overrideWith((ref) => Future.value(<TutorAuditLogEntry>[_entry()])),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TutorAuditLogScreen(
            grantId: _grantId,
            tutorEmail: _tutorEmail,
          ),
        ),
      );
    }

    testWidgets(
      'leading FilterChip is fully on-screen in RTL (Hebrew) — not clipped at edge',
      (tester) async {
        await tester.pumpWidget(buildLocalized(locale: const Locale('he')));
        await _pump(tester);

        final screenWidth =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        // The leading chip in RTL is the FIRST FilterChip (logical start = right).
        final firstChip = find.byType(FilterChip).first;
        final rect = tester.getRect(firstChip);

        // Must not be clipped past either physical edge.
        expect(
          rect.right,
          lessThanOrEqualTo(screenWidth + 0.5),
          reason:
              'Leading chip must not be clipped past the right (start) edge in RTL',
        );
        expect(
          rect.left,
          greaterThanOrEqualTo(-0.5),
          reason: 'Leading chip must not be clipped past the left edge',
        );

        await _teardown(tester);
      },
    );

    testWidgets('leading FilterChip is fully on-screen in LTR (English)', (
      tester,
    ) async {
      await tester.pumpWidget(buildLocalized(locale: const Locale('en')));
      await _pump(tester);

      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final firstChip = find.byType(FilterChip).first;
      final rect = tester.getRect(firstChip);

      expect(rect.left, greaterThanOrEqualTo(-0.5));
      expect(rect.right, lessThanOrEqualTo(screenWidth + 0.5));

      await _teardown(tester);
    });
  });
}
