import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Read-only school identity surface; reports go through the server callable.
@RoutePage()
class SchoolProfileScreen extends ConsumerWidget {
  const SchoolProfileScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final school = ref.watch(schoolProfileProvider(schoolId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolProfileTitle)),
      body: school.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.schoolProfileUnavailable)),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              profile.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (profile.verified)
              Chip(
                avatar: const Icon(Icons.verified_outlined),
                label: Text(l10n.schoolVerifiedBadge),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.schoolCreatedDate(
                profile.createdAt == null
                    ? l10n.schoolDateUnavailable
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(profile.createdAt!),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.schoolAdminsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final admin in profile.adminNames)
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(admin),
              ),
            TextButton.icon(
              onPressed: () => _report(context, ref, l10n),
              icon: const Icon(Icons.flag_outlined),
              label: Text(l10n.schoolReportAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final category = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.schoolReportTitle)),
            for (final value in ['impersonation', 'abuse', 'other'])
              ListTile(
                title: Text(switch (value) {
                  'impersonation' => l10n.schoolReportImpersonation,
                  'abuse' => l10n.schoolReportAbuse,
                  _ => l10n.schoolReportOther,
                }),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (category == null || !context.mounted) return;
    await ref
        .read(schoolRepositoryProvider)
        .report(schoolId: schoolId, category: category);
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.schoolReportSubmitted)));
  }
}
