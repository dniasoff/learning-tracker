---
title: "Learning Tracker - Documentation Index"
description: "Master navigation hub for all Learning Tracker project documentation."
date: 2026-03-18
generated_scan_level: "Exhaustive"
generated_mode: "Initial Scan"
---

# Learning Tracker - Documentation Index

## How to Navigate

This page serves as the master navigation hub for all project documentation. Documents fall into four groups:

- **Generated Docs** provide comprehensive analysis of the codebase, architecture, and components.
- **Planning Docs** contain the original product requirements, architecture decisions, and UX patterns.
- **Standards** define coding rules, project setup, and contribution guidelines.
- **WDS Docs** hold design system artifacts, scenarios, and development planning materials.

Start with the [Project Overview](./project-overview.md) for an executive summary, then explore the sections below based on your needs.

## Table of Contents

- [Project Overview](#project-overview)
- [Generated Docs](#generated-docs)
- [Planning Docs](#planning-docs)
- [Standards](#standards)
- [WDS Docs](#wds-docs)
- [Getting Started](#getting-started)
- [Project Status](#project-status)

## Project Overview

- **Type:** Monolith (single Flutter app)
- **Primary Language:** Dart 3.10.8+
- **Framework:** Flutter 3.29.4+
- **Architecture:** Feature-first Clean Architecture (17 feature modules)
- **Database:** Drift (SQLite ORM) — 22 tables, schema v15
- **Backend:** Firebase Auth + Cloud Firestore
- **State Management:** Riverpod 3.x with code generation

### Quick Reference

- **Entry Point:** `lib/main.dart` → AppShell (4-tab bottom nav)
- **Source Files:** ~366 Dart files in `lib/`
- **Test Files:** 182 files, 531+ tests
- **Features:** 17 modules following data/domain/presentation layers
- **Curricula:** 9 Torah learning curricula (Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash, Torah, Tanach, Nach, Mussar)

## Generated Docs

These documents provide a comprehensive analysis of the codebase, generated from an exhaustive scan.

- [Project Overview](./project-overview.md) — Executive summary, tech stack, feature modules, and project status
- [Architecture](./architecture.md) — Architecture decisions (D1-D8), patterns (P1-P6), Mermaid diagrams, and security model
- [Data Models](./data-models.md) — 22-table database schema, ER diagram, DAO operations, and Firestore collections
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure, entry points, and critical paths
- [Component Inventory](./component-inventory.md) — 45 screens, 59 widgets, Riverpod providers, navigation, and theme
- [Development Guide](./development-guide.md) — Setup instructions, Make targets, testing strategy, coding standards, and CI/CD
- [Testing Guide](./testing-guide.md) — Test architecture, how to write tests, fixtures, mocks, and known gotchas
- [Project Status (Linear)](./linear-status.md) — Epic breakdown, story status, and upcoming work from Linear

## Planning Docs

Original planning artifacts live in `_bmad-output/planning-artifacts/`.

- [Full PRD](../_bmad-output/planning-artifacts/prd.md) — Complete product requirements document
- [Full Architecture](../_bmad-output/planning-artifacts/architecture.md) — Detailed architectural decisions and rationale
- [Architecture Quick Reference](../_bmad-output/planning-artifacts/architecture-quick-reference.md) — Key architecture decisions at a glance
- [UX Patterns Quick Reference](../_bmad-output/planning-artifacts/ux-patterns-quick-reference.md) — Design system and navigation patterns
- [Testing Quick Reference](../_bmad-output/planning-artifacts/testing-quick-reference.md) — TDD workflow and test patterns

## Standards

- [Coding Standards](../coding-standards.md) — Cast-iron rules, Clean Code principles, and XP practices
- [Project README](../README.md) — Project overview, getting started, and contributing guidelines
- [App README](../learning_tracker/README.md) — Tech stack, test structure, and CI/CD configuration

## WDS Docs

Design and development planning materials live in `docs/`.

- [Product Brief](./A-Product-Brief/) — Product context and goals
- [Trigger Map](./B-Trigger-Map/) — User psychology mapping
- [Platform Requirements](./C-Platform-Requirements/) — Platform specifications
- [Scenarios](./C-Scenarios/) — UX scenarios and user journeys
- [Design System](./D-Design-System/) — Design tokens and component definitions
- [PRD](./E-PRD/) — Detailed requirements documents
- [Testing](./F-Testing/) — Test planning and strategy
- [Product Development](./G-Product-Development/) — Development artifacts and tracking

## Getting Started

```bash
# Clone and set up
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
make ci                    # Full CI suite (analyze + format + tests)
make test-story-X.Y        # Individual story test
make test-epic-N            # All stories in epic
```

## Project Status

Data sourced from Linear as of 2026-03-18.

| Metric | Value |
|---|---|
| Epics | 15 |
| Stories | 89 |
| Done | 86 |
| In Review | 3 (Epic 14: Settings) |
