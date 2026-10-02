/// AD-49 retired-symbols gate (DNI-521, "R0"; orchestrator ruling B3).
///
/// `docs/planning/architecture/architecture-sub-tracks-2026-09-30/
/// ARCHITECTURE-SPINE.md` AD-49 names this file as the binding cutover
/// gate: CI fails on any retired collection name, field, type, service or
/// callable in `lib/`, `functions/src/` or `firestore.rules`, except a
/// checked-in allowlist holding exactly the deny-all `match` blocks for the
/// retired collections in `firestore.rules` and their entries in
/// `functions/src/deletes.ts` and `firestore.indexes.json`.
///
/// ## Data-driven inventory, one file per Retirement Inventory group
///
/// The symbols live in `tool/retired_symbols/R1.json` ... `R16.json` (the
/// spine's Retirement Inventory rows R1-R16), never in this file. Each
/// group file is:
///
/// ```json
/// {"group": "R1", "title": "...", "entries": [
///   {"symbol": "CompletionEntity", "kind": "type", "state": "pending", "owner": "DNI-483"}
/// ]}
/// ```
///
/// Entry keys:
/// - `symbol` (required): matched on identifier word boundaries
///   (`[A-Za-z0-9_$]`), case-sensitive, never inside comments.
/// - `kind` (required): `collection | type | service | callable | field | ui`.
/// - `state` (required): `pending | retired`.
/// - `owner` (required): the Linear story that deletes it, `DNI-<n>`.
/// - `paths` (optional): `{"include": [globs], "exclude": [globs]}`,
///   relative to `learning_tracker/`. `**` spans directories, `*` and `?`
///   stay within one segment, `{a,b}` alternates. Without `include` the
///   entry applies to every scanned file.
/// - `match` (optional): `any` (identifiers and string literals) or
///   `string` (only where the symbol is a whole string literal or a
///   `/`-delimited segment of one, i.e. a Firestore path or field key;
///   never a variable, interpolated code, or a word in prose such as an
///   error message). Defaults by kind: `collection` and
///   `field` are `string`, everything else `any`. `string` only narrows
///   `.dart` and `.ts` files: `firestore.rules` path segments and
///   `firestore.indexes.json` values are always matched.
/// - `note` (optional): free text.
///
/// The same symbol may appear in more than one entry only with a different
/// `paths` scope (R14 owns the rules/indexes/deletes.ts remnants of the
/// retired collections; R1/R5/R6/R8/R13 own the rest of the tree).
///
/// ## Allowlist
///
/// `tool/retired_symbols/allowlist.json`:
///
/// ```json
/// {"entries": [
///   {"symbol": "completions", "path": "firestore.rules", "count": 1, "reason": "AD-49 deny-all match"}
/// ]}
/// ```
///
/// `count` is the exact number of hits of `symbol` in `path` it permits.
/// Per AD-49 an entry is valid only when `symbol` is an R14 `collection`
/// entry whose scope covers `path`, and `path` is `firestore.rules`,
/// `firestore.indexes.json` or `functions/src/deletes.ts`; anything else
/// is malformed (exit 2), in every mode.
///
/// ## Behaviour
///
/// - A malformed or duplicate inventory/allowlist entry fails (exit 2).
/// - A `retired` symbol that still appears outside the allowlist fails
///   (exit 1).
/// - A `pending` symbol is reported (counts) and never fails.
/// - `--enforce` (reserved for the cutover, DNI-490) treats every entry
///   as retired and requires the allowlist to match exactly: every hit
///   allowlisted, and every allowlist entry's count equal to its hits.
///
/// Contract for later stories: delete the code, then flip your own entries
/// in your own `R<n>.json` to `"retired"`. Never edit this checker.
///
/// Usage (from `learning_tracker/`):
///   dart run tool/check_retired_symbols.dart
///   dart run tool/check_retired_symbols.dart --report     # list every hit
///   dart run tool/check_retired_symbols.dart --enforce    # cutover mode
///   dart run tool/check_retired_symbols.dart --root DIR   # fixture root
///
/// Exit codes: 0 pass, 1 retired symbol outside the allowlist (or, under
/// `--enforce`, an inexact allowlist), 2 malformed inventory/allowlist,
/// a missing, mistyped or symlinked scan root (`lib/`, `functions/src/`,
/// `firestore.rules`, `firestore.indexes.json`), a symbolic link anywhere
/// under `lib/` or `functions/src/`, an unreadable scanned file or
/// directory (all fail closed), or bad usage.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _inventoryDir = 'tool/retired_symbols';
const _allowlistName = 'allowlist.json';
const _groupCount = 16;

const _kinds = {'collection', 'type', 'service', 'callable', 'field', 'ui'};
const _states = {'pending', 'retired'};
const _matchModes = {'any', 'string'};
const _stringKinds = {'collection', 'field'};
const _entryKeys = {
  'symbol',
  'kind',
  'state',
  'owner',
  'paths',
  'match',
  'note',
};
const _groupKeys = {'group', 'title', 'description', 'entries'};
const _allowlistKeys = {'description', 'entries'};
const _allowEntryKeys = {'symbol', 'path', 'count', 'reason', 'owner'};

/// AD-49: the allowlist holds exactly the cutover remnants of the retired
/// collections, i.e. R14 `collection` entries, and only in these files.
/// Nothing else (no type, service, callable, field or ui symbol, no other
/// group, no other path) can ever be allowlisted.
const _allowGroup = 'R14';
const _allowKind = 'collection';
const _allowPaths = [
  'firestore.rules',
  'firestore.indexes.json',
  'functions/src/deletes.ts',
];
final _ownerPattern = RegExp(r'^DNI-[0-9]+$');

// ---------------------------------------------------------------------------
// Inventory model
// ---------------------------------------------------------------------------

class _Entry {
  _Entry({
    required this.group,
    required this.symbol,
    required this.kind,
    required this.state,
    required this.owner,
    required this.include,
    required this.exclude,
    required this.stringOnly,
  });

  final String group;
  final String symbol;
  final String kind;
  final String state;
  final String owner;
  final List<RegExp> include;
  final List<RegExp> exclude;
  final bool stringOnly;

  bool appliesTo(String path) {
    if (include.isNotEmpty && !include.any((r) => r.hasMatch(path))) {
      return false;
    }
    return !exclude.any((r) => r.hasMatch(path));
  }
}

class _AllowEntry {
  _AllowEntry(this.symbol, this.path, this.count);
  final String symbol;
  final String path;
  final int count;
}

class _Hit {
  _Hit(this.path, this.line, this.column, this.text);
  final String path;
  final int line;
  final int column;
  final String text;

  String get key => '$path:$line:$column';

  @override
  String toString() => '$path:$line:$column: $text';
}

/// Translates a path glob to an anchored RegExp. `**/` matches zero or
/// more directories, `**` anything, `*` and `?` stay within one segment,
/// `{a,b}` alternates.
RegExp _globToRegExp(String glob) {
  final b = StringBuffer('^');
  var braceDepth = 0;
  for (var i = 0; i < glob.length; i++) {
    final c = glob[i];
    if (c == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        if (i + 2 < glob.length && glob[i + 2] == '/') {
          b.write('(?:.*/)?');
          i += 2;
        } else {
          b.write('.*');
          i += 1;
        }
      } else {
        b.write('[^/]*');
      }
    } else if (c == '?') {
      b.write('[^/]');
    } else if (c == '{') {
      braceDepth++;
      b.write('(?:');
    } else if (c == '}' && braceDepth > 0) {
      braceDepth--;
      b.write(')');
    } else if (c == ',' && braceDepth > 0) {
      b.write('|');
    } else {
      b.write(RegExp.escape(c));
    }
  }
  b.write(r'$');
  return RegExp(b.toString());
}

// ---------------------------------------------------------------------------
// Loading + schema validation
// ---------------------------------------------------------------------------

class _Inventory {
  final entries = <_Entry>[];
  final allow = <_AllowEntry>[];
  final errors = <String>[];
}

Object? _readJson(File file, List<String> errors) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    errors.add('${file.path}: invalid JSON (${e.message})');
  } on FileSystemException catch (e) {
    errors.add('${file.path}: unreadable (${e.message})');
  }
  return null;
}

bool _isNonEmptyString(Object? v) => v is String && v.trim().isNotEmpty;

bool _isValidGlob(String g) =>
    g.isNotEmpty && !g.startsWith('/') && !g.split('/').contains('..');

List<String>? _globList(Object? v, String where, List<String> errors) {
  if (v == null) return const [];
  if (v is! List || v.isEmpty) {
    errors.add('$where: must be a non-empty list of globs');
    return null;
  }
  final out = <String>[];
  for (final g in v) {
    if (g is! String || !_isValidGlob(g)) {
      errors.add(
        '$where: invalid glob ${jsonEncode(g)} (relative to '
        'learning_tracker/, no leading "/" or "..")',
      );
      return null;
    }
    out.add(g);
  }
  return out;
}

_Inventory _loadInventory(String root) {
  final inv = _Inventory();
  final errors = inv.errors;
  final dir = Directory('$root/$_inventoryDir');
  if (!dir.existsSync()) {
    errors.add('$_inventoryDir/ not found under $root');
    return inv;
  }

  final expected = {for (var n = 1; n <= _groupCount; n++) 'R$n.json'};
  final present = dir
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.json'))
      .toSet();
  for (final name in present.difference({...expected, _allowlistName})) {
    errors.add(
      '$_inventoryDir/$name: unexpected file (only R1.json..'
      'R$_groupCount.json and $_allowlistName belong here)',
    );
  }

  final seen = <String, String>{};
  final groupNames = expected.toList()
    ..sort(
      (a, b) => int.parse(
        a.substring(1, a.length - 5),
      ).compareTo(int.parse(b.substring(1, b.length - 5))),
    );
  for (final name in groupNames) {
    final where = '$_inventoryDir/$name';
    if (!present.contains(name)) {
      errors.add(
        '$where: missing (every Retirement Inventory group '
        'R1-R$_groupCount has a file, even with no entries)',
      );
      continue;
    }
    final data = _readJson(File('${dir.path}/$name'), errors);
    if (data == null) continue;
    final group = name.substring(0, name.length - 5);
    if (data is! Map<String, Object?>) {
      errors.add('$where: top level must be an object');
      continue;
    }
    for (final k in data.keys.where((k) => !_groupKeys.contains(k))) {
      errors.add('$where: unknown key "$k"');
    }
    if (data['group'] != group) {
      errors.add('$where: "group" must be "$group"');
    }
    if (!_isNonEmptyString(data['title'])) {
      errors.add('$where: "title" must be a non-empty string');
    }
    final list = data['entries'];
    if (list is! List) {
      errors.add('$where: "entries" must be a list');
      continue;
    }
    for (var i = 0; i < list.length; i++) {
      final entry = _parseEntry(group, list[i], '$where entries[$i]', errors);
      if (entry == null) continue;
      final raw = list[i] as Map<String, Object?>;
      final dupKey = '${entry.symbol}\u0000${jsonEncode(raw['paths'])}';
      final prior = seen[dupKey];
      if (prior != null) {
        errors.add(
          '$where entries[$i]: duplicate of $prior '
          '(symbol "${entry.symbol}" with the same paths scope)',
        );
        continue;
      }
      seen[dupKey] = '$where entries[$i]';
      inv.entries.add(entry);
    }
  }

  final allowFile = File('${dir.path}/$_allowlistName');
  if (!allowFile.existsSync()) {
    errors.add('$_inventoryDir/$_allowlistName: missing');
  } else {
    _loadAllowlist(allowFile, inv);
  }
  return inv;
}

_Entry? _parseEntry(
  String group,
  Object? raw,
  String where,
  List<String> errors,
) {
  if (raw is! Map<String, Object?>) {
    errors.add('$where: must be an object');
    return null;
  }
  var ok = true;
  void bad(String msg) {
    errors.add('$where: $msg');
    ok = false;
  }

  for (final k in raw.keys.where((k) => !_entryKeys.contains(k))) {
    bad('unknown key "$k"');
  }
  final symbol = raw['symbol'];
  if (symbol is! String ||
      symbol.isEmpty ||
      symbol.trim() != symbol ||
      symbol.contains('\n')) {
    bad(
      '"symbol" must be a non-empty single-line string without '
      'surrounding whitespace',
    );
  }
  final kind = raw['kind'];
  if (!_kinds.contains(kind)) bad('"kind" must be one of ${_kinds.join('|')}');
  final state = raw['state'];
  if (!_states.contains(state)) {
    bad('"state" must be one of ${_states.join('|')}');
  }
  final owner = raw['owner'];
  if (owner is! String || !_ownerPattern.hasMatch(owner)) {
    bad('"owner" must be a Linear story id like DNI-483');
  }
  final match = raw['match'];
  if (match != null && !_matchModes.contains(match)) {
    bad('"match" must be one of ${_matchModes.join('|')}');
  }
  if (raw.containsKey('note') && !_isNonEmptyString(raw['note'])) {
    bad('"note" must be a non-empty string');
  }
  var include = const <String>[];
  var exclude = const <String>[];
  if (raw.containsKey('paths')) {
    final paths = raw['paths'];
    if (paths is! Map<String, Object?> ||
        paths.isEmpty ||
        paths.keys.any((k) => k != 'include' && k != 'exclude')) {
      bad('"paths" must be an object with "include" and/or "exclude"');
    } else {
      final inc = _globList(paths['include'], '$where paths.include', errors);
      final exc = _globList(paths['exclude'], '$where paths.exclude', errors);
      if (inc == null || exc == null) {
        ok = false;
      } else {
        include = inc;
        exclude = exc;
      }
    }
  }
  if (!ok) return null;
  return _Entry(
    group: group,
    symbol: symbol as String,
    kind: kind as String,
    state: state as String,
    owner: owner as String,
    include: include.map(_globToRegExp).toList(),
    exclude: exclude.map(_globToRegExp).toList(),
    stringOnly: match == null ? _stringKinds.contains(kind) : match == 'string',
  );
}

void _loadAllowlist(File file, _Inventory inv) {
  final errors = inv.errors;
  const where = '$_inventoryDir/$_allowlistName';
  final data = _readJson(file, errors);
  if (data == null) return;
  if (data is! Map<String, Object?>) {
    errors.add('$where: top level must be an object');
    return;
  }
  for (final k in data.keys.where((k) => !_allowlistKeys.contains(k))) {
    errors.add('$where: unknown key "$k"');
  }
  final list = data['entries'];
  if (list is! List) {
    errors.add('$where: "entries" must be a list');
    return;
  }
  final seen = <String>{};
  for (var i = 0; i < list.length; i++) {
    final at = '$where entries[$i]';
    final raw = list[i];
    if (raw is! Map<String, Object?>) {
      errors.add('$at: must be an object');
      continue;
    }
    var ok = true;
    void bad(String msg) {
      errors.add('$at: $msg');
      ok = false;
    }

    for (final k in raw.keys.where((k) => !_allowEntryKeys.contains(k))) {
      bad('unknown key "$k"');
    }
    final symbol = raw['symbol'];
    final path = raw['path'];
    final count = raw['count'];
    if (symbol is! String || symbol.isEmpty) {
      bad('"symbol" must be a non-empty string');
    } else if (!inv.entries.any((e) => e.symbol == symbol)) {
      bad('"symbol" "$symbol" is not in any R<n>.json inventory file');
    } else if (!inv.entries.any(_isAllowable(symbol))) {
      bad(
        '"symbol" "$symbol" is not an $_allowGroup "$_allowKind" entry; '
        'AD-49 allowlists only the cutover remnants of the retired '
        'collections (delete every other retired reference instead)',
      );
    }
    if (path is! String || !_allowPaths.contains(path)) {
      bad(
        '"path" must be one of the AD-49 remnant files '
        '(${_allowPaths.join(', ')})',
      );
    }
    if (count is! int || count < 1) bad('"count" must be an integer >= 1');
    if (!_isNonEmptyString(raw['reason'])) {
      bad('"reason" must be a non-empty string');
    }
    final owner = raw['owner'];
    if (owner != null && (owner is! String || !_ownerPattern.hasMatch(owner))) {
      bad('"owner" must be a Linear story id like DNI-490');
    }
    if (!ok) continue;
    final s = symbol as String;
    final p = path as String;
    if (!inv.entries.any((e) => _isAllowable(s)(e) && e.appliesTo(p))) {
      errors.add(
        '$at: no $_allowGroup "$_allowKind" inventory entry for "$s" covers '
        '"$p", so this allowlist entry could never apply',
      );
      continue;
    }
    if (!seen.add('$s\u0000$p')) {
      errors.add('$at: duplicate allowlist entry for "$s" in "$p"');
      continue;
    }
    inv.allow.add(_AllowEntry(s, p, count as int));
  }
}

bool Function(_Entry) _isAllowable(String symbol) =>
    (e) => e.symbol == symbol && e.group == _allowGroup && e.kind == _allowKind;

// ---------------------------------------------------------------------------
// Lexing: classify every character as code, string literal or comment
// ---------------------------------------------------------------------------

const _code = 0;
const _string = 1;
const _comment = 2;

enum _Lang { dart, ts, plain }

bool _isWordUnit(int u) =>
    (u >= 0x30 && u <= 0x39) ||
    (u >= 0x41 && u <= 0x5A) ||
    (u >= 0x61 && u <= 0x7A) ||
    u == 0x5F ||
    u == 0x24;

bool _isIdentStart(int u) => _isWordUnit(u) && !(u >= 0x30 && u <= 0x39);

class _StrCtx {
  _StrCtx(this.quote, {required this.triple, required this.interp});
  final String quote;
  final bool triple;
  final bool interp;
}

/// Code context inside a string interpolation (`${...}`); null entries in
/// the stack below are plain code at top level.
class _InterpCtx {
  int depth = 0;
}

/// Returns per-UTF-16-unit classes for [s]: [_code], [_string] or
/// [_comment]. Dart: nested block comments, raw and triple-quoted strings,
/// `$ident` / `${...}` interpolation (classified as code). TS: template
/// literals with `${...}`. `plain` (rules, JSON): `//` and `/* */`
/// comments, single- and double-quoted strings. An unterminated
/// single-line string ends at the newline so a mis-lex cannot cascade.
Uint8List _classify(String s, _Lang lang) {
  final n = s.length;
  final cls = Uint8List(n);
  final stack = <Object>[]; // _StrCtx or _InterpCtx; empty = top-level code
  var i = 0;
  while (i < n) {
    final top = stack.isEmpty ? null : stack.last;
    final u = s.codeUnitAt(i);
    if (top is _StrCtx) {
      if (top.quote != '`' && !top.triple && u == 0x0A) {
        stack.removeLast(); // unterminated single-line string
        i++;
        continue;
      }
      if (u == 0x5C /* \ */ && (top.interp || lang != _Lang.dart)) {
        cls[i] = _string;
        if (i + 1 < n) cls[i + 1] = _string;
        i += 2;
        continue;
      }
      final closeLen = top.triple ? 3 : 1;
      if (s.startsWith(top.triple ? top.quote * 3 : top.quote, i)) {
        for (var k = 0; k < closeLen; k++) {
          cls[i + k] = _string;
        }
        i += closeLen;
        stack.removeLast();
        continue;
      }
      if (top.interp && u == 0x24 /* $ */ && i + 1 < n) {
        final next = s.codeUnitAt(i + 1);
        if (next == 0x7B /* { */ ) {
          cls[i] = _string;
          cls[i + 1] = _string;
          i += 2;
          stack.add(_InterpCtx());
          continue;
        }
        if (lang == _Lang.dart && _isIdentStart(next) && next != 0x24) {
          cls[i] = _string;
          i++;
          while (i < n &&
              _isWordUnit(s.codeUnitAt(i)) &&
              s.codeUnitAt(i) != 0x24) {
            cls[i] = _code;
            i++;
          }
          continue;
        }
      }
      cls[i] = _string;
      i++;
      continue;
    }

    // Code (top level or inside an interpolation).
    if (s.startsWith('//', i)) {
      while (i < n && s.codeUnitAt(i) != 0x0A) {
        cls[i] = _comment;
        i++;
      }
      continue;
    }
    if (s.startsWith('/*', i)) {
      var depth = 0;
      while (i < n) {
        if (s.startsWith('/*', i)) {
          depth++;
          cls[i] = _comment;
          cls[i + 1] = _comment;
          i += 2;
        } else if (s.startsWith('*/', i)) {
          cls[i] = _comment;
          cls[i + 1] = _comment;
          i += 2;
          // Only Dart nests block comments.
          depth = lang == _Lang.dart ? depth - 1 : 0;
          if (depth == 0) break;
        } else {
          cls[i] = _comment;
          i++;
        }
      }
      continue;
    }
    if (top is _InterpCtx) {
      if (u == 0x7B) {
        top.depth++;
      } else if (u == 0x7D /* } */ ) {
        if (top.depth == 0) {
          cls[i] = _string;
          i++;
          stack.removeLast();
          continue;
        }
        top.depth--;
      }
    }
    final isQuote =
        u == 0x27 || u == 0x22 || (u == 0x60 /* ` */ && lang == _Lang.ts);
    if (isQuote) {
      final q = s[i];
      var raw = false;
      if (lang == _Lang.dart &&
          i > 0 &&
          s.codeUnitAt(i - 1) == 0x72 /* r */ &&
          (i < 2 || !_isWordUnit(s.codeUnitAt(i - 2)))) {
        raw = true;
        cls[i - 1] = _string;
      }
      final triple = lang == _Lang.dart && s.startsWith(q * 3, i);
      final len = triple ? 3 : 1;
      for (var k = 0; k < len; k++) {
        cls[i + k] = _string;
      }
      i += len;
      stack.add(
        _StrCtx(
          q,
          triple: triple,
          interp: (lang == _Lang.dart && !raw) || q == '`',
        ),
      );
      continue;
    }
    cls[i] = _code;
    i++;
  }
  return cls;
}

// ---------------------------------------------------------------------------
// Scanning
// ---------------------------------------------------------------------------

/// A scanned file or directory could not be read. The gate fails closed
/// (exit 2): an unread file could hide a retired symbol.
class _ScanFailure implements Exception {
  _ScanFailure(this.path, this.error);
  final String path;
  final Object error;
}

/// The scan roots AD-49 names. Every one must exist as a real (non-link)
/// directory or file: a missing, mistyped or linked root would make the gate
/// pass without reading the code it guards, so it fails closed instead.
const _scanDirs = {'lib': '.dart', 'functions/src': '.ts'};
const _scanFiles = ['firestore.rules', 'firestore.indexes.json'];

List<String> _scanPaths(String root) {
  final out = <String>[];

  void requireType(String rel, FileSystemEntityType want) {
    final FileSystemEntityType got;
    try {
      got = FileSystemEntity.typeSync('$root/$rel', followLinks: false);
    } on FileSystemException catch (e) {
      throw _ScanFailure(rel, e);
    }
    if (got == want) return;
    final what = want == FileSystemEntityType.directory ? 'directory' : 'file';
    throw _ScanFailure(
      rel,
      got == FileSystemEntityType.notFound
          ? 'required scan root is missing (expected a $what)'
          : got == FileSystemEntityType.link
          ? 'required scan root is a symbolic link (expected a real $what)'
          : 'required scan root is not a $what ($got)',
    );
  }

  _scanDirs.forEach((rel, ext) {
    requireType(rel, FileSystemEntityType.directory);
    final List<FileSystemEntity> listing;
    try {
      // Links are never followed: a followed link can point outside the
      // root, loop, or dangle (and a dangling link would be skipped).
      listing = Directory(
        '$root/$rel',
      ).listSync(recursive: true, followLinks: false);
    } on FileSystemException catch (e) {
      throw _ScanFailure(rel, e);
    }
    for (final f in listing) {
      final p = f.path.replaceAll(r'\', '/');
      final relPath = p.substring(root.length + 1);
      if (f is Link) {
        throw _ScanFailure(
          relPath,
          'symbolic links are not allowed under scanned roots (the gate '
          'cannot vouch for what they point at)',
        );
      }
      if (f is Directory) continue;
      if (f is! File) {
        throw _ScanFailure(relPath, 'unexpected file system entity $f');
      }
      if (p.endsWith(ext)) out.add(relPath);
    }
  });
  for (final f in _scanFiles) {
    requireType(f, FileSystemEntityType.file);
    out.add(f);
  }
  out.sort();
  return out;
}

_Lang _langFor(String path) {
  if (path.endsWith('.dart')) return _Lang.dart;
  if (path.endsWith('.ts')) return _Lang.ts;
  return _Lang.plain;
}

String _boundedPattern(String symbol) {
  final b = StringBuffer();
  if (_isWordUnit(symbol.codeUnitAt(0))) b.write(r'(?<![A-Za-z0-9_$])');
  b.write(RegExp.escape(symbol));
  if (_isWordUnit(symbol.codeUnitAt(symbol.length - 1))) {
    b.write(r'(?![A-Za-z0-9_$])');
  }
  return b.toString();
}

/// Returns hits per entry index.
Map<int, List<_Hit>> _scan(String root, List<_Entry> entries) {
  final hits = <int, List<_Hit>>{};
  // Discover (and validate) the scan roots even with an empty inventory, so
  // a wrong --root or a missing root never passes silently.
  final paths = _scanPaths(root);
  if (entries.isEmpty) return hits;
  final bySymbol = <String, List<int>>{};
  for (var i = 0; i < entries.length; i++) {
    bySymbol.putIfAbsent(entries[i].symbol, () => []).add(i);
  }
  // Single-token symbols can never overlap at one position, so one
  // alternation finds them all; multi-token symbols get their own regex.
  final single =
      bySymbol.keys.where((s) => s.codeUnits.every(_isWordUnit)).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  final multi = bySymbol.keys.where((s) => !single.contains(s)).toList();
  final patterns = <RegExp>[
    if (single.isNotEmpty)
      RegExp(
        r'(?<![A-Za-z0-9_$])(?:' +
            single.map(RegExp.escape).join('|') +
            r')(?![A-Za-z0-9_$])',
      ),
    for (final s in multi) RegExp(_boundedPattern(s)),
  ];

  for (final path in paths) {
    final applicable = <int>[
      for (var i = 0; i < entries.length; i++)
        if (entries[i].appliesTo(path)) i,
    ];
    if (applicable.isEmpty) continue;
    final String content;
    try {
      content = File('$root/$path').readAsStringSync();
    } on FileSystemException catch (e) {
      // Unreadable, undecodable or vanished mid-scan: fail closed.
      throw _ScanFailure(path, e);
    } on FormatException catch (e) {
      throw _ScanFailure(path, e);
    }
    final lang = _langFor(path);
    final codeFile = lang != _Lang.plain;
    Uint8List? cls;
    List<int>? lineStarts;
    for (final re in patterns) {
      for (final m in re.allMatches(content)) {
        cls ??= _classify(content, lang);
        var inComment = false;
        var allString = true;
        for (var k = m.start; k < m.end; k++) {
          if (cls[k] == _comment) inComment = true;
          if (cls[k] != _string) allString = false;
        }
        if (inComment) continue;
        final keyLike = allString && _isKeyLike(content, m.start, m.end);
        final symbol = m[0]!;
        for (final idx in bySymbol[symbol] ?? const <int>[]) {
          final e = entries[idx];
          if (!e.appliesTo(path)) continue;
          if (e.stringOnly && codeFile && !keyLike) continue;
          lineStarts ??= _lineStarts(content);
          final line = _lineOf(lineStarts, m.start);
          final start = lineStarts[line];
          var end = content.indexOf('\n', start);
          if (end < 0) end = content.length;
          var text = content.substring(start, end).trim();
          if (text.length > 160) text = '${text.substring(0, 157)}...';
          hits
              .putIfAbsent(idx, () => [])
              .add(_Hit(path, line + 1, m.start - start + 1, text));
        }
      }
    }
  }
  return hits;
}

/// True when the string-literal text at [start, end) is a whole literal or
/// a `/`-delimited segment of one (a Firestore collection path or a field
/// key), not a word inside prose such as an error message.
bool _isKeyLike(String s, int start, int end) {
  const quotes = {0x27, 0x22, 0x60}; // ' " `
  final before = start > 0 ? s.codeUnitAt(start - 1) : -1;
  final after = end < s.length ? s.codeUnitAt(end) : -1;
  final beforeOk = quotes.contains(before) || before == 0x2F; // /
  final afterOk =
      quotes.contains(after) || after == 0x2F || after == 0x24; // / $
  return beforeOk && afterOk;
}

List<int> _lineStarts(String s) {
  final out = <int>[0];
  for (var i = 0; i < s.length; i++) {
    if (s.codeUnitAt(i) == 0x0A) out.add(i + 1);
  }
  return out;
}

int _lineOf(List<int> starts, int offset) {
  var lo = 0;
  var hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (starts[mid] <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const _usage =
    'Usage: dart run tool/check_retired_symbols.dart '
    '[--enforce] [--report] [--root DIR]';

void main(List<String> args) {
  var enforce = false;
  var report = false;
  var root = '.';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--enforce':
        enforce = true;
      case '--report':
        report = true;
      case '--root':
        if (i + 1 >= args.length) {
          stderr.writeln(_usage);
          exit(2);
        }
        root = args[++i];
      case '--help' || '-h':
        stdout.writeln(_usage);
        return;
      default:
        stderr.writeln('Unknown argument: ${args[i]}\n$_usage');
        exit(2);
    }
  }
  root = Directory(root).absolute.path.replaceAll(r'\', '/');
  while (root.length > 1 && root.endsWith('/')) {
    root = root.substring(0, root.length - 1);
  }
  if (root.endsWith('/.')) root = root.substring(0, root.length - 2);

  final inv = _loadInventory(root);
  if (inv.errors.isNotEmpty) {
    stderr.writeln(
      'Retired-symbols check FAILED (AD-49): malformed retired-symbol '
      'inventory/allowlist under $_inventoryDir/ — ${inv.errors.length} '
      'error(s):',
    );
    for (final e in inv.errors) {
      stderr.writeln('  $e');
    }
    exit(2);
  }

  final entries = inv.entries;
  final Map<int, List<_Hit>> hits;
  try {
    hits = _scan(root, entries);
  } on _ScanFailure catch (f) {
    stderr.writeln(
      'Retired-symbols check FAILED (AD-49): could not read ${f.path} '
      '(the gate fails closed on any unread file or scan root): ${f.error}',
    );
    exit(2);
  }
  bool isRetired(_Entry e) => enforce || e.state == 'retired';

  // Retired hits per symbol, then per path (deduplicated across entries
  // whose scopes overlap).
  final retiredHits = <String, Map<String, Map<String, _Hit>>>{};
  for (var i = 0; i < entries.length; i++) {
    if (!isRetired(entries[i])) continue;
    for (final h in hits[i] ?? const <_Hit>[]) {
      retiredHits
              .putIfAbsent(entries[i].symbol, () => {})
              .putIfAbsent(h.path, () => {})[h.key] =
          h;
    }
  }
  final allowed = {for (final a in inv.allow) '${a.symbol}\u0000${a.path}': a};

  final violations = <String>[];
  final usedAllow = <String>{};
  final symbols = retiredHits.keys.toList()..sort();
  for (final symbol in symbols) {
    final byPath = retiredHits[symbol]!;
    final paths = byPath.keys.toList()..sort();
    for (final path in paths) {
      final found = byPath[path]!.values.toList()
        ..sort(
          (a, b) => a.line != b.line
              ? a.line.compareTo(b.line)
              : a.column.compareTo(b.column),
        );
      final key = '$symbol\u0000$path';
      final allow = allowed[key];
      if (allow != null) usedAllow.add(key);
      final permitted = allow?.count ?? 0;
      if (found.length > permitted) {
        violations.add(
          '"$symbol" — ${found.length} hit(s) in $path, '
          '$permitted allowlisted:',
        );
        violations.addAll(found.map((h) => '    $h'));
      } else if (found.length < permitted && enforce) {
        violations.add(
          'allowlist not exact: "$symbol" in $path allows $permitted, '
          'found ${found.length}',
        );
      }
    }
  }
  final stale = [
    for (final a in inv.allow)
      if (!usedAllow.contains('${a.symbol}\u0000${a.path}'))
        'allowlist entry "${a.symbol}" in ${a.path} (count ${a.count}) matches no retired hit',
  ];
  if (enforce) violations.addAll(stale);

  // Pending report (counts only unless --report).
  final groups = <String, List<int>>{};
  for (var i = 0; i < entries.length; i++) {
    groups.putIfAbsent(entries[i].group, () => []).add(i);
  }
  final out = StringBuffer()
    ..writeln(
      'Retired-symbols gate (AD-49)${enforce ? ' --enforce' : ''}: '
      '${entries.length} inventory entr${entries.length == 1 ? 'y' : 'ies'}, '
      '${inv.allow.length} allowlist entr'
      '${inv.allow.length == 1 ? 'y' : 'ies'}.',
    );
  for (var n = 1; n <= _groupCount; n++) {
    final g = 'R$n';
    final idxs = groups[g] ?? const <int>[];
    final retired = idxs.where((i) => entries[i].state == 'retired').length;
    final pendingIdx = idxs.where((i) => entries[i].state == 'pending');
    final pendingHits = pendingIdx.fold<int>(
      0,
      (sum, i) => sum + (hits[i]?.length ?? 0),
    );
    out.writeln(
      '  $g: ${idxs.length - retired} pending '
      '($pendingHits hit(s), reported only), $retired retired',
    );
    if (report) {
      for (final i in idxs) {
        final e = entries[i];
        final list = hits[i] ?? const <_Hit>[];
        out.writeln(
          '    [${e.state}] ${e.symbol} (${e.kind}, ${e.owner}): '
          '${list.length} hit(s)',
        );
        for (final h in list) {
          out.writeln('      $h');
        }
      }
    }
  }
  if (!enforce && stale.isNotEmpty) {
    out.writeln(
      '  WARNING: stale allowlist entr'
      '${stale.length == 1 ? 'y' : 'ies'} (fails under --enforce):',
    );
    for (final s in stale) {
      out.writeln('    $s');
    }
  }
  stdout.write(out);

  if (violations.isNotEmpty) {
    stderr.writeln(
      'Retired-symbols check FAILED (AD-49): retired symbols remain outside '
      'tool/retired_symbols/$_allowlistName. Delete the remaining '
      'references (or, for the AD-49 cutover remnants only, allowlist the '
      'exact count):',
    );
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }
  stdout.writeln('Retired-symbols check OK (AD-49).');
}
