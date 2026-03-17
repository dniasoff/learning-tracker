import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tutor_mode_provider.g.dart';

/// Tracks whether tutor mode is currently active.
///
/// When active, all data modification APIs should be blocked (read-only mode).
/// This is device-local state — tutor mode is entered by verifying the tutor PIN
/// and exited by navigating away from the tutor mode screen.
@Riverpod(keepAlive: true)
class TutorMode extends _$TutorMode {
  @override
  bool build() => false;

  void enter() => state = true;
  void exit() => state = false;
}

/// Exception thrown when a write operation is attempted in tutor mode.
class TutorModeReadOnlyException implements Exception {
  const TutorModeReadOnlyException([
    this.message = 'Write operations are not allowed in tutor mode',
  ]);

  final String message;

  @override
  String toString() => 'TutorModeReadOnlyException: $message';
}

/// Throws [TutorModeReadOnlyException] if tutor mode is currently active.
///
/// Call this at the top of any service/provider method that performs writes.
void guardTutorModeWrite(Ref ref) {
  // Read synchronously — TutorMode is a keepAlive synchronous notifier.
  if (ref.read(tutorModeProvider)) {
    throw const TutorModeReadOnlyException();
  }
}

/// Overload for [WidgetRef] / [AsyncNotifier] that accepts a direct bool.
void guardTutorModeWriteFromBool(bool isTutorMode) {
  if (isTutorMode) {
    throw const TutorModeReadOnlyException();
  }
}
