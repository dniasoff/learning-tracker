import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_schedule_provider.dart';

/// Weekly assignment projection for the learning list. The reader action is
/// added with the dedicated three-pass reader phase.
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
        final current = projection.current;
        final title = current.portionKey
            .split('_')
            .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
            .join('–');
        final dueDate = MaterialLocalizations.of(
          context,
        ).formatMediumDate(current.dueDate);
        final catchUpCount = projection.catchUp.length;
        return Card(
          color: context.colors.brandCreamCard,
          child: ListTile(
            leading: Icon(
              Icons.menu_book_outlined,
              color: context.colors.curriculumFor(CurriculumId.shnayimMikra),
            ),
            title: Text('Shnayim Mikra · $title'),
            subtitle: Text(
              catchUpCount == 0
                  ? 'Due before Shabbos · $dueDate'
                  : 'Due before Shabbos · $dueDate · $catchUpCount overdue week(s) to catch up',
              style: theme.textTheme.bodySmall,
            ),
            isThreeLine: catchUpCount > 0,
          ),
        );
      },
    );
  }
}
