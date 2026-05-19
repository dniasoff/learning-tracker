import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Visual identity for curriculum + stage rows shown across the app.
///
/// Lives in `core/labels/` so feature widgets can render a leading icon and a
/// stage-accent colour without inlining their own switch on [CurriculumId] or
/// `stageId`. Keep the mapping in one place so a new curriculum picks up a
/// reasonable default everywhere at once.
///
/// `curriculumIcon` is pure (no BuildContext). `stageAccentColor` resolves
/// against the active theme so the colours read correctly in both light and
/// dark mode — passing the brand primary directly would land an unreadable
/// dark-on-dark for the Learn stage in dark mode.

/// Material icon used to mark a curriculum in lists and section headers.
///
/// Mapping leans on the structural shape of each corpus rather than its
/// content — e.g. Bavli is the canonical "auto_stories" daf-of-the-day glyph,
/// Mishneh Torah is the code-of-law `account_balance`. The icons are all
/// outlined so they sit comfortably next to a Hebrew-script title.
IconData curriculumIcon(CurriculumId id) {
  switch (id) {
    case CurriculumId.chumash:
    case CurriculumId.nach:
    case CurriculumId.tanach:
      return Icons.menu_book_outlined;
    case CurriculumId.mishnayos:
      return Icons.collections_bookmark_outlined;
    case CurriculumId.bavli:
      return Icons.auto_stories_outlined;
    case CurriculumId.yerushalmi:
      return Icons.import_contacts_outlined;
    case CurriculumId.mishnehTorah:
      return Icons.account_balance_outlined;
    case CurriculumId.mishnaBerurah:
      return Icons.menu_book;
    case CurriculumId.mussar:
      return Icons.psychology_alt_outlined;
  }
}

/// Accent colour for a stage badge / leading bar.
///
/// `stageId` is the 1-based DB value (1 = Learn, ≥2 = Chazara n). Learn uses
/// the theme's primary so it picks up `brandBlueDark` automatically in dark
/// mode; chazarah uses an amber accent — `shade700` on light surfaces,
/// `shade400` on dark surfaces — so review items are spottable at a glance
/// without losing contrast.
Color stageAccentColor(BuildContext context, int stageId) {
  final theme = Theme.of(context);
  if (stageId <= 1) return theme.colorScheme.primary;
  return theme.brightness == Brightness.dark
      ? Colors.amber.shade400
      : Colors.amber.shade700;
}
