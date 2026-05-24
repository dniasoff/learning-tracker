// WS3.3e — Dual-role fix (DEC-21)
//
// Verifies that:
//   AC1 — text_display_screen.dart no longer reads incomingTutorGrantsProvider
//          to determine isTutorSession (that was the dual-role bug).
//   AC2 — text_display_screen.dart now reads activeTutoredProfileSelectionProvider
//          to determine isTutorSession (correct: non-null only when inside a
//          specific talmid's context, not just because a grant exists).
//   AC3 — The comment in text_display_screen.dart references DEC-21 and
//          describes the fix so future readers understand the intent.

@Tags(['ws3', 'ws3_3e', 'tutor_mode'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('WS3.3e — Dual-role fix: _isTutorSession keyed to active selection (DEC-21)',
      () {
    late String textDisplaySrc;

    setUpAll(() {
      textDisplaySrc = File(
        'lib/features/content_browsing/presentation/screens/text_display_screen.dart',
      ).readAsStringSync();
    });

    // ── AC1: incomingTutorGrantsProvider no longer used for session check ──────

    test(
        'AC1: _isTutorSession does NOT read incomingTutorGrantsProvider '
        '(dual-role bug removed)', () {
      // The bug: checking incomingTutorGrantsProvider returned true whenever
      // ANY grant existed, breaking a tutor's own-profile live-mark.
      // The fix must not reference incomingTutorGrantsProvider in _isTutorSession.
      //
      // We verify this by checking that the method body uses
      // activeTutoredProfileSelectionProvider instead. Since the file may
      // still import or mention incomingTutorGrantsProvider in comments for
      // history, we check the actual _isTutorSession implementation.
      final methodStart = textDisplaySrc.indexOf('bool _isTutorSession(');
      expect(methodStart, isNot(-1), reason: '_isTutorSession method must exist');

      // Grab the method body (up to closing brace — heuristic: next `}`).
      final methodBody = textDisplaySrc.substring(
        methodStart,
        textDisplaySrc.indexOf('\n  }', methodStart) + 4,
      );

      // The method body must NOT call incomingTutorGrantsProvider.
      expect(
        methodBody,
        isNot(contains('incomingTutorGrantsProvider')),
        reason:
            '_isTutorSession must not use incomingTutorGrantsProvider — that '
            'caused the DEC-21 dual-role bug where a tutor viewing their own '
            'profile had live-mark wrongly disabled',
      );
    });

    // ── AC2: activeTutoredProfileSelectionProvider is the new gate ────────────

    test(
        'AC2: _isTutorSession reads activeTutoredProfileSelectionProvider '
        '(correct scope gate)', () {
      final methodStart = textDisplaySrc.indexOf('bool _isTutorSession(');
      final methodBody = textDisplaySrc.substring(
        methodStart,
        textDisplaySrc.indexOf('\n  }', methodStart) + 4,
      );

      expect(
        methodBody,
        contains('activeTutoredProfileSelectionProvider'),
        reason:
            '_isTutorSession must gate on activeTutoredProfileSelectionProvider, '
            'which is non-null only when the tutor has PINned into a specific '
            "talmid's context (WS3.3e DEC-21 fix)",
      );
    });

    test(
        'AC2: text_display_screen imports active_tutored_profile_provider', () {
      expect(
        textDisplaySrc,
        contains('active_tutored_profile_provider.dart'),
        reason:
            'text_display_screen.dart must import '
            'active_tutored_profile_provider.dart to access '
            'activeTutoredProfileSelectionProvider',
      );
    });

    // ── AC3: Comment explains the fix ─────────────────────────────────────────

    test('AC3: file comment references DEC-21 dual-role fix', () {
      expect(
        textDisplaySrc,
        contains('DEC-21'),
        reason:
            'text_display_screen.dart must have a comment explaining the '
            'DEC-21 dual-role fix so future readers understand why '
            'activeTutoredProfileSelectionProvider is used instead of '
            'incomingTutorGrantsProvider',
      );
    });
  });
}
