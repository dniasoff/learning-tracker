// Overflow guard for the Progress surfaces' overflow-prone Rows.
//
// Two production Rows were the offenders:
//
//  1. recent_activity_screen.dart `_AllTimeSummaryCard` — a `spaceAround` Row
//     of up to three stat tiles: an `_AllTimeStatPhrase` (the ICU-plural
//     active-days phrase, e.g. "1 Active day" / "128 Active days") followed
//     by up to two `_AllTimeStat` (number + word-label) columns. On a narrow
//     viewport at large text the unconstrained tiles pushed the Row wider
//     than the card → "RenderFlex overflowed horizontally". The fix wraps
//     each tile in `Expanded` and ellipsises/clamps its text.
//
//  2. siyumim_timeline_view.dart milestone-card `subtitle: Row` — a curriculum
//     label + " · {date}" Text. At large text the two ran past the card width.
//     The fix wraps both in `Flexible` with `maxLines: 1` + ellipsis.
//
// These are private, provider-heavy widgets, so — following the pattern in
// `test/overflow/overflow_guard_test.dart` — we reproduce the *exact* post-fix
// layout shape here and prove it survives the whole device/text-scale matrix
// (incl. small×2.0 and the narrow×2.0 width corner), in BOTH English and
// Hebrew (the app is RTL-first, and Hebrew ICU-plural / curriculum-label
// fixtures run meaningfully longer than their English counterparts).
//
// KEEP THESE COPIES IN SYNC WITH PRODUCTION.
// `_AllTimeStat`, `_AllTimeStatPhrase`, `_AllTimeSummaryRow` (mirroring
// `_AllTimeSummaryCard`'s stat Row) and `_SiyumSubtitleRow` are hand-copies of
// the private widgets in `recent_activity_screen.dart` /
// `siyumim_timeline_view.dart`. If those production classes change shape
// (widget type, maxLines, text style, child order), this file's copies must
// change to match — otherwise this guard stops proving anything about
// production and a real overflow regression (e.g. in `_AllTimeStatPhrase`)
// would ship with this suite still green.

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

/// Faithful copy of the fixed `_AllTimeStatPhrase`
/// (recent_activity_screen.dart): a single centred `Text` that fuses the
/// value + label into one localized ICU phrase (the singular/plural
/// active-days fix). Unlike `_AllTimeStat` there is no separate big-number
/// row — the phrase alone carries everything, so it needs its own
/// `maxLines: 2` clamp to survive long Hebrew plural forms at large text.
class _AllTimeStatPhrase extends StatelessWidget {
  const _AllTimeStatPhrase({required this.phrase});

  final String phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        phrase,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1A1F2F),
        ),
      ),
    );
  }
}

/// Faithful copy of the fixed `_AllTimeSummaryCard` stat Row — the
/// `_AllTimeStatPhrase` active-days tile followed by up to two `_AllTimeStat`
/// tiles, in a `spaceAround` Row each wrapped in `Expanded` so they share the
/// width. Content is parameterised (rather than hard-coded) so callers can
/// exercise both the deliberately-wordy English fixtures and real long
/// Hebrew ICU-plural / domain-term content through the same shape.
class _AllTimeSummaryRow extends StatelessWidget {
  const _AllTimeSummaryRow({
    required this.showChazara,
    required this.activeDaysPhrase,
    required this.limudLabel,
    this.chazaraLabel,
  }) : assert(
         !showChazara || chazaraLabel != null,
         'chazaraLabel is required when showChazara is true',
       );

  final bool showChazara;

  /// Stands in for the production ICU-plural phrase rendered by
  /// `l10n.recentActivityActiveDaysCount(activeDaysCount)`.
  final String activeDaysPhrase;
  final String limudLabel;
  final String? chazaraLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: _AllTimeStatPhrase(phrase: activeDaysPhrase)),
            // A deliberately wordy label to stress the cell at large text.
            Expanded(
              child: _AllTimeStat(value: '1,024', label: limudLabel),
            ),
            if (showChazara)
              Expanded(
                child: _AllTimeStat(value: '512', label: chazaraLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Faithful copy of the fixed siyumim milestone-card `subtitle: Row`.
/// Content is parameterised so both English and Hebrew fixtures share the
/// exact same shape.
class _SiyumSubtitleRow extends StatelessWidget {
  const _SiyumSubtitleRow({
    required this.title,
    required this.curriculumLabel,
    required this.dateLabel,
  });

  final String title;
  final String curriculumLabel;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: Text(title),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                curriculumLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
            Flexible(
              child: Text(
                dateLabel,
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
        () => const _AllTimeSummaryRow(
          showChazara: false,
          activeDaysPhrase: '128 Active days',
          limudLabel: 'Mishnayos learned',
        ),
      );
    },
  );

  testWidgets(
    'All-time summary stat Row (3 stats incl. chazara) does not overflow, '
    'including small×2.0 and the narrow 280px width corner',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _AllTimeSummaryRow(
          showChazara: true,
          activeDaysPhrase: '128 Active days',
          limudLabel: 'Mishnayos learned',
          chazaraLabel: 'Chazaros completed',
        ),
      );
    },
  );

  testWidgets(
    'All-time summary stat Row (3 stats, Hebrew locale) does not overflow '
    'with a long ICU-plural active-days phrase and real Hebrew curriculum '
    'content — exercises _AllTimeStatPhrase, which the English-only matrix '
    'above cannot reach',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _AllTimeSummaryRow(
          showChazara: true,
          // Real ICU "other"-form text from `recentActivityActiveDaysCount`
          // (app_he.arb: "{count, plural, ... other{{count} ימים פעילים}}"),
          // at a 4-digit count to stress worst-case width.
          activeDaysPhrase: '1,024 ימים פעילים',
          // Real `allTimeTermDoneHebrew` pattern ("{term} שנלמד") with the
          // longest real curriculum display name
          // (CurriculumId.yerushalmi.displayNameHe) standing in for the term,
          // matching this file's existing "deliberately wordy" convention.
          limudLabel: 'תלמוד ירושלמי שנלמד',
          chazaraLabel: 'חזרות שנלמד',
        ),
        locale: const Locale('he'),
      );
    },
  );

  testWidgets(
    'Siyum milestone subtitle Row (curriculum · date) does not overflow across '
    'the matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _SiyumSubtitleRow(
          title: 'Siyum Masechta Berachos and the whole long name',
          curriculumLabel: 'Mishnayos with a long curriculum name',
          dateLabel: ' · 11 May 2026',
        ),
      );
    },
  );

  testWidgets(
    'Siyum milestone subtitle Row (Hebrew locale) does not overflow with a '
    'real long Hebrew curriculum label',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _SiyumSubtitleRow(
          title: 'סיום מסכת ברכות והשם הארוך כולו',
          // CurriculumId.yerushalmi.displayNameHe — the longest real
          // curriculum label that ships in this app.
          curriculumLabel: 'תלמוד ירושלמי',
          dateLabel: ' · 11 במאי 2026',
        ),
        locale: const Locale('he'),
      );
    },
  );
}
