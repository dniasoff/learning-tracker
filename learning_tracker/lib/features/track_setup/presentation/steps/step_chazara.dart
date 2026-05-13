import 'package:flutter/material.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/chazara_widgets.dart';

// ── Chazara Inline Setup ───────────────────────────────────────────────────
//
// Single-screen חזרה configuration. Per DNI-180:
//   "Choose a preset, customize stages, or 'no חזרה'"
//   "All חזרה config on ONE screen"
// Replaces a Navigator.push to LearningProcessWizardScreen.

class ChazaraInlineSetup extends StatefulWidget {
  const ChazaraInlineSetup({
    required this.curriculumId,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.onComplete,
    super.key,
  });

  final CurriculumId curriculumId;
  final String headerTitle;
  final String headerSubtitle;
  final ValueChanged<LearningProcessWizardResult?> onComplete;

  @override
  State<ChazaraInlineSetup> createState() => _ChazaraInlineSetupState();
}

/// Built-in preset templates expressed as round delays in days.
class _ChazaraPreset {
  const _ChazaraPreset({required this.label, required this.delays});
  final String label;
  final List<int> delays;
}

class _ChazaraInlineSetupState extends State<ChazaraInlineSetup> {
  static const List<_ChazaraPreset> _presets = [
    _ChazaraPreset(label: 'Learn Only', delays: []),
    _ChazaraPreset(label: '1 day', delays: [1]),
    _ChazaraPreset(label: '1 + 7 days', delays: [1, 7]),
    _ChazaraPreset(label: '1 + 7 + 30 days', delays: [1, 7, 30]),
  ];

  /// Index of selected preset, or -1 for "Custom".
  int _selectedPresetIndex = 2; // default: 1 + 7 days
  late List<int> _customDelays;

  @override
  void initState() {
    super.initState();
    _customDelays = List.of(_presets[_selectedPresetIndex].delays);
  }

  List<int> get _activeDelays => _selectedPresetIndex >= 0
      ? _presets[_selectedPresetIndex].delays
      : _customDelays;

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _customDelays = List.of(_presets[index].delays);
    });
  }

  void _selectCustom() {
    setState(() {
      _selectedPresetIndex = -1;
      if (_customDelays.isEmpty) _customDelays = [1];
    });
  }

  void _addCustomRound() {
    setState(() {
      final next = _customDelays.isEmpty ? 1 : _customDelays.last * 2;
      _customDelays.add(next);
    });
  }

  void _removeCustomRound(int index) {
    setState(() => _customDelays.removeAt(index));
  }

  void _updateCustomRound(int index, int value) {
    setState(() => _customDelays[index] = value);
  }

  void _confirm() {
    final delays = _activeDelays;
    if (delays.isEmpty) {
      // לימוד only — equivalent to "no review".
      widget.onComplete(
        LearningProcessWizardResult(
          wizardResult: WizardResult(
            curriculumId: widget.curriculumId,
            choice: WizardChoice.noReview,
          ),
        ),
      );
      return;
    }

    final rounds = <CustomRound>[];
    for (var i = 0; i < delays.length; i++) {
      rounds.add(
        CustomRound(
          label: HebrewTerms.getChazaraStageName(i + 1),
          scheduleType: ScheduleType.delay,
          delayDays: delays[i],
        ),
      );
    }
    widget.onComplete(
      LearningProcessWizardResult(
        wizardResult: WizardResult(
          curriculumId: widget.curriculumId,
          choice: WizardChoice.custom,
          customRounds: rounds,
        ),
      ),
    );
  }

  void _skip() => widget.onComplete(null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.headerTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.headerSubtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < _presets.length; i++)
                            SizedBox(
                              width: cardWidth,
                              child: ReviewPresetCard(
                                title: _presets[i].label,
                                subtitle: _presetDescription(i),
                                icon: _presetIcon(i),
                                isSelected: _selectedPresetIndex == i,
                                onTap: () => _selectPreset(i),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedPresetIndex == -1
                            ? AppTheme.brandBlueBright
                            : const Color(0xFFE9ECF2),
                        width: _selectedPresetIndex == -1 ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _selectCustom,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Color(0xFFF9E4C8),
                                  child: Icon(
                                    Icons.settings_suggest_rounded,
                                    size: 16,
                                    color: Color(0xFF7D5411),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Custom Cycle',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E9FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_customDelays.length} Sessions',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: AppTheme.brandBlueDeep,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < _customDelays.length; i++)
                                  CustomDayEditorChip(
                                    day: _customDelays[i],
                                    accentColor: _delayAccent(i),
                                    onMinus: () {
                                      _selectCustom();
                                      if (_customDelays[i] > 1) {
                                        _updateCustomRound(
                                          i,
                                          _customDelays[i] - 1,
                                        );
                                      }
                                    },
                                    onPlus: () {
                                      _selectCustom();
                                      _updateCustomRound(
                                        i,
                                        _customDelays[i] + 1,
                                      );
                                    },
                                    onRemove: _customDelays.length > 1
                                        ? () {
                                            _selectCustom();
                                            _removeCustomRound(i);
                                          }
                                        : null,
                                  ),
                                if (_customDelays.length < 5)
                                  AddRoundChip(
                                    onTap: () {
                                      _selectCustom();
                                      _addCustomRound();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _skip,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE4E5E9),
              foregroundColor: AppTheme.brandInk,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Skip (no review)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _confirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _presetDescription(int index) {
    return switch (index) {
      0 => 'No scheduled reviews.',
      1 => 'Review next morning.',
      2 => 'The recommended starter.',
      3 => 'Full mastery cycle.',
      _ => '',
    };
  }

  IconData _presetIcon(int index) {
    return switch (index) {
      0 => Icons.visibility_off_rounded,
      1 => Icons.event_available_rounded,
      2 => Icons.auto_awesome_rounded,
      3 => Icons.insights_rounded,
      _ => Icons.schedule_rounded,
    };
  }

  Color _delayAccent(int index) {
    return switch (index % 3) {
      0 => AppTheme.brandBlueBright,
      1 => const Color(0xFFFF6C78),
      _ => const Color(0xFFAA7B36),
    };
  }
}
