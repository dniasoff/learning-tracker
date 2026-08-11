import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart'
    show defaultPointsForStage, kMaxPointConfigPoints, kMinPointConfigPoints;
import 'package:learning_tracker/features/gamification/data/repositories/point_config_repository_impl.dart';
import 'package:learning_tracker/features/gamification/domain/models/point_config.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// Design tokens aligned with Point Settings mock (deep blue + orange accents).
Color _kScreenBg(BuildContext context) =>
    context.colors.gamifPointConfigScreenBg;
Color _kOrangeAccent(BuildContext context) =>
    context.colors.gamifPointConfigOrangeAccent;
Color _kActiveBadgeBg(BuildContext context) =>
    context.colors.gamifPointConfigActiveBadgeBg;
Color _kActiveBadgeInk(BuildContext context) =>
    context.colors.gamifPointConfigActiveBadgeInk;
Color _kHebrewSubtitleBlue(BuildContext context) =>
    context.colors.gamifPointConfigHebrewSubtitleBlue;
Color _kHeroBlueTop(BuildContext context) =>
    context.colors.gamifPointConfigHeroBlueTop;
Color _kHeroBlueBottom(BuildContext context) =>
    context.colors.gamifPointConfigHeroBlueBottom;

class _StagePointConfig {
  const _StagePointConfig({required this.stage, required this.config});

  final domain_stage.StageDefinition stage;
  final PointConfigEntity config;
}

class _TrackPointData {
  const _TrackPointData({required this.curriculum, required this.stages});

  final CurriculumId curriculum;
  final List<_StagePointConfig> stages;
}

/// Top-level Provider (not an inline construction inside a WidgetRef-scoped
/// method): the adapter needs a real `Ref`, which only a provider
/// callback's `Ref` satisfies -- see track_detail_screen.dart's identical
/// `_curriculumTrackRepositoryProvider` doc comment (same lesson, earlier
/// this session).
final _pointConfigRepositoryProvider =
    Provider<FirestorePointConfigRepositoryAdapter>(
      (ref) => FirestorePointConfigRepositoryAdapter(ref: ref),
    );

_StagePointConfig _primaryStageRow(_TrackPointData data) {
  return data.stages.reduce(
    (a, b) => a.stage.stageOrder <= b.stage.stageOrder ? a : b,
  );
}

/// A pure read of the current point-config rows for every active track.
/// Nothing is ever seeded here or anywhere else in this file (D-E:
/// `point_configs` is configuration-shaped — a missing override document
/// truthfully means "this parent never set one", not "not ready yet"; see
/// `FirestorePointConfigRepository`'s class-level doc comment). Stage
/// definitions are seeded once, on track creation, by
/// `TrackCreationService.createTrack` → `LearningProcessWizardService
/// .applyWizardResult` -- every active track reaching this screen already
/// has them.
///
/// A stage with no override document is rendered with an in-memory-only
/// default (`defaultPointsForStage`, never persisted) so the screen has
/// something sensible to show/edit; `_savePending`'s upsert doesn't read an
/// id, so editing a synthetic default round-trips correctly, and saving the
/// ladder's own value back clears the (nonexistent) override instead of
/// pinning it.
final pointConfigDataProvider = FutureProvider.autoDispose<List<_TrackPointData>>(
  (ref) async {
    final activeTracks = await ref.watch(activeTracksProvider.future);
    final pointConfigRepo = ref.watch(_pointConfigRepositoryProvider);

    final result = <_TrackPointData>[];
    for (final track in activeTracks) {
      final curriculum = track.curriculumId;

      final stageRepo = ref.read(stageDefinitionRepositoryProvider(curriculum));
      final stages = await stageRepo.getStagesForCurriculum(curriculum);
      // A track legitimately has no stage definitions yet only in the
      // narrow window mid-creation before applyWizardResult lands -- skip
      // it rather than fabricate rows for stages that do not exist.
      if (stages.isEmpty) continue;

      final configs = await pointConfigRepo.getConfigsForCurriculum(curriculum);

      final stageConfigs = <_StagePointConfig>[];
      for (final stage in stages) {
        PointConfigEntity? config;
        for (final c in configs) {
          if (c.stageOrder == stage.stageOrder) {
            config = c;
            break;
          }
        }
        // Unpersisted view-model default -- see doc comment above.
        config ??= PointConfigEntity(
          curriculumId: curriculum,
          stageOrder: stage.stageOrder,
          points: defaultPointsForStage(stage.stageOrder),
        );
        stageConfigs.add(_StagePointConfig(stage: stage, config: config));
      }

      result.add(_TrackPointData(curriculum: curriculum, stages: stageConfigs));
    }
    return result;
  },
);

@RoutePage()
class PointConfigScreen extends ConsumerStatefulWidget {
  const PointConfigScreen({super.key});

  @override
  ConsumerState<PointConfigScreen> createState() => _PointConfigScreenState();
}

class _PointConfigScreenState extends ConsumerState<PointConfigScreen> {
  /// Pending edits for the primary (lowest stage order) row per curriculum
  /// (AD-25: curriculum IS the track, there is no separate track id to key
  /// this map on any more).
  final Map<CurriculumId, int> _pendingPrimaryByCurriculum = {};
  bool _saving = false;

  int _effectivePrimaryPoints(_TrackPointData data) {
    final pending = _pendingPrimaryByCurriculum[data.curriculum];
    if (pending != null) return pending;
    return _primaryStageRow(data).config.points;
  }

  bool get _hasPendingEdits => _pendingPrimaryByCurriculum.isNotEmpty;

  Future<void> _savePending(List<_TrackPointData> tracks) async {
    if (!_hasPendingEdits || _saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final pointConfigRepo = ref.read(_pointConfigRepositoryProvider);

      for (final track in tracks) {
        final pending = _pendingPrimaryByCurriculum[track.curriculum];
        if (pending == null) continue;
        final primary = _primaryStageRow(track);
        // Saving back the ladder's own default clears the override instead
        // of pinning it as a doc that would no longer track the ladder if
        // it ever changes (see FirestorePointConfigRepository.clearOverride's
        // doc comment).
        if (pending == defaultPointsForStage(primary.stage.stageOrder)) {
          await pointConfigRepo.clearOverride(
            curriculumId: track.curriculum,
            stageOrder: primary.stage.stageOrder,
          );
        } else {
          await pointConfigRepo.upsertConfig(
            curriculumId: track.curriculum,
            stageOrder: primary.stage.stageOrder,
            points: pending,
          );
        }
      }

      if (mounted) {
        setState(() {
          _pendingPrimaryByCurriculum.clear();
          _saving = false;
        });
        ref.invalidate(pointConfigDataProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pointSettingsSavedSnackbar)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        final l10nMsg =
            (e is TutorWriteException && e.code == 'permission-denied')
            ? AppLocalizations.of(context)!.tutorPermissionDenied
            : AppLocalizations.of(context)!.errorGeneric(e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10nMsg)));
      }
    }
  }

  void _bumpPrimary(_TrackPointData data, int delta) {
    final current = _effectivePrimaryPoints(data);
    final next = math.max(
      kMinPointConfigPoints,
      math.min(kMaxPointConfigPoints, current + delta),
    );
    setState(() => _pendingPrimaryByCurriculum[data.curriculum] = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pointsAsync = ref.watch(pointConfigDataProvider);
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final canEdit = tutorPerms == null || tutorPerms.canEditPoints;

    return Scaffold(
      backgroundColor: _kScreenBg(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: context.colors.brandBlueDeep,
          onPressed: () => context.maybePop(),
        ),
        title: Text(
          l10n.pointSettingsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.colors.brandBlueDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: pointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            AppLocalizations.of(context)!.errorGeneric(error.toString()),
          ),
        ),
        data: (pointData) {
          if (pointData.isEmpty) {
            return EmptyState(
              icon: Icons.tune_rounded,
              message: l10n.noActiveTracks,
              subtitle: l10n.pointConfigNoActiveTracksBody,
              action: OutlinedButton.icon(
                onPressed: () => context.router.push(TrackManagementHubRoute()),
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(l10n.manageTracks),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _HeroHeader(l10n: l10n)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              color: _kOrangeAccent(context),
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.pointSettingsActiveCurricula,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.brandInk,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final data = pointData[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _CurriculumPointsCard(
                              l10n: l10n,
                              data: data,
                              showAccentStripe: index == 1,
                              primaryPoints: _effectivePrimaryPoints(data),
                              primaryStageName: _primaryStageRow(
                                data,
                              ).stage.stageName,
                              onDecrement:
                                  (canEdit && _effectivePrimaryPoints(data) > 1)
                                  ? () => _bumpPrimary(data, -1)
                                  : null,
                              onIncrement: canEdit
                                  ? () => _bumpPrimary(data, 1)
                                  : null,
                            ),
                          );
                        }, childCount: pointData.length),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
              _SaveBar(
                l10n: l10n,
                enabled: _hasPendingEdits && !_saving && canEdit,
                busy: _saving,
                onPressed: () => _savePending(pointData),
                onNothingToSave: () {
                  if (!canEdit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.tutorPermissionDenied)),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.pointSettingsNothingToSaveSnackbar),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 148),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kHeroBlueTop(context), _kHeroBlueBottom(context)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pointSettingsConfigurationLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.pointSettingsRewardsStrategyTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.pointSettingsRewardsStrategySubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            // AUD-gamification-02: PositionedDirectional(end:) for
            // consistency with achievement_tier_card.dart's badge fix --
            // these are decorative-only (IgnorePointer, low opacity), so the
            // physical-vs-logical corner doesn't change appearance today,
            // but keeps this file free of the Positioned(right:) pattern
            // the app's AX-1 rule bans.
            PositionedDirectional(
              end: -36,
              bottom: -40,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.14,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 40,
              bottom: -56,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.1,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
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

class _CurriculumPointsCard extends ConsumerWidget {
  const _CurriculumPointsCard({
    required this.l10n,
    required this.data,
    required this.showAccentStripe,
    required this.primaryPoints,
    required this.primaryStageName,
    required this.onDecrement,
    required this.onIncrement,
  });

  final AppLocalizations l10n;
  final _TrackPointData data;
  final bool showAccentStripe;
  final int primaryPoints;
  final String primaryStageName;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final terms = domainTermLabels(ref);
    final resolvedStageName = terms.resolveStoredStageName(primaryStageName);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CurriculumLabel.curriculum(
                        data.curriculum,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.colors.brandInk,
                        ),
                      ),
                      if (!terms.isHebrew) ...[
                        const SizedBox(height: 4),
                        Text(
                          curriculumHebrewName(data.curriculum),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _kHebrewSubtitleBlue(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _kActiveBadgeBg(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.pointSettingsActiveBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _kActiveBadgeInk(context),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.brandCreamSoft,
                borderRadius: BorderRadius.circular(18),
                border: showAccentStripe
                    ? Border(
                        left: BorderSide(
                          color: context.colors.brandBlue,
                          width: 4,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pointSettingsPointsPerTask,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.colors.brandInkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: _kOrangeAccent(context),
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$primaryPoints',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: _kOrangeAccent(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.pointSettingsPts,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _kOrangeAccent(
                                  context,
                                ).withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$resolvedStageName · ${l10n.pointSettingsPrimaryStageLabel}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.colors.brandInkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StepperControl(
                    value: primaryPoints,
                    onDecrement: onDecrement,
                    onIncrement: onIncrement,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundStepButton(
            icon: Icons.remove,
            filled: false,
            onPressed: onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$value',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colors.brandInk,
              ),
            ),
          ),
          _RoundStepButton(
            icon: Icons.add,
            filled: true,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? context.colors.brandBlue
        : context.colors.gamifPointConfigChipUnselectedBg;
    // AUD-darkmode: brandBlue lightens in dark mode, so a hardcoded white
    // icon on the filled "+" button measured 2.52:1. colorScheme.onPrimary
    // is the same dynamically-computed contrast-safe ink FilledButton
    // already uses for this exact accent colour.
    final fg = filled
        ? Theme.of(context).colorScheme.onPrimary
        : context.colors.brandInkMuted;
    final child = Icon(icon, size: 20, color: fg);
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.l10n,
    required this.enabled,
    required this.busy,
    required this.onPressed,
    required this.onNothingToSave,
  });

  final AppLocalizations l10n;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;
  final VoidCallback onNothingToSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.brandBlue,
                  // AUD-darkmode: brandBlue lightens in dark mode, so a
                  // hardcoded white foreground/spinner measured 2.52:1.
                  // colorScheme.onPrimary is the same dynamically-computed
                  // contrast-safe ink FilledButton already uses for this
                  // exact accent colour by default.
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (busy) return;
                  if (enabled) {
                    onPressed();
                  } else {
                    onNothingToSave();
                  }
                },
                icon: busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 22),
                label: Text(
                  l10n.pointSettingsSaveAll,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.pointSettingsSaveFooter,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.brandInkMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
