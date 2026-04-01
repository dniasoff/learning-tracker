import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_content_providers.g.dart';

/// Provides the CloudContentService (singleton).
///
/// Retained for potential future use (content updates, text downloads).
@Riverpod(keepAlive: true)
CloudContentService cloudContentService(Ref ref) {
  final storage = ref.watch(firebaseStorageProvider);
  return CloudContentService(storage: storage);
}

/// Provides the TextDownloadStatusDao from UserDatabase.
@Riverpod(keepAlive: true)
TextDownloadStatusDao contentDownloadStatusDaoProvider(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  return db.textDownloadStatusDao;
}
