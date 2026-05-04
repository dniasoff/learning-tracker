import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Stage 1: Pick ONE curriculum from all 9 available options.
///
/// Displays Hebrew names. Single tap selection advances immediately.
class CurriculumPickerStep extends StatelessWidget {
  const CurriculumPickerStep({
    required this.onSelected,
    this.isOnboarding = false,
    super.key,
  });

  final ValueChanged<CurriculumId> onSelected;
  final bool isOnboarding;

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
                    onTap: () => onSelected(curriculum),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final curriculum in remaining) ...[
                  _CurriculumTile(
                    curriculum: curriculum,
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

class _CurriculumTile extends StatelessWidget {
  const _CurriculumTile({required this.curriculum, required this.onTap});

  final CurriculumId curriculum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _curriculumStyle(curriculum);

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.background,
                  ),
                  child: Icon(style.icon, color: style.iconColor, size: 27),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curriculum.displayNameHe,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        style.subtitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.brandInk,
                        ),
                      ),
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
    );
  }

  _CurriculumStyle _curriculumStyle(CurriculumId curriculum) {
    return switch (curriculum) {
      CurriculumId.mishnayos => const _CurriculumStyle(
        icon: Icons.menu_book_rounded,
        iconColor: Color(0xFF3F53BF),
        background: Color(0xFFE5E9FF),
        subtitle: 'Mishnayos',
      ),
      CurriculumId.bavli => const _CurriculumStyle(
        icon: Icons.gavel_rounded,
        iconColor: Color(0xFF7D5411),
        background: Color(0xFFF9E4C8),
        subtitle: 'Gemara',
      ),
      CurriculumId.chumash => const _CurriculumStyle(
        icon: Icons.book_outlined,
        iconColor: Color(0xFFB23749),
        background: Color(0xFFFFE0E5),
        subtitle: 'Chumash',
      ),
      CurriculumId.nach => const _CurriculumStyle(
        icon: Icons.description_rounded,
        iconColor: Color(0xFF646B79),
        background: Color(0xFFEBEDF2),
        subtitle: 'Nach',
      ),
      CurriculumId.mishnaBerurah => const _CurriculumStyle(
        icon: Icons.gavel_rounded,
        iconColor: Color(0xFF3B4AAE),
        background: Color(0xFFDDE4FF),
        subtitle: 'Halacha',
      ),
      CurriculumId.yerushalmi => const _CurriculumStyle(
        icon: Icons.auto_stories_rounded,
        iconColor: Color(0xFF32617A),
        background: Color(0xFFE2F4FF),
        subtitle: 'Talmud Yerushalmi',
      ),
      CurriculumId.mishnehTorah => const _CurriculumStyle(
        icon: Icons.account_balance_rounded,
        iconColor: Color(0xFF5B4BA6),
        background: Color(0xFFEAE5FF),
        subtitle: 'Mishneh Torah',
      ),
      CurriculumId.tanach => const _CurriculumStyle(
        icon: Icons.auto_stories_rounded,
        iconColor: Color(0xFF1D7D73),
        background: Color(0xFFE0FAF6),
        subtitle: 'Tanach',
      ),
      CurriculumId.mussar => const _CurriculumStyle(
        icon: Icons.self_improvement_rounded,
        iconColor: Color(0xFF6A4D9F),
        background: Color(0xFFEFE5FF),
        subtitle: 'Mussar',
      ),
    };
  }
}

class _CurriculumStyle {
  const _CurriculumStyle({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String subtitle;
}
