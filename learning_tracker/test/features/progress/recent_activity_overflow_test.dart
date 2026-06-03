// Overflow guard for the Progress surfaces' overflow-prone Rows.
//
// Two production Rows were the offenders:
//
//  1. recent_activity_screen.dart `_AllTimeSummaryCard` — a `spaceAround` Row
//     of up to three `_AllTimeStat` stat columns. On a narrow viewport at large
//     text the unconstrained stat columns (number + word-label) pushed the Row
//     wider than the card → "RenderFlex overflowed horizontally". The fix wraps
//     each stat in `Expanded` and ellipsises the value + label.
//
//  2. siyumim_timeline_view.dart milestone-card `subtitle: Row` — a curriculum
//     label + " · {date}" Text. At large text the two ran past the card width.
//     The fix wraps both in `Flexible` with `maxLines: 1` + ellipsis.
//
// These are private, provider-heavy widgets, so — following the pattern in
// `test/overflow/overflow_guard_test.dart` — we reproduce the *exact* post-fix
// layout shape here and prove it survives the whole device/text-scale matrix
// (incl. small×2.0 and the narrow×2.0 width corner).

@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/overflow_harness.dart';

/// Faithful copy of the fixed `_AllTimeStat` (recent_activity_screen.dart):
/// a centred number over a (now ellipsised) word-label.
class _AllTimeStat extends StatelessWidget {
  const _AllTimeStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1F2F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFF778099),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Faithful copy of the fixed `_AllTimeSummaryCard` stat Row — three stats in a
/// `spaceAround` Row, each wrapped in `Expanded` so they share the width.
class _AllTimeSummaryRow extends StatelessWidget {
  const _AllTimeSummaryRow({required this.showChazara});

  final bool showChazara;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Expanded(
              child: _AllTimeStat(value: '128', label: 'Active days'),
            ),
            // A deliberately wordy label to stress the cell at large text.
            const Expanded(
              child: _AllTimeStat(value: '1,024', label: 'Mishnayos learned'),
            ),
            if (showChazara)
              const Expanded(
                child: _AllTimeStat(value: '512', label: 'Chazaros completed'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Faithful copy of the fixed siyumim milestone-card `subtitle: Row`.
class _SiyumSubtitleRow extends StatelessWidget {
  const _SiyumSubtitleRow();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: const Text('Siyum Masechta Berachos and the whole long name'),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                'Mishnayos with a long curriculum name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
            Flexible(
              child: Text(
                ' · 11 May 2026',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'All-time summary stat Row (2 stats) does not overflow across the matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _AllTimeSummaryRow(showChazara: false),
      );
    },
  );

  testWidgets(
    'All-time summary stat Row (3 stats incl. chazara) does not overflow, '
    'including small×2.0 and the narrow 280px width corner',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _AllTimeSummaryRow(showChazara: true),
      );
    },
  );

  testWidgets(
    'Siyum milestone subtitle Row (curriculum · date) does not overflow across '
    'the matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _SiyumSubtitleRow(),
      );
    },
  );
}
