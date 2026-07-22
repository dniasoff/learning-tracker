---
title: "Run-10 — API 29 Learn-tab OOM baseline (device emulator-5556)"
purpose: "Settle run-8's P0 (\"opening Learn OOM-kills the app on API 29\") with guest-side-attributed evidence, per the reassurance campaign's R9 crash-attribution methodology."
date: 2026-07-22
device: emulator-5556 (AVD lt_api29_pixel3, Android 10 / API 29, 512m heap)
app: com.jcom.torah.learning_tracker
---

**Build note:** `versionName` (1.0.66) does not change between rebuilds — it
comes from `pubspec.yaml` and is not a reliable build fingerprint. Two
different APKs were measured across this session:
- Build A: `firstInstallTime=2026-07-22 04:28:28` (the pre-existing install,
  measured in the "first round" section below).
- Build B: `lastUpdateTime=2026-07-22 19:07:13` (reinstalled by the
  coordinator mid-session via `adb install -r -d`, data preserved; measured
  in the "Talmud Bavli follow-up" section below).

Both builds contain the identical, unfixed `content_index.dart:111-116` —
confirmed by direct read on Build B after the reinstall — so this is not a
confound for the verdict: the code under test is the same in both. Build B
additionally contains R8 Part A (aggregates no longer materialize all 9
curricula) and R8 Part B (the Lifetime Knowledge union denominator), neither
of which touches the Learn-tab/`contentIndex` path this report is about.

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

### P2/P3 — Reader next-chevron swallows most taps (usability defect, reproducible)

**Severity:** P2/P3 (usability, not a crash, not data-affecting). **Status:**
reproducible, not memory-related.

**Repro steps:**
1. Open any text in the reader (`text_display_screen.dart`) — e.g. Learn tab
   → Daily Tasks → any Mishnah, or Browse Content → Talmud Bavli → any
   tractate → any daf → עמוד א.
2. Tap the next-item chevron (top-right of the reader app bar) repeatedly at
   a steady ~1.1-1.5s pace, `adb shell input tap 1013 296` (coordinates for a
   1080-wide device).
3. Compare tap count to breadcrumb advancement.

**Observed:** Consistently swallows roughly half or more of the taps, not
just an occasional dropped frame:
- Round 1 (Mishnayos reader): 5 taps at ~1.2s → advanced **1** mishnah
  (Berakhot 1:1 → 1:2).
- Round 2 (Talmud Bavli, Bava Batra reader): 68 taps at ~1.1-1.3s over
  several batches → advanced **34** dapim (2:2 → 36:1), i.e. consistently
  ~2 taps consumed per 1 page advanced.

Both times the app remained fully responsive and never crashed — this is
purely a lost-input problem, most likely a debounce or an animation-lock on
the route/page transition in the reader's next/prev handler that swallows
taps landing mid-transition. On a reading surface, silently dropping half of
a user's "next page" taps is a genuine, worth-fixing usability defect, not
cosmetic — flagging as P2/P3 rather than a footnote per review feedback.
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
- `run10_50_bavabatra.png` — Talmud Bavli → Nezikin → Bava Batra daf list
- `run10_51_daf.png` — Bava Batra daf 2, amud selector
- `run10_52_reader_bb.png` — Bava Batra daf 2 amud א, real Talmud text
- `run10_55_paged_far.png` — after 68 chevron taps, daf 36 amud א

## Follow-up round: settled with the persistent host-side logcat recorder

After the above was reported, the coordinator added a host-side logcat
recorder (`/tmp/logcat_5556.log`) that survives the emulator dying — closing
exactly the evidence gap that made the earlier deaths ambiguous. This let me
inspect guest logcat *up to the literal last line before the device
disappeared*, three more times:

**Death #5 and #7 (clean ENVIRONMENT, confirmed):** in both cases the log
ends on ordinary, healthy app/system activity — one ends mid-reader with a
GC line (`Explicit concurrent copying GC freed ... 49% free, 3897KB/7795KB`)
and normal Riverpod provider updates for `Mishnah Berakhot 1:1/1:2/1:3`; the
other ends on a routine GC (`49% free, 3194KB/6388KB`) right after opening
Learn. Both times the log **just stops** — no `FATAL EXCEPTION`, `am_crash`,
`ANR`, or `lmkd`/`lowmemorykiller` line naming our package anywhere nearby.
Per the recorder's own decision rule this is ENVIRONMENT. The emulator's own
host log corroborates: it ends cleanly right after "Boot completed", no
error, no segfault — consistent with the coordinator's independent finding
that host load (`uptime` showed 27-37) is the cause, not the app.

**Death #6 (the interesting one — investigated in full, still not the P0):**
this one *did* produce a genuine guest-level kill: `Zygote: Process 3806
exited due to signal 9 (Killed)`, and I independently confirmed PID 3806 was
our app (via `pidof` moments earlier and `FirebaseSessions` debug lines
tagged with that PID). This is a real, guest-side SIGKILL of our process —
the kind of evidence that would normally confirm an app-level kill. I dug
into it rather than taking the win at face value:

- No `lmkd`/`lowmemorykiller` line anywhere in the log **names our package**
  as a kill target (the pattern `crash_attribution.sh` requires for a
  CONFIRMED verdict) — only the generic per-PID `Zygote` exit line, which
  fires for every process death regardless of cause.
- In the same ~45-second window, **~40 other, unrelated processes** (system
  services, Google apps, none of them ours) were also killed with signal 9,
  immediately after `lowmemorykiller`/`lmkd` freshly initialized post-cold-boot
  (`lmkd data connection established` at 19:06:46, kill storm 19:07:00-19:07:43).
  This is a mass reap, not a targeted kill of one memory-heavy app.
- Guest total RAM on this AVD is only **~2 GB** (`MemTotal: 2,040,256 kB`),
  and a burst of background/Google-service processes racing to start after
  a cold boot is a well-known, ordinary source of this kind of churn —
  independent of anything our app does.
- Decisively: I traced our app's own Riverpod log lines up to the exact kill
  timestamp. At time of death it was still showing **Dashboard** providers
  (`dashboardUserModeProvider`, `dashboardStreakProvider`) — **the Learn tab
  had not yet been opened in that session**, and `dumpsys meminfo` moments
  before showed a modest 53 MB Native Heap / 5.5 MB Dalvik Heap. The
  `contentIndex` code path named in the P0 was never touched before this
  process died.

So death #6 is real evidence that this app (like any app) is killable under
genuine system-wide memory churn on a RAM-constrained AVD — but it happened
on the Dashboard, before Learn was ever opened, amid a mass-kill sweeping
~40 unrelated processes. It does not support the P0 hypothesis about
Learn/`contentIndex` specifically; if anything it points at general AVD RAM
headroom (2 GB total) as a post-boot noise source, separate from the
per-app 512 MB Dalvik ceiling this whole investigation is about.

Every other `dumpsys meminfo` sample taken this round (baseline ~75 MB → post
Learn-tap ~66 MB Native Heap, Dalvik consistently 3-7 MB) continues to show
the same pattern as round 1: modest, flat, nowhere near the 512 MB limit.
**This does not change the verdict — REFUTED stands, now on stronger
evidence** (a real guest-level kill was available to check, and checking it
still didn't implicate Learn/contentIndex).

## Talmud Bavli deep-drill (the gap from the first round — now closed)

On Build B (`lastUpdateTime=2026-07-22 19:07:13`), with host load easing
(~15-30), 5556 stayed up long enough to complete this. Full drill: Learn tab
→ Browse Content → **תלמוד בבלי (Talmud Bavli)** → נזיקין (Nezikin) → בבא
בתרא (Bava Batra, one of the largest tractates at 176 dapim) → דף ג (daf 3)
→ עמוד א → reader opened on real Talmud text → paged forward **34 dapim**
(daf 2 amud א through daf 36 amud א) across ~68 chevron taps in several
batches.

| Stage | Native Heap (KB) | Dalvik Heap (KB) |
|---|--:|--:|
| Dashboard, pre-Learn | 62,966 | 5,513 |
| Talmud Bavli tractate list open | 57,089 | 4,201 |
| Nezikin tractate list | 56,061 | 4,125 |
| Bava Batra daf list (3 levels deep) | 74,061 | 4,109 |
| Daf 3 amud list (4 levels deep) | 58,253 | 4,133 |
| Reader opened, daf 2 amud א (5 levels deep) | 61,689 | 4,133 |
| After paging to ~daf 10 | 73,441 | 4,309 |
| After paging to ~daf 18 | 92,977 | 4,357 |
| After paging to ~daf 27 | 119,698 | 4,481 |
| After paging to ~daf 36 (68 taps total) | 109,850 → **125,566 peak**, oscillating down to 109,850 | 4,481-4,609 |

Memory rises with sustained paging through Bavli — a real, mild
growth-then-plateau/oscillate pattern (peaked ~125 MB, then a GC pass pulled
it back to ~110 MB) — consistent with the reader retaining some rendered
state per visited daf rather than fully releasing it. This is a genuine
observation worth a look if it's not already known, but it is **not runaway**:
it leveled off and partially reclaimed rather than climbing monotonically,
and even at its single highest sample (125,566 KB ≈ 123 MB) that is only
**~24% of the 512 MB limit** — nowhere near enough to threaten an OOM. The
device never died during this drill, `crash_attribution.sh` reported guest
clean at the end, and the app remained fully responsive throughout (modulo
the chevron-debounce finding above). This closes the Talmud-Bavli gap left
open after the first round: the largest curriculum, drilled deep and paged
through at length, does not reproduce the P0 either.
