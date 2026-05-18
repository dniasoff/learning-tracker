import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Stage 1: Pick ONE curriculum from all 9 available options.
///
/// Displays Hebrew title with English subtitle ([CurriculumId.displayNameEn]).
/// Single tap selection advances immediately.
///
/// When [existingTrackCurricula] contains a curriculum, a warning icon on the
/// right opens a brief SnackBar — re-adding replaces the current setup.
class CurriculumPickerStep extends StatelessWidget {
  const CurriculumPickerStep({
    required this.onSelected,
    this.isOnboarding = false,
    this.existingTrackCurricula = const <CurriculumId>{},
    super.key,
  });

  final ValueChanged<CurriculumId> onSelected;
  final bool isOnboarding;

  /// Curricula that already have an active track for this profile.
  final Set<CurriculumId> existingTrackCurricula;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = <CurriculumId>[
      CurriculumId.mishnayos,
      CurriculumId.bavli,
      CurriculumId.chumash,
      CurriculumId.nach,
      CurriculumId.mishnaBerurah,
    ];
    final remaining = CurriculumId.values
        .where((curriculum) => !featured.contains(curriculum))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isOnboarding
                ? 'What would you like to learn?'
                : 'Select a Curriculum',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose one curriculum for this track.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (final curriculum in featured) ...[
                  _CurriculumTile(
                    curriculum: curriculum,
                    showReplaceWarning: existingTrackCurricula.contains(
                      curriculum,
                    ),
                    onTap: () => onSelected(curriculum),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final curriculum in remaining) ...[
                  _CurriculumTile(
                    curriculum: curriculum,
                    showReplaceWarning: existingTrackCurricula.contains(
                      curriculum,
                    ),
                    onTap: () => onSelected(curriculum),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurriculumTile extends ConsumerWidget {
  const _CurriculumTile({
    required this.curriculum,
    required this.showReplaceWarning,
    required this.onTap,
  });

  final CurriculumId curriculum;
  final bool showReplaceWarning;
  final VoidCallback onTap;

  static const _warnIconColor = Color(0xFFE65100);

  static void _showReplaceSnack(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l10n = AppLocalizations.of(context)!;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.addTrackCurriculumReplaceWarning),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final style = _curriculumStyle(curriculum);
    final terms = domainTermLabels(ref);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1D2939),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: style.background,
                          ),
                          child: Icon(
                            style.icon,
                            color: style.iconColor,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CurriculumLabel.curriculum(
                                curriculum,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (!terms.isHebrew) ...[
                                const SizedBox(height: 2),
                                Text(
                                  curriculumHebrewName(curriculum),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppTheme.brandInk,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFC0C6D3),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showReplaceWarning)
              Material(
                color: Colors.transparent,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: AppLocalizations.of(
                    context,
                  )!.addTrackCurriculumReplaceWarning,
                  icon: const Icon(
                    Icons.warning_amber_rounded,
                    color: _warnIconColor,
                    size: 26,
                  ),
                  onPressed: () => _showReplaceSnack(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _CurriculumStyle _curriculumStyle(CurriculumId curriculum) {
    return switch (curriculum) {
      CurriculumId.mishnayos => const _CurriculumStyle(
        icon: Icons.menu_book_rounded,
        iconColor: Color(0xFF3F53BF),
        background: Color(0xFFE5E9FF),
      ),
      CurriculumId.bavli => const _CurriculumStyle(
        icon: Icons.gavel_rounded,
        iconColor: Color(0xFF7D5411),
        background: Color(0xFFF9E4C8),
      ),
      CurriculumId.chumash => const _CurriculumStyle(
        icon: Icons.book_outlined,
        iconColor: Color(0xFFB23749),
        background: Color(0xFFFFE0E5),
      ),
      CurriculumId.nach => const _CurriculumStyle(
        icon: Icons.description_rounded,
        iconColor: Color(0xFF646B79),
        background: Color(0xFFEBEDF2),
      ),
      CurriculumId.mishnaBerurah => const _CurriculumStyle(
        icon: Icons.gavel_rounded,
        iconColor: Color(0xFF3B4AAE),
        background: Color(0xFFDDE4FF),
      ),
      CurriculumId.yerushalmi => const _CurriculumStyle(
        icon: Icons.auto_stories_rounded,
        iconColor: Color(0xFF32617A),
        background: Color(0xFFE2F4FF),
      ),
      CurriculumId.mishnehTorah => const _CurriculumStyle(
        icon: Icons.account_balance_rounded,
        iconColor: Color(0xFF5B4BA6),
        background: Color(0xFFEAE5FF),
      ),
      CurriculumId.tanach => const _CurriculumStyle(
        icon: Icons.auto_stories_rounded,
        iconColor: Color(0xFF1D7D73),
        background: Color(0xFFE0FAF6),
      ),
      CurriculumId.mussar => const _CurriculumStyle(
        icon: Icons.self_improvement_rounded,
        iconColor: Color(0xFF6A4D9F),
        background: Color(0xFFEFE5FF),
      ),
    };
  }
}

class _CurriculumStyle {
  const _CurriculumStyle({
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
}
