import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_grid.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Segmented profile-picker sections (conditional headers — W6.14 refinement).
//
// Logic summary:
//   ownChild == 0 && tutored == 0  →  ungrouped (no headers)
//   ownChild > 0  || tutored > 0   →  "YOUR PROFILES" header shown
//   ownChild > 0                   →  "CHILD PROFILES" sub-section also shown
//   tutored > 0                    →  "TALMID PROFILES" shown by
//                                     TutoredChildrenSection (unchanged)
// ---------------------------------------------------------------------------

/// Own-profile section ("YOUR PROFILES") of the profile picker.
///
/// Shows a "YOUR PROFILES" header only when [showHeader] is true (i.e. when
/// child or tutored profiles also exist). The grid always renders ALL owned
/// profiles — adults and children together — plus the "Add Profile" card.
///
/// When segmentation is active ([showHeader] == true and [ownChildCount] > 0),
/// the screen also inserts a [ChildProfilesSection] below this widget to label
/// the child-profile subset.
class OwnProfilesSection extends StatelessWidget {
  const OwnProfilesSection({
    super.key,
    required this.profiles,
    required this.showHeader,
    required this.isSelectingProfile,
    required this.onProfileTap,
    required this.onProfileLongPress,
    required this.onAddProfile,
  });

  /// All owned profiles (adults + children).
  final List<ProfileModel> profiles;

  /// Whether to render the "YOUR PROFILES" section header.
  final bool showHeader;

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
        if (showHeader) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.profilePickerYourProfiles,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.brandInkMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
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

/// "CHILD PROFILES" sub-section header shown after the own-profiles grid when
/// child profiles exist and segmentation is active.
///
/// The child profile cards are rendered inside the single [ProfileGrid] in
/// [OwnProfilesSection] — this widget only adds the visual label+divider.
class ChildProfilesSection extends StatelessWidget {
  const ChildProfilesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.profilePickerChildProfiles,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
