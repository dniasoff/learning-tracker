import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

/// Mutable state shared across wizard steps.
class WizardStepData {
  int chazarahRounds = 1;
  List<CustomRoundState> rounds = [CustomRoundState.withDefault(0)];
  int? selectedPresetId;
}

/// Mutable state for a single review round in the custom wizard builder.
class CustomRoundState {
  CustomRoundState({this.delayDays = 1});

  bool useWeekly = false;
  int delayDays;
  Set<int> selectedDays = {};

  /// Spaced repetition defaults: 1 day, 7 days, 30 days, 60 days, 90 days.
  static CustomRoundState withDefault(int roundIndex) {
    const defaults = [1, 7, 30, 60, 90];
    final delay = roundIndex < defaults.length ? defaults[roundIndex] : 90;
    return CustomRoundState(delayDays: delay);
  }
}

// ── Wizard Steps ──────────────────────────────────────────────────────────────

/// Step 1 of the wizard: choose the review method.
class WizardChooseMethodStep extends OnboardingStep {
  const WizardChooseMethodStep({
    required this.curriculumId,
    required this.presets,
    required this.isChildMode,
    this.childName,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final List<LearningProgramData> presets;
  final bool isChildMode;
  final String? childName;
  final void Function(LearningProcessWizardResult) onComplete;

  @override
  String get id => 'wizardChooseMethod';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _ChooseMethodWidget(
      curriculumId: curriculumId,
      presets: presets,
      isChildMode: isChildMode,
      childName: childName,
      onComplete: onComplete,
      ctx: ctx,
    );
  }
}

class _ChooseMethodWidget extends ConsumerWidget {
  const _ChooseMethodWidget({
    required this.curriculumId,
    required this.presets,
    required this.isChildMode,
    this.childName,
    required this.onComplete,
    required this.ctx,
  });

  final CurriculumId curriculumId;
  final List<LearningProgramData> presets;
  final bool isChildMode;
  final String? childName;
  final void Function(LearningProcessWizardResult) onComplete;
  final OnboardingStepContext ctx;

  String get _questionText {
    if (isChildMode && childName != null) {
      return 'How does $childName review?';
    }
    return 'How do you review?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
              curriculumLabelText(ref, curriculum: curriculumId),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (presets.isNotEmpty)
              _OptionCard(
                icon: Icons.school,
                title: 'Follow a program',
                subtitle: '${presets.length} programs available',
                onTap: ctx.advance,
              ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.tune,
              title: 'Custom schedule',
              subtitle: 'Build your own review cycle',
              onTap: () => onComplete(
                LearningProcessWizardResult(
                  wizardResult: WizardResult(
                    curriculumId: curriculumId,
                    choice: WizardChoice.custom,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.play_arrow,
              title: 'No formal review',
              subtitle: 'Just track learning progress',
              onTap: () => onComplete(
                LearningProcessWizardResult(
                  wizardResult: WizardResult(
                    curriculumId: curriculumId,
                    choice: WizardChoice.noReview,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2 (preset path): select a program.
class WizardSelectPresetStep extends OnboardingStep {
  const WizardSelectPresetStep({
    required this.curriculumId,
    required this.presets,
    required this.isChildMode,
    this.childName,
    required this.data,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final List<LearningProgramData> presets;
  final bool isChildMode;
  final String? childName;
  final WizardStepData data;
  final void Function(LearningProcessWizardResult) onComplete;

  @override
  String get id => 'wizardSelectPreset';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _SelectPresetWidget(
      curriculumId: curriculumId,
      presets: presets,
      isChildMode: isChildMode,
      childName: childName,
      data: data,
      onComplete: onComplete,
    );
  }
}

class _SelectPresetWidget extends StatefulWidget {
  const _SelectPresetWidget({
    required this.curriculumId,
    required this.presets,
    required this.isChildMode,
    this.childName,
    required this.data,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final List<LearningProgramData> presets;
  final bool isChildMode;
  final String? childName;
  final WizardStepData data;
  final void Function(LearningProcessWizardResult) onComplete;

  @override
  State<_SelectPresetWidget> createState() => _SelectPresetWidgetState();
}

class _SelectPresetWidgetState extends State<_SelectPresetWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                final isSelected = widget.data.selectedPresetId == preset.id;
                return _PresetCard(
                  preset: preset,
                  isSelected: isSelected,
                  onTap: () =>
                      setState(() => widget.data.selectedPresetId = preset.id),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: widget.data.selectedPresetId != null
                  ? () => widget.onComplete(
                      LearningProcessWizardResult(
                        wizardResult: WizardResult(
                          curriculumId: widget.curriculumId,
                          choice: WizardChoice.preset,
                          programId: widget.data.selectedPresetId,
                        ),
                      ),
                    )
                  : null,
              child: Text(AppLocalizations.of(context)!.onboardingConfirm),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom builder Step 1: choose number of review rounds.
class WizardCustomStep1 extends OnboardingStep {
  const WizardCustomStep1({required this.data});

  final WizardStepData data;

  @override
  String get id => 'wizardCustomStep1';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _CustomStep1Widget(data: data, ctx: ctx);
  }
}

class _CustomStep1Widget extends StatefulWidget {
  const _CustomStep1Widget({required this.data, required this.ctx});

  final WizardStepData data;
  final OnboardingStepContext ctx;

  @override
  State<_CustomStep1Widget> createState() => _CustomStep1WidgetState();
}

class _CustomStep1WidgetState extends State<_CustomStep1Widget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              '${widget.data.chazarahRounds} round${widget.data.chazarahRounds == 1 ? '' : 's'}',
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            Slider(
              value: widget.data.chazarahRounds.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '${widget.data.chazarahRounds}',
              onChanged: (v) =>
                  setState(() => widget.data.chazarahRounds = v.round()),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                // Sync rounds list to match slider.
                while (widget.data.rounds.length < widget.data.chazarahRounds) {
                  widget.data.rounds.add(
                    CustomRoundState.withDefault(widget.data.rounds.length),
                  );
                }
                while (widget.data.rounds.length > widget.data.chazarahRounds) {
                  widget.data.rounds.removeLast();
                }
                widget.ctx.advance();
              },
              child: Text(AppLocalizations.of(context)!.actionNext),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom builder Step 2: set delay for each round.
class WizardCustomStep2 extends OnboardingStep {
  const WizardCustomStep2({required this.data});

  final WizardStepData data;

  @override
  String get id => 'wizardCustomStep2';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _CustomStep2Widget(data: data, ctx: ctx);
  }
}

class _CustomStep2Widget extends StatefulWidget {
  const _CustomStep2Widget({required this.data, required this.ctx});

  final WizardStepData data;
  final OnboardingStepContext ctx;

  @override
  State<_CustomStep2Widget> createState() => _CustomStep2WidgetState();
}

class _CustomStep2WidgetState extends State<_CustomStep2Widget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                itemCount: widget.data.rounds.length,
                itemBuilder: (context, index) {
                  return _RoundTimingCard(
                    roundIndex: index,
                    state: widget.data.rounds[index],
                    onChanged: () => setState(() {}),
                  );
                },
              ),
            ),
            FilledButton(
              onPressed: widget.ctx.advance,
              child: Text(AppLocalizations.of(context)!.actionNext),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom builder Step 3: review and confirm the schedule.
class WizardCustomStep3 extends OnboardingStep {
  const WizardCustomStep3({
    required this.curriculumId,
    required this.data,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final WizardStepData data;
  final void Function(LearningProcessWizardResult) onComplete;

  @override
  String get id => 'wizardCustomStep3';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _CustomStep3Widget(
      curriculumId: curriculumId,
      data: data,
      onComplete: onComplete,
    );
  }
}

class _CustomStep3Widget extends StatelessWidget {
  const _CustomStep3Widget({
    required this.curriculumId,
    required this.data,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final WizardStepData data;
  final void Function(LearningProcessWizardResult) onComplete;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    for (var i = 0; i < data.rounds.length; i++) ...[
                      Text(
                        HebrewTerms.getChazaraStageName(i + 1),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        data.rounds[i].useWeekly
                            ? 'Every ${_formatDays(data.rounds[i].selectedDays)}'
                            : '${data.rounds[i].delayDays} ${data.rounds[i].delayDays == 1 ? 'day' : 'days'} after learning',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (i < data.rounds.length - 1) const Divider(),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final rounds = <CustomRound>[];
                for (var i = 0; i < data.rounds.length; i++) {
                  final r = data.rounds[i];
                  rounds.add(
                    CustomRound(
                      label: HebrewTerms.getChazaraStageName(i + 1),
                      scheduleType: r.useWeekly
                          ? ScheduleType.weekly
                          : ScheduleType.delay,
                      delayDays: r.useWeekly ? null : r.delayDays,
                      daysOfWeek: r.useWeekly ? r.selectedDays.toList() : null,
                    ),
                  );
                }
                onComplete(
                  LearningProcessWizardResult(
                    wizardResult: WizardResult(
                      curriculumId: curriculumId,
                      choice: WizardChoice.custom,
                      customRounds: rounds,
                    ),
                  ),
                );
              },
              child: Text(AppLocalizations.of(context)!.onboardingConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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
  final CustomRoundState state;
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
              segments: [
                ButtonSegment(value: false, label: Text(AppLocalizations.of(context)!.schedulerDaysLabel)),
                ButtonSegment(value: true, label: Text(AppLocalizations.of(context)!.schedulerWeeksLabel)),
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
