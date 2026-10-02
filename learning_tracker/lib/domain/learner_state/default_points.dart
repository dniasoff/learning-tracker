/// The AD-50 default stage ladder: the points of one earning event at
/// [stageOrder] when no `point_configs` override exists (Learn = 10,
/// Chazara 1 = 5, Chazara 2 = 3, else 1).
///
/// The single source of the ladder: `defaultPointsForStage` (data layer)
/// and the owner capture's offline fallback (DNI-469) both resolve here.
library;

/// The default points of one earning event at [stageOrder].
int defaultStagePoints(int stageOrder) => switch (stageOrder) {
  1 => 10,
  2 => 5,
  3 => 3,
  _ => 1,
};
