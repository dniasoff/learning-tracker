String formatFractionAsPercent(double fraction, {int decimals = 2}) {
  final percent = fraction * 100;
  return '${percent.toStringAsFixed(decimals)}%';
}

String formatPercentValue(double percent, {int decimals = 2}) {
  return '${percent.toStringAsFixed(decimals)}%';
}
