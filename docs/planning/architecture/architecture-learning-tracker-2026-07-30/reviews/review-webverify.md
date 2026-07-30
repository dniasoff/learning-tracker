---
name: Web-Verification Review — ARCHITECTURE-SPINE.md
type: review
lens: web-verification
target: docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md
verified-against: live web (pub.dev package pages/changelogs, Firebase/FlutterFire docs, GitHub source, community threads)
status: complete
---

# Web-Verification Review — ARCHITECTURE-SPINE.md

## Verdict

**Conditionally sound.** The load-bearing claim for owner decision #1 — N named `FirebaseApp` instances, each with an independent `cloud_firestore` offline cache — is supported by the real API surface (`FirebaseFirestore.instanceFor(app:)`, `Settings(persistenceEnabled, cacheSizeBytes)`, `FirebaseAppCheck.instanceFor(app:)`), and is indirectly *corroborated* by a documented Firebase gotcha (a single app's cache is **not** auto-isolated per signed-in user). But I could not find an official doc or changelog that certifies this **exact** topology — N named apps against the **same** project/database, differing only by app name and Auth identity, each retaining a fully independent persistent cache on Android — as a tested, supported pattern; every official "secondary app" example is multi-project/environment-flavor focused, not multi-account-same-project. Treat AD-1 as "supported by the API surface + reasonable inference from cache-key semantics," not as an officially blessed configuration, and de-risk with a throwaway two-app/one-project spike before Phase 0. One real version-drift finding (sqlite3 pinned two years and one breaking major behind current) and one coverage gap (Crashlytics is default-app-only, conflicting with AD-1's "default app reserved for pre-auth only") also need spine edits.

## Top findings

1. **[HIGH — verify before Phase 0] AD-1's exact topology (same project, N named apps, N independent caches) is not explicitly documented anywhere; it's an inference from cache-key semantics, not a cited guarantee.**
   All official Firebase/FlutterFire "secondary FirebaseApp" material (`firebase.google.com/docs/projects/multiprojects`, FlutterFire Core docs, the "Setting Up Flutter Flavors with Multiple Firebase Apps" pattern) addresses **multiple projects/environments**, not multiple accounts inside **one** project distinguished only by `name` + Auth uid. What *is* confirmed: (a) `FirebaseFirestore.instanceFor(app: secondaryApp)` gives a distinct Firestore client per named app; (b) a **single** app/instance's local cache is explicitly **not** auto-partitioned or cleared per signed-in user — Firebase's own community guidance for that case is to manually call `terminate()` + `clearPersistence()` on sign-out, which is precisely the "cache/identity bleed" AD-1 is trying to avoid by using separate apps instead. That's consistent with AD-1's design intent but is inferential corroboration, not a citation that the N-named-apps-same-project shape itself is clean on Android. Recommend: keep AD-1, but add one line committing to a Phase 0 smoke test (2 named apps, same project, 2 different anonymous-Auth users, confirm writes/listeners in app A are invisible to app B's cache and vice versa, confirm no shared cache-directory collision) before the paradigm is load-bearing for the rest of the plan.

2. **[MEDIUM — spine gap] Crashlytics (and Analytics/Performance Monitoring) are documented default-app-only, which conflicts with AD-1 reserving the default app for "pre-auth/registry concerns only."**
   Firebase's own multi-app documentation states plainly that on Android and Apple platforms, "Analytics are only logged for the default app" — and Crashlytics/Performance Monitoring share that default-app restriction. Since `firebase_crashlytics ^5.2.0` is in the Stack and all real per-account usage under AD-1 happens on secondary named apps (`account_<accountId>`), crash reports generated while operating under a secondary app will not automatically attribute/collect the way they would on the default app. The spine doesn't mention this anywhere (not in AD-1, not in Deferred). Needs an explicit line: either Crashlytics stays wired to the default app only (accepting reduced/absent per-account crash attribution) or this is called out as a known limitation to accept/defer.

3. **[MEDIUM — wording precision] AD-18 says Settings are "pinned... at construction," but `FirebaseFirestore.instanceFor(app:, databaseId:)` has no `settings` parameter — Settings must be applied via the `.settings` setter immediately after obtaining the instance, before any other Firestore call.**
   Confirmed from the live `FirebaseFirestore` class docs: `instanceFor()` only accepts `app` and `databaseId`; there's no way to pass `Settings` into the constructor call itself. Functionally the ordering constraint AD-18 relies on ("Settings before persistence/read logic assumes it's on") still holds — it's a "set before first use" contract, not a literal constructor parameter — so the *rule* is sound but "at construction" should read "immediately after obtaining the handle, before first use" to match the actual API shape. Low severity, but worth a one-word-level spine fix since AD-2's `AccountFirebase` registry is the single place this ordering must be enforced correctly.

4. **[LOW — dependency drift, real breaking changes exist] `sqlite3` is pinned at `^2.9.4` in the Stack table; the live latest is `3.5.0`, and `3.0.0` was a genuine breaking major (build-hooks-based native loading replacing `DynamicLibrary`, `dispose()` deprecated in favor of `close()`, WASM no longer auto-registers a default VFS).**
   Every other pinned floor in the Stack table (firebase_core, cloud_firestore, firebase_auth, firebase_app_check, cloud_functions, firebase_crashlytics, flutter_riverpod, riverpod_annotation, drift, fake_cloud_firestore) has a newer release but stays inside the same caret range as the pin — routine drift, not a defect. `sqlite3` is the one exception: `^2.9.4` is `>=2.9.4 <3.0.0`, so the live latest (3.5.0) falls **outside** the declared constraint entirely, and the 2→3 jump carries real API-shape changes that touch the Content DB / Device Registry (AD-16) which are explicitly staying on Drift+sqlite3. Confirm the `^2.9.4` floor reflects the actual current `pubspec.yaml` (not staled since verification) and that a 2.x→3.x upgrade path is a deliberately separate, out-of-scope decision — it isn't mentioned in Deferred and probably should be, since AD-16 treats this dependency as settled/local-only and out of migration scope.

5. **[LOW — resolve the ASSUMPTION concretely] Exactly one actively-published, viable pub.dev ULID package exists: `ulid` (publisher agilord.com, latest `2.0.1`, ~22 months since last publish, zero dependencies, 160/160 pub points, 55 likes). The commonly-cited alternative `d-ulid` is GitHub-only and returns 404 on pub.dev (never published, or de-listed) — it is not a real pub.dev alternative. `ulid4d` likewise appears to be GitHub-only.**
   The package's 22-month publish gap is low-risk given it has zero dependencies to bit-rot and a clean static-analysis score, but "supports latest stable Dart and Flutter SDKs" on the pub.dev score page is an automated re-check at scan time, not evidence of recent maintenance activity — don't over-read it as "actively maintained." Recommend the Stack's `[ASSUMPTION]` row resolve to naming `ulid: ^2.0.1` explicitly (or confirming the app's existing ULID emission is hand-rolled and doesn't need a package at all), rather than leaving "confirm/standardize the generating package" open — there isn't a second credible pub.dev candidate to weigh it against.

## Supporting verification (no material issue found)

- **`cloud_firestore` `Settings` / `cacheSizeBytes` API names are current and unchanged**: constructor takes `persistenceEnabled: bool?`, `cacheSizeBytes: int?` (plus `host`, `sslEnabled`, web-only long-polling/tab-manager options), with `Settings.CACHE_SIZE_UNLIMITED` for disabling LRU GC. No deprecation notices found on the live platform-interface docs. This matches AD-18's rule shape exactly (persistence + bounded `cacheSizeBytes` per handle).
- **`FirebaseAppCheck.instanceFor(app:)` exists and has existed since `firebase_app_check` v0.0.5** (per its changelog: "NEW: Added support for multi-app via the `instanceFor()` method") — so per-account App Check activation implied by combining AD-1 with AD-12's future rules-level enforcement is technically supported today, well below the pinned `^0.4.4+1` floor.
- **Named-app initialization on Android is a real, working, documented pattern**: `FirebaseApp.initializeApp(context, options, "secondary")` / `Firebase.initializeApp(name: ..., options: ...)` in Dart, retrievable via `Firebase.app('name')`. The one platform caveat found is web-specific (`initializeApp` with a `name` historically errored on web before a fix) — irrelevant here since AD-18 already excludes web from the offline-switch guarantee.
- **Live package versions as of this check** (all within the same caret range as the Stack table's pinned floor, sqlite3 excepted — see finding 4): firebase_core 4.12.1, cloud_firestore 6.7.1, firebase_auth 6.5.6, firebase_app_check 0.4.5+2, cloud_functions 6.3.5, firebase_crashlytics 5.2.6, flutter_riverpod 3.4.2, riverpod_annotation 4.0.6, drift 2.34.3, fake_cloud_firestore 4.2.0, connectivity_plus 7.3.1, internet_connection_checker 3.0.1 (unchanged/dormant, consistent with the spine retiring it from the status path).

## Sources

- https://pub.dev/packages/firebase_core
- https://pub.dev/packages/cloud_firestore
- https://pub.dev/packages/cloud_firestore/changelog
- https://pub.dev/packages/firebase_auth
- https://pub.dev/packages/firebase_app_check
- https://pub.dev/packages/firebase_app_check/changelog
- https://pub.dev/packages/cloud_functions
- https://pub.dev/packages/firebase_crashlytics
- https://pub.dev/packages/flutter_riverpod
- https://pub.dev/packages/riverpod_annotation
- https://pub.dev/packages/drift
- https://pub.dev/packages/sqlite3
- https://pub.dev/packages/sqlite3/changelog
- https://pub.dev/packages/fake_cloud_firestore
- https://pub.dev/packages/connectivity_plus
- https://pub.dev/packages/internet_connection_checker
- https://pub.dev/packages/ulid
- https://pub.dev/packages/ulid/score
- https://pub.dev/packages/d_ulid (404 — not published)
- https://pub.dev/documentation/cloud_firestore_platform_interface/latest/cloud_firestore_platform_interface/Settings-class.html
- https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/FirebaseFirestore-class.html
- https://github.com/firebase/flutterfire/blob/master/packages/cloud_firestore/cloud_firestore/lib/src/firestore.dart
- https://firebase.google.com/docs/projects/multiprojects
- https://firebase.google.com/docs/firestore/manage-data/enable-offline
- https://github.com/firebase/firebase-ios-sdk/discussions/14596 (clearPersistence / multi-user cache gotcha)
- https://github.com/firebase/flutterfire/issues/9400 (named-app-on-web historical limitation)
