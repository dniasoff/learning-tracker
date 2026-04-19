# Learning Tracker

An open-source Android app that helps Torah learners stay on track across multiple curricula — with smart scheduling, chazara management, and progress tracking that works offline and syncs across devices.

<!-- Screenshots coming soon -->
<!-- ![Learning Tracker](docs/images/screenshots.png) -->

## The Problem

Learning Torah at scale means juggling multiple subjects, each with their own review cycles and progress markers. You need to remember where you are in Gemara, which Mishna Berurah simanim need chazara, and whether you're on pace to finish by your deadline.

Most people use spreadsheets, paper lists, or memory. It works until it doesn't.

## What Learning Tracker Does

Learning Tracker turns large-scale learning goals into a clear daily plan. You choose your curricula, set your pace, and the app tells you what to learn today — including what needs review and when.

It supports two modes from a single app:

- **For children:** Built-in motivation with points, streaks, and mystery rewards. A PIN-protected parent dashboard lets parents manage rewards and monitor progress.
- **For adults:** A clean, self-directed experience focused on scheduling and progress.

## Supported Curricula

All text is sourced from the [Sefaria](https://www.sefaria.org/) API, bundled with the app at build time so the app works fully offline.

| Curriculum | Category | What's Included |
|---|---|---|
| **Mishnayos** | Oral Law | 4,192 mishnayos across 6 sedarim |
| **Gemara Bavli** | Oral Law | ~2,711 dapim, full Shas |
| **Gemara Yerushalmi** | Oral Law | Full Talmud Yerushalmi |
| **Mishna Berurah** | Law Codes | 697 simanim |
| **Mishneh Torah** | Law Codes | Maimonides' 14-book code of Jewish law |
| **Chumash** | Biblical | 5,845 pesukim across the Five Books |
| **Nach** | Biblical | Prophets and Writings |
| **Tanach** | Biblical | Full Hebrew Bible as one curriculum |
| **Mussar** | Ethics | Multi-sefer library of mussar works |

Activate only what you need. Scope each curriculum to specific sedarim, masechtos, or sefarim.

## Key Features

### Smart daily scheduling

Set a completion deadline (Gregorian or Hebrew calendar) and the scheduler calculates your optimal daily load. It merges all your active curricula into one unified daily task list. No-deadline mode is available for self-paced learning.

### Flexible chazara cycles

Define your own review schedule per curriculum. The default is learn → chazara 1 (+1 day) → chazara 2 (+7 days), but you control the number of stages, their names, and the timing.

### Multiple tracks per curriculum

Run multiple independent tracks within a curriculum — a global program like Daf Yomi in one track, a personal deep-dive in another — each with its own bookmark, scope, and goals.

### Lifetime learning ledger

Every masechta, seder, or sefer you complete is permanently recorded. The ledger tracks your nth siyum on each unit and survives track deletion or curriculum changes.

### Parent mode

PIN-protected. Manage reward catalogs, configure point values, view analytics, and oversee your child's learning.

### Multi-device sync

Sign in with email or Google. Your data syncs across devices with offline-first operation — completions queue locally and push when you're back online.

### Dirshu test tracking

Track test dates, record scores, set reminders, and view performance trends.

## Getting Started

### Requirements

- Flutter SDK 3.38.6+ (stable channel)
- Android SDK (API 21+)
- An Android device or emulator

### Setup

```bash
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Running Tests

```bash
flutter test          # Run all tests
dart analyze          # Static analysis
make ci               # Full CI suite (from repo root)
make help             # See all available commands
```

For detailed setup, workflow, testing, and troubleshooting, see the **[Developer Handbook](docs/developer-handbook.md)**.

## Contributing

Learning Tracker is open source. Contributors of all experience levels are welcome.

1. **Browse open issues** — look for `good first issue` or `help wanted` labels.
2. **Read the docs** — start at [`docs/index.md`](docs/index.md). The [Developer Handbook](docs/developer-handbook.md) covers everything from domain concepts to common tasks.
3. **Pick something and dig in** — the codebase is organized by feature (auth, learning, scheduler, gamification, etc.), so you can focus on one area without understanding the entire app.

Development workflow:

```bash
git checkout -b feature/your-feature dev
make ci                     # verify before submitting
# Open a PR against dev
```

Coding standards live in [`coding-standards.md`](coding-standards.md). The project uses story-based TDD — run `make test-story-X.Y` to validate individual stories.

## Documentation

All documentation is under [`docs/`](docs/). Start at [`docs/index.md`](docs/index.md).

- [Project Overview](docs/project-overview.md)
- [Developer Handbook](docs/developer-handbook.md)
- [Architecture](docs/architecture.md)
- [Data Models](docs/data-models.md)
- [Project Status](docs/linear-status.md)
- [Full PRD](docs/planning/prd.md)

## Roadmap

- **iOS support**
- **Additional curricula** as the Sefaria content library expands
- **Dashboard & Progress Redesign** (Epic 20) — per-track isolation across the dashboard, progress screen, and charts
- **Offline-First Architecture v2** — hard-tier auth refactor to simplify the offline-first model

Parked ideas and cut features are documented under [`docs/_archive/`](docs/_archive/README.md).

## Attribution

Torah text content provided by [Sefaria](https://www.sefaria.org/).

## License

MIT. See [`LICENSE`](LICENSE).
