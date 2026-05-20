import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_grid.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// "My children" section: a section header followed by the owned-profile grid.
class MyChildrenSection extends StatelessWidget {
  const MyChildrenSection({
    super.key,
    required this.profiles,
    required this.isSelectingProfile,
    required this.onProfileTap,
    required this.onProfileLongPress,
    required this.onAddProfile,
  });

  final List<ProfileModel> profiles;
  final bool isSelectingProfile;
  final void Function(int profileId) onProfileTap;
  final void Function(ProfileModel profile, int profileCount)
  onProfileLongPress;
  final void Function(int profileCount) onAddProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── My children section header (W6.14) ──────────────────────────
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.profilePickerMyChildren,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ProfileGrid(
          profiles: profiles,
          isSelectingProfile: isSelectingProfile,
          onProfileTap: onProfileTap,
          onProfileLongPress: onProfileLongPress,
          onAddProfile: onAddProfile,
        ),
      ],
    );
  }
}
