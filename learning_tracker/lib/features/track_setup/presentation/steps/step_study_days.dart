import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';

/// Day labels in Jewish week order (Sunday first, Shabbos last).
const kStepStudyDayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Shabbos'];

/// ISO day numbers in Jewish week order.
const kStepStudyDayNumbers = [7, 1, 2, 3, 4, 5, 6];

/// Study days — vertical layout, all 7 active by default, "Shabbos" label.
class StudyDaysEditable extends StatefulWidget {
  const StudyDaysEditable({required this.onComplete, super.key});

  final ValueChanged<Map<int, String>> onComplete;

  @override
  State<StudyDaysEditable> createState() => _StudyDaysEditableState();
}

class _StudyDaysEditableState extends State<StudyDaysEditable> {
  late final Map<int, String> _days;

  @override
  void initState() {
    super.initState();
    _days = Map<int, String>.from(kDefaultStudyDays);
    // All 7 days default to study. Per the platform-wide rule "all days
    // default to a learning day" — users in many communities consider
    // Shabbos a primary learning day, so opting them out by default was a
    // mismatch. Users can still toggle Shabbos off explicitly.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Study Days',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Which days do you learn?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (context, index) {
                final dayNum = kStepStudyDayNumbers[index];
                final isActive = _days[dayNum] == 'study';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StudyDayCard(
                    initial: kStepStudyDayLabels[index].substring(0, 1),
                    title: _dayName(dayNum),
                    subtitle: _daySubtitle(dayNum),
                    subtitleColor: dayNum == 5
                        ? const Color(0xFFAA2F39)
                        : AppTheme.brandInkMuted,
                    activeColor: dayNum == 5
                        ? const Color(0xFFFFE1E4)
                        : const Color(0xFFE9ECF2),
                    isShabbos: dayNum == 6,
                    isOn: isActive,
                    onChanged: (v) =>
                        setState(() => _days[dayNum] = v ? 'study' : 'review'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onComplete(Map.from(_days)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dayName(int dayNum) {
    return switch (dayNum) {
      7 => 'Sunday',
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Shabbos',
      _ => 'Day',
    };
  }

  String _daySubtitle(int dayNum) {
    return switch (dayNum) {
      7 => 'Yom Rishon',
      5 => 'EREV SHABBOS',
      6 => 'DAY OF REST',
      _ => '',
    };
  }
}

class StudyDayCard extends StatelessWidget {
  const StudyDayCard({
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.activeColor,
    required this.isShabbos,
    required this.isOn,
    required this.onChanged,
    super.key,
  });

  final String initial;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Color activeColor;
  final bool isShabbos;
  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isShabbos ? const Color(0xFFD8DCE5) : const Color(0xFFE8EBF2),
        ),
        boxShadow: isShabbos
            ? null
            : const [
                BoxShadow(
                  color: Color(0x121D2939),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: activeColor,
              child: Text(
                initial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.brandBlueBright,
            ),
          ],
        ),
      ),
    );
  }
}

/// Study days — read-only display for program tracks.
class StudyDaysReadOnly extends StatelessWidget {
  const StudyDaysReadOnly({
    required this.programName,
    required this.onContinue,
    super.key,
  });

  final String programName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Study Days', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Study days set by $programName',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    kStepStudyDayLabels[index],
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                );
              },
            ),
          ),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
        ],
      ),
    );
  }
}
