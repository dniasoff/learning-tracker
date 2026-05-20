/// Formats [fraction] (0.0–1.0) as a percentage string.
///
/// When [decimals] is not provided the formatter uses adaptive precision:
///   - Whole numbers → no decimal places ("100%", "50%").
///   - Non-whole values → 1 decimal place ("32.5%", "7.1%").
///
/// Pass an explicit [decimals] value to override adaptive precision
/// (e.g. `decimals: 0` for always-integer display).
String formatFractionAsPercent(double fraction, {int? decimals}) {
  final percent = fraction * 100;
  return _formatPercent(percent, decimals: decimals);
}

/// Formats [percent] (0.0–100.0) as a percentage string.
///
/// See [formatFractionAsPercent] for adaptive-precision behaviour.
String formatPercentValue(double percent, {int? decimals}) {
  return _formatPercent(percent, decimals: decimals);
}

String _formatPercent(double percent, {int? decimals}) {
  if (decimals != null) {
    return '${percent.toStringAsFixed(decimals)}%';
  }
  // Adaptive precision: whole numbers get no decimal, others get 1 decimal.
  final rounded1 = double.parse(percent.toStringAsFixed(1));
  if (rounded1 == rounded1.truncate()) {
    return '${rounded1.toStringAsFixed(0)}%';
  }
  return '${rounded1.toStringAsFixed(1)}%';
}
