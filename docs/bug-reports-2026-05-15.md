# Bug Reports — 2026-05-15

Reported by Yisroel Meir during manual testing session.

---

## BUG-1 (HIGH) — Recreating a track after permanent delete yields nothing to learn

**Steps to reproduce:**
1. Delete a track permanently.
2. Recreate the same track.
3. On the prior-learning step, mark prior learning.
4. Complete setup.

**Expected:** Items are scheduled and appear under "Due today".  
**Actual:** Due today = 0, Lifetime Progress = 0.00% — nothing is scheduled.

**Notes:** Likely a scheduling/prior-learning interaction bug. Logs from the prior-learning step would help diagnose.

---

## BUG-2 — Misleading "skip for now" subtitle on pace/deadline step

**Screen:** Track setup Step 6 — "What's your pace or deadline?"

**Issue:** Subtitle reads "Set a goal, or skip for now." but there is no skip button or action. Copy is misleading.

**Fix:** Remove "or skip for now" from the subtitle.

---

## BUG-3 — Redundant "Skip (no review)" button on review schedule step

**Screen:** Track setup Step 5 — "How do you want to review?"

**Issue:** A "Skip (no review)" button appears below the options, but the "Learn Only" card already covers the no-review case. The button is redundant and confusing.

**Fix:** Remove the "Skip (no review)" button.

---

## BUG-4 — Unnecessary labels and wrong colour on Study Days screen

**Screen:** Track setup Step 4 — "Study Days"

**Issues:**
1. Friday shows "EREV SHABBOS" subtitle — adds no value, remove it.
2. Shabbos shows "DAY OF REST" subtitle — adds no value, remove it.
3. Friday's avatar circle is pink/red instead of the same grey as the other days.

**Fix:** Remove both subtitles; make Friday's avatar colour consistent with the rest.

---

## BUG-5 — Track detail screen missing configuration summary

**Screen:** Track detail / manage track screen (משניות → Personal Track)

**Issue:** Screen only shows completion %, lifetime learning %, and three actions (Mark Content Done, Reorder Content, Delete Track). User cannot see what they configured during setup.

**Requested information to surface:**
- Track type (personal / community — and if community, which one)
- Pace or deadline setting (value + unit)
- Items remaining
- Estimated finish date

---

## BUG-6 (HIGH) — Sync shows "not signed in" despite user being signed in

**Screen:** Settings

**Issue:** User is authenticated (Yisroel Meir, dniasoff@gmail.com, SELF-LEARNER role visible in Settings). Despite this:
- Backup & Sync banner reads "Your learning progress is currently LOCAL ONLY. Upgrade to sync across all devices."
- A toast appears: "Sync not available — not signed in."

**Expected:** Sync is active and recognised for the authenticated user.  
**Actual:** SyncEngine / auth state is not propagating — app behaves as if no user is signed in.
