/// Learn-tab slot for the erev planned-day sections, between today's tasks
/// and "Also learning" (DNI-504 AC-1 order).
///
/// One of the named Learn sections introduced by DNI-500 so later stories
/// plug a widget in here without editing the screen body (merge-hotspot
/// ruling). Empty until DNI-504 fills it.
library;

import 'package:flutter/widgets.dart';

/// The erev planned slot; zero size while empty.
class ErevPlannedSlot extends StatelessWidget {
  /// Creates the slot.
  const ErevPlannedSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
