import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/labels/program_label_resolver.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The locally cached reading schedule, linked to profile-visible text.
class CalendarReadingsSection extends ConsumerWidget {
  const CalendarReadingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final resolver = ProgramLabelResolver.of(ref);
    final readings = ref.watch(todayCalendarProvider);

    return readings.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.todayReadings, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(resolver.calendarEntryLabel(entry)),
                    subtitle: Text(resolver.calendarEntryTodayRef(entry)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openReading(context, ref, entry),
                  ),
                ),
              ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Future<void> _openReading(
    BuildContext context,
    WidgetRef ref,
    CalendarProgramEntry entry,
  ) async {
    final definition = CalendarProgramRegistry.byId(entry.programId);
    final curriculum = definition == null
        ? null
        : CurriculumId.fromStorageKey(definition.curriculumType);
    if (curriculum == null) {
      _showUnavailable(context);
      return;
    }

    try {
      final content = await ref.read(
        curriculumContentProvider(curriculum).future,
      );
      final resolved = resolveProgramTodayRefs(entry.todayRef, content);
      final reading = _firstVisibleReading(content, resolved);
      if (!context.mounted) return;
      if (reading == null) {
        _showUnavailable(context);
        return;
      }
      await context.router.push(TextDisplayRoute(sefariaRef: reading));
    } catch (_) {
      if (context.mounted) _showUnavailable(context);
    }
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.readingUnavailable)),
    );
  }

  String? _firstVisibleReading(List<ContentItem> content, Set<String> refs) {
    for (final item in content) {
      if (item.isLeaf && refs.contains(item.sefariaRef)) return item.sefariaRef;
    }
    return null;
  }
}
