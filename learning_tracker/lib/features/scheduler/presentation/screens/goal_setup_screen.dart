import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';
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
    _paceGranularity = _defaultUnit;
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

  /// Whether the curriculum supports a unit picker on the goal screen.
  bool get _showUnitPicker =>
      widget.curriculumId == CurriculumId.bavli ||
      widget.curriculumId == CurriculumId.yerushalmi ||
      _isPasukPerekCurriculum;

  /// Plural unit label shown in the pace input ("Pesukim per day", not
  /// "Pasuk per day") — the count is always > 1 in practice.
  String get _unitDisplayLabel {
    if (_paceGranularity == 'daf') return 'Dafim';
    if (_paceGranularity == 'amud') return 'Amudim';
    if (_paceGranularity == 'perek') return 'Perakim';
    if (_paceGranularity == 'pasuk') return 'Pesukim';
    return CurriculumLabels.leaf(widget.curriculumId).enPlural;
  }

  String _formatDateLine(DateTime? d, {required bool useHebrew}) {
    if (d == null) return 'Tap to choose a date';
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
          decoration: const InputDecoration(
            labelText: 'Occasion (optional)',
            hintText: 'e.g., Bar Mitzvah, Yahrzeit, Siyum',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        // Daily pace summary (deadline mode)
        if (_targetDate != null && widget.totalItems != null) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final daysRemaining = _targetDate!.difference(_now()).inDays;
              if (daysRemaining <= 0) {
                return Text(
                  'Deadline has passed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              final remainingItems = (widget.totalItems! * _targetPercent / 100)
                  .ceil();
              final pace = (remainingItems / daysRemaining).ceil();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '~$pace items per day',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$remainingItems items in $daysRemaining days',
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
    final unitLabel = _unitDisplayLabel;
    final perLabel = _paceUnit == 'per_day' ? 'per day' : 'per week';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pace value input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _paceValue.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '$unitLabel $perLabel',
                  helperText:
                      'How many ${unitLabel.toLowerCase()} ${_paceUnit == 'per_day' ? 'per day' : 'per week'}?',
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed > 0) {
                    setState(() => _paceValue = parsed);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            // Per day / per week selector
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
          ],
        ),
        // Projected completion card
        if (widget.totalItems != null) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final remainingItems = (widget.totalItems! * _targetPercent / 100)
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
                        'Projected completion: $formattedDate',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$remainingItems ${unitLabel.toLowerCase()} in ~$daysToComplete days',
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
                    widget.totalItems != null
                        ? 'Complete ${_targetPercent.round()}% of the material (${(widget.totalItems! * _targetPercent / 100).ceil()} of ${widget.totalItems!} items)'
                        : 'Complete ${_targetPercent.round()}% of the material',
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
                      'Learning unit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: _isPasukPerekCurriculum
                          ? [
                              ButtonSegment(
                                value: 'perek',
                                label: Text(
                                  AppLocalizations.of(context)!.unitPerakim,
                                ),
                              ),
                              ButtonSegment(
                                value: 'pasuk',
                                label: Text(
                                  AppLocalizations.of(context)!.unitPesukim,
                                ),
                              ),
                            ]
                          : [
                              ButtonSegment(
                                value: 'amud',
                                label: Text(
                                  AppLocalizations.of(context)!.unitAmudim,
                                ),
                              ),
                              ButtonSegment(
                                value: 'daf',
                                label: Text(
                                  AppLocalizations.of(context)!.unitDafim,
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
                      'Learn at your own pace with no time pressure.',
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
            onPressed: _submit,
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
