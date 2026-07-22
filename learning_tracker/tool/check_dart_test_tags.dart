/// `dart_test.yaml` tag-registry + global-timeout checker/generator —
/// AUD-guardrails-34 (tags) and R6 (`docs/test-artifacts/reassurance-plan.md`
/// Surface 6 — flake & CI-trust gate) for the file's `timeout:` default.
///
/// `dart_test.yaml`'s `tags:` block exists to suppress `package:test`'s
/// "unknown tag" warning when running `flutter test --tags <tag>` (see the
/// file's own header comment). AUD-guardrails-34 found the hand-maintained
/// registry had drifted so far from actual usage that most tags used via
/// `@Tags([...])`/`tags: [...]` across `test/` were undeclared — including
/// entire epics with their own Makefile targets (epic_18, epic_20, epic_24,
/// epic_28) — defeating the file's one stated job and adding warning noise
/// that makes genuine problems easy to miss in CI logs.
///
/// This script scans every `test/**/*.dart` file for tag string literals
/// passed to `@Tags([...])` or a `tags: [...]` group()/test() parameter, and
/// treats that as the source of truth — `dart_test.yaml`'s declared set must
/// be a superset (in practice, exactly equal after `--write`).
///
/// R6 ADDITION: this same generated file also owns dart_test.yaml's
/// top-level `timeout:` default (see [_globalTimeout]) and a reserved,
/// always-declared tag set (see [_reservedTags]). Both would otherwise be
/// silently wiped the next time a maintainer runs `--write` — before this
/// addition, `buildDartTestYaml` was a pure function of "tags used under
/// test/" and nothing else, so a hand-added `timeout:` line or an
/// as-yet-unused `quarantine:` tag would vanish on the very next
/// regeneration. They're now first-class generator inputs instead.
///
/// Usage (from `learning_tracker/`):
///   dart run tool/check_dart_test_tags.dart              # print the regenerated file
///   dart run tool/check_dart_test_tags.dart --check       # exit 1 if any tag used under
///                                                          # test/ is undeclared in
///                                                          # dart_test.yaml (the `comm -23`
///                                                          # check from AUD-guardrails-34's
///                                                          # acceptance criterion), OR if
///                                                          # the R6 global `timeout:` default
///                                                          # is missing/altered
///   dart run tool/check_dart_test_tags.dart --write       # regenerate dart_test.yaml in
///                                                          # place from the scan
///
/// Exit codes (`--check` mode):
///   0 — every tag used under test/ is declared in dart_test.yaml, and the
///       R6 global timeout default is present and unchanged
///   1 — one or more used tags are undeclared (prints the missing set), or
///       the timeout default is missing/altered (prints the mismatch)
library;

import 'dart:io';

/// R6 (flake & CI-trust gate): the file-level default test timeout. Applies
/// only to test()/group() calls that don't carry their own `timeout:`
/// parameter — every currently-longer-running test in this repo (the
/// `make audit`-shelling cases in test/tool/audit_and_arb_parity_test.dart,
/// 10-60 minutes each) already sets an explicit inline `Timeout(...)` that
/// takes precedence over this default, so raising it from package:test's
/// own hardcoded implicit fallback (`Invoker`'s 30s, see
/// package:test_api/src/backend/invoker.dart) to an EXPLICIT 2 minutes does
/// not touch them. The raise (not a straight `30s` restatement) exists
/// because CI runners are measurably slower than a local dev box (see
/// .github/workflows/ci.yml's `test` job comment) — a bare 30s default risks
/// false-positive timeouts there on ordinary (not hung) slow widget/golden
/// tests. 2 minutes is still short enough that a genuine hang fails in
/// bounded time instead of riding out the `test` job's 45-minute budget (or
/// `test-serial-tools`'s 90-minute one) uncontested — the exact failure this
/// surface exists to catch. Change this constant (then re-run `--write`) if
/// the tradeoff ever needs revisiting; do not hand-edit the generated line.
const _globalTimeout = '2m';

/// Tags that must always stay declared in dart_test.yaml even when nothing
/// under test/ currently uses them — infrastructure contracts, not scan
/// output. `quarantine` (R6): the flake-isolation lane a known-flaky test is
/// tagged with to be excluded from the main `make test` lane (see the
/// Makefile's `test:` target) without silently deleting/skipping it. Declared
/// unconditionally so the tag is always valid to reach for the moment a
/// flaky test is found, rather than reappearing only after some test happens
/// to use it.
const _reservedTags = {'quarantine'};

/// Matches an `@Tags([...])` annotation, capturing the bracket body. Uses a
/// negated character class (not `.`) so it spans multi-line tag lists too —
/// e.g. `@Tags([\n  'tracks',\n  'edit_track',\n])`.
final _atTagsPattern = RegExp(r'@Tags\(\[([^\]]*)\]\)');

/// Matches a `tags: [...]` group()/test() parameter, same multi-line
/// handling as [_atTagsPattern].
final _tagsKeywordPattern = RegExp(r'tags:\s*\[([^\]]*)\]');

/// A single quoted string literal inside a tag-list bracket body.
final _stringLiteralPattern = RegExp('''['"]([^'"]+)['"]''');

/// A bare `  <tag>:` entry under dart_test.yaml's top-level `tags:` map —
/// this repo's registry never assigns a value (no `skip:`/`timeout:` per
/// tag), so every declared tag is a colon-terminated key on its own line.
final _declaredTagPattern = RegExp(
  r'^  ([a-zA-Z0-9_-]+):\s*$',
  multiLine: true,
);

/// The file-level `timeout:` key, e.g. `timeout: 2m`.
final _declaredTimeoutPattern = RegExp(
  r'^timeout:\s*(\S+)\s*$',
  multiLine: true,
);

/// Scans [testDir] recursively for every tag literal used via `@Tags([...])`
/// or `tags: [...]`.
Set<String> scanUsedTags(Directory testDir) {
  final used = <String>{};
  for (final entity in testDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    for (final pattern in [_atTagsPattern, _tagsKeywordPattern]) {
      for (final match in pattern.allMatches(content)) {
        final body = match.group(1)!;
        for (final lit in _stringLiteralPattern.allMatches(body)) {
          used.add(lit.group(1)!);
        }
      }
    }
  }
  return used;
}

/// Parses the tag keys currently declared in dart_test.yaml's `tags:` block.
Set<String> declaredTags(String yamlContent) {
  return _declaredTagPattern
      .allMatches(yamlContent)
      .map((m) => m.group(1)!)
      .toSet();
}

/// Parses the file-level `timeout:` value currently declared in
/// dart_test.yaml, or null if absent.
String? declaredTimeout(String yamlContent) {
  return _declaredTimeoutPattern.firstMatch(yamlContent)?.group(1);
}

/// Builds the full replacement contents of dart_test.yaml from a scanned tag
/// set — a flat, alphabetically-sorted registry (the previous hand-grouped
/// per-epic comments could not be kept accurate across waves; the checker
/// itself is now the source of truth — see the `--write` usage note below) —
/// plus the R6 global `timeout:` default and reserved tag set.
String buildDartTestYaml(Set<String> tags) {
  final sorted = tags.union(_reservedTags).toList()..sort();
  final buffer = StringBuffer()
    ..writeln('# Tag registration for story acceptance tests.')
    ..writeln(
      '# Prevents "unknown tag" warnings when running flutter test --tags.',
    )
    ..writeln('#')
    ..writeln(
      '# GENERATED by tool/check_dart_test_tags.dart --write (AUD-guardrails-34).',
    )
    ..writeln(
      '# Do not hand-edit: run `dart run tool/check_dart_test_tags.dart --write`',
    )
    ..writeln(
      '# after adding/removing an @Tags([...])/tags: [...] literal under test/, and',
    )
    ..writeln(
      '# commit the result. `dart run tool/check_dart_test_tags.dart --check` (part',
    )
    ..writeln(
      '# of `make audit`) fails if this file drifts from actual usage again.',
    )
    ..writeln('#')
    ..writeln(
      '# R6 (flake & CI-trust gate, docs/test-artifacts/reassurance-plan.md):',
    )
    ..writeln('# `timeout:` below is the file-level default test timeout — see')
    ..writeln(
      '# tool/check_dart_test_tags.dart\'s `_globalTimeout` doc comment for the',
    )
    ..writeln('# 2-minute rationale. `quarantine:` is a reserved tag (see')
    ..writeln(
      '# `_reservedTags`) for isolating a known-flaky test out of the main',
    )
    ..writeln(
      '# `make test` lane (Makefile `test:` target) without disabling it.',
    )
    ..writeln()
    ..writeln('timeout: $_globalTimeout')
    ..writeln()
    ..writeln('tags:');
  for (final tag in sorted) {
    buffer.writeln('  $tag:');
  }
  return buffer.toString();
}

void main(List<String> args) {
  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    stderr.writeln('ERROR: test/ not found — run from learning_tracker/');
    exit(2);
  }
  final yamlFile = File('dart_test.yaml');
  if (!yamlFile.existsSync()) {
    stderr.writeln(
      'ERROR: dart_test.yaml not found — run from learning_tracker/',
    );
    exit(2);
  }

  final used = scanUsedTags(testDir);
  final check = args.contains('--check');
  final write = args.contains('--write');

  if (check) {
    final yamlContent = yamlFile.readAsStringSync();
    var failed = false;

    final declared = declaredTags(yamlContent);
    final missing = used.difference(declared).toList()..sort();
    if (missing.isNotEmpty) {
      failed = true;
      stderr.writeln(
        'AUD-guardrails-34 dart_test.yaml tag check FAILED: ${missing.length} '
        'tag(s) used under test/ via @Tags([...])/tags: [...] are not '
        "declared in dart_test.yaml's tags: block:",
      );
      for (final tag in missing) {
        stderr.writeln('  $tag');
      }
    }

    final timeout = declaredTimeout(yamlContent);
    if (timeout != _globalTimeout) {
      failed = true;
      stderr.writeln(
        'R6 dart_test.yaml global timeout check FAILED: expected a '
        'top-level `timeout: $_globalTimeout` line, found '
        '${timeout == null ? 'none' : '`timeout: $timeout`'}. A hung test '
        'with no per-test override must fail in bounded time instead of '
        "riding out the whole CI job's budget — see "
        "tool/check_dart_test_tags.dart's `_globalTimeout` doc comment.",
      );
    }

    if (failed) {
      stderr.writeln(
        '\nRun `dart run tool/check_dart_test_tags.dart --write` to '
        'regenerate dart_test.yaml, then commit the result.',
      );
      exit(1);
    }

    stdout.writeln(
      'dart_test.yaml check OK: all ${used.length} tag(s) used under test/ '
      'are declared, and the R6 global timeout ($_globalTimeout) is intact.',
    );
    return;
  }

  final regenerated = buildDartTestYaml(used);
  if (write) {
    yamlFile.writeAsStringSync(regenerated);
    stdout.writeln(
      'dart_test.yaml regenerated with ${used.union(_reservedTags).length} '
      'declared tag(s) and timeout: $_globalTimeout.',
    );
    return;
  }

  stdout.write(regenerated);
}
