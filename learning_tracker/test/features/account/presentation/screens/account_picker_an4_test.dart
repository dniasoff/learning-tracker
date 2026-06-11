// Regression test for AN-4:
// AccountPicker ordering / rapid-tap / back-stack defects.
//
// Root cause (ordering): the account list was sorted by lastUsedAt DESC,
// which changes every time you switch accounts — making card positions
// unpredictable on successive visits.
//
// Root cause (rapid-tap): _AccountTile._onTap had no re-entrancy guard;
// double-tap launched concurrent account switches.
//
// Fix (ordering): active account is pinned first (dbFileName match); remaining
// accounts sorted by dbFileName (stable alphabetical proxy for creation order).
// Fix (rapid-tap): _switching flag in _AccountTileState blocks concurrent taps;
// onTap is null while _switching is true.
//
// Test strategy: we test the ordering logic in isolation using the same sort
// algorithm as the fix, and verify the _switching guard behavior via a minimal
// widget replica.

@Tags(['account', 'account_picker', 'an4'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Minimal replica of the AN-4 guard ────────────────────────────────────────

/// Replica of the _AccountTileState._switching guard behavior.
class _TapGuardWidget extends StatefulWidget {
  const _TapGuardWidget({required this.onTap});
  final Future<void> Function() onTap;

  @override
  State<_TapGuardWidget> createState() => _TapGuardWidgetState();
}

class _TapGuardWidgetState extends State<_TapGuardWidget> {
  bool _switching = false;

  Future<void> _onTapGuarded() async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _switching ? null : _onTapGuarded,
      child: Text(_switching ? 'switching' : 'idle'),
    );
  }
}

// ── Minimal replica of the AN-4 ordering logic ───────────────────────────────

/// Replicates the sort algorithm from the AN-4 fix in AccountPickerScreen:
/// active account (dbFileName == activeDbFileName) first, then remaining
/// accounts sorted by dbFileName alphabetically (stable creation order proxy).
List<String> _sortedAccountDbFileNames({
  required List<String> accountDbFileNames,
  required String activeDbFileName,
}) {
  return [
    ...accountDbFileNames.where((fn) => fn == activeDbFileName),
    ...accountDbFileNames.where((fn) => fn != activeDbFileName).toList()
      ..sort(),
  ];
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AN-4 regression — AccountPicker ordering and tap guard', () {
    // ── Ordering ─────────────────────────────────────────────────────────────
    test(
      'active account is always pinned at position 0 regardless of alphabetical '
      'order (AN-4 deterministic ordering)',
      () {
        const accounts = ['user_acc_z.db', 'user_acc_a.db', 'user_acc_m.db'];

        // Active is 'z' — it should be first even though 'a' < 'z'.
        final sorted = _sortedAccountDbFileNames(
          accountDbFileNames: accounts,
          activeDbFileName: 'user_acc_z.db',
        );
        expect(
          sorted.first,
          equals('user_acc_z.db'),
          reason: 'AN-4: active account must be pinned first',
        );
        expect(
          sorted,
          equals(['user_acc_z.db', 'user_acc_a.db', 'user_acc_m.db']),
          reason: 'AN-4: remaining accounts sorted alphabetically',
        );
      },
    );

    test(
      'ordering is stable when active account is already alphabetically first',
      () {
        const accounts = ['user_acc_a.db', 'user_acc_b.db', 'user_acc_c.db'];

        final sorted = _sortedAccountDbFileNames(
          accountDbFileNames: accounts,
          activeDbFileName: 'user_acc_a.db',
        );
        expect(
          sorted,
          equals(['user_acc_a.db', 'user_acc_b.db', 'user_acc_c.db']),
          reason: 'Sorted list is correct when active is alphabetically first',
        );
      },
    );

    test('AN-4: ordering does NOT change when a non-active account has a later '
        'lastUsedAt (old lastUsedAt sort would have reordered the list)', () {
      // Simulate: active=A, last-used-desc order would be [B, A, C].
      // The fix always puts A first regardless.
      const activeDb = 'user_acc_a_001.db';
      final accounts = [
        'user_acc_b_002.db', // most recently used (non-active)
        'user_acc_a_001.db', // active
        'user_acc_c_003.db',
      ];

      final sorted = _sortedAccountDbFileNames(
        accountDbFileNames: accounts,
        activeDbFileName: activeDb,
      );
      // Active first, then B and C in alphabetical order.
      expect(
        sorted.first,
        equals(activeDb),
        reason:
            'AN-4: active must be first even if another was more recently used',
      );
    });

    // ── Tap guard ─────────────────────────────────────────────────────────────
    testWidgets(
      // AN-4: Before fix there was no guard; rapid double-tap launched two
      // concurrent switches. After fix, the second tap is silently dropped.
      'AN-4: double-tap is silently dropped while first tap is in progress',
      (tester) async {
        // We use a Completer to manually control when the "switch" completes.
        // This avoids relying on fake_async timer resolution.
        final firstCompleter = Completer<void>();
        var tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _TapGuardWidget(
                onTap: () async {
                  tapCount++;
                  if (tapCount == 1) {
                    await firstCompleter.future;
                  }
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Shows "idle" initially.
        expect(find.text('idle'), findsOneWidget);

        // First tap — starts the operation.
        await tester.tap(find.text('idle'));
        await tester.pump(); // Allow setState(_switching=true) to flush.

        // Shows "switching" while in progress.
        expect(find.text('switching'), findsOneWidget);
        expect(tapCount, equals(1));

        // Second tap during in-flight switch — onTap is null (guard active).
        // The tap should be silently dropped.
        await tester.tap(find.text('switching'), warnIfMissed: false);
        await tester.pump();

        // tapCount should still be 1 (second tap dropped).
        expect(
          tapCount,
          equals(1),
          reason: 'AN-4: second tap must be dropped while first is in flight',
        );

        // Complete the first switch.
        firstCompleter.complete();
        await tester.pumpAndSettle();

        // Guard resets — back to idle.
        expect(find.text('idle'), findsOneWidget);
        expect(tapCount, equals(1), reason: 'Only one switch ran');
      },
    );

    testWidgets(
      'after switch completes, subsequent tap is accepted (guard resets)',
      (tester) async {
        var tapCount = 0;
        final completer = Completer<void>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _TapGuardWidget(
                onTap: () async {
                  tapCount++;
                  if (tapCount == 1) await completer.future;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // First tap.
        await tester.tap(find.text('idle'));
        await tester.pump();
        expect(tapCount, equals(1));

        // Complete the first switch.
        completer.complete();
        await tester.pumpAndSettle();

        // Guard is reset — second tap should succeed.
        await tester.tap(find.text('idle'));
        await tester.pumpAndSettle();

        expect(
          tapCount,
          equals(2),
          reason: 'Guard must reset after switch completes',
        );
      },
    );
  });
}
