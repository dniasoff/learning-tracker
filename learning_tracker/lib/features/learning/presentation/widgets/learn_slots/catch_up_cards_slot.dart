/// Learn-tab slot for the catch-up cards, above today's tasks.
///
/// One of the named Learn sections (catchUpCards, mainTasks, erevPlanned,
/// alsoLearning) introduced by DNI-500 so later stories plug a widget in
/// here without editing the screen body (merge-hotspot ruling). Empty until
/// DNI-505 (Story 5.x catch-up cards) fills it.
library;

import 'package:flutter/widgets.dart';

/// The catch-up cards slot; zero size while empty.
class CatchUpCardsSlot extends StatelessWidget {
  /// Creates the slot.
  const CatchUpCardsSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
