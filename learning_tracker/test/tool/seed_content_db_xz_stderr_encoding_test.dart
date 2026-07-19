// Regression test for AUD-guardrails-20: `tool/seed_content_db.dart`'s xz
// `Process.runSync` call must decode `stderr` to a human-readable String
// before it is interpolated into the thrown `StateError` — not leave it as
// raw bytes (`stderrEncoding: null`), which String-interpolates via
// `List.toString()` as e.g. `"[120, 122, 58, ...]"` instead of xz's actual
// message.
//
// This does not run the full seed pipeline — Phase 6 (the xz compression
// step) is only reached after Phases 1-5 complete, which need the real
// seed data assets (book_text_cache.json, curriculum hierarchy JSON, etc.)
// that a fresh worktree/CI checkout may not have. Instead this test:
//
//   1. (AC2) Statically locates the actual `Process.runSync('xz', ...)`
//      call in the source and asserts it sets a real `stderrEncoding`
//      (not `null`) — the concrete code-shape AC.
//   2. (AC1) Extracts the *actual* `stderrEncoding` value the source uses
//      and drives a REAL `xz` process with the identical flags against a
//      guaranteed-to-fail (nonexistent) input path, asserting the
//      resulting failure message (built exactly as
//      `seed_content_db.dart` builds it: `'xz failed: ${result.stderr}'`)
//      is human-readable, not a numeric byte list.
//
// Because step 2 reads the encoding out of the real source rather than
// hardcoding it, a regression back to `stderrEncoding: null` turns this
// test red without needing to edit the test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches the `Process.runSync('xz', ...)` call (non-greedy, across
/// lines) in `seed_content_db.dart`'s source.
final _xzCallPattern = RegExp(
  r"Process\.runSync\(\s*'xz',.*?\);",
  dotAll: true,
);

void main() {
  // `flutter test` runs with cwd == the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptFile = File('$packageDir/tool/seed_content_db.dart');

  group('tool/seed_content_db.dart xz stderr encoding (AUD-guardrails-20)', () {
    test('the xz Process.runSync call sets a real stderrEncoding, not null '
        '(AC2)', () {
      final source = scriptFile.readAsStringSync();
      final callMatch = _xzCallPattern.firstMatch(source);
      expect(
        callMatch,
        isNotNull,
        reason:
            'could not locate the xz Process.runSync call in '
            'seed_content_db.dart — has it moved or been renamed? '
            'Update this test.',
      );
      final callText = callMatch!.group(0)!;

      expect(
        callText,
        contains('stderrEncoding:'),
        reason:
            'the xz Process.runSync call must set stderrEncoding '
            'explicitly (AUD-guardrails-20).',
      );
      expect(
        callText,
        isNot(contains('stderrEncoding: null')),
        reason:
            'stderrEncoding: null leaves ProcessResult.stderr as raw '
            'bytes (a Uint8List); String-interpolating it '
            r"(`'xz failed: ${xzResult.stderr}'`) prints something like "
            '"[120, 122, 58, ...]" instead of xz\'s actual, '
            'human-readable stderr text (AUD-guardrails-20).',
      );
    });

    test('a real xz failure, decoded exactly as seed_content_db.dart '
        'configures it, produces a human-readable failure message — not a '
        'numeric byte list (AC1)', () {
      final source = scriptFile.readAsStringSync();
      final callMatch = _xzCallPattern.firstMatch(source);
      expect(callMatch, isNotNull);
      final callText = callMatch!.group(0)!;

      final encodingMatch = RegExp(
        r'stderrEncoding:\s*([A-Za-z0-9_]+)',
      ).firstMatch(callText);
      expect(
        encodingMatch,
        isNotNull,
        reason:
            'the xz Process.runSync call must set stderrEncoding '
            'explicitly.',
      );
      final encodingName = encodingMatch!.group(1);
      final stderrEncoding = switch (encodingName) {
        'systemEncoding' => systemEncoding,
        'utf8' => utf8,
        'latin1' => latin1,
        'ascii' => ascii,
        _ => null, // covers 'null' and any other non-Encoding token
      };

      // A guaranteed-to-fail xz invocation using the exact flags
      // seed_content_db.dart uses (-9 --extreme -k -f <path>), against a
      // path that cannot exist: a file inside a freshly created, still-empty
      // temp directory (TQ-6: no wall-clock read — a createTempSync()
      // directory guarantees uniqueness/absence without touching the
      // system clock).
      final tmpDir = Directory.systemTemp.createTempSync('aud_guardrails_20_');
      addTearDown(() {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      });
      final missingPath = '${tmpDir.path}/does_not_exist.db';
      expect(
        File(missingPath).existsSync(),
        isFalse,
        reason: 'sanity: the synthetic missing-file path must not exist',
      );

      final result = Process.runSync(
        'xz',
        ['-9', '--extreme', '-k', '-f', missingPath],
        stdoutEncoding: null,
        stderrEncoding: stderrEncoding,
      );

      expect(
        result.exitCode,
        isNot(0),
        reason: 'xz against a nonexistent input file must fail',
      );

      // Exactly how seed_content_db.dart builds the thrown message.
      final message = 'xz failed: ${result.stderr}';

      final looksLikeByteList = RegExp(
        r'^xz failed: \[\d+(,\s*\d+)*\]$',
      ).hasMatch(message);
      expect(
        looksLikeByteList,
        isFalse,
        reason:
            'the failure message must be xz\'s human-readable stderr '
            'text, not a raw byte list — got: $message',
      );
      expect(
        message,
        contains(missingPath),
        reason:
            'a human-readable xz error names the offending path; got: '
            '$message',
      );
    });
  });
}
