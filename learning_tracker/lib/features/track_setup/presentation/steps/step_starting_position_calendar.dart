import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _kWeekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _kMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

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

  DateTime get _selectedDate =>
      DateTimeFactory.nowLocal().add(Duration(days: _offsetDays));

  @override
  void initState() {
    super.initState();
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
    setState(() => _calendarLoading = true);
    try {
      final service = ref.read(calendarProgramServiceProvider);
      final entry = await service.getEntry(_calendarProgramKey!, _selectedDate);
      if (!mounted) return;
      setState(() => _calendarEntry = entry);
    } finally {
      if (mounted) setState(() => _calendarLoading = false);
    }
  }

  String _dateLabel() {
    final d = _selectedDate;
    return '${_kWeekdayNames[d.weekday - 1]}, ${_kMonthNames[d.month - 1]} ${d.day}';
  }

  String _offsetLabel() => switch (_offsetDays) {
    0 => 'Today',
    < 0 => 'Day $_offsetDays',
    _ => 'Day +$_offsetDays',
  };

  String _directionLabel() => switch (_offsetDays) {
    > 0 => 'FORWARD',
    < 0 => 'BACKWARDS',
    _ => 'TODAY',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final absDays = _offsetDays.abs();
    final daysLabel = absDays == 1 ? '1 Day' : '$absDays Days';
    final canStart = _calendarEntry != null && !_calendarLoading;

    return Padding(
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
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          _buildDateCard(theme, l10n),
          const SizedBox(height: 14),
          _buildOffsetStepper(theme, daysLabel),
          const Spacer(),
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
              foregroundColor: AppTheme.brandInk,
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
                Text(l10n.actionStartHereLabel),
                const SizedBox(width: 8),
                const Icon(Icons.rocket_launch_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(ThemeData theme, AppLocalizations l10n) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
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
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFE6E8FF),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 28,
                    color: AppTheme.brandBlueDeep,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.startingPositionTargetDate,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dateLabel(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.brandBlueDeep,
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
                _offsetLabel(),
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

  Widget _buildOffsetStepper(ThemeData theme, String daysLabel) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7EAF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _OffsetButton(
              icon: Icons.chevron_left_rounded,
              enabled: _offsetDays > -30,
              onTap: () {
                setState(() => _offsetDays -= 1);
                unawaited(_refreshCalendarEntry());
              },
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _offsetDays == 0 ? 'Today' : daysLabel,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _directionLabel(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        letterSpacing: 1.1,
                        color: AppTheme.brandInkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _OffsetButton(
              icon: Icons.chevron_right_rounded,
              enabled: _offsetDays < 30,
              onTap: () {
                setState(() => _offsetDays += 1);
                unawaited(_refreshCalendarEntry());
              },
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
                  color: AppTheme.brandInk,
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
      'No local calendar entry found for this date.',
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
              ? AppTheme.brandBlueDeep
              : AppTheme.brandInkMuted.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
