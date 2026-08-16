# Bug Fix Prompt — 2026-05-15

Paste this into a new Claude Code session to execute the fixes.

---

Fix the bugs documented in `docs/bug-reports-2026-05-15.md` following the plan in `docs/bug-fix-plan-2026-05-15.md`. Work through them in the order listed in the plan (BUG-4 → BUG-3 → BUG-2 → BUG-5 → BUG-6 → BUG-1).

For each bug:
1. Read the relevant file(s) called out in the plan before editing.
2. Make the minimal change needed — no refactoring beyond what the fix requires.
3. After each fix, confirm what changed and what to verify manually on device.

**Key files per bug:**
- BUG-4: `learning_tracker/lib/features/track_setup/presentation/steps/step_study_days.dart` lines 79–84, 129–135
- BUG-3: `learning_tracker/lib/features/track_setup/presentation/steps/step_chazara.dart` around line 130
- BUG-2: `learning_tracker/lib/features/track_setup/presentation/steps/step_goal.dart` subtitle text
- BUG-5: `learning_tracker/lib/features/track_setup/presentation/screens/track_detail_screen.dart` `_buildHeaderCard()` (~line 264)
- BUG-6: `learning_tracker/lib/features/sync/presentation/providers/sync_providers.dart` line 71 (`isCloudBorn` gate); `learning_tracker/lib/features/settings/presentation/utils/send_logs_service.dart` line 40 (wrong toast message)
- BUG-1: Needs diagnostic logs first — ask the user to reproduce the bug and tap Settings → Send Diagnostic Logs before investigating `add_track_flow_screen.dart` lines 567–670

Stop before BUG-1 and ask for the logs.
