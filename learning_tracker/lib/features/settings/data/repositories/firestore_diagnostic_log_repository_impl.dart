import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';

/// Thrown by [FirestoreDiagnosticLogRepositoryAdapter.pushLog] when
/// `firestoreDiagnosticLogRepositoryProvider` resolves to `null` — the
/// resolve/throw pattern of the points readers (`EnginePointsReader`):
/// a backend that is not ready throws rather than silently doing nothing.
class DiagnosticLogRepositoryNotReadyException implements Exception {
  const DiagnosticLogRepositoryNotReadyException();

  @override
  String toString() =>
      'DiagnosticLogRepositoryNotReadyException: '
      'firestoreDiagnosticLogRepositoryProvider resolved to null (no '
      'active account, yet) — cannot upload diagnostic logs until one is '
      'active.';
}

/// Feature-scoped adapter over [FirestoreDiagnosticLogRepository] --
/// presentation/** (settings_screen.dart, send_logs_service.dart) cannot
/// reach `lib/data/firestore/repository_providers.dart` directly
/// (AD-23/AD-28); this file's own path (`.../data/repositories/`) is the
/// sanctioned seam.
class FirestoreDiagnosticLogRepositoryAdapter {
  FirestoreDiagnosticLogRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  Future<void> pushLog(Map<String, dynamic> data) async {
    final repo = await _ref.read(
      firestoreDiagnosticLogRepositoryProvider.future,
    );
    if (repo == null) {
      throw const DiagnosticLogRepositoryNotReadyException();
    }
    await repo.pushLog(data);
  }
}
