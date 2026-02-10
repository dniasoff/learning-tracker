import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/features/content_import/domain/models/import_progress.dart';
import 'package:learning_tracker/features/content_import/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for Sefaria fetchers map.
final sefariaFetchersProvider = Provider<Map<String, CurriculumContentFetcher>>(
  (ref) {
    return {
      CurriculumId.mishnayos.storageKey: ref.watch(mishnaFetcherProvider),
      CurriculumId.bavli.storageKey: ref.watch(bavliFetcherProvider),
      CurriculumId.yerushalmi.storageKey: ref.watch(yerushalmiFetcherProvider),
      CurriculumId.mishnaBerurah.storageKey: ref.watch(
        mishnaBerurahFetcherProvider,
      ),
      CurriculumId.chumash.storageKey: ref.watch(chumashFetcherProvider),
    };
  },
);

/// Provider for curriculum import service.
final curriculumImportServiceProvider = Provider<CurriculumImportService>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  final fetchers = ref.watch(sefariaFetchersProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final logger = ref.watch(talkerProvider);

  return CurriculumImportService(
    database: database,
    fetchers: fetchers,
    syncEngine: syncEngine,
    logger: logger,
  );
});

/// Provider for import progress stream.
final importProgressProvider = StreamProvider<ImportProgress>((ref) {
  final service = ref.watch(curriculumImportServiceProvider);
  return service.progressStream;
});

/// Provider for curriculum import status.
final curriculumImportStatusProvider =
    FutureProvider.family<bool, CurriculumId>((ref, curriculum) {
      final service = ref.watch(curriculumImportServiceProvider);
      return service.isCurriculumImported(curriculum);
    });
