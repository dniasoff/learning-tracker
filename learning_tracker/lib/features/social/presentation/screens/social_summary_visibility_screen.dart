import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/social/domain/social_summary_projection.dart';
import 'package:learning_tracker/features/social/domain/social_summary_visibility.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class SocialSummaryVisibilityScreen extends ConsumerStatefulWidget {
  const SocialSummaryVisibilityScreen({super.key});

  @override
  ConsumerState<SocialSummaryVisibilityScreen> createState() =>
      _SocialSummaryVisibilityScreenState();
}

class _SocialSummaryVisibilityScreenState
    extends ConsumerState<SocialSummaryVisibilityScreen> {
  bool _saving = false;
  SocialSummaryVisibility? _pending;

  Future<void> _save({
    required String profileId,
    required String? parentSessionId,
    required SocialSummaryVisibility visibility,
    required Map<String, Object?> summary,
  }) async {
    final query = (profileId: profileId, parentSessionId: parentSessionId);
    setState(() {
      _saving = true;
      _pending = visibility;
    });
    try {
      await ref
          .read(socialGraphRepositoryProvider)
          .setSummaryVisibility(
            profileId: profileId,
            parentSessionId: parentSessionId,
            visibility: visibility,
            summary: summary,
          );
      ref.invalidate(socialSummaryVisibilityProvider(query));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorWithMessage),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _pending = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileId = ref.watch(activeProfileIdProvider);
    final parentSessionId = ref.watch(parentSessionIdProvider);
    final state = ref.watch(activeLearnerStateProvider);
    if (profileId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.communityVisibilityTitle)),
        body: Center(child: Text(l10n.communitySummaryUnavailable)),
      );
    }
    final query = (profileId: profileId, parentSessionId: parentSessionId);
    final visibilityState = ref.watch(socialSummaryVisibilityProvider(query));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityVisibilityTitle)),
      body: SafeArea(
        child: visibilityState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l10n.errorWithMessage)),
          data: (savedVisibility) {
            final visibility = _pending ?? savedVisibility;
            final learnerState = state.asData?.value;
            if (learnerState == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final summary = socialSummaryPayload(learnerState);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.communityVisibilityDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                _choice(
                  title: l10n.communityVisibilityOverallStreak,
                  value: visibility.overallStreak,
                  onChanged: (value) => _save(
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                    visibility: visibility.copyWith(overallStreak: value),
                    summary: summary,
                  ),
                ),
                _choice(
                  title: l10n.communityVisibilityOverallWeekly,
                  value: visibility.overallWeekly,
                  onChanged: (value) => _save(
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                    visibility: visibility.copyWith(overallWeekly: value),
                    summary: summary,
                  ),
                ),
                _choice(
                  title: l10n.communityVisibilityTrackStreaks,
                  value: visibility.perTrackStreaks,
                  onChanged: (value) => _save(
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                    visibility: visibility.copyWith(perTrackStreaks: value),
                    summary: summary,
                  ),
                ),
                _choice(
                  title: l10n.communityVisibilityTrackWeekly,
                  value: visibility.perTrackWeekly,
                  onChanged: (value) => _save(
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                    visibility: visibility.copyWith(perTrackWeekly: value),
                    summary: summary,
                  ),
                ),
                _choice(
                  title: l10n.communityVisibilityCurrentTracks,
                  value: visibility.currentTracks,
                  onChanged: (value) => _save(
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                    visibility: visibility.copyWith(currentTracks: value),
                    summary: summary,
                  ),
                ),
                _choice(
                  title: l10n.communityVisibilitySiyumim,
                  value: visibility.siyumim,
                  onChanged: (value) => _save(
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                    visibility: visibility.copyWith(siyumim: value),
                    summary: summary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.communityVisibilityPreview,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _Preview(summary: summary, visibility: visibility),
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _choice({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: _saving ? null : onChanged,
  );
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.summary, required this.visibility});

  final Map<String, Object?> summary;
  final SocialSummaryVisibility visibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final streak = summary['streak']! as Map<String, Object?>;
    final weekly = summary['weekly_learning']! as Map<String, Object?>;
    final lines = <Widget>[];
    final overallStreak = streak['overall'] as Map<String, Object?>?;
    if (visibility.overallStreak && overallStreak != null) {
      lines.add(
        _previewLine(
          l10n.communityOverall,
          l10n.communityStreakValues(
            overallStreak['current_days']! as int,
            overallStreak['best_days']! as int,
          ),
        ),
      );
    }
    if (visibility.perTrackStreaks) {
      for (final item in streak['by_curriculum']! as List<Object?>) {
        final row = item! as Map<String, Object?>;
        lines.add(
          _previewLine(
            _label(ref, row['curriculum_id']! as String),
            l10n.communityStreakValues(
              row['current_days']! as int,
              row['best_days']! as int,
            ),
          ),
        );
      }
    }
    final overallWeekly = weekly['overall'] as Map<String, Object?>?;
    if (visibility.overallWeekly && overallWeekly != null) {
      lines.add(
        _previewLine(
          l10n.communityOverall,
          l10n.communityWeeklyCounts(
            overallWeekly['limudim']! as int,
            overallWeekly['chazaros']! as int,
          ),
        ),
      );
    }
    if (visibility.perTrackWeekly) {
      for (final item in weekly['by_curriculum']! as List<Object?>) {
        final row = item! as Map<String, Object?>;
        lines.add(
          _previewLine(
            _label(ref, row['curriculum_id']! as String),
            l10n.communityWeeklyCounts(
              row['limudim']! as int,
              row['chazaros']! as int,
            ),
          ),
        );
      }
    }
    if (visibility.currentTracks) {
      final tracks = summary['current_tracks']! as List<Object?>;
      lines.add(
        _previewLine(
          l10n.communityCurrentTracks,
          l10n.communityTrackCount(tracks.length),
        ),
      );
    }
    if (visibility.siyumim) {
      final siyumim = summary['siyumim']! as List<Object?>;
      lines.add(
        _previewLine(
          l10n.communitySiyumim,
          l10n.communitySiyumCount(siyumim.length),
        ),
      );
    }
    if (lines.isEmpty) return Text(l10n.communityVisibilityPreviewEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }

  Widget _previewLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$label: $value'),
  );

  String _label(WidgetRef ref, String key) {
    final curriculum = CurriculumId.fromStorageKey(key);
    if (curriculum == null) return key;
    return curriculumLabelText(ref, curriculum: curriculum);
  }
}
