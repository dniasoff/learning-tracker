import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_form_result.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';

// Re-export from domain layer for backward compatibility.
export 'package:learning_tracker/features/scheduler/domain/models/goal_form_result.dart'
    show GoalFormResult;

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
          text: existingGoal != null ? 'Edit Goal' : 'New Goal',
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
  final ValueChanged<GoalFormResult> onComplete;
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
  late String _learningUnit;

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
    _paceUnit = widget.existingGoal?.paceUnit ?? 'per_day';
    _learningUnit = _defaultUnit;
  }

  /// Default learning unit based on curriculum type.
  String get _defaultUnit {
    // Bavli/Yerushalmi use Amud as smallest unit
    if (widget.curriculumId == CurriculumId.bavli ||
        widget.curriculumId == CurriculumId.yerushalmi) {
      return 'amud';
    }
    return 'item';
  }

  /// Whether the curriculum supports Amud/Daf unit selection.
  bool get _showUnitPicker =>
      widget.curriculumId == CurriculumId.bavli ||
      widget.curriculumId == CurriculumId.yerushalmi;

  String get _unitDisplayLabel {
    if (_learningUnit == 'daf') return 'Daf';
    if (_learningUnit == 'amud') return 'Amud';
    return _getUnitLabel(widget.curriculumId);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _getUnitLabel(CurriculumId id) {
    final config = CurriculumDefaults.hierarchyConfigs[id];
    if (config == null) return 'items';
    return config.level4Label ??
        config.level3Label ??
        config.level2Label ??
        config.level1Label;
  }

  DateTime _now() => ref.read(clockProvider);

  Future<void> _pickGregorianDate() async {
    final now = _now();
    final picked = await showDatePicker(
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
    widget.onComplete(
      GoalFormResult(
        targetPercent: _targetPercent,
        targetDate: _goalType == 'deadline' ? _targetDate : null,
        description: _goalType == 'deadline' ? _descriptionController.text : '',
        dateType: ref.read(useHebrewDateProvider) ? 'hebrew' : 'gregorian',
        goalType: _goalType,
        paceValue: _goalType == 'pace' ? _paceValue : null,
        paceUnit: _goalType == 'pace' ? _paceUnit : null,
        learningUnit: _showUnitPicker ? _learningUnit : null,
      ),
    );
  }

  Widget _buildDeadlineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date selection — pick a date immediately
        Card(
          child: InkWell(
            onTap: ref.read(useHebrewDateProvider) ? _pickHebrewDate : _pickGregorianDate,
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
                      _targetDate != null
                          ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                          : 'Tap to choose a date',
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
              segments: const [
                ButtonSegment(value: 'per_day', label: Text('Per day')),
                ButtonSegment(value: 'per_week', label: Text('Per week')),
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
              final formattedDate =
                  '${projectedDate.year}-${projectedDate.month.toString().padLeft(2, '0')}-${projectedDate.day.toString().padLeft(2, '0')}';
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
                      // Unit picker (Amud/Daf) for Bavli/Yerushalmi
                      if (_showUnitPicker) ...[
                        Text(
                          'Learning unit',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'amud',
                              label: Text('Amud'),
                            ),
                            ButtonSegment(
                              value: 'daf',
                              label: Text('Daf'),
                            ),
                          ],
                          selected: {_learningUnit},
                          onSelectionChanged: (selected) {
                            setState(() => _learningUnit = selected.first);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Goal type toggle
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'deadline',
                            label: Text('Deadline'),
                            icon: Icon(Icons.calendar_today),
                          ),
                          ButtonSegment(
                            value: 'pace',
                            label: Text('Pace'),
                            icon: Icon(Icons.speed),
                          ),
                          ButtonSegment(
                            value: 'none',
                            label: Text('No deadline'),
                            icon: Icon(Icons.all_inclusive),
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
                  (widget.existingGoal != null ? 'Update Goal' : 'Create Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
