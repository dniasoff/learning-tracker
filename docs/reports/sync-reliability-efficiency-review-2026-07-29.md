# Cloud-Sync Reliability & Efficiency Review

*Scope: the Firestore/outbox sync layer in `learning_tracker/lib/core/sync`, `lib/features/sync`, and `lib/features/account`. Grounded against the 5-angle investigation plus the measured Firebase metrics (42 concurrent listeners, ~18 per launch, artificially low read/write because App Check was blocking traffic until today, 2026-07-29). I independently re-verified the highest-stakes citations against the working tree and the pinned `internet_connection_checker-3.0.1` in the pub cache; see §5 for confidence.*

---

## 1. Executive summary

**It is not fundamentally broken — it is under-coordinated and mis-tuned.** The hard parts are sound: a durable Drift `outbox`, single-flight drain with stale-reclaim, capped-jittered exponential backoff, dead-lettering at 10 attempts, batched completion writes, and correct per-active-profile listener scoping. The "fickle + heavy" feeling comes from a small number of wiring gaps and a couple of default-driven choices, not from a rotten design.

Three root causes explain almost everything the user reports:

- **RC-1 — Listener-first + pull-on-launch run uncoordinated, and neither self-heals in-session.** Every launch fetches the same collections twice (full pull `.get()` *and* each listener's initial server snapshot), which is the "heavy." And a Firestore `.snapshots()` stream is *terminal on error* — the supervisor logs the error but never resubscribes — so any channel that died under App Check enforcement stays dark until relaunch, which is the "fickle." (`firestore_listener_source.dart`, `listener_supervisor.dart:200-207`, `sync_orchestrator.dart:825-909`.)
- **RC-2 — Connectivity is sourced from a raw, un-hardened polling package.** The orchestrator's *only* guaranteed-eventual delivery trigger (the 60 s periodic drain) is gated on `_lastConnectivity == true` (`sync_orchestrator.dart:595`), and that flag is fed by `InternetConnectionChecker.createInstance()` — default **5 s** poll against **three third-party demo APIs** (`connectivity_providers.dart:17`; package defaults confirmed: `DEFAULT_INTERVAL = 5s`, hosts `dummyapi.online` / `jsonplaceholder` / `fakestoreapi`). A false-offline reading silently disables the safety net (fickle), and the poll itself is ~51,840 HTTP requests/day with a radio wake every 5 s — the single biggest battery/mobile-data drain, and **invisible to the Firebase monitoring the complaint was measured against** because it never touches Firestore (heavy).
- **RC-3 — Lifecycle coverage has holes.** A plain cold relaunch of an already-signed-in user triggers *no* pull and *no* drain — `SyncLifecycleObserver` only does `ref.watch(syncOrchestratorProvider)` (verified). The tutored listener fleet (16 streams) is never parked. Resume does a global Firestore network reset on every trivial app-switch. Result: backlogs linger until a 60 s tick or a manual gesture (fickle), and idle streams keep the radio warm (heavy).

**Bottom line for planning:** ~70% of the win is in **small/medium, low-risk wiring fixes** (cold-launch drain, resubscribe-on-error, fix the connectivity source, park the tutored fleet, dedup the launch double-fetch). The remaining big-ticket items — delta pull with a watermark, and re-scoping real-time to genuinely collaborative data — are **architectural** and worth doing, but are not prerequisites for making the app feel reliable again.

**App Check interaction (today's incident):** the low measured read/write volume is an artifact of App Check blocking traffic. Two consequences: (a) **RC-1's terminal-listener bug and RC-3's failed-pull-doesn't-drain path are exactly why the incident felt catastrophic and lingered** — errored channels stayed dark and the error status masked the real backlog with no in-card retry; (b) **now that App Check is fixed, the double-fetch and full-pull costs that were masked will start being billed**, so the efficiency items get *more* urgent this week, not less.

---

## 2. Reliability findings (why syncs stay pending / need "manual sync"), ranked

### R-1 (High) — Listener streams are terminal on error; nothing resubscribes in-session
A Firestore `.snapshots()` stream closes permanently on error (permission-denied, App Check attestation failure, `UNAVAILABLE`). The supervisor's `onError` only forwards to a logger — it never cancels+resubscribes and never flips `_attached=false`, so it believes it is still live while the channel is dead. **Evidence:** `listener_supervisor.dart:200-207`; `sync_orchestrator.dart:1491-1514` (`_onListenerError` only logs/Crashlytics); tutored equivalent `tutored_listener_supervisor.dart:197-209`. Recovery paths do **not** restart: connectivity-online only resets network + drains (`sync_orchestrator.dart:634-643`); resume only resets network + pulls + unparks-if-parked (`lifecycle_observer.dart:145-160`). Only a 60 s+ background park/unpark, a profile/account switch, or a relaunch reopens a dead channel.
**Why it's the #1 "fickle" mechanism and the direct App Check aftermath:** every listener that errored under enforcement stays dark for the rest of the session even after App Check is fixed — real-time stops, data goes stale, "manually sync" (which reruns pull) is the only in-session recovery.
**Fix:** on channel error, mark that channel dead, flip the supervisor off `_attached`, and schedule a bounded exponential-backoff resubscribe (or a coalesced `restart()`). Additionally wire the connectivity-online path and the resume network-reset to trigger a resubscribe so App Check recovery and network handoffs resurrect dead listeners without a relaunch. **Effort: medium. Risk: low-moderate** (touches the hot listener path — needs care around double-attach).

### R-2 (High) — Plain cold relaunch triggers no launch-time drain
`SyncLifecycleObserver` only does `ref.watch(syncOrchestratorProvider)` (**verified**, `sync_lifecycle_observer.dart:29`) — it does *not* call `pullOnLaunch`. Every `pullOnLaunch` caller is a fresh sign-in / account-switch / device-restore / upgrade, or `BackupSyncSection.initState` (only when Parent Settings is opened, `backup_sync_section.dart:46-59`). The pull-complete drain (triggers 2/4) lives only on the pull success path (`sync_orchestrator.dart:942`), so on a resume-less cold start a prior session's backlog is flushed only by the 60 s periodic timer or by new writes' write-tees.
**Impact:** this is precisely "I log on and a few syncs are pending" — queued writes sit until the first 60 s tick, a background/foreground round-trip, or opening Parent Settings.
**Fix:** kick a drain (ideally a `pullOnLaunch`) on a plain cold launch of an existing cloud session, from `SyncLifecycleObserver`. **Effort: small. Risk: low.**

### R-3 (High) — The only eventual-delivery guarantee is gated on a flaky connectivity flag
The 60 s periodic drain — the safety net meant to guarantee eventual delivery — early-returns on `if (_lastConnectivity != true)` (**verified**, `sync_orchestrator.dart:595`), and that flag comes from the raw `InternetConnectionChecker` via an inline `async*` stream (`sync_orchestrator_providers.dart:141-147`), **not** the app's hardened self-healing `connectivityStreamProvider` (`connectivity_providers.dart:77-90,125-226`). The codebase itself documents these hosts as flaky demo APIs whose check "can keep timing out / returning offline, leaving the banner stuck." A false-offline (or a slow/never-resolving null seed) silently disables *both* the periodic drain *and* the offline→online connectivity drain (trigger 3), so writes stay pending forever with no auto-retry.
**Fix:** feed the orchestrator the hardened `connectivityStreamProvider`, and gate the periodic timer on **outbox depth > 0** instead of on connectivity (never disables delivery, and stops idle wakeups — see E-2). **Effort: medium. Risk: low.**

### R-4 (High) — Failed pull doesn't drain and latches an error status that masks the real backlog; appCheck/permissionDenied have no tap-to-retry
The `pullOnLaunch` catch block emits `SyncStatus.error` and rethrows with **no** `_drainOutbox` (contrast the success path at `:942`) — `sync_orchestrator.dart:972-1043`. `_recomputeOutboxStatus` early-returns when the current status is `SyncStatusError` (`:1315`), so the truthful pending/degraded count is suppressed. The card offers `onTap: retryPull` only for timeout/unknown; **appCheck and permissionDenied render informational copy with no retry button** (`backup_sync_section.dart:123-141`).
**Impact:** this is the exact App-Check-denial window — every push and the pull fail, the badge shows an unactionable error card, queued writes are not flushed, and the outbox-derived status is masked; recovery depends on an external resume.
**Fix:** drain the outbox in the pull catch path (or whenever an error status is emitted), stop letting an error status suppress the recompute, and add a tap-to-retry (that also kicks a drain) to the pending/offline/degraded-stuck cards **including** the appCheck/permissionDenied variants. **Effort: medium. Risk: low.**

### R-5 (Medium) — Backoff/dead-letter budget isn't reset on connectivity-regain or foreground
The only attempts-reset is `reviveIdentityDeadLetters` (attempts ≥ 10 **and** error like `%permission-denied%`/`%unauthenticated%`), invoked once-per-launch (`outbox_dao.dart:198-213` per the investigation; `_maybeReviveIdentityDeadLetters` `sync_orchestrator.dart:1127-1172`). Backoff cap is 1 h; all kicks call `drain`, which *skips* rows whose next-attempt is in the future (`outbox_processor.dart:310,463`) — none reset attempts.
**Impact:** after any transient outage (or the multi-day App Check incident), a row that reached attempts 6–9 waits out a capped 1 h backoff even though connectivity is fine; **timeout-caused dead-letters (attempts ≥ 10 without a permission-denied string) are never revived and remain pending forever.**
**Fix:** on connectivity-regain and foreground, reset the retry budget (attempts→0 / eligible-now) for all pending rows; broaden the revive to cover timeout dead-letters; expose a "retry all now" that resets attempts. **Effort: medium. Risk: low-moderate** (guard against thundering-herd re-push on a large stuck queue).

### R-6 (Medium) — Two facades race to own `pointsBalanceDao.syncSink`; the tee-less one may win
**Verified:** `sync_orchestrator_providers.dart:113` sets `database.pointsBalanceDao.syncSink = uploadFacade` (constructed **without** `onEnqueueDrain`), while `sync_providers.dart:200` (inside a `scheduleMicrotask`) sets the **same field** to a facade that *does* have the write-tee (`onEnqueueDrain` at `:174`). Whichever runs last wins; ordering is not guaranteed.
**Impact:** if the tee-less facade wins, a points credit/redemption enqueues a durable outbox row but fires **no** write-tee, so it waits for the 60 s periodic (connectivity-gated) or a resume pull to reach the cloud — points feel especially laggy.
**Fix:** establish a single composition root for `pointsBalanceDao.syncSink` so the tee-enabled facade always wins (or give the account-level `uploadFacade` an `onEnqueueDrain`). **Effort: small. Risk: low.**

### R-7 (Medium) — Status can misreport in both directions, with no in-card way out
`depth` is a plain `COUNT(*)` with no eligibility filter, so it counts dead-lettered and backing-off rows; `stuckCount(attempts≥3)→degraded` (`sync_orchestrator.dart:1336-1342`). The pending/offline/degraded-stuck cards have **no** `onTap` (`backup_sync_section.dart:104-115,193-204`). Separately, offline pushes are plain `collection.doc(id).set(...)` under default persistence; they hang until the 20 s `.timeout` throws → `markAttempted`, inflating attempts even though Firestore's own persistence queue will still deliver them.
**Impact:** a stuck row shows a permanent "N pending"/"Sync paused" with no in-card recovery (only a relaunch runs the revive); conversely, offline writes accumulate attempts and can flip the badge to degraded while the data *is* being delivered by the SDK — a false-negative that only self-corrects on a later successful drain.
**Fix:** filter `depth` to delivery-eligible rows; add recovery affordances (folds into R-4); treat an offline push timeout as "deferred," not a failed attempt (folds into E-4). **Effort: medium. Risk: low.**

### R-8 (Medium) — Short app-switch during a network handoff can leave dead listeners *and* a skipped pull for up to 5 min
Resume pull is throttled out if the last pull was < 5 min ago (`sync_orchestrator.dart:704-726,658`); listeners are only re-opened via unpark, which only runs if the background lasted ≥ 60 s (`lifecycle_observer.dart:156-160,165-171`). `resetFirestoreNetwork` on resume does **not** resurrect an already-terminated snapshot stream. So a brief (< 60 s) background across a Wi-Fi↔cell handoff can leave the app with no live listeners and no fresh pull.
**Impact:** the exact "I come back and it's stale / stuck pending until I manually sync" report.
**Fix:** subsumed by R-1 (resubscribe on error/handoff). **Effort: covered by R-1.**

---

## 3. Efficiency findings (listener fleet + data/battery/cpu), ranked, with expected savings

### E-1 (High) — Connectivity checker polls 3 demo APIs every 5 s for the whole session — the largest, invisible cost
**Verified:** `InternetConnectionChecker.createInstance()` with no overrides (`connectivity_providers.dart:17`) → package defaults: `checkInterval = DEFAULT_INTERVAL = 5s`, three hosts `dummyapi.online` / `jsonplaceholder.typicode.com` / `fakestoreapi.com` (`internet_connection_checker-3.0.1`). The orchestrator holds a lifetime listener (`sync_orchestrator.dart:585-587`), and each cycle fires a request to **all three** hosts concurrently. A code comment even asserts the opposite — "event-driven instead of polling, so idle CPU cost is ~0" (`connectivity_providers.dart:8-10`) — which is **factually wrong** for this package version and actively steers future reviewers away from the biggest cost.
**Cost:** 3 hosts × (86,400 / 5) ≈ **51,840 requests/day**, plus a cellular-radio wake every 5 s (the radio tail keeps the modem near-continuously awake), foreground *and* background, online *or* offline. Never touches Firestore, so it is **invisible to Cloud Monitoring**. A second 5 s loop (`connectivity_providers.dart:153-172`) *doubles* this while offline.
**Fix:** construct the checker with a long `checkInterval` (3–5 min) — the constructor accepts it (`internet_connection.dart:35`, setter `:370`) — and/or rely on `connectivity_plus` platform events with an on-demand probe only on transitions/resume; replace the 3 demo hosts with a single first-party/Google reachability endpoint; remove the redundant offline re-probe loop; correct the false comment.
**Expected saving:** ~**99%** of connectivity traffic (51,840/day → a few hundred/day) and elimination of the 5 s radio-wake cadence. **This is the single largest battery/mobile-data win. Effort: small. Risk: low.**

### E-2 (High) — 60 s periodic drain fires in the background and runs a ~40-query DB sweep even when the outbox is empty
**Verified:** `Timer.periodic(_periodicDrainInterval /*60s*/…)` gated only on `_lastConnectivity`, not foreground (`sync_orchestrator.dart:594-597`); cancelled only in `dispose()`. Park stops listeners but not this timer. Each fire runs `_doDrain → _drainForProfile` ×2 (active + profile 0), ~19 `getPendingByKind` queries each (`outbox_processor.dart:283,446,555-579`) plus `_recomputeOutboxStatus` (several COUNTs, `:1244-1266`) — **~40–46 SQLite queries per tick with no empty-outbox precheck.**
**Cost:** ~1,440 wakeups/day × ~40 queries ≈ **~60k no-op queries/day**, continuing while backgrounded-and-online.
**Fix:** (a) add a cheap `depth > 0` / `EXISTS` precheck at the top of the periodic drain and `_drainForProfile`; (b) gate the timer on foreground (cancel on park, re-arm on unpark) — the outbox can't grow while backgrounded; (c) this also implements R-3's depth-gate.
**Expected saving:** turns ~60k queries/day into near-zero, and removes the background wakeup entirely. **Effort: small. Risk: low.**

### E-3 (High) — Standing 18-listener fleet (≈34 for a tutor); the tutored fleet is *never* parked
**Verified:** `firestore_listener_source.openChannels()` returns 18 logical channels for the own account (~19 gRPC streams; `tutor_grants` fans out to 2); a tutor adds a second `TutoredListenerSupervisor` of **16** channels (`channelCount = 16`, **verified** — and the class exposes only attach/detach, **no park/unpark**). 18(+1) own + 16 tutored ≈ the **42-concurrent** measured spike. `LifecycleObserver.parkListeners` touches only `_listenerSupervisor` (`sync_orchestrator.dart:544-573`), so a parent who backgrounds while viewing a child leaves **16 gRPC streams live 24/7** — the larger of the two fleets, running past every Doze window. Many own channels (`stage_definitions`, `curriculum_tracks`, `learning_order`, `study_day_configs`, `profile_programs`, 3× `preferences/*`) change rarely or only from this device, so a permanent real-time listener buys ~nothing.
**Fix (in order of leverage):**
1. Add `park()/unpark()` to `TutoredListenerSupervisor` (delegate to its inner supervisor) and register it in the park/unpark hooks. **Small, low-risk, highest single reduction.**
2. Batch the 3 single-doc preference listeners into 1 (listen at the `preferences` collection level). **Small.**
3. Re-scope real-time to genuinely collaborative data (`tutor_grants`, `learner_profiles`, `completions`, `points_ledger`, tutored child collections); convert slow-changing/append-only/same-device collections to pull-on-resume + write-tee. Target ~6–8 standing listeners (≈2 for a non-tutoring single-device user). **Medium/large, architectural.**
**Expected saving:** tutored-park alone removes 16 always-on background streams; the full re-scope cuts standing gRPC streams ~60–90% and the per-resume re-handshake proportionally.

### E-4 (High) — Every launch reads each collection ~twice; every resume ~three times — no delta cursor
`pullOnLaunch` walks all 18 kinds sequentially via keyset **pagination by `documentId`** with **no `where(updated_at > watermark)`** filter (`pull_pipeline.dart:433-469`; `firestore_gateway_impl.dart:598-623`, comment `:592-597` confirms no filtered query/index exists), using `query.get()` (server round-trip). Concurrently the 18 listeners each deliver an initial **server** snapshot (the cache emission is suppressed by the FB-3 `isFromCache` guard, `:1000`). On a >5-min resume you additionally get a global network reset re-handshake — full pull + full re-attach + re-handshake all at once (`lifecycle_observer.dart:145-160`).
**Cost:** for a ~1-year user (~2,300 mutable-history docs) this re-reads ~2,300 docs (~1 MB, ~2,300 billed reads) on **every** launch even when nothing changed — with several launches/resume-pulls a day, multiple MB/day and >10k redundant reads/day/user. **This was largely masked by App Check and will now start billing.** It also produces the launch "flicker" (two writers racing into Drift) and part of the "few syncs pending on logon."
**Fix (staged):**
- **Near-term (medium):** dedup — skip pull-on-launch for any collection with a healthy live listener and let the initial snapshot seed Drift; or attach listeners *after* pull completes so their first emission comes from cache. Roughly halves per-launch reads.
- **Architectural (large):** convert pull to a **delta pull** — persist a per-collection high-watermark and query `where(synced_at > watermark).orderBy(synced_at)`; requires composite indexes (`firestore.indexes.json` is currently empty) and a watermark store. A quiet launch then performs ~0 pull reads.
**Expected saving:** dedup ≈ −50% launch reads; delta pull collapses the ~2,300-doc re-read to only the handful changed.

### E-5 (Medium) — Global Firestore network reset on *every* resume, even a 2-second app-switch
On resume the observer **unconditionally** awaits `resetFirestoreNetwork` when `_wasBackgrounded` — `disableNetwork()` then `enableNetwork()` (`lifecycle_observer.dart:145-149` → `firestore_instance_provider.dart:55-56`), which is instance-global and forces **all** live listeners to drop and re-handshake. Unlike the connectivity path it has **no debounce**, and `_wasBackgrounded` is set on *any* non-resumed state including a transient `inactive` blip (notification shade, permission dialog).
**Impact:** a user who glances away and back (well under the 60 s park window, so nothing was parked) still pays a full teardown + re-establish of all ~18–35 listeners; frequent short switches make this a dominant hidden traffic/CPU source and a contributor to the 42-concurrent spike.
**Fix:** gate the reset on a real network-identity change (or an observed stream error), restrict it to true background states (`paused`/`hidden`) not `inactive`, debounce it, and skip it for sub-park-window backgrounds; rely on listener re-attach for self-heal. **Effort: small. Risk: low.**

### E-6 (Medium) — Append-only ledgers pushed one round-trip per row; the batch writer is dead code
Only completions are batched (`pushCompletionsBatch`, `outbox_processor.dart:377`). `learning_ledger`/`points_ledger`/`streak_events`/`reward_redemptions` and all config kinds drain one row per `_dispatch` (`outbox_processor.dart:445-502`). The batched `pushLedgerEntriesBatch` exists (`firestore_gateway_impl.dart:530-554`) but **has no caller** — dead code.
**Impact:** a day of study producing N ledger/points/streak rows costs N separate write round-trips (uplink traffic + radio wakeups + latency on cellular) instead of one commit.
**Fix:** route the append-only kinds through the existing batched writer. **Effort: medium. Risk: low.**

### E-7 (Medium) — Self-sustaining at-limit recovery-pull loop for heavy/long-tenured accounts
`isAtLimit` is `snapshot.docs.length >= limit` on the raw 500-row page (`firestore_gateway_impl.dart:987-990`); for any user with >500 completions/ledger/streak/points rows, **every** snapshot (including the echo of the user's own write) is at-limit and triggers a recovery pull, throttled only to 1/min per channel (`listener_supervisor.dart:168,343-365`).
**Impact:** long-tenured accounts self-generate up to several full-page background pulls per minute — a footprint cost that *grows with account age*, the opposite of "minimal."
**Fix:** only trigger recovery when the server cursor actually advanced past the merged window, or exclude append-only collections from at-limit recovery. **Effort: small. Risk: low.**

### E-8 (Low) — No explicit Firestore persistence/cache config; no metered/cellular awareness
`firestore_instance_provider.dart:15-17` returns raw `FirebaseFirestore.instance` — no `Settings`/`persistenceEnabled`/`cacheSizeBytes`/`localCache` anywhere (persistence ON by default on native, OFF on web; cache untuned), yet the merge logic depends on persistence (`isFromCache` guard). And connectivity is binary online/offline (`sync_orchestrator_providers.dart:142-147`) — no `NetworkType`/metered awareness, so the app keeps the full fleet warm and double-reads on cellular identically to Wi-Fi.
**Fix:** pin `FirebaseFirestore.settings` (persistence + bounded `cacheSizeBytes`) at bootstrap; add metered awareness so cellular prefers a parked-listener + on-demand-pull mode with a longer resume throttle and suppressed at-limit recovery. **Effort: small (config) / medium (metered). Risk: low.**

### E-9 (Low) — 60 s park delay + throttled-resume still does work
The full fleet + gRPC channel stays live for 60 s after the user leaves (`lifecycle_observer.dart:58-59,136-137`); a throttled (no-op) resume still awaits `SharedPreferences.getInstance()` and runs a full `_drainOutbox('resume_throttled')` sweep before returning (`sync_orchestrator.dart:704-726`).
**Fix:** shorten the park delay (60 s → 10–20 s), and early-out the throttled resume before the prefs read + drain when outbox depth is 0. **Effort: small. Risk: low.**

---

## 4. Prioritized action plan

Ordered by **impact ÷ effort**. "Quick wins" are small/low-risk and can ship this week; "Architectural" are the larger bets. **★ = directly interacts with the just-fixed App Check issue.**

### Quick wins — safe, small, ship first

| # | Change | Fixes | Effort | Risk | Expected win |
|---|--------|-------|--------|------|--------------|
| 1 ★ | Resubscribe dead listeners on error + on connectivity-online/resume (mark channel dead, backoff re-attach) | R-1, R-8 | Medium | Low-Mod | Ends the #1 fickleness + the App-Check-stays-dark-until-relaunch aftermath |
| 2 | Configure connectivity checker: 3–5 min interval, single first-party host, drop redundant offline loop, fix false comment | E-1 | Small | Low | ~99% of connectivity traffic + the 5 s radio wake — biggest battery/data win |
| 3 | Kick a drain (+ pullOnLaunch) on plain cold launch from `SyncLifecycleObserver` | R-2 | Small | Low | "Few pending on logon" flushes immediately, not after ≥60 s |
| 4 | Depth-gate + foreground-gate the 60 s periodic drain; add empty-outbox precheck | R-3, E-2 | Small | Low | Removes ~60k no-op queries/day + background wakeups; makes delivery independent of the flaky flag |
| 5 ★ | Drain in the pull catch path; stop error status masking the recompute; add tap-to-retry to appCheck/permissionDenied cards | R-4, R-7 | Medium | Low | Closes the App-Check-denial trap; gives users an in-app recovery |
| 6 | Single composition root for `pointsBalanceDao.syncSink` (tee-enabled facade wins) | R-6 | Small | Low | Points/ledger writes always kick a drain on enqueue |
| 7 | Add `park()/unpark()` to `TutoredListenerSupervisor`; wire into lifecycle hooks | E-3.1 | Small | Low | Removes 16 always-on background streams on parent devices |
| 8 | Gate/debounce `resetFirestoreNetwork` — real network change or `paused`/`hidden` only, not `inactive` | E-5 | Small | Low | Stops all-fleet re-handshake on every trivial app-switch |
| 9 | Point connectivity source at hardened `connectivityStreamProvider` | R-3 | Small | Low | Self-healing re-probe instead of raw flaky checker |

### Medium — worth doing soon

| # | Change | Fixes | Effort | Risk | Notes |
|---|--------|-------|--------|------|-------|
| 10 ★ | Reset retry budget on connectivity-regain/foreground; revive timeout dead-letters; "retry all now" | R-5 | Medium | Low-Mod | Guard against thundering-herd on a large stuck queue; matters post-incident |
| 11 | Dedup launch reads (listener snapshot OR pull, not both) | E-4 near-term | Medium | Low | ≈ −50% per-launch reads; removes launch flicker |
| 12 | Batch append-only ledger drains via existing `pushLedgerEntriesBatch` | E-6 | Medium | Low | Fewer uplink round-trips; wire the dead code |
| 13 | Curb at-limit recovery-pull loop (cursor-advanced check / exclude append-only) | E-7 | Small | Low | Stops footprint growing with account age |
| 14 | Batch 3 preference doc listeners into 1; shorten park delay; early-out throttled resume | E-3.2, E-9 | Small | Low | Trims standing count + idle work |
| 15 | Pin `FirebaseFirestore.settings` (persistence + cache size) | E-8 | Small | Low | Removes silent platform-default dependency |

### Architectural — larger bets, plan deliberately

| # | Change | Fixes | Effort | Risk | Notes |
|---|--------|-------|--------|------|-------|
| A ★ | **Delta pull** with per-collection watermark + composite indexes | E-4 full | Large | Moderate | Quiet launch → ~0 pull reads. Higher urgency now that App Check no longer masks read volume |
| B | **Re-scope real-time** to collaborative data only (~18 → ~2–8 listeners); own-data becomes pull-driven | E-3.3 | Large | Moderate | Answers "is 18 listeners even right" — no, for single-user-per-account. Biggest standing-cost cut |
| C | **Metered/cellular awareness** — cheap on-demand mode on cellular | E-8 | Medium | Low-Mod | Enables the "minimal mobile-data" fallback the code can't express today |
| D | Decide one durability owner (Firestore persistence vs. outbox); treat offline push timeout as "deferred" not a failed attempt | R-7, E-4 | Large | Moderate | Stops double-delivery + false-degraded on offline writes |

**Sequencing note:** items 1–9 are independent and parallelizable. Do **#1 and #5 first** — they are the reliability fallout of today's App Check incident and will most change the "fickle" perception. Do **#2 first** for battery/data — it is the biggest efficiency win and is entirely decoupled from Firestore. Land the dedup (#11) before the delta pull (A) so you have a fallback; A + B are the roadmap items, not this-week items.

**App Check-specific callouts:** #1 (dead listeners stay dark), #5 (error status masks backlog, no retry) and #10 (dead-letters from the outage window) are the three items that determine how the app *recovers* from the incident — they should not wait for the architectural work. And because App Check was suppressing traffic, expect measured reads to **rise** as soon as it's enforced-and-passing; #11 and A are what keep that rise bounded.

---

## 5. What I could and couldn't measure

**Verified directly in this session (high confidence):**
- The periodic-drain connectivity gate (`sync_orchestrator.dart:595`, timer at `:594`) and the twin gate at `:633`.
- `SyncLifecycleObserver` does only `ref.watch(syncOrchestratorProvider)` — no launch pull/drain.
- `TutoredListenerSupervisor` declares `channelCount = 16` and exposes **no** park/unpark.
- The `pointsBalanceDao.syncSink` double-assignment race (`sync_orchestrator_providers.dart:113` without `onEnqueueDrain` vs. `sync_providers.dart:200` with the tee at `:174`).
- Connectivity checker is `InternetConnectionChecker.createInstance()` with **no overrides**, and the pinned `internet_connection_checker-3.0.1` defaults to a **5 s interval** across **3 demo hosts** (`dummyapi.online`, `jsonplaceholder`, `fakestoreapi`) — confirmed from the pub cache. The `checkInterval` is configurable via constructor/setter. → The ~51,840 requests/day figure is arithmetic on confirmed constants (3 × 86,400/5), not a measurement.

**Taken from the investigation's cited file:lines, not independently re-run here (high confidence, but flagged):** the deeper drain/backoff/dead-letter internals (`outbox_processor.dart`, `outbox_dao.dart`), the pull-pipeline no-delta claim, the listener `onError` terminal behavior, and the `backup_sync_section.dart` card-affordance gaps. These are well-cited and internally consistent; I did not open every one.

**Measured Firebase metrics available (from the task, not re-pulled by me):** 42 concurrent snapshot listeners, ~18 real-time listeners per app launch, and low read/write volume — with the explicit caveat that **App Check was blocking traffic until today**, so the read/write numbers are an artificial floor, not steady state.

**What I could NOT measure / confirm, and why it matters:**
- **Actual per-launch Firestore read counts and $ cost.** The double-fetch and full-pull sizes (~2,300 docs for a 1-year user) are analytic estimates from the code, not measured — and they were suppressed by App Check anyway. **Instrument:** wrap pull + listener paths with per-collection read counters and log doc counts per launch/resume, before and after the dedup/delta changes.
- **The connectivity-poll battery/radio cost is invisible to Cloud Monitoring** because it never hits Firestore. The 42-concurrent Firestore number does *not* capture it. **Instrument:** Android Battery Historian + network-stats attribution (or a debug HTTP interceptor counting HEAD/GET to the 3 hosts) to quantify the radio-wake cost and validate the ~99% projected reduction.
- **How many listeners actually errored-and-stayed-dark under the App Check incident.** The terminal-listener bug is confirmed in code, but its real-world hit rate is unmeasured. **Instrument:** count listener `onError` events and (once #1 lands) resubscribe events; alert when a channel is dead > N seconds.
- **Real outbox backlog behavior on users' devices** — depth, oldest-pending age, attempts distribution, time-to-drain, dead-letter counts. **Instrument:** periodic telemetry of `depth`/`stuckCount`/`oldestPendingAt` and a drain-latency histogram; this is the direct signal for whether "pending" is real backlog vs. the false-negative in R-7. (There is a `sync-error-telemetry` agent active in this session that likely overlaps — coordinate.)

**Overclaim guardrails:** the "~2,300 docs / ~1 MB / >10k reads-per-day" figures are illustrative for a heavy, long-tenured user and scale down sharply for new/light users; treat them as order-of-magnitude motivation for the delta-pull work, not committed numbers. Every savings percentage in §3 is an analytic projection to be confirmed by the instrumentation above before it's reported as achieved.