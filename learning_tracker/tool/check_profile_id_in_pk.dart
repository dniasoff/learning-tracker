/// profileId-in-PK Invariant checker — AUD-t-cross-06.
///
/// docs/coding-standards.md's "profileId-in-PK Invariant" section (line
/// ~692) claims: "**Enforcement:** `make audit` flags any user-DB table
/// without a `profileId` column." AUD-t-cross-06 found that claim was
/// false for `learning_tracker`'s `make audit` (`grep -n profileId
/// learning_tracker/Makefile` matched nothing) — the only mechanism that
/// came close, `tool/schema_check.dart`, uses an accretion whitelist that
/// silently skips any table never added to it (which is exactly how
/// `TrackLearningOrder` went unnoticed).
///
/// This script is deny-by-default instead: it reads every table class
/// named in `UserDatabase`'s `tables: [...]` list
/// (`lib/core/database/user/user_database.dart`) — not a hand-maintained
/// whitelist — finds each table's `.dart` source under
/// `lib/core/database/tables/`, and fails if the class has no `profileId`
/// column UNLESS the table is named in [_defaultExemptTables] below, so a
/// NEW per-profile table added to `UserDatabase` without a `profileId`
/// column fails this check immediately, with no whitelist entry required to
/// "turn the check on" for it.
///
/// Usage:
///   dart run tool/check_profile_id_in_pk.dart
///   dart run tool/check_profile_id_in_pk.dart \
///       [--user-database-file <path>] [--tables-dir <path>] \
///       [--exempt <Name1,Name2>]
///
/// Exit codes:
///   0 — every non-exempt table has a profileId column
///   1 — one or more non-exempt tables are missing profileId (prints names)
///   2 — CLI/IO error (user-database file or a table file not found)
// ignore_for_file: avoid_print
library;

import 'dart:io';

const _defaultUserDatabaseFile = 'lib/core/database/user/user_database.dart';
const _defaultTablesDir = 'lib/core/database/tables';

/// UserDatabase tables that are legitimately NOT per-profile data, so they
/// carry no `profileId` column. Each entry names the reason — this list is
/// the "documented content-table exemption list" docs/coding-standards.md's
/// profileId-in-PK section refers to.
///
///   - Accounts, LearnerProfiles: identity backbone — `profileId` IS
///     `LearnerProfiles.id`; these tables define the concept, they don't
///     carry it as a foreign column.
///   - TextDownloadStatuses: device-level content-download tracking (which
///     curricula have been downloaded for offline use) — shared across
///     every profile on the device, not per-profile.
///   - SacredWindowEntries: device/location-level Sacred Time window cache
///     (depends on device geolocation, not on which profile is active).
///   - SyncKv: device-level sync-cursor bookkeeping (last-applied
///     `updated_at` per entity kind/key) — not user-facing per-profile data.
const _defaultExemptTables = <String>{
  'Accounts',
  'LearnerProfiles',
  'TextDownloadStatuses',
  'SacredWindowEntries',
  'SyncKv',
};

final _tablesListPattern = RegExp(r'tables:\s*\[([^\]]*)\]', dotAll: true);
final _identifierPattern = RegExp(r'^[A-Z][A-Za-z0-9_]*$');
final _profileIdGetterPattern = RegExp(r'\bget\s+profileId\s*=>');

List<String> _extractTableNames(String source) {
  final match = _tablesListPattern.firstMatch(source);
  if (match == null) return const [];
  final body = match.group(1)!;
  // Strip full-line/trailing `//` comments before splitting on commas — a
  // comment on its own line would otherwise be swallowed into the same
  // comma-delimited token as the identifier on the next line.
  final withoutComments = body
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx == -1 ? line : line.substring(0, idx);
      })
      .join('\n');
  return withoutComments
      .split(',')
      .map((t) => t.trim())
      .where((t) => _identifierPattern.hasMatch(t))
      .toList();
}

/// Finds `class $tableName extends Table {` under [tablesDir] and returns
/// whether its body declares a `profileId` getter. Returns `null` if no
/// file in [tablesDir] declares the class at all.
bool? _hasProfileIdColumn(String tableName, Directory tablesDir) {
  final classPattern = RegExp('class\\s+$tableName\\s+extends\\s+Table\\s*\\{');
  for (final entity in tablesDir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    final match = classPattern.firstMatch(content);
    if (match == null) continue;

    var depth = 0;
    var i = match.end - 1; // position of the opening '{'
    var bodyStart = -1;
    for (; i < content.length; i++) {
      final ch = content[i];
      if (ch == '{') {
        depth++;
        if (bodyStart == -1) bodyStart = i + 1;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) break;
      }
    }
    final body = content.substring(bodyStart, i);
    return _profileIdGetterPattern.hasMatch(body);
  }
  return null;
}

void _printUsage() {
  stderr.writeln(
    'Usage: dart run tool/check_profile_id_in_pk.dart '
    '[--user-database-file <path>] [--tables-dir <path>] '
    '[--exempt <Name1,Name2>]',
  );
}

void main(List<String> argv) {
  final code = _run(argv);
  exit(code);
}

int _run(List<String> argv) {
  var userDatabaseFile = _defaultUserDatabaseFile;
  var tablesDir = _defaultTablesDir;
  var exemptTables = _defaultExemptTables;

  for (var i = 0; i < argv.length; i++) {
    final arg = argv[i];
    if (arg == '--user-database-file') {
      if (i + 1 >= argv.length) {
        stderr.writeln('Error: --user-database-file requires a value.');
        _printUsage();
        return 2;
      }
      userDatabaseFile = argv[++i];
    } else if (arg == '--tables-dir') {
      if (i + 1 >= argv.length) {
        stderr.writeln('Error: --tables-dir requires a value.');
        _printUsage();
        return 2;
      }
      tablesDir = argv[++i];
    } else if (arg == '--exempt') {
      if (i + 1 >= argv.length) {
        stderr.writeln('Error: --exempt requires a value.');
        _printUsage();
        return 2;
      }
      exemptTables = argv[++i]
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } else if (arg == '-h' || arg == '--help') {
      _printUsage();
      return 0;
    } else {
      stderr.writeln('Error: unknown argument `$arg`.');
      _printUsage();
      return 2;
    }
  }

  final userDbFile = File(userDatabaseFile);
  if (!userDbFile.existsSync()) {
    stderr.writeln('ERROR: $userDatabaseFile not found.');
    return 2;
  }
  final dir = Directory(tablesDir);
  if (!dir.existsSync()) {
    stderr.writeln('ERROR: $tablesDir not found.');
    return 2;
  }

  final tableNames = _extractTableNames(userDbFile.readAsStringSync());
  if (tableNames.isEmpty) {
    stderr.writeln(
      'ERROR: could not find a non-empty `tables: [...]` list in '
      '$userDatabaseFile',
    );
    return 2;
  }

  final missing = <String>[];
  final notFound = <String>[];

  for (final tableName in tableNames) {
    if (exemptTables.contains(tableName)) continue;
    final hasProfileId = _hasProfileIdColumn(tableName, dir);
    if (hasProfileId == null) {
      notFound.add(tableName);
    } else if (!hasProfileId) {
      missing.add(tableName);
    }
  }

  if (notFound.isNotEmpty) {
    stderr.writeln(
      'ERROR: could not locate the Table class source for: '
      '${notFound.join(", ")} under $tablesDir/',
    );
    return 2;
  }

  if (missing.isEmpty) {
    print(
      'check_profile_id_in_pk OK — '
      '${tableNames.length - exemptTables.length} non-exempt table(s) all '
      'carry profileId.',
    );
    return 0;
  }

  stderr.writeln(
    'check_profile_id_in_pk FAILED — ${missing.length} UserDatabase '
    'table(s) have no `profileId` column and are not on the documented '
    'exemption list (tool/check_profile_id_in_pk.dart `_defaultExemptTables`):\n',
  );
  for (final name in missing) {
    stderr.writeln('  $name');
  }
  stderr.writeln(
    '\nRemediation: every user-data table in UserDatabase must carry '
    '`profileId` as part of its keying surface (docs/coding-standards.md, '
    '"profileId-in-PK Invariant", AUD-t-cross-06). Either add a `profileId` '
    'IntColumn (`.references(LearnerProfiles, #id, onDelete: '
    'KeyAction.cascade)`) with a schema migration, or — if the table is '
    'genuinely device-level/content-level and not per-profile data — add it '
    'to `_defaultExemptTables` in tool/check_profile_id_in_pk.dart with a '
    'one-line reason, matching the existing entries.',
  );
  return 1;
}
