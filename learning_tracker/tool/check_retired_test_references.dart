/// Retired-stack test-reference gate (DNI-489, Story 1.27, AD-49 R15).
///
/// Fails when a symbol deleted by the retirement stories (1.11–1.26) is
/// still referenced anywhere under `test/`, `integration_test/` or
/// `functions/test/` — source, comments and text fixtures alike. Binary
/// files are skipped. There is no allowlist: what counts as deleted, and
/// where, comes only from the AD-49 inventory in `tool/retired_symbols/`
/// (the data `tool/check_retired_symbols.dart` enforces on runtime code).
///
/// The inventory is read as its contract defines it:
///
/// * **Deleted means `retired`.** A symbol with any `pending` entry still
///   has a live AD-49 remnant (for example the R14 `firestore.rules`
///   blocks, `deletes.ts` entries and indexes of a retired collection,
///   which the cutover release DNI-490 flips and DNI-491 removes). It is not
///   yet deleted, so tests of that remnant may name it. When its last entry
///   becomes `retired` this gate covers it with no change here.
/// * **A retired entry is deleted only in its `paths` scope.** The scope is
///   projected onto the tests of that code:
///
///   | inventory scope            | test scope                                     |
///   | -------------------------- | ---------------------------------------------- |
///   | none                       | all three test roots                           |
///   | `lib/**`                   | `test/**`, `integration_test/**`               |
///   | `lib/<dir>/**`             | `test/<dir>/**`, `integration_test/<dir>/**`   |
///   | `lib/<path>.dart`          | `{test,integration_test}/<path>_test.dart` and `<path>_*_test.dart` |
///   | `functions/src/**`         | `functions/test/**`                            |
///   | `functions/src/<name>.ts`  | `functions/test/{cf_,}<name>.test.mjs`         |
///   | `firestore.rules`          | `functions/test/firestore_rules.test.mjs`      |
///   | anything else              | all three test roots (fail safe)               |
///
///   `exclude` patterns project the same way. Brace alternatives
///   (`{a,b}`) expand first.
/// * **A one-word lowercase `collection` or `field` name** (such as a
///   collection called by an English plural) is a reference only in code
///   position: between quotes or backticks, or as a `/` path segment. Prose
///   that happens to use the same word is not a reference to the deleted
///   symbol. Every other symbol matches on identifier boundaries anywhere.
library;

import 'dart:convert';
import 'dart:io';

const _retiredInventoryDir = 'tool/retired_symbols';
const _retiredInventoryFileCount = 16;
const _testRoots = ['test', 'integration_test', 'functions/test'];

final class RetiredTestReference {
  const RetiredTestReference({
    required this.path,
    required this.line,
    required this.symbol,
  });

  final String path;
  final int line;
  final String symbol;

  @override
  String toString() => '$path:$line: $symbol';
}

/// One retired inventory entry, projected onto the test roots.
final class RetiredTestSymbol {
  const RetiredTestSymbol(
    this.symbol, {
    this.kind = 'type',
    this.include,
    this.exclude = const [],
  });

  final String symbol;

  /// The inventory kind (`type`, `service`, `collection`, `field`, ...).
  final String kind;

  /// Test-path globs the symbol is deleted in; null means every test root.
  final List<String>? include;

  /// Test-path globs carved out of [include].
  final List<String> exclude;

  /// Whether [path] (relative, `/`-separated) is in this entry's scope.
  bool covers(String path) {
    final included = include;
    if (included != null && !included.any((g) => _globMatches(g, path))) {
      return false;
    }
    return !exclude.any((g) => _globMatches(g, path));
  }

  /// Whether a match must sit in code position (see the library doc).
  bool get codePositionOnly =>
      (kind == 'collection' || kind == 'field') &&
      RegExp(r'^[a-z]+$').hasMatch(symbol);
}

List<Map<String, dynamic>> _inventoryEntries(Directory root) {
  final entries = <Map<String, dynamic>>[];
  for (var group = 1; group <= _retiredInventoryFileCount; group++) {
    final file = File('${root.path}/$_retiredInventoryDir/R$group.json');
    if (!file.existsSync()) {
      throw FileSystemException('Missing retired-symbol inventory', file.path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
      throw FormatException('Malformed retired-symbol inventory: ${file.path}');
    }
    for (final entry in decoded['entries'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('Malformed inventory entry: ${file.path}');
      }
      final symbol = entry['symbol'];
      if (symbol is! String || symbol.isEmpty) {
        throw FormatException('Malformed retired symbol: ${file.path}');
      }
      entries.add(entry);
    }
  }
  return entries;
}

/// Loads every deleted inventory entry, projected onto the test roots.
/// Symbols with any `pending` entry are left out (see the library doc).
List<RetiredTestSymbol> loadRetiredTestInventory(Directory root) {
  final entries = _inventoryEntries(root);
  final pending = {
    for (final e in entries)
      if (e['state'] != 'retired') e['symbol'] as String,
  };
  return [
    for (final e in entries)
      if (e['state'] == 'retired' && !pending.contains(e['symbol']))
        _project(e),
  ];
}

/// The distinct symbols [loadRetiredTestInventory] checks.
Set<String> loadRetiredTestSymbols(Directory root) => {
  for (final entry in loadRetiredTestInventory(root)) entry.symbol,
};

RetiredTestSymbol _project(Map<String, dynamic> entry) {
  final paths = entry['paths'];
  List<String> globs(String key) => [
    if (paths is Map<String, dynamic> && paths[key] is List)
      for (final pattern in (paths[key] as List).cast<String>())
        for (final expanded in expandBraces(pattern))
          ...projectToTestRoots(expanded),
  ];
  final includes = paths is Map<String, dynamic> && paths['include'] is List
      ? globs('include')
      : null;
  return RetiredTestSymbol(
    entry['symbol'] as String,
    kind: (entry['kind'] as String?) ?? 'type',
    include: includes,
    exclude: globs('exclude'),
  );
}

/// Expands `{a,b}` alternatives (nested braces are not used by the
/// inventory).
List<String> expandBraces(String pattern) {
  final match = RegExp(r'\{([^{}]*)\}').firstMatch(pattern);
  if (match == null) return [pattern];
  return [
    for (final alternative in match.group(1)!.split(','))
      ...expandBraces(
        pattern.replaceRange(match.start, match.end, alternative),
      ),
  ];
}

/// Projects one inventory path glob onto test-path globs (see the table in
/// the library doc).
List<String> projectToTestRoots(String pattern) {
  if (pattern.startsWith('lib/')) {
    final rest = pattern.substring('lib/'.length);
    if (rest.endsWith('.dart') && !rest.contains('*')) {
      final stem = rest.substring(0, rest.length - '.dart'.length);
      return [
        for (final root in const ['test', 'integration_test']) ...[
          '$root/${stem}_test.dart',
          '$root/${stem}_*_test.dart',
        ],
      ];
    }
    return ['test/$rest', 'integration_test/$rest'];
  }
  if (pattern.startsWith('functions/src/')) {
    final rest = pattern.substring('functions/src/'.length);
    if (rest.endsWith('.ts') && !rest.contains('*')) {
      final stem = rest.substring(0, rest.length - '.ts'.length);
      return [
        'functions/test/cf_$stem.test.mjs',
        'functions/test/$stem.test.mjs',
      ];
    }
    return ['functions/test/$rest'];
  }
  if (pattern == 'firestore.rules') {
    return ['functions/test/firestore_rules.test.mjs'];
  }
  return [for (final root in _testRoots) '$root/**'];
}

bool _globMatches(String glob, String path) {
  final buffer = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    final char = glob[i];
    if (char == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        buffer.write('.*');
        i++;
      } else {
        buffer.write('[^/]*');
      }
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString()).hasMatch(path);
}

/// Scans the three test roots. A missing or empty root has no references.
/// Text files are scanned regardless of extension; binary files are skipped.
///
/// [symbols] are checked everywhere on identifier boundaries; [inventory]
/// entries are checked in their own scope (see [RetiredTestSymbol]).
List<RetiredTestReference> scanRetiredTestReferences({
  required Directory root,
  Iterable<String> symbols = const [],
  Iterable<RetiredTestSymbol> inventory = const [],
}) {
  final checks = [
    for (final symbol in symbols.toSet()) RetiredTestSymbol(symbol),
    ...inventory,
  ]..sort((a, b) => b.symbol.length.compareTo(a.symbol.length));
  final patterns = <RetiredTestSymbol, RegExp>{
    for (final check in checks) check: _symbolPattern(check),
  };
  final references = <RetiredTestReference>[];
  final seen = <String>{};

  for (final relativeRoot in _testRoots) {
    final scanRoot = Directory('${root.path}/$relativeRoot');
    if (!scanRoot.existsSync()) continue;

    for (final entity in scanRoot.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final path = _relativePath(root, entity.path);
      final applicable = [
        for (final check in checks)
          if (check.covers(path)) check,
      ];
      if (applicable.isEmpty) continue;
      final contents = _decodeText(entity.readAsBytesSync());
      if (contents == null) continue;

      final lines = contents.split('\n');
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        for (final check in applicable) {
          var index = 0;
          for (final _ in patterns[check]!.allMatches(lines[lineIndex])) {
            // A symbol scoped by several entries is reported once per match.
            final key = '$path:$lineIndex:${check.symbol}:${index++}';
            if (!seen.add(key)) continue;
            references.add(
              RetiredTestReference(
                path: path,
                line: lineIndex + 1,
                symbol: check.symbol,
              ),
            );
          }
        }
      }
    }
  }

  references.sort((a, b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    final lineOrder = a.line.compareTo(b.line);
    if (lineOrder != 0) return lineOrder;
    return a.symbol.compareTo(b.symbol);
  });
  return references;
}

String _relativePath(Directory root, String path) {
  final rootPath = root.absolute.path;
  final absolutePath = File(path).absolute.path;
  if (absolutePath.startsWith('$rootPath${Platform.pathSeparator}')) {
    return absolutePath
        .substring(rootPath.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
  }
  return path.replaceAll(Platform.pathSeparator, '/');
}

String? _decodeText(List<int> bytes) {
  if (bytes.contains(0)) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

RegExp _symbolPattern(RetiredTestSymbol check) {
  final symbol = check.symbol;
  if (check.codePositionOnly) {
    return RegExp('(?<=[\'"`/])${RegExp.escape(symbol)}(?=[\'"`/])');
  }
  final startsWithIdentifier = RegExp(r'^[A-Za-z0-9_$]').hasMatch(symbol);
  final endsWithIdentifier = RegExp(r'[A-Za-z0-9_$]$').hasMatch(symbol);
  final left = startsWithIdentifier ? r'(?<![A-Za-z0-9_$])' : '';
  final right = endsWithIdentifier ? r'(?![A-Za-z0-9_$])' : '';
  return RegExp('$left${RegExp.escape(symbol)}$right');
}

void main(List<String> args) {
  if (args.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/check_retired_test_references.dart');
    exitCode = 2;
    return;
  }

  final root = Directory.current;
  try {
    final inventory = loadRetiredTestInventory(root);
    final references = scanRetiredTestReferences(
      root: root,
      inventory: inventory,
    );
    if (references.isEmpty) {
      stdout.writeln(
        'Retired test-reference check passed: no retired symbols in ${_testRoots.join(', ')}.',
      );
      return;
    }
    for (final reference in references) {
      stdout.writeln(reference);
    }
    stdout.writeln(
      'Retired test-reference check failed: ${references.length} reference(s) across ${references.map((e) => e.path).toSet().length} file(s).',
    );
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Retired test-reference check could not run: $error');
    exitCode = 2;
  }
}
