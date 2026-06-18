# E2E Test Suite — Master Journey Catalog

**Consolidates:** learning+content_browsing audit (J1–J15) + settings audit (J1–J15) + account-auth audit (J1–J16)  
**Scope:** 48 routed `@RoutePage` screens · 53 AutoRoute entries · ~54 dialog/sheet surfaces · 16 feature areas  
**Date:** 2026-06-18 · **Status:** Planning — Wave 1 implementation ready

---

## 1. Coverage Overview

### Screen & route inventory

| Category | Count | Notes |
|---|---|---|
| `@RoutePage`-annotated screen classes | **48** | Includes 3 `PinFlow` variant classes in one file |
| AutoRoute entries in `app_router.dart` | **53** | Includes 4 redirect entries, 1 shell route |
| Routed screens reachable from shell | **44** | Shell itself + 4 tab children + 39 full-screen routes |
| Non-routed screens (Navigator push only) | **3** | `ScopeSelectionScreen`, `GoalSetupScreen`, `LearningProcessWizardScreen` |
| Dialog/sheet surfaces | **~54** | 27 `showDialog` call-sites, 7 `showModalBottomSheet`, ~20 named helper functions |
| Golden-eligible surfaces | **48** | All routed screens; `skipGolden: true` everywhere today — zero baselines |

### Feature areas (16)

| # | Area | Screens | L1 cov% (2026-05-30) | Priority |
|---|---|---|---|---|
| 1 | Auth / Account | SignIn, Signup, AccountPicker, UpgradeToCloud | ~62% | P0 |
| 2 | Onboarding | AppIntro, Onboarding, EmptyLogin, PermissionPrompt, DeviceRestore | ~41% | P0 |
| 3 | Dashboard | DashboardScreen | ~73% | P0 |
| 4 | Learning / Completion | LearningScreen | ~63% | P0 |
| 5 | Content browsing | CurriculumList, ContentHierarchy, ContentSearch, TextDisplay | ~63% | P0–P1 |
| 6 | Progress | Progress, RecentActivity, LifetimeKnowledge, CurriculumProgress, SiyumimMilestones | ~73% | P1 |
| 7 | Settings | Settings, CurriculumSettings, LifetimeMarking, LifetimeCurriculumMarking, ScopeSelection | ~44% | P1 |
| 8 | Tracks | TrackManagementHub, TrackDetail, EditTrack, LearningOrder | ~29% | P1 |
| 9 | Scheduler | Scheduler, StudyDayConfig | ~60% | P1 |
| 10 | Gamification | GamificationHub, ChildRedemption, ParentPendingRedemptions, PointConfig, RewardConfig | ~36% | P1 |
| 11 | Profiles & child mode | ProfilePicker, ManageLearners, ParentSettings, ParentTrackMgmt, PinFlow (×3) | ~39% | P1 |
| 12 | Tutoring | AcceptInvite, DeclineInvite, InviteTutor, ManageTutors, ManageGrants, TutorAuditLog, TutorPinSetup, TutorPinReset | ~17% | P0 (highest risk) |
| 13 | Sync / offline | BackupSyncSection, OfflineTopBanner, SyncStatusIndicator, AppShell-adaptive | ~23% | P1 |
| 14 | Sacred time | CityPicker, SacredTimeLockOverlay | ~50% | P2 |
| 15 | Notifications | NotificationsScreen | ~63% | P2 |
| 16 | Navigation / guards | AuthGuard, RestoreGuard, ProfileGuard, PinGuard, ChildModeGuard | unit-tested | P1 |

### Dimension multipliers

Every journey can be run in one or more of the following dimensions. The journey catalog below notes which dimensions apply per journey. The full Cartesian product is not required — each dimension is stress-tested for at least one journey per feature area.

| Dimension | Values | Multiplier reason |
|---|---|---|
| UI locale | `en` / `he-RTL` | RTL layout, Hebrew curriculum terms, date format locale-aware |
| Network | online / offline | Drift-first; no network-gated UI; outbox queues writes |
| Profile mode | child / adult / tutor-viewing-child | Different screen rows, guards, mark permissions |
| Parent mode | entered (PIN-gated) / not entered | Controls gamification admin, lifetime marking, track mgmt |

---

## 2. Complete Journey Catalog

**Key:**
- **id** — `E2E-NNN` prefix; area code matches § above
- **modes** — `ch`=child · `ad`=adult · `tu`=tutor-as-talmid · `pa`=parent-mode  
- **dims** — `en`=English only · `he`=Hebrew-RTL variant required · `off`=offline variant
- **P** — priority (P0 happy paths first; P1 important paths; P2 edge/variant)
- **seed/pre** — Drift DB state required before the journey starts

### Area 1 — Auth / Account

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-101 | Sign in with email — happy path | P0 | ad | en | SignInScreen renders; submit valid creds → shell lands on Dashboard; authStateProvider = signedIn | No profile yet; Firebase emulator user |
| E2E-102 | Sign in — wrong password error | P0 | ad | en | Error banner appears; button re-enables; no navigation | Same emulator user |
| E2E-103 | Sign-up new account — adult | P0 | ad | en | Signup → onboarding flow starts; account created in Drift | Fresh emulator |
| E2E-104 | Sign-up — 5-account cap enforced | P1 | ad | en | 5th device shows upgrade prompt | Emulator with 4 existing accounts |
| E2E-105 | Account picker — switch account | P1 | ad | en | AccountPickerScreen lists 2 accounts; tap second → shell switches profile | 2 seeded accounts |
| E2E-106 | Upgrade to cloud flow | P1 | ad | en | UpgradeToCloudScreen renders; email→magic link sent; error state mapped from Firebase error code | Local-born account |
| E2E-107 | Sign out via account actions sheet | P1 | ad | en | Swipe up account sheet; tap Sign Out; confirm → returns to intro | Signed-in account |
| E2E-108 | Magic link — cold-start deep link consumed | P1 | ad | en | App cold-starts with email-link URI; MagicLinkService processes; user signed in | AppLinks stub with pending URI |
| E2E-109 | Magic link — warm-start deep link consumed | P2 | ad | en | App in foreground; email-link deep link arrives; user signed in without re-launch | AppLinks stub emitting warm URI |
| E2E-110 | Google Sign-In watchdog — picker abandoned 45s | P2 | ad | en | Google picker held >45s; watchdog fires SignInTimeout; UI shows error; subsequent completion attempt no-ops gracefully | signInWithGoogle stub with 50s delay |

### Area 2 — Onboarding

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-201 | App intro → sign in path | P0 | ad | en | AppIntroScreen shows; tap "Sign in" → SignInScreen | Fresh install |
| E2E-202 | App intro → create account path | P0 | ad | en | Tap "Create account" → SignupScreen | Fresh install |
| E2E-203 | Onboarding adult — create profile | P0 | ad | en | OnboardingScreen; choose Adult; enter name; complete → Dashboard | Signed in, 0 profiles |
| E2E-204 | Onboarding child — create profile + PIN | P0 | ch | en | Choose Child; enter name; set parent PIN → Dashboard in child mode | Signed in, 0 profiles |
| E2E-205 | Empty login screen | P1 | ad | en | EmptyLoginScreen renders for cloud user with 0 profiles; "Add profile" CTA visible | Cloud user, 0 profiles |
| E2E-206 | Permission prompt screen | P1 | ad | en | PermissionPromptScreen renders notification request; grant → proceeds | Post-sign-in |
| E2E-207 | Device restore flow | P1 | ad | en | DeviceRestoreScreen phases render; restore skipped → dashboard | Fresh device, existing cloud data |
| E2E-208 | Onboarding — join as tutor path | P1 | tu | en | OnboardingScreen; "Join as a talmid" path; invite token consumed | AcceptInvite deep link |

### Area 3 — Dashboard

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-301 | Dashboard — populated with today tasks | P0 | ad | en,he | Dashboard renders task cards; carousel shows current curriculum; streak badge visible | 1 active track, seed daily tasks |
| E2E-302 | Dashboard — all caught up empty state | P0 | ad | en | "All caught up" message shown when no pending tasks | 1 active track, all tasks done |
| E2E-303 | Dashboard — offline banner appears | P1 | ad | off | OfflineTopBanner shows when connectivity stub returns false | Seeded Drift; connectivity mock offline |
| E2E-304 | Dashboard — points balance reactive | P1 | ch | en | Child dashboard shows points; redeem → balance decrements live without reload | Child profile, seeded points |
| E2E-305 | Dashboard — parent-mode tile visible for child | P1 | ch,pa | en | "Parent Mode" tile present; tap → PIN entry | Child profile |
| E2E-306 | Dashboard — persistent switcher present on all tabs | P0 | ad | en | Role label bar visible on Dashboard, Learn, Progress, Settings tabs; tap opens switcher sheet | Any active profile |
| E2E-307 | Dashboard — tutor session indicator | P1 | tu | en | Entering tutor session shows talmid name in persistent switcher | Tutor grant accepted |

### Area 4 — Learning / Completion

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-401 | Mark daily task complete — adult | P0 | ad | en | LearningScreen; tap "Mark Complete"; task advances; completionCommittedProvider increments | Active track, seed daily task |
| E2E-402 | Mark daily task — child with celebration | P0 | ch | en | Child completes task; AchievementUnlockCelebration fires if milestone; points update | Child profile, seeded milestone threshold |
| E2E-403 | Skip task then undo | P1 | ad | en | Skip button skips task; Undo restores it to pending | Active track, seed task |
| E2E-404 | Daf-paced track marks multiple refs | P1 | ad | en | coarsePacedTrackIds set; "Mark Complete" marks daf (multiple refs); next task updates | Seed daf-paced track |
| E2E-405 | Chazara task renders only when enabled | P1 | ad | en | Track with stages: chazara section visible; track without stages: chazara section absent | Two tracks: with/without stages |
| E2E-406 | Tutor CANNOT mark live completion | P0 | tu | en | Tutor enters talmid session; "Mark Complete" button absent or disabled on LearningScreen | Tutor grant, active talmid track |
| E2E-407 | Learning screen — offline, tasks from Drift | P1 | ad | off | No network; tasks still appear from local Drift DB; mark completes via outbox | Drift seeded; connectivity offline |
| E2E-408 | Learning screen — Hebrew locale RTL | P1 | ad | he | Learning screen layout correct in RTL; Hebrew curriculum term displayed | Active Mishnah/Talmud track, he locale |

### Area 5 — Content Browsing

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-501 | Browse curricula list | P0 | ad | en | CurriculumListScreen renders available curricula; tap opens ContentHierarchyScreen | Content DB seeded |
| E2E-502 | Navigate content hierarchy to leaf | P0 | ad | en | ContentHierarchyScreen drills to daf/chapter; leaf item navigates to TextDisplayScreen | Content DB with tree |
| E2E-503 | Text display — cached content | P0 | ad | en | TextDisplayScreen renders sefariaRef; text content cached; prev/next arrows work | Content cache seeded |
| E2E-504 | Text display — offline cached | P1 | ad | off | Offline; textContentProvider returns cached; reader renders without network | textContentProvider = cached fixture |
| E2E-505 | Content search | P1 | ad | en | ContentSearchScreen; type query; results appear; tap leaf → TextDisplayScreen | Content DB seeded with searchable items |
| E2E-506 | Content hierarchy — empty state | P1 | ad | en | No content rows → "No content" message (not false-empty race) | Empty content DB |
| E2E-507 | Browse — Hebrew locale curriculum names | P1 | ad | he | Curriculum names render in Hebrew terms (CurriculumLabelRenderer), RTL list | he locale |

### Area 6 — Progress

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-601 | Progress tab — overview | P0 | ad | en | ProgressScreen renders; 3 lens cards visible (Engagement, Achievement, Lifetime) | Seeded completion history |
| E2E-602 | Recent activity screen | P0 | ad | en | RecentActivityRoute renders streak, recent items, no bulk-sentinel dates visible | Seeded streak + completions |
| E2E-603 | Lifetime knowledge screen | P1 | ad | en | LifetimeKnowledgeScreen renders total items; curriculum breakdown | Seeded lifetime completions |
| E2E-604 | Curriculum progress screen | P1 | ad | en | CurriculumProgressScreen renders progress bar; section breakdown | Seed completions for one curriculum |
| E2E-605 | Siyumim & milestones | P1 | ad | en,he | SiyumimMilestonesScreen lists completed siyumim; Hebrew RTL milestone name | Seeded milestone events |
| E2E-606 | Progress — child view (no lifetime editing) | P1 | ch | en | ProgressScreen in child mode; no admin sections visible | Child profile |

### Area 7 — Settings

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-701 | Settings screen — adult row visibility | P0 | ad | en | All adult rows visible (Tracks, Curriculum, Backup, Account); child rows absent | Adult profile |
| E2E-702 | Settings screen — child row visibility | P0 | ch | en | Child rows only; no Sign Out; no Delete Account; no Backup | Child profile |
| E2E-703 | Settings — Backup & Sync card | P1 | ad | en | BackupSyncSection renders sync status; pull triggered on render; status transitions Connecting→Synced | Cloud account; sync mock |
| E2E-704 | Curriculum settings screen | P1 | ad | en | CurriculumSettingsScreen renders for a curriculum; study days, scope, goal configurable | Active track |
| E2E-705 | Lifetime marking — PIN gated | P0 | ad,pa | en | Tap "Add What You Learned" → PIN entry → LifetimeMarkingScreen | Adult profile with parent PIN |
| E2E-706 | Lifetime curriculum marking — bulk mark | P1 | ad,pa | en | LifetimeCurriculumMarkingScreen; select items; save; provider invalidation fires | Parent mode, seeded curriculum |
| E2E-707 | Scope selection | P1 | ad | en | ScopeSelectionScreen pushes via Navigator (not AutoRoute); scope saves; snackbar uses localized strings | Track with scope support |
| E2E-708 | Settings — Hebrew locale tile rendering | P1 | ad | he | Settings tiles render correctly in RTL; no overflow; Hebrew date terms | he locale |
| E2E-709 | Settings — tutor-mode row visibility | P1 | tu | en | Tutoring section appears for adult with tutor grants; absent for child | Adult with accepted grant |

### Area 8 — Tracks

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-801 | Add track — full wizard | P0 | ad | en | TrackManagementHub → Add; choose curriculum → start position → goal → schedule → track created in Drift | Adult, no existing track |
| E2E-802 | Add track — program with chazara stages seeded | P0 | ad | en | Dirshu-preset: track created with stages; stageOrder > 1 means chazara shows | Seeded dirshu preset |
| E2E-803 | Edit track — change goal | P1 | ad | en | TrackDetailScreen → Edit; change daily goal; saved to Drift | Existing track |
| E2E-804 | Edit track — disable chazara inline | P1 | ad | en | ChazaraInlineSetup renders when stages present; clearing removes chazara UI | Track with stages |
| E2E-805 | Track detail — learning order reorder | P1 | ad | en | LearningOrderScreen drag + drop; ReorderConfirmDialog confirms; order persisted | Multi-section track |
| E2E-806 | Track — back-date start → overdue tasks | P1 | ad | en | Set start date 7 days ago; scheduler generates 7 overdue catch-up tasks | clockProvider fixed |
| E2E-807 | Track management — no track type label | P0 | ad | en | No "Personal" / "Standard" / "Custom" label visible anywhere in AddTrackFlow or TrackDetail | Any profile |
| E2E-808 | Track — stage-less track shows no chazara | P0 | ad | en | Track without stages: "No projection" in scheduler; no chazara section in learning; no chazara badge | 0-stage track |

### Area 9 — Scheduler

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-901 | Scheduler — today tasks | P0 | ad | en | SchedulerScreen renders today tasks list; shows projected completion date | Active track, seeded tasks |
| E2E-902 | Scheduler — overdue tasks | P1 | ad | en | SchedulerScreen surfaces overdue tasks at top; "Overdue" label present | clockProvider advanced past due date |
| E2E-903 | Scheduler — chazara review tasks | P1 | ad | en | Chazara section visible when anyActiveTrackHasChazaraProvider = true; absent when false | Stage-enabled track |
| E2E-904 | Study day config — toggle days | P1 | ad | en | StudyDayConfigScreen; toggle Monday off; saves; scheduler respects non-study day | Seeded curriculum |
| E2E-905 | Goal setup screen | P1 | ad | en | GoalSetupScreen (Navigator push, not AutoRoute); set completion date goal; saved | Existing track |

### Area 10 — Gamification

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1001 | Gamification hub — parent view | P0 | ch,pa | en | GamificationScreen renders points balance, rewards list; admin controls visible in parent mode | Child profile, seeded points+rewards |
| E2E-1002 | Child redeem reward — affordable | P0 | ch | en | ChildRedemptionScreen; tap reward with sufficient points; confirm → redemption request created; balance debited | Child, enough points |
| E2E-1003 | Child redeem reward — not affordable | P1 | ch | en | Reward tap shows "Not enough points" feedback; no request created | Child, insufficient points |
| E2E-1004 | Parent approves redemption | P0 | ch,pa | en | ParentPendingRedemptionsScreen shows pending; tap Approve → status = fulfilled; no double-tap race | Pending redemption in Drift |
| E2E-1005 | Parent declines redemption | P1 | ch,pa | en | Decline button → status = declined; balance refunded | Pending redemption in Drift |
| E2E-1006 | Point config — add points manually | P1 | ch,pa | en | PointConfigScreen → AdjustPointsDialog; +50 → balance updates | Child profile, parent mode |
| E2E-1007 | Reward configuration — add/edit/delete reward | P1 | ch,pa | en | RewardConfigurationScreen; add reward with points cost; edit; delete with confirm dialog | Parent mode |
| E2E-1008 | Gamification — child blocked from admin | P0 | ch | en | Child user cannot reach RewardConfig / PointConfig / ParentPendingRedemptions (ChildModeGuard + PinGuard) | Child profile |

### Area 11 — Profiles & Child Mode

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1101 | Profile picker — switch active profile | P0 | ad | en | ProfilePickerScreen lists profiles; tap → switches activeProfileId | 2 profiles seeded |
| E2E-1102 | Add profile from switcher sheet | P0 | ad | en | Persistent switcher → Add Profile → showAddProfileDialog; create child; PIN set | 1 existing profile |
| E2E-1103 | Manage learners screen | P1 | ad | en | ManageLearnersScreen lists child profiles; tap → edit/delete | Adult with child profiles |
| E2E-1104 | Parent settings — tutor permission matrix | P1 | ch,pa | en | ParentSettingsScreen renders permissions matrix; toggle → saved | Child profile, parent mode |
| E2E-1105 | Parent track management | P1 | ch,pa | en | ParentTrackManagementScreen in parent mode; view child tracks | Child profile, parent mode |
| E2E-1106 | PIN flow — set PIN | P0 | ch | en | PinFlowSetupRoute; enter 4-digit PIN; confirm; PIN stored | Child profile |
| E2E-1107 | PIN flow — verify PIN (parent mode entry) | P0 | ch | en | PinFlowVerifyRoute; enter correct PIN → parent mode entered | Child profile with PIN |
| E2E-1108 | PIN flow — change PIN | P1 | ch,pa | en | PinFlowChangeRoute; enter old PIN; enter new PIN twice; success | Child profile, parent mode |
| E2E-1109 | Child mode guard — blocks adult-only screens | P0 | ch | en | ChildModeGuard redirects child from /gamification to ChildRedemption | Child profile |

### Area 12 — Tutoring

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1201 | Invite tutor — send invite | P0 | ad | en | InviteTutorScreen; enter tutor email; send → pending invite created in Firestore | Adult child profile, tutor email |
| E2E-1202 | Accept invite — full 6-step state machine | P0 | tu | en | AcceptInviteScreen; deep-link /invite?token=X; step 1→6; grant accepted; talmid visible | Pending grant, tutor account |
| E2E-1203 | Decline invite | P1 | tu | en | DeclineInviteScreen; confirm → grant declined; talmid not accessible | Pending grant |
| E2E-1204 | Enter talmid session | P0 | tu | en | ManageGrantsScreen; select talmid; enter session → persistent switcher shows talmid name; tutor-mode UI | Accepted grant |
| E2E-1205 | Tutor views talmid tracks/progress (read-only) | P0 | tu | en | Dashboard + Learn screen as tutor; LearningScreen shows no Mark Complete; Progress visible | Active talmid session |
| E2E-1206 | Tutor CANNOT mark live completion (invariant) | P0 | tu | en | LearningScreen: mark button absent; canMarkLiveCompletion = false from VO, use-case, rules, CF | Active talmid session |
| E2E-1207 | Tutor bulk prior marks (past dates only) | P1 | tu | en | Tutor bulk-marks prior items (sentinel date); live-forward dates rejected by CF | tutorBulkPriorCompletions CF |
| E2E-1208 | Manage tutors — revoke grant | P1 | ad | en | ManageTutorsScreen; revoke active tutor; grant status = revoked; talmid disappears from tutor | Active grant |
| E2E-1209 | Tutor audit log | P1 | tu | en | TutorAuditLogScreen renders events; date format locale-aware (DateFormat.yMMMd) | Seeded audit events |
| E2E-1210 | Tutor PIN setup | P1 | tu | en | TutorPinSetupScreen; set tutor PIN; subsequent entry shows TutorPinVerificationDialog | Tutor account |
| E2E-1211 | Tutor PIN reset | P1 | tu | en | TutorPinResetScreen renders; reset confirmed | Tutor with PIN |
| E2E-1212 | Offline tutor grant union (CF + mirror dedup) | P1 | tu | off | Offline: incomingTutorGrantsProvider returns union of CF + mirror, deduped | Drift mirror seeded |
| E2E-1213 | Revoked talmid does NOT resurrect via mirror | P1 | tu | off | Revoked grant: offline mirror does not restore access | Revoked grant, offline |

### Area 13 — Sync / Offline

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1301 | Full sync round-trip (push+pull) | P0 | ad | en | Sign in; mark completion; go offline; go online; sync status shows Synced; data appears on second device | 2 seeded DB instances + emulator |
| E2E-1302 | Offline-first: all shell tabs render offline | P0 | ad | off | Connectivity = offline; Dashboard/Learn/Progress/Settings all render from Drift without hanging | Drift seeded; connectivity mock offline |
| E2E-1303 | Outbox write queued offline → flushed online | P1 | ad | off | Mark task offline; reconnect; outbox row consumed; Firestore doc updated | outbox seeded; emulator |
| E2E-1304 | Sync status indicator — 7 states | P1 | ad | en | BackupSyncSection card shows each SyncStatus subclass: syncing/synced/error/pending/stale/offline/local-only | SyncStatus mocked through each state |
| E2E-1305 | Degraded card — stuck outbox detected | P2 | ad | en | BackupSyncSection._buildDegradedCard appears when outbox row age > threshold | Seeded old outbox row |
| E2E-1306 | Two-device sync — LWW merge | P1 | ad | en | Edit on device A and device B within 5s; merged result matches LWW winner | Two in-memory DBs + DriftMergeStore |

### Area 14 — Sacred Time

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1401 | City picker — select city | P1 | ad | en | CityPickerScreen renders cities; search; tap → city saved | No city set |
| E2E-1402 | Sacred time lock overlay — Shabbos | P2 | ad | en | SacredTimeLockOverlay covers app during Shabbos window; study actions blocked | clockProvider = Shabbos time |
| E2E-1403 | Notification suppressed on Shabbos | P2 | ad | en | Notification not scheduled during Shabbos window | clockProvider = Friday afternoon |

### Area 15 — Notifications

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1501 | Notifications screen — list | P1 | ad | en | NotificationsScreen renders notification items | Seeded notifications |
| E2E-1502 | Notifications — empty state | P2 | ad | en | Empty state message shown | 0 notifications |

### Area 16 — Navigation & Guards

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1601 | Auth guard — unauthenticated redirect | P0 | — | en | Navigating to /dashboard without auth → redirected to /intro | No auth state |
| E2E-1602 | Profile guard — no-profile redirect | P0 | ad | en | Authenticated but 0 profiles → redirected to /onboarding | Auth, 0 profiles |
| E2E-1603 | PIN guard — child-mode screen requires PIN | P0 | ch | en | PinGuard on /parent-mode/settings: no PIN entered → /parent-mode/pin-entry | Child profile, no parent mode |
| E2E-1604 | Child mode guard — redirects child profile | P0 | ch | en | ChildModeGuard on /gamification → child mode → /redeem | Child profile |
| E2E-1605 | Restore guard — fresh device triggers restore | P1 | ad | en | RestoreGuard detects restore-needed → /restore | RestoreGuard = needs-restore |
| E2E-1606 | Guard fail-safe — no lockout on guard exception | P1 | ad | en | Guard throws; top-level try/catch allows navigation to proceed | AuthGuard throws |
| E2E-1607 | Deep link — /invite?token=X routes to AcceptInvite | P0 | tu | en | AcceptInviteRoute has no auth guard; loads without sign-in | Unauthenticated |

**Total journeys: 103**

---

## 3. Implementation Waves

Waves are ordered P0 → P1 → P2 and grouped so each is a reviewable commit batch. All built on the harness described in §5.

### Wave 1 — P0 Happy Paths (target: ~20 journeys)

**Goal:** The most critical user-visible happy paths. Every primary feature reachable in one sitting. CI gate: `flutter test integration_test/`.

| Journey IDs | Area |
|---|---|
| E2E-101, E2E-201, E2E-202 | Auth, Onboarding entry |
| E2E-203, E2E-204 | Onboarding profile creation (adult + child) |
| E2E-301, E2E-306 | Dashboard populated + persistent switcher |
| E2E-401, E2E-402 | Mark complete (adult + child+celebration) |
| E2E-406 | Tutor cannot mark live |
| E2E-501, E2E-502, E2E-503 | Browse → hierarchy → text display |
| E2E-601 | Progress overview |
| E2E-701, E2E-702 | Settings row visibility (adult + child) |
| E2E-801, E2E-802 | Add track wizard + chazara-preset track |
| E2E-807, E2E-808 | No track-type label; no chazara on stage-less track |
| E2E-1001, E2E-1002, E2E-1004 | Gamification hub, redeem, approve |
| E2E-1101, E2E-1106, E2E-1107 | Profile picker, PIN setup + verify |
| E2E-1201, E2E-1202, E2E-1204, E2E-1205, E2E-1206 | Tutoring: invite, accept, enter session, view-only, no-mark invariant |
| E2E-1301, E2E-1302 | Sync round-trip, offline render |
| E2E-1601–E2E-1604, E2E-1607 | Auth/profile/PIN/child guards + deep link |

### Wave 2 — P1 Important Paths (~45 journeys)

All remaining P1 journeys not in Wave 1. Adds dimension variants (offline, he-RTL, tutor). Includes:

- Auth errors, account-picker, upgrade-to-cloud, magic-link cold-start (E2E-102–E2E-109)
- Full onboarding variants, restore (E2E-205–E2E-208)
- Dashboard offline, tutor indicator (E2E-303, E2E-304, E2E-305, E2E-307)
- Learning: skip/undo, daf-paced, offline, he-RTL (E2E-403–E2E-408)
- Content: offline, search, empty state, he (E2E-504–E2E-507)
- All progress sub-screens (E2E-602–E2E-606)
- All settings sub-screens (E2E-703–E2E-709)
- Track edit, order, back-date (E2E-803–E2E-806)
- Scheduler (E2E-901–E2E-905)
- Remaining gamification (E2E-1003, E2E-1005–E2E-1008)
- Profile management (E2E-1102–E2E-1109)
- Tutoring management, bulk marks, audit, PIN (E2E-1207–E2E-1213)
- Sync: outbox, status indicator, LWW (E2E-1303–E2E-1306)
- City picker (E2E-1401)
- Notifications (E2E-1501)
- Guard variants (E2E-1605, E2E-1606)

### Wave 3 — P2 Edge Cases, Dimension Variants, Overflow Guard

- Sacred time lock + notification suppression (E2E-1402, E2E-1403)
- Notifications empty (E2E-1502)
- Sync degraded card (E2E-1305)
- Magic link warm-start + Google watchdog timeout (E2E-109, E2E-110)
- All `he-RTL` dimension variants not already covered
- `expectNoOverflowAcrossDevices` sweep across all 48 screens + all named dialogs
- Golden baselines (en + he-RTL) for all 48 `@RoutePage` screens once baselined on CI

---

## 4. Harness API Summary

All E2E journeys build on the proven in-process harness; the stub `integration_test/app_test.dart` is the on-device entry point.

### Core helpers

```dart
// In-memory Drift DB (test/helpers/drift_memory.dart)
UserDatabase db = inMemoryDb();           // fresh per test
ContentDatabase cdb = createTestContentDatabase();
await seedProfile(db);                    // inserts account + profile id=1
await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');

// Overflow guard (test/helpers/overflow_harness.dart)
await expectNoOverflowAcrossDevices(
  tester,
  () => const MyScreen(),
  overrides: [...],
  locale: const Locale('he'),
);

// Golden runner (test/helpers/golden_runner.dart)
goldenTest(
  'dashboard_populated',
  builder: (locale) => DashboardScreen(),
  skipGolden: false,   // flip to false once baselines committed
);

// Firestore fake (test/helpers/firestore_fake.dart)
// firebase_auth_mocks + fake_cloud_firestore for outbox push tests
```

### Standard Riverpod overrides per feature area

The seams inventory from the two audits is consolidated here. Every E2E test overrides the minimum required set:

```dart
// Auth
authStateProvider.overrideWith((_) => Stream.value(AuthState.signedIn(user, tier))),
currentUserProvider.overrideWith((_) => user),

// Database
userDatabaseProvider.overrideWithValue(db),
appDatabaseProvider.overrideWithValue(db),
contentDatabaseProvider.overrideWithValue(cdb),

// Profile
activeProfileIdProvider.overrideWith((_) => 1),
profileListStreamProvider.overrideWith((_) => Stream.value([profile])),
activeProfileProvider.overrideWith((_) async => profile),

// Connectivity / clock
internetConnectionCheckerProvider.overrideWith((_) => mockChecker),
connectivityServiceProvider.overrideWith((_) => mockConnectivity),
clockProvider.overrideWithValue(fixedDateTime),

// Content
contentRepositoryProvider.overrideWith((_) => stubRepo),
allDailyTasksProvider.overrideWith((_) => AsyncValue.data(seedTasks)),

// Sync
syncStatusProvider.overrideWith((_) => const SyncStatus.synced()),
syncOrchestratorProvider.overrideWith((_) => mockOrchestrator),

// Tutor
activeTutoredProfileSelectionProvider.overrideWith((_) => tutoredSelection),
activeTutorPermissionsProvider.overrideWith((_) => permissions),
incomingTutorGrantsProvider.overrideWith((_) => AsyncValue.data(grants)),

// Gamification
completionCommittedProvider,  // watch + assert increments
markCompletionUseCaseProvider.overrideWith((_) => stubUseCase),
```

### Account-auth specific overrides (from account-auth audit)

```dart
// Magic link — inject fake AppLinks via constructor param
magicLinkInitializationProvider.overrideWith((ref) => Future<void>.value()),
// For cold-start link test: stub AppLinks stream with a pending URI
// appLinksProvider.overrideWith((_) => Stream.value(Uri.parse('https://...')))

// Device registry / account DB
deviceRegistryProvider.overrideWithValue(inMemoryDeviceRegistry),
userDatabaseProvider.overrideWithValue(db),
accountDbFileNameProvider.overrideWithValue('e2e_test.db'),

// Connectivity (internet checker + stream together)
internetConnectionCheckerProvider.overrideWith((_) => fakeChecker),
connectivityStreamProvider.overrideWith((_) => Stream.value(true)),
// Seed helpers for connectivity window fallback:
//   debugSetLastKnownOnline(true) / debugResetLastKnownOnline()

// Tutor grants (offline union: CF + mirror)
incomingTutorGrantsProvider.overrideWith((_) => AsyncValue.data(grants)),
tutorGrantRepositoryProvider.overrideWithValue(stubTutorGrantRepo),

// Firestore gateway (profile fetch on cloud sign-in)
firestoreGatewayProvider.overrideWithValue(stubGateway), // returns []

// Clock (for upgrade/sign-in updatedAt assertions)
// DateTimeFactory.nowUtc() must be overridden via clock injection in test setup

// SharedPreferences keys to pre-seed:
// kOnboardingComplete, kOnboardingSkipped, kIntroSeen, kPermissionsPrompted,
// kMagicLinkPendingEmail, kPendingVerifyEmailOobCode, kMagicLinkPendingDisplayName
```

### Navigation pattern for E2E

```dart
// Route directly to a screen without the full shell
await tester.pumpWidget(
  ProviderScope(
    overrides: [...],
    child: MaterialApp(
      home: const TargetScreen(),
      // or use AutoRouter via routerProvider override
    ),
  ),
);
```

---

## 5. Coverage Matrix — Screen to Journey

Every `@RoutePage` screen must be reached by at least one journey. Screens marked with `[GAP]` have no assigned journey and require closure before Wave 2 can be considered complete.

| Screen (route) | Journey IDs | Notes |
|---|---|---|
| AppIntroScreen (`/intro`) | E2E-201, E2E-202 | |
| SignInScreen (`/sign-in`) | E2E-101, E2E-102 | |
| SignupScreen (`/create-account`) | E2E-103, E2E-104 | |
| AccountPickerScreen (`/account-picker`) | E2E-105 | |
| UpgradeToCloudScreen (`/upgrade-to-cloud`) | E2E-106 | |
| OnboardingScreen (`/onboarding`) | E2E-203, E2E-204, E2E-208 | |
| EmptyLoginScreen (`/empty-login`) | E2E-205 | |
| PermissionPromptScreen (`/permission-prompt`) | E2E-206 | |
| DeviceRestoreScreen (`/restore`) | E2E-207, E2E-1605 | |
| ProfilePickerScreen (`/profile-picker`) | E2E-1101 | |
| ManageLearnersScreen (`/manage-learners`) | E2E-1103 | |
| AppShell (`/`) | E2E-301, E2E-401, E2E-601, E2E-701 | Parent of tab routes |
| DashboardScreen (`/dashboard`) | E2E-301–E2E-307 | |
| LearningScreen (`/learn`) | E2E-401–E2E-408 | |
| ProgressScreen (`/progress`) | E2E-601, E2E-606 | |
| SettingsScreen (`/settings`) | E2E-701, E2E-702, E2E-708, E2E-709 | |
| SiyumimMilestonesScreen (`/journey`) | E2E-605 | |
| RecentActivityScreen (`/progress/recent`) | E2E-602 | |
| LifetimeKnowledgeScreen (`/progress/lifetime`) | E2E-603 | |
| CurriculumListScreen (`/browse`) | E2E-501 | |
| ContentHierarchyScreen (`/curriculum/:id/browse`) | E2E-502, E2E-506 | |
| CurriculumProgressScreen (`/curriculum/:id/progress`) | E2E-604 | |
| CurriculumSettingsScreen (`/curriculum/:id/settings`) | E2E-704 | |
| ContentSearchScreen (`/curriculum/:id/search`) | E2E-505 | |
| TextDisplayScreen (`/text/:sefariaRef`) | E2E-503, E2E-504 | |
| SchedulerScreen (`/scheduler`) | E2E-901, E2E-902, E2E-903 | |
| GamificationScreen (`/gamification`) | E2E-1001 | |
| ChildRedemptionScreen (`/redeem`) | E2E-1002, E2E-1003 | |
| ParentPendingRedemptionsScreen (`/parent-mode/pending-redemptions`) | E2E-1004, E2E-1005 | |
| NotificationsScreen (`/notifications`) | E2E-1501, E2E-1502 | |
| CityPickerScreen (`/sacred-time/city`) | E2E-1401 | |
| ParentSettingsScreen (`/parent-mode/settings`) | E2E-1104 | |
| PointConfigScreen (`/parent-mode/point-config`) | E2E-1006 | |
| RewardConfigurationScreen (`/parent-mode/reward-config`) | E2E-1007 | |
| PinFlowScreen — Setup (`/parent-mode/pin-setup`) | E2E-1106 | |
| PinFlowScreen — Verify (`/parent-mode/pin-entry`) | E2E-1107, E2E-1603 | |
| PinFlowScreen — Change (`/parent-mode/pin-change`) | E2E-1108 | |
| ParentTrackManagementScreen (`/parent-mode/tracks`) | E2E-1105 | |
| StudyDayConfigScreen (`/study-days/:curriculumId`) | E2E-904 | |
| TrackManagementHubScreen (`/settings/tracks`) | E2E-801 | |
| TrackDetailScreen (`/settings/tracks/detail`) | E2E-803 | |
| LifetimeMarkingScreen (`/settings/lifetime`) | E2E-705 | |
| LifetimeCurriculumMarkingScreen (`/settings/lifetime/:curriculumId`) | E2E-706 | |
| LearningOrderScreen (`/curriculum/:id/order`) | E2E-805 | |
| ManageTutorsScreen (`/tutor/manage-tutors`) | E2E-1208 | |
| ManageGrantsScreen (`/tutor/my-grants`) | E2E-1204 | |
| TutorAuditLogScreen (`/tutor/audit-log`) | E2E-1209 | |
| InviteTutorScreen (`/tutor/invite`) | E2E-1201 | |
| AcceptInviteScreen (`/invite`) | E2E-1202, E2E-1607 | |
| DeclineInviteScreen (`/tutor/decline`) | E2E-1203 | |

**Tutoring non-routed screens (shown via Navigator push / dialog within tutor flows):**

| Screen | Journey IDs | Gap / notes |
|---|---|---|
| TutorPinSetupScreen | E2E-1210 | Navigator push from tutoring settings |
| TutorPinResetScreen | E2E-1211 | Navigator push from tutoring settings |
| TutorPinEntryDialog / TutorPinEntryGate | E2E-1210 | Modal gate before talmid session entry |

**Non-routed screens (Navigator push — no AutoRoute path):**

| Screen | Journey IDs | Gap / notes |
|---|---|---|
| ScopeSelectionScreen | E2E-707 | No AutoRoute; no URL; no guard — document intentionally |
| GoalSetupScreen | E2E-905 | Navigator push from SchedulerScreen |
| LearningProcessWizardScreen | [GAP] | Reachable from onboarding wizard; no journey assigned |
| EditTrackScreen | E2E-803, E2E-804 | Push from TrackDetailScreen |
| TrackLearningOrderScreen | [GAP] | Push from TrackDetailScreen "Reorder content"; distinct from LearningOrderScreen |
| BulkMarkScreen | E2E-706 | Push from LifetimeCurriculumMarkingScreen |

**Named dialogs / sheets — every primary dialog covered:**

| Dialog / Sheet | Journey IDs |
|---|---|
| ProfileSwitcherSheet | E2E-306, E2E-1102 |
| showAddProfileDialog | E2E-1102 |
| ProfileEditFormDialog | E2E-1103 |
| showParentPinSetupDialog | E2E-1106 |
| showParentPinVerificationDialog | E2E-1107 |
| showParentPinChangeDialog | E2E-1108 |
| showTutorPinVerificationDialog | E2E-1210 |
| showAccountActionsSheet | E2E-107 |
| showDeleteAccountDialog | E2E-107 |
| showReauthenticateDialog | E2E-107 |
| showChangePasswordDialog | E2E-107 |
| showEmailVerificationDialog | E2E-106 |
| showDeleteDialog (generic) | E2E-1007, E2E-1208 |
| showAdjustPointsDialog | E2E-1006 |
| ReorderConfirmDialog | E2E-805 |
| ResetOrderDialog | E2E-805 |
| AchievementUnlockCelebration | E2E-402 |

**Identified gaps (screens with no assigned journey — close before Wave 2):**

1. `LearningProcessWizardScreen` — onboarding bulk-mark wizard; no journey assigned
2. `TrackLearningOrderScreen` — reorder content within a track; distinct route from `LearningOrderScreen`

---

## 6. Lower-Layer Cross-Reference

The E2E layer (L3 integration_test) owns **through-the-UI journeys**. It does NOT duplicate the contracts tested in lower layers:

| Lower layer | Location | What it tests — E2E does NOT repeat |
|---|---|---|
| **Codec-rules contract** | `test/story_acceptance/epic_25_story_9_lints_test.dart` + custom lints | Layering invariants (no cross-feature imports, Firebase confined to core, Talker confined to logging); compile-time rules |
| **Emulator Firestore rules suite** | `test/` (rules tests via `@firebase/rules-unit-testing`, `make test-rules`) | All 24 Firestore rules paths (read/write matrix per collection, tutor write-block, hasOnly, default-deny); these fire against the security rules file, not the app UI |
| **Cloud Function unit tests** | `functions/test/` via `firebase-functions-test` | All 27 CF auth/state/transition branches (acceptTutorInvite token, tutorBulkPriorCompletions live-forward block, purgeExpiredAuditLogs, etc.) |
| **Merge round-trip tests** | `test/story_acceptance/epic_25_story_13_merge_router_test.dart`, `epic_26_story_23_data_export_round_trip_test.dart`, integration sync tests | DriftMergeStore LWW logic, outbox codec, data export round-trip |
| **Overflow guard tests** | `test/helpers/overflow_harness.dart` + `test/widget/step_overflow_test.dart` | Layout overflow across device matrix — E2E Wave 3 calls the same helper but for new screens not yet in the guard suite |
| **Story acceptance tests** | `test/story_acceptance/epic_*` | Story-level unit/widget behaviour; E2E adds the through-the-router navigation layer on top |

**Boundary rule:** If a bug is caught by the Firestore rules suite (e.g. a tutor trying to write a live completion), the E2E test asserts the UI outcome (button absent) but does NOT re-test the rules path. The E2E test for `canMarkLiveCompletion` (E2E-1206) asserts the UI button is absent; the rules + CF test asserts the server-side rejection. Both must pass.

---

## 7. Known Risks and Flagged Gaps

The audits surfaced the following risks that journey tests should specifically assert against (do not assume existing coverage covers them):

### From learning + content_browsing audit

| # | Risk | Assigned journey | Note |
|---|---|---|---|
| R-LC1 | CurriculumListScreen search button has dead `onPressed: () {}` | E2E-501 | Assert button exists but currently does nothing (P2 known gap) |
| R-LC2 | Recent activity is a static placeholder | E2E-602 | Assert placeholder visible; document intentional |
| R-LC3 | Nikud toggle has no UI button in TextDisplayScreen | E2E-503 | Document as gap; no toggle assertion |
| R-LC4 | ContentHierarchy false-empty race during cold start | E2E-506 | Test empty state after forced cold path |
| R-LC5 | OptimisticCompletionState not rolled back on write failure | E2E-401 | Stub useCase to fail; assert item reverts |
| R-LC6 | OutlinedButton "Next" may point to wrong task on daf-paced track | E2E-404 | Assert next-task pointer after daf mark |
| R-LC7 | Scheduler English-only summary strings (breaks he locale) | E2E-901 he variant | Assert no English literal in he-RTL render |

### From settings audit

| # | Risk | Assigned journey | Note |
|---|---|---|---|
| R-S1 | LifetimeMarkingScreen bypasses PIN guard via MaterialPageRoute | E2E-705 | Assert PIN is requested when child is on device; guard gap exists |
| R-S2 | ScopeSelectionScreen has no AutoRoute registration | E2E-707 | Document; no deep-link; back-button depends on caller |
| R-S3 | CurriculumSettingsScreen leaks raw exception text | E2E-704 error state | Assert no raw exception string in subtitle |
| R-S4 | BackupSyncSection stuck-outbox detection via English string match | E2E-1305 | Assert degraded card appears; fragile coupling flagged |
| R-S5 | showDeleteAccountDialog uses bare showDialog (not showAppDialog) | E2E-107 overflow | Add to overflow guard sweep |
| R-S6 | Sign-out test skipped in epic_14 (contract changed) | E2E-107 | New E2E journey fills the gap |

### From account-auth audit

| # | Risk | Assigned journey | Note |
|---|---|---|---|
| R-AA1 | EmailVerificationConfirmPanel title hardcoded "Confirm Your Email" — not l10n | E2E-106, he variant | Assert Hebrew locale shows localized title, not English literal |
| R-AA2 | UpgradeToCloudScreen._extractFirebaseCode uses simpler regex; wrong-password branch never fires | E2E-106 error | Assert wrong-password error banner appears (not generic fallback) |
| R-AA3 | AccountPickerScreen FutureBuilder re-fires on every rebuild (stale account list) | E2E-105 | Assert second account remains visible after unrelated connectivity change |
| R-AA4 | DeviceRestoreScreen (/restore) has no authGuard — unauthenticated deep link reaches _startRestore() | E2E-207, E2E-1605 | Assert unauthenticated /restore navigates safely to /intro, not crash |
| R-AA5 | OnboardingProfileCreationStep strings "What should we call you?" hardcoded English | E2E-203 he variant | Assert Hebrew locale shows localised label |
| R-AA6 | PendingLocalSignupStore.rollbackIfIncomplete fires on back-pop from onboarding — silent account deletion | E2E-203, E2E-204 abandon | Assert user sees warning or account is not silently deleted when abandoning mid-onboarding |
| R-AA7 | Google Sign-In watchdog fires at 45s but actual Firebase sign-in may succeed after — UI stuck in error state | E2E-110 | Assert UI resets to idle / correct state after watchdog + late completion |
| R-AA8 | EmptyLoginScreen stale account count on second account added/removed while showing | E2E-205 | Assert switch-account icon updates after background account change |
| R-AA9 | signInControllerProvider autoDispose — re-entry during in-flight sign-in creates new controller with no callbacks | E2E-101 concurrency | Assert rapid double sign-in attempt does not crash or navigate incorrectly |
| R-AA10 | AccountLifecycleService.removeCloudFromDevice (soft-remove) leaves no test coverage for re-register same email | E2E-105 | Add sub-case: remove cloud account, re-add same email, confirm new entry created |

---

## 8. Metrics Targets

| Wave | Journeys | New screens covered | Target line cov% |
|---|---|---|---|
| Wave 1 (P0) | ~25 | All 48 reachable | 82% (from 80.1% baseline) |
| Wave 2 (P1) | ~55 | Full dialog/sheet sweep | 87% |
| Wave 3 (P2 + goldens) | ~20 | he-RTL goldens, overflow sweep | 90%+ |

**Definition of "E2E done" for a screen:** at least one journey (a) navigates to the screen through the router, (b) asserts at least one primary button/state, (c) asserts the screen renders in offline mode or documents why offline does not apply, (d) has a `he-RTL` variant or documents why it is content-equivalent to the `en` variant.
