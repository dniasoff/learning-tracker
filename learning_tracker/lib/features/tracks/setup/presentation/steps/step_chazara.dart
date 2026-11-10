import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Single-screen review schedule configuration, shared by track setup and edit.
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

  /// Delay days for each review round. The learn stage is not included.
  final List<int>? initialDelays;

  @override
  ConsumerState<ChazaraInlineSetup> createState() => _ChazaraInlineSetupState();
}

class _ChazaraInlineSetupState extends ConsumerState<ChazaraInlineSetup> {
  static const _presets = <List<int>>[
    [],
    [1],
    [1, 7],
    [1, 7, 30],
  ];
  static const _maxDelayDays = 3650;

  late List<TextEditingController> _controllers;
  bool _showValidation = false;

  List<String> get _values =>
      _controllers.map((controller) => controller.text).toList();

  List<int>? get _validDelays {
    final values = _values;
    final delays = <int>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (!RegExp(r'^\d+$').hasMatch(value)) return null;
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 1 || parsed > _maxDelayDays) return null;
      if (delays.isNotEmpty && parsed <= delays.last) return null;
      delays.add(parsed);
    }
    return delays;
  }

  @override
  void initState() {
    super.initState();
    _controllers = _makeControllers(widget.initialDelays ?? _presets[2]);
  }

  List<TextEditingController> _makeControllers(List<int> delays) =>
      delays.map((day) => TextEditingController(text: '$day')).toList();

  void _replaceDelays(List<int> delays) {
    final old = _controllers;
    setState(() {
      _controllers = _makeControllers(delays);
      _showValidation = false;
    });
    for (final controller in old) {
      controller.dispose();
    }
  }

  void _addInterval() {
    final delays = _validDelays;
    final next = delays == null || delays.isEmpty ? 1 : delays.last + 1;
    setState(() {
      _controllers.add(TextEditingController(text: '$next'));
      _showValidation = false;
    });
  }

  void _removeInterval(int index) {
    final controller = _controllers.removeAt(index);
    controller.dispose();
    setState(() => _showValidation = false);
  }

  String? _intervalError(int index, AppLocalizations l10n) {
    final value = _controllers[index].text;
    if (value.isEmpty) return l10n.chazaraIntervalPositiveError;
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return l10n.chazaraIntervalWholeNumberError;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) return l10n.chazaraIntervalPositiveError;
    if (parsed > _maxDelayDays)
      return l10n.chazaraIntervalMaximumError(_maxDelayDays);
    if (index > 0) {
      final previous = int.tryParse(_controllers[index - 1].text);
      if (previous != null && parsed <= previous) {
        return l10n.chazaraIntervalIncreasingError;
      }
    }
    return null;
  }

  void _confirm() {
    final delays = _validDelays;
    if (delays == null) {
      setState(() => _showValidation = true);
      return;
    }
    if (delays.isEmpty) {
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
    final rounds = [
      for (var i = 0; i < delays.length; i++)
        CustomRound(
          label: terms.chazaraStage(i + 1),
          scheduleType: ScheduleType.delay,
          delayDays: delays[i],
        ),
    ];
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
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final delays = _validDelays;
    final selectedPreset = delays == null
        ? -1
        : _presets.indexWhere((preset) => _listEquals(preset, delays));

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
                  Text(
                    l10n.chazaraQuickFillLabel,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _presets.length; i++)
                        ChoiceChip(
                          label: Text(_presetLabel(l10n, i)),
                          selected: selectedPreset == i,
                          onSelected: (_) => _replaceDelays(_presets[i]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.chazaraPlanEditorTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.chazaraPlanEditorHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.colors.brandInkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _controllers.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[i],
                            keyboardType: TextInputType.number,
                            textInputAction: i == _controllers.length - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.chazaraIntervalFieldLabel(i + 1),
                              suffixText: l10n.chazaraDaysUnit,
                              errorText: _showValidation
                                  ? _intervalError(i, l10n)
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.chazaraRemoveIntervalLabel(i + 1),
                          onPressed: () => _removeInterval(i),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _addInterval,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.chazaraAddInterval),
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

  String _presetLabel(AppLocalizations l10n, int index) => switch (index) {
    0 => l10n.chazaraQuickFillLearnOnly,
    1 => l10n.chazaraQuickFillOneDay,
    2 => l10n.chazaraQuickFillWeek,
    3 => l10n.chazaraQuickFillMonth,
    _ => '',
  };

  static bool _listEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
