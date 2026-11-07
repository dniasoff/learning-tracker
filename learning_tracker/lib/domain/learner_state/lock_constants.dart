/// AD-36 lock margins: the ONLY definition of the Shabbos / yom tov lock
/// offsets (PRD FR-23, deviation #6).
///
/// Legacy compatibility names. Shabbat locks now use parent-configured
/// candle-lighting and tzeis values directly, with no timing buffers.
library;

/// No buffer before candle-lighting.
const Duration lockStartBeforeCandleLighting = Duration.zero;

/// No buffer after tzeis.
const Duration lockEndAfterTzeis = Duration.zero;
