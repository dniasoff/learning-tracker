import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';

class ActiveTrackFocusPill extends StatelessWidget {
  const ActiveTrackFocusPill({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kActiveTrackFocusPillBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: kActiveTrackPrimaryBlue,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            // The full breadcrumb chain can be 4-5 segments; wrap freely
            // and cap at 3 lines so it never overflows the pill height.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.brandInk,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
