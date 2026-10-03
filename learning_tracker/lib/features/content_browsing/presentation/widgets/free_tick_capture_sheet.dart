/// The confirm sheet of a Browse free tick (Story 1.11, DNI-473; UX-DR-20,
/// UX-DR-74): asks the source ONCE for the whole batch (Home by default, any
/// other active source, or Before tracking), shows an editable date that
/// defaults to today, and records with one "Record {count}" button.
///
/// Presentation only: it returns the learner's [FreeTickChoice]; the screen
/// issues the single capture.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// An extra source the learner may pick (an active sub-track), by its
/// source id (the sub-track ULID) and display [label].
final class FreeTickSourceOption {
  /// Creates the option.
  const FreeTickSourceOption({required this.id, required this.label});

  /// The `source` written on the events.
  final String id;

  /// The name shown.
  final String label;
}

/// What the learner confirmed.
final class FreeTickChoice {
  /// Creates the choice.
  const FreeTickChoice({
    required this.source,
    required this.dateState,
    this.learnedOn,
    this.taps = 2,
  });

  /// `main` or a sub-track ULID.
  final String source;

  /// [DateState.dated], or [DateState.beforeTracking] (no date).
  final DateState dateState;

  /// The edited civil date (`YYYY-MM-DD`); null keeps "today" (the command
  /// resolves it in the learner's time zone) and for Before tracking.
  final String? learnedOn;

  /// Taps from the initiating gesture through the confirmation button.
  final int taps;

  @override
  bool operator ==(Object other) =>
      other is FreeTickChoice &&
      other.source == source &&
      other.dateState == dateState &&
      other.learnedOn == learnedOn &&
      other.taps == taps;

  @override
  int get hashCode => Object.hash(source, dateState, learnedOn, taps);

  @override
  String toString() => 'FreeTickChoice($source, ${dateState.name}, $learnedOn)';
}

/// The radio value of Before tracking (never a source id).
const _beforeTracking = '__before_tracking__';

String _civil(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// Shows the sheet for a batch of [count] leaves titled [title]; null when
/// dismissed (nothing is written).
Future<FreeTickChoice?> showFreeTickCaptureSheet(
  BuildContext context, {
  required String title,
  required int count,
  required DateTime today,
  List<FreeTickSourceOption> extraSources = const [],
}) => showModalBottomSheet<FreeTickChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => FreeTickCaptureSheet(
    title: title,
    count: count,
    today: today,
    extraSources: extraSources,
  ),
);

/// The sheet body; pops a [FreeTickChoice] on Record.
class FreeTickCaptureSheet extends StatefulWidget {
  /// Creates the sheet.
  const FreeTickCaptureSheet({
    super.key,
    required this.title,
    required this.count,
    required this.today,
    this.extraSources = const [],
  });

  /// What is being ticked (a node name, or "Tick up to here").
  final String title;

  /// How many leaves the batch records.
  final int count;

  /// The local date of today (the default date).
  final DateTime today;

  /// Active sources besides Home and Before tracking.
  final List<FreeTickSourceOption> extraSources;

  @override
  State<FreeTickCaptureSheet> createState() => _FreeTickCaptureSheetState();
}

class _FreeTickCaptureSheetState extends State<FreeTickCaptureSheet> {
  String _source = LearningEvent.sourceMain;
  late DateTime _date = DateUtils.dateOnly(widget.today);
  int _taps = 1; // the tap/long-press that opened the sheet

  bool get _beforeTrackingChosen => _source == _beforeTracking;

  Future<void> _pickDate() async {
    _taps++;
    final today = DateUtils.dateOnly(widget.today);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked != null && mounted) {
      _taps++;
      setState(() => _date = picked);
    }
  }

  void _record() {
    _taps++;
    final today = DateUtils.dateOnly(widget.today);
    Navigator.of(context).pop(
      _beforeTrackingChosen
          ? FreeTickChoice(
              source: LearningEvent.sourceMain,
              dateState: DateState.beforeTracking,
              taps: _taps,
            )
          : FreeTickChoice(
              source: _source,
              dateState: DateState.dated,
              learnedOn: DateUtils.isSameDay(_date, today)
                  ? null
                  : _civil(_date),
              taps: _taps,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat.yMMMd(locale).format(_date);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.captureSourceQuestion, style: theme.textTheme.titleSmall),
            RadioGroup<String>(
              groupValue: _source,
              onChanged: (value) {
                if (value != null) {
                  _taps++;
                  setState(() => _source = value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    key: const Key('freeTickSourceHome'),
                    value: LearningEvent.sourceMain,
                    title: Text(l10n.captureSourceHome),
                  ),
                  for (final option in widget.extraSources)
                    RadioListTile<String>(
                      key: Key('freeTickSource-${option.id}'),
                      value: option.id,
                      title: Text(option.label),
                    ),
                  RadioListTile<String>(
                    key: const Key('freeTickSourceBeforeTracking'),
                    value: _beforeTracking,
                    title: Text(l10n.mishnaHistoryBeforeTracking),
                    subtitle: Text(l10n.captureBeforeTrackingHint),
                  ),
                ],
              ),
            ),
            if (!_beforeTrackingChosen)
              ListTile(
                key: const Key('freeTickDate'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.captureDateLabel),
                subtitle: Text(dateText),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: Text(l10n.captureChangeDate),
                ),
                onTap: _pickDate,
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('freeTickRecord'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: widget.count > 0 ? _record : null,
              child: Text(l10n.captureRecordCount(widget.count)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
