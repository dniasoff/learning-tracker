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

Fails on any `import 'package:learning_tracker/features/X/…'` that appears inside a file under `features/Y/` (a different feature), **unless** the imported path is exactly `X.dart` — the feature's own barrel file (e.g. `features/tracks/tracks.dart`).

### Why it exists

Following NFR2 / NFR17, features must be independently deployable and testable. Direct deep imports between features create hidden coupling that:

- Breaks feature isolation and makes incremental builds unreliable.
- Makes it impossible to reason about a feature's public API surface.

The single allowed crossing point is `features/<feature>/<feature>.dart`, which is the deliberate, documented public surface.

### How to fix

**Before (banned):**
```dart
// Inside features/dashboard/...
import 'package:learning_tracker/features/learning/data/repositories/progress_repository.dart';
```

**After (correct):**
```dart
// Use the feature's public barrel surface:
import 'package:learning_tracker/features/learning/learning.dart';
// Then read the provider (or type) exported from the barrel rather than importing internals directly.
```

If the type you need is not yet exposed through `learning.dart`, add it to that file rather than bypassing the boundary.

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

## Rule 8 — `no_color_literal_outside_theme`

### What it checks

Fails on any direct `Color(0xFF…)` / `Color(0x…)` hex-literal constructor call in a file that is **not** under `lib/core/theme/`.

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

### Why it exists

Colour definitions belong in `lib/core/theme/app_colors.dart` or `lib/core/theme/app_theme.dart` (W5.14/W5.15). Feature and widget code must reference the named constants from those files instead of embedding hex literals, so theming stays consistent and future dark-mode/brand work has one place to change a colour.

### How to fix

**Before (banned):**
```dart
// In lib/features/dashboard/presentation/widgets/foo.dart
color: const Color(0xFF1A57C2),
```

**After (correct):**
```dart
import 'package:learning_tracker/core/theme/app_theme.dart';
color: AppTheme.brandBlueBright,

// or
import 'package:learning_tracker/core/theme/app_colors.dart';
color: AppColors.blueMedium,
```

---

## Rule 9 — `no_dead_error_field`

### What it checks

Flags a Riverpod Notifier (including `riverpod_generator`'s `class Foo extends _$Foo` codegen shape) whose state carries a `loading`/`error`-shaped pair of fields — evidenced by a `copyWith(loading: ..., error: ..., ...)` call somewhere in the file — where the file contains **zero** `copyWith(...)` call that sets `error:` to anything other than the literal `null`.

### Why it exists

AUD-gamification-10: if every `copyWith(error: ...)` call in a file only ever resets the field to `null`, the field is declared-but-dead — any exception not already special-cased elsewhere becomes a silent, invisible failure. The user taps an action, nothing happens, and no code path ever surfaces why (`RewardConfigController` before the fix never set `error` to a failure value from any of its four async mutation methods).

### How to fix

**Before (banned — error field never driven by a failure):**
```dart
Future<void> save() async {
  state = state.copyWith(loading: true, error: null);
  try {
    await _repo.save(config);
    state = state.copyWith(loading: false, error: null);
  } catch (_) {
    state = state.copyWith(loading: false, error: null); // dead field
  }
}
```

**After (correct — the failure path surfaces a real error):**
```dart
Future<void> save() async {
  state = state.copyWith(loading: true, error: null);
  try {
    await _repo.save(config);
    state = state.copyWith(loading: false, error: null);
  } catch (e) {
    state = state.copyWith(loading: false, error: e.toString());
  }
}
```

---

## Rule 10 — `no_eager_list_in_non_lazy_scroll_container`

### What it checks

Flags an eagerly-expanded widget list — `for (final x in y) Widget(...)`, `…iterable.map((x) => Widget(...))` / `.map(...).toList()`, or `List.generate(count, (i) => Widget(...))` — fed directly into the `children:` of a non-lazy container:

- `ListView(children: […])` — the plain/default constructor, not `.builder`/`.separated`/`.custom`, which are already lazy;
- a `Column(children: […])` wrapped in a `SingleChildScrollView`; or
- an `ExpansionTile(children: […])`.

Known-bounded sources are not flagged: `SomeEnum.values`, an iterable capped via `.take(n)`, a list/set literal, or a `List.generate(n, ...)` whose count is a literal int or a `.length` read off one of those bounded sources.

### Why it exists

PF-2: an unbounded, provider-driven collection fed into one of these shapes is fully realized in a single frame regardless of viewport (AUD-tutoring-08, AUD-scheduler-01, AUD-settings-08).

### How to fix

**Before (banned):**
```dart
ListView(
  children: [for (final grant in incomingTutorGrants) GrantTile(grant)],
)
```

**After (correct):**
```dart
ListView.builder(
  itemCount: incomingTutorGrants.length,
  itemBuilder: (context, i) => GrantTile(incomingTutorGrants[i]),
)
```

---

## Rule 11 — `no_e_to_string_in_ui`

### What it checks

Warns when a caught exception (identifiers named `e`, `err`, `ex`, `error`, `exception`) is converted to a string via `.toString()` inside a `presentation/` file.

### Why it exists

Propagating a raw exception message to the UI leaks internal implementation details and untranslated text to users. Presentation code should display a localised, user-friendly message instead (W7.18/W7.20).

### How to fix

**Before (banned):**
```dart
Text(e.toString())
```

**After (correct):**
```dart
Text(l10n.errorGeneric)
AppErrorView(message: l10n.errorUnknown)
```

---

## Rule 12 — `no_hardcoded_domain_term`

### What it checks

Flags a Torah domain-term English literal hardcoded in a user-facing string in presentation code. The curated term list is deliberately conservative — ambiguous common English words (Review, Page, Seder, Daf, Amud, Perek, Mishnah, Siyum) are excluded to avoid false positives.

### Why it exists

The app must render Torah domain terms through the shared label library (`domainTermLabels` / `CurriculumLabels` / `CurriculumLabelRenderer`) or via l10n so they honour the Hebrew-terms contract and the Ashkenazi/Sephardi nusach setting (`docs/hebrew-terms.md`). A bare English literal bypasses that contract.

### How to fix

**Before (banned):**
```dart
Text('Mishnayos done!')
```

**After (correct):**
```dart
Text(domainTermLabels(ref).mishnayos)
Text(l10n.mishnayosDone)
```

---

## Rule 13 — `no_hardcoded_error_widget_string`

### What it checks

Flags any hardcoded English literal in a user-facing string slot inside `AppErrorView`, `ErrorDisplay`, or `PinEntryWidget` specifically — deliberately scoped to exactly those three files, not all of `lib/core/widgets/`.

### Why it exists

AUD-core-widgets-01 (AX-2/EH-5): these are shared, widely reused widgets in a Hebrew-first, EN+HE app (`AppErrorView` alone is used from 16+ screens; `PinEntryWidget` gates parent-mode PIN entry). A hardcoded English literal in any of their string slots ships untranslated text into an otherwise-Hebrew UI.

### How to fix

**Before (banned):**
```dart
Text('Retry')
_ErrorConfig(title: 'Something went wrong', ...)
```

**After (correct):**
```dart
Text(l10n.actionRetry)
_ErrorConfig(title: l10n.appErrorViewGenericTitle, subtitle: l10n.appErrorViewGenericBody, ...)
```

---

## Rule 14 — `no_log_less_catch`

### What it checks

Flags any `catch` clause under `lib/` whose body contains no call to `AppLogger.instance.<method>(...)` and no `rethrow` — regardless of whether the body is literally empty, comment-only, or does something else (e.g. a bare `setState`/`return`) without ever recording why the exception was swallowed. Files outside `lib/` and generated files (`.g.dart`/`.freezed.dart`/`.gr.dart`) are excluded.

### Why it exists

AUD-onboarding-11, EH-3: "Never swallow an error: every `catch` rethrows, converts, or logs through `AppLogger`." The analyzer's built-in `empty_catches` lint only flags a literally-empty `{}` body, and Dart's own style guidance silences that exact lint by adding a comment inside the block — precisely the shape that slips past it undetected (e.g. the pre-fix `catch (_) { // comment }`).

### How to fix

**Before (banned):**
```dart
try {
  await _loadPreExistingCompletions();
} catch (_) {
  // ignore
}
```

**After (correct):**
```dart
try {
  await _loadPreExistingCompletions();
} catch (e, st) {
  AppLogger.instance.error(event: 'load_completions_failed', exception: e, stackTrace: st);
}
```

---

## Rule 15 — `no_onboarding_raw_string_literal`

### What it checks

Flags a raw (non-empty) string literal — or a string interpolation whose literal text chunks are non-empty — passed directly as a user-facing text argument under `lib/features/onboarding/presentation/**`: a positional argument to `Text(`/`SnackBar(`/`Tooltip(`, or the value of a UI-facing named argument (`errorText:`, `hintText:`, `labelText:`, `label:`, `title:`, `text:`, `message:`, `content:`, `semanticLabel:`, `tooltip:`) on any constructor/method call.

### Why it exists

AUD-onboarding-04/AX-2: the onboarding flow is this app's Hebrew-locale first-impression surface. A bare English literal here ships untranslated text into the Hebrew build. This is a directory-scoped follow-on to `no_hardcoded_domain_term`, not a general-purpose AX-2 literals checker for the whole app (that remains Pending per `docs/coding-standards.md`).

### How to fix

**Before (banned):**
```dart
Text('Set a 4-digit PIN')
AppBarTitle(text: 'All Set!')
TextFormField(decoration: InputDecoration(errorText: 'PINs do not match'))
```

**After (correct):**
```dart
Text(l10n.onboardingSetPinTitle)
AppBarTitle(text: l10n.onboardingAllSetTitle)
TextFormField(decoration: InputDecoration(errorText: l10n.pinMismatch))
```

---

## Rule 16 — `no_raw_logevent`

### What it checks

Prevents direct calls to `logEvent(name, …)` in any file that is **not** under `lib/core/analytics/`.

### Why it exists

All analytics events must be dispatched through the typed helper methods on `AnalyticsService` (e.g. `analyticsService.logTrackAdded(...)`) rather than calling `logEvent` directly, so event names stay defined as constants, parameter schemas are validated at the call site, and tests can verify analytics through the typed surface (W7.21).

### How to fix

**Before (banned):**
```dart
analyticsService.logEvent('custom_event', parameters: {'key': 'value'});
```

**After (correct):**
```dart
// Add a typed helper to AnalyticsService and call that instead.
analyticsService.logCustomEvent(key: 'value');
```

---

## Rule 17 — `no_ref_after_await_without_mounted_check`

### What it checks

Flags a `ref.read(...)`/`ref.watch(...)`/`ref.invalidate(...)`/`ref.refresh(...)`/`ref.listen(...)` call, or an assignment to a bare `state` variable, that runs after an earlier `await` in the same async method/closure with no `if (!ref.mounted) return;`-shaped guard in between.

### Why it exists

SM-4/AUD-sync-04: Riverpod 3 throws `UnmountedRefException` when a disposed `Ref` is touched. An autoDispose provider can be torn down mid-`await` (e.g. a profile switch or sign-out while a network round trip is in flight), and the very next `ref.read`/`state =` after that `await` crashes.

### How to fix

**Before (banned):**
```dart
Future<void> onEnqueueDrain() async {
  await _drain();
  state = state.copyWith(draining: false); // may run after disposal
}
```

**After (correct):**
```dart
Future<void> onEnqueueDrain() async {
  await _drain();
  if (!ref.mounted) return;
  state = state.copyWith(draining: false);
}
```

---

## Rule 18 — `no_shrink_wrap_reorderable_list`

### What it checks

Flags the plain (non-`.builder`) `ReorderableListView(...)` constructor combined with `shrinkWrap: true`, anywhere under `lib/features/**`.

### Why it exists

AUD-tracks-05 (PF-2): `shrinkWrap: true` forces every row to be realized up front regardless of viewport, no matter how many items the list holds — and the plain `ReorderableListView(children: [...])` constructor also expands its full item list eagerly before the widget is even built. Switching to `.builder` alone does not fix this: `shrinkWrap: true` forces eager realization of a `.builder` list too. A Mishna Berurah track has 697 Simanim, all realized in one frame by a single tap of "Reorder Learning Order" pre-fix.

### How to fix

**Before (banned):**
```dart
ReorderableListView(
  shrinkWrap: true,
  children: [for (final s in simanim) SimanTile(s)],
  onReorder: _onReorder,
)
```

**After (correct — host as a lazy sliver, no shrinkWrap):**
```dart
CustomScrollView(
  slivers: [
    SliverReorderableList(
      itemCount: simanim.length,
      itemBuilder: (context, i) => SimanTile(simanim[i], key: ValueKey(simanim[i].id)),
      onReorder: _onReorder,
    ),
  ],
)
```

---

## Rule 19 — `no_side_effect_in_provider_build`

### What it checks

Flags two side-effect shapes found directly (synchronously) inside the `create` callback passed to a legacy `Provider`/`StreamProvider`/`FutureProvider` constructor (including `.autoDispose`/`.family`):

1. A chained-property assignment — `a.b.c = value;` where the assignment target is itself a member-access chain, not a bare local/`ref` identifier (e.g. reaching through a getter chain to mutate a field owned by some other object).
2. A call to `unawaited(...)`.

`@riverpod`-codegen `Notifier`/`AsyncNotifier` classes are not flagged — those are covered by `no_unguarded_async_notifier_init` for their own build-time hazard shape.

### Why it exists

AUD-sync-08 (SM-2 backstop): SM-2 requires provider `build`/`create` bodies to stay pure — "no writes, no request-firing, no side effects." `build`/`create` can rerun for reasons unrelated to a meaningful state change (a sibling watched provider rebuilding, hot-reload, provider disposal/recreation, test overrides), so a synchronous field mutation or fire-and-forget call there re-fires on every such rerun with no way to gate it.

### How to fix

**Before (banned — the pre-fix `outboxSyncWriteFacadeProvider` shape):**
```dart
final outboxSyncWriteFacadeProvider = Provider<OutboxSyncWriteFacade?>((ref) {
  final facade = OutboxSyncWriteFacade(...);
  database.pointsBalanceDao.syncSink = facade;
  unawaited(database.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(profileId));
  return facade;
});
```

**After (correct — move the side effects behind an explicit, triggered action):**
```dart
final outboxSyncWriteFacadeProvider = Provider<OutboxSyncWriteFacade?>((ref) {
  return OutboxSyncWriteFacade(...);
});

// Wire the sink and the re-enqueue drain from an explicit lifecycle hook
// (e.g. app startup / sign-in flow), not from the provider's own build.
```

---

## Rule 20 — `no_unguarded_state_touch_after_await`

### What it checks

Flags a `state = ...` assignment or a bare `setState(...)` call that appears after an `await` in the same method body's statement sequence (including inside `try`/`catch` blocks), with no intervening `if (!mounted) return;` / `if (!ref.mounted) return;` (or an `if (mounted) { ... }` / `if (ref.mounted) { ... }` wrapping guard) in between. Scoped to Riverpod Notifier-like classes and `State`/`ConsumerState` subclasses whose method is `async`.

### Why it exists

SM-4/AUD-onboarding-01: an autoDispose provider or a widget can be torn down while an `await` is still in flight (backgrounding the app, popping the route mid-write). Resuming without a guard throws `UnmountedRefException` (Riverpod 3) or Flutter's `setState() called after dispose()`.

### How to fix

**Before (banned):**
```dart
Future<void> _createProfile() async {
  final profile = await _repo.create(name);
  setState(() => _profile = profile); // may run after dispose
}
```

**After (correct):**
```dart
Future<void> _createProfile() async {
  final profile = await _repo.create(name);
  if (!mounted) return;
  setState(() => _profile = profile);
}
```

---

## Configuration

All rules are enabled automatically. To disable one (discouraged):

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - no_curriculum_display_name_bypass: false      # discouraged
    - no_feature_cross_import: false                # discouraged
    - no_firebase_outside_core: false                # discouraged
    - no_raw_talker: false                          # discouraged
    - no_hardcoded_text_direction: false            # discouraged
    - no_hand_rolled_async_state_notifier: false    # discouraged
    - no_unguarded_async_notifier_init: false       # discouraged
    - no_color_literal_outside_theme: false         # discouraged
    - no_dead_error_field: false                    # discouraged
    - no_eager_list_in_non_lazy_scroll_container: false # discouraged
    - no_e_to_string_in_ui: false                   # discouraged
    - no_hardcoded_domain_term: false                # discouraged
    - no_hardcoded_error_widget_string: false       # discouraged
    - no_log_less_catch: false                      # discouraged
    - no_onboarding_raw_string_literal: false       # discouraged
    - no_raw_logevent: false                        # discouraged
    - no_ref_after_await_without_mounted_check: false # discouraged
    - no_shrink_wrap_reorderable_list: false        # discouraged
    - no_side_effect_in_provider_build: false       # discouraged
    - no_unguarded_state_touch_after_await: false   # discouraged
```
