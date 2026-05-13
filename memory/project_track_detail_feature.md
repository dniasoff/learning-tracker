---
name: Track detail, bulk mark post-setup, per-track ordering
description: Feature sprint completed 2026-05-08 — three stories shipped to internal track
type: project
---

Shipped in commit `0c67bd9c` on dev branch (2026-05-08).

**Story A — TrackDetailScreen**
- New `lib/features/track_setup/presentation/screens/track_detail_screen.dart`
- Route `/settings/tracks/detail` added to `app_router.dart`
- Active track cards in `TrackManagementHubScreen` navigate to it on tap; long-press archive shortcut retained

**Story B — Bulk Mark Post-Setup**
- `BulkPriorCompletionService.execute()` gained `awardGamificationPoints` param (default `false`)
- `BulkMarkScreen` gained same param, threads through to service
- Detail screen loads track scope via `curriculumScopeDao.getScopesByTrack()` and opens BulkMarkScreen with `awardGamificationPoints: true`

**Story C — Per-Track Drag Reorder (schema v7)**
- New table `track_learning_order`, DAO `TrackLearningOrderDao`
- Feature at `lib/features/track_learning_order/` — repository, providers, `TrackLearningOrderScreen`
- Screen has two independent `ReorderableListView` sections: sedarim (level1 containers) and masechtos (level2 containers)
- Reset deletes all custom rows for the track, falls back to canonical content `sort_order`
- Scheduler still reads the global `learning_order` table — per-track scheduler integration is deferred

**Why:** User-requested feature to give per-track content management from a single hub screen.
