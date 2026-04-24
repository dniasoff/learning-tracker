import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

@RoutePage()
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  bool _isSelectingProfile = false;

  @override
  Widget build(BuildContext context) {
    // Use future provider instead of stream provider to avoid the
    // InheritedElement '_dependents.isEmpty' assertion that fires when
    // a stream-triggered rebuild races with dialog/overlay dismissal.
    final profilesAsync = ref.watch(profileListProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: profilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
            data: (profiles) => _buildBody(context, profiles),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProfileModel> profiles) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Who is learning?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandBlueDeep,
                      letterSpacing: -0.8,
                      height: 1.03,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose a profile to continue your\njourney',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.brandInkMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.71,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                    itemCount: profiles.length + 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, index) {
                      if (index == profiles.length) {
                        return _AddProfileCard(
                          onTap: () => _showAddDialog(profiles.length),
                          isDisabled: profiles.length >= 10,
                        );
                      }
                      final profile = profiles[index];
                      return _ProfileCard(
                        profile: profile,
                        onTap: _isSelectingProfile
                            ? () {}
                            : () => unawaited(_selectProfile(profile.id)),
                        onLongPress: () =>
                            _showManageSheet(profile, profiles.length),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: _PickerBottomBar(),
          ),
        ),
      ],
    );
  }

  // ── Select Profile ─────────────────────────────────────────────────────────

  Future<void> _selectProfile(int profileId) async {
    if (_isSelectingProfile) return;
    _isSelectingProfile = true;

    try {
      ref.read(selectedProfileIdProvider.notifier).select(profileId);

      if (!mounted) return;
      await context.router.replaceAll([const AppShellRoute()]);
    } finally {
      // If navigation didn't happen (or failed), allow another tap attempt.
      if (mounted) {
        setState(() {
          _isSelectingProfile = false;
        });
      }
    }
  }

  // ── Add Profile ───────────────────────────────────────────────────────────

  Future<void> _showAddDialog(int profileCount) async {
    final profileDao = ref.read(userDatabaseProvider).profileDao;
    final repo = ref.read(profileRepositoryProvider);

    final ctrl = TextEditingController();
    var mode = 'adult';
    String? err;

    final result = await showDialog<({String n, String m})>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            try {
              final exists = await profileDao.profileExistsByName(1, n);
              set(
                () => err = exists
                    ? 'A profile with this name already exists'
                    : null,
              );
            } catch (_) {
              set(() => err = null);
            }
          }

          return AlertDialog(
            title: const Text('Add Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: err,
                    ),
                    onChanged: (_) => check(),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'adult', label: Text('Adult')),
                      ButtonSegment(value: 'child', label: Text('Child')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => set(() => mode = v.first),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isNotEmpty && err == null
                    ? () => Navigator.pop(ctx, (n: ctrl.text.trim(), m: mode))
                    : null,
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) {
      // Delay dispose so the dialog exit animation finishes using the controller.
      Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
      return;
    }
    try {
      final created = await repo.createProfile(
        accountId: 1,
        displayName: result.n,
        mode: result.m,
      );
      // Dispose after creation (dialog animation is done by now).
      ctrl.dispose();
      // Manually refresh the profile list after creation.
      if (mounted) ref.invalidate(profileListProvider);
      // Child profiles require a parent PIN so the parent can gate access
      // to parental controls. Prompt right after creation.
      if (created.mode == 'child' && mounted) {
        await showParentPinSetupDialog(
          context,
          ref,
          profileId: created.id,
          profileName: created.displayName,
        );
      }
    } on DuplicateProfileNameException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A profile named "${result.n}" already exists'),
          ),
        );
      }
    } on MaxProfilesExceededException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 profiles reached')),
        );
      }
    }
  }

  // ── Manage (Long-press) ───────────────────────────────────────────────────

  Future<void> _showManageSheet(ProfileModel profile, int profileCount) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              enabled: profileCount > 1,
              subtitle: profileCount <= 1
                  ? const Text('You must have at least one profile')
                  : null,
              onTap: profileCount > 1
                  ? () => Navigator.pop(ctx, 'delete')
                  : null,
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _showRenameDialog(profile);
    } else if (action == 'delete' && mounted) {
      await _showDeleteDialog(profile);
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(ProfileModel profile) async {
    final profileDao = ref.read(userDatabaseProvider).profileDao;
    final repo = ref.read(profileRepositoryProvider);

    final ctrl = TextEditingController(text: profile.displayName);
    String? err;
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            try {
              final exists = await profileDao.profileExistsByName(
                1,
                n,
                excludeId: profile.id,
              );
              set(
                () => err = exists
                    ? 'A profile with this name already exists'
                    : null,
              );
            } catch (_) {
              set(() => err = null);
            }
          }

          return AlertDialog(
            title: const Text('Rename Profile'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: const OutlineInputBorder(),
                errorText: err,
              ),
              onChanged: (_) => check(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isNotEmpty && err == null
                    ? () => Navigator.pop(ctx, ctrl.text.trim())
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (name == null || name.isEmpty || !mounted) {
      Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
      return;
    }
    try {
      await repo.updateProfile(id: profile.id, displayName: name);
      ctrl.dispose();
      if (mounted) ref.invalidate(profileListProvider);
    } on DuplicateProfileNameException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A profile named "$name" already exists')),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _showDeleteDialog(ProfileModel profile) async {
    final repo = ref.read(profileRepositoryProvider);

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Permanently delete "${profile.displayName}" and ALL associated '
          'learning data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    try {
      await repo.deleteProfile(profile.id);
      final sel = ref.read(selectedProfileIdProvider) ?? -1;
      if (sel == profile.id) {
        ref.read(selectedProfileIdProvider.notifier).clear();
      }
      ref.invalidate(profileListProvider);
    } on LastProfileException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete your only profile')),
        );
      }
    }
  }
}

// ── Stateless card widgets ──────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ProfileCard({
    required this.profile,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChild = profile.mode == 'child';
    const modeColor = AppTheme.brandBlue;
    final trimmedName = profile.displayName.trim();
    final firstLetter = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.brandOutline.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandInk.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isChild ? 'CHILD MODE' : 'ADULT MODE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.brandInkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF2F5FC), Color(0xFFE6ECF8)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.brandBlue.withValues(alpha: 0.14),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          firstLetter,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppTheme.brandBlueDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (isChild)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF96B82),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.brandCreamCard,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: AppTheme.brandInk,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to\ncontinue',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDisabled;
  const _AddProfileCard({required this.onTap, this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: isDisabled ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30),
          ),
          child: CustomPaint(
            painter: _DashedRoundedRectPainter(
              color: isDisabled
                  ? AppTheme.brandOutline.withValues(alpha: 0.6)
                  : AppTheme.brandOutline,
              strokeWidth: 1.6,
              dashLength: 6,
              gapLength: 5,
              borderRadius: 30,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    painter: _DashedCirclePainter(
                      color: isDisabled
                          ? AppTheme.brandOutline.withValues(alpha: 0.6)
                          : AppTheme.brandInkMuted,
                    ),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 44,
                          color: isDisabled
                              ? AppTheme.brandInkSoft
                              : AppTheme.brandBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isDisabled ? 'Max Profiles' : 'Add\nProfile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brandInk,
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDisabled ? 'Maximum reached' : 'Create new\nlearner',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerBottomBar extends StatelessWidget {
  const _PickerBottomBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.brandBlueSoft.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.supervised_user_circle_rounded,
                    color: AppTheme.brandBlueDeep,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Profiles',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandBlueDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.router.push(const SettingsRoute()),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_rounded,
                      color: AppTheme.brandInkMuted.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Settings',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint, dashLength, gapLength);
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength ||
        borderRadius != oldDelegate.borderRadius;
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2 - 2,
        ),
      );
    _drawDashedPath(canvas, path, paint, 6, 5);
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

void _drawDashedPath(
  Canvas canvas,
  Path source,
  Paint paint,
  double dashLength,
  double gapLength,
) {
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = distance + dashLength;
      canvas.drawPath(
        metric.extractPath(distance, next.clamp(0, metric.length)),
        paint,
      );
      distance = next + gapLength;
    }
  }
}
