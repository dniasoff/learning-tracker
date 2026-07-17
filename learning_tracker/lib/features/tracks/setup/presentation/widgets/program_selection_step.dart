import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Returns the text for the calendar-icon row on a program card.
///
/// TS-1 fix: the row must NOT display the program's own name — that was
/// the pre-fix bug ('Starts: $name').  For calendar programs the row should
/// read "DAILY CALENDAR"; for non-calendar programs (custom / manual) there
/// is no meaningful start label so the row is hidden (empty string returned).
String programStartsLabel(AppLocalizations l10n, LearningProgramData program) {
  if (program.isCalendarProgram) return l10n.programDailyCalendarBadge;
  return '';
}

/// Stage 2: Join a calendar program or continue self-paced.
///
/// Loads active programs via [LearningProgramRepository]. The parent
/// [AddTrackFlow] omits this step when the curriculum has no programs.
class ProgramSelectionStep extends ConsumerStatefulWidget {
  const ProgramSelectionStep({
    required this.curriculumId,
    required this.onSelected,
    super.key,
  });

  final CurriculumId curriculumId;

  /// Called with (programId, programName, fullProgram) or (null, null, null) for self-paced.
  final void Function(
    int? programId,
    String? programName,
    LearningProgramData? program,
  )
  onSelected;

  @override
  ConsumerState<ProgramSelectionStep> createState() =>
      _ProgramSelectionStepState();
}

class _ProgramSelectionStepState extends ConsumerState<ProgramSelectionStep> {
  late final List<LearningProgramData> _programs;
  bool _didAutoSkip = false;

  @override
  void initState() {
    super.initState();
    _programs = ref
        .read(learningProgramRepositoryProvider)
        .getActiveProgramsByCurriculumType(widget.curriculumId.storageKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_programs.isEmpty) {
      if (!_didAutoSkip) {
        _didAutoSkip = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSelected(null, null, null);
        });
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.programStepTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.programStepSubtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                _FeaturedProgramCard(
                  program: _programs.first,
                  onTap: () => widget.onSelected(
                    _programs.first.id,
                    learningProgramLabelText(ref, program: _programs.first),
                    _programs.first,
                  ),
                ),
                for (var i = 1; i < _programs.length; i++) ...[
                  const SizedBox(height: 12),
                  _CompactProgramCard(
                    program: _programs[i],
                    accentColor: i.isEven
                        ? const Color(0xFFDDE4FF)
                        : AppColors.peachTint,
                    iconColor: i.isEven
                        ? const Color(0xFF2F4CB5)
                        : AppColors.goldDark,
                    onTap: () => widget.onSelected(
                      _programs[i].id,
                      learningProgramLabelText(ref, program: _programs[i]),
                      _programs[i],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    l10n.programStepOrChooseFreedom,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.brandInkMuted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => widget.onSelected(null, null, null),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.peachMid,
                    foregroundColor: const Color(0xFF2E271E),
                    elevation: 0,
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Color(0xFFE4B46F)),
                    ),
                  ),
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: Text(
                    l10n.programStepSelfPaced,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.programStepSelfPacedCaption,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedProgramCard extends ConsumerWidget {
  const _FeaturedProgramCard({required this.program, required this.onTap});

  final LearningProgramData program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = learningProgramLabelText(ref, program: program);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceE9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1D2939),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceBlueLight,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF2E4BBB),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  learningProgramDescriptionText(
                    ref,
                    context,
                    program: program,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.brandInkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: AppTheme.brandBlueDeep,
                    ),
                    const SizedBox(width: 6),
                    // TS-1 fix: use programStartsLabel so the row shows
                    // "DAILY CALENDAR" (or is hidden) instead of the
                    // program name.
                    if (programStartsLabel(
                      AppLocalizations.of(context)!,
                      program,
                    ).isNotEmpty)
                      Expanded(
                        child: Text(
                          programStartsLabel(
                            AppLocalizations.of(context)!,
                            program,
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.brandBlueDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactProgramCard extends ConsumerWidget {
  const _CompactProgramCard({
    required this.program,
    required this.onTap,
    this.accentColor = AppColors.peachTint,
    this.iconColor = AppColors.goldDark,
  });

  final LearningProgramData program;
  final VoidCallback onTap;
  final Color accentColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = learningProgramLabelText(ref, program: program);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceE9),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  learningProgramDescriptionText(
                    ref,
                    context,
                    program: program,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: AppTheme.brandBlueDeep,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.programDailyCalendarBadge,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.brandBlueDeep,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
