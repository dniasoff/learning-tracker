/// Domain service for resolving Sefaria reference strings.
///
/// Contains all fuzzy-matching and regex expansion logic used to map
/// calendar-program `todayRef` values to canonical content-item
/// `sefariaRef` strings. Extracted from `scheduler_providers.dart` — no
/// logic changes.
library;

import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Resolves [todayRef] (from a calendar program entry) to a set of canonical
/// leaf [sefariaRef] strings found in [contentItems].
///
/// Returns the resolved set when at least one match is found.
/// Falls back to [_displayProgramRef] when no content match exists.
Set<String> resolveProgramTodayRefs(
  String todayRef,
  List<ContentItem> contentItems,
) {
  final leafRefs = contentItems
      .where((item) => item.isLeaf)
      .map((item) => item.sefariaRef)
      .whereType<String>()
      .toList();
  if (leafRefs.isEmpty) return const {};

  final normalizedLeaf = <String, String>{
    for (final ref in leafRefs) normalizeRef(ref): ref,
  };

  final candidates = <String>{
    ...refVariants(todayRef),
    ...expandSimpleRange(todayRef),
    ...expandDafLikeRange(todayRef),
    for (final variant in refVariants(todayRef)) ...expandSimpleRange(variant),
    for (final variant in refVariants(todayRef)) ...expandDafLikeRange(variant),
  };

  final matches = <String>{};
  for (final candidate in candidates) {
    final resolved = normalizedLeaf[normalizeRef(candidate)];
    if (resolved != null) {
      matches.add(resolved);
    }
  }

  if (matches.isNotEmpty) return matches;

  // Fallback: calendar entry may point at a non-leaf unit (e.g. full daf),
  // while track content is leaf-only (e.g. amud a/b). Expand to leaf children.
  for (final candidate in candidates) {
    final expanded = resolveLeafRefsFromContainer(candidate, contentItems);
    if (expanded.isNotEmpty) {
      matches.addAll(expanded);
      continue;
    }

    final indexed = resolveIndexedUnitRefs(candidate, contentItems);
    if (indexed.isNotEmpty) {
      matches.addAll(indexed);
    }
  }
  return matches;
}

/// Resolves [todayRef] to canonical refs, or returns a display-safe fallback
/// when no content match can be found.
Set<String> resolvedOrFallbackProgramRefs({
  required String todayRef,
  required List<ContentItem> contentItems,
}) {
  final resolved = resolveProgramTodayRefs(todayRef, contentItems);
  if (resolved.isNotEmpty) return resolved;

  final fallback = displayProgramRef(todayRef);
  if (fallback.isEmpty) return const {};
  return {fallback};
}

/// Returns a human-readable form of a raw program ref (underscores → spaces).
String displayProgramRef(String ref) {
  return ref.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Expands a Sefaria reference into spelling/prefix variants.
///
/// Handles common transliteration differences (e.g. "midos" → "middot",
/// "mishnayos" → "mishnah") and optional "Mishnah " / "Jerusalem Talmud "
/// prefixes that may or may not appear in calendar feeds versus content trees.
Set<String> refVariants(String ref) {
  final trimmed = ref.replaceAll('–', '-').trim();
  if (trimmed.isEmpty) return const {};

  final variants = <String>{trimmed};
  final lower = trimmed.toLowerCase();

  // Common transliteration variants seen in calendar feeds vs content trees.
  final aliasMap = <String, String>{
    'midos': 'middot',
    'mishnayos': 'mishnah',
    'mishna ': 'mishnah ',
  };
  var replacedLower = lower;
  aliasMap.forEach((from, to) {
    replacedLower = replacedLower.replaceAll(from, to);
  });
  if (replacedLower != lower) {
    variants.add(matchOriginalCasing(trimmed, replacedLower));
  }

  if (lower.startsWith('mishnah ')) {
    variants.add(trimmed.substring('mishnah '.length).trim());
  } else {
    variants.add('Mishnah $trimmed');
  }

  if (lower.startsWith('jerusalem talmud ')) {
    variants.add(trimmed.substring('jerusalem talmud '.length).trim());
  } else {
    variants.add('Jerusalem Talmud $trimmed');
  }

  return variants
      .where((v) => v.trim().isNotEmpty)
      .map((v) => v.trim())
      .toSet();
}

/// Re-applies the capitalisation style of [original] to [lowerValue].
String matchOriginalCasing(String original, String lowerValue) {
  if (original == original.toUpperCase()) return lowerValue.toUpperCase();
  if (original == original.toLowerCase()) return lowerValue;
  return lowerValue
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

/// Normalises a Sefaria ref to a canonical lower-case, punctuation-stripped
/// form for fuzzy comparison.
String normalizeRef(String ref) {
  return ref
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(':', '.')
      .replaceAll(RegExp(r'[^a-z0-9.\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Expands a simple verse-range ref of the form `<title> N.M-P` into
/// individual `<title> N.M` … `<title> N.P` refs.
Set<String> expandSimpleRange(String ref) {
  final normalized = ref.replaceAll('–', '-').trim();
  final match = RegExp(
    r'^(.*?)(\d+)[\.:](\d+)\s*-\s*(\d+)$',
  ).firstMatch(normalized);
  if (match == null) return const {};

  final base = match.group(1)?.trim() ?? '';
  final chapter = int.tryParse(match.group(2) ?? '');
  final from = int.tryParse(match.group(3) ?? '');
  final to = int.tryParse(match.group(4) ?? '');
  if (chapter == null || from == null || to == null || to < from)
    return const {};

  final expanded = <String>{};
  for (var section = from; section <= to; section++) {
    expanded.add('$base $chapter.$section'.trim());
    expanded.add('$base $chapter:$section'.trim());
  }
  return expanded;
}

/// Expands a daf-style range ref of the form `<title> Na-Mb` into individual
/// amud refs, respecting optional a/b side suffixes on the endpoints.
Set<String> expandDafLikeRange(String ref) {
  final normalized = ref.replaceAll('–', '-').trim();
  final match = RegExp(
    r'^(.*?)(\d+)([ab])?\s*-\s*(\d+)([ab])?$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) return const {};

  final base = match.group(1)?.trim() ?? '';
  final fromPage = int.tryParse(match.group(2) ?? '');
  final fromSide = (match.group(3) ?? '').toLowerCase();
  final toPage = int.tryParse(match.group(4) ?? '');
  final toSide = (match.group(5) ?? '').toLowerCase();
  if (fromPage == null || toPage == null || toPage < fromPage) return const {};

  final expanded = <String>{};
  for (var page = fromPage; page <= toPage; page++) {
    if (fromSide.isNotEmpty || toSide.isNotEmpty) {
      expanded.add('$base ${page}a'.trim());
      expanded.add('$base ${page}b'.trim());
      continue;
    }
    expanded.add('$base $page'.trim());
  }

  // If specific boundary sides are provided, trim out impossible endpoints.
  if (fromSide == 'b') {
    expanded.remove('$base ${fromPage}a'.trim());
  }
  if (toSide == 'a') {
    expanded.remove('$base ${toPage}b'.trim());
  }
  return expanded;
}

/// Resolves [candidate] to the leaf children of the matching container node
/// (if any) in [contentItems].
///
/// First tries an exact normalised match; falls back to fuzzy matching via
/// [findFuzzyContainerMatch].
Set<String> resolveLeafRefsFromContainer(
  String candidate,
  List<ContentItem> contentItems,
) {
  final normalizedCandidate = normalizeRef(candidate);
  if (normalizedCandidate.isEmpty) return const {};

  final exactContainer = contentItems.firstWhere(
    (item) => normalizeRef(item.sefariaRef) == normalizedCandidate,
    orElse: () => const ContentItem(
      curriculumId: '',
      level1: '',
      displayNameHe: '',
      displayNameEn: '',
      sefariaRef: '',
      sortOrder: 0,
      isLeaf: true,
    ),
  );

  if (exactContainer.sefariaRef.isNotEmpty && !exactContainer.isLeaf) {
    return leafChildrenForContainer(exactContainer, contentItems);
  }

  final fuzzyContainer = findFuzzyContainerMatch(candidate, contentItems);
  if (fuzzyContainer == null) return const {};
  return leafChildrenForContainer(fuzzyContainer, contentItems);
}

/// Resolves [candidate] as an ordinal index into the leaf children of a
/// container unit.
///
/// Currently handles Yerushalmi cycle entries of the form
/// `"Jerusalem Talmud <masechta> <ordinal>"` where the ordinal picks the
/// Nth leaf in sort order.
Set<String> resolveIndexedUnitRefs(
  String candidate,
  List<ContentItem> contentItems,
) {
  final parsed = parseRefTail(candidate);
  if (parsed == null) return const {};

  final rawTitle = parsed.$1.trim();
  final address = parsed.$2.trim().toLowerCase();
  final index = int.tryParse(address);
  if (index == null || index <= 0) return const {};

  // Yerushalmi cycle entries are often "Jerusalem Talmud <masechta> <ordinal>"
  // where ordinal indexes through units, not chapter number.
  if (!normalizeRef(rawTitle).startsWith('jerusalem talmud ')) return const {};

  final topContainer = contentItems.firstWhere(
    (item) =>
        !item.isLeaf && normalizeRef(item.sefariaRef) == normalizeRef(rawTitle),
    orElse: () => const ContentItem(
      curriculumId: '',
      level1: '',
      displayNameHe: '',
      displayNameEn: '',
      sefariaRef: '',
      sortOrder: 0,
      isLeaf: true,
    ),
  );
  if (topContainer.sefariaRef.isEmpty) return const {};

  final leaves = leafChildrenForContainer(topContainer, contentItems).toList()
    ..sort((a, b) {
      final aOrder = contentItems
          .firstWhere(
            (i) => i.sefariaRef == a,
            orElse: () => const ContentItem(
              curriculumId: '',
              level1: '',
              displayNameHe: '',
              displayNameEn: '',
              sefariaRef: '',
              sortOrder: 0,
              isLeaf: true,
            ),
          )
          .sortOrder;
      final bOrder = contentItems
          .firstWhere(
            (i) => i.sefariaRef == b,
            orElse: () => const ContentItem(
              curriculumId: '',
              level1: '',
              displayNameHe: '',
              displayNameEn: '',
              sefariaRef: '',
              sortOrder: 0,
              isLeaf: true,
            ),
          )
          .sortOrder;
      return aOrder.compareTo(bOrder);
    });
  if (leaves.isEmpty || index > leaves.length) return const {};

  return {leaves[index - 1]};
}

/// Returns the leaf-node [sefariaRef] values that are children of [container]
/// in [contentItems], sorted by [ContentItem.sortOrder].
Set<String> leafChildrenForContainer(
  ContentItem container,
  List<ContentItem> contentItems,
) {
  final leaves = contentItems.where((item) {
    if (!item.isLeaf) return false;
    if (item.level1 != container.level1) return false;
    if (container.level2 != null && item.level2 != container.level2)
      return false;
    if (container.level3 != null && item.level3 != container.level3)
      return false;
    if (container.level4 != null && item.level4 != container.level4)
      return false;
    return true;
  }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return leaves.map((leaf) => leaf.sefariaRef).toSet();
}

/// Finds the best-matching non-leaf [ContentItem] for [candidate] using fuzzy
/// title similarity scoring (minimum score: 2).
///
/// Returns `null` when no container meets the threshold.
ContentItem? findFuzzyContainerMatch(
  String candidate,
  List<ContentItem> contentItems,
) {
  final parsed = parseRefTail(candidate);
  if (parsed == null) return null;
  final title = parsed.$1;
  final address = parsed.$2;
  if (title.isEmpty || address.isEmpty) return null;

  final normalizedTitle = normalizeTitle(title);
  final possibleContainers = contentItems
      .where((item) => !item.isLeaf)
      .toList();
  ContentItem? best;
  var bestScore = -1;

  for (final item in possibleContainers) {
    final parsedItem = parseRefTail(item.sefariaRef);
    if (parsedItem == null) continue;
    final itemAddress = parsedItem.$2;
    if (itemAddress != address) continue;

    final itemTitleNorm = normalizeTitle(parsedItem.$1);
    final score = titleSimilarityScore(normalizedTitle, itemTitleNorm);
    if (score > bestScore) {
      bestScore = score;
      best = item;
    }
  }

  return bestScore >= 2 ? best : null;
}

/// Splits a ref string into a `(title, address)` pair by peeling the trailing
/// numeric (with optional letter suffix) token off the end.
///
/// Returns `null` when the ref does not end with a numeric address.
(String, String)? parseRefTail(String ref) {
  final normalized = ref.replaceAll('_', ' ').trim();
  final match = RegExp(r'^(.*?)(\d+[a-z]?)$').firstMatch(normalized);
  if (match == null) return null;
  return ((match.group(1) ?? '').trim(), (match.group(2) ?? '').trim());
}

/// Normalises a title string for fuzzy comparison by lowercasing, removing
/// punctuation, stripping common stop-words, and applying spelling
/// normalisations.
String normalizeTitle(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), '')
      .replaceAll(RegExp(r'\b(the|talmud|mishnah|jerusalem)\b'), '')
      .replaceAll('baba', 'bava')
      .replaceAll('succah', 'sukkah')
      .replaceAll('megilah', 'megillah')
      .replaceAll('hullin', 'chullin')
      .replaceAll('beitzah', 'beitza')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Scores the similarity between two normalised title strings.
///
/// Returns 10 for exact match, 6 for containment, or the count of shared
/// words otherwise.
int titleSimilarityScore(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 10;
  if (a.contains(b) || b.contains(a)) return 6;

  final aWords = a.split(' ').where((w) => w.isNotEmpty).toSet();
  final bWords = b.split(' ').where((w) => w.isNotEmpty).toSet();
  final overlap = aWords.intersection(bWords).length;
  return overlap;
}
