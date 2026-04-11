import 'package:learning_tracker/core/database/user/user_database.dart';

/// Pure reducer: sum every xp_event for a profile to get total XP.
int reduceXpEvents(Iterable<XpEvent> events) {
  var total = 0;
  for (final e in events) {
    total += e.xpDelta;
  }
  return total;
}
