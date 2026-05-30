import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// Design tokens aligned with Point Settings mock (deep blue + orange accents).
const Color _kScreenBg = Color(0xFFF8F9FB);
const Color _kOrangeAccent = Color(0xFFF5A623);
const Color _kActiveBadgeBg = Color(0xFFFFE4D1);
const Color _kActiveBadgeInk = Color(0xFF5C4033);
const Color _kHebrewSubtitleBlue = Color(0xFF5B9BD5);
const Color _kHeroBlueTop = Color(0xFF002D9C);
const Color _kHeroBlueBottom = Color(0xFF001F6E);

/// Matches [PointConfigDao.seedDefaults] descending defaults per stage order.
int _defaultPointsForStageOrder(int stageOrder) {
  const defaultPoints = [10, 5, 3, 2, 1];
  final idx = stageOrder - 1;
  if (idx >= 0 && idx < defaultPoints.length) return defaultPoints[idx];
  return 1;
}

class _StagePointConfig {
  const _StagePointConfig({required this.stage, required this.config});

  final domain_stage.StageDefinition stage;
  final PointConfig config;
}

class _TrackPointData {
  const _TrackPointData({
    required this.curriculum,
    required this.profileId,
    required this.trackId,
    required this.stages,
  });

  final CurriculumId curriculum;
  final int profileId;
  final int trackId;
  final List<_StagePointConfig> stages;
}

_StagePointConfig _primaryStageRow(_TrackPointData data) {
  return data.stages.reduce(
    (a, b) => a.stage.stageOrder <= b.stage.stageOrder ? a : b,
  );
}

final _pointConfigDataProvider = FutureProvider.autoDispose<List<_TrackPointData>>(
  (ref) async {
    final db = ref.watch(userDatabaseProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final sync = ref.read(syncWriteFacadeProvider);

    // Same query as [activeTracksProvider] / dashboard; watch the stream so we
    // rebuild when tracks change, but avoid awaiting another provider's .future
    // (can stall tests). Fall back to a one-shot read while the stream is idle.
    final tracksAsync = ref.watch(activeTracksProvider);
    final activeTracks = switch (tracksAsync) {
      AsyncData(:final value) => value,
      AsyncLoading() => await db.trackDao.getActiveTracksForProfile(profileId),
      AsyncError() => await db.trackDao.getActiveTracksForProfile(profileId),
    };

    var wroteConfigs = false;
    final result = <_TrackPointData>[];
    for (final track in activeTracks) {
      final curriculum = CurriculumId.values
          .where((c) => c.storageKey == track.curriculumId)
          .firstOrNull;
      if (curriculum == null) continue;

      final stageRepo = ref.read(stageDefinitionRepositoryProvider(curriculum));
      var stages = await stageRepo.getStagesByTrack(track.id);
      if (stages.isEmpty) {
        await stageRepo.initializeDefaults(
          curriculum,
          profileId: profileId,
          trackId: track.id,
        );
        stages = await stageRepo.getStagesByTrack(track.id);
      }
      if (stages.isEmpty) {
        continue;
      }

      final configs = await db.pointConfigDao.getConfigsByCurriculum(
        curriculum.storageKey,
        profileId: profileId,
        trackId: track.id,
      );

      final stageConfigs = <_StagePointConfig>[];
      for (final stage in stages) {
        PointConfig? config;
        for (final c in configs) {
          if (c.stageOrder == stage.stageOrder) {
            config = c;
            break;
          }
        }
        if (config == null) {
          await db.pointConfigDao.upsertConfig(
            PointConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: curriculum.storageKey,
              trackId: track.id,
              stageOrder: stage.stageOrder,
              points: _defaultPointsForStageOrder(stage.stageOrder),
            ),
          );
          wroteConfigs = true;
          config = await db.pointConfigDao.getConfig(
            curriculum.storageKey,
            stage.stageOrder,
            profileId: profileId,
            trackId: track.id,
          );
        }
        if (config != null) {
          stageConfigs.add(_StagePointConfig(stage: stage, config: config));
        }
      }

      result.add(
        _TrackPointData(
          curriculum: curriculum,
          profileId: profileId,
          trackId: track.id,
          stages: stageConfigs,
        ),
      );
    }
    if (wroteConfigs) {
      await sync?.pushGamificationSettingsSnapshot();
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
  /// Pending edits for the primary (lowest stage order) row per track.
  final Map<int, int> _pendingPrimaryByTrackId = {};
  bool _saving = false;

  int _effectivePrimaryPoints(_TrackPointData data) {
    final pending = _pendingPrimaryByTrackId[data.trackId];
    if (pending != null) return pending;
    return _primaryStageRow(data).config.points;
  }

  bool get _hasPendingEdits => _pendingPrimaryByTrackId.isNotEmpty;

  Future<void> _savePending(List<_TrackPointData> tracks) async {
    if (!_hasPendingEdits || _saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final db = ref.read(userDatabaseProvider);
      final profileId = ref.read(activeProfileIdProvider);
      final sync = ref.read(syncWriteFacadeProvider);

      for (final track in tracks) {
        final pending = _pendingPrimaryByTrackId[track.trackId];
        if (pending == null) continue;
        final primary = _primaryStageRow(track);
        await db.pointConfigDao.upsertConfig(
          PointConfigsCompanion(
            profileId: Value(profileId),
            curriculumId: Value(track.curriculum.storageKey),
            trackId: Value(track.trackId),
            stageOrder: Value(primary.stage.stageOrder),
            points: Value(pending),
          ),
        );
      }

      await sync?.pushGamificationSettingsSnapshot();
      if (mounted) {
        setState(() {
          _pendingPrimaryByTrackId.clear();
          _saving = false;
        });
        ref.invalidate(_pointConfigDataProvider);
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
    final next = math.max(1, math.min(9999, current + delta));
    setState(() => _pendingPrimaryByTrackId[data.trackId] = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pointsAsync = ref.watch(_pointConfigDataProvider);
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final canEdit = tutorPerms == null || tutorPerms.canEditPoints;

    return Scaffold(
      backgroundColor: _kScreenBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppTheme.brandBlueDeep,
          onPressed: () => context.maybePop(),
        ),
        title: Text(
          l10n.pointSettingsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.brandBlueDeep,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.pointConfigNoActiveTracksBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
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
                            const Icon(
                              Icons.menu_book_rounded,
                              color: _kOrangeAccent,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.pointSettingsActiveCurricula,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.brandInk,
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kHeroBlueTop, _kHeroBlueBottom],
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
            Positioned(
              right: -36,
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
            Positioned(
              right: 40,
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
      color: Colors.white,
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
                          color: AppTheme.brandInk,
                        ),
                      ),
                      if (!terms.isHebrew) ...[
                        const SizedBox(height: 4),
                        Text(
                          curriculumHebrewName(data.curriculum),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _kHebrewSubtitleBlue,
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
                    color: _kActiveBadgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.pointSettingsActiveBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _kActiveBadgeInk,
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
                color: AppTheme.brandCreamSoft,
                borderRadius: BorderRadius.circular(18),
                border: showAccentStripe
                    ? const Border(
                        left: BorderSide(color: AppTheme.brandBlue, width: 4),
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
                            color: AppTheme.brandInkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: _kOrangeAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$primaryPoints',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: _kOrangeAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.pointSettingsPts,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _kOrangeAccent.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$resolvedStageName · ${l10n.pointSettingsPrimaryStageLabel}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.brandInkSoft,
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
        color: Colors.white,
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
                color: AppTheme.brandInk,
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
    final bg = filled ? AppTheme.brandBlue : const Color(0xFFE8EBF0);
    final fg = filled ? Colors.white : AppTheme.brandInkMuted;
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
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
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
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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
                color: AppTheme.brandInkMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
