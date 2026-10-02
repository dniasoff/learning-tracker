/// Who is looking at the sub-track rows and where their taps lead
/// (Story 2.9, DNI-500 T2/T6).
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

/// The viewer's role for sub-track affordances (AC-1, AC-3, AC-9).
enum SubTrackViewerRole {
  /// The learner in child mode: records, never edits ground.
  child,

  /// The owner (adult profile, or a child profile unlocked with the parent
  /// PIN): records and sees *Add ground* / *Manage*.
  parent,

  /// A tutor device: every sub-track write control is visible but disabled
  /// until tutor sub-track writes ship (DNI-509/DNI-510, UX-DR-158).
  tutor,
}

/// The current [SubTrackViewerRole].
///
/// A tutored session is always [SubTrackViewerRole.tutor]. Otherwise a
/// child-mode profile is the child unless the parent PIN was verified for
/// it this session. While the profile is still loading the least-privileged
/// role (child) applies, so no parent-only control flashes in.
final subTrackViewerRoleProvider = Provider.autoDispose<SubTrackViewerRole>((
  ref,
) {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
    return SubTrackViewerRole.tutor;
  }
  final profileAsync = ref.watch(selectedProfileProvider);
  if (!profileAsync.hasValue) return SubTrackViewerRole.child;
  final profile = profileAsync.requireValue;
  if (profile == null) return SubTrackViewerRole.child;
  if (profile.mode != ProfileMode.child) return SubTrackViewerRole.parent;
  final pinFor = ref.watch(parentPinAuthenticatedProfileIdProvider);
  return pinFor == profile.profileId
      ? SubTrackViewerRole.parent
      : SubTrackViewerRole.child;
});

/// A sub-track destination that a sibling story builds.
enum SubTrackDestination {
  /// The sub-track detail (DNI-497, Story 2.6; AC-7).
  detail,

  /// The ground picker (DNI-498, Story 2.7; AC-3, AC-4).
  groundPicker,

  /// The *Up to…* picker (DNI-501, Story 2.10).
  upTo,
}

/// Where the sub-track rows and cards navigate.
///
/// The destinations belong to sibling stories: detail (DNI-497, Story 2.6),
/// ground picker (DNI-498, Story 2.7) and the *Up to…* picker (DNI-501,
/// Story 2.10). Each of them wires its destination by replacing
/// [subTrackNavigatorProvider]'s value with a navigator whose [canOpen]
/// reports it. Until then the entry point is rendered disabled rather than
/// routed somewhere else: a row or card whose detail does not exist is not
/// tappable, and *Up to…* / *Add ground* are visible but disabled.
abstract interface class SubTrackNavigator {
  /// Whether [destination] exists. Callers render its entry point disabled
  /// (and never call the matching `open…` method) while this is false.
  bool canOpen(SubTrackDestination destination);

  /// Opens the sub-track detail (AC-7). Requires
  /// `canOpen(SubTrackDestination.detail)`.
  void openDetail(BuildContext context, SubTrackHomeItem item);

  /// Opens the ground picker for a parent (AC-3, AC-4). Requires
  /// `canOpen(SubTrackDestination.groundPicker)`.
  void openGroundPicker(BuildContext context, SubTrackHomeItem item);

  /// Opens the *Up to…* picker (Story 2.10). Requires
  /// `canOpen(SubTrackDestination.upTo)`.
  void openUpTo(BuildContext context, SubTrackHomeItem item);

  /// Opens the track-management hub (*Manage*, AC-8). Always available.
  void openHub(BuildContext context);
}

/// The production navigator until the sibling destinations land: only the
/// hub exists, so every other destination reports `canOpen == false` and
/// its entry point stays disabled (no tap is mis-routed to the hub).
final class HubOnlySubTrackNavigator implements SubTrackNavigator {
  /// Creates the navigator.
  const HubOnlySubTrackNavigator();

  @override
  bool canOpen(SubTrackDestination destination) => false;

  @override
  void openDetail(BuildContext context, SubTrackHomeItem item) =>
      throw UnsupportedError('Sub-track detail is not wired (DNI-497)');

  @override
  void openGroundPicker(BuildContext context, SubTrackHomeItem item) =>
      throw UnsupportedError('Ground picker is not wired (DNI-498)');

  @override
  void openUpTo(BuildContext context, SubTrackHomeItem item) =>
      throw UnsupportedError('Up to… picker is not wired (DNI-501)');

  @override
  void openHub(BuildContext context) =>
      context.router.push(TrackManagementHubRoute());
}

/// The active [SubTrackNavigator].
final subTrackNavigatorProvider = Provider<SubTrackNavigator>(
  (ref) => const HubOnlySubTrackNavigator(),
);
