/// Learner-state domain (AD-35) — placeholder library.
///
/// Home of the pure `LearnerStateEngine(events, subTracks, mainTrackIntent,
/// goals, intentHistory, calendars, corpora, nowUtc) → LearnerState` that
/// later sub-tracks stories implement. Everything under `lib/domain/**`
/// must stay pure Dart: `tool/check_dependency_direction.dart` fails on any
/// import of `cloud_firestore`, `firebase_*`, `flutter/`,
/// `flutter_riverpod`, `riverpod*` or `learning_tracker/data/**` here.
///
/// Intentionally import-free and empty until story 1.2 lands the data
/// contracts.
library;
