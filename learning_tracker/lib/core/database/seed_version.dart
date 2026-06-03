/// The bundled seed database version.
///
/// This is updated by the build pipeline when a new seed DB is generated.
/// SeedManager compares this against the installed content.db's
/// SeedMetadata.version to decide if replacement is needed.
///
/// 15 (2026-06-04): the bundled asset gained English translation text
/// (text_cache.english_text) but its baked seed_metadata.version stayed 14, so
/// devices on v14 never re-extracted and the Chumash reader showed no English
/// tab. SeedManager now stamps this constant into the extracted db after a
/// replace, so bumping this value alone is sufficient to force a re-seed (and
/// cannot loop). Bump this whenever the bundled content asset changes.
const int bundledSeedVersion = 15;
