# Seed content DB — from-zero build (local Sefaria Mongo via Docker)

The app ships a pre-built **content database** (`learning_tracker/assets/db/content.db.xz`,
decompressed + bundled as `content.db.gz`) containing all learnable text and the
pre-computed learning calendar. This doc describes how to rebuild it **from
zero**, deterministically, from a **local Sefaria MongoDB dump** loaded via
Docker. There are **no public Sefaria API calls** in the build path.

> TL;DR: `cd learning_tracker && make seed`

## What's in the DB

| Table | Rows (current) | Source |
|---|---|---|
| `text_cache` | 113,273 | Curriculum atomic text (Hebrew + English), keyed by Sefaria ref |
| `calendar_cycles` | 62,068 | Daily learning-program schedule (program × date → ref), computed locally |
| `daily_content` | 15,933 | Pre-resolved bilingual text for every calendar ref (incl. ranges) |
| `seed_metadata` | 1 | version / build id / counts / content hash |

`text_cache` is read for the curriculum reader; `daily_content` is the fallback
the runtime uses when a calendar program's display ref (often a *range* like
`Psalms 97-103`) isn't an atomic `text_cache` key.

## Prerequisites

- **Docker** + `docker compose` (the build runs an official `mongo:7` image).
- The **Sefaria mongodump** on disk. Default location:
  `/home/daniel/repos/sefaria_dump/dump/` (containing `dump/sefaria/texts.bson`,
  `index.bson`, calendar collections, …). Override with the `SEFARIA_DUMP_DIR`
  env var (it is bind-mounted read-only at `/dump`).
- `dart` (for the build tools). `mongo_dart` is a dev-dependency.
- ~5 GB free for the Mongo data volume + ~450 MB for the uncompressed seed DB.

The dump + `mongo_dart` replace the old dependency on a running Sefaria-Project
Python checkout (and the public Sefaria API) — the build needs only the dump
file + Docker.

## Committed source-of-truth inputs

Under `learning_tracker/tool/data/` (committed):

| File | Role |
|---|---|
| `curriculum_books.json` | **The text ref manifest.** curriculum → book → `[atomic Sefaria refs]` for all 15 curricula. 113,431 refs. |
| `hebcal_calendar_cache.json` | date → program → `{en, he, url}` for every calendar program (from `@hebcal/learning`). |
| `sefaria_calendar_cache.json` | Same shape; fills `halakhah_yomit` (hebcal doesn't expose it). |

The large extracted caches — `book_text_cache.json` (~220 MB) and
`daily_content_cache.json` (~750 MB) — are **gitignored build artifacts**,
regenerated from the inputs above by reading the local Mongo.

## The pipeline (`make seed`)

`make seed` is idempotent and runs:

1. **`make seed-mongo-up`** — `docker compose up -d` the `mongo:7` container
   (`tool/seed/docker-compose.yml`), mounting the dump read-only, exposing Mongo
   on `127.0.0.1:27117`; waits for the container healthcheck.
2. **`make seed-restore`** — `mongorestore` the needed collections **only**
   (`--nsInclude`): `texts`, `index`, and the calendar collections. The 2.6 GB
   `links`, `dibur_hamatchils`, `topic_links`, etc. are skipped. Idempotent:
   skips if `texts` is already populated.
3. **`dart run tool/seed/build_text_cache.dart`** — resolves every ref in
   `curriculum_books.json` against Mongo → clean `tool/data/book_text_cache.json`
   (refs with no text dropped).
4. **`dart run tool/seed/build_daily_content.dart`** — resolves every (date,
   program) calendar ref against Mongo → clean `tool/data/daily_content_cache.json`.
5. **`dart run tool/seed_content_db.dart --build --no-resume`** — assembles
   `build/seed.db`: loads `text_cache` from `book_text_cache.json`, generates
   `calendar_cycles` locally, loads `daily_content`, validates cross-references
   (Phase 4c) + curriculum completeness (Phase 4d), writes `seed_metadata`
   (version = `bundledSeedVersion`), and compresses to `assets/db/content.db.xz`.
   (Phases 3 & 4b also pass every fragment through `cleanSefariaText` as a
   defensive net.)
6. **`dart run tool/prepare_asset.dart`** — decompresses the xz and re-compresses
   it as the bundled `content.db.gz`. A final `--validate-only` checks schema +
   row counts.

`make seed-down` stops the container and removes its data volume.

## Sefaria ref → text resolution (`tool/seed/lib/sefaria_mongo.dart`)

Reimplements the slice of Sefaria's `Ref`/`TextChunk` model the seed needs,
reading directly from the `texts` + `index` Mongo collections:

- **Title matching** — longest `index.title` (or any English title *variant*
  from `schema.titles`, e.g. `Mishnah Taanit` → canonical `Mishnah Ta'anit`)
  that prefixes the ref. Variants map back to the canonical title for the
  `texts` lookup.
- **Schema walking** — descend `SchemaNode` children by matching each child's
  English title (or node `key`) as a **longest prefix** of the remaining string
  (node titles can contain commas — "Part One, The Prohibition Against Lashon
  Hara" — and end in numbers — "Principle 10"). `default` nodes are entered
  without consuming a title segment.
- **Address parsing** — per terminal `JaggedArrayNode` `addressTypes`. Every
  address type used by our 15 curricula is **integer-style** (section N → array
  index N-1) EXCEPT **`Talmud`** (daf 2a→index 2, 2b→3, 3a→4 …; the empty
  1a/1b slots 0/1 are why tractates begin at 2a). Ranges (`a-b`,
  cross-section/cross-segment) are flattened and joined.
- **Version selection** — among versions of the requested language, sort by
  `[priority desc, _id asc]` and **merge segment-wise** (first non-empty per
  segment), mirroring Sefaria's default `VersionSet` + `merge_texts`. This is
  what the public API returns by default.
- **Cleaning** — all text routed through `HebrewUtils.cleanSefariaText`, which
  removes Sefaria footnote markup whole (`<sup class="footnote-marker">` +
  `<i class="footnote">` — the BUG-5 corruption) before stripping remaining
  tags/entities.

### English version selected (sample)

| Book | Selected English version (highest priority) |
|---|---|
| Genesis | THE JPS TANAKH: Gender-Sensitive Edition (prio 8) — footnoted; cleaned to "When God began to create heaven and earth—" |
| Talmud (Berakhot …) | William Davidson Edition - English |
| Mishnah | William Davidson Edition - English |
| Mishneh Torah / Shulchan Arukh / Kitzur / Sefer HaMitzvot | the book's highest-priority English version |
| Arukh HaShulchan | (no English version exists — Hebrew only, matching the shipped DB) |

### Daily-content non-canonical resolvers

The calendar entry's `url` carries the canonical Sefaria ref; the `en` display
string (`Berachot 40b`, `Kings Seder 12`, `44:14-45:2`) is a fallback. Plus,
ported from the retired `tool/text_extract/main.py`:

- **`sefer_hamitzvot`** — `Day NN: N353, P149` / `Negative Commandment 353` /
  `Principle 1-3` / `Introduction` → the corresponding
  `Sefer HaMitzvot, …` ref(s), concatenated.
- **`rambam_3_chapters`** cross-book ranges — `Forbidden Intercourse 21-22,
  Forbidden Foods 1` → `Mishneh Torah, <part>` per comma-segment.
- **External fallback** — if a display ref's resolved text comes back empty
  (e.g. dual-book Hilchot ranges Sefaria can't address, reversed ranges), the
  entry is stored with the display strings marked `external: true`, so the
  calendar → daily_content cross-reference (Phase 4c) still resolves and the
  user sees a ref name rather than a blank screen.

## Reproducibility / idempotency

- `make seed` from a clean state: `docker up → mongorestore → build`. The
  restore is skipped if Mongo already has `texts`; re-running rebuilds the
  caches + DB deterministically (sorted keys, fixed version selection).
- The full text build is ~1–2 minutes (Mongo, ~1,000+ refs/s); daily is similar.
  No network, no rate limits.

## Output artifacts & version bump

- `learning_tracker/assets/db/content.db.xz` — committed source-of-truth asset
  (under GitHub's 100 MB limit).
- `learning_tracker/assets/db/content.db.gz` — gitignored, regenerated from the
  xz by `prepare_asset.dart`; bundled into the APK.
- `learning_tracker/build/seed.db` + `seed_version.json` — uncompressed DB +
  sidecar.
- **Version bump:** increment `bundledSeedVersion` in
  `learning_tracker/lib/core/database/seed_version.dart`. `SeedManager` compares
  it against the installed DB's `seed_metadata.version` and atomically replaces
  the on-device DB when the bundled version is higher. Currently **14**.

## Validation checklist (current build, verified)

- `text_cache` rows = 113,273; English non-empty = 67,577; Hebrew = 113,262
- 0 rows with footnote markup; `Genesis 1:1` English == `When God began to create heaven and earth—`
- `daily_content` = 15,933; `calendar_cycles` = 62,068; Phase 4c (every calendar
  ref resolves) and Phase 4d (every curriculum leaf in `text_cache`) both pass
- content hash matches the previously-shipped DB (identical ref set)
