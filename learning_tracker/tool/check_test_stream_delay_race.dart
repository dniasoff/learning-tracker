/// TQ-6 Rule-0 checker — fixed-millisecond-delay stream-emission race guard.
///
/// AUD-t-cross-36 found `points_balance_dao_test.dart`'s two `watchBalance`
/// tests collecting stream emissions into a list via `.listen(emissions.add)`
/// and then asserting on `emissions.last` after a fixed
/// `Future<void>.delayed(const Duration(milliseconds: N))` sleep. Under CI
/// contention the reactive query stream may not have emitted the post-write
/// value before the sleep expires, producing an intermittent failure that has
/// nothing to do with a real regression (TQ-6: tests must be hermetic, no
/// wall-clock races). The deterministic alternative already used elsewhere
/// in this codebase (`profile_dao_test.dart`'s `watchProfilesByAccount`
/// test) is `expect(stream, emitsInOrder([...]))` / `expectLater(...)`,
/// which waits for the actual emission instead of racing a clock.
///
/// This implements the finding's own acceptance criterion verbatim: "grep
/// test/**/*_test.dart for `Future<void>.delayed(const Duration(milliseconds`
/// occurring in the same test body as a preceding `.listen(` call". Test
/// bodies are located by balancing parens/braces from each top-level
/// `test(`/`testWidgets(` call opener to its matching close (mirrors the
/// scoped-window convention of `tool/check_db_dao_loop_writes.dart`, but
/// here the "window" is the exact test body rather than a fixed line count,
/// since test bodies vary widely in length).
///
/// A `.listen(` call with no subsequent fixed-millisecond delay is fine (it
/// may be feeding an `emitsInOrder`-style matcher, or a fire-and-forget
/// subscription for teardown). A `Future<void>.delayed(const Duration(
/// milliseconds: ...))` with no preceding `.listen(` in the same body is
/// also fine (e.g. a delay used to yield a microtask before a write, as in
/// `profile_dao_test.dart`'s own `Future<void>.delayed(Duration.zero)` —
/// note that pattern uses `Duration.zero`, not a fixed millisecond value,
/// so it never matches this checker's delay pattern anyway). Only the
/// combination — a `.listen(` followed later, in the same test body, by a
/// fixed-millisecond delay — is the flaky-wait-then-assert shape this
/// checker forbids.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_test_mirroring.dart` (AG-5) and `tool/check_story_dod.dart`
/// (AG-9): AUD-t-cross-36 names only `points_balance_dao_test.dart`'s two
/// `watchBalance` tests (now fixed to use `emitsInOrder`, so they no longer
/// trip this checker). A full-repo scan surfaces the SAME pre-existing
/// fixed-delay-after-listen shape in four other, unrelated test files —
/// out of this finding's scope (fixing them is a drive-by, not this
/// finding's job). Those files are captured in [_baseline] below so the
/// gate fails only on a NEW file introducing this pattern, not on the
/// pre-existing backlog; shrink [_baseline] as each is burned down.
///
/// Usage:
///   dart run tool/check_test_stream_delay_race.dart            # ratchet check
///   dart run tool/check_test_stream_delay_race.dart --report    # print all violations, exit 0
///
/// Exit codes (ratchet mode):
///   0 — no NEW (non-baselined) test file has a `.listen(` call followed,
///       in the same test body, by a fixed-millisecond
///       `Future<void>.delayed(...)`
///   1 — one or more such violations found in a file outside [_baseline]
///       (prints file:line)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates — discovered by this
/// checker's own first run (AUD-t-cross-36), out of that finding's named
/// scope (which is `points_balance_dao_test.dart` only). Shrink this set as
/// each file is burned down to `emitsInOrder`/`expectLater`; never add to it
/// to paper over a NEW violation.
const _baseline = <String>{
  'test/core/analytics/streak_milestone_analytics_observer_test.dart',
  'test/core/streak/streak_state_service_test.dart',
  'test/features/dashboard/presentation/providers/dashboard_providers_test.dart',
  'test/story_acceptance/epic_15_multi_profile_test.dart',
};

final _testBodyOpener = RegExp(r'^\s*test(?:Widgets)?\(');
final _listenCall = RegExp(r'\.listen\(');
final _fixedMillisecondDelay = RegExp(
  r'Future<void>\.delayed\(\s*const Duration\(milliseconds',
);

void main(List<String> args) {
  final report = args.contains('--report');

  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    stderr.writeln('ERROR: test/ not found — run from learning_tracker/.');
    exit(1);
  }

  final files =
      testDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // path -> [ "path:line: message", ... ]
  final violationsByFile = <String, List<String>>{};
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final found = _checkFile(path, file.readAsLinesSync());
    if (found.isNotEmpty) {
      violationsByFile[path] = found;
    }
  }

  if (report) {
    for (final entry in violationsByFile.entries) {
      for (final v in entry.value) {
        stdout.writeln(v);
      }
    }
    stdout.writeln(
      '--- ${violationsByFile.length} file(s), '
      '${violationsByFile.values.fold<int>(0, (n, l) => n + l.length)} '
      'violation(s) total',
    );
    return;
  }

  final newViolationFiles =
      violationsByFile.keys.where((p) => !_baseline.contains(p)).toList()
        ..sort();

  if (newViolationFiles.isNotEmpty) {
    stderr.writeln(
      'Stream-emission fixed-delay race check FAILED (TQ-6, AUD-t-cross-36) '
      '— a test body collects stream emissions via .listen( and then races '
      'a fixed-millisecond Future<void>.delayed(...) sleep instead of '
      'awaiting the emission deterministically. Under CI contention the '
      'sleep can expire before the stream emits, producing an intermittent '
      'failure unrelated to a real regression. Use '
      '`expect(stream, emitsInOrder([...]))` / `expectLater(...)` instead '
      '(see test/core/database/daos/profile_dao_test.dart\'s '
      'watchProfilesByAccount test for the pattern):',
    );
    for (final path in newViolationFiles) {
      for (final v in violationsByFile[path]!) {
        stderr.writeln('  $v');
      }
    }
    exit(1);
  }

  stdout.writeln(
    'Stream-emission fixed-delay race check passed — no NEW test file pairs '
    'a .listen( call with a fixed-millisecond Future<void>.delayed(...) '
    'wait (${_baseline.length} pre-existing baselined file(s) tolerated).',
  );
}

/// Scans one file's lines for the `.listen(` -> fixed-millisecond-delay
/// pattern within the same test body, and returns violation strings.
List<String> _checkFile(String path, List<String> lines) {
  final violations = <String>[];

  var i = 0;
  while (i < lines.length) {
    if (!_testBodyOpener.hasMatch(lines[i])) {
      i++;
      continue;
    }

    // Balance parens/braces from the `test(`/`testWidgets(` opener to find
    // the matching close of this test body.
    final bodyStart = i;
    var depth = 0;
    var j = i;
    var sawListenAt = -1;
    var reported = false;
    for (; j < lines.length; j++) {
      final line = lines[j];
      for (final ch in line.split('')) {
        if (ch == '(' || ch == '{') depth++;
        if (ch == ')' || ch == '}') depth--;
      }

      if (sawListenAt == -1 && _listenCall.hasMatch(line)) {
        sawListenAt = j;
      } else if (sawListenAt != -1 &&
          !reported &&
          _fixedMillisecondDelay.hasMatch(line)) {
        violations.add(
          '$path:${j + 1}: fixed-millisecond Future<void>.delayed(...) '
          'follows a .listen( call at line ${sawListenAt + 1} in the same '
          'test body (opened at line ${bodyStart + 1}) — use '
          'emitsInOrder/expectLater instead of racing a clock',
        );
        reported = true;
      }

      if (j > bodyStart && depth <= 0) break;
    }

    // Resume scanning after this test body.
    i = j + 1;
  }

  return violations;
}
