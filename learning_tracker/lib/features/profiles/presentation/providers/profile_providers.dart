import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

/// The current account ID.
///
/// TODO(DNI-110): Replace with actual account ID from auth state once
/// multi-account support is implemented.
@Riverpod(keepAlive: true)
int currentAccountId(Ref ref) => 1;

/// Provider for the ProfileRepository implementation.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  return ProfileRepositoryImpl(db);
}

/// The currently selected profile ID. Null means no profile selected yet.
@Riverpod(keepAlive: true)
class SelectedProfileId extends _$SelectedProfileId {
  @override
  int? build() => null;

  void select(int id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}

/// Profiles for the current account.
@riverpod
Future<List<ProfileModel>> profileList(Ref ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final accountId = ref.watch(currentAccountIdProvider);
  return repo.getProfilesByAccount(accountId);
}

/// Stream of profiles for the current account, for reactive UI.
@riverpod
Stream<List<ProfileModel>> profileListStream(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final accountId = ref.watch(currentAccountIdProvider);
  return db.profileDao
      .watchProfilesByAccount(accountId)
      .map((rows) => rows.map(ProfileModel.fromDriftRow).toList());
}

/// The currently selected profile model.
@riverpod
Future<ProfileModel?> selectedProfile(Ref ref) async {
  final id = ref.watch(selectedProfileIdProvider);
  if (id == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfileById(id);
}
