import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/parent_mode/presentation/providers/parent_track_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart'
    as tm;
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Parent mode screen for managing tracks across all curricula.
///
/// Shows each active curriculum with its current tracks, allowing the parent
/// to add school/tutor tracks or remove them (with confirmation).
/// Personal track is always shown but cannot be removed.
@RoutePage()
class ParentTrackManagementScreen extends ConsumerStatefulWidget {
  const ParentTrackManagementScreen({super.key});

  @override
  ConsumerState<ParentTrackManagementScreen> createState() =>
      _ParentTrackManagementScreenState();
}

class _ParentTrackManagementScreenState
    extends ConsumerState<ParentTrackManagementScreen> {
  bool _addingTrack = false;

  @override
  Widget build(BuildContext context) {
    if (_addingTrack) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Track')),
        body: AddTrackFlow(
          profileId: ref.watch(activeProfileIdProvider),
          isOnboarding: false,
          isChildMode:
              ref.watch(dashboardUserModeProvider).value == UserMode.child,
          onComplete: _onAddTrackComplete,
          onCancel: () => setState(() => _addingTrack = false),
        ),
      );
    }

    final activeCurriculaAsync = ref.watch(parentTrackCurriculaProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: l10n.manageTracks)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _addingTrack = true),
        icon: const Icon(Icons.add),
        label: Text(l10n.addTrack),
      ),
      body: SafeArea(
        top: false,
        child: activeCurriculaAsync.when(
          data: (curricula) => curricula.isEmpty
              ? Center(child: Text(l10n.noActiveCurricula))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: curricula.length,
                  itemBuilder: (context, index) =>
                      _CurriculumTrackCard(curriculum: curricula[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text(l10n.errorLoadingCurricula(error.toString()))),
        ),
      ),
    );
  }

  void _onAddTrackComplete(AddTrackResult result) {
    setState(() => _addingTrack = false);
    ref.invalidate(parentTrackCurriculaProvider);
    ref.invalidate(tm.activeTracksProvider);
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.trackCreated(result.label))));
  }
}

class _CurriculumTrackCard extends ConsumerWidget {
  final CurriculumId curriculum;

  const _CurriculumTrackCard({required this.curriculum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final displayName = localeCode == 'he'
        ? curriculum.displayNameHe
        : curriculum.displayNameEn;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
