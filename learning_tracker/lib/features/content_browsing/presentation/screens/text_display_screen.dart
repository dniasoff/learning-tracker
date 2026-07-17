import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/core/utils/gematriya.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class TextDisplayScreen extends ConsumerWidget {
  const TextDisplayScreen({
    super.key,
    @PathParam('sefariaRef') required this.sefariaRef,
  });

  final String sefariaRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textAsync = ref.watch(textContentProvider(sefariaRef));
    final fontSize = ref.watch(fontSizeProvider);
    final showNikud = ref.watch(showNikudProvider);
    final theme = Theme.of(context);

    // Single label renderer drives the AppBar — full breadcrumb chain so
    // the user always knows where they are (Sefer › Perek › Mishna / Daf).
    // Wraps onto multiple lines if needed; the AppBar grows to fit.
    final chainAsync = ref.watch(renderedDisplayForRefProvider(sefariaRef));
    final chainTitle = chainAsync.when(
      data: (v) => v,
      loading: () => '…',
      error: (_, __) => sefariaRef.replaceAll('_', ' '),
    );

    final adjAsync = ref.watch(adjacentContentRefsProvider(sefariaRef));
    final adj = adjAsync.asData?.value;

    // #14 — fire-and-forget background prefetch so the SQLite read is warm
    // before the user taps ‹ or ›, eliminating the ~8s "Loading text…" spinner.
    // Uses ref.read (non-reactive) + .ignore() to swallow both the result and
    // any error; textContentProvider is auto-dispose so no leak occurs.
    if (adj?.next != null) {
      ref.read(textContentProvider(adj!.next!).future).ignore();
    }
    if (adj?.prev != null) {
      ref.read(textContentProvider(adj!.prev!).future).ignore();
    }

    // #16 — resolve the curriculum root name so the AppBar title can
    // disambiguate shared seder/masechta names (e.g. ברכות in Mishnah vs Bavli).
    // contentIndexProvider is keepAlive so the lookup is O(1) once warm.
    final contentIndex = ref.watch(contentIndexProvider).asData?.value;
    final curriculumId = contentIndex != null
        ? _curriculumIdForRef(sefariaRef, contentIndex)
        : null;
    final curriculumName = curriculumId != null
        ? curriculumLabelText(ref, curriculum: curriculumId)
        : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceF5,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceF5,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          curriculumName != null ? '$curriculumName › $chainTitle' : chainTitle,
          textAlign: TextAlign.center,
          maxLines: 3,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.brandInk,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('text_display_prev_button'),
            icon: const Icon(Icons.chevron_left),
            tooltip: AppLocalizations.of(context)!.textReaderTooltipPrevious,
            onPressed: adj?.prev != null
                ? () => context.router.replace(
                    TextDisplayRoute(sefariaRef: adj!.prev!),
                  )
                : null,
          ),
          IconButton(
            key: const Key('text_display_next_button'),
            icon: const Icon(Icons.chevron_right),
            tooltip: AppLocalizations.of(context)!.textReaderTooltipNext,
            onPressed: adj?.next != null
                ? () => context.router.replace(
                    TextDisplayRoute(sefariaRef: adj!.next!),
                  )
                : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: textAsync.when(
          data: (textContent) {
            if (textContent == null) {
              return const _OfflineMessage();
            }
            return _TextContentView(
              textContent: textContent,
              fontSize: fontSize,
              showNikud: showNikud,
              sefariaRef: sefariaRef,
            );
          },
          loading: () => const _LoadingView(),
          error: (error, stack) => const _ErrorView(),
        ),
      ),
    );
  }
}

/// Maps [sefariaRef] to its [CurriculumId] via the pre-built [ContentIndex].
/// Returns null when the ref is not found or the storage key is unrecognised.
CurriculumId? _curriculumIdForRef(String sefariaRef, ContentIndex index) {
  final item = index.lookup(sefariaRef);
  if (item == null) return null;
  return CurriculumId.fromStorageKey(item.curriculumId);
}

/// Loading view with spinner and message.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.loadingText),
        ],
      ),
    );
  }
}

/// Message shown when text is unavailable (not cached and API unreachable).
class _OfflineMessage extends StatelessWidget {
  const _OfflineMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.textReaderTextUnavailableTitle,
              style: AppTextStyles.titleMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.textReaderCheckConnection,
              style: AppTextStyles.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view.
class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.textReaderFailedToLoad,
            style: AppTextStyles.titleMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.textReaderCheckConnection,
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Main text content view redesigned as a learning reader.
class _TextContentView extends StatelessWidget {
  const _TextContentView({
    required this.textContent,
    required this.fontSize,
    required this.showNikud,
    required this.sefariaRef,
  });

  final TextContent textContent;
  final FontSize fontSize;
  final bool showNikud;
  final String sefariaRef;

  @override
  Widget build(BuildContext context) {
    final segments = textContent.segments;
    final showSegmentNumbers =
        segments.length > 1 && segments.any((s) => s.number != null);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (textContent.hebrewText.isNotEmpty) ...[
                  _ReaderSectionCard(
                    label: AppLocalizations.of(context)!.textReaderHebrewTab,
                    labelBackground: AppColors.statusDanger,
                    alignLabelRight: false,
                    child: _NumberedSegmentColumn(
                      segments: segments,
                      isHebrew: true,
                      showNumbers: showSegmentNumbers,
                      showNikud: showNikud,
                      baseStyle: AppTextStyles.hebrewBodyLarge.copyWith(
                        fontSize: 26 * fontSize.multiplier,
                        height: 1.65,
                        color: AppTheme.brandInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppTheme.brandOutline.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 22,
                      color: AppTheme.brandBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Divider(
                        color: AppTheme.brandOutline.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (textContent.englishText.isNotEmpty) ...[
                  _ReaderSectionCard(
                    label: AppLocalizations.of(context)!.textReaderEnglishTab,
                    labelBackground: AppTheme.brandBlue,
                    alignLabelRight: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NumberedSegmentColumn(
                          segments: segments,
                          isHebrew: false,
                          showNumbers: showSegmentNumbers,
                          showNikud: showNikud,
                          baseStyle: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 16 * fontSize.multiplier,
                            height: 1.55,
                            color: AppTheme.brandInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceF5,
            border: Border(
              top: BorderSide(
                color: AppTheme.brandOutline.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: _CompletionSection(sefariaRef: sefariaRef),
        ),
      ],
    );
  }
}

/// Renders a list of [TextSegment]s — one paragraph per segment with a
/// small leading number badge when [showNumbers] is true.
///
/// Hebrew side uses gematriya (`א`, `ב`, …); English side uses Arabic
/// numerals (`1`, `2`, …). The number is visually distinct (smaller,
/// brand-blue, slight badge background) so it reads as a verse marker
/// rather than text. Only the number itself is shown — no leading
/// "Pasuk" / "Mishna" / etc. label.
class _NumberedSegmentColumn extends StatelessWidget {
  const _NumberedSegmentColumn({
    required this.segments,
    required this.isHebrew,
    required this.showNumbers,
    required this.showNikud,
    required this.baseStyle,
  });

  final List<TextSegment> segments;
  final bool isHebrew;
  final bool showNumbers;
  final bool showNikud;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) {
      final t = isHebrew ? s.hebrewText : s.englishText;
      return t.isNotEmpty;
    }).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: isHebrew
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _SegmentParagraph(
            segment: visible[i],
            isHebrew: isHebrew,
            showNumber: showNumbers && visible[i].number != null,
            showNikud: showNikud,
            baseStyle: baseStyle,
          ),
          if (i < visible.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SegmentParagraph extends StatelessWidget {
  const _SegmentParagraph({
    required this.segment,
    required this.isHebrew,
    required this.showNumber,
    required this.showNikud,
    required this.baseStyle,
  });

  final TextSegment segment;
  final bool isHebrew;
  final bool showNumber;
  final bool showNikud;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    var text = isHebrew ? segment.hebrewText : segment.englishText;
    if (isHebrew && !showNikud) {
      text = HebrewUtils.stripNikud(text);
    }

    final spans = <InlineSpan>[];
    if (showNumber && segment.number != null) {
      final marker = isHebrew
          ? Gematriya.forNumber(segment.number!)
          : segment.number!.toString();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: isHebrew
                ? const EdgeInsetsDirectional.only(start: 6)
                : const EdgeInsetsDirectional.only(end: 6),
            child: _VerseNumberBadge(marker: marker),
          ),
        ),
      );
    }
    spans.add(TextSpan(text: text, style: baseStyle));

    return Text.rich(
      TextSpan(children: spans, style: baseStyle),
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      textAlign: TextAlign.start,
    );
  }
}

class _VerseNumberBadge extends StatelessWidget {
  const _VerseNumberBadge({required this.marker});

  final String marker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.brandBlueSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        marker,
        style: const TextStyle(
          color: AppTheme.brandBlueDeep,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ReaderSectionCard extends StatelessWidget {
  const _ReaderSectionCard({
    required this.label,
    required this.labelBackground,
    required this.child,
    this.alignLabelRight = false,
  });

  final String label;
  final Color labelBackground;
  final Widget child;
  final bool alignLabelRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandInk.withValues(alpha: 0.04),
                blurRadius: 11,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppTheme.brandOutline.withValues(alpha: 0.45),
            ),
          ),
          child: child,
        ),
        Positioned(
          top: -12,
          left: alignLabelRight ? null : 0,
          right: alignLabelRight ? 0 : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: labelBackground,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: labelBackground.withValues(alpha: 0.26),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                // AUD-content_browsing-08: theme's onPrimary token instead
                // of a raw Colors.white literal (see FilledButton fix below
                // in this file / error_display.dart / app_error_view.dart
                // for the same pattern).
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Next distinct daily-task item in [tasks] after any entries that share
/// [currentRef] (same reader URL).
DailyTask? _nextDailyTaskAfter(List<DailyTask> tasks, String currentRef) {
  final firstIdx = tasks.indexWhere(
    (t) => t.contentItemSefariaRef == currentRef,
  );
  if (firstIdx < 0) return null;
  var i = firstIdx;
  while (i < tasks.length && tasks[i].contentItemSefariaRef == currentRef) {
    i++;
  }
  if (i >= tasks.length) return null;
  return tasks[i];
}

/// Like [_nextDailyTaskAfter] but skips a SET of just-completed refs — used by
/// daf-atomic completion, where one mark clears both amudim of a daf, so the
/// next task must skip past every ref in the marked daf.
DailyTask? _nextDailyTaskAfterRefs(List<DailyTask> tasks, Set<String> refs) {
  final firstIdx = tasks.indexWhere(
    (t) => refs.contains(t.contentItemSefariaRef),
  );
  if (firstIdx < 0) return null;
  for (var i = firstIdx + 1; i < tasks.length; i++) {
    if (!refs.contains(tasks[i].contentItemSefariaRef)) return tasks[i];
  }
  return null;
}

/// Mark completion section. Resolves the curriculum + stage for this sefariaRef
/// from today's scheduled tasks, then records the completion directly via
/// [markCompletionUseCaseProvider] and invalidates dashboard providers so
/// progress, streak, points, and daily tasks all refresh.
class _CompletionSection extends ConsumerStatefulWidget {
  const _CompletionSection({required this.sefariaRef});

  final String sefariaRef;

  @override
  ConsumerState<_CompletionSection> createState() => _CompletionSectionState();
}

class _CompletionSectionState extends ConsumerState<_CompletionSection> {
  bool _saving = false;

  /// The content refs to complete for [task]. On a COARSE-paced track
  /// (paceGranularity = daf/perek/seif) this returns every leaf of the current
  /// coarse unit — the daf's amudim (e.g. 2a + 2b) — so one mark completes the
  /// whole daf. On a fine/leaf-paced track it returns just the current ref.
  Future<List<String>> _refsToMark(DailyTask task) async {
    final goal = await ref
        .read(userDatabaseProvider)
        .goalDao
        .getGoalByTrack(task.trackId);
    final isCoarse =
        PaceGranularity.fromStorageKey(goal?.paceGranularity) != null;
    if (!isCoarse) return [widget.sefariaRef];
    final items = await ref.read(
      curriculumContentProvider(task.curriculumId).future,
    );
    return coarseUnitLeafRefs(items, widget.sefariaRef);
  }

  Future<void> _handleComplete(
    DailyTask task,
    String trackType, {
    required ResolvedSession session,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final tasksBefore = await ref.read(allDailyTasksProvider.future);

      // Phase 2a — daf-atomic marking: on a COARSE-paced track (daf/perek/seif)
      // one mark completes the WHOLE coarse unit (e.g. both amudim 2a+2b of a
      // daf), because the daf — not the amud — is the unit the learner marks.
      // The primary ref is marked first (drives the celebration); siblings are
      // marked in the same action. Each amud stays an independent completion row
      // (idempotent), so points/siyum/sync are unchanged — just one tap.
      final markRefs = await _refsToMark(task);
      final nextAfterComplete = _nextDailyTaskAfterRefs(
        tasksBefore,
        markRefs.toSet(),
      );

      // H1 fix: route the live completion write through MarkLiveCompletionUseCase
      // so the domain guard (TutorWriteForbiddenException) is enforced at the
      // application layer — not just by the UI button being disabled.
      // This ensures any future call site (keyboard shortcut, notification action,
      // etc.) that bypasses the UI still hits the domain boundary.
      // AUD-content_browsing-03: inject analytics so tutor_live_mark_blocked
      // (W7.11) actually fires when the domain guard rejects a tutor
      // session — without this, `_analytics` stays null inside the use
      // case and the dashboard-visibility event silently never fires.
      final markLiveUseCase = MarkLiveCompletionUseCase<MarkCompletionResult>(
        session: session,
        analytics: ref.read(analyticsServiceProvider),
      );
      final completionUseCase = ref.read(markCompletionUseCaseProvider);

      final results = <MarkCompletionResult>[];
      for (final markRef in markRefs) {
        results.add(
          await markLiveUseCase.call(
            () => completionUseCase(
              CompletionRequest(
                curriculumId: task.curriculumId.storageKey,
                sefariaRef: markRef,
                stageId: task.stageOrder,
                trackType: trackType,
              ),
            ),
          ),
        );
      }
      // Aggregate milestone unlocks across every amud marked in this action.
      final newUnlocks = [for (final r in results) ...r.newMilestoneUnlocks];

      // Signal all completion-aware providers to rebuild (Story 26.13 — DNI-356).
      // Incrementing completionCommittedProvider replaces 14 direct
      // ref.invalidate() calls: each consumer now watches this counter and
      // re-fetches automatically on every new commit.
      ref.read(completionCommittedProvider.notifier).increment();

      if (mounted) {
        setState(() => _saving = false);
      }

      if (mounted) {
        final userMode = ref.read(dashboardUserModeProvider).asData?.value;
        if (userMode == ProfileMode.child && newUnlocks.isNotEmpty) {
          await AchievementUnlockCelebration.showForUnlockedMilestones(
            context: context,
            ref: ref,
            newUnlocks: newUnlocks,
          );
        }
      }

      if (mounted && nextAfterComplete != null) {
        await context.router.replace(
          TextDisplayRoute(sefariaRef: nextAfterComplete.contentItemSefariaRef),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.markedComplete),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on TutorWriteForbiddenException {
      // W6.19: Catch the domain-layer guard and surface a friendly dialog
      // explaining the permission boundary (FR-3 / FR-6.2).
      if (mounted) {
        setState(() => _saving = false);
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            return AlertDialog(
              icon: const Icon(
                Icons.school_rounded,
                color: AppColors.goldAmber, // tutor accent
                size: 32,
              ),
              title: Text(l10n.tutorWriteForbiddenTitle),
              content: Text(l10n.tutorWriteForbiddenMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.actionOk),
                ),
              ],
            );
          },
        );
      }
    } on Exception catch (e, st) {
      // Typed so a programming-error Error subtype (TypeError/StateError)
      // escaping the mark-completion path propagates to the zone's
      // uncaught-error handler instead of being shown as an ordinary
      // "Could not save" snackbar, same as any other expected write
      // failure (AUD-content_browsing-09, EH-4).
      AppLogger.instance.error(
        event: 'Failed to mark completion',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotSave(e.toString()),
            ),
            backgroundColor: AppTheme.brandWarningDeep,
          ),
        );
      }
    }
  }

  // W6.15/W6.17 / WS3.3e (DEC-21): Returns true only when the current user
  // is *actively viewing a talmid's profile context* (i.e. has passed the
  // TutorPinEntryGate for a specific child). When true, live-mark actions
  // are disabled (FR-3, FR-6.2).
  //
  // Fix for DEC-21 dual-role bug: previously checked incomingTutorGrantsProvider,
  // which returned true whenever the user had ANY active grant — causing a tutor
  // who also has their own adult profile to have live-mark wrongly disabled on
  // their *own* profile. The correct gate is the active selection provider,
  // which is non-null only while inside a specific talmid's context.
  bool _isTutorSession(WidgetRef ref) {
    return ref.watch(activeTutoredProfileSelectionProvider) != null;
  }

  // H1: Build a ResolvedSession that reflects the current user's role so
  // _handleComplete can route through MarkLiveCompletionUseCase.
  // The session only needs to carry the correct isTutorSession flag — the
  // profile/grant details are not required for the domain guard.
  ResolvedSession _sessionForCurrentUser(WidgetRef ref, bool isTutor) {
    if (isTutor) {
      // L3: use the real active tutored selection (carries the talmid's
      // profile, grant id, and the parent-configured permissions) instead of
      // an empty placeholder. Falls back to a minimal selection only if the
      // provider is somehow null while isTutor is true (should not happen,
      // since isTutor is derived from the same provider).
      final selection = ref.read(activeTutoredProfileSelectionProvider);
      return ResolvedSession.forTutor(
        selection:
            selection ??
            const TutoredProfileSelection(
              profileId: '',
              ownerUid: '',
              grantId: '',
              permissions: TutorPermissions(),
            ),
      );
    }
    return ResolvedSession.forOwner(
      selection: const OwnProfileSelection(profileId: '', ownerUid: ''),
      isChildMode: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);

    return dailyTasksAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.brandWarning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              )!.unableToLoadCompletionContext(e.toString()),
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.brandInkMuted,
              ),
            ),
          ),
        ],
      ),
      data: (tasks) {
        final matches = tasks.where(
          (t) => t.contentItemSefariaRef == widget.sefariaRef,
        );
        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        final task = matches.first;
        final nextTask = _nextDailyTaskAfter(tasks, widget.sefariaRef);
        final trackTypeAsync = ref.watch(
          trackStorageKeyForTrackIdProvider(task.trackId),
        );
        return trackTypeAsync.when(
          loading: () => const SizedBox(
            height: 44,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (trackType) {
            final isCompletedByOrderAsync = ref.watch(
              isStageCompletedProvider((
                sefariaRef: widget.sefariaRef,
                stageId: task.stageOrder,
                trackType: trackType,
              )),
            );
            final isCompletedByDefinitionIdAsync = ref.watch(
              isStageCompletedProvider((
                sefariaRef: widget.sefariaRef,
                stageId: task.stageDefinitionId,
                trackType: trackType,
              )),
            );
            final isDone =
                (isCompletedByOrderAsync.asData?.value ?? false) ||
                (isCompletedByDefinitionIdAsync.asData?.value ?? false);

            final nextLabel =
                AppLocalizations.of(context)?.textReaderNextDailyTask ??
                'Next daily task';

            // W6.17: Check if we are in a tutor session and disable live mark.
            final isTutor = _isTutorSession(ref);
            final l10n = AppLocalizations.of(context)!;

            // R2: SafeArea(top:false) so the mark-complete / next-task buttons
            // are never clipped by the system navigation-bar inset at the bottom.
            return SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // W6.17/W6.18: Wrap in Tooltip when disabled due to tutor mode.
                  Tooltip(
                    // W6.18: Tooltip text — shown only when the button is
                    // disabled for tutor reasons (not for "already done").
                    message: isTutor ? l10n.tutorCannotMarkLiveCompletion : '',
                    child: FilledButton(
                      // W6.17: Disable for tutors regardless of isDone state.
                      // H1: session is passed so _handleComplete routes through
                      // MarkLiveCompletionUseCase for domain-layer enforcement.
                      onPressed: (_saving || isDone || isTutor)
                          ? null
                          : () => _handleComplete(
                              task,
                              trackType,
                              session: _sessionForCurrentUser(ref, isTutor),
                            ),
                      style: FilledButton.styleFrom(
                        // W6.17: When in tutor mode, show a muted amber
                        // colour to visually communicate the disabled state.
                        backgroundColor: isTutor
                            ? AppColors.goldAmber.withValues(alpha: 0.3)
                            : isDone
                            ? AppTheme.brandGoldDeep
                            : AppTheme.brandBlue,
                        // AUD-content_browsing-08: theme's onPrimary token
                        // (matches error_display.dart / app_error_view.dart)
                        // instead of a raw Colors.white literal — onPrimary
                        // is white in both the light and dark theme today,
                        // but repaints if that ever changes.
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: isTutor ? 0 : 2,
                        disabledBackgroundColor: isTutor
                            ? AppColors.goldAmber.withValues(alpha: 0.2)
                            : null,
                        disabledForegroundColor: isTutor
                            ? AppColors.goldAmber.withValues(alpha: 0.7)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.brandCreamCard,
                              ),
                            )
                          else
                            Icon(
                              // W6.17: When tutor, show a school/lock icon.
                              isTutor
                                  ? Icons.school_rounded
                                  : isDone
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                          const SizedBox(width: 10),
                          Text(
                            isTutor
                                ? l10n.markCompleteTutorUnavailable
                                : isDone
                                ? l10n.markCompleteCompletedStage(
                                    domainTermLabels(
                                      ref,
                                    ).resolveStoredStageName(task.stageName),
                                  )
                                : l10n.markComplete,
                            style: const TextStyle(
                              fontSize: 31 / 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (nextTask != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.router.replace(
                        TextDisplayRoute(
                          sefariaRef: nextTask.contentItemSefariaRef,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        nextLabel,
                        style: const TextStyle(
                          fontSize: 31 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: BorderSide(
                          color: AppTheme.brandBlue.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
