#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// gen_arch_tables.dart — DNI-391 (Story 27.15)
//
// Reads the @DriftDatabase annotations from:
//   - lib/core/database/user/user_database.dart      (UserDatabase)
//   - lib/core/database/content/content_database.dart (ContentDatabase)
//   - lib/core/database/registry/device_registry_database.dart (DeviceRegistryDatabase)
//
// For each registered table, finds its .dart source file under
// lib/core/database/tables/ (or registry/tables/) and counts the column
// getters (lines matching `\b\w*Column get \w+`).
//
// Prints a Markdown table with columns: Database | Table | Columns.
//
// Usage:
//   dart run tool/gen_arch_tables.dart
//
// The Makefile target `gen-arch-tables` runs this and writes the output
// to the "Database Schema — Generated Table List" section in
// docs/architecture.md.

import 'dart:io';

/// Matches Drift column getter declarations:
///   `  TextColumn get email => ...`
///   `  IntColumn get id => ...`
///   `  DateTimeColumn get createdAt => ...`
final _columnGetter = RegExp(r'\b\w*Column get \w+');

/// Matches class names inside a `tables: [...]` annotation block.
/// Parses multi-line lists by scanning between the brackets.
List<String> _extractTableList(String src) {
  final start = src.indexOf('tables: [');
  if (start < 0) return [];
  final end = src.indexOf(']', start);
  if (end < 0) return [];
  final block = src.substring(start + 'tables: ['.length, end);
  return block
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Returns the project root — accepts being run from the repo root or
/// from learning_tracker/.
Directory _projectRoot() {
  for (final dir in [Directory.current, Directory.current.parent]) {
    if (Directory('${dir.path}/learning_tracker').existsSync()) return dir;
  }
  throw StateError(
    'Cannot locate project root — run from the repo root or learning_tracker/.',
  );
}

/// Overrides for class names whose file name differs from the default
/// PascalCase → snake_case conversion.
const _fileNameOverrides = {
  // Registry DB
  'DeviceAccounts': 'device_accounts',
  'DeviceState': 'device_state',
};

/// Converts PascalCase class name to likely snake_case file name.
String _toSnake(String pascal) {
  if (_fileNameOverrides.containsKey(pascal)) {
    return _fileNameOverrides[pascal]!;
  }
  return pascal
      .replaceAllMapped(
        RegExp(r'(?<=[a-z0-9])([A-Z])'),
        (m) => '_${m.group(1)!.toLowerCase()}',
      )
      .toLowerCase();
}

/// Count columns in a table class file.
int _countColumns(File f) =>
    _columnGetter.allMatches(f.readAsStringSync()).length;

/// Find the table source file for a given class name, searching [searchDirs].
File? _findTableFile(String className, List<Directory> searchDirs) {
  final snake = _toSnake(className);
  for (final dir in searchDirs) {
    if (!dir.existsSync()) continue;
    final candidate = File('${dir.path}/$snake.dart');
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

class _TableRow {
  _TableRow({required this.db, required this.table, required this.columns});
  final String db;
  final String table;
  final int columns;
}

void main() {
  final root = _projectRoot();
  final ltt = '${root.path}/learning_tracker';
  final tablesDir = Directory('$ltt/lib/core/database/tables');
  final registryTablesDir = Directory('$ltt/lib/core/database/registry/tables');

  final databases = [
    (
      label: 'User DB',
      file: File('$ltt/lib/core/database/user/user_database.dart'),
      searchDirs: [tablesDir],
    ),
    (
      label: 'Content DB',
      file: File('$ltt/lib/core/database/content/content_database.dart'),
      searchDirs: [tablesDir],
    ),
    (
      label: 'Registry DB',
      file: File(
        '$ltt/lib/core/database/registry/device_registry_database.dart',
      ),
      searchDirs: [registryTablesDir],
    ),
  ];

  final rows = <_TableRow>[];

  for (final db in databases) {
    if (!db.file.existsSync()) {
      stderr.writeln('WARNING: ${db.file.path} not found — skipping.');
      continue;
    }
    final src = db.file.readAsStringSync();
    final tableNames = _extractTableList(src);
    for (final name in tableNames) {
      final tableFile = _findTableFile(name, db.searchDirs);
      final cols = tableFile != null ? _countColumns(tableFile) : 0;
      if (tableFile == null) {
        stderr.writeln(
          'WARNING: source file not found for ${db.label} table "$name"',
        );
      }
      rows.add(_TableRow(db: db.label, table: name, columns: cols));
    }
  }

  // Print Markdown table.
  print('| Database | Table | Columns |');
  print('|---|---|---|');
  for (final r in rows) {
    print('| ${r.db} | ${r.table} | ${r.columns} |');
  }
  print('');

  // Summary.
  final counts = <String, int>{};
  for (final r in rows) {
    counts[r.db] = (counts[r.db] ?? 0) + 1;
  }
  final summary = counts.entries.map((e) => '${e.value} ${e.key}').join(' + ');
  print(
    '_Generated by `tool/gen_arch_tables.dart`. '
    'Total: $summary = ${rows.length} tables._',
  );
}
