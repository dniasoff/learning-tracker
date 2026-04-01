/// The bundled seed database version.
///
/// This is updated by the build pipeline when a new seed DB is generated.
/// SeedManager compares this against the installed content.db's
/// SeedMetadata.version to decide if replacement is needed.
const int bundledSeedVersion = 1;
