import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Whether [track] has not started yet on the learner's civil [today]: a
/// live sub-track whose `window_start` is after today. Such a sub-track is
/// absent from Learn (`onHome` false) yet already holds its ground
/// (`holdsGround`, prd-deviations #4); the engine derives both, this only
/// picks the hub copy.
bool subTrackStartsLater(SubTrack track, CivilDate today) =>
    !track.isEnded && track.windowStart.compareTo(today) > 0;

/// The hub row status of a future-start sub-track, "Starts {date}" with
/// the date in the active locale (UX-DR-89, DNI-496 AC-4), or null when
/// [track] has started or ended.
String? subTrackStartsLabel(
  BuildContext context,
  SubTrack track,
  CivilDate today,
) {
  if (!subTrackStartsLater(track, today)) return null;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.yMMMd(
    locale,
  ).format(parseCivilDay(track.windowStart));
  return AppLocalizations.of(context)!.ongoingSubTrackStarts(date);
}
