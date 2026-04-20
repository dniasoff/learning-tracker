---
title: "Deprioritized: Tutor Mode (Epic 11)"
description: PIN-protected in-app tutor dashboard. Shipped as Epic 11 and still fully wired in code; removed from active marketing/roadmap on 2026-04-19.
status: deprioritized
shipped_as: Epic 11 (DNI-15)
deprioritized_on: 2026-04-19
---

# Deprioritized: Tutor Mode (Epic 11)

## What shipped

Epic 11 delivered a PIN-protected, read-only in-app mode where a tutor could view a child's completion history, chazara queue, and pace info without being able to modify anything.

Stories delivered (all marked Done in Linear):

- **DNI-65** — 11.1 Tutor PIN Setup & Authentication
- **DNI-66** — 11.2 Tutor Dashboard
- **DNI-67** — 11.3 Completion History Views (Tutor)
- **DNI-68** — 11.4 Chazara Due & Progress Views (Tutor)

Relevant code lives under `lib/features/tutor_mode/` and the `TutorPinGuard` in the router.

## Why it was deprioritized

- Paired with the broader School/Tutor track concept, which is no longer actively promoted (see [`school-and-tutor-tracks.md`](school-and-tutor-tracks.md)).
- No onboarding flow surfaces it.
- No roadmap items extend it.

## What "deprioritized" means in practice

- **Code is intact and active.** All 5 routes (`/tutor-mode`, `/tutor-mode/pin-setup`, `/tutor-mode/pin-entry`, `/tutor-mode/pin-change`, `/tutor-mode/dashboard`) are registered in the router. `TutorPinGuard` gates the protected routes. 7 screens in `lib/features/tutor_mode/presentation/`.
- **Docs still cross-reference it** factually (architecture mentions the feature module) but the README roadmap and project overview don't lead users to it.
- **No new investment.** Bugs in `tutor_mode` are deprioritized. No new stories planned.

If usage data ever shows real tutor adoption, revisit by promoting a fresh roadmap item — don't quietly re-activate.

## Provenance

- Shipped: Epic 11 retrospective in `docs/status/sprint-status.yaml`
- Original epic: `docs/planning/epics.md` §Epic 11 (historical list)
- Code: `lib/features/tutor_mode/`, `lib/core/navigation/guards/tutor_pin_guard.dart`
