# Run-10 — emulator-5562 (API 33, Android 13): tracks + data consistency

**Findings: 2 × P1, 3 × P2. 0 × P0.** Light mode only. Profile `SettingsQA` (adult),
9 curricula / 70,033 sections seeded. Every scenario ran `crash_attribution.sh`
clear/check — **guest-clean throughout; nothing here is an app crash.**

> Filed by the coordinator on the auditor's behalf — its harness returns findings as text
> rather than writing files. Content is the auditor's, verbatim in substance.
> Screenshots under `scratchpad/run10_5562/`, not checked in.

## Numeric-consistency table (the headline deliverable)

Same profile, same curriculum (חומש), after bulk-marking all 5 sifrei Chumash
(5,846 leaf sections) via Settings → Add Lifetime Learning:

| Screen | Metric | Value |
|---|---|---|
| Dashboard | Learning lifetime (all curricula) | 8.3% — 5,847 / 70,033, 9 curricula |
| Progress tab top tile | Lifetime | 5,847 |
| Progress → Lifetime Knowledge | חומש | **100%** — 5,846 of 5,846 |
| Settings → Add Lifetime Learning | חומש | **100%** |
| **Progress tab → ACTIVE TRACKS row** | חומש "Lifetime" | **0%** ❌ |
| **Curriculum Progress** (tap that same row) | חומש "Lifetime" | **100%** |
| Curriculum Progress (same screen) | Total / Completed / In progress / Not started | 859 / 0 / 0 / 859 (only ויקרא listed, not all 5 books) |

Ground truth from three independent screens = **100%**.

## Finding 1 — P1: the Progress-tab "Lifetime" row disagrees with its own destination

Progress tab row reads *"Track progress 0% · Lifetime 0%"*. Tap it → Curriculum Progress
reads *"Track progress 0% · Lifetime 100%"*. Same session, screenshots seconds apart,
reproduced twice.

⚠️ **This challenges the existing divergence analysis, correctly.**
`docs/test-artifacts/run10/progress-percentage-divergence.md` argues the percentage
divergence is "labelling, not arithmetic" — that different denominators answer genuinely
different questions and should be relabelled rather than equalised. **That framing does not
excuse this case:** here two figures carrying the *identical* label "Lifetime", one tap
apart, read 0% and 100%. There is no different question being answered. This is a wrong
count on the screen a parent checks first.

Not data loss — three other screens read the ledger correctly.

### ✅ ROOT CAUSE FOUND — and it is NOT the 5558 staleness P1

The auditor established the decisive fact: this was observed **after a full app/emulator
restart**, at a moment when the Dashboard *had* already refreshed to 5,847 / 8.3%. So
"needs a restart" does not explain it — the per-track row stayed wrong while the
header-level surfaces were already correct. That makes it **restart-resistant**, i.e. a
computation bug, not the self-healing invalidation gap filed on 5558.

Confirmed in code (`lifetime_knowledge_providers.dart:548-556`):

```dart
final trackLedger = ledgerEntriesByTrack[track.id] ?? const <LearningLedgerData>[];
final lifetimeRefs = builder.computeLearnedLeafRefs(
  leaves: leaves,
  completedRefs: allTrackCompletions.map((c) => c.sefariaRef).toSet(),
  ledgerEntries: trackLedger,
);
final lifetimePct = lifetimeRefs.length / denominator;
```

Both inputs are keyed by **`trackId`** — `allTrackCompletions` is the by-track grouping,
and `trackLedger` is `ledgerEntriesByTrack[track.id]`. Settings → "Add Lifetime Learning"
writes **`lifetimeOnly`** rows that carry **no track association**, so they are excluded
from the numerator entirely → the row reads 0% for a curriculum the user has fully learned.

**This contradicts the provider's own documented contract**, which states
`lifetimePercentage` is *"the fraction of items the user has ever encountered, computed by
`LifetimeTreeBuilder` across all completion sources (live + bulk-prior + **lifetime
imports**)"*. Lifetime imports are precisely what it drops.

⚠️ Not fixed here, deliberately: correcting it means deciding whether a track's "Lifetime"
figure should count knowledge acquired **outside** that track. The doc comment says yes and
the user-visible expectation (a Chumash track showing 100% when you know all of Chumash)
agrees — but that is a product decision touching child-progress numbers, so it wants intent
confirmed against `git log`/blame and existing tests before the numerator changes.

## Finding 2 — P2: Curriculum Progress undercounts Chumash ~7× and drops 4 of 5 books

Same screen: *"Total items: 859"*, breakdown lists only ויקרא; the true total is 5,846.
Cause appears to be the **active track's own scope** (Vayikra-only — confirmed via Track
Detail showing "Items remaining: 859") being displayed **unlabelled** beside an *unscoped*
"Lifetime: 100%" headline on the same card. The card contradicts itself rather than being
merely mislabelled.

## Finding 3 — P2: track rename does not propagate to the Progress-tab screens

Renamed a track "תלמוד בבלי" → "תלמוד בבלי EDITED" via Edit Track (write succeeded).
Settings-side screens (Manage Tracks, Track Detail) show "EDITED" consistently — **including
after a full emulator restart**. Progress-tab-side screens (Active Tracks row, Curriculum
Progress, its gear → Program Settings) all still show the **old** name, also after restart.

Surviving a restart rules out simple caching and points at the two screen families reading
different sources, or a persisted denormalised copy.

## Finding 4 — P1/P2: dead CTA on the Lifetime Knowledge screen

The "Add items I learned previously" card failed to navigate across **7 tap attempts**
(uiautomator-verified centre, chevron, icon, and swipe-tap variants) spanning **2 sessions
with a restart between**. In the same sessions the adjacent segmented toggle on the
identical screen responded, and back always worked — so this is not host lag, it is
specific to this control. The identical route works fine from Settings → Add Lifetime
Learning. Code at `lifetime_knowledge_screen.dart:159-161` looks unremarkable
(`onTap: () => context.router.push(const LifetimeMarkingRoute())`); root cause not
isolated (possible overlay / hit-test issue).

## Finding 5 — P2, code-confirmed: the Jan-1-2000 sentinel is still raw-rendered

Important distinction the auditor established: **two different bulk-mark features exist.**
- Settings → "Add Lifetime Learning" explicitly does **not** feed siyumim (its own copy says
  so). Verified: "No siyumim yet" after marking 100% of Chumash through it — **correct, not
  a bug.**
- Track Detail → "Mark as previously learned" **does** feed siyumim ("count toward סיומים").

The on-device repro was blocked by a *sensible guardrail* (the app refused to mark the only
available scope 100%, requiring some content left unmarked), so the actual siyum card was
never forced before the session ended.

Code confirms it unfixed on the audited build: `completion_constants.dart:30` still defines
`kBulkPriorSentinelDate = DateTime.utc(2000, 1, 1)`, and
`siyumim_grouped_view.dart:434-437` / `siyumim_timeline_view.dart:195` format `achievedAt`
through plain `DateFormat.yMMMd` with no sentinel awareness. Both files' comments show a
recent IA redesign deliberately removed the "via bulk-mark" vs "Live" provenance **label**
but not the underlying date **value** — so a bulk-completed masechta would now show a bare
"Jan 1, 2000" with *less* context than before.

**Status: already fixed on `reassurance/run9-data-consistency`** (renders "Previously
learned" instead; the stored sentinel is untouched because it is load-bearing for
pace/streak logic). That branch was unmerged at the time of this audit.

## Worked correctly — no findings

Track creation (full wizard), Set Goal (pace goal with correct estimated-finish arithmetic),
the Edit Track write itself, Delete Track → Archive, and completion-direction staleness
(Learn tab count, Dashboard streak, Progress tab all updated immediately with no manual
refresh).

## Explicitly not completed — gaps, not findings

- **Un-complete / un-mark staleness**: no completion-toggle affordance was found on an
  already-completed reader page; investigation ended with the session. **Not reported as a
  bug** — not fully investigated.
- **Finding 5's on-device repro** — blocked by the guardrail above plus running out of
  multi-unit tracks.

## Environment

**13 SIGSEGV crashes** on 5562 this session (host SwiftShader segfault storm under load;
host load ~10–38 across 24 cores with 5–6 concurrent emulators). All recovered per protocol,
**guest-clean every time**, app/DB state survived every restart intact. One blank Learn-tab
screenshot coincided with a crash notification — logged ENVIRONMENT, not investigated as an
app defect.
