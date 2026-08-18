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

import '../../helpers/dart_method_body.dart';

void main() {
  group('WS3.3e — Dual-role fix: _isTutorSession keyed to active selection (DEC-21)', () {
    late String textDisplaySrc;

    setUpAll(() {
      textDisplaySrc = File(
        'lib/features/content_browsing/presentation/screens/text_display_screen.dart',
      ).readAsStringSync();
    });

    // ── AC1: incomingTutorGrantsProvider no longer used for session check ──────

    test('AC1: _isTutorSession does NOT read incomingTutorGrantsProvider '
        '(dual-role bug removed)', () {
      // The bug: checking incomingTutorGrantsProvider returned true whenever
      // ANY grant existed, breaking a tutor's own-profile live-mark.
      // The fix must not reference incomingTutorGrantsProvider in _isTutorSession.
      //
      // We verify this by checking that the method body uses
      // activeTutoredProfileSelectionProvider instead. Since the file may
      // still import or mention incomingTutorGrantsProvider in comments for
      // history, we check the actual _isTutorSession implementation.
      expect(
        textDisplaySrc.contains('bool _isTutorSession('),
        isTrue,
        reason: '_isTutorSession method must exist',
      );

      // Grab the method body via brace-depth-matched extraction (not a
      // naive "next `}`" search — see AUD-t-tutoring-11 and
      // test/helpers/dart_method_body.dart's doc comment).
      final methodBody = extractMethodBody(
        textDisplaySrc,
        'bool _isTutorSession(',
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

    test('AC2: _isTutorSession reads activeTutoredProfileSelectionProvider '
        '(correct scope gate)', () {
      final methodBody = extractMethodBody(
        textDisplaySrc,
        'bool _isTutorSession(',
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
      'AC2: text_display_screen imports active_tutored_profile_provider',
      () {
        expect(
          textDisplaySrc,
          contains('active_tutored_profile_provider.dart'),
          reason:
              'text_display_screen.dart must import '
              'active_tutored_profile_provider.dart to access '
              'activeTutoredProfileSelectionProvider',
        );
      },
    );

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

    // ── Regression: extraction must not truncate on a naive brace search ──────
    // AUD-t-tutoring-11: AC1/AC2 above used to grab the method body via
    // `textDisplaySrc.indexOf('\n  }', methodStart) + 4` — a naive search
    // for the *first* two-space-indented `}` after the method start,
    // rather than counting brace depth. That heuristic only worked because
    // `_isTutorSession` happens to be a one-line method today. This test
    // proves `extractMethodBody` (test/helpers/dart_method_body.dart),
    // which AC1/AC2 now use, does NOT get fooled the way the old naive
    // search would: a nested block whose closing brace lands at the same
    // indent as the method's own closing brace must not truncate the
    // extracted body early. (Ran red against the old inline naive search
    // before this file was fixed — see the AUD-t-tutoring-11 commit.)
    test('REGRESSION: method-body extraction survives a nested block whose '
        r"closing brace sits at the method's own indent (naive '\n  }' "
        'search would truncate here and miss the rest of the body)', () {
      const fixture = '''
class _Fixture {
  bool _isTutorSession(BuildContext context) {
    if (checkSomething()) {
  }
    return ref.watch(incomingTutorGrantsProvider) != null;
  }
}
''';

      final body = extractMethodBody(fixture, 'bool _isTutorSession(');

      // A naive `indexOf('\n  }', methodStart) + 4` search would stop
      // at the nested `if` block's closing brace above (also 2-space
      // indented) and never reach this marker — silently truncating
      // the body and letting an `isNot(contains(...))` assertion pass
      // regardless of what the unseen remainder actually does.
      expect(
        body,
        contains('incomingTutorGrantsProvider'),
        reason:
            'depth-matched extraction must return the full method body '
            "even when a nested block's closing brace lands at the "
            "same indent as the method's own closing brace",
      );
    });
  });
}
