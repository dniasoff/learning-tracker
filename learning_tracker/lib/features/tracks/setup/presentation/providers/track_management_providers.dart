import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Stream provider for active tracks for the current profile.
final activeTracksProvider = StreamProvider<List<CurriculumTrack>>((ref) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.trackDao.watchActiveTracksForProfile(profileId);
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

/// The custom track name (`Goal.description`) for [trackId], or null when the
/// track has no goal / no description. Watched by the track title surfaces so
/// an edited name re-renders live after [onTrackChanged] invalidation.
final trackCustomNameProvider = FutureProvider.autoDispose.family<String?, int>(
  (ref, trackId) async {
    final goal = await ref
        .watch(userDatabaseProvider)
        .goalDao
        .getGoalByTrack(trackId);
    final desc = goal?.description;
    return (desc == null || desc.trim().isEmpty) ? null : desc;
  },
);

/// Resolves the display title for [track], honouring the user's custom name
/// (from [trackCustomNameProvider]) and falling back to the curriculum label.
///
/// Synchronous: reads the custom-name async value's current data (null while
/// loading) and composes it with the live curriculum label so the title tracks
/// both the Hebrew-Terms toggle (for the fallback) and edits to the name.
String trackDisplayTitle(WidgetRef ref, CurriculumTrack track) {
  final curriculum = CurriculumId.values
      .where((c) => c.storageKey == track.curriculumId)
      .firstOrNull;
  final fallback = curriculum != null
      ? curriculumLabelText(ref, curriculum: curriculum)
      : track.curriculumId;
  final customName = ref.watch(trackCustomNameProvider(track.id)).asData?.value;
  return resolveTrackTitle(
    customName: customName,
    curriculumFallback: fallback,
  );
}
