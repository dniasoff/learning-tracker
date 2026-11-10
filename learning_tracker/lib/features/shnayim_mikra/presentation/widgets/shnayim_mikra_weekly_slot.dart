import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_reading_plan.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_settings_change.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_reader_data_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_schedule_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/screens/shnayim_mikra_reader_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Weekly and catch-up assignments for the learning list.
final class ShnayimMikraWeeklySlot extends ConsumerWidget {
  const ShnayimMikraWeeklySlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(shnayimMikraScheduleProjectionProvider);
    return schedule.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (projection) {
        if (projection == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context)!;
        final current = projection.current;
        final title = _portionName(current.portionKey);
        final refsAsync = ref.watch(
          shnayimMikraParshaVerseRefsProvider((
            current.portionKey,
            current.inIsrael,
          )),
        );
        final scope = ref.watch(activeLearnerScopeProvider).asData?.value;
        final profile = ref.watch(activeProfileProvider).asData?.value;
        final parentPinProfileId = ref.watch(
          parentPinAuthenticatedProfileIdProvider,
        );
        final settingsHistory = scope == null
            ? null
            : ref.watch(learnerLockSettingsProvider(scope)).asData?.value;
        final isParent = canEditShnayimMikraSettings(
          profileMode: profile?.mode,
          profileId: profile?.profileId,
          parentPinProfileId: parentPinProfileId,
          isTutored: ref.watch(activeTutoredProfileSelectionProvider) != null,
        );
        final state = scope == null
            ? null
            : ref.watch(shnayimMikraReaderEventsProvider(scope)).asData?.value;
        final refs = refsAsync.asData?.value.expand((aliyah) => aliyah);
        final learned = state == null
            ? const <String>{}
            : completedShnayimMikraRefs(
                events: state,
                assignmentKey: current.key,
              );
        final progress = refs == null
            ? null
            : l10n.shnayimMikraProgressVerses(
                refs.where(learned.contains).length,
                refs.length,
              );
        final materialL10n = MaterialLocalizations.of(context);
        final dueDate = materialL10n.formatMediumDate(
          DateTime(current.dueAt.year, current.dueAt.month, current.dueAt.day),
        );
        final dueTime = materialL10n.formatTimeOfDay(
          TimeOfDay(hour: current.dueAt.hour, minute: current.dueAt.minute),
        );
        return Card(
          color: context.colors.brandCreamCard,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.menu_book_outlined,
                  color: context.colors.curriculumFor(
                    CurriculumId.shnayimMikra,
                  ),
                ),
                title: Text('${l10n.shnayimMikraReaderTitle} · $title'),
                subtitle: Text(
                  [
                    l10n.shnayimMikraDueBeforeShabbos('$dueDate $dueTime'),
                    if (progress != null) progress,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isParent && settingsHistory != null && scope != null)
                      IconButton(
                        key: const ValueKey('shnayimMikra.settings'),
                        tooltip: l10n.shnayimMikraSettingsTitle,
                        icon: const Icon(Icons.tune),
                        onPressed: () => _editSettings(
                          context,
                          ref,
                          scope.profileId,
                          settingsHistory.current,
                          l10n,
                        ),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openReader(context, current),
              ),
              for (final assignment in projection.catchUp)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    l10n.shnayimMikraCatchUp(
                      _portionName(assignment.portionKey),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openReader(context, assignment),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSettings(
    BuildContext context,
    WidgetRef ref,
    String profileId,
    LearnerSettings current,
    AppLocalizations l10n,
  ) async {
    var mode = current.shnayimMikraMode;
    var pace = current.shnayimMikraPace;
    var source = current.shnayimMikraSource;
    var schedule =
        current.shnayimMikraParshaSchedule ??
        shnayimMikraScheduleFromLegacyYomTovFlag(
          yomTovDays: current.yomTovDays,
          legacyInIsrael: current.inIsrael,
        );
    final edit = await showDialog<ShnayimMikraSettingsEdit>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.shnayimMikraSettingsTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ShnayimMikraMode>(
                  initialValue: mode,
                  decoration: InputDecoration(
                    labelText: l10n.shnayimMikraModeLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ShnayimMikraMode.pasuk,
                      child: Text(l10n.shnayimMikraModePasuk),
                    ),
                    DropdownMenuItem(
                      value: ShnayimMikraMode.aliyah,
                      child: Text(l10n.shnayimMikraModeAliyah),
                    ),
                    DropdownMenuItem(
                      value: ShnayimMikraMode.parsha,
                      child: Text(l10n.shnayimMikraModeParsha),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() {
                    mode = value!;
                    if (mode != ShnayimMikraMode.aliyah) {
                      pace = ShnayimMikraPace.self;
                    }
                  }),
                ),
                DropdownButtonFormField<ShnayimMikraPace>(
                  initialValue: pace,
                  decoration: InputDecoration(
                    labelText: l10n.shnayimMikraPaceLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ShnayimMikraPace.self,
                      child: Text(l10n.shnayimMikraPaceSelf),
                    ),
                    DropdownMenuItem(
                      value: ShnayimMikraPace.dailyAliyah,
                      child: Text(l10n.shnayimMikraPaceDailyAliyah),
                    ),
                  ],
                  onChanged: mode == ShnayimMikraMode.aliyah
                      ? (value) => setDialogState(() => pace = value!)
                      : null,
                ),
                DropdownButtonFormField<ShnayimMikraSource>(
                  initialValue: source,
                  decoration: InputDecoration(
                    labelText: l10n.shnayimMikraSourceLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ShnayimMikraSource.onkelos,
                      child: Text(l10n.shnayimMikraOnkelosReading),
                    ),
                    DropdownMenuItem(
                      value: ShnayimMikraSource.rashi,
                      child: Text(l10n.shnayimMikraRashiReading),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => source = value!),
                ),
                DropdownButtonFormField<ShnayimMikraParshaSchedule>(
                  initialValue: schedule,
                  decoration: InputDecoration(
                    labelText: l10n.shnayimMikraParshaSchedule,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ShnayimMikraParshaSchedule.eretzYisrael,
                      child: Text(l10n.shnayimMikraScheduleEretzYisrael),
                    ),
                    DropdownMenuItem(
                      value: ShnayimMikraParshaSchedule.chutzLaaretz,
                      child: Text(l10n.shnayimMikraScheduleChutzLaaretz),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => schedule = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                ShnayimMikraSettingsEdit(
                  mode: mode,
                  pace: pace,
                  source: source,
                  parshaSchedule: schedule,
                ),
              ),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (edit == null || !context.mounted) return;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) throw const GovernedWriterNotReadyException();
      requireOwnerSuccess(
        await commands.applyGovernedChange(
          shnayimMikraSettingsAction(profileId, edit),
        ),
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shnayimMikraSettingsSaveFailed)),
        );
      }
    }
  }

  void _openReader(
    BuildContext context,
    ShnayimMikraWeeklyAssignment assignment,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShnayimMikraReaderScreen(assignment: assignment),
      ),
    );
  }

  String _portionName(String key) => key
      .split('_')
      .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
      .join('–');
}
