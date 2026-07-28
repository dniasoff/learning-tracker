import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Read-only review schedule display for program tracks that have
/// defined chazara stages (chazara is fixed by the program).
class ChazaraReadOnlyStep extends StatelessWidget {
  const ChazaraReadOnlyStep({
    required this.programName,
    required this.stages,
    required this.onContinue,
    super.key,
  });

  final String programName;

  /// Raw stage objects decoded from program.stagesConfig (non-learn stages).
  final List<dynamic> stages;

  final VoidCallback onContinue;

  static String normalizeStageName(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Review stage';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reviewScheduleTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.reviewScheduleSetByProgram(programName),
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.colors.brandInkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              // darkmode/tracks audit: was a hardcoded Colors(0xFFEFF2FF)
              // while the icon/text below already read the adapting
              // brandBlueDeep ink — measured 1.46:1 in dark.
              // chazaraReadOnlyHintBg is the theme-aware token (identical hex
              // in light; darkens in dark).
              color: context.colors.chazaraReadOnlyHintBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: context.colors.brandBlueDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.reviewScheduleFixedHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.brandBlueDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: stages.isEmpty
                ? Center(
                    child: Text(
                      l10n.reviewScheduleNoStages,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colors.brandInkMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: stages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final stage = stages[index] as Map<String, dynamic>;
                      // Prefer the program's stored script label (e.g.
                      // "חזרה א׳" / "חזרה יומית") so the stage name honours the
                      // Hebrew/term form the seed data already carries; fall
                      // back to title-casing the raw snake_case key only when
                      // no label is present.
                      final storedLabel = (stage['label'] as String?)?.trim();
                      final name = (storedLabel?.isNotEmpty ?? false)
                          ? storedLabel!
                          : normalizeStageName(stage['stage'].toString());
                      final delay = stage['delay_days'];
                      final delayLabel = switch (delay) {
                        final int value when value == 1 =>
                          l10n.reviewScheduleAfterOneDay,
                        final int value => l10n.reviewScheduleAfterNDays(
                          '$value',
                        ),
                        final String value => l10n.reviewScheduleAfterNDays(
                          value,
                        ),
                        _ => l10n.reviewScheduleScheduledByProgram,
                      };

                      return DecoratedBox(
                        decoration: BoxDecoration(
                          // darkmode/tracks audit: was a hardcoded
                          // Colors.white while the title text below reads the
                          // theme's default titleMedium colour (brandInk,
                          // near-white in dark) — measured ~1.06:1 in dark.
                          // brandCreamCard is the theme-aware card surface
                          // token (identical 0xFFFFFFFF in light; darkens in
                          // dark).
                          color: context.colors.brandCreamCard,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE7EAF1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                // darkmode/tracks audit: was a hardcoded
                                // Colors(0xFFE9ECFF) while the number text
                                // below already read the adapting
                                // brandBlueDeep ink — measured ~1.5:1 in
                                // dark. chazaraReadOnlyStageBadgeBg is the
                                // theme-aware token (identical hex in light;
                                // darkens in dark).
                                backgroundColor:
                                    context.colors.chazaraReadOnlyStageBadgeBg,
                                child: Text(
                                  '${index + 1}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: context.colors.brandBlueDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      delayLabel,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context.colors.brandInkMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.lock_rounded,
                                size: 18,
                                color: context.colors.brandInkMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );
  }
}
