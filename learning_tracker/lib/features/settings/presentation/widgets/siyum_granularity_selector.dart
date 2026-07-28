import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/progress/progress.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Per-curriculum siyum-granularity selector for the Curriculum Settings
/// screen.
///
/// Shows one radio per offered tier (finest → coarsest) — always
/// per-unit + whole-curriculum, plus a per-aggregate (seder-style) option when
/// the curriculum exposes a meaningful aggregate level (see
/// [availableSiyumTiersProvider]). The chosen tier is the FINEST milestone the
/// family wants celebrated; the journey/siyumim screens react live because the
/// same [siyumGranularityProvider] drives both.
class SiyumGranularitySelector extends ConsumerWidget {
  const SiyumGranularitySelector({super.key, required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tiersAsync = ref.watch(availableSiyumTiersProvider(curriculum));
    final selected = ref.watch(siyumGranularityProvider(curriculum));

    return tiersAsync.when(
      loading: () => const SizedBox.shrink(),
      // A content-load failure just hides the (optional) selector rather than
      // breaking the whole settings screen — the default (finest) granularity
      // still applies underneath.
      error: (_, _) => const SizedBox.shrink(),
      data: (tiers) => RadioGroup<MilestoneLevel>(
        groupValue: selected,
        onChanged: (value) {
          if (value == null) return;
          ref.read(siyumGranularityProvider(curriculum).notifier).set(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.siyumGranularityTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.siyumGranularitySubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final tier in tiers)
              RadioListTile<MilestoneLevel>(
                value: tier,
                title: Text(
                  siyumTierLabel(
                    ref,
                    context,
                    curriculum: curriculum,
                    level: tier,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
