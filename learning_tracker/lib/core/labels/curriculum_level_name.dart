import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/content_browsing.dart';

/// Resolve a curriculum hierarchy level's raw storage key (a seder/sefer at
/// level 1, a masechta/siman/hilchos at level 2, …) to its variant-aware
/// display name — the single shared implementation behind every surface that
/// renders a bare level name (Progress "Breakdown by Level", the
/// Siyumim & Milestones views, …).
///
/// The function:
///   * watches [curriculumContentProvider] for [curriculumId] and finds the
///     content row whose level1/level2 raw key equals [rawValue], reading its
///     Hebrew name through [CurriculumLabelRenderer.hebrewNameOf] (never a
///     direct Hebrew-name field access — DNI-386);
///   * renders the bare name via [CurriculumLabelRenderer.renderValue], reading
///     the Hebrew-Terms toggle through [domainTermLabels] and the nusach
///     through [currentTransliterationVariantProvider] so it re-renders live
///     when either setting changes;
///   * falls back to a transliteration-only render (no Hebrew name) while the
///     content is still loading or when the key is absent, so it never shows a
///     blank value — the Hebrew name simply arrives on the next rebuild.
///
/// [level] is 1-based (1 = named seder/sefer, 2 = masechta, …) and is matched
/// against the content row's corresponding raw level key.
String renderCurriculumLevelName(
  WidgetRef ref, {
  required CurriculumId curriculumId,
  required int level,
  required String rawValue,
}) {
  // Resolve the matching content row's Hebrew name (level-1 named seder/sefer,
  // else the level-2 named unit). Null while content loads or when the key
  // isn't present; the renderer then transliterates the raw key.
  final hebrewName = ref
      .watch(curriculumContentProvider(curriculumId))
      .maybeWhen(
        data: (items) {
          for (final item in items) {
            final key = level == 1 ? item.level1 : item.level2;
            if (key == rawValue) {
              return CurriculumLabelRenderer.hebrewNameOf(item);
            }
          }
          return null;
        },
        orElse: () => null,
      );

  return CurriculumLabelRenderer.renderValue(
    curriculumId: curriculumId,
    level: level,
    rawValue: rawValue,
    // Term toggle via the shared accessor (DNI 7/15: no raw
    // useHebrewTermsProvider read outside core/labels).
    useHebrew: domainTermLabels(ref).isHebrew,
    hebrewName: hebrewName,
    transliterationVariant: ref.watch(currentTransliterationVariantProvider),
  );
}
