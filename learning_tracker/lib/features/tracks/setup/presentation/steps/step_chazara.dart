import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/chazara_widgets.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Chazara Inline Setup ───────────────────────────────────────────────────
//
// Single-screen חזרה configuration. Per DNI-180:
//   "Choose a preset, customize stages, or 'no חזרה'"
//   "All חזרה config on ONE screen"
// Replaces a Navigator.push to LearningProcessWizardScreen.

class ChazaraInlineSetup extends ConsumerStatefulWidget {
  const ChazaraInlineSetup({
    required this.curriculumId,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.onComplete,
    this.initialDelays,
    super.key,
  });

  final CurriculumId curriculumId;
  final String headerTitle;
  final String headerSubtitle;
  final ValueChanged<LearningProcessWizardResult?> onComplete;

  /// When provided, pre-selects the matching preset or switches to Custom mode.
  /// Each value is the delayDays of one chazarah round (learn stage excluded).
  final List<int>? initialDelays;

  @override
  ConsumerState<ChazaraInlineSetup> createState() => _ChazaraInlineSetupState();
}

/// Built-in preset templates expressed as round delays in days.
///
/// [label] is a fixed lookup key resolved to a localized title via
/// [_ChazaraInlineSetupState._presetTitle] — never rendered directly.
class _ChazaraPreset {
  const _ChazaraPreset({required this.label, required this.delays});
  final String label;
  final List<int> delays;
}

class _ChazaraInlineSetupState extends ConsumerState<ChazaraInlineSetup> {
  static const List<_ChazaraPreset> _presets = [
    _ChazaraPreset(label: 'learnOnly', delays: []),
    _ChazaraPreset(label: 'oneDay', delays: [1]),
    _ChazaraPreset(label: 'week', delays: [1, 7]),
    _ChazaraPreset(label: 'month', delays: [1, 7, 30]),
  ];

  /// Index of selected preset, or -1 for "Custom".
  int _selectedPresetIndex = 2; // default: 1 + 7 days
  late List<int> _customDelays;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDelays;
    if (initial != null) {
      final match = _presets.indexWhere((p) => _listEquals(p.delays, initial));
      if (match >= 0) {
        _selectedPresetIndex = match;
        _customDelays = List.of(_presets[match].delays);
      } else {
        _selectedPresetIndex = -1;
        _customDelays = List.of(initial);
      }
    } else {
      _customDelays = List.of(_presets[_selectedPresetIndex].delays);
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

    final terms = domainTermLabels(ref);
    final rounds = <CustomRound>[];
    for (var i = 0; i < delays.length; i++) {
      rounds.add(
        CustomRound(
          label: terms.chazaraStage(i + 1),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
              color: context.colors.brandInkMuted,
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
                                title: _presetTitle(l10n, i),
                                subtitle: _presetDescription(l10n, i),
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
                      // Run-11 deferred dark-mode sweep: same hardcoded-white
                      // bug as the (already-fixed) unselected ReviewPresetCard
                      // above — this stayed white in dark mode while the
                      // "Custom Cycle" heading below reads the theme's default
                      // titleLarge colour (brandInk, near-white in dark),
                      // measured 1.16:1 on device. brandCreamCard is the
                      // theme-aware card surface: identical 0xFFFFFFFF in
                      // light mode, darkens to 0xFF151A26 in dark (14.94:1
                      // with brandInk).
                      color: context.colors.brandCreamCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedPresetIndex == -1
                            ? context.colors.brandBlueBright
                            : context.colors.surfaceE9,
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
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: context.colors.peachTint,
                                  child: Icon(
                                    Icons.settings_suggest_rounded,
                                    size: 16,
                                    color: context.colors.goldDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.chazaraCustomCycle,
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
                                    color: context.colors.surfaceBlueLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    l10n.chazaraSessionsCount(
                                      _customDelays.length,
                                    ),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: context.colors.brandBlueDeep,
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
            onPressed: _confirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );
  }

  String _presetTitle(AppLocalizations l10n, int index) {
    return switch (_presets[index].label) {
      'learnOnly' => l10n.chazaraPresetLearnOnlyTitle,
      'oneDay' => l10n.chazaraPresetOneDayTitle,
      'week' => l10n.chazaraPresetWeekTitle,
      'month' => l10n.chazaraPresetMonthTitle,
      _ => '',
    };
  }

  String _presetDescription(AppLocalizations l10n, int index) {
    return switch (_presets[index].label) {
      'learnOnly' => l10n.chazaraPresetLearnOnlyDescription,
      'oneDay' => l10n.chazaraPresetOneDayDescription,
      'week' => l10n.chazaraPresetWeekDescription,
      'month' => l10n.chazaraPresetMonthDescription,
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
      0 => context.colors.brandBlueBright,
      1 => const Color(0xFFFF6C78),
      _ => const Color(0xFFAA7B36),
    };
  }
}
