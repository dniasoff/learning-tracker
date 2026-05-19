import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/core/widgets/scrollable_step_body.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/goal_helpers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class SelfPacedGoalStep extends ConsumerStatefulWidget {
  const SelfPacedGoalStep({
    required this.curriculumId,
    required this.studyDays,
    required this.onComplete,
    super.key,
  });

  final CurriculumId curriculumId;
  final Map<int, String> studyDays;
  final ValueChanged<GoalEntity?> onComplete;

  @override
  ConsumerState<SelfPacedGoalStep> createState() => _SelfPacedGoalStepState();
}

class _SelfPacedGoalStepState extends ConsumerState<SelfPacedGoalStep> {
  int _paceValue = 1;
  String _paceUnit = 'per_week';
  DateTime? _deadline;
  String _mode = 'pace';
  late String _paceGranularity;

  @override
  void initState() {
    super.initState();
    final daily =
        CurriculumDefaults.defaultDailyTargets[widget.curriculumId] ?? 1;
    _paceValue = (daily * 7).clamp(1, 99);
    final now = DateTimeFactory.nowLocal();
    _deadline = DateTime(now.year, now.month, now.day);
    _paceGranularity = _opts.defaultKey;
  }

  PaceUnitOptions get _opts => paceUnitOptionsFor(widget.curriculumId);

  LevelLabels get _paceUnitLevel => _opts.levelFor(_paceGranularity);

  String _unitSingular({required bool useHebrew}) =>
      _paceUnitLevel.inLanguage(useHebrew: useHebrew);

  String _unitPlural({required bool useHebrew}) =>
      _paceUnitLevel.inLanguage(useHebrew: useHebrew, plural: true);

  String _formatDate(DateTime value, {required bool useHebrew}) {
    if (useHebrew) {
      return HebrewCalendarUtils.gregorianToHebrew(value.toLocal());
    }
    return HebrewCalendarUtils.formatEnglishDate(
      value,
      locale: Localizations.localeOf(context).toString(),
    );
  }

  int _countScopeInLearningUnit(
    List<ContentItem>? scopedContent,
    int leafCountFallback,
  ) {
    final isCoarse = _opts.hasChoice && _paceGranularity != _opts.fineKey;
    if (!isCoarse) return leafCountFallback;
    if (scopedContent == null) return leafCountFallback;
    final keys = <String>{};
    for (final item in scopedContent) {
      if (!item.isLeaf) continue;
      final key = item.level4 != null
          ? '${item.level1}|${item.level2}|${item.level3}'
          : item.level3 != null
          ? '${item.level1}|${item.level2}'
          : item.level2 != null
          ? item.level1
          : item.sefariaRef;
      keys.add(key);
    }
    return keys.isEmpty ? leafCountFallback : keys.length;
  }

  String _projectedFinishLabel(bool useHebrew, int totalScopeItems) {
    if (totalScopeItems <= 0 || _paceValue <= 0) {
      return _formatDate(DateTimeFactory.nowLocal(), useHebrew: useHebrew);
    }
    final weeklyPace = _paceUnit == 'per_day' ? _paceValue * 7 : _paceValue;
    final days = (totalScopeItems / weeklyPace * 7).ceil();
    final projected = DateTimeFactory.nowLocal().add(Duration(days: days));
    return _formatDate(projected, useHebrew: useHebrew);
  }

  Future<void> _pickDeadline() async {
    final useHebrew = ref.read(useHebrewDateProvider);
    if (useHebrew) {
      final picked = await HebrewDatePicker.show(
        context,
        initialDate: _deadline,
      );
      if (picked != null) {
        setState(() {
          _deadline = picked;
          _mode = 'deadline';
        });
      }
      return;
    }
    final now = DateTimeFactory.nowLocal();
    final picked = await showLearningAppDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
        _mode = 'deadline';
      });
    }
  }

  Future<void> _activateDeadlineMode() async {
    setState(() => _mode = 'deadline');
    await _pickDeadline();
  }

  String _formatUnitForEstimate(int perStudyDay, {required bool useHebrew}) {
    final s = perStudyDay == 1
        ? _unitSingular(useHebrew: useHebrew)
        : _unitPlural(useHebrew: useHebrew);
    return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
  }

  /// Derives an explicit weekly pace from the current deadline + scope + study
  /// day pattern.  Delegates to the top-level [derivePaceFromDeadline] in
  /// goal_helpers.dart so the logic is directly testable without the widget.
  ({int paceValue, String pacePeriod}) _derivedPaceFromDeadline({
    required DateTime deadline,
    required int totalScopeItems,
    required int studyDaysInWindow,
  }) => derivePaceFromDeadline(
    studyDays: widget.studyDays,
    totalScopeItems: totalScopeItems,
    studyDaysInWindow: studyDaysInWindow,
  );

  void _continue() {
    final now = DateTimeFactory.nowUtc();
    // Seed the description with the curriculum's display name so that Edit
    // Track's "Track Name" field is pre-filled on new tracks (B4 fix).
    final defaultDescription = curriculumLabelText(
      ref,
      curriculum: widget.curriculumId,
    );
    if (_mode == 'deadline') {
      if (_deadline == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.goalPickDeadlineFirst),
          ),
        );
        return;
      }
      // F-M2: do not proceed while the scope count is still loading — the
      // derived pace would use the fallback (120) and produce a wildly wrong
      // result for large or small curricula.
      final scopeCountAsync = ref.read(
        scopedItemCountProvider(widget.curriculumId),
      );
      if (scopeCountAsync.isLoading) return;
      // Derive an explicit pace from the deadline + scope so that every
      // self-paced GoalEntity carries paceValue+pacePeriod (architecture §10.3).
      // The deadline mode stores BOTH the target date AND an explicit pace;
      // the projection uses the pace; the goal edit screen shows the deadline.
      final totalScopeItems = scopeCountAsync.asData?.value ?? 120;
      final start = localDateOnlyFromDt(DateTimeFactory.nowLocal());
      final end = localDateOnlyFromDt(_deadline!.toLocal());
      final studyDaysInWindow = countStudyDaysInInclusiveMapRange(
        widget.studyDays,
        start,
        end,
      );
      final derived = _derivedPaceFromDeadline(
        deadline: _deadline!,
        totalScopeItems: totalScopeItems,
        studyDaysInWindow: studyDaysInWindow,
      );
      final useHebrew = ref.read(useHebrewDateProvider);
      widget.onComplete(
        GoalEntity(
          curriculumId: widget.curriculumId,
          targetPercent: 100,
          goalType: 'deadline',
          targetDate: _deadline!.toUtc(),
          dateType: useHebrew ? 'hebrew' : 'gregorian',
          paceValue: derived.paceValue,
          pacePeriod: derived.pacePeriod,
          description: defaultDescription,
          paceGranularity: PaceGranularity.fromStorageKey(_paceGranularity),
          rawLearningUnit: _paceGranularity,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    widget.onComplete(
      GoalEntity(
        curriculumId: widget.curriculumId,
        targetPercent: 100,
        goalType: 'pace',
        paceValue: _paceValue,
        pacePeriod: _paceUnit,
        description: defaultDescription,
        paceGranularity: PaceGranularity.fromStorageKey(_paceGranularity),
        rawLearningUnit: _paceGranularity,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final useHebrew = ref.watch(useHebrewDateProvider);
    final useHebrewTerms = domainTermLabels(ref).isHebrew;
    final scopeCountAsync = ref.watch(
      scopedItemCountProvider(widget.curriculumId),
    );
    final scopedContentAsync = ref.watch(
      scopedCurriculumContentProvider(widget.curriculumId),
    );
    final start = localDateOnlyFromDt(DateTimeFactory.nowLocal());
    final end = _deadline != null
        ? localDateOnlyFromDt(_deadline!.toLocal())
        : null;
    final studyDaysInWindow = end != null
        ? countStudyDaysInInclusiveMapRange(widget.studyDays, start, end)
        : 0;
    final scopeLoading = scopeCountAsync.isLoading;
    final totalScopeItems = scopeCountAsync.asData?.value ?? 120;
    final totalScopeInLearningUnit = _countScopeInLearningUnit(
      scopedContentAsync.asData?.value,
      totalScopeItems,
    );
    final itemsPerStudyDay = studyDaysInWindow > 0
        ? (totalScopeItems / studyDaysInWindow).ceil().clamp(1, 999999)
        : 0;

    final opts = _opts;
    final paceCard = PaceGoalCard(
      isActive: _mode == 'pace',
      paceValue: _paceValue,
      pacePeriod: _paceUnit,
      unitSingular: _unitSingular(useHebrew: useHebrewTerms),
      unitPlural: _unitPlural(useHebrew: useHebrewTerms),
      hasUnitChoice: opts.hasChoice,
      coarseKey: opts.coarseKey,
      coarseLabel: opts.coarse.inLanguage(
        useHebrew: useHebrewTerms,
        plural: true,
      ),
      fineKey: opts.fineKey,
      fineLabel: opts.fine?.inLanguage(useHebrew: useHebrewTerms, plural: true),
      paceGranularity: _paceGranularity,
      projectedFinishLabel: _projectedFinishLabel(
        useHebrew,
        totalScopeInLearningUnit,
      ),
      onPaceDecrease: () => setState(() {
        _mode = 'pace';
        if (_paceValue > 1) _paceValue -= 1;
      }),
      onPaceIncrease: () => setState(() {
        _mode = 'pace';
        _paceValue += 1;
      }),
      onPaceUnitChanged: (v) => setState(() {
        _mode = 'pace';
        _paceUnit = v;
      }),
      onPaceGranularityChanged: (v) => setState(() {
        _mode = 'pace';
        _paceGranularity = v;
      }),
    );

    final deadlineCard = DeadlineGoalCard(
      isActive: _mode == 'deadline',
      deadline: _deadline,
      dateLabel: _formatDate(
        _deadline ?? DateTimeFactory.nowLocal(),
        useHebrew: useHebrew,
      ),
      useHebrew: useHebrew,
      studyDaysInWindow: studyDaysInWindow,
      itemsPerStudyDay: itemsPerStudyDay,
      totalScopeItems: totalScopeItems,
      scopeIsLoading: scopeLoading,
      unitLabel: _formatUnitForEstimate(
        itemsPerStudyDay,
        useHebrew: useHebrewTerms,
      ),
      onTapDate: _pickDeadline,
      l10n: l10n,
    );

    return ScrollableStepBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.goalPaceOrDeadlineTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.goalPaceOrDeadlineSubtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          _mode == 'pace'
              ? paceCard
              : BlurInactiveGoalOption(
                  hint: l10n.addTrackGoalTapToUsePace,
                  onTap: () => setState(() => _mode = 'pace'),
                  child: paceCard,
                ),
          const SizedBox(height: 12),
          _mode == 'deadline'
              ? deadlineCard
              : BlurInactiveGoalOption(
                  hint: l10n.addTrackGoalTapToUseDeadline,
                  onTap: () => unawaited(_activateDeadlineMode()),
                  child: deadlineCard,
                ),
          const SizedBox(height: 24),
          FilledButton(
            // F-M2: disable Continue while scope is loading in deadline mode so
            // the user cannot proceed with the fallback (120) pace.
            onPressed: (_mode == 'deadline' && scopeLoading) ? null : _continue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(l10n.actionContinue),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => widget.onComplete(null),
            child: Text(l10n.actionSkipForNow),
          ),
        ],
      ),
    );
  }
}
