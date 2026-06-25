import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Screen for creating or editing a learning goal.
///
/// Thin Scaffold wrapper around [GoalSetupForm]. The form is exposed
/// separately so it can be embedded inline (e.g. inside the Add Track
/// flow page view) without nesting Scaffolds.
class GoalSetupScreen extends StatelessWidget {
  final CurriculumId curriculumId;
  final GoalEntity? existingGoal;
  final int? totalItems;

  const GoalSetupScreen({
    super.key,
    required this.curriculumId,
    this.existingGoal,
    this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: existingGoal != null
              ? AppLocalizations.of(context)!.goalEditTitle
              : AppLocalizations.of(context)!.goalNewTitle,
        ),
      ),
      body: SafeArea(
        top: false,
        child: GoalSetupForm(
          curriculumId: curriculumId,
          existingGoal: existingGoal,
          totalItems: totalItems,
          onComplete: (result) => Navigator.of(context).pop(result),
        ),
      ),
    );
  }
}

/// Form body for goal setup. Embeddable — no Scaffold or AppBar.
///
/// Calls [onComplete] when the user submits the form.
class GoalSetupForm extends ConsumerStatefulWidget {
  final CurriculumId curriculumId;
  final GoalEntity? existingGoal;
  final int? totalItems;
  final ValueChanged<GoalEntity> onComplete;
  final String? submitLabel;

  const GoalSetupForm({
    super.key,
    required this.curriculumId,
    required this.onComplete,
    this.existingGoal,
    this.totalItems,
    this.submitLabel,
  });

  @override
  ConsumerState<GoalSetupForm> createState() => _GoalSetupFormState();
}

class _GoalSetupFormState extends ConsumerState<GoalSetupForm> {
  late double _targetPercent;
  DateTime? _targetDate;
  late TextEditingController _descriptionController;

  // Pace mode fields
  late String _goalType;
  late int _paceValue;
  String _paceUnit = 'per_day';
  late String _paceGranularity;

  @override
  void initState() {
    super.initState();
    _targetPercent = widget.existingGoal?.targetPercent ?? 100.0;
    _targetDate = widget.existingGoal?.targetDate;
    _descriptionController = TextEditingController(
      text: widget.existingGoal?.description ?? '',
    );
    _goalType = widget.existingGoal?.goalType ?? 'deadline';
    _paceValue =
        widget.existingGoal?.paceValue ??
        (CurriculumDefaults.defaultDailyTargets[widget.curriculumId] ?? 1);
    _paceUnit = widget.existingGoal?.pacePeriod ?? 'per_day';
    // Restore the saved learning unit when editing (e.g. daf for a daf-paced
    // Bavli track) — without this the picker always reset to _defaultUnit
    // ('amud' for Bavli), so editing a daf goal wrongly showed amudim.
    _paceGranularity = widget.existingGoal?.paceGranularityKey ?? _defaultUnit;
  }

  /// Whether this curriculum's pace is set in Pasuk/Perek units (Tanakh
  /// family + Mussar). For these the user can pick between counting
  /// pesukim per day or perakim per day.
  bool get _isPasukPerekCurriculum =>
      widget.curriculumId == CurriculumId.chumash ||
      widget.curriculumId == CurriculumId.nach ||
      widget.curriculumId == CurriculumId.tanach ||
      widget.curriculumId == CurriculumId.mussar;

  /// Default learning unit based on curriculum type.
  String get _defaultUnit {
    // Bavli/Yerushalmi use Amud as smallest unit
    if (widget.curriculumId == CurriculumId.bavli ||
        widget.curriculumId == CurriculumId.yerushalmi) {
      return 'amud';
    }
    // Tanakh + Mussar default to Perek pace (1 perek/day reads more
    // naturally than 1 pasuk/day for most learners).
    if (_isPasukPerekCurriculum) return 'perek';
    return 'item';
  }

  /// Scope total expressed in the SELECTED pace unit: the coarse-unit count
  /// (dapim/perakim) when a coarse unit (daf/perek/seif) is selected, else the
  /// leaf total. Keeps the "X of Y" count and the projected-completion estimate
  /// consistent with the chosen unit (a daf goal must read in dapim, not amudim).
  int? get _effectiveTotal {
    final isCoarse = PaceGranularity.fromStorageKey(_paceGranularity) != null;
    if (!isCoarse) return widget.totalItems;
    final coarse = ref
        .watch(scopedCoarseUnitCountProvider(widget.curriculumId))
        .asData
        ?.value;
    // Fall back to the leaf total until the coarse count is loaded (>0); keeps
    // the count sane when content isn't available yet (and in widget tests).
    return (coarse != null && coarse > 0) ? coarse : widget.totalItems;
  }

  /// Whether the curriculum supports a unit picker on the goal screen.
  bool get _showUnitPicker =>
      widget.curriculumId == CurriculumId.bavli ||
      widget.curriculumId == CurriculumId.yerushalmi ||
      _isPasukPerekCurriculum;

  /// Plural unit label shown in the pace input ("Pesukim per day", not
  /// "Pasuk per day") — the count is always > 1 in practice.
  ///
  /// Renders the Torah unit term via the shared [CurriculumLabels] control so
  /// it honours the Hebrew Terms toggle ([useHebrew]) and the nusach
  /// ([variant]) — e.g. "Dafim" → "דפים" (Hebrew) or "Dapim" (Sephardi).
  /// The granularity key (daf/amud/perek/pasuk) is matched against the
  /// curriculum's own level list so the correct [LevelLabels] is chosen;
  /// it falls back to the leaf level when the granularity has no matching
  /// level (e.g. Yerushalmi has no Amud level).
  String _unitDisplayLabel({
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    return _granularityUnitLabel(
      _paceGranularity,
      useHebrew: useHebrew,
      variant: variant,
    );
  }

  /// Resolves the plural display label for a specific pace-granularity key
  /// (daf/amud/perek/pasuk) via the variant-aware [CurriculumLabels] library,
  /// honouring both the Hebrew-terms toggle and the Ashkenazi/Sefardi nusach.
  /// Used by the unit-picker pills so they never bypass either control
  /// (e.g. Sefardi renders "Dapim", Ashkenazi "Dafim", Hebrew "דפים").
  String _granularityUnitLabel(
    String granularity, {
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    final labels = _levelForGranularity(widget.curriculumId, granularity);
    return labels.inLanguage(
      useHebrew: useHebrew,
      plural: true,
      variant: variant,
    );
  }

  /// Resolves the [LevelLabels] for a pace-granularity storage key by matching
  /// its canonical English singular (Daf/Amud/Perek/Pasuk) against the
  /// curriculum's level list. Falls back to the leaf level when no level in
  /// this curriculum corresponds to the granularity.
  LevelLabels _levelForGranularity(CurriculumId id, String granularity) {
    const granularityToEn = {
      'daf': 'Daf',
      'amud': 'Amud',
      'perek': 'Perek',
      'pasuk': 'Pasuk',
    };
    final targetEn = granularityToEn[granularity];
    if (targetEn != null) {
      final singulars = CurriculumLabels.labelsEn(id);
      final idx = singulars.indexOf(targetEn);
      if (idx >= 0) return CurriculumLabels.level(id, idx + 1);
    }
    return CurriculumLabels.leaf(id);
  }

  String _formatDateLine(DateTime? d, {required bool useHebrew}) {
    if (d == null)
      return AppLocalizations.of(context)!.goalDeadlineDatePickerHint;
    if (useHebrew) {
      return HebrewCalendarUtils.gregorianToHebrew(d.toLocal());
    }
    return HebrewCalendarUtils.formatEnglishDate(
      d,
      locale: Localizations.localeOf(context).toString(),
    );
  }

  String _formatYmdLine(DateTime d, {required bool useHebrew}) {
    if (useHebrew) {
      return HebrewCalendarUtils.gregorianToHebrew(d.toLocal());
    }
    return HebrewCalendarUtils.formatEnglishDate(
      d,
      locale: Localizations.localeOf(context).toString(),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(clockProvider);

  Future<void> _pickEnglishDate() async {
    final now = _now();
    final picked = await showLearningAppDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _targetDate = picked.toUtc());
    }
  }

  Future<void> _pickHebrewDate() async {
    final picked = await HebrewDatePicker.show(
      context,
      initialDate: _targetDate,
    );
    if (picked != null) {
      setState(() => _targetDate = picked.toUtc());
    }
  }

  void _submit() {
    final now = _now();
    widget.onComplete(
      GoalEntity(
        curriculumId: widget.curriculumId,
        targetPercent: _targetPercent,
        targetDate: _goalType == 'deadline' ? _targetDate : null,
        description: _goalType == 'deadline' ? _descriptionController.text : '',
        dateType: ref.read(useHebrewDateProvider) ? 'hebrew' : 'gregorian',
        goalType: _goalType,
        paceValue: _goalType == 'pace' ? _paceValue : null,
        pacePeriod: _goalType == 'pace' ? _paceUnit : null,
        paceGranularity: _showUnitPicker
            ? PaceGranularity.fromStorageKey(_paceGranularity)
            : null,
        rawLearningUnit: _showUnitPicker ? _paceGranularity : null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Widget _buildDeadlineSection() {
    final useHebrew = ref.watch(useHebrewDateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date selection — pick a date immediately
        Card(
          child: InkWell(
            onTap: useHebrew ? _pickHebrewDate : _pickEnglishDate,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _formatDateLine(_targetDate, useHebrew: useHebrew),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_targetDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: AppLocalizations.of(
                        context,
                      )!.goalClearDeadlineTooltip,
                      onPressed: () => setState(() => _targetDate = null),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Optional occasion/label field
        TextField(
          controller: _descriptionController,
          inputFormatters: const [TrimLeadingSpaceFormatter()],
          decoration: InputDecoration(
            // R1-(7): use l10n so Hebrew sees translated label/hint.
            labelText: AppLocalizations.of(context)!.goalDeadlineOccasionLabel,
            hintText: AppLocalizations.of(context)!.goalDeadlineOccasionHint,
            prefixIcon: const Icon(Icons.label_outline),
          ),
        ),
        // Daily pace summary (deadline mode)
        if (_targetDate != null && _effectiveTotal != null) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final daysRemaining = _targetDate!.difference(_now()).inDays;
              if (daysRemaining <= 0) {
                return Text(
                  // R1-(7): use l10n.
                  AppLocalizations.of(context)!.goalDeadlinePassed,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              final remainingItems = (_effectiveTotal! * _targetPercent / 100)
                  .ceil();
              final pace = (remainingItems / daysRemaining).ceil();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        // R1-(7): use l10n.
                        AppLocalizations.of(
                          context,
                        )!.goalDeadlinePaceItems(pace),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // R1-(7): use l10n.
                        AppLocalizations.of(context)!.goalDeadlineItemsInDays(
                          remainingItems,
                          daysRemaining,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPaceSection() {
    final useHebrew = ref.watch(useHebrewDateProvider);
    // Domain-term toggle via the shared accessor (DNI: no raw
    // useHebrewTermsProvider read outside core/labels).
    final useHebrewTerms = domainTermLabels(ref).isHebrew;
    final variant = ref.watch(currentTransliterationVariantProvider);
    final unitLabel = _unitDisplayLabel(
      useHebrew: useHebrewTerms,
      variant: variant,
    );
    // R1-(7): use l10n keys so Hebrew sees translated period labels.
    final perLabel = _paceUnit == 'per_day'
        ? AppLocalizations.of(context)!.pacePerDay
        : AppLocalizations.of(context)!.pacePerWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pace value input.
        //
        // R1v2-(5): the per-day/per-week SegmentedButton previously shared a
        // horizontal Row with the field, taking its intrinsic width and
        // squeezing the Expanded field so the (often long, e.g. "Amudim Per
        // day" / "כמה עמודים ביום?") labelText + helperText were clipped —
        // worse at font scale 1.3. The selector now sits on its own row BELOW
        // the field so the field spans the full width, and helperMaxLines lets
        // the helper wrap instead of ellipsizing. This holds for en + he at
        // font scale 1.0 and 1.3.
        TextFormField(
          initialValue: _paceValue.toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            // R1-(7): use l10n so Hebrew sees translated labels.
            labelText: AppLocalizations.of(
              context,
            )!.goalPaceInputLabel(unitLabel, perLabel),
            helperText: AppLocalizations.of(context)!.goalPaceHowMany(
              unitLabel.toLowerCase(),
              // The template already supplies the connective ("per"/"ב"), so
              // pass the BARE period noun (day/week), not the selector label
              // ("Per day") — otherwise the helper read "per Per week".
              _paceUnit == 'per_day'
                  ? AppLocalizations.of(context)!.goalPacePeriodDay
                  : AppLocalizations.of(context)!.goalPacePeriodWeek,
            ),
            // Allow the helper to wrap rather than truncate to one ellipsized
            // line at large font scales / long Hebrew strings.
            helperMaxLines: 2,
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null && parsed > 0) {
              setState(() => _paceValue = parsed);
            }
          },
        ),
        const SizedBox(height: 12),
        // Per day / per week selector — full width on its own row so it never
        // squeezes the pace field's label/helper above.
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'per_day',
              label: Text(AppLocalizations.of(context)!.pacePerDay),
            ),
            ButtonSegment(
              value: 'per_week',
              label: Text(AppLocalizations.of(context)!.pacePerWeek),
            ),
          ],
          selected: {_paceUnit},
          onSelectionChanged: (selected) {
            setState(() => _paceUnit = selected.first);
          },
        ),
        // Projected completion card
        if (_effectiveTotal != null) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final remainingItems = (_effectiveTotal! * _targetPercent / 100)
                  .ceil();
              final dailyRate = _paceUnit == 'per_day'
                  ? _paceValue.toDouble()
                  : _paceValue / 7.0;
              if (dailyRate <= 0) {
                return const SizedBox.shrink();
              }
              final daysToComplete = (remainingItems / dailyRate).ceil();
              final projectedDate = _now().add(Duration(days: daysToComplete));
              final formattedDate = _formatYmdLine(
                projectedDate,
                useHebrew: useHebrew,
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        // R1-(7): use l10n.
                        AppLocalizations.of(
                          context,
                        )!.goalPaceProjectedCompletion(formattedDate),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // R1-(7): use l10n.
                        AppLocalizations.of(context)!.goalPaceItemsInDays(
                          remainingItems,
                          unitLabel.toLowerCase(),
                          daysToComplete,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Domain-term toggle + nusach variant, read once and reused for the
    // unit-picker pills so they honour both controls (DNI: no raw
    // useHebrewTermsProvider read outside core/labels).
    final useHebrewTerms = domainTermLabels(ref).isHebrew;
    final variant = ref.watch(currentTransliterationVariantProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Target percentage slider
                  Text(
                    // R1-(7): use l10n so Hebrew sees translated text.
                    _effectiveTotal != null
                        ? AppLocalizations.of(
                            context,
                          )!.goalTargetPercentWithCount(
                            _targetPercent.round(),
                            (_effectiveTotal! * _targetPercent / 100).ceil(),
                            _effectiveTotal!,
                          )
                        : AppLocalizations.of(
                            context,
                          )!.goalTargetPercentOnly(_targetPercent.round()),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _targetPercent,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${_targetPercent.round()}%',
                    onChanged: (v) => setState(() => _targetPercent = v),
                  ),
                  const SizedBox(height: 24),
                  // Unit picker — Amud/Daf for Talmud, Pasuk/Perek for
                  // Tanakh + Mussar. Lets the user choose whether the
                  // pace count is in chapter-sized or verse-sized units.
                  if (_showUnitPicker) ...[
                    Text(
                      // R1-(7): use l10n.
                      AppLocalizations.of(context)!.goalLearningUnitLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: _isPasukPerekCurriculum
                          ? [
                              ButtonSegment(
                                value: 'perek',
                                label: Text(
                                  _granularityUnitLabel(
                                    'perek',
                                    useHebrew: useHebrewTerms,
                                    variant: variant,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: 'pasuk',
                                label: Text(
                                  _granularityUnitLabel(
                                    'pasuk',
                                    useHebrew: useHebrewTerms,
                                    variant: variant,
                                  ),
                                ),
                              ),
                            ]
                          : [
                              ButtonSegment(
                                value: 'amud',
                                label: Text(
                                  _granularityUnitLabel(
                                    'amud',
                                    useHebrew: useHebrewTerms,
                                    variant: variant,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: 'daf',
                                label: Text(
                                  _granularityUnitLabel(
                                    'daf',
                                    useHebrew: useHebrewTerms,
                                    variant: variant,
                                  ),
                                ),
                              ),
                            ],
                      selected: {_paceGranularity},
                      onSelectionChanged: (selected) {
                        setState(() => _paceGranularity = selected.first);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Goal type toggle
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'deadline',
                        label: Text(
                          AppLocalizations.of(context)!.goalTypeDeadline,
                        ),
                        icon: const Icon(Icons.calendar_today),
                      ),
                      ButtonSegment(
                        value: 'pace',
                        label: Text(AppLocalizations.of(context)!.goalTypePace),
                        icon: const Icon(Icons.speed),
                      ),
                      ButtonSegment(
                        value: 'none',
                        label: Text(
                          AppLocalizations.of(context)!.goalTypeNoDeadline,
                        ),
                        icon: const Icon(Icons.all_inclusive),
                      ),
                    ],
                    selected: {_goalType},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _goalType = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Mode-specific content
                  if (_goalType == 'deadline') _buildDeadlineSection(),
                  if (_goalType == 'pace') _buildPaceSection(),
                  if (_goalType == 'none')
                    Text(
                      // R1-(7): use l10n.
                      AppLocalizations.of(context)!.goalNoPressureLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_goalType == 'deadline' && _targetDate == null)
                ? null
                : _submit,
            child: Text(
              widget.submitLabel ??
                  (widget.existingGoal != null
                      ? AppLocalizations.of(context)!.goalUpdateButton
                      : AppLocalizations.of(context)!.goalCreateButton),
            ),
          ),
        ],
      ),
    );
  }
}
