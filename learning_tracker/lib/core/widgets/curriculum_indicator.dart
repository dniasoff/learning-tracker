import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// CurriculumIndicator displays a colored indicator for a curriculum.
///
/// Each of the 5 curricula has a distinct color:
/// - Mishna: Blue
/// - Bavli: Purple
/// - Yerushalmi: Green
/// - Mishna Berurah: Orange
/// - Chumash: Red
class CurriculumIndicator extends StatelessWidget {
  /// Curriculum ID (e.g., 'mishna', 'bavli', etc.)
  final String curriculumId;

  /// Size of the indicator
  final double size;

  /// Optional curriculum label to display
  final String? label;

  /// Shape of the indicator
  final CurriculumIndicatorShape shape;

  const CurriculumIndicator({
    super.key,
    required this.curriculumId,
    this.size = 24.0,
    this.label,
    this.shape = CurriculumIndicatorShape.circle,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCurriculumColor(curriculumId);

    Widget indicator;
    switch (shape) {
      case CurriculumIndicatorShape.circle:
        indicator = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
        break;
      case CurriculumIndicatorShape.square:
        indicator = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
        break;
      case CurriculumIndicatorShape.bar:
        indicator = Container(
          width: size * 3,
          height: size / 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size / 6),
          ),
        );
        break;
    }

    if (label == null) {
      return indicator;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(width: 8),
        Text(
          label!,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Shape options for CurriculumIndicator
enum CurriculumIndicatorShape {
  /// Circular indicator
  circle,

  /// Square indicator with rounded corners
  square,

  /// Horizontal bar indicator
  bar,
}
