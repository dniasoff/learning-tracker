import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_grid.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Own profiles section of the profile picker.
//
// The "YOUR PROFILES" header (and the sibling "TALMID PROFILES" header
// rendered by TutoredChildrenSection) appear only when the current user has
// at least one active tutored grant — i.e. is a rebbe with ≥1 talmid.
// Otherwise the picker shows a single flat list with no headers.
//
// Within "YOUR PROFILES", child and adult profiles are co-mingled inside one
// grid — there is no separate "CHILD PROFILES" sub-section.
// ---------------------------------------------------------------------------

/// Own-profile section ("YOUR PROFILES") of the profile picker.
///
/// Shows a "YOUR PROFILES" header only when [showHeader] is true (i.e. when
/// the user has ≥1 active tutored grant). The grid always renders ALL owned
/// profiles — adults and children together — plus the "Add Profile" card.
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
                color: context.colors.brandInkMuted,
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
