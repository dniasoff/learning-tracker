import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart'
    show goalRepositoryProvider;
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

/// Stream provider for active tracks for the current profile.
final activeTracksProvider = StreamProvider<List<CurriculumTrackEntity>>((
  ref,
) {
  final adapter = ref.watch(curriculumTrackRepositoryAdapterProvider);
  return adapter.watchActiveTracks();
});

/// Firestore-backed adapter for curriculum-track lifecycle (activate/retire/
/// archive/query) — **wired Phase 3, T-20**.
/// The Drift DAO-backed CurriculumActivationService is deprecated and will
/// be refactored in Phase 4.
final curriculumTrackRepositoryAdapterProvider =
    Provider<FirestoreCurriculumTrackRepositoryAdapter>((ref) {
      return FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
    });

/// Resolves the display title for a track.
///
/// The user-entered track name is stored in `Goal.description` (the Edit Track
/// "Name" field writes there, and new tracks seed it with the curriculum label
/// so it is pre-filled). Returns that custom name when it is non-blank,
/// otherwise falls back to [curriculumFallback] — the curriculum label — so a
/// track without a custom name still shows a sensible title.
///
/// Pure + side-effect free so the precedence rule (custom name wins, blank
/// falls back) is unit-testable without a widget or a DB.
String resolveTrackTitle({
  required String? customName,
  required String curriculumFallback,
}) {
  final trimmed = customName?.trim() ?? '';
  return trimmed.isNotEmpty ? trimmed : curriculumFallback;
}

/// The custom track name (`Goal.description`) for [curriculumId] — AD-25: a
/// track IS its curriculum, so this is the sole identity a "track name" can
/// key off now. `null` when the curriculum has no goal / no description.
/// Watched by the track title surfaces so an edited name re-renders live
/// after [onTrackChanged] invalidation.
final trackCustomNameProvider = FutureProvider.autoDispose
    .family<String?, CurriculumId>((ref, curriculumId) async {
      final goals = await ref
          .watch(goalRepositoryProvider)
          .getGoals(curriculumId);
      final desc = goals.firstOrNull?.description;
      return (desc == null || desc.trim().isEmpty) ? null : desc;
    });

/// Resolves the display title for [track], honouring the user's custom name
/// (from [trackCustomNameProvider]) and falling back to the curriculum label.
///
/// Synchronous: reads the custom-name async value's current data (null while
/// loading) and composes it with the live curriculum label so the title tracks
/// both the Hebrew-Terms toggle (for the fallback) and edits to the name.
String trackDisplayTitle(WidgetRef ref, CurriculumTrackEntity track) {
  final fallback = curriculumLabelText(ref, curriculum: track.curriculumId);
  final customName = ref
      .watch(trackCustomNameProvider(track.curriculumId))
      .asData
      ?.value;
  return resolveTrackTitle(
    customName: customName,
    curriculumFallback: fallback,
  );
}
