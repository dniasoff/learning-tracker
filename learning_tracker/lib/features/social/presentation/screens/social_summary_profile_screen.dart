import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/features/social/presentation/widgets/social_summary_sections.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class SocialSummaryProfileScreen extends ConsumerWidget {
  const SocialSummaryProfileScreen({
    super.key,
    @PathParam('summaryId') required this.summaryId,
  });

  final String summaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summary = ref.watch(socialSummaryProvider(summaryId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityProfile)),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.communitySummaryUnavailable)),
        data: (value) => value == null
            ? Center(child: Text(l10n.communitySummaryUnavailable))
            : _SummaryContent(summary: value),
      ),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent({required this.summary});

  final SocialSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Text(summary.displayName.characters.first.toUpperCase()),
          ),
          title: Text(
            summary.displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(
            l10n.communityUpdatedAt(
              MaterialLocalizations.of(
                context,
              ).formatMediumDate(summary.computedAt),
            ),
          ),
        ),
        const Divider(),
        SocialSummarySections(summary: summary),
      ],
    );
  }
}
