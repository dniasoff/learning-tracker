import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Lists every registered calendar learning program and opens today's
/// reading from the local content index when it is available.
class DailyLearningProgramsSlot extends ConsumerWidget {
  const DailyLearningProgramsSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final calendar = ref.watch(todayCalendarProvider);
    final contentIndexAsync = ref.watch(contentIndexProvider);
    final contentIndex = contentIndexAsync.asData?.value;
    final entries = calendar.asData?.value ?? const <CalendarProgramEntry>[];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(l10n.dailyLearningProgramsTitle),
        subtitle: Text(l10n.dailyLearningProgramsSubtitle),
        children: [
          if (calendar.isLoading ||
              (!calendar.hasError && contentIndexAsync.isLoading))
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (calendar.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${calendar.error}'),
            )
          else
            for (final program in _programsIncludingCalendarExtras(entries))
              _ProgramTile(
                program: program.definition,
                entry: program.entry,
                contentIndex: contentIndex,
              ),
        ],
      ),
    );
  }
}

List<_DailyProgram> _programsIncludingCalendarExtras(
  List<CalendarProgramEntry> entries,
) {
  final entriesById = {for (final entry in entries) entry.programId: entry};
  const definitions = CalendarProgramRegistry.programs;
  final knownIds = definitions.map((program) => program.id).toSet();
  final rows = [
    for (final definition in definitions)
      _DailyProgram(definition: definition, entry: entriesById[definition.id]),
  ];
  for (final entry in entries) {
    if (knownIds.add(entry.programId)) {
      rows.add(_DailyProgram(entry: entry));
    }
  }
  return rows;
}

class _DailyProgram {
  const _DailyProgram({this.definition, this.entry});

  final CalendarProgramDefinition? definition;
  final CalendarProgramEntry? entry;
}

class _ProgramTile extends ConsumerWidget {
  const _ProgramTile({
    required this.program,
    required this.entry,
    required this.contentIndex,
  });

  final CalendarProgramDefinition? program;
  final CalendarProgramEntry? entry;
  final ContentIndex? contentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final title = entry != null
        ? calendarEntryLabelText(ref, entry: entry!)
        : calendarProgramDefinitionLabelText(ref, program: program!);
    if (entry == null) {
      return ListTile(
        dense: true,
        title: Text(title),
        subtitle: Text(l10n.dailyLearningProgramNoSchedule),
      );
    }

    final refs = contentIndex == null
        ? const <String>{}
        : resolveProgramTodayRefs(entry!.todayRef, contentIndex!.allItems);
    if (refs.isEmpty) {
      return ListTile(
        dense: true,
        title: Text(title),
        subtitle: Text(l10n.dailyLearningProgramNoOfflineText),
      );
    }

    final orderedRefs = contentIndex!.allItems
        .where((item) => refs.contains(item.sefariaRef))
        .map((item) => item.sefariaRef)
        .toList(growable: false);
    return Column(
      children: [
        for (final sefariaRef in orderedRefs)
          ListTile(
            dense: true,
            title: Text(title),
            subtitle: Text(sefariaRef),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.router.push(TextDisplayRoute(sefariaRef: sefariaRef)),
          ),
      ],
    );
  }
}
