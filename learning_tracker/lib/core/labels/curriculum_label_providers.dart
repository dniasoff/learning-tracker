import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/transliteration_variant_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'curriculum_label_providers.g.dart';

/// Renders the **full breadcrumb chain** for [sefariaRef] as a single
/// string joined by ` › ` (e.g. "משניות › זרעים › ברכות › פרק א › משנה א"
/// in Hebrew mode). Callers should render the result in a `Text` that
/// allows wrapping so the chain stays legible on narrow widgets.
///
/// Reads the Hebrew-terms toggle and transliteration variant, looks up the
/// matching `ContentItem` across all curricula, and delegates to
/// [CurriculumLabelRenderer]. Falls back to a stripped-underscore version
/// of the ref when no item matches.
@riverpod
Future<String> renderedDisplayForRef(Ref ref, String sefariaRef) async {
  final useHebrew = ref.watch(hebrewTermsScriptProvider);
  final variant = ref.watch(transliterationVariantProvider);
  final item = await _findContentItem(ref, sefariaRef);
  if (item == null) {
    return sefariaRef.replaceAll('_', ' ');
  }
  return CurriculumLabelRenderer.renderForItem(
    item,
    useHebrew: useHebrew,
    transliterationVariant: variant,
    fullPath: true,
  );
}

/// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
/// when the caller already shows ancestor context elsewhere and doesn't
/// want to duplicate it.
@riverpod
Future<String> renderedLeafForRef(Ref ref, String sefariaRef) async {
  final useHebrew = ref.watch(hebrewTermsScriptProvider);
  final variant = ref.watch(transliterationVariantProvider);
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
  final useHebrew = ref.watch(hebrewTermsScriptProvider);
  final variant = ref.watch(transliterationVariantProvider);
  final item = await _findContentItem(ref, sefariaRef);
  if (item == null) return null;
  return CurriculumLabelRenderer.renderParentForItem(
    item,
    useHebrew: useHebrew,
    transliterationVariant: variant,
  );
}

/// Renders every breadcrumb segment for [sefariaRef] in order.
@riverpod
Future<List<String>> renderedBreadcrumbForRef(
  Ref ref,
  String sefariaRef,
) async {
  final useHebrew = ref.watch(hebrewTermsScriptProvider);
  final variant = ref.watch(transliterationVariantProvider);
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

  final hebrewNames = List<String?>.filled(rawSegments.length, null);
  hebrewNames[hebrewNames.length - 1] = item.displayNameHe;

  return CurriculumLabelRenderer.renderBreadcrumb(
    curriculumId: id,
    rawSegmentValues: rawSegments,
    useHebrew: useHebrew,
    hebrewNamesPerSegment: hebrewNames,
    transliterationVariant: variant,
  );
}

Future<ContentItem?> _findContentItem(Ref ref, String sefariaRef) async {
  for (final curriculum in CurriculumId.values) {
    final items = await ref.watch(curriculumContentProvider(curriculum).future);
    for (final i in items) {
      if (i.sefariaRef == sefariaRef) return i;
    }
  }
  return null;
}

CurriculumId? _curriculumIdFromStorageKey(String key) {
  for (final id in CurriculumId.values) {
    if (id.storageKey == key) return id;
  }
  return null;
}
