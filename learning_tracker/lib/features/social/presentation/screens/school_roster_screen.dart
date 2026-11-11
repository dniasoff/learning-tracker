import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The staff-only roster routes each member to w4v's shared summary provider.
@RoutePage()
class SchoolRosterScreen extends ConsumerWidget {
  const SchoolRosterScreen({
    super.key,
    required this.schoolId,
    required this.onOpenSummary,
  });

  final String schoolId;
  final ValueChanged<String> onOpenSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roster = ref.watch(
      schoolRosterProvider((schoolId: schoolId, limit: 50)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolRosterTitle)),
      body: roster.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.schoolProfileUnavailable)),
        data: (members) => ListView(
          children: [
            for (final member in members)
              ListTile(
                leading: CircleAvatar(
                  child: Text(member.displayName.characters.firstOrNull ?? '?'),
                ),
                title: Text(member.displayName),
                subtitle: member.mode == 'child'
                    ? Text(l10n.schoolChildMemberLabel)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenSummary(member.summaryId),
              ),
          ],
        ),
      ),
    );
  }
}
