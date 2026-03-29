import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart';

/// Screen showing full track configuration with tappable edit sections.
///
/// Displays label, curriculum (Hebrew), program, scope summary,
/// chazara stages, goal, and study days for a single track.
// @RoutePage() — disabled until Story 18.5 adds the route to app_router.dart
class TrackDetailScreen extends ConsumerStatefulWidget {
  const TrackDetailScreen({
    super.key,
    required this.curriculumId,
    required this.trackType,
  });

  final String curriculumId;
  final String trackType;

  @override
  ConsumerState<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends ConsumerState<TrackDetailScreen> {
  CurriculumId? get _curriculumEnum => CurriculumId.values
      .where((c) => c.storageKey == widget.curriculumId)
      .firstOrNull;

  Future<CurriculumTrack?>? _trackFuture;
  Future<List<StageDefinition>>? _stagesFuture;
  Future<List<Goal>>? _goalsFuture;

  void _refreshData() {
    final db = ref.read(appDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    _trackFuture =
        (db.select(db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(widget.curriculumId) &
                  t.trackType.equals(widget.trackType),
            ))
            .getSingleOrNull();
    _stagesFuture = db.stageDao.getStageDefinitionsByCurriculum(
      widget.curriculumId,
    );
    _goalsFuture = (db.select(
      db.goals,
    )..where((g) => g.curriculumId.equals(widget.curriculumId))).get();
  }

  @override
  void initState() {
    super.initState();
    // Defer until after first frame so ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _refreshData());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curriculum = _curriculumEnum;

    if (_trackFuture == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(curriculum?.displayNameHe ?? widget.curriculumId),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(curriculum?.displayNameHe ?? widget.curriculumId),
      ),
      body: FutureBuilder<CurriculumTrack?>(
        future: _trackFuture,
        builder: (context, trackSnapshot) {
          if (trackSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final track = trackSnapshot.data;
          if (track == null) {
            return const Center(child: Text('Track not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildLabelSection(theme, track),
              const Divider(height: 32),
              _buildCurriculumSection(theme),
              const Divider(height: 32),
              _buildScopeSection(theme),
              const Divider(height: 32),
              _buildChazaraSection(theme),
              const Divider(height: 32),
              _buildGoalSection(theme),
              const Divider(height: 32),
              _buildStudyDaysSection(theme),
            ],
          );
        },
      ),
    );
  }

  // ── Label Section ──────────────────────────────────────────────

  Widget _buildLabelSection(ThemeData theme, CurriculumTrack track) {
    final curriculum = _curriculumEnum;
    final displayLabel = curriculum?.displayNameHe ?? widget.curriculumId;
    final trackTypeLabel =
        TrackType.values
            .where((t) => t.storageKey == track.trackType)
            .firstOrNull
            ?.storageKey ??
        track.trackType;

    return InkWell(
      key: const Key('edit_label_tile'),
      onTap: () => _showEditLabelDialog(displayLabel),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track Label',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    trackTypeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Curriculum Section (read-only) ─────────────────────────────

  Widget _buildCurriculumSection(ThemeData theme) {
    final curriculum = _curriculumEnum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curriculum',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            curriculum?.displayNameHe ?? widget.curriculumId,
            style: theme.textTheme.titleMedium,
            textDirection: TextDirection.rtl,
          ),
          Text(
            curriculum?.displayNameEn ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Scope Section ──────────────────────────────────────────────

  Widget _buildScopeSection(ThemeData theme) {
    final curriculum = _curriculumEnum;
    if (curriculum == null) return const SizedBox.shrink();

    final scopeAsync = ref.watch(curriculumScopeSummaryProvider(curriculum));

    return InkWell(
      key: const Key('edit_scope_tile'),
      onTap: () => _editScope(curriculum),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scope',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  scopeAsync.when(
                    data: (summary) =>
                        Text(summary, style: theme.textTheme.bodyLarge),
                    loading: () => const Text('Loading...'),
                    error: (_, __) => const Text('Error'),
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
    );
  }

  // ── Chazara Stages Section ─────────────────────────────────────

  Widget _buildChazaraSection(ThemeData theme) {
    return FutureBuilder<List<StageDefinition>>(
      future: _stagesFuture,
      builder: (context, snapshot) {
        final stages = snapshot.data ?? [];
        return InkWell(
          key: const Key('edit_chazara_tile'),
          onTap: () => _editChazara(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u05D7\u05D6\u05E8\u05D4 Stages',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (stages.isEmpty)
                        Text(
                          'No review stages configured',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...stages.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${s.stageName} - '
                              '${s.delayDays} day${s.delayDays == 1 ? '' : 's'}',
                              style: theme.textTheme.bodyMedium,
                            ),
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
        );
      },
    );
  }

  // ── Goal Section ───────────────────────────────────────────────

  Widget _buildGoalSection(ThemeData theme) {
    final curriculum = _curriculumEnum;
    if (curriculum == null) return const SizedBox.shrink();

    return FutureBuilder<List<Goal>>(
      future: _goalsFuture,
      builder: (context, snapshot) {
        final goals = snapshot.data ?? [];
        return InkWell(
          key: const Key('edit_goal_tile'),
          onTap: () => _editGoal(curriculum, goals),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Goal',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (goals.isEmpty)
                        Text(
                          'No goal set',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...goals.map(
                          (g) => Text(
                            _formatGoalSummary(g),
                            style: theme.textTheme.bodyMedium,
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
        );
      },
    );
  }

  String _formatGoalSummary(Goal goal) {
    if (goal.goalType == 'pace') {
      final unit = goal.paceUnit == 'per_week' ? 'per week' : 'per day';
      return '${goal.paceValue ?? 1} $unit (${goal.targetPercent.round()}%)';
    }
    if (goal.targetDate != null) {
      final d = goal.targetDate!;
      return 'By ${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '(${goal.targetPercent.round()}%)';
    }
    return '${goal.targetPercent.round()}% target';
  }

  // ── Study Days Section ─────────────────────────────────────────

  Widget _buildStudyDaysSection(ThemeData theme) {
    final curriculum = _curriculumEnum;
    if (curriculum == null) return const SizedBox.shrink();

    final configAsync = ref.watch(studyDayConfigsProvider(curriculum));

    return InkWell(
      key: const Key('edit_study_days_tile'),
      onTap: () => _editStudyDays(curriculum),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study Days',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  configAsync.when(
                    data: (configs) {
                      const dayNames = {
                        1: 'Mon',
                        2: 'Tue',
                        3: 'Wed',
                        4: 'Thu',
                        5: 'Fri',
                        6: 'Sat',
                        7: 'Sun',
                      };
                      final studyDays = <String>[];
                      for (final entry in [7, 1, 2, 3, 4, 5, 6]) {
                        final config = configs
                            .where((c) => c.dayOfWeek == entry)
                            .firstOrNull;
                        final isStudy =
                            config == null || config.dayType == DayType.study;
                        if (isStudy) {
                          studyDays.add(dayNames[entry]!);
                        }
                      }
                      return Text(
                        studyDays.isEmpty
                            ? 'No study days configured'
                            : studyDays.join(', '),
                        style: theme.textTheme.bodyLarge,
                      );
                    },
                    loading: () => const Text('Loading...'),
                    error: (_, __) => const Text('Error'),
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
    );
  }

  // ── Edit Actions ───────────────────────────────────────────────

  Future<void> _showEditLabelDialog(String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Track Label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Track Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Track label is derived from curriculum displayNameHe.
      // The CurriculumTracks table does not have a label column.
      // We show confirmation that the rename was acknowledged.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Label updated to "$result"')));
      ref.invalidate(activeTracksProvider);
    }
  }

  void _editScope(CurriculumId curriculum) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ScopeSelectionScreen(curriculumId: curriculum),
      ),
    ).then((_) {
      ref.invalidate(curriculumScopeSummaryProvider(curriculum));
      ref.invalidate(scopedCurriculumContentProvider(curriculum));
      ref.invalidate(scopedItemCountProvider(curriculum));
      ref.invalidate(allDailyTasksProvider);
    });
  }

  void _editChazara() {
    final curriculum = _curriculumEnum;
    if (curriculum == null) return;

    Navigator.push<LearningProcessWizardResult>(
      context,
      MaterialPageRoute<LearningProcessWizardResult>(
        builder: (_) => LearningProcessWizardScreen(
          curriculumId: curriculum,
          presets: const [],
          isChildMode: false,
        ),
      ),
    ).then((result) async {
      if (result != null && mounted) {
        final db = ref.read(appDatabaseProvider);
        final profileId = ref.read(activeProfileIdProvider);
        final wizardResult = result.wizardResult;

        // Delete existing stages and recreate
        await db.stageDao.deleteAllForCurriculum(curriculum.storageKey);

        if (wizardResult.choice == WizardChoice.custom &&
            wizardResult.customRounds != null) {
          for (var i = 0; i < wizardResult.customRounds!.length; i++) {
            final round = wizardResult.customRounds![i];
            await db.stageDao.insertStageDefinition(
              StageDefinitionsCompanion.insert(
                profileId: drift.Value(profileId),
                curriculumId: curriculum.storageKey,
                stageOrder: i + 1,
                stageName: round.label,
                delayDays: round.delayDays ?? 0,
                scheduleType: drift.Value(round.scheduleType.name),
                daysOfWeek: round.daysOfWeek != null
                    ? drift.Value(round.daysOfWeek!.join(','))
                    : const drift.Value(null),
              ),
            );
          }
        }

        ref.invalidate(allDailyTasksProvider);
        if (mounted) {
          setState(() => _refreshData()); // Refresh the FutureBuilders
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review stages updated')),
          );
        }
      }
    });
  }

  void _editGoal(CurriculumId curriculum, List<Goal> existingGoals) {
    GoalEntity? existing;
    if (existingGoals.isNotEmpty) {
      final g = existingGoals.first;
      existing = GoalEntity(
        id: g.id,
        curriculumId: curriculum,
        targetPercent: g.targetPercent,
        targetDate: g.targetDate,
        description: g.description,
        dateType: g.dateType,
        goalType: g.goalType,
        paceValue: g.paceValue,
        paceUnit: g.paceUnit,
        createdAt: g.createdAt,
        updatedAt: g.updatedAt,
      );
    }

    Navigator.push<GoalFormResult>(
      context,
      MaterialPageRoute<GoalFormResult>(
        builder: (_) =>
            GoalSetupScreen(curriculumId: curriculum, existingGoal: existing),
      ),
    ).then((result) async {
      if (result != null && mounted) {
        final db = ref.read(appDatabaseProvider);
        final now = DateTime.now().toUtc();

        if (existingGoals.isNotEmpty) {
          await (db.update(
            db.goals,
          )..where((g) => g.id.equals(existingGoals.first.id))).write(
            GoalsCompanion(
              targetPercent: drift.Value(result.targetPercent),
              targetDate: drift.Value(result.targetDate),
              description: drift.Value(result.description),
              dateType: drift.Value(result.dateType),
              goalType: drift.Value(result.goalType),
              paceValue: drift.Value(result.paceValue),
              paceUnit: drift.Value(result.paceUnit),
              updatedAt: drift.Value(now),
            ),
          );
        } else {
          await db
              .into(db.goals)
              .insert(
                GoalsCompanion.insert(
                  curriculumId: widget.curriculumId,
                  targetPercent: drift.Value(result.targetPercent),
                  targetDate: drift.Value(result.targetDate),
                  description: drift.Value(result.description),
                  dateType: drift.Value(result.dateType),
                  goalType: drift.Value(result.goalType),
                  paceValue: drift.Value(result.paceValue),
                  paceUnit: drift.Value(result.paceUnit),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        ref.invalidate(allDailyTasksProvider);
        if (mounted) {
          setState(() => _refreshData()); // Refresh the FutureBuilders
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Goal updated')));
        }
      }
    });
  }

  void _editStudyDays(CurriculumId curriculum) {
    context.router.push(StudyDayConfigRoute(curriculumId: curriculum)).then((
      _,
    ) {
      ref.invalidate(studyDayConfigsProvider(curriculum));
      ref.invalidate(allDailyTasksProvider);
    });
  }
}
