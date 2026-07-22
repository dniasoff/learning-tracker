import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_edit_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// R1-(5): pure validation helper — returns `true` when [name] is valid
/// (non-blank after trimming), `false` when blank or whitespace-only.
/// Extracted so the blank-name guard in [_EditTrackScreenState._save] is
/// unit-testable; the screen surfaces the localized
/// [AppLocalizations.trackEditNameRequired] when this returns `false`.
///
/// AUD-tracks-24: returns a bool rather than a natural-language message —
/// a validator returning hardcoded English text invites a future bug where
/// that string is displayed directly, bypassing localization.
bool validateTrackName(String name) => name.trim().isNotEmpty;

/// R1-(5): pure helper — the number of days marked `'study'` (as opposed to
/// `'review'`) in a study-day map. Used by [_EditTrackScreenState._save] to warn
/// before saving a self-paced track with zero study days.
int studyDayCount(Map<int, String> studyDays) =>
    studyDays.values.where((v) => v == 'study').length;

class EditTrackScreen extends ConsumerStatefulWidget {
  const EditTrackScreen({required this.track, super.key});

  final CurriculumTrack track;

  @override
  ConsumerState<EditTrackScreen> createState() => _EditTrackScreenState();
}

class _EditTrackScreenState extends ConsumerState<EditTrackScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _hasOverdue = false;

  // Inline validation error for the Track Name field. Non-null when the user
  // has tried to save an empty/whitespace-only name; cleared as they type.
  String? _nameError;

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

    // F-H1: Read overdue state from the projection — the authoritative source
    // after the projection cutover. daily_plans.isOverdue is stale and must
    // not be used.
    final allTasks = await ref.read(allDailyTasksProvider.future);
    final hasOverdue = allTasks.any(
      (t) =>
          t.trackId == widget.track.id &&
          t.priority == DailyTaskPriority.overdueProgram,
    );

    final studyDays = <int, String>{};
    for (final d in studyDayList) {
      studyDays[d.dayOfWeek] = d.dayType;
    }
    if (studyDays.isEmpty) {
      studyDays.addAll(kDefaultStudyDays);
    }

    // Chazarah delays = delayDays of stages with stageOrder > 1 (skip learn).
    // W3.27: schedule quartet replaced by JSON column; decode delay_days here.
    final delays = stages.where((s) => s.stageOrder > 1).map((s) {
      try {
        final sched = jsonDecode(s.schedule) as Map<String, dynamic>;
        return (sched['delay_days'] as num?)?.toInt() ?? 0;
      } catch (_) {
        return 0;
      }
    }).toList();

    if (!mounted) return;
    // Fallback: when the stored goal has no description (tracks created before
    // B4 was fixed), show the curriculum's display name so the field is never
    // blank. Uses the current Hebrew Terms toggle to pick the right language.
    final curriculum = _curriculumId;
    var nameDefault = '';
    if (curriculum != null) {
      nameDefault = curriculumLabelText(ref, curriculum: curriculum);
    }
    setState(() {
      _goal = goal;
      final desc = goal?.description ?? '';
      _nameController.text = desc.isNotEmpty ? desc : nameDefault;
      _editedStudyDays = studyDays;
      _currentChazaraDelays = delays;
      _hasOverdue = hasOverdue;

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

    // Block save when the Track Name is empty or whitespace-only. Surface an
    // inline error and abort before the save-confirm dialog so the user can
    // never proceed with a blank name.
    if (!validateTrackName(_nameController.text)) {
      setState(() => _nameError = l10n.trackEditNameRequired);
      return;
    }
    if (_nameError != null) {
      setState(() => _nameError = null);
    }

    // R1-(5): warn (non-blocking) when no study days are selected so the user
    // knows new learning will not be scheduled. Program tracks pace themselves,
    // so the warning only applies to self-paced tracks. Shown before the
    // confirm dialog (no async gap) so the messenger context is still valid.
    if (!_isProgramTrack && studyDayCount(_editedStudyDays) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Allow the warning to wrap onto multiple lines instead of being
          // clipped off-screen at large text scales (e.g. font scale 1.3).
          content: Text(l10n.trackEditZeroStudyDaysWarning, maxLines: 4),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }

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
      PaceTarget? newPaceTarget;
      String? newPaceGranularity;
      var clearPaceTarget = false;

      if (goal.goalType == 'pace') {
        // Always send a complete PacePeriodTarget when any pace field changed.
        final currentPaceValue = _paceValue;
        final currentPacePeriod = _pacePeriod;
        final existingPaceValue = goal.paceValue ?? 1;
        final existingPacePeriod = goal.pacePeriod ?? 'per_week';
        if (currentPaceValue != existingPaceValue ||
            currentPacePeriod != existingPacePeriod) {
          newPaceTarget = PacePeriodTarget(
            rate: currentPaceValue,
            period: currentPacePeriod,
          );
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
            clearPaceTarget = true;
          } else {
            newPaceTarget = DeadlineTarget(edited.toUtc());
          }
        }
      }

      try {
        await service.editTrack(
          trackId: widget.track.id,
          goalId: goal.id,
          profileId: profileId,
          curriculum: curriculum,
          label: newLabel,
          studyDays: _isProgramTrack ? null : _editedStudyDays,
          chazarahWizard: _isProgramTrack ? null : _pendingChazarah,
          paceTarget: newPaceTarget,
          paceGranularity: newPaceGranularity,
          clearPaceTarget: clearPaceTarget,
        );
      } on TutorWriteException catch (e, st) {
        // AUD-tracks-07: 'permission-denied' is one specific, expected
        // TutorWriteException code (the tutor's permissions changed
        // server-side). Any other code (e.g. 'internal', 'unavailable',
        // 'deadline-exceeded' -- all plausible on a flaky mobile
        // connection, per the throw site in tutored_write_router.dart)
        // must still surface feedback instead of silently returning: the
        // Save spinner clears via the outer `finally`, so a swallowed
        // failure here would leave the user on the same screen with zero
        // indication anything went wrong.
        if (e.code != 'permission-denied') {
          AppLogger.instance.error(
            event: 'edit_track_save_failed: code=${e.code}',
            exception: e,
            stackTrace: st,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.code == 'permission-denied'
                    ? l10n.tutorPermissionDenied
                    : l10n.errorSaveTrackFailed,
              ),
            ),
          );
        }
        return;
      }

      await onTrackChanged(ref, profileId);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearOverdue() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trackEditClearOverdueConfirmTitle),
        content: Text(l10n.trackEditClearOverdueConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.trackEditClearOverdueButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final curriculum = _curriculumId;
    if (curriculum == null) return;

    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final calendarService = await ref.read(
      calendarProgramServiceProvider.future,
    );

    final now = DateTimeFactory.nowLocal();
    final today = DateTime(now.year, now.month, now.day);
    // Use UTC midnight for the DB column (DateTimeColumn stores UTC).
    final todayUtc = DateTime.utc(today.year, today.month, today.day);

    // Resolve the enrollment and its calendar program key.
    final enrollment = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
    if (enrollment == null) return;

    final program = ref
        .read(learningProgramRepositoryProvider)
        .getProgramById(enrollment.programId);
    final apiKey = program?.apiProgramKey;

    String? todayRef;
    if (program != null && apiKey != null && apiKey.isNotEmpty) {
      final programKey =
          CalendarProgramRegistry.byId(apiKey)?.id ??
          CalendarProgramRegistry.byApiKey(apiKey)?.id ??
          CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;

      if (programKey != null) {
        final entry = await calendarService.getEntry(programKey, today);
        todayRef = entry?.todayRef;
      }
    }

    // Re-anchor: move tracking_start_date to today (UTC midnight).
    // tracking_start_ref is today's calendar unit (or null if the calendar
    // engine cannot resolve it — the projection uses the date, not the ref).
    await db.profileProgramDao.setProfileProgram(
      profileId: profileId,
      curriculumType: curriculum.storageKey,
      programId: enrollment.programId,
      trackingStartDate: todayUtc,
      trackingStartRef: todayRef,
    );

    // F-C1: Push the updated profile_program row to Firestore so the
    // new anchor survives reinstall / sync pull. Routes through
    // syncWriteFacadeProvider so a tutored session calls tutorSetProfileProgram
    // instead of the local outbox (which the isProfileTutored guard blocks).
    try {
      final syncFacade = ref.read(syncWriteFacadeProvider);
      await syncFacade?.pushProfileProgram({
        'profile_id': profileId,
        'curriculum_id': curriculum.storageKey,
        'program_id': enrollment.programId,
        'tracking_start_date': todayUtc.toIso8601String(),
        'tracking_start_ref': todayRef,
        'updated_at': todayUtc.toIso8601String(),
      });
    } catch (e, st) {
      AppLogger.instance.warning(
        event: 'clear_overdue_push_failed: curriculum=${curriculum.storageKey}',
        exception: e,
        stackTrace: st,
      );
    }

    await onTrackChanged(ref, profileId);

    if (mounted) setState(() => _hasOverdue = false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build helpers
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final canEditGoals = tutorPerms == null || tutorPerms.canEditGoals;
    final canEditStages = tutorPerms == null || tutorPerms.canEditStages;
    final canSave = canEditGoals && canEditStages;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trackEditTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        title: Text(
          l10n.trackEditTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandBlueDeep,
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
              onPressed: canSave
                  ? _save
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.tutorPermissionDenied)),
                    ),
              child: Text(
                l10n.trackEditSaveButton,
                style: const TextStyle(fontWeight: FontWeight.w700),
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
              onChanged: (_) {
                // Clear the inline error as soon as the user types a non-empty
                // value, so the error doesn't linger once it's resolved.
                if (_nameError != null &&
                    _nameController.text.trim().isNotEmpty) {
                  setState(() => _nameError = null);
                }
              },
              decoration: InputDecoration(
                errorText: _nameError,
                border: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: context.colors.surfaceGreyBlue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: context.colors.surfaceGreyBlue),
                ),
                contentPadding: const EdgeInsets.symmetric(
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
            // Per the per-track chazara rule, the entire Review section is
            // hidden when this track has no chazara stages — no chazara or
            // review references on a learn-only track, anywhere. Users who
            // want to add chazara to a learn-only track recreate it via
            // Add Track.
            if (ref
                    .watch(trackHasChazaraProvider(widget.track.id))
                    .asData
                    ?.value ??
                false) ...[
              const SizedBox(height: 14),
              _SectionCard(
                title: l10n.trackEditSectionReview(
                  domainTermLabels(ref).chazara,
                ),
                child: _buildChazaraSection(context, theme, l10n),
              ),
            ],
          ],
          if (_isProgramTrack) ...[
            const SizedBox(height: 14),
            _buildClearOverdueSection(theme, l10n),
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
            color: context.colors.surfaceBlueNeutral,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _goalTypeLabel(goal.goalType, l10n),
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colors.brandInkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.trackEditGoalTypeLocked,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.colors.brandInkMuted,
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
              semanticLabel: l10n.trackEditPaceDecrease,
            ),
            const SizedBox(width: 16),
            Text(
              '$_paceValue',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colors.brandBlueDeep,
              ),
            ),
            const SizedBox(width: 16),
            _StepperButton(
              icon: Icons.add_rounded,
              onPressed: () => setState(() => _paceValue++),
              semanticLabel: l10n.trackEditPaceIncrease,
            ),
            const SizedBox(width: 16),
            Text(
              periodLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.brandInkMuted,
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
          border: Border.all(color: context.colors.surfaceGreyBlue),
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
            const Icon(Icons.edit_rounded, size: 18),
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
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    return Column(
      children: [
        for (var i = 0; i < kStepStudyDayNumbers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          StudyDayCard(
            // Avatar initial = first grapheme of the LOCALIZED short label so
            // the column never mixes Latin initials with a lone Hebrew glyph
            // (matches StudyDaysEditable / finding 1).
            initial: studyDayInitial(
              studyDayAbbrevLabel(
                dayNum: kStepStudyDayNumbers[i],
                l10n: l10n,
                terms: terms,
                variant: variant,
              ),
            ),
            title: _dayName(kStepStudyDayNumbers[i]),
            subtitle: '',
            subtitleColor: context.colors.brandInkMuted,
            activeColor: context.colors.surfaceE9,
            isShabbos: kStepStudyDayNumbers[i] == 6,
            isOn: _editedStudyDays[kStepStudyDayNumbers[i]] == 'study',
            onChanged: (v) => setState(
              () => _editedStudyDays[kStepStudyDayNumbers[i]] = v
                  ? 'study'
                  : 'review',
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
    final delays = _pendingChazarah != null
        ? _pendingDelays()
        : _currentChazaraDelays;
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
                  color: context.colors.brandInk,
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

    final currentDelays = _pendingChazarah != null
        ? _pendingDelays()
        : _currentChazaraDelays;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceF5,
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
          headerTitle: l10n.trackEditSectionReview(
            domainTermLabels(ref).chazara,
          ),
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

  Widget _buildClearOverdueSection(ThemeData theme, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _hasOverdue ? _clearOverdue : null,
        icon: const Icon(Icons.clear_all_rounded),
        label: Text(l10n.trackEditClearOverdueButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: _hasOverdue ? Colors.red.shade600 : null,
          side: BorderSide(
            color: _hasOverdue ? Colors.red.shade300 : theme.disabledColor,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Color(0xFF6B84D6),
          ),
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
      'pace' =>
        '${l10n.trackEditSectionGoal} · ${l10n.pacePerDay}/${l10n.pacePerWeek}',
      'deadline' =>
        '${l10n.trackEditSectionGoal} · ${l10n.trackDetailConfigEstFinish}',
      _ => l10n.trackEditSectionGoal,
    };
  }

  String _chazaraSummary(List<int> delays, AppLocalizations l10n) {
    if (delays.isEmpty) return l10n.trackEditReviewSummaryNone;
    final joined = delays.map((d) => '$d').join(' + ');
    // Localize the day unit. The old code appended a hardcoded English
    // "day"/"days", which leaked into the Hebrew locale; the unit now comes
    // from an ICU plural inside the message itself. Pluralize on the number of
    // review rounds, matching the prior behaviour.
    return l10n.trackEditReviewSummaryWithDays(joined, delays.length);
  }

  /// Returns the locale-aware full weekday name for [dayNum].
  ///
  /// Convention: [dayNum] follows Dart's [DateTime.weekday] values
  /// (1 = Monday … 7 = Sunday), identical to [kStepStudyDayNumbers].
  /// Day 6 (Saturday) renders the app's term "Shabbos" (Ashkenazi) /
  /// "Shabbat" (Sephardi) / "שבת" (Hebrew Terms on) via [domainTermLabels],
  /// so it honours both the transliteration nusach and the Hebrew-Terms
  /// toggle — consistent with [StudyDaysEditable] and the sacred-time
  /// feature; other days are locale-formatted via [DateFormat].
  String _dayName(int dayNum) {
    if (dayNum == 6) {
      return domainTermLabels(
        ref,
      ).shabbos(variant: ref.watch(currentTransliterationVariantProvider));
    }
    final locale = Localizations.localeOf(context).languageCode;
    // Anchor: 2023-01-02 is a Monday (DateTime.weekday == 1).
    // Adding (dayNum - 1) days yields a date whose weekday == dayNum.
    final anchor = DateTime(2023, 1, 2);
    final date = anchor.add(Duration(days: dayNum - 1));
    return DateFormat('EEEE', locale).format(date);
  }
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
            color: context.colors.blueDeepNavy.withValues(alpha: 0.06),
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
              color: context.colors.brandInkMuted,
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
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });
  final IconData icon;
  final VoidCallback? onPressed;

  /// AUD-tracks-10 (AX-3): this control is icon-only, so it must carry an
  /// explicit, action-specific label for TalkBack/VoiceOver. Callers pass
  /// the ARB-sourced string (e.g. `l10n.trackEditPaceDecrease`).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: Material(
        color: context.colors.surfaceBlueNeutral,
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
                  ? context.colors.brandBlueDeep
                  : context.colors.brandInkMuted,
            ),
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
          color: isSelected
              ? context.colors.brandBlueBright
              : context.colors.surfaceBlueNeutral,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.colors.brandInkMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
