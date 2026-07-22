---
title: "Run-10 — API 29 Learn-tab OOM baseline (device emulator-5556)"
purpose: "Settle run-8's P0 (\"opening Learn OOM-kills the app on API 29\") with guest-side-attributed evidence, per the reassurance campaign's R9 crash-attribution methodology."
date: 2026-07-22
device: emulator-5556 (AVD lt_api29_pixel3, Android 10 / API 29, 512m heap)
app: com.jcom.torah.learning_tracker, versionName 1.0.66
---

# Run-10 — API 29 Learn-tab OOM baseline

## Verdict on run-8's P0

# **REFUTED**

Across 5 separate app launches and repeated, deliberate stress of the exact code
path named in the P0 (`contentIndex` in
`learning_tracker/lib/core/content/content_index.dart:111-116`, reached via the
Learn tab, the reader, the content hierarchy, and search), **guest-side memory
never came close to the device's heap limit, and `crash_attribution.sh` came
back clean on every single check — zero exceptions.**

- Device heap limit: `dalvik.vm.heapsize=512m` (`dalvik.vm.heapgrowthlimit` is
  unset on this AVD, so 512 MB is the effective ceiling).
- Observed Native Heap (the pool that would hold the ~70k materialized
  `ContentItem` objects) ranged **~47 MB (idle/backgrounded) to ~90 MB (peak,
  Learn tab + reader + hierarchy + search all opened in the same session)** —
  about **18% of the limit at its worst**, with tens of MB of headroom to
  spare even under compounding load.
- Java/Dalvik heap stayed at **3–7 MB** throughout, negligible against the
  512 MB ceiling.
- `tool/device_e2e/crash_attribution.sh check` was run after every scenario
  (Learn-tab open, reader open, reader paging, 4-level hierarchy drill,
  search x3, background/foreground x2, full app exit+relaunch x2) — **every
  single call returned `guest clean`**. No `FATAL EXCEPTION`, `am_crash`,
  `ANR in`, or `lmkd/lowmemorykiller` kill of `com.jcom.torah.learning_tracker`
  ever appeared in guest logcat.

The code path itself is confirmed unchanged and real — `content_index.dart`
still force-materializes all 9 curricula into a `keepAlive` provider, and the
Dashboard's own "3 / 70,033 sections — 9 curricula" stat proves the fixture
has the full-size dataset loaded. It just does not push this device over its
memory ceiling in practice. This is a clean, reproducible **REFUTE**, not an
"couldn't confirm."

## Memory table

Native Heap in KB (`dumpsys meminfo` "Native Heap / Private" column, PSS
total shown), Dalvik Heap in KB, sampled across the whole session. All rows
passed `crash_attribution.sh check` (guest clean) immediately after.

| Stage | Native Heap (KB) | Dalvik Heap (KB) | Notes |
|---|--:|--:|---|
| Launch 1, fresh (before any nav) | 61,747 | 7,284 | baseline |
| Launch 1, dashboard settled | 60,704 | 3,412 | pre-Learn-tap |
| *(Launch 1 interrupted by ENVIRONMENT VM crash — see below)* | | | |
| Launch 2, fresh dashboard | 60,203 | 4,066 | pre-Learn-tap |
| Learn tab tapped, t+1s…t+8s | 58,838 → 60,262 → 56,964 → 63,669 → 72,580 → **75,843** (plateau) | 4,066–4,082 | monotonic-ish climb, plateaus ~76 MB |
| Reader opened (Berachot 1:1, Hebrew text) | 76,813 | 4,094 | |
| Reader paged x5 | 81,673 | 4,198 | |
| Hierarchy: Mishnayos → Zeraim | 71,421 | 4,090 | |
| Hierarchy: → Berachot | 67,417 | 4,074 | |
| Hierarchy: → chapter (4 levels deep) | 69,693 | 4,082 | |
| Search "shabbat" (results) | 87,326 | 4,204 | **peak region** |
| Search "yom" appended | 87,342 | 4,426 | |
| Backgrounded (HOME) | 87,342 | 4,426 | retained, no trim yet |
| Foregrounded again | 79,467 | 4,414 | small GC trim on resume |
| Round 2: hierarchy re-entry | 77,299 | 4,262 | |
| Full app exit to home screen + relaunch (same pid) | 47,675 → 55,831 | 4,322 → 5,882 | biggest trim of the session |
| Launch 3 (after 2nd ENVIRONMENT restart), fresh dashboard | 62,996 | 6,319 | |
| Launch 4 (after 3rd/4th ENVIRONMENT restart), fresh dashboard | 67,233 | 3,530 | |

Absolute peak observed anywhere in the session: **~90 MB Native Heap, ~4-6 MB
Dalvik Heap** — against a 512 MB limit.

## Other findings on these screens

- **Reader chevron debounce (APP, minor, not a crash):** tapping the
  next-item chevron 5x at ~1.2s intervals only advanced the reader by 1
  mishnah, not 5. Likely input debounce/animation-lock during route
  transition. Not memory-related, not a crash, but worth a follow-up look at
  `text_display_screen.dart`'s next/prev handler if snappier paging is
  wanted.
- **Search requires transliteration, silently (APP, cosmetic):** `adb shell
  input text` cannot send Hebrew (Android `Input` command throws
  `NullPointerException` on non-ASCII), so this was tested with ASCII
  transliterations ("shabbat", "yom") instead of Hebrew — this is a test-tool
  limitation, not an app bug. The search itself worked correctly against
  transliterated Latin input, matched real content, and cleanly reported "No
  results for ..." with a helpful hint ("Try searching by the Hebrew name")
  for an unmatched query. No defect.
- **Duplicate-AppBar transition artifact (cosmetic, unconfirmed):** two
  screenshots (`run10_08_reader2.png`, `run10_25_talmud2.png`) caught what
  looks like two stacked "LearnQA" app bars mid-transition. Likely just a
  screenshot caught mid-route-animation (Hero/slide transition overlap), not
  reproduced as a persisted visual bug on any subsequent frame. Flagging only
  because it's visible in the artifacts; did not chase further given time
  spent on the environment issue below.

## ENVIRONMENT: emulator-5556's QEMU process died 4 times during this run — separate from the app, but worth escalating on its own

This is the most important secondary finding and the reason the session took
longer than expected. Per the campaign's own established rule
(`docs/test-artifacts/reassurance-log.md`, R9 section): **"Host
emulator-process death alone = ENVIRONMENT."** Applying that rule as written:

Over the course of this run, the **host** `qemu-system-x86_64 ... -port 5556`
process fully disappeared 4 separate times (confirmed via `ps` showing no
matching process and `adb devices` dropping the serial entirely), each
requiring a manual cold-boot relaunch (`setsid emulator -avd lt_api29_pixel3
-port 5556 ... & disown`, per the documented recovery recipe, plus clearing
the stale `multiinstance.lock`/`hardware-qemu.ini.lock`). Every disappearance
happened within seconds of me actively driving the UI (Learn tab / hierarchy
scrolling), never while idle.

What I checked, to attribute this correctly instead of guessing:
- **Guest logcat:** clean before every single one of these incidents — no
  app-level signal at all, consistent with the process dying at the host/VM
  level rather than anything happening inside the guest.
- **Host dmesg (`sudo dmesg -T`, passwordless sudo available):** each
  incident window shows a burst of `RenderThread[<pid>]: segfault at
  <addr> ip <addr>` lines — **the exact same instruction pointer offset every
  time**, which is the fleet-wide SwiftShader software-renderer bug already
  documented in `crash_attribution.sh`'s header comment and the reassurance
  log's R9 entry ("host-side RenderThread segfault storms... 199 in a single
  run-8 session"). I could **not** conclusively map the segfaulting thread
  PIDs to the port-5556 process specifically in every case — in the last
  incident the segfaulting PIDs were numerically inconsistent with the
  freshly-started 5556 instance, so some of this noise may belong to one of
  the other 5 concurrently-running emulators sharing the same host GPU
  driver, not to 5556 itself.
- **Host memory:** never under pressure — 36–82 GB free throughout (123 GB
  total). Ruled out.
- **Host OOM-killer:** zero `oom-killer`/`Killed process` lines anywhere in
  `dmesg`. Ruled out.
- **crashpad (`/tmp/android-daniel/emu-crash-*.db/{new,pending,completed}`):**
  empty every time. Ruled out a catchable-signal (SIGSEGV/SIGABRT) crash of
  the QEMU process itself — if QEMU had crashed on a signal crashpad hooks,
  it should have produced a report.

Net: the *process* silently vanished (no dmesg kill message, no crash
report), and the only related-looking log evidence (RenderThread segfaults)
doesn't cleanly attribute to this specific instance every time. I don't have
a confirmed root cause, and I'm not going to guess one. What I can say
confidently: it is **not** the app (guest logcat proves it), and it is
**not** host memory exhaustion. Per the campaign's own rule this is
ENVIRONMENT and does not count toward or against the app-level OOM verdict —
but four cold restarts of one specific AVD in under 20 minutes, all
correlated with active UI driving, is more frequent/severe than the
previously-documented "storms of segfaults that don't kill the emulator" and
is worth someone with infra visibility (e.g. whether another process in this
shared session force-restarts emulators) taking a look at separately.

## Screenshots

`docs/test-artifacts/run10-api29-learn/screenshots/`:
- `run10_00_initial.png` — first Dashboard, "3 / 70,033 sections — 9 curricula"
- `run10_04_dashboard.png` — Dashboard after 2nd launch
- `run10_06_learn_tab.png` — Learn tab, Daily Tasks
- `run10_07_reader.png`, `run10_08_reader2.png` — text_display_screen, Berachot 1:1 Hebrew text
- `run10_09_paged.png` — reader after paging, Berachot 1:2
- `run10_13_scrolled2.png` — Browse Content root (Sedarim)
- `run10_14_zeraim.png` — Zeraim tractate list
- `run10_15_berachot.png`, `run10_16_perek.png` — Berachot chapter list (3-4 levels deep)
- `run10_19_search2.png` — empty search screen with keyboard
- `run10_20_search_results.png` — search "shabbat" results
- `run10_21_search_ascii.png` — search "shabbat" input confirmation

## What I did not get to

I was not able to sustain a long, uninterrupted drill specifically into
Talmud Bavli's deeper tractates (the largest single curriculum) — every
attempt to navigate there was cut short within 1-2 minutes by the
ENVIRONMENT-level emulator restarts above. I did reach Mishnayos → Zeraim →
Berachot → chapter level (4 levels) repeatedly and exercised Learn/reader/
search/background-foreground fully to completion multiple times, which
covers the code path named in the P0 (`contentIndex`, shared across all 9
curricula, not curriculum-specific). Given the consistent, low, sub-100MB
memory ceiling observed every time that code path was exercised, I'm
confident the REFUTED verdict holds, but flagging the gap for completeness
rather than quietly omitting it.
