/// How a My talmidim row opens its learner (Story 4.3, DNI-511; AC-3,
/// AC-5, UX-DR-83).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';

/// Opens a talmid's context from his row: the learner's screens, or with
/// [groundSubTrackId] that sub-track's ground picker (*Add ground*).
abstract interface class TalmidContextOpener {
  /// Opens [entry]; true when the learner's context was entered, false
  /// when it was cancelled or refused (the roster stays as it was).
  Future<bool> open(
    BuildContext context,
    TalmidRosterEntry entry, {
    String? groundSubTrackId,
  });
}

/// The opener rows use.
final talmidContextOpenerProvider = Provider<TalmidContextOpener>(
  (ref) => const _NotWiredTalmidContextOpener(),
);

final class _NotWiredTalmidContextOpener implements TalmidContextOpener {
  const _NotWiredTalmidContextOpener();

  @override
  Future<bool> open(
    BuildContext context,
    TalmidRosterEntry entry, {
    String? groundSubTrackId,
  }) async => false;
}
