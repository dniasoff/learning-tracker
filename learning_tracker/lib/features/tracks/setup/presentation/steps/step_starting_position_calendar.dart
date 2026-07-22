import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Calendar-program variant of the starting-position step.
///
/// Shows a date-offset picker (±30 days from today) and resolves the
/// corresponding [CalendarProgramEntry] via [CalendarProgramService].
/// The confirmed result is encoded as `offset:<days>|ref:<todayRef>`.
class StartingPositionCalendarMode extends ConsumerStatefulWidget {
  const StartingPositionCalendarMode({
    required this.selectedProgram,
    required this.onComplete,
    super.key,
  });

  final LearningProgramData selectedProgram;
  final ValueChanged<String?> onComplete;

  @override
  ConsumerState<StartingPositionCalendarMode> createState() =>
      _StartingPositionCalendarModeState();
}

class _StartingPositionCalendarModeState
    extends ConsumerState<StartingPositionCalendarMode> {
  int _offsetDays = 0;
  bool _calendarLoading = false;
  String? _calendarProgramKey;
  CalendarProgramEntry? _calendarEntry;

  // AUD-tracks-04 (EH-3): _refreshCalendarEntry had no catch clause at all
  // (only `finally`), so a thrown exception propagated as an unhandled
  // Future rejection (every caller invokes it via `unawaited(...)`). The
  // widget then rendered the hardcoded "No local calendar entry found for
  // this date." fallback, mislabelling a real fetch/service failure as
  // "no data for this date". Track failures explicitly so the UI can show
  // a distinct, retryable error affordance instead.
  bool _calendarError = false;

  // B2 enforcement — picker bounds from ProgramStartingPosition.allowedWindow().
  // Memoised at build time; today's date is the upper bound.
  late final DateTime _today;
  late final int _minOffsetDays;
  // maxOffset is always 0 (no future dates allowed — B2).
  static const int _maxOffsetDays = 0;

  DateTime get _selectedDate =>
      DateTimeFactory.nowLocal().add(Duration(days: _offsetDays));

  @override
  void initState() {
    super.initState();
    // B2: compute the allowed window once and store as offset bounds.
    _today = DateTimeFactory.nowLocal();
    final window = ProgramStartingPosition.allowedWindow(_today);
    // Window is [today − N, today]; the back-bound is a negative offset.
    // `minDate.difference(maxDate)` is already negative (e.g. −30 days) —
    // double-negating it produced +30 and disabled both arrows.
    _minOffsetDays = window.minDate.difference(window.maxDate).inDays;
    _calendarProgramKey = _resolveCalendarProgramKey();
    unawaited(_refreshCalendarEntry());
  }

  String? _resolveCalendarProgramKey() {
    final apiKey = widget.selectedProgram.apiProgramKey;
    if (apiKey == null || apiKey.isEmpty) {
      assert(
        !widget.selectedProgram.isCalendarProgram,
        'Calendar program ${widget.selectedProgram.name} has null/empty '
        'apiProgramKey — every is_calendar_program seed must set '
        'api_program_key to a CalendarProgramDefinition.id',
      );
      return null;
    }
    final resolved =
        CalendarProgramRegistry.byId(apiKey)?.id ??
        CalendarProgramRegistry.byApiKey(apiKey)?.id ??
        CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
    assert(
      resolved != null,
      'Calendar program ${widget.selectedProgram.name} apiProgramKey="$apiKey"'
      ' did not resolve to any CalendarProgramRegistry entry. Update '
      'learning_program_seeds.dart so api_program_key matches a '
      'CalendarProgramDefinition.id.',
    );
    return resolved;
  }

  Future<void> _refreshCalendarEntry() async {
    if (_calendarProgramKey == null) return;
    setState(() {
      _calendarLoading = true;
      _calendarError = false;
    });
    try {
      final service = await ref.read(calendarProgramServiceProvider.future);
      final entry = await service.getEntry(_calendarProgramKey!, _selectedDate);
      if (!mounted) return;
      setState(() {
        _calendarEntry = entry;
        _calendarError = false;
      });
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event: 'tracks_calendar_entry_load_failed',
        fields: {'programKey': _calendarProgramKey},
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _calendarEntry = null;
        _calendarError = true;
      });
    } finally {
      if (mounted) setState(() => _calendarLoading = false);
    }
  }

  // Locale-aware weekday + month + day (e.g. "Monday, May 31" / Hebrew
  // equivalent) — replaces the old hardcoded English name arrays so Hebrew
  // users see Hebrew (R4-2).
  String _dateLabel(BuildContext context) {
    final localeName = Localizations.localeOf(context).languageCode;
    return DateFormat('EEEE, MMM d', localeName).format(_selectedDate);
  }

  String _offsetLabel(AppLocalizations l10n) => switch (_offsetDays) {
    0 => l10n.calendarOffsetToday,
    < 0 => l10n.calendarOffsetDay('$_offsetDays'),
    _ => l10n.calendarOffsetDay('+$_offsetDays'),
  };

  String _directionLabel(AppLocalizations l10n) => switch (_offsetDays) {
    > 0 => l10n.calendarDirectionForward,
    < 0 => l10n.calendarDirectionBackwards,
    _ => l10n.calendarDirectionToday,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final absDays = _offsetDays.abs();
    final daysLabel = l10n.calendarOffsetDaysCount(absDays);
    final canStart = _calendarEntry != null && !_calendarLoading;

    // R1-(4): wrap in SingleChildScrollView so the column can scroll at large
    // OS text scales instead of overflowing ("BOTTOM OVERFLOWED BY 59 PIXELS").
    // Spacer() is incompatible with scroll views (it requires unbounded height),
    // so replace it with a fixed-height gap.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.startingPositionTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.startingPositionHint,
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.colors.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          _buildDateCard(theme, l10n, _dateLabel(context)),
          const SizedBox(height: 14),
          _buildOffsetStepper(theme, l10n, daysLabel),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () {
              setState(() => _offsetDays = 0);
              unawaited(_refreshCalendarEntry());
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: const Color(0xFFE9EBF1),
              foregroundColor: context.colors.brandInk,
            ),
            child: Text(l10n.actionUseToday),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: canStart
                ? () => widget.onComplete(
                    'offset:$_offsetDays|ref:${_calendarEntry!.todayRef}',
                  )
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // AUD-t-cross-34: at narrow viewports + large OS text scale
                // (e.g. 320×568 @ 2.0x) the unconstrained label overflowed the
                // button's Row by 43px. Flexible+ellipsis lets the label
                // shrink instead of overflowing while the icon stays fixed.
                Flexible(
                  child: Text(
                    l10n.actionStartHereLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.rocket_launch_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(
    ThemeData theme,
    AppLocalizations l10n,
    String dateLabel,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFE6E8FF),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 28,
                    color: context.colors.brandBlueDeep,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.startingPositionTargetDate,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: context.colors.brandInkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: context.colors.brandBlueDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCalendarEntrySection(theme),
              ],
            ),
          ),
        ),
        Positioned(
          top: -14,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFF707D),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _offsetLabel(l10n),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOffsetStepper(
    ThemeData theme,
    AppLocalizations l10n,
    String daysLabel,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7EAF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // B2: min is today − kMaxLookBackDays (no older). When already at
            // the lower bound, hide the chevron (but keep its slot) so the
            // header stays centred.
            Visibility(
              visible: _offsetDays > _minOffsetDays,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _OffsetButton(
                icon: Icons.chevron_left_rounded,
                enabled: true,
                onTap: () {
                  setState(() => _offsetDays -= 1);
                  unawaited(_refreshCalendarEntry());
                },
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _offsetDays == 0 ? l10n.calendarOffsetToday : daysLabel,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _directionLabel(l10n),
                      style: theme.textTheme.titleSmall?.copyWith(
                        letterSpacing: 1.1,
                        color: context.colors.brandInkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // B2: max is today (no future dates). Hide the forward chevron
            // entirely when at the upper bound — the policy is back-only, so
            // a permanently-disabled arrow is confusing. The slot is kept
            // (maintainSize) so the centred label doesn't reflow.
            Visibility(
              visible: _offsetDays < _maxOffsetDays,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _OffsetButton(
                icon: Icons.chevron_right_rounded,
                enabled: true,
                onTap: () {
                  setState(() => _offsetDays += 1);
                  unawaited(_refreshCalendarEntry());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarEntrySection(ThemeData theme) {
    if (_calendarLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_calendarError) {
      final l10n = AppLocalizations.of(context)!;
      return Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.calendarEntryLoadFailed,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 2),
          TextButton(
            onPressed: () => unawaited(_refreshCalendarEntry()),
            child: Text(l10n.actionRetry),
          ),
        ],
      );
    }
    if (_calendarEntry != null) {
      return Column(
        children: [
          Builder(
            builder: (context) {
              final refLabel = calendarEntryTodayRefText(
                ref,
                entry: _calendarEntry!,
              );
              return Text(
                refLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: context.colors.brandInk,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final label = calendarEntryLabelText(ref, entry: _calendarEntry!);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E2C5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A4A13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }
    return Text(
      AppLocalizations.of(context)!.calendarNoLocalEntryFound,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _OffsetButton extends StatelessWidget {
  const _OffsetButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: enabled ? onTap : null,
      child: Ink(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 30,
          color: enabled
              ? context.colors.brandBlueDeep
              : context.colors.brandInkMuted.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
