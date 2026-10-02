/// The ongoing form's navigation entry (Story 2.5 / DNI-496). The form is
/// pushed from the Manage tracks sub-track group, which is itself shown
/// only in a parent session, so it has no deep-linkable route of its own.
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_screen.dart';

/// Opens the ongoing form for [curriculumId]: a new sub-track, or
/// [existing] for an edit. Resolves to the save outcome, or null when the
/// parent leaves without saving.
Future<OngoingSubTrackSaved?> openOngoingSubTrackForm(
  BuildContext context, {
  required String curriculumId,
  SubTrack? existing,
}) => Navigator.of(context).push<OngoingSubTrackSaved>(
  MaterialPageRoute(
    builder: (_) => OngoingSubTrackFormScreen(
      curriculumId: curriculumId,
      existing: existing,
    ),
  ),
);
