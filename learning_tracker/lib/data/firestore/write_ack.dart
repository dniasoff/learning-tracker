/// Bounded-acknowledgement helper for Firestore writes.
///
/// ## Why this exists
///
/// A bare `await` on any Firestore write NEVER RETURNS while the client is
/// offline. Measured on a real device (cloud_firestore 6.8.0, Android emulator
/// against the Firestore emulator): both `DocumentReference.set` and
/// `WriteBatch.commit` left the await pending indefinitely offline, yet every
/// document was present on the server after reconnecting.
///
/// The cause is platform-level: the Android plugin awaits a `Task` that
/// completes only on SERVER acknowledgement
/// (`FlutterFirebaseFirestorePlugin.java` does `Tasks.await(...)`), while the
/// SDK has already durably queued the write locally. So the data is safe and
/// the UI is stuck — which presents to a learner as the app freezing on a bus
/// or a train, and is close to undiagnosable from a bug report.
///
/// ## What this does
///
/// Bounds the wait and treats a timeout as *queued, will sync*. That is sound
/// precisely because the probe showed the write lands: the timeout means "no
/// server acknowledgement yet", not "lost".
///
/// A genuine failure — permission denied, invalid argument — still surfaces
/// promptly WHILE ONLINE, because the server answers rather than timing out.
///
/// ## Do NOT use this on reads
///
/// A bounded read that times out returns nothing, which fabricates an empty
/// result and is indistinguishable from real emptiness — the silent-zero defect
/// class owner ruling D-E exists to forbid. Writes queue offline; reads do not.
library;

import 'dart:async';

/// How long to wait for a Firestore server acknowledgement before treating a
/// write as queued-and-will-sync.
///
/// Short by design: while online a write acknowledges in well under this, so
/// the timeout path is reached essentially only when genuinely offline.
const Duration kFirestoreWriteAckTimeout = Duration(seconds: 3);

extension FirestoreWriteAck on Future<void> {
  /// Awaits a server acknowledgement, giving up after
  /// [kFirestoreWriteAckTimeout] and treating that as *queued offline*.
  ///
  /// Use on every Firestore WRITE reached from a UI path. Never on a read.
  Future<void> get orQueuedOffline =>
      timeout(kFirestoreWriteAckTimeout, onTimeout: () {});
}
