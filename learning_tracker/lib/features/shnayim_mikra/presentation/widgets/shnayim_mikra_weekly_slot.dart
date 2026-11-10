import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_reader_data_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_schedule_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/screens/shnayim_mikra_reader_screen.dart';
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
        final state = scope == null
            ? null
            : ref.watch(learnerStateProvider(scope)).asData?.value;
        final refs = refsAsync.asData?.value.expand((aliyah) => aliyah);
        final learned =
            state
                ?.curricula[CurriculumId.shnayimMikra.storageKey]
                ?.learntLeaves ??
            const <String>{};
        final progress = refs == null
            ? null
            : l10n.shnayimMikraProgressVerses(
                refs.where(learned.contains).length,
                refs.length,
              );
        final dueDate = MaterialLocalizations.of(
          context,
        ).formatMediumDate(current.dueDate);
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
                    l10n.shnayimMikraDueBeforeShabbos(dueDate),
                    if (progress != null) progress,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
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
