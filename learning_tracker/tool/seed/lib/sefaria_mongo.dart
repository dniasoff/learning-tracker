// ignore_for_file: avoid_print
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:mongo_dart/mongo_dart.dart';

/// Resolves Sefaria refs → cleaned (he, en) text directly from a local Sefaria
/// MongoDB (the mongodump restored into the Dockerized `sefaria` database).
///
/// Reimplements the slice of Sefaria's `Ref`/`TextChunk` model the seed needs:
///   - Title matching: longest `index.title` that prefixes the ref.
///   - Schema walking: descend SchemaNode children by title; `default` nodes
///     are entered without consuming a title segment.
///   - Address parsing: per terminal JaggedArrayNode `addressTypes`. Every
///     address type used by our 15 curricula is integer-style (section N →
///     array index N-1) EXCEPT `Talmud` (daf 2a→0, 2b→1, 3a→2, …).
///   - Version selection: among versions of the requested `language`, sort by
///     `[priority desc, _id asc]` and MERGE segment-wise (first non-empty),
///     mirroring Sefaria's default `VersionSet` + `merge_texts`.
///   - Ranges (`a-b`, cross-section/cross-segment) are flattened and joined.
///   - All text routed through [HebrewUtils.cleanSefariaText] (BUG-5 footnotes).

/// A parsed schema node (subset of Sefaria's index schema).
class SchemaNode {
  SchemaNode({
    required this.key,
    required this.nodeType,
    required this.enTitles,
    required this.addressTypes,
    required this.children,
  });

  final String key; // storage key in the texts `chapter` dict
  final String nodeType; // 'JaggedArrayNode' | 'SchemaNode'
  final List<String> enTitles; // English titles that can address this node
  final List<String> addressTypes; // for JaggedArrayNode
  final List<SchemaNode> children; // for SchemaNode

  bool get isLeaf => nodeType == 'JaggedArrayNode';
  bool get isDefault => key == 'default';
}

/// A book's index: root title + schema tree.
class BookIndex {
  BookIndex({required this.title, required this.root});
  final String title;
  final SchemaNode root;
}

/// Cached, version-priority-sorted text payload for one (title, language).
class _MergedVersion {
  _MergedVersion(this.versions);
  // Each entry is the `chapter` payload (List or Map) of one version, in
  // priority order (highest first).
  final List<dynamic> versions;
}

class SefariaMongo {
  SefariaMongo(this._db);
  final Db _db;

  late final DbCollection _texts = _db.collection('texts');
  late final DbCollection _index = _db.collection('index');

  /// title → BookIndex (lazy).
  final Map<String, BookIndex> _indexCache = {};

  /// Sorted list of all index titles, longest first (for prefix matching).
  List<String>? _titlesByLength;

  /// (title|lang) → priority-ordered list of `chapter` payloads.
  final Map<String, _MergedVersion> _versionCache = {};

  static Future<SefariaMongo> connect(String uri) async {
    final db = await Db.create(uri);
    await db.open();
    return SefariaMongo(db);
  }

  Future<void> close() => _db.close();

  /// English title VARIANT → canonical `index.title`. A book may be addressed
  /// by any of its `schema.titles` en variants (e.g. "Mishnah Taanit" →
  /// "Mishnah Ta'anit"); texts are stored under the canonical title.
  final Map<String, String> _titleVariantToCanonical = {};

  /// Load all index title variants once, sorted by descending length for
  /// greedy longest-prefix matching.
  Future<void> warmTitles() async {
    if (_titlesByLength != null) return;
    final docs = await _index
        .modernFind(projection: {'title': 1, 'schema.titles': 1})
        .toList();
    for (final d in docs) {
      final canonical = d['title'] as String?;
      if (canonical == null) continue;
      _titleVariantToCanonical[canonical] = canonical;
      final schema = d['schema'] as Map<String, dynamic>?;
      final titles = schema?['titles'] as List<dynamic>?;
      if (titles != null) {
        for (final t in titles) {
          final m = t as Map<String, dynamic>;
          if (m['lang'] == 'en') {
            final text = m['text'] as String?;
            if (text != null && text.isNotEmpty) {
              // First writer wins on collision (canonical added first).
              _titleVariantToCanonical.putIfAbsent(text, () => canonical);
            }
          }
        }
      }
    }
    final list = _titleVariantToCanonical.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _titlesByLength = list;
    print(
      '[mongo] loaded ${_titleVariantToCanonical.length} title variants '
      '(${docs.length} indexes)',
    );
  }

  /// Resolve cleaned Hebrew + English for [ref]. Empty strings where absent.
  Future<({String he, String en})> resolve(String ref) async {
    final he = await _resolveLang(ref, 'he');
    final en = await _resolveLang(ref, 'en');
    return (
      he: HebrewUtils.cleanSefariaText(he).trim(),
      en: HebrewUtils.cleanSefariaText(en).trim(),
    );
  }

  /// Debug helper: expose the parsed book/nodePath/address for a ref.
  Future<String> debugParse(String ref) async {
    final p = await _parse(ref);
    if (p == null) return 'PARSE FAILED';
    return 'book="${p.bookTitle}" nodePath=${p.nodePath} '
        'addr=${p.addressTypes} start=${p.start} end=${p.end}';
  }

  Future<String> _resolveLang(String ref, String lang) async {
    final parsed = await _parse(ref);
    if (parsed == null) return '';
    final merged = await _mergedVersions(parsed.bookTitle, lang);
    if (merged.versions.isEmpty) return '';

    // Navigate each version to the node payload (schema path), then collect
    // the addressed text, merging across versions segment-wise.
    final perVersionNodes = <dynamic>[];
    for (final chapter in merged.versions) {
      perVersionNodes.add(_navigateNodePath(chapter, parsed.nodePath));
    }
    // Now apply the numeric address (+ optional range) on the node arrays,
    // merging across versions.
    final collected = collectAddressed(
      perVersionNodes,
      start: parsed.start,
      end: parsed.end,
      addressTypes: parsed.addressTypes,
    );
    return collected;
  }

  // ── Version selection + merge ─────────────────────────────────────────────

  Future<_MergedVersion> _mergedVersions(String title, String lang) async {
    final ck = '$title|$lang';
    final cached = _versionCache[ck];
    if (cached != null) return cached;
    final docs = await _texts
        .modernFind(
          filter: {'title': title, 'language': lang},
          sort: {'priority': -1, '_id': 1},
          projection: {'chapter': 1},
        )
        .toList();
    final mv = _MergedVersion([for (final d in docs) d['chapter']]);
    _versionCache[ck] = mv;
    return mv;
  }

  // ── Ref parsing ───────────────────────────────────────────────────────────

  Future<_ParsedRef?> _parse(String ref) async {
    await warmTitles();
    // Longest index title that is a prefix of the ref (followed by end,
    // space, or comma).
    String? book;
    for (final t in _titlesByLength!) {
      if (ref == t) {
        book = t;
        break;
      }
      if (ref.startsWith(t)) {
        final next = ref[t.length];
        if (next == ' ' || next == ',' || next == ':' || next == '.') {
          book = t;
          break;
        }
      }
    }
    if (book == null) return null;
    // `book` is the matched (possibly variant) title; texts + index are keyed
    // by the canonical title.
    final canonical = _titleVariantToCanonical[book] ?? book;
    final idx = await _loadIndex(canonical);
    if (idx == null) return null;

    var rest = ref.substring(book.length).trim();
    // Walk the schema until a leaf. Child node titles may themselves contain
    // commas ("Part One, The Prohibition Against Lashon Hara") and/or end in a
    // number ("Principle 10"), so match each child's en-title as a LONGEST
    // PREFIX of the remaining string (same strategy as book-title matching) —
    // never split on commas/digits.
    final nodePath = <String>[];
    var node = idx.root;
    while (!node.isLeaf) {
      // Drop any leading separator between titles (comma/space) or between a
      // title and the numeric address (URL-derived refs use '.').
      rest = rest.replaceFirst(RegExp(r'^[,\s.]+'), '');

      final childMatch = matchChild(node, rest);

      if (childMatch != null) {
        nodePath.add(childMatch.node.key);
        rest = rest.substring(childMatch.matchedLength).trim();
        node = childMatch.node;
      } else {
        // No titled child matched → enter the `default` child (addressing
        // applies directly), else a sole child, else give up.
        final def = node.children.where((c) => c.isDefault).firstOrNull;
        if (def != null) {
          nodePath.add(def.key);
          node = def;
        } else if (node.children.length == 1) {
          node = node.children.first;
          nodePath.add(node.key);
        } else {
          return null;
        }
      }
    }

    // `rest` now holds the numeric address (e.g. "199:2-11", "12:18", "2a",
    // "60", "199:2-200:3"). Strip any leading separator left by the node-title
    // match (URL-derived refs put a '.' between title and address).
    rest = rest.replaceFirst(RegExp(r'^[,\s.:]+'), '');
    final addr = _parseAddress(rest, node.addressTypes);
    if (addr == null) return null;
    return _ParsedRef(
      bookTitle: canonical,
      nodePath: nodePath,
      addressTypes: node.addressTypes,
      start: addr.start,
      end: addr.end,
    );
  }

  /// True if [title] is a prefix of [rest] followed by a boundary, so
  /// "Principle 1" does NOT match "Principle 10 …". Boundaries: end-of-string,
  /// space, comma, or the address separators '.'/':' (URL-derived refs use
  /// dots, e.g. "Arukh HaShulchan, Yoreh De'ah.201.68-74").
  static bool _prefixWithBoundary(String rest, String title) {
    if (!rest.startsWith(title)) return false;
    if (rest.length == title.length) return true;
    final next = rest[title.length];
    return next == ' ' || next == ',' || next == '.' || next == ':';
  }

  /// Find the child of [node] whose title is the LONGEST prefix of [rest]
  /// (matched with a boundary — see [_prefixWithBoundary]), trying each
  /// child's en-titles then its `key` as a fallback candidate. Child titles
  /// may themselves contain commas (e.g. "Part One, The Prohibition Against
  /// Lashon Hara") and/or end in a number (e.g. "Principle 10"), so this
  /// never splits on commas/digits — only longest-prefix-with-boundary
  /// matching disambiguates "Principle 1" from "Principle 10 …".
  ///
  /// Returns `null` when no child title prefixes [rest].
  ///
  /// Extracted out of [_parse]'s schema-walk loop and made `static` +
  /// `@visibleForTesting` so the longest-prefix matching rule can be unit
  /// tested directly against an in-memory [SchemaNode] fixture, without a
  /// live Mongo connection (AUD-guardrails-04).
  @visibleForTesting
  static ({SchemaNode node, int matchedLength})? matchChild(
    SchemaNode node,
    String rest,
  ) {
    SchemaNode? matched;
    var matchedLen = -1;
    for (final c in node.children) {
      if (c.isDefault) continue;
      // Candidate titles: the en-titles, plus the node `key` as a fallback
      // (some nodes — e.g. Arukh HaShulchan "Introduction" — carry no
      // explicit title, only a key that the ref uses verbatim).
      final candidates = [...c.enTitles, c.key];
      for (final t in candidates) {
        if (t.isEmpty) continue;
        if (rest == t || _prefixWithBoundary(rest, t)) {
          if (t.length > matchedLen) {
            matched = c;
            matchedLen = t.length;
          }
        }
      }
    }
    if (matched == null) return null;
    return (node: matched, matchedLength: matchedLen);
  }

  // ── Address parsing ───────────────────────────────────────────────────────

  /// Parse a numeric address like "199:2", "12:18-20", "2a", "60",
  /// "199:2-200:3" into 0-based start/end index lists per [addressTypes].
  _Address? _parseAddress(String s, List<String> addressTypes) {
    s = s.trim();
    if (s.isEmpty) {
      // Whole-node ref (depth handled by collector returning all).
      return _Address(start: const [], end: null);
    }
    // Range: split on the LAST '-' that separates two address tuples.
    // Forms: "A-B" where A,B are ":"-separated. Also single "A".
    final dash = s.indexOf('-');
    String startStr;
    String? endStr;
    if (dash >= 0) {
      startStr = s.substring(0, dash).trim();
      endStr = s.substring(dash + 1).trim();
    } else {
      startStr = s;
      endStr = null;
    }
    final start = _parseTuple(startStr, addressTypes);
    if (start == null) return null;
    List<int>? end;
    if (endStr != null) {
      end = _parseTuple(endStr, addressTypes, partialOf: start);
    }
    return _Address(start: start, end: end);
  }

  /// Parse one ":"-separated address tuple to 0-based indices.
  /// [partialOf] supplies leading components for a short range end like
  /// "12:18-20" (end "20" means same section, segment 20).
  List<int>? _parseTuple(
    String s,
    List<String> addressTypes, {
    List<int>? partialOf,
  }) {
    // Address components can be ':' or '.' separated.
    final parts = s.split(RegExp('[:.]')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final out = <int>[];
    // If this is a short range-end (fewer parts than addressTypes and we have
    // a partial), left-pad from partialOf.
    final offset = (partialOf != null && parts.length < addressTypes.length)
        ? addressTypes.length - parts.length
        : 0;
    for (var i = 0; i < offset; i++) {
      out.add(partialOf![i]);
    }
    for (var i = 0; i < parts.length; i++) {
      final at = addressTypes[(offset + i).clamp(0, addressTypes.length - 1)];
      final idx = addressToIndex(parts[i].trim(), at);
      if (idx == null) return null;
      out.add(idx);
    }
    return out;
  }

  /// Convert a single address token to a 0-based array index for [addressType].
  ///
  /// `static` + `@visibleForTesting` (AUD-guardrails-04) so the Talmud
  /// daf→index formula — the arithmetic a silent regression would most
  /// dangerously slip through, per the finding — can be unit tested directly
  /// with no live Mongo connection.
  @visibleForTesting
  static int? addressToIndex(String token, String addressType) {
    if (addressType == 'Talmud') {
      // Sefaria stores Talmud with daf 1a at chapter index 0, so amud index =
      // (daf-1)*2 + amud  →  2a→2, 2b→3, 3a→4 … (1a/1b slots 0/1 are empty
      // because tractates begin at 2a).
      final m = RegExp(r'^(\d+)([ab])$').firstMatch(token);
      if (m != null) {
        final daf = int.parse(m.group(1)!);
        final amud = m.group(2) == 'a' ? 0 : 1;
        return (daf - 1) * 2 + amud;
      }
      // Bare daf number → amud a.
      final n = int.tryParse(token);
      if (n != null) return (n - 1) * 2;
      return null;
    }
    // All other address types (Integer, Perek, Pasuk, Halakhah, Mishnah,
    // Siman, Seif, SeifKatan) are 1-based integers.
    final n = int.tryParse(token);
    if (n == null) return null;
    return n - 1;
  }

  // ── Navigation + collection ────────────────────────────────────────────────

  /// Walk the schema node-path (dict keys) into a version's `chapter` payload,
  /// returning the JaggedArray for the addressed leaf node (or null).
  dynamic _navigateNodePath(dynamic chapter, List<String> nodePath) {
    dynamic cur = chapter;
    for (final key in nodePath) {
      if (cur is Map) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// Apply the numeric address (with optional range) to the per-version node
  /// arrays, merging across versions segment-wise, and join to a single
  /// string. [start]/[end]/[addressTypes] are the fields of a parsed ref's
  /// address (an empty [start] means "whole node"; a null [end] means a
  /// single address, not a range).
  ///
  /// `static` + `@visibleForTesting` (AUD-guardrails-04) so multi-section
  /// range flattening and version-priority merge-first-non-empty can be
  /// unit tested directly against in-memory fixture node arrays, with no
  /// live Mongo connection.
  @visibleForTesting
  static String collectAddressed(
    List<dynamic> perVersionNodes, {
    required List<int> start,
    required List<int>? end,
    required List<String> addressTypes,
  }) {
    // Build the list of leaf "cells" (strings) to emit, in order. For a single
    // address we emit one cell; for a range we emit the inclusive span.
    // Strategy: enumerate the flat index path(s) and, for each, take the first
    // non-empty value across versions (priority-merged).

    // Helper: fetch a value at a multi-index path from a node array.
    dynamic at(dynamic node, List<int> path) {
      dynamic cur = node;
      for (final i in path) {
        if (cur is List && i >= 0 && i < cur.length) {
          cur = cur[i];
        } else {
          return null;
        }
      }
      return cur;
    }

    String mergedAt(List<int> path) {
      for (final node in perVersionNodes) {
        if (node == null) continue;
        final v = at(node, path);
        final s = _flatten(v);
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final depth = addressTypes.length;

    // Whole-node (no address) → flatten the whole first non-empty version.
    if (start.isEmpty) {
      for (final node in perVersionNodes) {
        final s = _flatten(node);
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    if (end == null) {
      // Single address. If it points above the leaf depth (e.g. a whole
      // chapter), flatten that subtree.
      return mergedAt(start);
    }

    // Range. Enumerate inclusive cells from start..end.
    final cells = <String>[];
    if (depth == 1 || start.length == 1) {
      for (var i = start[0]; i <= (end.isNotEmpty ? end[0] : start[0]); i++) {
        cells.add(mergedAt([i]));
      }
    } else {
      // depth >= 2. Enumerate section-by-section.
      final s0 = start[0];
      final e0 = end[0];
      for (var sec = s0; sec <= e0; sec++) {
        // Determine segment span within this section.
        final segStart = (sec == s0) ? (start.length > 1 ? start[1] : 0) : 0;
        // Upper bound: if last section, use end's segment; else to end of row.
        int segEnd;
        if (sec == e0 && end.length > 1) {
          segEnd = end[1];
        } else {
          // Find row length from the first version that has this section.
          segEnd = _rowLen(perVersionNodes, sec) - 1;
        }
        for (var seg = segStart; seg <= segEnd; seg++) {
          cells.add(mergedAt([sec, seg]));
        }
      }
    }
    return cells.where((c) => c.isNotEmpty).join('\n');
  }

  static int _rowLen(List<dynamic> perVersionNodes, int sec) {
    for (final node in perVersionNodes) {
      if (node is List && sec >= 0 && sec < node.length) {
        final row = node[sec];
        if (row is List) return row.length;
      }
    }
    return 0;
  }

  /// Flatten a possibly-nested text payload to a single newline-joined string.
  static String _flatten(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is List) {
      return v.map(_flatten).where((s) => s.isNotEmpty).join('\n');
    }
    return '';
  }

  // ── Index loading + schema parsing ──────────────────────────────────────────

  Future<BookIndex?> _loadIndex(String title) async {
    final cached = _indexCache[title];
    if (cached != null) return cached;
    final doc = await _index.findOne(where.eq('title', title));
    if (doc == null) return null;
    final schema = doc['schema'] as Map<String, dynamic>?;
    if (schema == null) return null;
    final root = _parseSchemaNode(schema);
    final bi = BookIndex(title: title, root: root);
    _indexCache[title] = bi;
    return bi;
  }

  SchemaNode _parseSchemaNode(Map<String, dynamic> node) {
    final nodeType = node['nodeType'] as String? ?? 'JaggedArrayNode';
    final key = (node['key'] as String?) ?? 'default';
    final enTitles = <String>[];
    final titles = node['titles'] as List<dynamic>?;
    if (titles != null) {
      for (final t in titles) {
        final m = t as Map<String, dynamic>;
        if (m['lang'] == 'en') enTitles.add(m['text'] as String);
      }
    }
    final children = <SchemaNode>[];
    final nodes = node['nodes'] as List<dynamic>?;
    if (nodes != null) {
      for (final n in nodes) {
        children.add(_parseSchemaNode(n as Map<String, dynamic>));
      }
    }
    final addr =
        (node['addressTypes'] as List<dynamic>?)?.cast<String>() ?? const [];
    return SchemaNode(
      key: key,
      nodeType: children.isNotEmpty ? 'SchemaNode' : nodeType,
      enTitles: enTitles,
      addressTypes: addr,
      children: children,
    );
  }
}

class _ParsedRef {
  _ParsedRef({
    required this.bookTitle,
    required this.nodePath,
    required this.addressTypes,
    required this.start,
    required this.end,
  });
  final String bookTitle;
  final List<String> nodePath;
  final List<String> addressTypes;
  final List<int> start;
  final List<int>? end;
}

class _Address {
  _Address({required this.start, required this.end});
  final List<int> start;
  final List<int>? end;
}
