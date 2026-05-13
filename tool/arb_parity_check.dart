#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// arb_parity_check.dart — DNI-389 (Story 27.13, AR9/NFR14).
//
// Reads `learning_tracker/lib/l10n/app_en.arb` and
// `learning_tracker/lib/l10n/app_he.arb` and asserts that every
// user-facing key present in the English file also exists in the
// Hebrew file.
//
// Metadata keys (those starting with `@`) are intentionally excluded
// from the parity check — they carry descriptive context for
// translators and are not required to appear in the target locale.
//
// Exit codes:
//   0  all English keys exist in Hebrew
//   1  one or more English keys are absent in Hebrew (missing keys printed)
//   2  CLI / IO error (file not found, invalid JSON, etc.)

import 'dart:convert';
import 'dart:io';

const _defaultEnPath =
    'learning_tracker/lib/l10n/app_en.arb';
const _defaultHePath =
    'learning_tracker/lib/l10n/app_he.arb';

void main(List<String> argv) {
  exit(_run(argv));
}

int _run(List<String> argv) {
  var enPath = _defaultEnPath;
  var hePath = _defaultHePath;

  for (var i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case '--en':
        if (i + 1 >= argv.length) {
          stderr.writeln('Error: --en requires a value.');
          return 2;
        }
        enPath = argv[++i];
      case '--he':
        if (i + 1 >= argv.length) {
          stderr.writeln('Error: --he requires a value.');
          return 2;
        }
        hePath = argv[++i];
      case '-h' || '--help':
        _printUsage();
        return 0;
      default:
        stderr.writeln('Error: unknown argument `${argv[i]}`.');
        _printUsage();
        return 2;
    }
  }

  final enFile = File(enPath);
  final heFile = File(hePath);

  if (!enFile.existsSync()) {
    stderr.writeln('Error: English ARB not found: $enPath');
    return 2;
  }
  if (!heFile.existsSync()) {
    stderr.writeln('Error: Hebrew ARB not found: $hePath');
    return 2;
  }

  Map<String, dynamic> enMap;
  Map<String, dynamic> heMap;

  try {
    enMap = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (e) {
    stderr.writeln('Error: failed to parse English ARB as JSON: $e');
    return 2;
  }

  try {
    heMap = jsonDecode(heFile.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (e) {
    stderr.writeln('Error: failed to parse Hebrew ARB as JSON: $e');
    return 2;
  }

  // Collect user-facing keys from English ARB (exclude metadata keys that
  // start with `@`).
  final enKeys = enMap.keys.where((k) => !k.startsWith('@')).toSet();
  final heKeys = heMap.keys.where((k) => !k.startsWith('@')).toSet();

  final missing = enKeys.difference(heKeys);

  if (missing.isEmpty) {
    print(
      'arb_parity_check OK — '
      '${enKeys.length} English key(s) all present in Hebrew.',
    );
    return 0;
  }

  stderr.writeln(
    'arb_parity_check FAILED — '
    '${missing.length} English key(s) missing in Hebrew ARB:\n',
  );
  for (final key in missing.toList()..sort()) {
    stderr.writeln('  $key');
  }
  stderr.writeln(
    '\nRemediation: add the missing key(s) to `$hePath`.\n'
    'See Story 26.30 / NFR14 in '
    '`docs/planning/epics-greenfield-rebuild.md`.',
  );
  return 1;
}

void _printUsage() {
  stderr.writeln(
    'Usage: dart run tool/arb_parity_check.dart '
    '[--en <path>] [--he <path>]\n'
    '\n'
    'Defaults:\n'
    '  --en  $_defaultEnPath\n'
    '  --he  $_defaultHePath',
  );
}
