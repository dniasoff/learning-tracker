import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// High-fidelity parent reward screen (navy #00218D, orange #F2994A).
const Color _kNavy = Color(0xFF00218D);
const Color _kOrange = Color(0xFFF2994A);
const Color _kPageBg = Color(0xFFF4F6FB);
const Color _kFieldFill = Color(0xFFF2F4F8);
const Color _kPreviewBg = Color(0xFFEEF3FA);
const Color _kMutedLabel = Color(0xFF6B7280);
const Color _kCardWhite = Color(0xFFFFFFFF);

@RoutePage()
class RewardConfigurationScreen extends ConsumerStatefulWidget {
  const RewardConfigurationScreen({super.key});

  @override
  ConsumerState<RewardConfigurationScreen> createState() =>
      _RewardConfigurationScreenState();
}

class _RewardConfigurationScreenState extends ConsumerState<RewardConfigurationScreen> {
  static const List<IconData> _avatarIcons = [
    Icons.menu_book_rounded,
    Icons.auto_stories_rounded,
    Icons.import_contacts_rounded,
  ];

  final _nameController = TextEditingController();
  final _pointsController = TextEditingController();

  List<CurriculumTrack> _tracks = [];
  int? _selectedTrackId;
  bool _isGlobalReward = false;
  int _iconIndex = 0;
  String? _editingMilestoneId;
  bool _loading = true;
  String? _error;

  /// Total-points ladder when there are no active tracks, or when the parent
  /// explicitly chose "Total points".
  bool get _usesGlobalLadder => _tracks.isEmpty || _isGlobalReward;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _pointsController.addListener(() => setState(() {}));
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pointsController.dispose();
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
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _selectedTrackId = tracks.isNotEmpty ? tracks.first.id : null;
        if (tracks.isEmpty) {
          _isGlobalReward = true;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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

  void _clearForm() {
    setState(() {
      _editingMilestoneId = null;
      _iconIndex = 0;
      _nameController.clear();
      _pointsController.clear();
      if (_tracks.isEmpty) {
        _isGlobalReward = true;
      }
    });
  }

  void _applyMilestoneToForm(RewardMilestone m) {
    setState(() {
      _editingMilestoneId = m.id;
      final globalMilestone =
          m.trackId == RewardMilestone.kGlobalTrackSentinel;
      _isGlobalReward = _tracks.isEmpty || globalMilestone;
      if (!_isGlobalReward) {
        _selectedTrackId = m.trackId;
      }
      _iconIndex = m.iconIndex.clamp(0, _avatarIcons.length - 1);
      _nameController.text = m.title;
      _pointsController.text = '${m.thresholdPoints}';
    });
  }

  Future<List<RewardMilestone>> _milestonesForCurrentLadder() async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    if (_usesGlobalLadder) {
      return svc.getGlobalMilestones();
    }
    final tid = _selectedTrackId;
    if (tid == null) return const [];
    return svc.getMilestonesForTrack(tid);
  }

  Future<bool> _hasDuplicateThresholdAsync(
    int threshold, {
    String? excludeId,
  }) async {
    final list = await _milestonesForCurrentLadder();
    for (final m in list) {
      if (excludeId != null && m.id == excludeId) continue;
      if (m.thresholdPoints == threshold) return true;
    }
    return false;
  }

  Future<void> _saveReward() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _nameController.text.trim();
    final pointsParsed = int.tryParse(_pointsController.text.trim()) ?? 0;
    final wasEditing = _editingMilestoneId != null;

    if (title.isEmpty || pointsParsed <= 0) {
      return;
    }

    if (!_usesGlobalLadder && _selectedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rewardConfigNoActiveTracks)),
      );
      return;
    }

    if (await _hasDuplicateThresholdAsync(
      pointsParsed,
      excludeId: _editingMilestoneId,
    )) {
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
    final trackId = _usesGlobalLadder
        ? RewardMilestone.kGlobalTrackSentinel
        : _selectedTrackId!;

    await svc.upsertMilestone(
      trackId: trackId,
      title: title,
      thresholdPoints: pointsParsed,
      milestoneId: _editingMilestoneId,
      isEnabled: true,
      iconIndex: _iconIndex.clamp(0, _avatarIcons.length - 1),
    );
    await _persistAndSync();
    _clearForm();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          wasEditing
              ? l10n.rewardConfigRewardUpdatedTitle
              : l10n.rewardConfigRewardCreatedTitle,
        ),
        content: Text(
          wasEditing
              ? l10n.rewardConfigRewardUpdatedBody(title)
              : l10n.rewardConfigRewardCreatedBody(title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).okButtonLabel,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEnabled(RewardMilestone m) async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    await svc.upsertMilestone(
      trackId: m.trackId,
      title: m.title,
      thresholdPoints: m.thresholdPoints,
      milestoneId: m.id,
      isEnabled: !m.isEnabled,
      iconIndex: m.iconIndex,
    );
    await _persistAndSync();
    if (mounted) setState(() {});
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
    if (_editingMilestoneId == m.id) _clearForm();
    if (mounted) setState(() {});
  }

  Future<void> _openManageRewardsSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.rewardConfigMenuManageRewards,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.42,
                  child: _ManageRewardsList(
                    load: _milestonesForCurrentLadder,
                    onEdit: (m) {
                      Navigator.pop(ctx);
                      _applyMilestoneToForm(m);
                    },
                    onDelete: (m) async {
                      Navigator.pop(ctx);
                      await _confirmDelete(m);
                    },
                    onToggle: (m) async {
                      await _toggleEnabled(m);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int get _previewPoints =>
      int.tryParse(_pointsController.text.trim()) ?? 0;

  String get _previewTitle {
    final t = _nameController.text.trim();
    if (t.isEmpty) {
      return AppLocalizations.of(context)!.rewardConfigNamePlaceholder;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topInset = MediaQuery.paddingOf(context).top;

    if (_loading) {
      return const Scaffold(
        backgroundColor: _kPageBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(title: Text(l10n.rewardConfigurationTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      backgroundColor: _kPageBg,
      body: Column(
        children: [
          _RewardConfigHeader(
            topInset: topInset,
            title: l10n.rewardConfigScreenContextLabel,
            onBack: () => context.maybePop(),
            onMenuSelected: (value) {
              if (value == 'manage') unawaited(_openManageRewardsSheet());
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _kCardWhite,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1200218D),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.rewardConfigConfigureNewTitle,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              fontSize: 22,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.rewardConfigConfigureNewSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _kMutedLabel,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        l10n.rewardConfigChooseAvatarStep,
                        style: const TextStyle(
                          color: _kNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < _avatarIcons.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: _AvatarTile(
                                icon: _avatarIcons[i],
                                selected: _iconIndex == i,
                                onTap: () => setState(() => _iconIndex = i),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        l10n.rewardConfigRewardNameLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _kMutedLabel,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: l10n.rewardConfigNamePlaceholder,
                          filled: true,
                          fillColor: _kFieldFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          suffixIcon: Icon(
                            Icons.edit_outlined,
                            color: _kMutedLabel.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.rewardConfigRewardTypeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _kMutedLabel,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _RewardTypeSegmented(
                        perTrackLabel: l10n.rewardConfigPerTrackTab,
                        totalLabel: l10n.rewardConfigTotalPointsTab,
                        perTrackEnabled: _tracks.isNotEmpty,
                        isGlobal: _usesGlobalLadder,
                        onChanged: (global) {
                          if (_tracks.isEmpty) {
                            setState(() => _isGlobalReward = true);
                            return;
                          }
                          setState(() => _isGlobalReward = global);
                        },
                      ),
                      if (!_usesGlobalLadder) ...[
                        const SizedBox(height: 18),
                        Text(
                          l10n.rewardConfigChooseTrackLabel,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _kMutedLabel,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _kFieldFill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              // ignore: deprecated_member_use
                              value: _selectedTrackId,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _kNavy,
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
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: _pointsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.rewardConfigPointsPlaceholder,
                          filled: true,
                          fillColor: _kFieldFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          suffixIcon: const Icon(
                            Icons.star_rounded,
                            color: _kOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kPreviewBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.rewardConfigPreviewLabel,
                              style: const TextStyle(
                                color: _kNavy,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _avatarIcons[_iconIndex.clamp(
                                      0,
                                      _avatarIcons.length - 1,
                                    )],
                                    color: _kNavy,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _previewTitle,
                                        style: const TextStyle(
                                          color: _kNavy,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: _kOrange,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            l10n.rewardConfigPointsPreview(
                                              _previewPoints,
                                            ),
                                            style: const TextStyle(
                                              color: _kOrange,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _clearForm,
                          child: Text(
                            l10n.rewardConfigCancel,
                            style: const TextStyle(
                              color: _kMutedLabel,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _saveReward,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: Text(
                            l10n.rewardConfigSaveRewardButton,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardConfigHeader extends StatelessWidget {
  const _RewardConfigHeader({
    required this.topInset,
    required this.title,
    required this.onBack,
    required this.onMenuSelected,
  });

  final double topInset;
  final String title;
  final VoidCallback onBack;
  final void Function(String) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: topInset + 4,
          left: 4,
          right: 4,
          bottom: 12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: _kNavy,
                onPressed: onBack,
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, color: _kNavy),
                onSelected: onMenuSelected,
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'manage',
                    child: Text(
                      AppLocalizations.of(ctx)!.rewardConfigMenuManageRewards,
                    ),
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

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kFieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kNavy : Colors.transparent,
              width: selected ? 3 : 0,
            ),
          ),
          child: Icon(
            icon,
            color: selected ? _kNavy : _kMutedLabel.withValues(alpha: 0.45),
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _RewardTypeSegmented extends StatelessWidget {
  const _RewardTypeSegmented({
    required this.perTrackLabel,
    required this.totalLabel,
    required this.perTrackEnabled,
    required this.isGlobal,
    required this.onChanged,
  });

  final String perTrackLabel;
  final String totalLabel;
  final bool perTrackEnabled;
  final bool isGlobal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Seg(
              label: perTrackLabel,
              selected: !isGlobal,
              enabled: perTrackEnabled,
              onTap: perTrackEnabled ? () => onChanged(false) : null,
            ),
          ),
          Expanded(
            child: _Seg(
              label: totalLabel,
              selected: isGlobal,
              enabled: true,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const baseMuted = _kMutedLabel;
    final labelColor = !enabled
        ? baseMuted.withValues(alpha: 0.35)
        : (selected ? Colors.white : baseMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageRewardsList extends StatefulWidget {
  const _ManageRewardsList({
    required this.load,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Future<List<RewardMilestone>> Function() load;
  final void Function(RewardMilestone) onEdit;
  final Future<void> Function(RewardMilestone) onDelete;
  final Future<void> Function(RewardMilestone) onToggle;

  @override
  State<_ManageRewardsList> createState() => _ManageRewardsListState();
}

class _ManageRewardsListState extends State<_ManageRewardsList> {
  late Future<List<RewardMilestone>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<RewardMilestone>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = [...?snap.data]
          ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));
        if (list.isEmpty) {
          return Center(
            child: Text(
              l10n.rewardConfigEmptyMilestones,
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final m = list[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                m.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${l10n.rewardConfigPointsThresholdLabel}: ${m.thresholdPoints}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: m.isEnabled,
                    onChanged: (_) async {
                      await widget.onToggle(m);
                      await _refresh();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => widget.onEdit(m),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => widget.onDelete(m),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
