// Overflow guard for the learning_screen.dart task-card badge Row.
//
// The offender: the badge Row at the top of the daily-task card — an optional
// fixed "OVERDUE" chip followed by a variable-length `stageLabel` chip. Inside
// the card's `Expanded` column the Row's width is bounded, so at large text on
// a narrow viewport the two chips ran past it → horizontal RenderFlex overflow.
// The fix wraps the stage chip in `Flexible` and ellipsises its label.
//
// (The fix ultimately switched the badge Row to a `Wrap` so the stage chip
// drops to a second line rather than overflowing — guarded below.)
//
// The card column + chips are private/provider-bound, so — matching
// `test/overflow/overflow_guard_test.dart` — we reproduce the exact post-fix
// shape (the Expanded column with the fixed OVERDUE chip + a Wrap of badges)
// and prove it survives the whole device/text-scale matrix.

@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/overflow_harness.dart';

/// Faithful copy of the fixed daily-task card badge Row + title.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.isOverdue, required this.stageLabel});

  final bool isOverdue;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(width: 44, height: 44, color: const Color(0xFFEFF0F4)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCDDE0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'OVERDUE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFC22840),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF0F4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          stageLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF6A7282),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Berachos, Perek 9, Mishnah 5 — a long task title here',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'Task card badge Row (overdue + long stage label) does not overflow across '
    'the matrix incl. small×2.0 and the narrow width corner',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _TaskCard(
          isOverdue: true,
          stageLabel: 'CHAZARA — SECOND REVIEW',
        ),
      );
    },
  );

  testWidgets(
    'Task card badge Row (not overdue, stage chip only) does not overflow',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () =>
            const _TaskCard(isOverdue: false, stageLabel: 'NEW LEARNING STAGE'),
      );
    },
  );
}
