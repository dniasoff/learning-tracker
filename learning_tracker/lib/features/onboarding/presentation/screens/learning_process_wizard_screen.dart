import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

// Re-export from domain layer for backward compatibility.
export 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart'
    show LearningProcessWizardResult;

/// Learning Process Wizard screen — shown per curriculum during onboarding.
///
/// Three paths:
/// 1. Follow a program (preset)
/// 2. Custom schedule (3-step builder)
/// 3. No formal review (Learn only)
class LearningProcessWizardScreen extends ConsumerStatefulWidget {
  const LearningProcessWizardScreen({
    required this.curriculumId,
    required this.presets,
    required this.isChildMode,
    this.childName,
    this.skipChooseMethod = false,
    super.key,
  });

  final CurriculumId curriculumId;
  final List<LearningProgramData> presets;
  final bool isChildMode;
  final String? childName;

  /// When true, skips the initial "How do you review?" choice screen
  /// and goes directly to the custom schedule builder.
  final bool skipChooseMethod;

  @override
  ConsumerState<LearningProcessWizardScreen> createState() =>
      _LearningProcessWizardScreenState();
}

enum _WizardStep {
  chooseMethod,
  selectPreset,
  customStep1,
  customStep2,
  customStep3,
}

class _LearningProcessWizardScreenState
    extends ConsumerState<LearningProcessWizardScreen> {
  late _WizardStep _step;

  // Preset selection
  int? _selectedPresetId;

  // Custom builder state
  int _chazarahRounds = 1;
  late List<_CustomRoundState> _rounds;

  @override
  void initState() {
    super.initState();
    _step = widget.skipChooseMethod
        ? _WizardStep.customStep1
        : _WizardStep.chooseMethod;
    _rounds = [_CustomRoundState.withDefault(0)];
  }

  String get _questionText {
    if (widget.isChildMode && widget.childName != null) {
      return 'How does ${widget.childName} review?';
    }
    return 'How do you review?';
  }

  void _onChoosePreset() {
    if (widget.presets.isEmpty) return;
    setState(() => _step = _WizardStep.selectPreset);
  }

  void _onChooseCustom() {
    setState(() => _step = _WizardStep.customStep1);
  }

  void _onChooseNoReview() {
    Navigator.of(context).pop(
      LearningProcessWizardResult(
        wizardResult: WizardResult(
          curriculumId: widget.curriculumId,
          choice: WizardChoice.noReview,
        ),
      ),
    );
  }

  void _onPresetConfirmed() {
    if (_selectedPresetId == null) return;
    Navigator.of(context).pop(
      LearningProcessWizardResult(
        wizardResult: WizardResult(
          curriculumId: widget.curriculumId,
          choice: WizardChoice.preset,
          programId: _selectedPresetId,
        ),
      ),
    );
  }

  void _onCustomStep1Next() {
    // Ensure rounds list matches slider value with smart defaults.
    while (_rounds.length < _chazarahRounds) {
      _rounds.add(_CustomRoundState.withDefault(_rounds.length));
    }
    while (_rounds.length > _chazarahRounds) {
      _rounds.removeLast();
    }
    setState(() => _step = _WizardStep.customStep2);
  }

  void _onCustomStep2Next() {
    setState(() => _step = _WizardStep.customStep3);
  }

  void _onCustomConfirmed() {
    final rounds = <CustomRound>[];
    for (var i = 0; i < _rounds.length; i++) {
      final r = _rounds[i];
      rounds.add(
        CustomRound(
          label: HebrewTerms.getChazaraStageName(i + 1),
          scheduleType: r.useWeekly ? ScheduleType.weekly : ScheduleType.delay,
          delayDays: r.useWeekly ? null : r.delayDays,
          daysOfWeek: r.useWeekly ? r.selectedDays.toList() : null,
        ),
      );
    }
    Navigator.of(context).pop(
      LearningProcessWizardResult(
        wizardResult: WizardResult(
          curriculumId: widget.curriculumId,
          choice: WizardChoice.custom,
          customRounds: rounds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(curriculumLabelText(ref, curriculum: widget.curriculumId)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _WizardStep.chooseMethod) {
              Navigator.of(context).pop(); // Skip — wizard skippable
            } else if (_step == _WizardStep.customStep1 &&
                widget.skipChooseMethod) {
              Navigator.of(context).pop(); // Back exits when choice was skipped
            } else if (_step == _WizardStep.customStep2) {
              setState(() => _step = _WizardStep.customStep1);
            } else if (_step == _WizardStep.customStep3) {
              setState(() => _step = _WizardStep.customStep2);
            } else {
              setState(() => _step = _WizardStep.chooseMethod);
            }
          },
        ),
      ),
      body: switch (_step) {
        _WizardStep.chooseMethod => _buildChooseMethod(theme),
        _WizardStep.selectPreset => _buildSelectPreset(theme),
        _WizardStep.customStep1 => _buildCustomStep1(theme),
        _WizardStep.customStep2 => _buildCustomStep2(theme),
        _WizardStep.customStep3 => _buildCustomStep3(theme),
      },
    );
  }

  Widget _buildChooseMethod(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _questionText,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              curriculumLabelText(ref, curriculum: widget.curriculumId),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (widget.presets.isNotEmpty)
              _OptionCard(
                icon: Icons.school,
                title: 'Follow a program',
                subtitle: '${widget.presets.length} programs available',
                onTap: _onChoosePreset,
              ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.tune,
              title: 'Custom schedule',
              subtitle: 'Build your own review cycle',
              onTap: _onChooseCustom,
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.play_arrow,
              title: 'No formal review',
              subtitle: 'Just track learning progress',
              onTap: _onChooseNoReview,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectPreset(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              widget.isChildMode && widget.childName != null
                  ? 'What program does ${widget.childName} follow?'
                  : 'Select a program',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.presets.length,
              itemBuilder: (context, index) {
                final preset = widget.presets[index];
                final isSelected = _selectedPresetId == preset.id;
                return _PresetCard(
                  preset: preset,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedPresetId = preset.id),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: _selectedPresetId != null ? _onPresetConfirmed : null,
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomStep1(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How many review rounds?',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Each round reviews the material at increasing intervals',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              '$_chazarahRounds round${_chazarahRounds == 1 ? '' : 's'}',
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            Slider(
              value: _chazarahRounds.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_chazarahRounds',
              onChanged: (v) => setState(() => _chazarahRounds = v.round()),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _onCustomStep1Next,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStep2(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set delay for each round',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'How long after learning before each review?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _rounds.length,
                itemBuilder: (context, index) {
                  return _RoundTimingCard(
                    roundIndex: index,
                    state: _rounds[index],
                    onChanged: () => setState(() {}),
                  );
                },
              ),
            ),
            FilledButton(
              onPressed: _onCustomStep2Next,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStep3(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review your schedule',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HebrewTerms.stageLearn,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Daily new material',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Divider(),
                    for (var i = 0; i < _rounds.length; i++) ...[
                      Text(
                        HebrewTerms.getChazaraStageName(i + 1),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        _rounds[i].useWeekly
                            ? 'Every ${_formatDays(_rounds[i].selectedDays)}'
                            : '${_rounds[i].delayDays} ${_rounds[i].delayDays == 1 ? 'day' : 'days'} after learning',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (i < _rounds.length - 1) const Divider(),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _onCustomConfirmed,
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(Set<int> days) {
    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Shabbos',
      7: 'Sun',
    };
    final sorted = days.toList()..sort();
    return sorted.map((d) => dayNames[d] ?? '?').join(', ');
  }
}

class _CustomRoundState {
  _CustomRoundState({this.delayDays = 1});

  bool useWeekly = false;
  int delayDays;
  Set<int> selectedDays = {};

  /// Spaced repetition defaults: 1 day, 7 days, 30 days, 60 days, 90 days.
  static _CustomRoundState withDefault(int roundIndex) {
    const defaults = [1, 7, 30, 60, 90];
    final delay = roundIndex < defaults.length ? defaults[roundIndex] : 90;
    return _CustomRoundState(delayDays: delay);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final LearningProgramData preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary)
                else
                  Icon(
                    Icons.circle_outlined,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundTimingCard extends StatelessWidget {
  const _RoundTimingCard({
    required this.roundIndex,
    required this.state,
    required this.onChanged,
  });

  final int roundIndex;
  final _CustomRoundState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              HebrewTerms.getChazaraStageName(roundIndex + 1),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Days')),
                ButtonSegment(value: true, label: Text('Weeks')),
              ],
              selected: {state.useWeekly},
              onSelectionChanged: (s) {
                state.useWeekly = s.first;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            if (!state.useWeekly) ...[
              Row(
                children: [
                  Text(
                    '${state.delayDays} ${state.delayDays == 1 ? 'day' : 'days'} after',
                  ),
                  Expanded(
                    child: Slider(
                      value: state.delayDays.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '${state.delayDays}',
                      onChanged: (v) {
                        state.delayDays = v.round();
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in {
                    7: 'Sun',
                    1: 'Mon',
                    2: 'Tue',
                    3: 'Wed',
                    4: 'Thu',
                    5: 'Fri',
                    6: 'Shabbos',
                  }.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: state.selectedDays.contains(entry.key),
                      onSelected: (selected) {
                        if (selected) {
                          state.selectedDays.add(entry.key);
                        } else {
                          state.selectedDays.remove(entry.key);
                        }
                        onChanged();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
