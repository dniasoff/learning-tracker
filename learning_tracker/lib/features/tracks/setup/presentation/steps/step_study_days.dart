import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Day labels in Jewish week order (Sunday first, Shabbos last).
///
/// Legacy English fallback only — kept for source compatibility. UI labels and
/// avatar initials are now LOCALIZED via [studyDayAbbrevLabel] so the Hebrew
/// locale renders Hebrew abbreviations (א׳, ב׳ …) instead of Latin Sun/Mon and
/// the row never mixes scripts. Do not use this list for display.
const kStepStudyDayLabels = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Shabbos',
];

/// ISO day numbers in Jewish week order.
const kStepStudyDayNumbers = [7, 1, 2, 3, 4, 5, 6];

/// Returns the LOCALIZED short day label for [dayNum] (ISO weekday; Saturday=6).
///
/// Sun–Fri come from the shared scheduler day-abbreviation ARB keys
/// ([AppLocalizations.schedulerDayAbbrevSun] … `Fri`) so the label follows the
/// UI locale (English "Sun" / Hebrew "א׳"). Saturday routes through
/// [DomainTermLabels.shabbos] so it renders "Shabbos" (Ashkenazi) / "Shabbat"
/// (Sephardi) / "שבת" (Hebrew Terms) — matching [_dayName] and the scheduler's
/// `studyDayLabel`. This keeps the whole study-days row script-consistent and
/// drives the day-circle avatar initial (its first grapheme).
String studyDayAbbrevLabel({
  required int dayNum,
  required AppLocalizations l10n,
  required DomainTermLabels terms,
  required TransliterationVariant variant,
}) {
  switch (dayNum) {
    case 7:
      return l10n.schedulerDayAbbrevSun;
    case 1:
      return l10n.schedulerDayAbbrevMon;
    case 2:
      return l10n.schedulerDayAbbrevTue;
    case 3:
      return l10n.schedulerDayAbbrevWed;
    case 4:
      return l10n.schedulerDayAbbrevThu;
    case 5:
      return l10n.schedulerDayAbbrevFri;
    case 6:
      return terms.shabbos(variant: variant);
    default:
      return '';
  }
}

/// First grapheme of [label] — the day-circle avatar initial.
///
/// Grapheme-aware (via `characters`) so a Hebrew abbreviation such as "א׳"
/// yields "א" (not the trailing geresh) and a multi-codepoint glyph is not
/// split mid-character.
String studyDayInitial(String label) =>
    label.characters.isEmpty ? '' : label.characters.first;

/// Study days — vertical layout, all 7 active by default, "Shabbos" label.
class StudyDaysEditable extends ConsumerStatefulWidget {
  const StudyDaysEditable({required this.onComplete, super.key});

  final ValueChanged<Map<int, String>> onComplete;

  @override
  ConsumerState<StudyDaysEditable> createState() => _StudyDaysEditableState();
}

class _StudyDaysEditableState extends ConsumerState<StudyDaysEditable> {
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
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.studyDaysTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.studyDaysSubtitle,
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
                final title = _dayName(dayNum);
                // Avatar initial = first grapheme of the LOCALIZED short label
                // (Sun–Fri from the shared scheduler abbrev keys, Sat from the
                // shabbos term) so the row never mixes Latin initials with a
                // lone Hebrew glyph and stays fully Hebrew in the he locale.
                final initial = studyDayInitial(
                  studyDayAbbrevLabel(
                    dayNum: dayNum,
                    l10n: l10n,
                    terms: terms,
                    variant: variant,
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StudyDayCard(
                    initial: initial,
                    title: title,
                    subtitle: '',
                    subtitleColor: AppTheme.brandInkMuted,
                    activeColor: AppColors.surfaceE9,
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
                  child: Text(l10n.actionContinue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns the locale-aware full weekday name for [dayNum].
  ///
  /// Convention: [dayNum] follows Dart's [DateTime.weekday] values
  /// (1 = Monday … 7 = Sunday), identical to [kStepStudyDayNumbers].
  /// Day 6 (Saturday) renders the app's term "Shabbos" (Ashkenazi) /
  /// "Shabbat" (Sephardi) / "שבת" (Hebrew Terms on) via [domainTermLabels],
  /// so it honours both the transliteration nusach and the Hebrew-Terms
  /// toggle — consistent with the sacred-time feature; other days are
  /// locale-formatted via [DateFormat].
  String _dayName(int dayNum) {
    if (dayNum == 6) {
      return domainTermLabels(
        ref,
      ).shabbos(variant: ref.watch(currentTransliterationVariantProvider));
    }
    final locale = Localizations.localeOf(context).languageCode;
    // Anchor: 2023-01-02 is a Monday (DateTime.weekday == 1).
    // Adding (dayNum - 1) days yields a date whose weekday == dayNum.
    final anchor = DateTime(2023, 1, 2);
    final date = anchor.add(Duration(days: dayNum - 1));
    return DateFormat('EEEE', locale).format(date);
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
class StudyDaysReadOnly extends ConsumerWidget {
  const StudyDaysReadOnly({
    required this.programName,
    required this.onContinue,
    super.key,
  });

  final String programName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.studyDaysTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l10n.studyDaysSetByProgram(programName),
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
                // Localized short labels so the he locale stays fully Hebrew
                // (Sun–Fri from the shared scheduler abbrev keys, Sat from the
                // shabbos term) — no Latin Sun/Mon leaking into Hebrew.
                final label = studyDayAbbrevLabel(
                  dayNum: kStepStudyDayNumbers[index],
                  l10n: l10n,
                  terms: terms,
                  variant: variant,
                );
                return ListTile(
                  title: Text(label, style: theme.textTheme.bodyLarge),
                  trailing: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                );
              },
            ),
          ),
          FilledButton(onPressed: onContinue, child: Text(l10n.actionContinue)),
        ],
      ),
    );
  }
}
