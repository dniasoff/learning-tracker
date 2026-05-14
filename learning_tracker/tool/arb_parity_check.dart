/// ARB parity check — verifies that every key in app_en.arb exists in app_he.arb.
///
/// Usage:
///   dart run tool/arb_parity_check.dart
///
/// Exit codes:
///   0 — all English keys present in Hebrew
///   1 — one or more keys missing in Hebrew (prints the missing keys)
library;

import 'dart:convert';
import 'dart:io';

void main() {
  const enPath = 'lib/l10n/app_en.arb';
  const hePath = 'lib/l10n/app_he.arb';

  final enFile = File(enPath);
  final heFile = File(hePath);

  if (!enFile.existsSync()) {
    stderr.writeln('ERROR: $enPath not found');
    exit(1);
  }
  if (!heFile.existsSync()) {
    stderr.writeln('ERROR: $hePath not found');
    exit(1);
  }

  final enMap = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
  final heMap = jsonDecode(heFile.readAsStringSync()) as Map<String, dynamic>;

  // Collect all translatable keys from English (skip @-prefixed metadata keys).
  final enKeys = enMap.keys.where((k) => !k.startsWith('@')).toSet();
  final heKeys = heMap.keys.where((k) => !k.startsWith('@')).toSet();

  final missing = enKeys.difference(heKeys);

  if (missing.isEmpty) {
    stdout.writeln(
      'arb-parity OK — ${enKeys.length} keys, all present in Hebrew.',
    );
    exit(0);
  }

  stderr.writeln(
    'arb-parity FAILED — ${missing.length} key(s) in $enPath missing from $hePath:',
  );
  for (final key in missing.toList()..sort()) {
    stderr.writeln('  $key');
  }
  exit(1);
}
