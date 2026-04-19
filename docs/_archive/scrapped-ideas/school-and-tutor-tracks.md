---
title: "Deprioritized: School and Tutor Track Types"
description: Three-track learning model (Personal + School + Tutor) from the original PRD. Shipped in code; removed from the v1 onboarding promotion path on 2026-04-19.
status: deprioritized
deprioritized_on: 2026-04-19
---

# Deprioritized: School and Tutor Track Types

## What the idea was

The original product brief (2026-01-03) and PRD v2 (2026-02-08) defined **three parallel track types per curriculum**, all contributing to the same completion goal:

1. **Personal Track (mandatory)** — AI-driven with adaptive scheduler, daily recommendations, automatic chazara scheduling.
2. **School Track (optional)** — Manual progress logging for formal school curriculum. Parent-activated for child accounts.
3. **Tutor Track (optional)** — Manual progress logging for tutoring sessions. Parent-activated for child accounts.

Each track would maintain its own bookmark and separate progress. No content item could appear in multiple tracks simultaneously within the same curriculum.

The intent was to let a child learn Masechta Berachos at school while simultaneously learning a different masechta with a tutor, and a third independently — with the app keeping each stream separate.

## Why it was deprioritized

- Added configuration complexity to onboarding that had no proven demand.
- Multiplied the surface area of every feature (scheduler, completions, progress, dashboard) for a hypothetical use case.
- No production user requested it during Epics 1–21.

## What the current app does

The track-type architecture **did ship** and is still functional in code:

- The `TrackType` enum (`lib/core/enums/track_type.dart`) has all three values: `personal`, `school`, `tutor`.
- The `CurriculumTracks` table supports multiple track types per curriculum per profile.
- The **parent-mode track management screen** (`lib/features/parent_mode/presentation/screens/parent_track_management_screen.dart`) lets parents activate school and tutor tracks on a child's profile.
- Epic 11 Tutor Mode (in-app PIN-protected tutor dashboard) is a separate feature — see [`tutor-mode-epic-11.md`](tutor-mode-epic-11.md).

## What changed on 2026-04-19

- **Onboarding does not expose school/tutor tracks.** The default new-account flow creates a single `personal` track per active curriculum.
- **The roadmap does not promote them.** The v1 marketing and README describe single-track-per-user by default.
- **No new investment.** UX polish for multi-context parents is deprioritized.

If real demand appears from parents managing multi-context learners, re-promote by adding onboarding steps and UX for it — the data model and parent-mode plumbing already exist.

## Provenance

- Enum definition: `lib/core/enums/track_type.dart`
- Parent track management UI: `lib/features/parent_mode/presentation/screens/parent_track_management_screen.dart`
- Former roadmap item in `README.md` (removed)
- Original PRD: [`docs/_archive/superseded/product-brief-2026-01-03.md`](../superseded/product-brief-2026-01-03.md)

## Provenance

- Original: `_bmad-output/planning-artifacts/product-brief-learning-tracker-2026-01-03.md` §Multi-Context Learning
- Original: `_bmad-output/planning-artifacts/prd.md` §Multi-Context Learning
- Former "v2: School and Tutor Tracks" section of `docs/developer-guide.md` (removed)
- Former roadmap item in `README.md` (removed)
