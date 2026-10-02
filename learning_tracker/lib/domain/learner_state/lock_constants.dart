/// AD-36 lock margins: the ONLY definition of the Shabbos / yom tov lock
/// offsets (PRD FR-23, deviation #6).
///
/// The lock opens [lockStartBeforeCandleLighting] before candle-lighting and
/// closes [lockEndAfterTzeis] after tzeis. Changing either value is a new
/// AD, never an in-place edit; no other file may define a lock offset.
library;

/// The lock opens this long before candle-lighting.
const Duration lockStartBeforeCandleLighting = Duration(minutes: 10);

/// The lock closes this long after tzeis.
const Duration lockEndAfterTzeis = Duration(minutes: 10);
