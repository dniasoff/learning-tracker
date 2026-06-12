import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'curriculum_label_providers.g.dart';

/// Renders the **full breadcrumb chain** for [sefariaRef] as a single
/// string joined by ` › ` (e.g. "זרעים › ברכות › פרק א › משנה א" in
/// Hebrew mode). Looks up the matching `ContentItem` for the leaf AND
/// for each ancestor segment so every named level renders in Hebrew,
/// not just the leaf. Callers should render the result in a `Text` that
/// allows wrapping so the chain stays legible on narrow widgets.
@riverpod
Future<String> renderedDisplayForRef(Ref ref, String sefariaRef) async {
  final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
  final variant = ref.watch(currentTransliterationVariantProvider);
  final item = await _findContentItem(ref, sefariaRef);
  if (item == null) {
    return sefariaRef.replaceAll('_', ' ');
  }
  final id = _curriculumIdFromStorageKey(item.curriculumId);
  if (id == null) {
    return useHebrew ? item.displayNameHe : item.displayNameEn;
  }

  final rawSegments = <String>[item.level1];
  if (item.level2 != null) rawSegments.add(item.level2!);
  if (item.level3 != null) rawSegments.add(item.level3!);
  if (item.level4 != null) rawSegments.add(item.level4!);

  // Look up Hebrew names for every ancestor segment so the renderer
  // doesn't fall back to the raw English value ("Seder Moed",
  // "Mishnah Shabbat").
  final allItems = await ref.watch(curriculumContentProvider(id).future);
  final hebrewNames = _hebrewNamesForPath(allItems, rawSegments);
  // The leaf segment uses the item's own displayNameHe (always present
  // for the matched ref).
  hebrewNames[hebrewNames.length - 1] = item.displayNameHe;

  final segments = CurriculumLabelRenderer.renderBreadcrumb(
    curriculumId: id,
    rawSegmentValues: rawSegments,
    useHebrew: useHebrew,
    hebrewNamesPerSegment: hebrewNames,
    transliterationVariant: variant,
  );
  return segments.join(' › ');
}

/// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
/// when the caller already shows ancestor context elsewhere and doesn't
/// want to duplicate it.
@riverpod
Future<String> renderedLeafForRef(Ref ref, String sefariaRef) async {
  final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
  final variant = ref.watch(currentTransliterationVariantProvider);
  final item = await _findContentItem(ref, sefariaRef);
  if (item == null) {
    return sefariaRef.replaceAll('_', ' ');
  }
  return CurriculumLabelRenderer.renderForItem(
    item,
    useHebrew: useHebrew,
    transliterationVariant: variant,
  );
}

/// Renders the parent (one level above leaf) display string for [sefariaRef].
/// Used by the reader page's two-line AppBar — leaf big, parent small.
/// Returns null when the item is already at level 1.
@riverpod
Future<String?> renderedParentForRef(Ref ref, String sefariaRef) async {
  final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
  final variant = ref.watch(currentTransliterationVariantProvider);
  final item = await _findContentItem(ref, sefariaRef);
  if (item == null) return null;
  return CurriculumLabelRenderer.renderParentForItem(
    item,
    useHebrew: useHebrew,
    transliterationVariant: variant,
  );
}

/// Renders every breadcrumb segment for [sefariaRef] in order. Looks up
/// the Hebrew name of every ancestor segment so each renders in Hebrew
/// rather than the raw English value.
@riverpod
Future<List<String>> renderedBreadcrumbForRef(
  Ref ref,
  String sefariaRef,
) async {
  final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
  final variant = ref.watch(currentTransliterationVariantProvider);
  final item = await _findContentItem(ref, sefariaRef);
  if (item == null) {
    return [sefariaRef.replaceAll('_', ' ')];
  }
  final id = _curriculumIdFromStorageKey(item.curriculumId);
  if (id == null) return [item.displayNameEn];

  final rawSegments = <String>[item.level1];
  if (item.level2 != null) rawSegments.add(item.level2!);
  if (item.level3 != null) rawSegments.add(item.level3!);
  if (item.level4 != null) rawSegments.add(item.level4!);

  final allItems = await ref.watch(curriculumContentProvider(id).future);
  final hebrewNames = _hebrewNamesForPath(allItems, rawSegments);
  hebrewNames[hebrewNames.length - 1] = item.displayNameHe;

  return CurriculumLabelRenderer.renderBreadcrumb(
    curriculumId: id,
    rawSegmentValues: rawSegments,
    useHebrew: useHebrew,
    hebrewNamesPerSegment: hebrewNames,
    transliterationVariant: variant,
  );
}

/// For each entry in [rawSegments], find the container ContentItem
/// (matching levels 1..N and no deeper levels) and return its
/// [ContentItem.displayNameHe]. Returns null entries when no container
/// is found at that depth — the renderer will fall back to the raw value.
List<String?> _hebrewNamesForPath(
  List<ContentItem> allItems,
  List<String> rawSegments,
) {
  final result = <String?>[];
  for (var depth = 0; depth < rawSegments.length; depth++) {
    final segmentDepth = depth + 1;
    ContentItem? match;
    for (final it in allItems) {
      if (it.level1 != rawSegments[0]) continue;
      if (segmentDepth >= 2 && it.level2 != rawSegments[1]) continue;
      if (segmentDepth >= 3 && it.level3 != rawSegments[2]) continue;
      if (segmentDepth >= 4 && it.level4 != rawSegments[3]) continue;
      if (segmentDepth < 2 && it.level2 != null) continue;
      if (segmentDepth < 3 && it.level3 != null) continue;
      if (segmentDepth < 4 && it.level4 != null) continue;
      match = it;
      break;
    }
    result.add(match?.displayNameHe);
  }
  return result;
}

/// Locate the [ContentItem] for [sefariaRef] in O(1) via
/// [contentIndexProvider]. Replaces the previous O(N × 9-curriculum) scan
/// (NFR22).
Future<ContentItem?> _findContentItem(Ref ref, String sefariaRef) async {
  final index = await ref.watch(contentIndexProvider.future);
  return index.lookup(sefariaRef);
}

CurriculumId? _curriculumIdFromStorageKey(String key) {
  for (final id in CurriculumId.values) {
    if (id.storageKey == key) return id;
  }
  return null;
}
