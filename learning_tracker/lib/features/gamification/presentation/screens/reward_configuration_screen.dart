import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/avatar_picker_row.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/manage_rewards_list.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_config_header.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const Color _kNavy = AppTheme.brandBlueDeep;
const Color _kOrange = AppTheme.brandWarning;
const Color _kPageBg = AppColors.surfaceF4b;
const Color _kPreviewBg = Color(0xFFEEF3FA);
const Color _kMutedLabel = AppTheme.brandInkMuted;

@RoutePage()
class RewardConfigurationScreen extends ConsumerStatefulWidget {
  const RewardConfigurationScreen({super.key});

  @override
  ConsumerState<RewardConfigurationScreen> createState() =>
      _RewardConfigurationScreenState();
}

class _RewardConfigurationScreenState
    extends ConsumerState<RewardConfigurationScreen> {
  final _nameController = TextEditingController();
  final _pointsController = TextEditingController();

  // Track whether the controllers were last updated by the notifier to avoid
  // infinite update loops.
  String _lastSyncedName = '';
  String _lastSyncedPoints = '';

  // Incremented on save/delete to force the inline rewards section to re-fetch.
  int _rewardsVersion = 0;

  void _refreshRewards() => setState(() => _rewardsVersion++);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _pointsController.addListener(_onPointsChanged);
    // Defer to post-frame: bootstrap() synchronously assigns controller state,
    // and calling it during initState (inside the build cycle) trips Riverpod
    // 3.x "Tried to modify a provider while the widget tree was building"
    // (R-GA-boot).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(rewardConfigControllerProvider.notifier).bootstrap());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final v = _nameController.text;
    if (v != _lastSyncedName) {
      ref.read(rewardConfigControllerProvider.notifier).setName(v);
    }
  }

  void _onPointsChanged() {
    final v = _pointsController.text;
    if (v != _lastSyncedPoints) {
      ref.read(rewardConfigControllerProvider.notifier).setPointsText(v);
    }
  }

  /// Syncs the text controllers to the notifier state without re-triggering
  /// listener callbacks (avoids infinite loops when applyMilestoneToForm
  /// or clearForm updates notifier state externally).
  void _syncControllersFromState(RewardForm form) {
    if (form.name != _nameController.text) {
      _lastSyncedName = form.name;
      _nameController.text = form.name;
    }
    if (form.pointsText != _pointsController.text) {
      _lastSyncedPoints = form.pointsText;
      _pointsController.text = form.pointsText;
    }
  }

  Future<void> _openManageRewardsSheet(AppLocalizations l10n) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final notifier = ref.read(rewardConfigControllerProvider.notifier);
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
                  child: ManageRewardsList(
                    load: notifier.milestonesForCurrentLadder,
                    onEdit: (m) {
                      Navigator.pop(ctx);
                      notifier.applyMilestoneToForm(m);
                    },
                    onDelete: (m) async {
                      Navigator.pop(ctx);
                      await _confirmDelete(m, l10n);
                    },
                    onToggle: (m) async {
                      try {
                        await notifier.toggleEnabled(m);
                      } on TutorWriteException catch (e) {
                        if (!mounted) return;
                        if (e.code == 'permission-denied') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                )!.tutorPermissionDenied,
                              ),
                            ),
                          );
                        }
                      }
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

  Future<void> _confirmDelete(
    RewardMilestone milestone,
    AppLocalizations l10n,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteReward),
        content: Text(l10n.deleteRewardConfirm(milestone.title)),
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
    try {
      await ref
          .read(rewardConfigControllerProvider.notifier)
          .deleteMilestone(milestone);
      _refreshRewards();
    } on TutorWriteException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tutorPermissionDenied),
          ),
        );
      }
    }
  }

  Future<void> _saveReward(AppLocalizations l10n) async {
    final RewardSaveResult result;
    try {
      result = await ref
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
    } on TutorWriteException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.tutorPermissionDenied)));
      }
      return;
    }
    if (!mounted) return;

    switch (result) {
      case RewardSaveInvalidInput():
        // Empty title / invalid points — no-op; button should be disabled.
        break;
      case RewardSaveNoTrack():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rewardConfigNoActiveTracks)),
        );
      case RewardSaveDuplicateThreshold():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rewardConfigDuplicateThreshold)),
        );
      case RewardSaveDuplicateName():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.rewardConfigDuplicateName)));
      case RewardSaved(:final title, :final wasEditing):
        _refreshRewards();
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final form = ref.watch(rewardConfigControllerProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final canEdit = tutorPerms == null || tutorPerms.canEditRewards;

    // Keep text controllers in sync with notifier state (e.g. after clear/apply).
    _syncControllersFromState(form);

    if (form.loading) {
      return const Scaffold(
        backgroundColor: _kPageBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (form.error != null) {
      return Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(title: Text(l10n.rewardConfigurationTitle)),
        body: Center(child: Text(form.error!)),
      );
    }

    final notifier = ref.read(rewardConfigControllerProvider.notifier);
    final previewTitle = form.name.trim().isEmpty
        ? l10n.rewardConfigNamePlaceholder
        : form.name.trim();

    return Scaffold(
      backgroundColor: _kPageBg,
      body: Column(
        children: [
          RewardConfigHeader(
            topInset: topInset,
            title: l10n.rewardConfigScreenContextLabel,
            onBack: () => context.maybePop(),
            onMenuSelected: (value) {
              if (value == 'manage') {
                unawaited(_openManageRewardsSheet(l10n));
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fix #1: Show existing rewards inline so parents can see
                  // them without discovering the overflow menu.
                  _InlineRewardsSection(
                    key: ValueKey(_rewardsVersion),
                    load: notifier.milestonesForCurrentLadder,
                    l10n: l10n,
                    onEdit: notifier.applyMilestoneToForm,
                    onDelete: (m) => _confirmDelete(m, l10n),
                    onToggle: (m) async {
                      try {
                        await notifier.toggleEnabled(m);
                      } on TutorWriteException catch (e) {
                        if (!context.mounted) return;
                        if (e.code == 'permission-denied') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.tutorPermissionDenied)),
                          );
                        }
                      }
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
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
                            // GA-7: Switch heading to edit-mode copy when editing.
                            form.isEditing
                                ? l10n.rewardConfigEditReward
                                : l10n.rewardConfigConfigureNewTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            // GA-7: Subtitle also switches to edit-mode copy.
                            form.isEditing
                                ? l10n.rewardConfigEditModeSubtitle
                                : l10n.rewardConfigConfigureNewSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: _kMutedLabel, height: 1.35),
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
                          AvatarPickerRow(
                            selectedIndex: form.iconIndex,
                            onSelect: notifier.setIconIndex,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            l10n.rewardConfigRewardNameLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _kMutedLabel,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: const [
                              TrimLeadingSpaceFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: l10n.rewardConfigNamePlaceholder,
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
                          // R4o-H2 / DEC-32: the Per-track vs Total reward-type
                          // split was removed — every reward is a single global
                          // priced spend-item against the one debitable balance, so
                          // the type segmented control and per-track dropdown are
                          // gone.
                          const SizedBox(height: 18),
                          Text(
                            l10n.rewardConfigPointsThresholdLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _kMutedLabel,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              hintText: l10n.rewardConfigPointsPlaceholder,
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
                          _RewardPreview(
                            iconIndex: form.iconIndex,
                            previewTitle: previewTitle,
                            isPlaceholder: form.name.trim().isEmpty,
                            previewPoints: form.previewPoints,
                            l10n: l10n,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: notifier.clearForm,
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
                              // GA-7: Disable Save when form is not valid (name
                              // empty / cost invalid) to prevent the silent no-op.
                              // Also disable for tutors without edit permission.
                              onPressed: canEdit
                                  ? (form.canSave
                                        ? () => unawaited(_saveReward(l10n))
                                        : null)
                                  : () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.tutorPermissionDenied,
                                            ),
                                          ),
                                        ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _kNavy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: Text(
                                // GA-7: Use "Update Reward" button label in edit mode.
                                form.isEditing
                                    ? l10n.rewardConfigUpdateRewardButton
                                    : l10n.rewardConfigSaveRewardButton,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline preview card showing how the reward will appear to the learner.
class _RewardPreview extends StatelessWidget {
  const _RewardPreview({
    required this.iconIndex,
    required this.previewTitle,
    required this.isPlaceholder,
    required this.previewPoints,
    required this.l10n,
  });

  final int iconIndex;
  final String previewTitle;
  final bool isPlaceholder;
  final int previewPoints;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  RewardMilestoneIcons.iconForIndex(iconIndex),
                  color: _kNavy,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewTitle,
                      style: isPlaceholder
                          ? const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.normal,
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                            )
                          : const TextStyle(
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
                          l10n.rewardConfigPointsPreview(previewPoints),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline rewards section (Fix #1)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the existing configured rewards inline above the form so parents see
/// them without having to discover the overflow menu.
///
/// Keyed externally with [_rewardsVersion] so it re-fetches after every
/// save or delete operation.
class _InlineRewardsSection extends StatefulWidget {
  const _InlineRewardsSection({
    super.key,
    required this.load,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Future<List<RewardMilestone>> Function() load;
  final AppLocalizations l10n;
  final void Function(RewardMilestone) onEdit;
  final Future<void> Function(RewardMilestone) onDelete;
  final Future<void> Function(RewardMilestone) onToggle;

  @override
  State<_InlineRewardsSection> createState() => _InlineRewardsSectionState();
}

class _InlineRewardsSectionState extends State<_InlineRewardsSection> {
  late Future<List<RewardMilestone>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RewardMilestone>>(
      future: _future,
      builder: (_, snap) {
        final list = snap.data;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        final listHeight = (list.length * 72.0).clamp(72.0, 260.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
              child: Text(
                widget.l10n.rewardConfigMenuManageRewards,
                style: const TextStyle(
                  color: _kNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            SizedBox(
              height: listHeight,
              child: ManageRewardsList(
                load: widget.load,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                onToggle: widget.onToggle,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
