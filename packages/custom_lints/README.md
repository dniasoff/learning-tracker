# learning_tracker_lints

Custom lint rules for the Learning Tracker project. Powered by [custom_lint](https://pub.dev/packages/custom_lint).

---

## Rule 1 — `no_curriculum_display_name_bypass`

### What it checks

Fails on any direct property access of `.displayNameEn` or `.displayNameHe` outside the canonical whitelist:

- `lib/core/labels/` — the only place allowed to consume raw display-name fields
- Files ending in `.g.dart` or `.freezed.dart` — generated code (excluded automatically)

### Why it exists

Story 25.9 introduced `CurriculumLabelRenderer` as the **sole** consumer of curriculum display names. All presentation and business logic must go through this renderer so that:

- Label lookup is locale-aware and centralised.
- Regressions (e.g., hardcoded language selection) are caught automatically by CI.

### How to fix

**Before (banned):**
```dart
Text(item.displayNameEn); // direct field access
```

**After (correct):**
```dart
// Inject or locate via Riverpod:
final label = ref.watch(curriculumLabelRendererProvider);
Text(label.render(item));
```

---

## Rule 2 — `no_feature_cross_import`

### What it checks

Fails on any `import 'package:learning_tracker/features/X/…'` that appears inside a file under `features/Y/` (a different feature), **unless** the imported path is exactly `providers.dart` (or ends with `/providers.dart`).

### Why it exists

Following NFR2 / NFR17, features must be independently deployable and testable. Direct deep imports between features create hidden coupling that:

- Breaks feature isolation and makes incremental builds unreliable.
- Makes it impossible to reason about a feature's public API surface.

The single allowed crossing point is `features/<feature>/providers.dart`, which is the deliberate, documented public surface.

### How to fix

**Before (banned):**
```dart
// Inside features/dashboard/...
import 'package:learning_tracker/features/learning/data/repositories/progress_repository.dart';
```

**After (correct):**
```dart
// Use the public providers surface:
import 'package:learning_tracker/features/learning/providers.dart';
// Then read the provider from Riverpod rather than importing the repo directly.
```

If the type you need is not yet exposed through `providers.dart`, add it to that file rather than bypassing the boundary.

---

---

## Rule 3 — `no_firebase_outside_core`

### What it checks

Fails on any import of a Firebase SDK package in a file that is **not** under one of these authorised directories:

- `lib/core/auth/` — the authentication domain (Firebase Auth)
- `lib/core/sync/` — the Firestore / Firebase Storage sync domain

Restricted package prefixes:

- `package:firebase_auth/`
- `package:cloud_firestore/`
- `package:firebase_storage/`

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

### Why it exists

NFR3 requires that all Firebase interaction be confined to the core infrastructure layer. This prevents Firebase types from leaking into feature and presentation code, making the Firebase dependency replaceable and testable in isolation.

### How to fix

**Before (banned):**
```dart
// Inside lib/features/dashboard/...
import 'package:cloud_firestore/cloud_firestore.dart';

final db = FirebaseFirestore.instance;
```

**After (correct):**
```dart
// Inject the abstraction from lib/core/sync/:
import 'package:learning_tracker/core/sync/sync_repository.dart';

// Use the injected SyncRepository; never touch Firestore directly.
```

If the functionality you need is not yet exposed by `core/auth/` or `core/sync/`, extend those layers rather than bypassing the boundary.

---

## Rule 4 — `no_raw_talker`

### What it checks

Fails on the import:

```dart
import 'package:talker/talker.dart';
```

in any file that is **not** under `lib/core/logging/`.

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

Note: other Talker packages (e.g. `package:talker_flutter/…`) are **not** restricted by this rule; only the raw `package:talker/talker.dart` URI is banned.

### Why it exists

NFR8 requires that all log output pass through the centralised redaction layer before being written. Importing the raw `Talker` class bypasses redaction rules and log-level configuration, which can leak PII or make log noise uncontrollable.

### How to fix

**Before (banned):**
```dart
// Inside lib/features/auth/...
import 'package:talker/talker.dart';

final talker = Talker();
talker.log('User signed in: $email'); // leaks PII, bypasses redaction
```

**After (correct):**
```dart
// Use the application logger from the core logging abstraction:
import 'package:learning_tracker/core/logging/app_logger.dart';

AppLogger.instance.info('User signed in'); // redacted, centralised
```

---

## Rule 5 — `no_hardcoded_text_direction`

### What it checks

Warns on the following hardcoded directional values in Dart files:

| Banned expression | RTL-safe alternative |
|---|---|
| `EdgeInsets.only(left: …)` | `EdgeInsetsDirectional.only(start: …)` |
| `EdgeInsets.only(right: …)` | `EdgeInsetsDirectional.only(end: …)` |
| `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `Alignment.centerRight` | `AlignmentDirectional.centerEnd` |
| `TextAlign.left` | `TextAlign.start` |
| `TextAlign.right` | `TextAlign.end` |
| `textDirection: TextDirection.rtl` (bare literal) | Omit the override (ambient `Directionality`) or compute it from a locale-aware flag |
| `textDirection: TextDirection.ltr` (bare literal) | Same as above |

A **computed** `textDirection:` value — a ternary keyed off a locale-aware flag (`useHebrew ? TextDirection.rtl : TextDirection.ltr`), `Directionality.of(context)`, a variable, etc. — is direction-aware and is *not* flagged. Only a bare `TextDirection.rtl`/`.ltr` literal used directly as the argument value is banned (AUD-tracks-25).

**Severity: WARNING** — existing code has many legacy violations. New code must not introduce new ones. Clean up incrementally.

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

### Why it exists

UX-DR5 and NFR16 mandate full RTL support (Hebrew UI). Hardcoded `left`/`right` variants assume LTR layout and produce mirror-image bugs when the device locale switches to Hebrew or any other RTL language.

### How to fix

**Before (banned):**
```dart
Padding(
  padding: EdgeInsets.only(left: 16),
  child: Text(
    label,
    textAlign: TextAlign.left,
  ),
);
```

**After (correct):**
```dart
Padding(
  padding: EdgeInsetsDirectional.only(start: 16),
  child: Text(
    label,
    textAlign: TextAlign.start,
  ),
);
```

---

## Rule 6 — `no_hand_rolled_async_state_notifier`

### What it checks

Flags a `class X extends Notifier<T>` where `T` is a hand-rolled sealed union whose subclass names cover all three of:

- an Idle/Initial-shaped variant,
- a Loading/Submitting/Pending-shaped variant, and
- an Error/Failure-shaped variant.

`AsyncNotifier<T>` / `StreamNotifier<T>` subclasses are never flagged — they are the migration target this rule nudges towards, not a violation.

**Severity: INFO** — this is a migration-candidate nudge, not a hard error. Detection is purely syntactic (subclass name matching), so it cannot tell "~20 scattered `state = ...` assignments" (the actual SM-5 defect) apart from a notifier that deliberately keeps this public sealed-state shape while driving every transition through a single internal `AsyncValue.guard(...)` call — SM-5's own documented lighter-weight alternative. `SignInController` (fixed under AUD-account-14) is exactly that case and is *expected* to still trip this rule; it is flagged for human triage, not as a defect to silence.

### Why it exists

SM-5 (`docs/coding-standards.md`) requires async mutations to go through `AsyncValue.guard` rather than hand-managed try/catch `state = ...` assignments — a hand-rolled Idle/Loading/Error union on a plain `Notifier<T>` is the shape that pattern tends to produce (see AUD-account-14).

### How to fix

**Flagged (candidate for review — may already be an accepted guard-derived case):**
```dart
sealed class FooState {}
final class FooIdle extends FooState {}
final class FooSubmitting extends FooState {}
final class FooError extends FooState {
  FooError(this.message);
  final String message;
}

class FooController extends Notifier<FooState> {
  @override
  FooState build() => const FooIdle();
  // ... several `state = FooError(...)` / `state = FooIdle()` assignments
  // scattered across try/catch blocks.
}
```

**After (preferred — full migration):**
```dart
class FooController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> doThing() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _doThingBody());
  }
}
```

**Also acceptable (lighter-weight — keep the public shape, derive it via a single guard):** see `SignInController` in `lib/features/account/presentation/notifiers/sign_in_controller.dart` — the public `SignInIdle`/`SignInSubmitting`/`SignInError` union is retained, but every transition is derived from one `AsyncValue.guard(() => _bodyFn(...))` call per action rather than manual assignments spread across the method.

---

## Rule 7 — `no_unguarded_async_notifier_init`

### What it checks

Flags a Riverpod `Notifier`/`AsyncNotifier` (any of `Notifier`, `AsyncNotifier`, `StateNotifier`, `StreamNotifier`, their `AutoDispose`/`Family` variants, or `riverpod_generator`'s `class Foo extends _$Foo` codegen shape) whose `build()` method fires a private (`_`-prefixed) async method **fire-and-forget**:

- called as a bare statement (`_init();` / `this._init();`),
- never `await`ed, and
- never wrapped in `try`/`catch` at the call site,

where that private method's own body contains **zero `try` statements anywhere**.

**Severity: WARNING.** An exception anywhere in such a method is an unobserved Future rejection — `build()` already returned its placeholder state before the async work settles, and nothing ever resets `state` on failure, so the notifier can get stuck at that placeholder forever.

**Not flagged:**

- The call is `await`ed.
- The call is guarded by `try`/`catch` at the call site.
- The callee's body contains at least one `try` statement anywhere (this rule does not verify the guard is exhaustive — that's a human-triage question).
- The callee is public, or is not declared `async`.

Detection does not follow indirect call chains (`build()` calling `_setup()` which itself fires `_init()`) — only a direct fire-and-forget call from `build()` is flagged.

### Why it exists

AUD-account-11: `AuthStateNotifier.build()` fired `_init()` fire-and-forget with zero try/catch anywhere in `_init()`'s body, so a Firebase/DAO exception during startup silently stranded `sessionStatus` at `SessionStatus.initializing` forever — directly contradicting `auth_state.dart`'s own "Must not hang — see 19.6 startup hardening" doc comment. This rule is the Rule-0 checker for that pattern.

### How to fix

**Before (banned — the pre-fix AUD-account-11 shape):**
```dart
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() {
    _init();
    return const AuthState.initializing();
  }

  Future<void> _init() async {
    final refreshed = await authRepo.reloadCurrentUser(); // can throw
    // ... zero try/catch anywhere in this method
  }
}
```

**After (correct — wrap the fired method's body in try/catch and resolve `state` on every path):**
```dart
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() {
    _init();
    return const AuthState.initializing();
  }

  Future<void> _init() async {
    try {
      final refreshed = await authRepo.reloadCurrentUser();
      // ... state = AuthState.signedIn(...) / AuthState.signedOut()
    } on Exception catch (e, st) {
      AppLogger.instance.error(event: 'auth_state_init_failed', exception: e, stackTrace: st);
      state = const AuthState.signedOut();
    }
  }
}
```

---

## Configuration

All rules are enabled automatically. To disable one (discouraged):

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - no_curriculum_display_name_bypass: false   # discouraged
    - no_feature_cross_import: false             # discouraged
    - no_firebase_outside_core: false            # discouraged
    - no_raw_talker: false                       # discouraged
    - no_hardcoded_text_direction: false         # discouraged
    - no_hand_rolled_async_state_notifier: false # discouraged
    - no_unguarded_async_notifier_init: false    # discouraged
```
