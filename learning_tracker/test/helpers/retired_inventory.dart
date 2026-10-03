/// AD-49 retired Firestore keys, read from the inventory in
/// `tool/retired_symbols/` (DNI-489, Story 1.27).
///
/// A test that proves a retirement holds (a codec never encodes a retired
/// key; a legacy document carrying one still decodes; a write adding one is
/// refused) takes the keys from here instead of spelling them. The
/// retired-test-reference gate (`tool/check_retired_test_references.dart`)
/// then stays empty, and a key retired later is covered with no test change.
library;

import 'dart:convert';
import 'dart:io';

final RegExp _snakeKey = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');
final RegExp _camelKey = RegExp(r'^[a-z][a-z0-9]*([A-Z][a-z0-9]*)+$');

/// The retired Firestore keys of the code at [libPath] in inventory
/// [group]: every retired snake_case `field` entry whose `paths` scope
/// covers [libPath], plus the group's unscoped ones, in inventory order.
/// [aliases] adds the retired camelCase spelling of each of those keys.
List<String> retiredKeysOf(
  String libPath, {
  String group = 'R16',
  bool aliases = false,
}) {
  final file = File('tool/retired_symbols/$group.json');
  final entries =
      (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['entries']
          as List;
  final keys = <String>{};
  final camelSpellings = <String>{};
  for (final entry in entries.cast<Map<String, dynamic>>()) {
    if (entry['kind'] != 'field' || entry['state'] != 'retired') continue;
    final symbol = entry['symbol'] as String;
    if (_camelKey.hasMatch(symbol)) {
      camelSpellings.add(symbol);
      continue;
    }
    if (!_snakeKey.hasMatch(symbol)) continue;
    final paths = entry['paths'];
    if (paths is Map<String, dynamic> && paths['include'] is List) {
      final covered = (paths['include'] as List).cast<String>().any(
        (pattern) => _expandBraces(pattern).any((g) => _matches(g, libPath)),
      );
      if (!covered) continue;
    }
    keys.add(symbol);
  }
  if (aliases) {
    for (final key in keys.toList()) {
      final camel = key.replaceAllMapped(
        RegExp('_([a-z0-9])'),
        (m) => m.group(1)!.toUpperCase(),
      );
      if (camel != key && camelSpellings.contains(camel)) keys.add(camel);
    }
  }
  if (keys.isEmpty) {
    throw StateError('No retired $group keys cover $libPath');
  }
  return keys.toList();
}

/// The deleted code identifiers (retired types, services, callables and UI,
/// unscoped and with no pending entry) of inventory [groups], for audits
/// that a reader or a tree no longer uses the retired stack.
List<String> retiredIdentifiersIn(Iterable<String> groups) {
  final symbols = <String>{};
  for (final group in groups) {
    final entries =
        (jsonDecode(File('tool/retired_symbols/$group.json').readAsStringSync())
                as Map<String, dynamic>)['entries']
            as List;
    final typed = entries.cast<Map<String, dynamic>>();
    final pending = {
      for (final e in typed)
        if (e['state'] != 'retired') e['symbol'] as String,
    };
    for (final entry in typed) {
      final symbol = entry['symbol'] as String;
      if (entry['state'] != 'retired' || pending.contains(symbol)) continue;
      if (entry['kind'] == 'collection' || entry['kind'] == 'field') continue;
      if (entry['paths'] != null) continue;
      symbols.add(symbol);
    }
  }
  if (symbols.isEmpty) throw StateError('No retired identifiers in $groups');
  return symbols.toList();
}

/// A pattern matching any of [identifiers] on identifier boundaries.
RegExp identifierPattern(Iterable<String> identifiers) => RegExp(
  '(?<![A-Za-z0-9_\$])(${identifiers.map(RegExp.escape).join('|')})'
  r'(?![A-Za-z0-9_$])',
);

/// A legacy document fragment holding every key of [keys] at [value].
Map<String, Object?> legacyKeys(
  Iterable<String> keys, {
  Object? value = '2026-01-01T00:00:00.000Z',
}) => {for (final key in keys) key: value};

List<String> _expandBraces(String pattern) {
  final match = RegExp(r'\{([^{}]*)\}').firstMatch(pattern);
  if (match == null) return [pattern];
  return [
    for (final alternative in match.group(1)!.split(','))
      ..._expandBraces(
        pattern.replaceRange(match.start, match.end, alternative),
      ),
  ];
}

bool _matches(String glob, String path) {
  final pattern = RegExp.escape(glob)
      .replaceAll(r'\*\*', '\u0000')
      .replaceAll(r'\*', '[^/]*')
      .replaceAll('\u0000', '.*');
  return RegExp('^$pattern\$').hasMatch(path);
}
