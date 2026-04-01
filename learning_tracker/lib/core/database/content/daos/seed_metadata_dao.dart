import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/seed_metadata.dart';

part 'seed_metadata_dao.g.dart';

/// Read-only DAO for seed metadata in the ContentDatabase.
@DriftAccessor(tables: [SeedMetadata])
class SeedMetadataDao extends DatabaseAccessor<ContentDatabase>
    with _$SeedMetadataDaoMixin {
  SeedMetadataDao(super.db);

  /// Get the current seed version info.
  Future<SeedMetadataData?> getVersion() =>
      select(seedMetadata).getSingleOrNull();
}
