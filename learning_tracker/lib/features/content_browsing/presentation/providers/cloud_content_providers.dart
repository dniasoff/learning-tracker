import 'package:learning_tracker/core/database/daos/content_download_status_dao.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_content_providers.g.dart';

/// Provides the CloudContentService (singleton).
@Riverpod(keepAlive: true)
CloudContentService cloudContentService(Ref ref) {
  final storage = ref.watch(firebaseStorageProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return CloudContentService(storage: storage, firestore: firestore);
}

/// Provides the ContentDownloadStatusDao.
@Riverpod(keepAlive: true)
ContentDownloadStatusDao contentDownloadStatusDaoProvider(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.contentDownloadStatusDao;
}
