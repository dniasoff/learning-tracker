---
title: "Scrapped: Tutor and School Companion App"
description: Standalone companion app for tutors and schools to manage multiple students. Cut from roadmap 2026-04-19.
status: scrapped
cut_on: 2026-04-19
---

# Scrapped: Tutor and School Companion App

## What the idea was

A **separate application** for tutors and schools to manage multiple students, assign curricula, and track progress across classrooms. The main Learning Tracker app would remain learner-facing; the companion app would provide the management side.

Scope envisioned:

- Multi-student dashboards
- Curriculum assignment to individual students or whole classes
- Cross-student analytics and pace comparisons
- Teacher/tutor account tier with different pricing and auth

## Why it was cut

- Requires a multi-tenant backend, role-based access control, and a separate release pipeline — none of which exist today.
- Paired with the now-scrapped School and Tutor track types ([`school-and-tutor-tracks.md`](school-and-tutor-tracks.md)); without those, the companion app has no connected data model.
- No validated demand from schools or tutors.
- Distracts from the core learner experience.

## What the current roadmap does instead

The active roadmap covers:

- iOS support
- Additional Sefaria-sourced curricula as the library expands
- Ongoing refinement of the existing learner experience

There is no plan to build a standalone tutor/school product.

## Provenance

- Former "Roadmap" entry in `README.md`: *"Tutor and school companion app — a separate app for tutors and schools to manage students..."*
- Former "Upcoming Work" item in `docs/linear-status.md`
