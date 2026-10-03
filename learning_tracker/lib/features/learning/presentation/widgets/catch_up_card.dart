/// The catch-up cards on the Learn tab (Story 3.2, DNI-505; screen #10).
///
/// One `catch-up-card` per pending lock, oldest first (A-4), at the top of
/// the Learn tab (UX-DR-57): a blue-soft `{rounded.card}` surface with a
/// calendar icon, the question ("Shabbos · 4 mishnayos planned — learnt
/// them all?") in `title-medium`, the availability caption ("Available
/// until the end of Sunday"), what each source planned, and the *Yes, all
/// of it* (primary pill) and *Adjust…* (outlined pill) actions.
///
/// * No pending lock, a tutored session, or nothing planned: no card and
///   nothing in its place — no streak or pressure copy (AC-9, AC-12,
///   NFR-18).
/// * The contents fail to load: the card stays, with an inline error and
///   retry, until its window ends (AC-11, UX-DR-132).
///
/// The actions write nothing here: Story 3.3 (DNI-506, *Yes, all of it*,
/// `recordCatchUpAll`) and Story 3.4 (DNI-507, *Adjust…* then Record,
/// `recordCatchUpAdjusted`) provide them through
/// [catchUpCardActionsProvider]; one not yet provided is shown disabled.
/// *Adjust…* expands the [CatchUpAdjustPanel] in place (no new route) and
/// collapses it again, discarding the panel's edits. While a record action
/// runs the actions are disabled, and a record that was not saved shows
/// "Couldn't save — try again before the card expires." on the card
/// (DNI-506 AC-8, UX-DR-133).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_adjust_panel.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The card actions the later stories plug in; a null handler shows its
/// action disabled.
final class CatchUpCardActions {
  /// Creates the actions.
  const CatchUpCardActions({this.recordAll, this.recordAdjusted});

  /// *Yes, all of it* (Story 3.3, DNI-506).
  final void Function(BuildContext context, CatchUpTaskCard card)? recordAll;

  /// *Record {n}* of the *Adjust…* panel (Story 3.4, DNI-507): records the
  /// adjusted [CatchUpAction] of the card. Null disables *Adjust…*.
  final void Function(
    BuildContext context,
    CatchUpTaskCard card,
    CatchUpAction action,
  )?
  recordAdjusted;
}

/// The actions of the catch-up card: *Yes, all of it* (Story 3.3); Story
/// 3.4 adds *Adjust…*.
final catchUpCardActionsProvider = Provider<CatchUpCardActions>(
  (ref) => CatchUpCardActions(recordAll: catchUpRecordAllOf(ref)),
);

/// The pending catch-up cards, or nothing.
class CatchUpCardsSection extends ConsumerWidget {
  /// Creates the section.
  const CatchUpCardsSection({super.key});

  /// Gap below the section when it renders, and between cards.
  static const double spacing = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(catchUpCardWindowsProvider).asData?.value;
    if (windows == null || windows.isEmpty) return const SizedBox.shrink();
    final cards = ref.watch(catchUpCardsProvider);
    final List<Widget> children;
    if (cards.hasError) {
      children = [
        for (final w in windows)
          CatchUpCardShell(
            key: ValueKey('catchUpCardError-${w.key}'),
            window: w,
            question: catchUpDayLabel(ref, w),
            child: _ContentsError(onRetry: () => retryCatchUpCards(ref)),
          ),
      ];
    } else if (!cards.hasValue) {
      children = [
        for (final w in windows)
          CatchUpCardShell(
            key: ValueKey('catchUpCardLoading-${w.key}'),
            window: w,
            question: catchUpDayLabel(ref, w),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          ),
      ];
    } else {
      final value = cards.requireValue;
      if (value.isEmpty) return const SizedBox.shrink();
      children = [for (final c in value) CatchUpCardView(card: c)];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: spacing),
            child,
          ],
        ],
      ),
    );
  }
}

/// The card's day label (A-2), per the Hebrew Terms setting: "Shabbos",
/// "Yom Tov", "Yom Tov & Shabbos" or "Yom Kippur".
String catchUpDayLabel(WidgetRef ref, CatchUpCardWindow window) {
  final terms = domainTermLabels(ref);
  final variant = ref.watch(currentTransliterationVariantProvider);
  return switch (window.kind) {
    ErevKind.shabbos => terms.shabbos(variant: variant),
    ErevKind.yomTov => terms.yomTov,
    ErevKind.yomTovAndShabbos => terms.yomTovAndShabbos(variant: variant),
    ErevKind.yomKippur => terms.yomKippur,
  };
}

/// The localized weekday of [window]'s last available day.
String catchUpLastDayName(BuildContext context, CatchUpCardWindow window) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.EEEE(locale).format(parseCivilDay(window.lastDay));
}

/// The leaf unit of curriculum [curriculumId] for [count] leaves.
String _unitLabel(WidgetRef ref, String curriculumId, int count) {
  final id = CurriculumId.fromStorageKey(curriculumId);
  if (id == null) return curriculumId;
  return CurriculumLabels.leaf(id).inLanguage(
    useHebrew: domainTermLabels(ref).isHebrew,
    plural: count != 1,
    variant: ref.watch(currentTransliterationVariantProvider),
  );
}

/// The card's question (AC-2): the main-track planner count with the
/// curriculum's unit for one curriculum, as items across curricula, or
/// without a count when only sub-tracks planned something.
String catchUpQuestion(
  WidgetRef ref,
  AppLocalizations l10n,
  CatchUpTaskCard card,
) {
  final day = catchUpDayLabel(ref, card.window);
  final n = card.mainTaskCount;
  if (n == 0) return l10n.catchUpCardQuestionNoCount(day);
  final curricula = {
    for (final g in card.groups)
      if (g.mainTaskCount > 0) g.curriculumId,
  };
  if (curricula.length == 1) {
    return l10n.catchUpCardQuestion(
      day,
      n,
      _unitLabel(ref, curricula.first, n),
    );
  }
  return l10n.catchUpCardQuestionItems(day, n);
}

/// The card frame: icon, [question], the availability caption, then
/// [child].
class CatchUpCardShell extends StatelessWidget {
  /// Creates the shell.
  const CatchUpCardShell({
    super.key,
    required this.window,
    required this.question,
    required this.child,
  });

  /// The lock and its window (for the caption).
  final CatchUpCardWindow window;

  /// The question (or, before the contents load, the day label).
  final String question;

  /// What follows the caption.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final caption = l10n.catchUpCardAvailableUntil(
      catchUpLastDayName(context, window),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.brandBlueSoft,
          borderRadius: BorderRadius.circular(18), // {rounded.card}
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.calendar_month_rounded,
                    key: const ValueKey('catchUpCardIcon'),
                    color: colors.brandBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          question,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.brandInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.brandInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// One pending card with its contents and actions; *Adjust…* expands the
/// [CatchUpAdjustPanel] in place.
class CatchUpCardView extends ConsumerStatefulWidget {
  /// Creates the card.
  const CatchUpCardView({super.key, required this.card});

  /// The card.
  final CatchUpTaskCard card;

  @override
  ConsumerState<CatchUpCardView> createState() => _CatchUpCardViewState();
}

class _CatchUpCardViewState extends ConsumerState<CatchUpCardView> {
  /// Whether the Adjust panel is open. Closing it drops its selection.
  bool _adjusting = false;

  @override
  void didUpdateWidget(CatchUpCardView old) {
    super.didUpdateWidget(old);
    if (old.card.window.key != widget.card.window.key) _adjusting = false;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final actions = ref.watch(catchUpCardActionsProvider);
    final phase = ref.watch(catchUpRecordStatusProvider)[card.window.key];
    final recording = phase == CatchUpRecordPhase.recording;
    final recordAll = recording ? null : actions.recordAll;
    final recordAdjusted = actions.recordAdjusted;
    final adjusting = _adjusting && recordAdjusted != null;
    final lines = <(String key, String text)>[];
    for (final g in card.groups) {
      if (g.mainTaskCount > 0) {
        lines.add((
          '${g.curriculumId}/main',
          l10n.catchUpCardSourceLine(
            l10n.captureSourceHome,
            g.mainTaskCount,
            _unitLabel(ref, g.curriculumId, g.mainTaskCount),
          ),
        ));
      }
      final perTrack = <String, (String, int)>{};
      for (final d in g.days) {
        for (final s in d.subTracks) {
          final prev = perTrack[s.subTrackId];
          perTrack[s.subTrackId] = (s.name, (prev?.$2 ?? 0) + s.leaves.length);
        }
      }
      for (final MapEntry(key: id, value: (name, count)) in perTrack.entries) {
        lines.add((
          '${g.curriculumId}/$id',
          l10n.catchUpCardSourceLine(
            name,
            count,
            _unitLabel(ref, g.curriculumId, count),
          ),
        ));
      }
    }
    const pillMin = Size(64, 48); // 48dp targets (UX-DR-157)
    return CatchUpCardShell(
      key: ValueKey('catchUpCard-${card.window.key}'),
      window: card.window,
      question: catchUpQuestion(ref, l10n, card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (key, text) in lines)
            Padding(
              key: ValueKey('catchUpCardLine-$key'),
              padding: const EdgeInsetsDirectional.only(start: 36, bottom: 4),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.brandInk,
                ),
              ),
            ),
          if (phase == CatchUpRecordPhase.failed)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  key: const ValueKey('catchUpCardSaveFailed'),
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.catchUpCardSaveFailed,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('catchUpCardYesAll'),
                style: FilledButton.styleFrom(
                  minimumSize: pillMin,
                  shape: const StadiumBorder(),
                ),
                onPressed: recordAll == null
                    ? null
                    : () => recordAll(context, card),
                child: recording
                    ? Semantics(
                        label: l10n.catchUpCardRecording,
                        child: const SizedBox.square(
                          key: ValueKey('catchUpCardRecording'),
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Text(l10n.catchUpCardYesAll),
              ),
              Semantics(
                expanded: recordAdjusted == null ? null : adjusting,
                child: OutlinedButton.icon(
                  key: const ValueKey('catchUpCardAdjust'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: pillMin,
                    shape: const StadiumBorder(),
                  ),
                  iconAlignment: IconAlignment.end,
                  onPressed: recordAdjusted == null || recording
                      ? null
                      : () => setState(() => _adjusting = !_adjusting),
                  icon: Icon(
                    adjusting
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                  ),
                  label: Text(l10n.catchUpCardAdjust),
                ),
              ),
            ],
          ),
          if (adjusting)
            CatchUpAdjustPanel(
              card: card,
              recording: recording,
              onCollapse: () => setState(() => _adjusting = false),
              onRecord: (action) => recordAdjusted(context, card, action),
            ),
        ],
      ),
    );
  }
}

/// The inline contents error with a 48dp Retry (AC-11, UX-DR-132).
class _ContentsError extends StatelessWidget {
  const _ContentsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      key: const ValueKey('catchUpCardContentsError'),
      children: [
        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.catchUpCardContentsError,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('catchUpCardRetry'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}
