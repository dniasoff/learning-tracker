# DNI-339 — 25.18: typed auto_route + PinScope-parameterized guard

**Status:** review
**Linear:** [DNI-339](https://linear.app/orvexai/issue/DNI-339)

> ℹ️ **Historical implementation record.** This story is complete (per `docs/linear-status.md`, Epic 25 — all 22 stories Done, 2026-05-14). The `ParentPinGuard` / `TutorPinGuard` classes named in the Story statement below are what this change *replaced*; neither exists in code anymore. The single typed guard they were consolidated into is `PinGuard(PinScope.{parent,tutor}(profileId))` in `lib/core/navigation/guards/pin_guard.dart`. The class names are kept here only to document what was removed — do not use them as current API reference.

## Story

As a developer adding a new gated route, I want typed auto_route generation and one composable `PinGuard(PinScope.{parent(profileId), tutor(profileId)})` rather than separate `ParentPinGuard` / `TutorPinGuard`, so that guard duplication is removed and adding a new PIN-gated route is one line.

## Acceptance Criteria

1. One `PinGuard` class takes a `PinScope` value and dispatches verification to `PinService`.
2. Route declarations parameterize the guard via `PinGuard(PinScope.parent(profileId))` — instantiated once in `router_provider.dart` with a `getScope` closure; the same instance is wired into every gated route.
3. The count of distinct guards in `core/navigation/` is audited against the architecture-doc claim (5 = `AuthGuard`, `RestoreGuard`, `ProfileGuard`, `ChildModeGuard`, `PinGuard`).
4. Route declarations are fully typed — no `pushNamed` / `navigateNamed` / string-arg `context.go` / `context.push` in `lib/`.

## Tasks / Subtasks

- [x] Add sealed `PinScope` (freezed) at `lib/core/navigation/pin_scope.dart` with `parent(profileId)` and `tutor(profileId)` variants.
- [x] Extend `PinService` with `setTutorPin` / `verifyTutorPin` / `hasTutorPin` / `clearTutorPin` / `getTutorLockoutRemainingMinutes` (independent storage namespace from parent PINs).
- [x] Rewrite `lib/core/navigation/guards/pin_guard.dart` from an unused abstract base into the concrete guard. Takes `getScope: PinScope? Function()` and dispatches to scope-appropriate `PinService` methods. Keeps `lock()` / `markAuthenticated()` / `markScopeAuthenticated()` + session cache.
- [x] Delete `lib/core/navigation/guards/parent_pin_guard.dart` and the matching test.
- [x] Rename `AppRouter.parentPinGuard` → `AppRouter.pinGuard` and update all four guard-list references.
- [x] Rewire `router_provider.dart` to construct `PinGuard` with a `getScope` closure.
- [x] Update call sites: `settings_screen.dart`, `account_actions.dart` (x2), `pin_entry_screen.dart`, `manual_completion_use_case.dart` doc-comment, `test/core/navigation/app_shell_test.dart`, `test/story_acceptance/epic_01_foundation_test.dart`.
- [x] Update `docs/architecture.md` — "7 guards" claim corrected to "5 guards" with PinGuard parameterized by PinScope.
- [x] Add `test/story_acceptance/epic_25_story_18_pin_guard_test.dart` and `make test-story-25.18` target.

## File List

**Added:**

- `lib/core/navigation/pin_scope.dart` (+ generated `pin_scope.freezed.dart`)
- `test/story_acceptance/epic_25_story_18_pin_guard_test.dart`
- `docs/stories/implementation/DNI-339-typed-auto-route-pinscope-guard.md`

**Modified:**

- `lib/core/navigation/app_router.dart` (+ regenerated `app_router.gr.dart`)
- `lib/core/navigation/router_provider.dart`
- `lib/core/navigation/guards/pin_guard.dart` (full rewrite — concrete, scope-parameterized)
- `lib/core/services/pin_service.dart` (tutor namespace methods)
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/settings/presentation/utils/account_actions.dart`
- `lib/features/parent_mode/presentation/screens/pin_entry_screen.dart`
- `lib/features/learning/domain/use_cases/manual_completion_use_case.dart`
- `test/core/navigation/app_shell_test.dart`
- `test/story_acceptance/epic_01_foundation_test.dart`
- `docs/architecture.md`
- `Makefile`

**Deleted:**

- `lib/core/navigation/guards/parent_pin_guard.dart`
- `test/core/navigation/guards/parent_pin_guard_test.dart`

## Notes

- Schema is unchanged (still v13).
- No new pub dependencies.
- `flutter_secure_storage` keys for tutor scope are namespaced `profile_{id}_tutor_pin_hash` etc. so parent and tutor PINs cannot collide.
- Parent and tutor sessions are *independent*: authenticating one does not authorize the other, even for the same `profileId`. Verified by the `parent session cache does NOT authorize tutor scope` test.
