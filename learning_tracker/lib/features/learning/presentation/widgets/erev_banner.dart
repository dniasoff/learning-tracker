/// The erev banner on the Learn tab (Story 3.1, DNI-504; screen #09).
///
/// A blue-soft `{rounded.card}` banner naming the coming lock (Shabbos
/// Kodesh, Yom Tov, Yom Tov & Shabbos or Yom Kippur, per the Hebrew Terms
/// setting) and its start time, which is the [ErevWindow]'s lock start:
/// the same `lockWindows` value the capture gate and the lock overlay use,
/// fallbacks included (AC-6). It is the first focusable element of the
/// tab and announces the lock time (AC-11, UX-DR-159).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The banner while the Learn tab is in the erev window; nothing outside
/// it, while it loads, or when it cannot be computed (the gate and overlay
/// fail closed on their own reads).
class ErevBannerSlot extends ConsumerWidget {
  /// Creates the slot.
  const ErevBannerSlot({super.key});

  /// Gap below the banner when it renders.
  static const double bottomSpacing = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(erevWindowProvider).asData?.value;
    if (window == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomSpacing),
      child: ErevBanner(window: window),
    );
  }
}

/// The lock's label for [kind] per the Hebrew Terms setting.
String erevLockLabel(WidgetRef ref, ErevKind kind) {
  final terms = domainTermLabels(ref);
  final variant = ref.watch(currentTransliterationVariantProvider);
  return switch (kind) {
    ErevKind.shabbos => terms.shabbosKodesh(variant: variant),
    ErevKind.yomTov => terms.yomTov,
    ErevKind.yomTovAndShabbos => terms.yomTovAndShabbos(variant: variant),
    ErevKind.yomKippur => terms.yomKippur,
  };
}

/// The lock's short term for the "begins at" line ("Shabbos" for a
/// Shabbos lock, else the full label).
String _beginsTerm(WidgetRef ref, ErevKind kind) {
  if (kind != ErevKind.shabbos) return erevLockLabel(ref, kind);
  return domainTermLabels(
    ref,
  ).shabbos(variant: ref.watch(currentTransliterationVariantProvider));
}

/// [window]'s lock start as the learner's wall clock shows it, in the
/// device's 12/24-hour convention.
String erevLockTime(BuildContext context, ErevWindow window) {
  final local = window.lockStartLocal;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: local.hour, minute: local.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// The erev banner for [window].
class ErevBanner extends ConsumerWidget {
  /// Creates the banner.
  const ErevBanner({super.key, required this.window});

  /// The erev window it announces.
  final ErevWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final label = erevLockLabel(ref, window.kind);
    final beginsAt = l10n.erevBannerBeginsAt(
      _beginsTerm(ref, window.kind),
      erevLockTime(context, window),
    );
    return Semantics(
      container: true,
      focusable: true,
      sortKey: const OrdinalSortKey(0),
      label: '$label. $beginsAt',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('erevBanner'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.brandBlueSoft,
          borderRadius: BorderRadius.circular(18), // {rounded.card}
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.nights_stay_rounded, color: colors.brandBlue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    beginsAt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.brandInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
