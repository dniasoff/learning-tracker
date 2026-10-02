/// Firestore implementation for curriculum scopes —
/// `users/{uid}/learner_profiles/{profileId}/curriculum_scopes/{scopeId}`
/// (`DocIds.curriculumScopeDocId`: one doc per curriculum, level and
/// value), the AD-38 governed entity `mainTrackScope`.
///
/// Reads are direct queries; every write is ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476): a field-level merge of the
/// changed docs with `last_change_id` and one co-written `change_log`
/// entry for the curriculum's scope. This class never writes or deletes a
/// document itself.
///
/// ## Set-replace without deletes, atomic or online
///
/// [setScopes] tombstones (`ended_at`) every live selection that is not in
/// the new set and upserts the new ones (a re-selected value is revived);
/// [clearScopes] tombstones them all. Client `delete` is denied (AD-38),
/// and reads skip ended docs. The whole replacement is ONE entity change:
/// up to 10 docs it is one atomic owner batch (offline-capable); above
/// that it goes whole through the online-only `writeWithChangeLog` path
/// (AD-54, Story 1.8) and is refused offline without any partial write.
///
/// ## Fields
///
/// Exactly the AD-52 keys `curriculum_id`, `scope_level`, `scope_value`
/// (+ `ended_at`), so the oversized path accepts them too. `created_at` /
/// `updated_at` / `synced_at` are not written.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_scope.dart';

/// Firestore-backed curriculum-scopes repository (see the library doc
/// comment).
class FirestoreCurriculumScopeRepository {
  FirestoreCurriculumScopeRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    OwnerGovernedWriter? writer,
    AppLogger? logger,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _writer = writer,
       _logger = logger ?? AppLogger.instance,
       _clock = clock ?? DateTimeFactory.nowUtc;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final OwnerGovernedWriter? _writer;
  final AppLogger _logger;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _scopes => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('curriculum_scopes');

  static String _docId(
    CurriculumId curriculumId,
    int scopeLevel,
    String scopeValue,
  ) => DocIds.curriculumScopeDocId({
    'curriculum_id': curriculumId.storageKey,
    'scope_level': scopeLevel,
    'scope_value': scopeValue,
  });

  /// Equality-only filter — no composite index needed.
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _scopes.where('curriculum_id', isEqualTo: curriculumId.storageKey);

  static bool _isLive(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] == null;

  /// Every live scope selection for [curriculumId] (any level, in
  /// document-id order).
  Future<List<CurriculumScopeEntity>> getScopes(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every live document in [docs], skipping (and logging) any
  /// single document whose decode fails.
  List<CurriculumScopeEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <CurriculumScopeEntity>[];
    for (final doc in docs) {
      if (!_isLive(doc.data())) continue;
      try {
        results.add(curriculumScopeFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_curriculum_scopes_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Live updates of [getScopes]. Resubscribes with bounded exponential
  /// backoff if the listener errors (`resilientQueryStream`).
  Stream<List<CurriculumScopeEntity>> watchScopes(CurriculumId curriculumId) {
    return resilientQueryStream<CurriculumScopeEntity?>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) =>
          _isLive(doc.data()) ? curriculumScopeFromFirestore(doc.data()) : null,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_scopes_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map((scopes) => scopes.whereType<CurriculumScopeEntity>().toList());
  }

  /// Live scope values of [curriculumId] as plain strings.
  Future<List<String>> getScopeValues(CurriculumId curriculumId) async {
    final scopes = await getScopes(curriculumId);
    return scopes.map((s) => s.scopeValue).toList();
  }

  /// The scope level of [curriculumId] (from its first live selection), or
  /// `null` if no live scope exists.
  Future<int?> getScopeLevel(CurriculumId curriculumId) async {
    final scopes = await getScopes(curriculumId);
    if (scopes.isEmpty) return null;
    return scopes.first.scopeLevel;
  }

  /// Whether [curriculumId] has any live scope selection.
  Future<bool> hasScopes(CurriculumId curriculumId) async =>
      (await getScopes(curriculumId)).isNotEmpty;

  /// Every live scope selection of this profile (cross-curriculum).
  Future<List<CurriculumScopeEntity>> getAllScopes() async {
    final snapshot = await _scopes.get();
    return _decodeAll(snapshot.docs);
  }

  /// Additively selects [scopes] for [curriculumId] (one logged change);
  /// existing selections are kept.
  Future<void> insertScopes({
    required CurriculumId curriculumId,
    required List<({int level, String value})> scopes,
  }) async {
    if (scopes.isEmpty) return;
    await _apply([
      _change(curriculumId, {
        for (final scope in scopes)
          _docId(curriculumId, scope.level, scope.value): _fields(
            scope.level,
            scope.value,
          ),
      }),
    ]);
  }

  /// Replaces every scope selection of [curriculumId] with [scopeValues]
  /// at [scopeLevel] (one logged change). An empty [scopeValues] clears
  /// the scope (= track the entire curriculum).
  Future<void> setScopes({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    final change = await planSetScopes(
      curriculumId: curriculumId,
      scopes: [for (final v in scopeValues) (level: scopeLevel, value: v)],
    );
    if (change != null) await _apply([change]);
  }

  /// The `mainTrackScope` change that makes [scopes] the curriculum's whole
  /// selection: upserts each, tombstones every other live selection; null
  /// when there is nothing to write. Used by [setScopes] and the
  /// one-action Add track flow (DNI-476 T5).
  Future<GovernedEntityChange?> planSetScopes({
    required CurriculumId curriculumId,
    required List<({int level, String value})> scopes,
  }) async {
    final live = {
      for (final old in await getScopes(curriculumId))
        _docId(curriculumId, old.scopeLevel, old.scopeValue),
    };
    final wanted = {
      for (final scope in scopes)
        _docId(curriculumId, scope.level, scope.value): scope,
    };
    final now = _clock();
    // Only the docs that change: a selection kept as-is is not part of the
    // entity (so it does not count toward the AD-54 batch budget).
    final docs = <String, Map<String, Object?>>{
      for (final id in live)
        if (!wanted.containsKey(id)) id: {GovernedKeys.endedAt: now},
      for (final MapEntry(key: id, value: scope) in wanted.entries)
        if (!live.contains(id)) id: _fields(scope.level, scope.value),
    };
    return docs.isEmpty ? null : _change(curriculumId, docs);
  }

  /// Clears every scope selection of [curriculumId] (= track the entire
  /// curriculum): one logged change tombstoning each live selection.
  Future<void> clearScopes(CurriculumId curriculumId) async {
    final change = await planSetScopes(curriculumId: curriculumId, scopes: []);
    if (change != null) await _apply([change]);
  }

  static Map<String, Object?> _fields(int level, String value) => {
    'scope_level': level,
    'scope_value': value,
    GovernedKeys.endedAt: null,
  };

  static GovernedEntityChange _change(
    CurriculumId curriculumId,
    Map<String, Map<String, Object?>> docs,
  ) => OwnerGovernedIntents.mainTrackDocs(
    entity: GovernedEntity.mainTrackScope,
    curriculumId: curriculumId.storageKey,
    docs: docs,
  );

  Future<void> _apply(List<GovernedEntityChange> changes) async {
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    await applyOwnerAction(writer, GovernedAction(changes));
  }
}
