import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_card.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_card.dart';

/// A two-column grid of owned profiles plus the "add profile" card.
///
/// Exposes [onProfileTap] (disabled while a selection is in-flight via
/// [isSelectingProfile]) and [onAddProfile] callbacks so the parent screen
/// owns all navigation logic.
class ProfileGrid extends ConsumerWidget {
  const ProfileGrid({
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
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.67,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: profiles.length + 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, index) {
        if (index == profiles.length) {
          return AddProfileCard(
            onTap: () => onAddProfile(profiles.length),
            isDisabled: profiles.length >= 10,
          );
        }
        final profile = profiles[index];
        return ProfileCard(
          profile: profile,
          onTap: isSelectingProfile
              ? () {}
              : () => unawaited(Future(() => onProfileTap(profile.id))),
          onLongPress: () => onProfileLongPress(profile, profiles.length),
        );
      },
    );
  }
}
