# Bug Fix Plan — 2026-05-15

Source: `docs/bug-reports-2026-05-15.md`

---

## BUG-2 — Remove misleading "skip for now" subtitle (easy)

**File:** `learning_tracker/lib/features/track_setup/presentation/steps/step_goal.dart`  
**Fix:** Find the subtitle string/l10n key for Step 6 and remove the "or skip for now" clause.  
**Verify:** Run through track setup to Step 6 — subtitle should no longer mention skipping.

---

## BUG-3 — Remove redundant "Skip (no review)" button (easy)

**File:** `learning_tracker/lib/features/track_setup/presentation/steps/step_chazara.dart`  
**Fix:** Remove the "Skip (no review)" button (rendered near line 130 via `_skip()`) and its associated method. "Learn Only" card already covers this case.  
**Verify:** Step 5 shows four preset cards + Custom Cycle, no skip button.

---

## BUG-4 — Remove Shabbos/Friday labels and fix Friday colour (easy)

**File:** `learning_tracker/lib/features/track_setup/presentation/steps/step_study_days.dart`  
**Fixes:**
1. Lines 129–135: In `_daySubtitle()`, remove the `5 => 'EREV SHABBOS'` and `6 => 'DAY OF REST'` cases (return `''` for all days, or delete the method if nothing else uses it).
2. Lines 79–84: Remove Friday-specific pink/burgundy colour overrides so its avatar matches the other days (grey).  
**Verify:** Study Days screen — all day rows look identical in colour; no subtitles under Friday or Shabbos.

---

## BUG-5 — Show track configuration on track detail screen (medium)

**File:** `learning_tracker/lib/features/track_setup/presentation/screens/track_detail_screen.dart`  
**Fix:** Add a "Configuration" section to `_buildHeaderCard()` (after the progress bars, ~line 264) that surfaces:
- Track type (personal / community track name)
- Pace or deadline (value + unit, or deadline date)
- Items remaining (total − completed)
- Estimated finish date  

These values should already be available on the track entity; wire them into the UI.  
**Verify:** Open any track's detail screen — the config summary is visible without going back into setup.

---

## BUG-6 (HIGH) — Sync shows "not signed in" despite authenticated session (medium)

**Files:**
- `learning_tracker/lib/features/sync/presentation/providers/sync_providers.dart` line 71
- `learning_tracker/lib/features/settings/presentation/utils/send_logs_service.dart` line 40

**Investigation:**  
Line 71 of `sync_providers.dart`: `if (!authState.isCloudBorn) return null;`  
The user is authenticated but `isCloudBorn` is `false`, so `syncEngineProvider` returns `null`, causing the "LOCAL ONLY" banner. The toast at `send_logs_service.dart:40` then incorrectly says "not signed in" when the real reason is tier/cloud-born status.

**Fix:**
1. Determine why `isCloudBorn` is false for a signed-in user (likely the profile was created locally before sign-in, or the flag isn't being set on sign-in).
2. Fix the `isCloudBorn` flag logic so it is set correctly when a user signs in.
3. Update the toast message at `send_logs_service.dart:40` to accurately reflect the real reason if sync is still unavailable (e.g. "Sync unavailable — account not linked to cloud").  
**Verify:** Sign in → Settings → Backup & Sync should show active sync, not "LOCAL ONLY". Diagnostic logs button should not show "not signed in" toast.

---

## BUG-1 (HIGH) — Recreating track + marking prior learning yields nothing scheduled (hard)

**Files:**
- `learning_tracker/lib/features/track_setup/presentation/screens/add_track_flow_screen.dart` lines 515–524, 567–670
- Scheduling layer (TBD from logs)

**Investigation:**  
`_applySelfPacedPriorCompletions()` (lines 641–670) bulk-marks stage IDs as complete and then calls `onTrackChanged()`. The question is whether the scheduler runs *after* prior completions are applied and correctly computes what remains to schedule. Possible causes:
- Scheduler runs before `_applySelfPacedPriorCompletions()` completes (race/async ordering).
- All items are marked complete (prior learning selects everything), leaving nothing to schedule.
- A deleted track leaves orphaned data that confuses the new track's scheduler.

**Fix:** Get diagnostic logs from the device (Settings → Send Diagnostic Logs) immediately after reproducing Bug 1. Trace through `_finishFlow()` → `createTrack()` → `_applySelfPacedPriorCompletions()` → scheduling trigger to find where the pipeline breaks.  
**Verify:** Delete track → recreate → mark partial prior learning → complete setup → Due today > 0.

---

## Fix Order

1. BUG-4 (trivial — pure UI cleanup)
2. BUG-3 (trivial — remove one button)
3. BUG-2 (trivial — copy change)
4. BUG-5 (medium — read-only UI addition)
5. BUG-6 (medium — needs auth/sync investigation)
6. BUG-1 (hard — needs logs first)
