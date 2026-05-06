import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class RewardConfigurationScreen extends ConsumerStatefulWidget {
  const RewardConfigurationScreen({super.key});

  @override
  ConsumerState<RewardConfigurationScreen> createState() =>
      _RewardConfigurationScreenState();
}

class _RewardConfigurationScreenState extends ConsumerState<RewardConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CurriculumTrack> _tracks = [];
  int? _selectedTrackId;
  List<RewardMilestone> _milestones = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _bootstrap();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    unawaited(_reloadMilestones());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = ref.read(userDatabaseProvider);
      final profileId = ref.read(activeProfileIdProvider);
      final tracks = await db.trackDao.getActiveTracksForProfile(profileId);
      final svc = RewardMilestoneService(db, profileId: profileId);
      for (final t in tracks) {
        if (await svc.trackCountsTowardRewardPoints(t.id)) {
          await svc.ensureDefaultsForTrack(t.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _selectedTrackId = tracks.isNotEmpty ? tracks.first.id : null;
        _loading = false;
      });
      await _reloadMilestones();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _reloadMilestones() async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);

    if (_tabController.index == 1) {
      final list = await svc.getGlobalMilestones();
      if (mounted) setState(() => _milestones = list);
      return;
    }

    if (_selectedTrackId == null) {
      if (mounted) setState(() => _milestones = []);
      return;
    }

    await svc.ensureDefaultsForTrack(_selectedTrackId!);
    final list = await svc.getMilestonesForTrack(_selectedTrackId!);
    if (mounted) setState(() => _milestones = list);
  }

  String _trackTitle(CurriculumTrack track, AppLocalizations l10n) {
    final c = CurriculumId.values
        .where((x) => x.storageKey == track.curriculumId)
        .firstOrNull;
    if (c == null) return track.curriculumId;
    final code = Localizations.localeOf(context).languageCode;
    return code == 'he' ? c.displayNameHe : c.displayNameEn;
  }

  Future<void> _invalidateChildRewardProviders() async {
    ref.invalidate(achievementsOverviewProvider);
    ref.invalidate(dashboardChildNextRewardProvider);
  }

  Future<void> _persistAndSync() async {
    await ref.read(syncEngineProvider)?.pushGamificationSettingsSnapshot();
    await _invalidateChildRewardProviders();
  }

  bool _hasDuplicateThreshold(int threshold, {String? excludeId}) {
    for (final m in _milestones) {
      if (excludeId != null && m.id == excludeId) continue;
      if (m.thresholdPoints == threshold) return true;
    }
    return false;
  }

  Future<void> _showMilestoneEditor({
    RewardMilestone? existing,
    required bool isGlobal,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final pointsCtrl = TextEditingController(
      text: existing != null ? '${existing.thresholdPoints}' : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            existing == null ? l10n.rewardConfigAddReward : l10n.rewardConfigEditReward,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: l10n.rewardConfigRewardNameLabel),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pointsCtrl,
                decoration: InputDecoration(
                  labelText: l10n.rewardConfigPointsThresholdLabel,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.rewardConfigSaveReward),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) {
      titleCtrl.dispose();
      pointsCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final pointsParsed = int.tryParse(pointsCtrl.text.trim()) ?? 0;
    titleCtrl.dispose();
    pointsCtrl.dispose();

    if (title.isEmpty || pointsParsed <= 0) return;

    if (_hasDuplicateThreshold(pointsParsed, excludeId: existing?.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rewardConfigDuplicateThreshold)),
        );
      }
      return;
    }

    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    final trackId = isGlobal
        ? RewardMilestone.kGlobalTrackSentinel
        : _selectedTrackId!;

    await svc.upsertMilestone(
      trackId: trackId,
      title: title,
      thresholdPoints: pointsParsed,
      milestoneId: existing?.id,
      isEnabled: existing?.isEnabled ?? true,
    );
    await _persistAndSync();
    await _reloadMilestones();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.rewardConfigSaved)));
    }
  }

  Future<void> _toggleEnabled(RewardMilestone m, bool isGlobal) async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    await svc.upsertMilestone(
      trackId: m.trackId,
      title: m.title,
      thresholdPoints: m.thresholdPoints,
      milestoneId: m.id,
      isEnabled: !m.isEnabled,
    );
    await _persistAndSync();
    await _reloadMilestones();
  }

  Future<void> _confirmDelete(RewardMilestone m) async {
    final l10n = AppLocalizations.of(context)!;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteReward),
        content: Text(l10n.deleteRewardConfirm(m.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteReward),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    await svc.removeMilestone(m.id);
    await _persistAndSync();
    await _reloadMilestones();
  }

  Widget _buildMilestoneList(bool isGlobal) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_milestones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.rewardConfigEmptyMilestones,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
        ),
      );
    }

    final sorted = [..._milestones]
      ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = sorted[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            title: Text(
              m.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${l10n.rewardConfigPointsThresholdLabel}: ${m.thresholdPoints}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: m.isEnabled,
                  onChanged: (_) => _toggleEnabled(m, isGlobal),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showMilestoneEditor(
                    existing: m,
                    isGlobal: isGlobal,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  onPressed: () => _confirmDelete(m),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerTrackTab(AppLocalizations l10n) {
    if (_tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.rewardConfigNoActiveTracks,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.rewardConfigPerTrackHelper,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.brandInkMuted,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<int>(
            // Controlled selection; `initialValue` does not update when track changes.
            // ignore: deprecated_member_use
            value: _selectedTrackId,
            decoration: InputDecoration(
              labelText: l10n.rewardConfigSelectTrack,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              for (final t in _tracks)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(_trackTitle(t, l10n)),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() => _selectedTrackId = id);
              unawaited(_reloadMilestones());
            },
          ),
        ),
        Expanded(child: _buildMilestoneList(false)),
      ],
    );
  }

  Widget _buildGlobalTab(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l10n.rewardConfigTotalPointsHelper,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.brandInkMuted,
                ),
          ),
        ),
        Expanded(child: _buildMilestoneList(true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isGlobalTab = _tabController.index == 1;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.rewardConfigurationTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.rewardConfigurationTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppTheme.brandBlueDeep,
          onPressed: () => context.maybePop(),
        ),
        title: Text(
          l10n.rewardConfigurationTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.brandBlueDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandBlueDeep,
          unselectedLabelColor: AppTheme.brandInkMuted,
          indicatorColor: AppTheme.brandBlueBright,
          tabs: [
            Tab(text: l10n.rewardConfigPerTrackTab),
            Tab(text: l10n.rewardConfigTotalPointsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerTrackTab(l10n),
          _buildGlobalTab(l10n),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!isGlobalTab && (_tracks.isEmpty || _selectedTrackId == null)) {
            return;
          }
          _showMilestoneEditor(
            existing: null,
            isGlobal: isGlobalTab,
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.rewardConfigAddReward),
      ),
    );
  }
}
