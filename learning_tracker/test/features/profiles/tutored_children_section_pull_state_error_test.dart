// The former single test case was removed during the Drift-to-Firestore
// migration. It exercised buildTutoredPullServiceFromWidget's no-live-session
// StateError and the old firebaseFirestoreProvider/UserDatabase wiring; that
// entry path no longer exists in the current Firestore tutor flow, so there is
// no honest Firestore-fake equivalent to preserve.
void main() {}
