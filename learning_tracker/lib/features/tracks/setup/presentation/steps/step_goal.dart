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
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_helpers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class SelfPacedGoalStep extends ConsumerStatefulWidget {
  const SelfPacedGoalStep({
    required this.curriculumId,
    required this.studyDays,
    required this.onComplete,
    // TS-2 fix: accept in-wizard scope selections so the item-count math is
    // driven by the selected scope, not the full curriculum total.
    this.scopeSelections,
    // TS-10 fix: accept a previously-set goal so Back+Forward navigation
    // restores the deadline/pace choice the user already made.
    this.initialGoal,
    super.key,
  });

  final CurriculumId curriculumId;
  final Map<int, String> studyDays;
  final ValueChanged<GoalEntity?> onComplete;

  /// The scope selections the user has chosen in the wizard (not yet saved to DB).
  ///
  /// When non-null and non-empty, the goal step derives its item count from
  /// these selections rather than [scopedItemCountProvider] (which reads DB
  /// scope — not yet written during the wizard flow).
  final List<ScopeEntry>? scopeSelections;

  /// A previously-set goal from the wizard state (TS-10).
  ///
  /// When non-null, the step initializes [_mode] and [_deadline] from this
  /// value so backing-and-forwarding through the wizard does not discard the
  /// user's deadline choice.
  final GoalEntity? initialGoal;

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
    _paceGranularity = _opts.defaultKey;

    // TS-10: restore deadline/mode from a previously-set goal so Back+Forward
    // navigation does not discard the user's choice.
    final prev = widget.initialGoal;
    if (prev != null &&
        prev.goalType == 'deadline' &&
        prev.targetDate != null) {
      _mode = 'deadline';
      _deadline = prev.targetDate!.toLocal();
      _paceValue = (prev.paceValue ?? (daily * 7)).clamp(1, 99);
    } else {
      _paceValue = (daily * 7).clamp(1, 99);
      final now = DateTimeFactory.nowLocal();
      _deadline = DateTime(now.year, now.month, now.day);
    }
  }

  PaceUnitOptions get _opts => paceUnitOptionsFor(widget.curriculumId);

  LevelLabels get _paceUnitLevel => _opts.levelFor(_paceGranularity);

  String _unitSingular({
    required bool useHebrew,
    required TransliterationVariant variant,
  }) => _paceUnitLevel.inLanguage(useHebrew: useHebrew, variant: variant);

  String _unitPlural({
    required bool useHebrew,
    required TransliterationVariant variant,
  }) => _paceUnitLevel.inLanguage(
    useHebrew: useHebrew,
    plural: true,
    variant: variant,
  );

  String _formatDate(DateTime value, {required bool useHebrew}) {
    if (useHebrew) {
      return HebrewCalendarUtils.gregorianToHebrew(value.toLocal());
    }
    return HebrewCalendarUtils.formatEnglishDate(
      value,
      locale: Localizations.localeOf(context).toString(),
    );
  }

  /// Counts the leaf content items that fall within the given wizard scope
  /// selections (scope level + value filters applied to [allContent]).
  ///
  /// TS-2 fix: used when [SelfPacedGoalStep.scopeSelections] is non-null so
  /// the goal step's item count reflects the scope the user chose in the wizard
  /// (not the DB-saved scope which hasn't been written yet).
  int _countItemsInWizardScope(
    List<ContentItem> allContent,
    List<ScopeEntry> selections,
  ) {
    if (selections.isEmpty) return allContent.where((i) => i.isLeaf).length;
    // Apply the first scope entry (the wizard stores a single scope level).
    final entry = selections.first;
    final scopeLevel = entry.level;
    final scopeValue = entry.value;
    return allContent.where((item) {
      if (!item.isLeaf) return false;
      switch (scopeLevel) {
        case 1:
          return item.level1 == scopeValue;
        case 2:
          return item.level2 == scopeValue;
        case 3:
          return item.level3 == scopeValue;
        default:
          return true;
      }
    }).length;
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

  String _formatUnitForEstimate(
    int perStudyDay, {
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    final s = perStudyDay == 1
        ? _unitSingular(useHebrew: useHebrew, variant: variant)
        : _unitPlural(useHebrew: useHebrew, variant: variant);
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
      // F-M2 + W6 re-review: do not proceed while the scope count is loading
      // OR in error — the derived pace would otherwise be computed against a
      // stale or wrong total, saving a wildly wrong pace for large or small
      // curricula. The button-disable in build() is the primary guard; this
      // is defence-in-depth.
      final scopeCountAsync = ref.read(
        scopedItemCountProvider(widget.curriculumId),
      );
      final totalScopeItems = scopeCountAsync.asData?.value;
      if (totalScopeItems == null) return;
      // Derive an explicit pace from the deadline + scope so that every
      // self-paced GoalEntity carries paceValue+pacePeriod (architecture §10.3).
      // The deadline mode stores BOTH the target date AND an explicit pace;
      // the projection uses the pace; the goal edit screen shows the deadline.
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
    final variant = ref.watch(currentTransliterationVariantProvider);

    // TS-2 fix: when the wizard has passed explicit scopeSelections we must
    // drive the item count from those selections (they aren't in the DB yet).
    // When no selections are provided, fall through to the DB-backed provider
    // as before (e.g. in the standalone GoalSetupScreen path).
    final wizardSelections = widget.scopeSelections;
    final scopeCountAsync = ref.watch(
      scopedItemCountProvider(widget.curriculumId),
    );
    // Full-curriculum content is always loaded so _countScopeInLearningUnit
    // can filter by learning unit within the (possibly-scoped) set.
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

    // TS-2: if wizard selections are available, compute item count from those
    // selections applied to the already-loaded content, not the DB-saved scope.
    final int totalScopeItems;
    if (wizardSelections != null &&
        wizardSelections.isNotEmpty &&
        scopedContentAsync.asData != null) {
      final allContent = scopedContentAsync.asData!.value;
      totalScopeItems = _countItemsInWizardScope(allContent, wizardSelections);
    } else {
      totalScopeItems = scopeCountAsync.asData?.value ?? 120;
    }
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
      unitSingular: _unitSingular(useHebrew: useHebrewTerms, variant: variant),
      unitPlural: _unitPlural(useHebrew: useHebrewTerms, variant: variant),
      hasUnitChoice: opts.hasChoice,
      coarseKey: opts.coarseKey,
      coarseLabel: opts.coarse.inLanguage(
        useHebrew: useHebrewTerms,
        plural: true,
        variant: variant,
      ),
      fineKey: opts.fineKey,
      fineLabel: opts.fine?.inLanguage(
        useHebrew: useHebrewTerms,
        plural: true,
        variant: variant,
      ),
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
        variant: variant,
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
          // TS-5 fix: ClipRect constrains the InkWell hit-test area in
          // BlurInactiveGoalOption to the card's visual bounds, preventing
          // it from intercepting taps on the Continue button below.
          _mode == 'deadline'
              ? deadlineCard
              : ClipRect(
                  child: BlurInactiveGoalOption(
                    hint: l10n.addTrackGoalTapToUseDeadline,
                    onTap: () => unawaited(_activateDeadlineMode()),
                    child: deadlineCard,
                  ),
                ),
          const SizedBox(height: 32),
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
        ],
      ),
    );
  }
}
