/// Learn-tab slot for "Also learning · {n} sub-tracks", directly below
/// today's main-track tasks (Story 2.9, DNI-500 T4).
///
/// Zero size when the section is absent, so the main-track list above it
/// renders exactly as before (AC-1); its loading and error states stay
/// inside the section and never gate today's tasks (AC-6).
library;

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

/// The also-learning slot.
class AlsoLearningSlot extends StatelessWidget {
  /// Creates the slot.
  const AlsoLearningSlot({super.key});

  /// Gap above the section when it renders (DESIGN.md `spacing.5`).
  static const double topSpacing = 24;

  @override
  Widget build(BuildContext context) =>
      const AlsoLearningSection(topSpacing: topSpacing);
}
