/// Rule-0 checker — no config drift in
/// `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` across the
/// iOS `XCBuildConfiguration` blocks in `project.pbxproj` (AUD-platform-04).
///
/// AUD-platform-04 found that
/// `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` — a
/// Boolean Xcode build setting — was set to `YES` in the Runner target's
/// Profile configuration but to the invalid value `AppIcon` in its Debug and
/// Release configurations (a copy-paste bleed from the neighboring
/// `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` setting a few lines away).
/// Debug and Release are the two configurations used for every local dev
/// run and every shipped build, so the drift/invalid-value pair is live risk:
/// it produces an Xcode build warning today and will silently break the
/// moment Swift code starts referencing a generated asset symbol (compiles
/// only in the one configuration that happens to hold the valid value).
///
/// This checker fails if any of the following regress:
///   1. Any `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
///      occurrence in the project has a value other than the valid Xcode
///      boolean literals `YES` / `NO`.
///   2. The occurrences that do carry a valid value are not all the same
///      value (Debug/Release/Profile diverging from each other).
///
/// Usage:
///   dart run tool/check_ios_asset_symbol_extensions.dart
///   dart run tool/check_ios_asset_symbol_extensions.dart --pbxproj <path>
///     # test-only override so the regression test
///     # (test/tool/check_ios_asset_symbol_extensions_test.dart) can exercise
///     # deliberately-broken fixtures without touching this repo's real
///     # ios/Runner.xcodeproj/project.pbxproj.
///
/// Exit codes:
///   0 — every occurrence is a valid, matching YES/NO value (or the key is
///       absent entirely)
///   1 — one or more of the above regressed (prints file:line and why)
///   2 — the input file is missing/unreadable
library;

import 'dart:io';

const _key = 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';
const _validValues = {'YES', 'NO'};

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

class _Occurrence {
  _Occurrence(this.line, this.value);
  final int line;
  final String value;
}

void main(List<String> args) {
  final pbxprojPath =
      _argValue(args, '--pbxproj') ?? 'ios/Runner.xcodeproj/project.pbxproj';

  final file = File(pbxprojPath);
  if (!file.existsSync()) {
    stderr.writeln('ERROR: $pbxprojPath not found.');
    exit(2);
  }

  final lines = file.readAsLinesSync();
  final keyPattern = RegExp(
    r'^\s*' + RegExp.escape(_key) + r'\s*=\s*([^;]+);\s*$',
  );

  final occurrences = <_Occurrence>[];
  for (var i = 0; i < lines.length; i++) {
    final match = keyPattern.firstMatch(lines[i]);
    if (match != null) {
      occurrences.add(_Occurrence(i + 1, match.group(1)!.trim()));
    }
  }

  if (occurrences.isEmpty) {
    stdout.writeln(
      'iOS asset-symbol-extensions check passed — $pbxprojPath has no '
      '$_key settings to check (AUD-platform-04).',
    );
    return;
  }

  final violations = <String>[];

  for (final occ in occurrences) {
    if (!_validValues.contains(occ.value)) {
      violations.add(
        '$pbxprojPath:${occ.line}: $_key = ${occ.value} — not a valid '
        'Xcode boolean value (must be YES or NO); this looks like a '
        'copy-paste bleed from a neighboring string-valued setting such as '
        'ASSETCATALOG_COMPILER_APPICON_NAME (AUD-platform-04).',
      );
    }
  }

  final distinctValues = occurrences.map((o) => o.value).toSet();
  if (distinctValues.length > 1) {
    final detail = occurrences
        .map((o) => '$pbxprojPath:${o.line}=${o.value}')
        .join(', ');
    violations.add(
      '$pbxprojPath: $_key diverges across XCBuildConfiguration blocks '
      '($detail) — Debug, Release, and Profile must all carry the same '
      'valid YES/NO value (AUD-platform-04).',
    );
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'iOS asset-symbol-extensions check FAILED (AUD-platform-04) — '
      '${violations.length} violation(s):',
    );
    for (final v in violations) {
      stderr.writeln('  - $v');
    }
    exit(1);
  }

  stdout.writeln(
    'iOS asset-symbol-extensions check passed — every '
    '$_key occurrence in $pbxprojPath is the same valid YES/NO value '
    '(AUD-platform-04).',
  );
}
