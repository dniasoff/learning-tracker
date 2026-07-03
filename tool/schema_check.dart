#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// schema_check.dart — DNI-327 (Story 25.6, AR5/NFR1).
//
// Parses every Drift `Table` subclass under
// `learning_tracker/lib/core/database/tables/` and asserts the v1 schema
// invariants that protect against the multi-profile leak (Story 25.1):
//
//   1. Every profile-scoped table has `profileId` participating in the
//      profile-scoping key. We accept three equivalent shapes:
//        a. `profileId` appears in the explicit `primaryKey` set, OR
//        b. `profileId` appears in at least one `uniqueKeys` set, OR
//        c. `profileId` appears in at least one `@TableIndex(columns: …)`
//           annotation.
//      Shapes (b) and (c) are the historical patterns for autoIncrement
//      tables. All three produce the structural guarantee we care about:
//      profileId is part of the table's keying surface, not an
//      afterthought column the DAO might forget to filter on.
//
//   2. Every profile-scoped table has at least one composite index, either:
//        a. A `@TableIndex(columns: {…})` annotation with 2+ columns, OR
//        b. A `uniqueKeys` entry with 2+ columns.
//
// The whitelist below is intentionally narrow — only tables that satisfy
// both invariants on the v1 schema are listed. New profile-scoped tables
// must be added explicitly, forcing reviewers to verify the invariants.
//
// Exit code:
//   0  every whitelisted table satisfies both invariants
//   1  at least one whitelisted table fails; offending names + hint printed
//   2  CLI/IO error (bad --tables-dir, etc.)

import 'dart:io';

const _defaultTablesDir = 'learning_tracker/lib/core/database/tables';

/// Profile-scoped tables that MUST satisfy the v1 invariants.
///
/// Listed by Drift table-class name. Names use PascalCase, matching the
/// `class X extends Table` declaration. The corresponding SQL table name
/// is the snake_case form (Drift's default).
///
/// Tables intentionally omitted from this list (and why):
///   - Accounts, LearnerProfiles, UserProfiles, Profiles: account- or
///     identity-scoped; not per-profile.
///   - CalendarCycles, DailyContent, TextCache, TextDownloadStatus,
///     SeedMetadata, TrackLearningOrder: global / content / per-track,
///     not per-profile.
///   - SyncQueue: legacy outbox replacement; pre-v1 schema, scheduled
///     for removal once OutboxProcessor (DNI-326) lands fully.
const _defaultWhitelist = <String>{
  'Bookmarks',
  'CompletionEvents',
  'CurriculumScopes',
  'CurriculumTracks',
  'DailyPlans',
  'Goals',
  'LearningLedger',
  'LearningOrder',
  'Outbox',
  'PointConfigs',
  'ProfilePrograms',
  'StageDefinitions',
  'StreakEvents',
  'StudyDayConfigs',
};

class _Violation {
  _Violation(this.tableClass, this.tableFile, this.reasons);
  final String tableClass;
  final String tableFile;
  final List<String> reasons;
}

class _TableDecl {
  _TableDecl({
    required this.className,
    required this.file,
    required this.body,
    required this.tableIndexAnnotations,
  });

  final String className;
  final String file;
  final String body;
  final List<String> tableIndexAnnotations;

  bool get hasProfileIdColumn =>
      RegExp(r'\bget\s+profileId\s*=>').hasMatch(body);

  bool get hasAutoIncrementId => RegExp(
    r'\bget\s+id\s*=>\s*integer\(\)\.autoIncrement\(\)',
  ).hasMatch(body);

  /// Returns the column-name sets declared in `primaryKey`, e.g.
  /// `Set<Column> get primaryKey => {profileId, curriculumId};` →
  /// `[{'profileId','curriculumId'}]`.
  List<Set<String>> get primaryKeySets =>
      _extractColumnSets(body, RegExp(r'get\s+primaryKey\s*=>\s*(\{[^}]*\})'));

  /// Returns the column-name sets declared in `uniqueKeys`.
  List<Set<String>> get uniqueKeySets => _extractColumnSets(
    body,
    RegExp(r'get\s+uniqueKeys\s*=>\s*\[([\s\S]*?)\];'),
    listOfSets: true,
  );

  /// Returns `@TableIndex(columns: {…})` column-name sets.
  List<Set<String>> get tableIndexColumnSets {
    final result = <Set<String>>[];
    final pattern = RegExp(r'columns:\s*(\{[^}]*\})');
    for (final ann in tableIndexAnnotations) {
      final m = pattern.firstMatch(ann);
      if (m == null) continue;
      final set = _parseColumnSet(m.group(1)!);
      if (set.isNotEmpty) result.add(set);
    }
    return result;
  }
}

List<Set<String>> _extractColumnSets(
  String body,
  RegExp pattern, {
  bool listOfSets = false,
}) {
  final match = pattern.firstMatch(body);
  if (match == null) return const [];
  final raw = match.group(1)!;
  if (!listOfSets) {
    final set = _parseColumnSet(raw);
    return set.isEmpty ? const [] : [set];
  }
  // listOfSets: parse the body of `[ {…}, {…} ]`.
  final result = <Set<String>>[];
  final setPattern = RegExp(r'\{[^{}]*\}');
  for (final m in setPattern.allMatches(raw)) {
    final set = _parseColumnSet(m.group(0)!);
    if (set.isNotEmpty) result.add(set);
  }
  return result;
}

Set<String> _parseColumnSet(String raw) {
  // raw is `{a, b, c}` — strip braces and split on commas. Each token
  // can be a bare identifier (column getter) or `#name` (Drift symbol).
  final inner = raw.trim();
  if (!inner.startsWith('{') || !inner.endsWith('}')) return const {};
  final stripped = inner.substring(1, inner.length - 1);
  return stripped
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => s.startsWith('#') ? s.substring(1) : s)
      .toSet();
}

List<_TableDecl> _parseTablesDir(Directory dir) {
  final decls = <_TableDecl>[];
  final files =
      dir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final source = file.readAsStringSync();
    final classPattern = RegExp(
      r'((?:@TableIndex\([^)]*\)\s*)*)class\s+(\w+)\s+extends\s+Table\s*\{',
    );
    for (final match in classPattern.allMatches(source)) {
      final annotationsBlock = match.group(1) ?? '';
      final className = match.group(2)!;
      final bodyStart = match.end - 1; // points at '{'
      final body = _extractBalancedBraces(source, bodyStart);
      if (body == null) continue;
      final tableIndexes = RegExp(
        r'@TableIndex\([^)]*\)',
      ).allMatches(annotationsBlock).map((m) => m.group(0)!).toList();
      decls.add(
        _TableDecl(
          className: className,
          file: file.uri.pathSegments.last,
          body: body,
          tableIndexAnnotations: tableIndexes,
        ),
      );
    }
  }
  return decls;
}

String? _extractBalancedBraces(String source, int openBraceIndex) {
  if (openBraceIndex >= source.length || source[openBraceIndex] != '{') {
    return null;
  }
  var depth = 0;
  for (var i = openBraceIndex; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(openBraceIndex + 1, i);
    }
  }
  return null;
}

List<_Violation> _validate(List<_TableDecl> decls, Set<String> whitelist) {
  final violations = <_Violation>[];
  final seen = <String>{};

  for (final decl in decls) {
    if (!whitelist.contains(decl.className)) continue;
    seen.add(decl.className);

    final reasons = <String>[];

    if (!decl.hasProfileIdColumn) {
      reasons.add(
        'no `profileId` column found. Add `IntColumn get profileId => integer()();`.',
      );
    } else {
      final pkSets = decl.primaryKeySets;
      final ukSets = decl.uniqueKeySets;
      final indexSets = decl.tableIndexColumnSets;
      final profileInPk = pkSets.any((s) => s.contains('profileId'));
      final profileInUk = ukSets.any((s) => s.contains('profileId'));
      final profileInIndex = indexSets.any((s) => s.contains('profileId'));

      if (!profileInPk && !profileInUk && !profileInIndex) {
        reasons.add(
          '`profileId` is not part of the profile-scoping key. Add it to '
          '`primaryKey`, to a `uniqueKeys` entry, or to an '
          '`@TableIndex(columns: {#profileId, …})` annotation.',
        );
      }
    }

    final indexSets = decl.tableIndexColumnSets;
    final ukSets = decl.uniqueKeySets;
    final pkSets = decl.primaryKeySets;
    final hasCompositeIndex = indexSets.any((s) => s.length >= 2);
    final hasCompositeUnique = ukSets.any((s) => s.length >= 2);
    final hasCompositePk = pkSets.any((s) => s.length >= 2);

    if (!hasCompositeIndex && !hasCompositeUnique && !hasCompositePk) {
      reasons.add(
        'no composite index, composite `uniqueKeys`, or composite '
        '`primaryKey` declared. Add `@TableIndex(name: …, columns: '
        '{#profileId, #…})` above the class, or a multi-column '
        '`uniqueKeys`/`primaryKey` entry.',
      );
    }

    if (reasons.isNotEmpty) {
      violations.add(_Violation(decl.className, decl.file, reasons));
    }
  }

  for (final expected in whitelist) {
    if (!seen.contains(expected)) {
      violations.add(
        _Violation(expected, '<missing>', [
          'whitelisted table not found in tables directory. Either remove it '
              'from the whitelist in `tool/schema_check.dart` or restore the '
              'table file.',
        ]),
      );
    }
  }

  return violations;
}

void _printUsage() {
  stderr.writeln(
    'Usage: dart run tool/schema_check.dart '
    '[--tables-dir <path>] [--whitelist <Name1,Name2>]',
  );
}

void main(List<String> argv) {
  final code = _run(argv);
  exit(code);
}

int _run(List<String> argv) {
  var tablesDir = _defaultTablesDir;
  Set<String> whitelist = _defaultWhitelist;

  for (var i = 0; i < argv.length; i++) {
    final arg = argv[i];
    if (arg == '--tables-dir') {
      if (i + 1 >= argv.length) {
        stderr.writeln('Error: --tables-dir requires a value.');
        _printUsage();
        return 2;
      }
      tablesDir = argv[++i];
    } else if (arg == '--whitelist') {
      if (i + 1 >= argv.length) {
        stderr.writeln('Error: --whitelist requires a value.');
        _printUsage();
        return 2;
      }
      whitelist = argv[++i]
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

  final dir = Directory(tablesDir);
  if (!dir.existsSync()) {
    stderr.writeln('Error: tables directory not found: $tablesDir');
    return 2;
  }

  final decls = _parseTablesDir(dir);
  final violations = _validate(decls, whitelist);

  if (violations.isEmpty) {
    print(
      'schema_check OK — '
      '${whitelist.length} profile-scoped tables verified.',
    );
    return 0;
  }

  stderr.writeln(
    'schema_check FAILED — '
    '${violations.length} table(s) violate v1 invariants:\n',
  );
  for (final v in violations) {
    stderr.writeln('  ${v.tableClass}  (${v.tableFile})');
    for (final reason in v.reasons) {
      stderr.writeln('    - $reason');
    }
    stderr.writeln('');
  }
  stderr.writeln(
    'Remediation: see Story 25.1 / Story 25.6 in '
    '`docs/planning/epics-greenfield-rebuild.md`. Every profile-scoped '
    'table must have `profileId` in its profile-scoping key (PK or '
    'composite UNIQUE) and at least one composite index / UNIQUE / PK.',
  );
  return 1;
}
