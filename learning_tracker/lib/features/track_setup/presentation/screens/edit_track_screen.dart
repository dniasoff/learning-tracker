import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_edit_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class EditTrackScreen extends ConsumerStatefulWidget {
  const EditTrackScreen({required this.track, super.key});

  final CurriculumTrack track;

  @override
  ConsumerState<EditTrackScreen> createState() => _EditTrackScreenState();
}

class _EditTrackScreenState extends ConsumerState<EditTrackScreen> {
  bool _loading = true;
  bool _saving = false;

  Goal? _goal;

  late TextEditingController _nameController;
  late Map<int, String> _editedStudyDays;

  // Pace goal fields
  int _paceValue = 1;
  String _pacePeriod = 'per_week';
  String? _paceGranularity;

  // Deadline goal field
  DateTime? _targetDate;

  // Chazarah: null means no change; non-null is the pending replacement
  WizardResult? _pendingChazarah;
  List<int> _currentChazaraDelays = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _editedStudyDays = {};
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = ref.read(userDatabaseProvider);
    final results = await Future.wait([
      db.goalDao.getGoalByTrack(widget.track.id),
      db.studyDayConfigDao.getConfigsByTrack(widget.track.id),
      db.stageDao.getStagesByTrack(widget.track.id),
    ]);

    final goal = results[0] as Goal?;
    final studyDayList = results[1] as List<StudyDayConfig>;
    final stages = results[2] as List<StageDefinition>;

    final studyDays = <int, String>{};
    for (final d in studyDayList) {
      studyDays[d.dayOfWeek] = d.dayType;
    }
    if (studyDays.isEmpty) {
      studyDays.addAll(kDefaultStudyDays);
    }

    // Chazarah delays = delayDays of stages with stageOrder > 1 (skip learn).
    final delays = stages
        .where((s) => s.stageOrder > 1)
        .map((s) => s.delayDays)
        .toList();

    if (!mounted) return;
    // Fallback: when the stored goal has no description (tracks created before
    // B4 was fixed), show the curriculum's display name so the field is never
    // blank. Uses the current Hebrew Terms toggle to pick the right language.
    final curriculum = _curriculumId;
    var nameDefault = '';
    if (curriculum != null) {
      final useHebrew = ref.read(useHebrewTermsProvider);
      nameDefault = useHebrew
          ? curriculumHebrewName(curriculum)
          : curriculumEnglishName(curriculum);
    }
    setState(() {
      _goal = goal;
      final desc = goal?.description ?? '';
      _nameController.text = desc.isNotEmpty ? desc : nameDefault;
      _editedStudyDays = studyDays;
      _currentChazaraDelays = delays;

      if (goal != null) {
        _paceValue = goal.paceValue ?? 1;
        _pacePeriod = goal.pacePeriod ?? 'per_week';
        _paceGranularity = goal.paceGranularity;
        _targetDate = goal.targetDate?.toLocal();
      }

      _loading = false;
    });
  }

  bool get _isProgramTrack {
    final curriculum = _curriculumId;
    if (curriculum == null) return false;
    return ref
            .watch(dashboardHasProgramEnrollmentProvider(curriculum))
            .asData
            ?.value ??
        false;
  }

  CurriculumId? get _curriculumId => CurriculumId.values
      .where((c) => c.storageKey == widget.track.curriculumId)
      .firstOrNull;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trackEditConfirmTitle),
        content: Text(l10n.trackEditConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.trackEditSaveButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final goal = _goal;
      final curriculum = _curriculumId;
      if (goal == null || curriculum == null) return;

      final profileId = ref.read(activeProfileIdProvider);
      final service = ref.read(trackEditServiceProvider);

      // Determine goal value changes.
      final newLabel = _nameController.text.trim() != goal.description
          ? _nameController.text.trim()
          : null;
      int? newPaceValue;
      String? newPacePeriod;
      String? newPaceGranularity;
      DateTime? newTargetDate;
      var clearTargetDate = false;

      if (goal.goalType == 'pace') {
        if (_paceValue != (goal.paceValue ?? 1)) newPaceValue = _paceValue;
        if (_pacePeriod != (goal.pacePeriod ?? 'per_week')) {
          newPacePeriod = _pacePeriod;
        }
        if (_paceGranularity != goal.paceGranularity) {
          newPaceGranularity = _paceGranularity;
        }
      } else if (goal.goalType == 'deadline') {
        final orig = goal.targetDate?.toLocal();
        final edited = _targetDate;
        final origDay = orig != null
            ? DateTime(orig.year, orig.month, orig.day)
            : null;
        final editedDay = edited != null
            ? DateTime(edited.year, edited.month, edited.day)
            : null;
        if (origDay != editedDay) {
          if (edited == null) {
            clearTargetDate = true;
          } else {
            newTargetDate = edited.toUtc();
          }
        }
      }

      await service.editTrack(
        trackId: widget.track.id,
        goalId: goal.id,
        profileId: profileId,
        curriculum: curriculum,
        label: newLabel,
        studyDays: _isProgramTrack ? null : _editedStudyDays,
        chazarahWizard: _isProgramTrack ? null : _pendingChazarah,
        paceValue: newPaceValue,
        pacePeriod: newPacePeriod,
        paceGranularity: newPaceGranularity,
        targetDate: newTargetDate,
        clearTargetDate: clearTargetDate,
      );

      await onTrackChanged(ref, profileId);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build helpers
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trackEditTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        elevation: 0,
        title: Text(
          l10n.trackEditTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandBlueDeep,
          ),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                l10n.trackEditSaveButton,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: l10n.trackEditSectionName,
            child: TextField(
              controller: _nameController,
              inputFormatters: const [TrimLeadingSpaceFormatter()],
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFFE2E6F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFFE2E6F0)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_goal != null) ...[
            _SectionCard(
              title: l10n.trackEditSectionGoal,
              child: _buildGoalSection(context, theme, l10n),
            ),
            const SizedBox(height: 14),
          ],
          if (_isProgramTrack)
            _buildProgramLockedBanner(theme, l10n)
          else ...[
            _SectionCard(
              title: l10n.trackEditSectionStudyDays,
              child: _buildStudyDaysSection(theme),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: l10n.trackEditSectionReview,
              child: _buildChazaraSection(context, theme, l10n),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGoalSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final goal = _goal!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Locked goal type label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _goalTypeLabel(goal.goalType, l10n),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.trackEditGoalTypeLocked,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.brandInkMuted,
          ),
        ),
        const SizedBox(height: 14),
        if (goal.goalType == 'pace') _buildPaceEditor(theme, l10n),
        if (goal.goalType == 'deadline') _buildDeadlineEditor(context, theme),
      ],
    );
  }

  Widget _buildPaceEditor(ThemeData theme, AppLocalizations l10n) {
    final periodLabel = _pacePeriod == 'per_day'
        ? l10n.pacePerDay
        : l10n.pacePerWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Value stepper
        Row(
          children: [
            _StepperButton(
              icon: Icons.remove_rounded,
              onPressed: _paceValue > 1
                  ? () => setState(() => _paceValue--)
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              '$_paceValue',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.brandBlueDeep,
              ),
            ),
            const SizedBox(width: 16),
            _StepperButton(
              icon: Icons.add_rounded,
              onPressed: () => setState(() => _paceValue++),
            ),
            const SizedBox(width: 16),
            Text(
              periodLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Per-day / per-week toggle
        Row(
          children: [
            _PeriodChip(
              label: l10n.pacePerDay,
              isSelected: _pacePeriod == 'per_day',
              onTap: () => setState(() => _pacePeriod = 'per_day'),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: l10n.pacePerWeek,
              isSelected: _pacePeriod == 'per_week',
              onTap: () => setState(() => _pacePeriod = 'per_week'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeadlineEditor(BuildContext context, ThemeData theme) {
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = _targetDate != null
        ? DateFormat.yMMMd(locale).format(_targetDate!)
        : '—';

    return InkWell(
      onTap: () => _pickDeadline(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E6F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 20),
            const SizedBox(width: 12),
            Text(
              dateLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.edit_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline(BuildContext context) async {
    final now = DateTimeFactory.nowLocal();
    final picked = await showLearningAppDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  Widget _buildStudyDaysSection(ThemeData theme) {
    return Column(
      children: [
        for (var i = 0; i < kStepStudyDayNumbers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          StudyDayCard(
            initial: kStepStudyDayLabels[i].substring(0, 1),
            title: _dayName(kStepStudyDayNumbers[i]),
            subtitle: '',
            subtitleColor: AppTheme.brandInkMuted,
            activeColor: const Color(0xFFE9ECF2),
            isShabbos: kStepStudyDayNumbers[i] == 6,
            isOn: _editedStudyDays[kStepStudyDayNumbers[i]] == 'study',
            onChanged: (v) => setState(
              () => _editedStudyDays[kStepStudyDayNumbers[i]] =
                  v ? 'study' : 'review',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChazaraSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final delays =
        _pendingChazarah != null ? _pendingDelays() : _currentChazaraDelays;
    final summary = _chazaraSummary(delays, l10n);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.brandInk,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _openChazaraSheet(context, l10n),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(l10n.trackEditChangeReview),
        ),
      ],
    );
  }

  List<int> _pendingDelays() {
    final wiz = _pendingChazarah!;
    if (wiz.choice == WizardChoice.noReview) return [];
    if (wiz.choice == WizardChoice.custom) {
      return wiz.customRounds?.map((r) => r.delayDays ?? 0).toList() ?? [];
    }
    return [];
  }

  Future<void> _openChazaraSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final curriculum = _curriculumId;
    if (curriculum == null) return;

    final currentDelays =
        _pendingChazarah != null ? _pendingDelays() : _currentChazaraDelays;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F7FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ChazaraInlineSetup(
          curriculumId: curriculum,
          headerTitle: l10n.trackEditSectionReview,
          headerSubtitle: l10n.trackEditConfirmBody,
          initialDelays: currentDelays,
          onComplete: (result) {
            Navigator.pop(ctx);
            if (result == null) return;
            setState(() => _pendingChazarah = result.wizardResult);
          },
        ),
      ),
    );
  }

  Widget _buildProgramLockedBanner(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDD6F5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF6B84D6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.trackEditProgramLocked,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4A5C99),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _goalTypeLabel(String goalType, AppLocalizations l10n) {
    return switch (goalType) {
      'pace' => '${l10n.trackEditSectionGoal} · ${l10n.pacePerDay}/${l10n.pacePerWeek}',
      'deadline' => '${l10n.trackEditSectionGoal} · ${l10n.trackDetailConfigEstFinish}',
      _ => l10n.trackEditSectionGoal,
    };
  }

  String _chazaraSummary(List<int> delays, AppLocalizations l10n) {
    if (delays.isEmpty) return l10n.trackEditReviewSummaryNone;
    final joined = delays.map((d) => '$d').join(' + ');
    final daysLabel = delays.length == 1 ? 'day' : 'days';
    return l10n.trackEditReviewSummaryDays('$joined $daysLabel');
  }

  String _dayName(int dayNum) => switch (dayNum) {
    7 => 'Sunday',
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Shabbos',
    _ => 'Day',
  };
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2056).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F2F8),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null
                ? AppTheme.brandBlueDeep
                : AppTheme.brandInkMuted,
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandBlueBright : const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.brandInkMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
