# Learning Tracker

An open-source Android app that helps Torah learners stay on track across multiple curricula — with smart scheduling, chazara management, and progress tracking that works offline and syncs across devices.

<!-- Screenshots coming soon -->
<!-- ![Learning Tracker](docs/images/screenshots.png) -->

## Table of Contents

- [The Problem](#the-problem)
- [What Learning Tracker Does](#what-learning-tracker-does)
- [Supported Curricula](#supported-curricula)
- [Key Features](#key-features)
- [Getting Started](#getting-started)
- [Contributing](#contributing)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [Attribution](#attribution)
- [License](#license)

## The Problem

Learning Torah at scale means juggling multiple subjects, each with their own review cycles and progress markers. You need to remember where you are in Gemara, which Mishna Berurah simanim need chazara, and whether you're on pace to finish by your deadline — across school, tutoring, and personal learning.

Most people use spreadsheets, paper lists, or memory. It works until it doesn't.

## What Learning Tracker Does

Learning Tracker turns large-scale learning goals into a clear daily plan. You choose your curricula, set your pace, and the app tells you what to learn today — including what needs review and when.

It supports two modes from a single app:

- **For children:** Built-in motivation with points, streaks, and mystery rewards. A PIN-protected parent dashboard lets parents manage rewards and monitor progress.
- **For adults:** A clean, self-directed experience focused on scheduling and progress.

## Supported Curricula

All text is sourced from the [Sefaria](https://www.sefaria.org/) API with Hebrew and English display.

| Curriculum | What's Included |
|---|---|
| **Mishnayos** | All 4,192 mishnayos across 6 sedarim |
| **Gemara Bavli** | ~2,711 dapim, full Shas |
| **Gemara Yerushalmi** | Full Talmud Yerushalmi |
| **Mishna Berurah** | 697 simanim |
| **Chumash** | 5,845 pesukim across all 5 chumashim |
| **Nach** | Full Tanach |
| **Mussar** | Multi-sefer library of mussar works |
| **Halacha** | Halachic works |

Activate only what you need. Scope each curriculum to specific sedarim, masechtos, or sefarim — you track only what you're actually learning.

## Key Features

### Smart Daily Scheduling

Set a completion deadline (Gregorian or Hebrew calendar) and the scheduler calculates your optimal daily load. It merges all your active curricula into one unified daily task list. No-deadline mode is available for self-paced learning.

### Flexible Chazara Cycles

Define your own review schedule per curriculum. The default is learn > chazara 1 (+1 day) > chazara 2 (+7 days), but you control the number of stages, their names, and the timing between them.

### Multi-Track Learning

Run up to three parallel tracks per curriculum — personal, school, and tutor — each with its own bookmark and scope. A child might learn one masechta at school and a different one with a tutor, and the app keeps them separate.

### Lifetime Learning Ledger

Every masechta, seder, or sefer you complete is permanently recorded. The ledger tracks your nth siyum on each unit and survives track deletion or curriculum changes. Your achievements are never lost.

### My Learning Journey

A dedicated screen showing your lifetime achievements across all curricula. See how far you've come ("12 of 63 masechtos"), toggle between chronological and grouped views, and celebrate milestones like completing an entire seder.

### Parent and Tutor Modes

- **Parent mode** (PIN-protected): Manage reward catalogs, configure point values, view analytics, and oversee your child's learning.
- **Tutor mode** (PIN-protected, read-only): View completion history, chazara queues, and progress breakdowns for any student.

### Multi-Device Sync

Sign in with email or Google. Your data syncs across devices with offline-first operation — completions queue locally and push when you're back online.

### Dirshu Test Tracking

Track test dates, record scores, set reminders, and view performance trends.

## Getting Started

### What You Need

- Flutter SDK 3.38.6+ (stable channel)
- Android SDK (API 21+)
- An Android device or emulator

### Setup

```bash
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker

# Install dependencies
flutter pub get

# Generate required code (Drift, Freezed, Riverpod, AutoRoute)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Running Tests

```bash
flutter test          # Run all tests
dart analyze          # Static analysis
make ci               # Full CI suite (from repo root)
make help             # See all available commands
```

## Contributing

Learning Tracker is open source and welcomes contributors of all experience levels.

### Where to Start

1. **Browse open issues** — look for `good first issue` or `help wanted` labels.
2. **Read the quick references** — the [Architecture Quick Reference](_bmad-output/planning-artifacts/architecture-quick-reference.md) covers all the key decisions in one document. The [Testing Quick Reference](_bmad-output/planning-artifacts/testing-quick-reference.md) explains the TDD workflow.
3. **Pick something and dig in** — the codebase is organized by feature (auth, learning, scheduler, gamification, etc.), so you can focus on one area without understanding the entire app.

### Development Workflow

```bash
# Branch from dev
git checkout -b feature/your-feature dev

# Verify everything passes before submitting
make ci

# Open a PR against dev
```

Coding standards are documented in [coding-standards.md](coding-standards.md). The project uses story-based TDD — run `make test-story-X.Y` to validate individual stories.

## Documentation

Detailed planning and design documents are in `_bmad-output/planning-artifacts/`:

- **[Architecture Quick Reference](_bmad-output/planning-artifacts/architecture-quick-reference.md)** — key decisions, patterns, and data models
- **[UX Patterns Quick Reference](_bmad-output/planning-artifacts/ux-patterns-quick-reference.md)** — design system, navigation, and accessibility
- **[Testing Quick Reference](_bmad-output/planning-artifacts/testing-quick-reference.md)** — TDD workflow and test patterns
- **[Full PRD](_bmad-output/planning-artifacts/prd.md)** — complete product requirements
- **[Full Architecture](_bmad-output/planning-artifacts/architecture.md)** — all architectural decisions in detail

## Roadmap

- **Tutor and school companion app** — a separate app for tutors and schools to manage students, assign curricula, and track progress across classrooms. The current app already supports tutor and school tracks per learner; the companion app will provide the management side.
- **iOS support**
- **Additional curricula** as the Sefaria content library expands

## Attribution

Torah text content provided by [Sefaria](https://www.sefaria.org/).

## License

This project is licensed under the [MIT License](LICENSE).
