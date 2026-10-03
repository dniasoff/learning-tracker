/// Learn-tab slot for the catch-up cards, at the top of the tab (Story 3.2,
/// DNI-505; UX-DR-57).
///
/// One of the named Learn sections (catchUpCards, mainTasks, erevPlanned,
/// alsoLearning) introduced by DNI-500 so later stories plug a widget in
/// here without editing the screen body (merge-hotspot ruling). Zero size
/// with no pending card.
library;

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_card.dart';

/// The catch-up cards slot; zero size while no card is pending.
class CatchUpCardsSlot extends StatelessWidget {
  /// Creates the slot.
  const CatchUpCardsSlot({super.key});

  @override
  Widget build(BuildContext context) => const CatchUpCardsSection();
}
