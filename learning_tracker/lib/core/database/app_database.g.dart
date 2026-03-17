// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ActiveCurriculaTable extends ActiveCurricula
    with TableInfo<$ActiveCurriculaTable, ActiveCurriculaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveCurriculaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activatedAtMeta = const VerificationMeta(
    'activatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> activatedAt = GeneratedColumn<DateTime>(
    'activated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, curriculumId, activatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_curricula';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveCurriculaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('activated_at')) {
      context.handle(
        _activatedAtMeta,
        activatedAt.isAcceptableOrUnknown(
          data['activated_at']!,
          _activatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, curriculumId};
  @override
  ActiveCurriculaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveCurriculaData(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      activatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}activated_at'],
      )!,
    );
  }

  @override
  $ActiveCurriculaTable createAlias(String alias) {
    return $ActiveCurriculaTable(attachedDatabase, alias);
  }
}

class ActiveCurriculaData extends DataClass
    implements Insertable<ActiveCurriculaData> {
  final int profileId;

  /// curriculum_id from CurriculumId enum storageKey
  final String curriculumId;

  /// When this curriculum was activated
  final DateTime activatedAt;
  const ActiveCurriculaData({
    required this.profileId,
    required this.curriculumId,
    required this.activatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['activated_at'] = Variable<DateTime>(activatedAt);
    return map;
  }

  ActiveCurriculaCompanion toCompanion(bool nullToAbsent) {
    return ActiveCurriculaCompanion(
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      activatedAt: Value(activatedAt),
    );
  }

  factory ActiveCurriculaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveCurriculaData(
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      activatedAt: serializer.fromJson<DateTime>(json['activatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'activatedAt': serializer.toJson<DateTime>(activatedAt),
    };
  }

  ActiveCurriculaData copyWith({
    int? profileId,
    String? curriculumId,
    DateTime? activatedAt,
  }) => ActiveCurriculaData(
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    activatedAt: activatedAt ?? this.activatedAt,
  );
  ActiveCurriculaData copyWithCompanion(ActiveCurriculaCompanion data) {
    return ActiveCurriculaData(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      activatedAt: data.activatedAt.present
          ? data.activatedAt.value
          : this.activatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveCurriculaData(')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('activatedAt: $activatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, curriculumId, activatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveCurriculaData &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.activatedAt == this.activatedAt);
}

class ActiveCurriculaCompanion extends UpdateCompanion<ActiveCurriculaData> {
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<DateTime> activatedAt;
  final Value<int> rowid;
  const ActiveCurriculaCompanion({
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveCurriculaCompanion.insert({
    this.profileId = const Value.absent(),
    required String curriculumId,
    required DateTime activatedAt,
    this.rowid = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       activatedAt = Value(activatedAt);
  static Insertable<ActiveCurriculaData> custom({
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<DateTime>? activatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveCurriculaCompanion copyWith({
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<DateTime>? activatedAt,
    Value<int>? rowid,
  }) {
    return ActiveCurriculaCompanion(
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      activatedAt: activatedAt ?? this.activatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<DateTime>(activatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveCurriculaCompanion(')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CurriculumTracksTable extends CurriculumTracks
    with TableInfo<$CurriculumTracksTable, CurriculumTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurriculumTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackTypeMeta = const VerificationMeta(
    'trackType',
  );
  @override
  late final GeneratedColumn<String> trackType = GeneratedColumn<String>(
    'track_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _activatedAtMeta = const VerificationMeta(
    'activatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> activatedAt = GeneratedColumn<DateTime>(
    'activated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deactivatedAtMeta = const VerificationMeta(
    'deactivatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deactivatedAt =
      GeneratedColumn<DateTime>(
        'deactivated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    curriculumId,
    trackType,
    isActive,
    activatedAt,
    deactivatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'curriculum_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurriculumTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('track_type')) {
      context.handle(
        _trackTypeMeta,
        trackType.isAcceptableOrUnknown(data['track_type']!, _trackTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_trackTypeMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('activated_at')) {
      context.handle(
        _activatedAtMeta,
        activatedAt.isAcceptableOrUnknown(
          data['activated_at']!,
          _activatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activatedAtMeta);
    }
    if (data.containsKey('deactivated_at')) {
      context.handle(
        _deactivatedAtMeta,
        deactivatedAt.isAcceptableOrUnknown(
          data['deactivated_at']!,
          _deactivatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, curriculumId, trackType};
  @override
  CurriculumTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurriculumTrack(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      trackType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_type'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      activatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}activated_at'],
      )!,
      deactivatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deactivated_at'],
      ),
    );
  }

  @override
  $CurriculumTracksTable createAlias(String alias) {
    return $CurriculumTracksTable(attachedDatabase, alias);
  }
}

class CurriculumTrack extends DataClass implements Insertable<CurriculumTrack> {
  final int profileId;

  /// curriculum_id from CurriculumId enum storageKey
  final String curriculumId;

  /// track_type from TrackType enum storageKey
  final String trackType;

  /// Whether this track is currently active for this curriculum
  final bool isActive;

  /// When this track was activated (or reactivated) for this curriculum
  final DateTime activatedAt;

  /// When this track was last deactivated (null if currently active)
  final DateTime? deactivatedAt;
  const CurriculumTrack({
    required this.profileId,
    required this.curriculumId,
    required this.trackType,
    required this.isActive,
    required this.activatedAt,
    this.deactivatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_type'] = Variable<String>(trackType);
    map['is_active'] = Variable<bool>(isActive);
    map['activated_at'] = Variable<DateTime>(activatedAt);
    if (!nullToAbsent || deactivatedAt != null) {
      map['deactivated_at'] = Variable<DateTime>(deactivatedAt);
    }
    return map;
  }

  CurriculumTracksCompanion toCompanion(bool nullToAbsent) {
    return CurriculumTracksCompanion(
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackType: Value(trackType),
      isActive: Value(isActive),
      activatedAt: Value(activatedAt),
      deactivatedAt: deactivatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deactivatedAt),
    );
  }

  factory CurriculumTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurriculumTrack(
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      activatedAt: serializer.fromJson<DateTime>(json['activatedAt']),
      deactivatedAt: serializer.fromJson<DateTime?>(json['deactivatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'trackType': serializer.toJson<String>(trackType),
      'isActive': serializer.toJson<bool>(isActive),
      'activatedAt': serializer.toJson<DateTime>(activatedAt),
      'deactivatedAt': serializer.toJson<DateTime?>(deactivatedAt),
    };
  }

  CurriculumTrack copyWith({
    int? profileId,
    String? curriculumId,
    String? trackType,
    bool? isActive,
    DateTime? activatedAt,
    Value<DateTime?> deactivatedAt = const Value.absent(),
  }) => CurriculumTrack(
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackType: trackType ?? this.trackType,
    isActive: isActive ?? this.isActive,
    activatedAt: activatedAt ?? this.activatedAt,
    deactivatedAt: deactivatedAt.present
        ? deactivatedAt.value
        : this.deactivatedAt,
  );
  CurriculumTrack copyWithCompanion(CurriculumTracksCompanion data) {
    return CurriculumTrack(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      trackType: data.trackType.present ? data.trackType.value : this.trackType,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      activatedAt: data.activatedAt.present
          ? data.activatedAt.value
          : this.activatedAt,
      deactivatedAt: data.deactivatedAt.present
          ? data.deactivatedAt.value
          : this.deactivatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumTrack(')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('isActive: $isActive, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('deactivatedAt: $deactivatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    curriculumId,
    trackType,
    isActive,
    activatedAt,
    deactivatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurriculumTrack &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackType == this.trackType &&
          other.isActive == this.isActive &&
          other.activatedAt == this.activatedAt &&
          other.deactivatedAt == this.deactivatedAt);
}

class CurriculumTracksCompanion extends UpdateCompanion<CurriculumTrack> {
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> trackType;
  final Value<bool> isActive;
  final Value<DateTime> activatedAt;
  final Value<DateTime?> deactivatedAt;
  final Value<int> rowid;
  const CurriculumTracksCompanion({
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.isActive = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.deactivatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurriculumTracksCompanion.insert({
    this.profileId = const Value.absent(),
    required String curriculumId,
    required String trackType,
    this.isActive = const Value.absent(),
    required DateTime activatedAt,
    this.deactivatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       trackType = Value(trackType),
       activatedAt = Value(activatedAt);
  static Insertable<CurriculumTrack> custom({
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? trackType,
    Expression<bool>? isActive,
    Expression<DateTime>? activatedAt,
    Expression<DateTime>? deactivatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackType != null) 'track_type': trackType,
      if (isActive != null) 'is_active': isActive,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (deactivatedAt != null) 'deactivated_at': deactivatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurriculumTracksCompanion copyWith({
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? trackType,
    Value<bool>? isActive,
    Value<DateTime>? activatedAt,
    Value<DateTime?>? deactivatedAt,
    Value<int>? rowid,
  }) {
    return CurriculumTracksCompanion(
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackType: trackType ?? this.trackType,
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (trackType.present) {
      map['track_type'] = Variable<String>(trackType.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<DateTime>(activatedAt.value);
    }
    if (deactivatedAt.present) {
      map['deactivated_at'] = Variable<DateTime>(deactivatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumTracksCompanion(')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('isActive: $isActive, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('deactivatedAt: $deactivatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StageDefinitionsTable extends StageDefinitions
    with TableInfo<$StageDefinitionsTable, StageDefinition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StageDefinitionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageOrderMeta = const VerificationMeta(
    'stageOrder',
  );
  @override
  late final GeneratedColumn<int> stageOrder = GeneratedColumn<int>(
    'stage_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageNameMeta = const VerificationMeta(
    'stageName',
  );
  @override
  late final GeneratedColumn<String> stageName = GeneratedColumn<String>(
    'stage_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _delayDaysMeta = const VerificationMeta(
    'delayDays',
  );
  @override
  late final GeneratedColumn<int> delayDays = GeneratedColumn<int>(
    'delay_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    stageOrder,
    stageName,
    delayDays,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stage_definitions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StageDefinition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('stage_order')) {
      context.handle(
        _stageOrderMeta,
        stageOrder.isAcceptableOrUnknown(data['stage_order']!, _stageOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_stageOrderMeta);
    }
    if (data.containsKey('stage_name')) {
      context.handle(
        _stageNameMeta,
        stageName.isAcceptableOrUnknown(data['stage_name']!, _stageNameMeta),
      );
    } else if (isInserting) {
      context.missing(_stageNameMeta);
    }
    if (data.containsKey('delay_days')) {
      context.handle(
        _delayDaysMeta,
        delayDays.isAcceptableOrUnknown(data['delay_days']!, _delayDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_delayDaysMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, stageOrder},
  ];
  @override
  StageDefinition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StageDefinition(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      stageOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_order'],
      )!,
      stageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage_name'],
      )!,
      delayDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delay_days'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $StageDefinitionsTable createAlias(String alias) {
    return $StageDefinitionsTable(attachedDatabase, alias);
  }
}

class StageDefinition extends DataClass implements Insertable<StageDefinition> {
  final int id;
  final int profileId;
  final String curriculumId;
  final int stageOrder;
  final String stageName;
  final int delayDays;
  final bool isDefault;
  const StageDefinition({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['stage_order'] = Variable<int>(stageOrder);
    map['stage_name'] = Variable<String>(stageName);
    map['delay_days'] = Variable<int>(delayDays);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  StageDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return StageDefinitionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      stageOrder: Value(stageOrder),
      stageName: Value(stageName),
      delayDays: Value(delayDays),
      isDefault: Value(isDefault),
    );
  }

  factory StageDefinition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StageDefinition(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      stageOrder: serializer.fromJson<int>(json['stageOrder']),
      stageName: serializer.fromJson<String>(json['stageName']),
      delayDays: serializer.fromJson<int>(json['delayDays']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'stageOrder': serializer.toJson<int>(stageOrder),
      'stageName': serializer.toJson<String>(stageName),
      'delayDays': serializer.toJson<int>(delayDays),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  StageDefinition copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? stageOrder,
    String? stageName,
    int? delayDays,
    bool? isDefault,
  }) => StageDefinition(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    stageOrder: stageOrder ?? this.stageOrder,
    stageName: stageName ?? this.stageName,
    delayDays: delayDays ?? this.delayDays,
    isDefault: isDefault ?? this.isDefault,
  );
  StageDefinition copyWithCompanion(StageDefinitionsCompanion data) {
    return StageDefinition(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      stageOrder: data.stageOrder.present
          ? data.stageOrder.value
          : this.stageOrder,
      stageName: data.stageName.present ? data.stageName.value : this.stageName,
      delayDays: data.delayDays.present ? data.delayDays.value : this.delayDays,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StageDefinition(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('stageName: $stageName, ')
          ..write('delayDays: $delayDays, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    stageOrder,
    stageName,
    delayDays,
    isDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StageDefinition &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.stageOrder == this.stageOrder &&
          other.stageName == this.stageName &&
          other.delayDays == this.delayDays &&
          other.isDefault == this.isDefault);
}

class StageDefinitionsCompanion extends UpdateCompanion<StageDefinition> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> stageOrder;
  final Value<String> stageName;
  final Value<int> delayDays;
  final Value<bool> isDefault;
  const StageDefinitionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.stageName = const Value.absent(),
    this.delayDays = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  StageDefinitionsCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    this.isDefault = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       stageOrder = Value(stageOrder),
       stageName = Value(stageName),
       delayDays = Value(delayDays);
  static Insertable<StageDefinition> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? stageOrder,
    Expression<String>? stageName,
    Expression<int>? delayDays,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (stageName != null) 'stage_name': stageName,
      if (delayDays != null) 'delay_days': delayDays,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  StageDefinitionsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? stageOrder,
    Value<String>? stageName,
    Value<int>? delayDays,
    Value<bool>? isDefault,
  }) {
    return StageDefinitionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      stageOrder: stageOrder ?? this.stageOrder,
      stageName: stageName ?? this.stageName,
      delayDays: delayDays ?? this.delayDays,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (stageOrder.present) {
      map['stage_order'] = Variable<int>(stageOrder.value);
    }
    if (stageName.present) {
      map['stage_name'] = Variable<String>(stageName.value);
    }
    if (delayDays.present) {
      map['delay_days'] = Variable<int>(delayDays.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StageDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('stageName: $stageName, ')
          ..write('delayDays: $delayDays, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }
}

class $CompletionsTable extends Completions
    with TableInfo<$CompletionsTable, Completion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sefariaRefMeta = const VerificationMeta(
    'sefariaRef',
  );
  @override
  late final GeneratedColumn<String> sefariaRef = GeneratedColumn<String>(
    'sefaria_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageIdMeta = const VerificationMeta(
    'stageId',
  );
  @override
  late final GeneratedColumn<int> stageId = GeneratedColumn<int>(
    'stage_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackTypeMeta = const VerificationMeta(
    'trackType',
  );
  @override
  late final GeneratedColumn<String> trackType = GeneratedColumn<String>(
    'track_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    sefariaRef,
    stageId,
    trackType,
    completedAt,
    points,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Completion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('stage_id')) {
      context.handle(
        _stageIdMeta,
        stageId.isAcceptableOrUnknown(data['stage_id']!, _stageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stageIdMeta);
    }
    if (data.containsKey('track_type')) {
      context.handle(
        _trackTypeMeta,
        trackType.isAcceptableOrUnknown(data['track_type']!, _trackTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_trackTypeMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Completion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Completion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      stageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_id'],
      )!,
      trackType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_type'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
    );
  }

  @override
  $CompletionsTable createAlias(String alias) {
    return $CompletionsTable(attachedDatabase, alias);
  }
}

class Completion extends DataClass implements Insertable<Completion> {
  final int id;
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;
  final DateTime completedAt;
  final int points;
  const Completion({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    required this.completedAt,
    required this.points,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['stage_id'] = Variable<int>(stageId);
    map['track_type'] = Variable<String>(trackType);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['points'] = Variable<int>(points);
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      sefariaRef: Value(sefariaRef),
      stageId: Value(stageId),
      trackType: Value(trackType),
      completedAt: Value(completedAt),
      points: Value(points),
    );
  }

  factory Completion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Completion(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      stageId: serializer.fromJson<int>(json['stageId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      points: serializer.fromJson<int>(json['points']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'stageId': serializer.toJson<int>(stageId),
      'trackType': serializer.toJson<String>(trackType),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'points': serializer.toJson<int>(points),
    };
  }

  Completion copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? stageId,
    String? trackType,
    DateTime? completedAt,
    int? points,
  }) => Completion(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    stageId: stageId ?? this.stageId,
    trackType: trackType ?? this.trackType,
    completedAt: completedAt ?? this.completedAt,
    points: points ?? this.points,
  );
  Completion copyWithCompanion(CompletionsCompanion data) {
    return Completion(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      stageId: data.stageId.present ? data.stageId.value : this.stageId,
      trackType: data.trackType.present ? data.trackType.value : this.trackType,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      points: data.points.present ? data.points.value : this.points,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Completion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('completedAt: $completedAt, ')
          ..write('points: $points')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    sefariaRef,
    stageId,
    trackType,
    completedAt,
    points,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Completion &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.sefariaRef == this.sefariaRef &&
          other.stageId == this.stageId &&
          other.trackType == this.trackType &&
          other.completedAt == this.completedAt &&
          other.points == this.points);
}

class CompletionsCompanion extends UpdateCompanion<Completion> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> stageId;
  final Value<String> trackType;
  final Value<DateTime> completedAt;
  final Value<int> points;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.stageId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.points = const Value.absent(),
  });
  CompletionsCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required DateTime completedAt,
    this.points = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       sefariaRef = Value(sefariaRef),
       stageId = Value(stageId),
       trackType = Value(trackType),
       completedAt = Value(completedAt);
  static Insertable<Completion> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? sefariaRef,
    Expression<int>? stageId,
    Expression<String>? trackType,
    Expression<DateTime>? completedAt,
    Expression<int>? points,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (stageId != null) 'stage_id': stageId,
      if (trackType != null) 'track_type': trackType,
      if (completedAt != null) 'completed_at': completedAt,
      if (points != null) 'points': points,
    });
  }

  CompletionsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? stageId,
    Value<String>? trackType,
    Value<DateTime>? completedAt,
    Value<int>? points,
  }) {
    return CompletionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      stageId: stageId ?? this.stageId,
      trackType: trackType ?? this.trackType,
      completedAt: completedAt ?? this.completedAt,
      points: points ?? this.points,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (stageId.present) {
      map['stage_id'] = Variable<int>(stageId.value);
    }
    if (trackType.present) {
      map['track_type'] = Variable<String>(trackType.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('completedAt: $completedAt, ')
          ..write('points: $points')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackTypeMeta = const VerificationMeta(
    'trackType',
  );
  @override
  late final GeneratedColumn<String> trackType = GeneratedColumn<String>(
    'track_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sefariaRefMeta = const VerificationMeta(
    'sefariaRef',
  );
  @override
  late final GeneratedColumn<String> sefariaRef = GeneratedColumn<String>(
    'sefaria_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    trackType,
    sefariaRef,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('track_type')) {
      context.handle(
        _trackTypeMeta,
        trackType.isAcceptableOrUnknown(data['track_type']!, _trackTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_trackTypeMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, trackType},
  ];
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      trackType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_type'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int id;
  final int profileId;
  final String curriculumId;
  final String trackType;
  final String sefariaRef;
  final DateTime updatedAt;
  const Bookmark({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackType,
    required this.sefariaRef,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_type'] = Variable<String>(trackType);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackType: Value(trackType),
      sefariaRef: Value(sefariaRef),
      updatedAt: Value(updatedAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'trackType': serializer.toJson<String>(trackType),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bookmark copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? trackType,
    String? sefariaRef,
    DateTime? updatedAt,
  }) => Bookmark(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackType: trackType ?? this.trackType,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      trackType: data.trackType.present ? data.trackType.value : this.trackType,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    trackType,
    sefariaRef,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackType == this.trackType &&
          other.sefariaRef == this.sefariaRef &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> trackType;
  final Value<String> sefariaRef;
  final Value<DateTime> updatedAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required String trackType,
    required String sefariaRef,
    required DateTime updatedAt,
  }) : curriculumId = Value(curriculumId),
       trackType = Value(trackType),
       sefariaRef = Value(sefariaRef),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? trackType,
    Expression<String>? sefariaRef,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackType != null) 'track_type': trackType,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? trackType,
    Value<String>? sefariaRef,
    Value<DateTime>? updatedAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackType: trackType ?? this.trackType,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (trackType.present) {
      map['track_type'] = Variable<String>(trackType.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPercentMeta = const VerificationMeta(
    'targetPercent',
  );
  @override
  late final GeneratedColumn<double> targetPercent = GeneratedColumn<double>(
    'target_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100.0),
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateTypeMeta = const VerificationMeta(
    'dateType',
  );
  @override
  late final GeneratedColumn<String> dateType = GeneratedColumn<String>(
    'date_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('gregorian'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    targetPercent,
    targetDate,
    description,
    dateType,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('target_percent')) {
      context.handle(
        _targetPercentMeta,
        targetPercent.isAcceptableOrUnknown(
          data['target_percent']!,
          _targetPercentMeta,
        ),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('date_type')) {
      context.handle(
        _dateTypeMeta,
        dateType.isAcceptableOrUnknown(data['date_type']!, _dateTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      targetPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_percent'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      dateType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  final int id;
  final int profileId;
  final String curriculumId;
  final double targetPercent;
  final DateTime? targetDate;
  final String description;
  final String dateType;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Goal({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.targetPercent,
    this.targetDate,
    required this.description,
    required this.dateType,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['target_percent'] = Variable<double>(targetPercent);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['description'] = Variable<String>(description);
    map['date_type'] = Variable<String>(dateType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      targetPercent: Value(targetPercent),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      description: Value(description),
      dateType: Value(dateType),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      targetPercent: serializer.fromJson<double>(json['targetPercent']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      description: serializer.fromJson<String>(json['description']),
      dateType: serializer.fromJson<String>(json['dateType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'targetPercent': serializer.toJson<double>(targetPercent),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'description': serializer.toJson<String>(description),
      'dateType': serializer.toJson<String>(dateType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Goal copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    double? targetPercent,
    Value<DateTime?> targetDate = const Value.absent(),
    String? description,
    String? dateType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Goal(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    targetPercent: targetPercent ?? this.targetPercent,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    description: description ?? this.description,
    dateType: dateType ?? this.dateType,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      targetPercent: data.targetPercent.present
          ? data.targetPercent.value
          : this.targetPercent,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      dateType: data.dateType.present ? data.dateType.value : this.dateType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('targetPercent: $targetPercent, ')
          ..write('targetDate: $targetDate, ')
          ..write('description: $description, ')
          ..write('dateType: $dateType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    targetPercent,
    targetDate,
    description,
    dateType,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.targetPercent == this.targetPercent &&
          other.targetDate == this.targetDate &&
          other.description == this.description &&
          other.dateType == this.dateType &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<double> targetPercent;
  final Value<DateTime?> targetDate;
  final Value<String> description;
  final Value<String> dateType;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.targetPercent = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.description = const Value.absent(),
    this.dateType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    this.targetPercent = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.description = const Value.absent(),
    this.dateType = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : curriculumId = Value(curriculumId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Goal> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<double>? targetPercent,
    Expression<DateTime>? targetDate,
    Expression<String>? description,
    Expression<String>? dateType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (targetPercent != null) 'target_percent': targetPercent,
      if (targetDate != null) 'target_date': targetDate,
      if (description != null) 'description': description,
      if (dateType != null) 'date_type': dateType,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GoalsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<double>? targetPercent,
    Value<DateTime?>? targetDate,
    Value<String>? description,
    Value<String>? dateType,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      targetPercent: targetPercent ?? this.targetPercent,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
      dateType: dateType ?? this.dateType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (targetPercent.present) {
      map['target_percent'] = Variable<double>(targetPercent.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (dateType.present) {
      map['date_type'] = Variable<String>(dateType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('targetPercent: $targetPercent, ')
          ..write('targetDate: $targetDate, ')
          ..write('description: $description, ')
          ..write('dateType: $dateType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LearningOrderTable extends LearningOrder
    with TableInfo<$LearningOrderTable, LearningOrderData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningOrderTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sefariaRefMeta = const VerificationMeta(
    'sefariaRef',
  );
  @override
  late final GeneratedColumn<String> sefariaRef = GeneratedColumn<String>(
    'sefaria_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userSortOrderMeta = const VerificationMeta(
    'userSortOrder',
  );
  @override
  late final GeneratedColumn<int> userSortOrder = GeneratedColumn<int>(
    'user_sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    sefariaRef,
    userSortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_order';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningOrderData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('user_sort_order')) {
      context.handle(
        _userSortOrderMeta,
        userSortOrder.isAcceptableOrUnknown(
          data['user_sort_order']!,
          _userSortOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userSortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, sefariaRef},
  ];
  @override
  LearningOrderData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningOrderData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      userSortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_sort_order'],
      )!,
    );
  }

  @override
  $LearningOrderTable createAlias(String alias) {
    return $LearningOrderTable(attachedDatabase, alias);
  }
}

class LearningOrderData extends DataClass
    implements Insertable<LearningOrderData> {
  final int id;
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int userSortOrder;
  const LearningOrderData({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.userSortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['user_sort_order'] = Variable<int>(userSortOrder);
    return map;
  }

  LearningOrderCompanion toCompanion(bool nullToAbsent) {
    return LearningOrderCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      sefariaRef: Value(sefariaRef),
      userSortOrder: Value(userSortOrder),
    );
  }

  factory LearningOrderData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningOrderData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      userSortOrder: serializer.fromJson<int>(json['userSortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'userSortOrder': serializer.toJson<int>(userSortOrder),
    };
  }

  LearningOrderData copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? userSortOrder,
  }) => LearningOrderData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    userSortOrder: userSortOrder ?? this.userSortOrder,
  );
  LearningOrderData copyWithCompanion(LearningOrderCompanion data) {
    return LearningOrderData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      userSortOrder: data.userSortOrder.present
          ? data.userSortOrder.value
          : this.userSortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningOrderData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('userSortOrder: $userSortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, curriculumId, sefariaRef, userSortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningOrderData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.sefariaRef == this.sefariaRef &&
          other.userSortOrder == this.userSortOrder);
}

class LearningOrderCompanion extends UpdateCompanion<LearningOrderData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> userSortOrder;
  const LearningOrderCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.userSortOrder = const Value.absent(),
  });
  LearningOrderCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required String sefariaRef,
    required int userSortOrder,
  }) : curriculumId = Value(curriculumId),
       sefariaRef = Value(sefariaRef),
       userSortOrder = Value(userSortOrder);
  static Insertable<LearningOrderData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? sefariaRef,
    Expression<int>? userSortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (userSortOrder != null) 'user_sort_order': userSortOrder,
    });
  }

  LearningOrderCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? userSortOrder,
  }) {
    return LearningOrderCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      userSortOrder: userSortOrder ?? this.userSortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (userSortOrder.present) {
      map['user_sort_order'] = Variable<int>(userSortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningOrderCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('userSortOrder: $userSortOrder')
          ..write(')'))
        .toString();
  }
}

class $PointConfigsTable extends PointConfigs
    with TableInfo<$PointConfigsTable, PointConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageOrderMeta = const VerificationMeta(
    'stageOrder',
  );
  @override
  late final GeneratedColumn<int> stageOrder = GeneratedColumn<int>(
    'stage_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (points > 0)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    stageOrder,
    points,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'point_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PointConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('stage_order')) {
      context.handle(
        _stageOrderMeta,
        stageOrder.isAcceptableOrUnknown(data['stage_order']!, _stageOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_stageOrderMeta);
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, stageOrder},
  ];
  @override
  PointConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PointConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      stageOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_order'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
    );
  }

  @override
  $PointConfigsTable createAlias(String alias) {
    return $PointConfigsTable(attachedDatabase, alias);
  }
}

class PointConfig extends DataClass implements Insertable<PointConfig> {
  final int id;
  final int profileId;
  final String curriculumId;
  final int stageOrder;
  final int points;
  const PointConfig({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.stageOrder,
    required this.points,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['stage_order'] = Variable<int>(stageOrder);
    map['points'] = Variable<int>(points);
    return map;
  }

  PointConfigsCompanion toCompanion(bool nullToAbsent) {
    return PointConfigsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      stageOrder: Value(stageOrder),
      points: Value(points),
    );
  }

  factory PointConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PointConfig(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      stageOrder: serializer.fromJson<int>(json['stageOrder']),
      points: serializer.fromJson<int>(json['points']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'stageOrder': serializer.toJson<int>(stageOrder),
      'points': serializer.toJson<int>(points),
    };
  }

  PointConfig copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? stageOrder,
    int? points,
  }) => PointConfig(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    stageOrder: stageOrder ?? this.stageOrder,
    points: points ?? this.points,
  );
  PointConfig copyWithCompanion(PointConfigsCompanion data) {
    return PointConfig(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      stageOrder: data.stageOrder.present
          ? data.stageOrder.value
          : this.stageOrder,
      points: data.points.present ? data.points.value : this.points,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PointConfig(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('points: $points')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, curriculumId, stageOrder, points);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointConfig &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.stageOrder == this.stageOrder &&
          other.points == this.points);
}

class PointConfigsCompanion extends UpdateCompanion<PointConfig> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> stageOrder;
  final Value<int> points;
  const PointConfigsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.points = const Value.absent(),
  });
  PointConfigsCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required int stageOrder,
    required int points,
  }) : curriculumId = Value(curriculumId),
       stageOrder = Value(stageOrder),
       points = Value(points);
  static Insertable<PointConfig> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? stageOrder,
    Expression<int>? points,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (points != null) 'points': points,
    });
  }

  PointConfigsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? stageOrder,
    Value<int>? points,
  }) {
    return PointConfigsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      stageOrder: stageOrder ?? this.stageOrder,
      points: points ?? this.points,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (stageOrder.present) {
      map['stage_order'] = Variable<int>(stageOrder.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointConfigsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('points: $points')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarIndexMeta = const VerificationMeta(
    'avatarIndex',
  );
  @override
  late final GeneratedColumn<int> avatarIndex = GeneratedColumn<int>(
    'avatar_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    displayName,
    mode,
    avatarIndex,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('avatar_index')) {
      context.handle(
        _avatarIndexMeta,
        avatarIndex.isAcceptableOrUnknown(
          data['avatar_index']!,
          _avatarIndexMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      avatarIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avatar_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final int id;
  final int accountId;
  final String displayName;
  final String mode;
  final int avatarIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Profile({
    required this.id,
    required this.accountId,
    required this.displayName,
    required this.mode,
    required this.avatarIndex,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['display_name'] = Variable<String>(displayName);
    map['mode'] = Variable<String>(mode);
    map['avatar_index'] = Variable<int>(avatarIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      displayName: Value(displayName),
      mode: Value(mode),
      avatarIndex: Value(avatarIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      mode: serializer.fromJson<String>(json['mode']),
      avatarIndex: serializer.fromJson<int>(json['avatarIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'displayName': serializer.toJson<String>(displayName),
      'mode': serializer.toJson<String>(mode),
      'avatarIndex': serializer.toJson<int>(avatarIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Profile copyWith({
    int? id,
    int? accountId,
    String? displayName,
    String? mode,
    int? avatarIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Profile(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    displayName: displayName ?? this.displayName,
    mode: mode ?? this.mode,
    avatarIndex: avatarIndex ?? this.avatarIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      mode: data.mode.present ? data.mode.value : this.mode,
      avatarIndex: data.avatarIndex.present
          ? data.avatarIndex.value
          : this.avatarIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('displayName: $displayName, ')
          ..write('mode: $mode, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    displayName,
    mode,
    avatarIndex,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.displayName == this.displayName &&
          other.mode == this.mode &&
          other.avatarIndex == this.avatarIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> displayName;
  final Value<String> mode;
  final Value<int> avatarIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.mode = const Value.absent(),
    this.avatarIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String displayName,
    required String mode,
    this.avatarIndex = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : accountId = Value(accountId),
       displayName = Value(displayName),
       mode = Value(mode),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Profile> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? displayName,
    Expression<String>? mode,
    Expression<int>? avatarIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (displayName != null) 'display_name': displayName,
      if (mode != null) 'mode': mode,
      if (avatarIndex != null) 'avatar_index': avatarIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? displayName,
    Value<String>? mode,
    Value<int>? avatarIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      displayName: displayName ?? this.displayName,
      mode: mode ?? this.mode,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (avatarIndex.present) {
      map['avatar_index'] = Variable<int>(avatarIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('displayName: $displayName, ')
          ..write('mode: $mode, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _firebaseUidMeta = const VerificationMeta(
    'firebaseUid',
  );
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
    'firebase_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userModeMeta = const VerificationMeta(
    'userMode',
  );
  @override
  late final GeneratedColumn<String> userMode = GeneratedColumn<String>(
    'user_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    firebaseUid,
    displayName,
    userMode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
        _firebaseUidMeta,
        firebaseUid.isAcceptableOrUnknown(
          data['firebase_uid']!,
          _firebaseUidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('user_mode')) {
      context.handle(
        _userModeMeta,
        userMode.isAcceptableOrUnknown(data['user_mode']!, _userModeMeta),
      );
    } else if (isInserting) {
      context.missing(_userModeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      firebaseUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firebase_uid'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      userMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_mode'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final String firebaseUid;
  final String displayName;
  final String userMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserProfile({
    required this.id,
    required this.firebaseUid,
    required this.displayName,
    required this.userMode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['firebase_uid'] = Variable<String>(firebaseUid);
    map['display_name'] = Variable<String>(displayName);
    map['user_mode'] = Variable<String>(userMode);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      firebaseUid: Value(firebaseUid),
      displayName: Value(displayName),
      userMode: Value(userMode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      displayName: serializer.fromJson<String>(json['displayName']),
      userMode: serializer.fromJson<String>(json['userMode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'displayName': serializer.toJson<String>(displayName),
      'userMode': serializer.toJson<String>(userMode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfile copyWith({
    int? id,
    String? firebaseUid,
    String? displayName,
    String? userMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id ?? this.id,
    firebaseUid: firebaseUid ?? this.firebaseUid,
    displayName: displayName ?? this.displayName,
    userMode: userMode ?? this.userMode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      firebaseUid: data.firebaseUid.present
          ? data.firebaseUid.value
          : this.firebaseUid,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      userMode: data.userMode.present ? data.userMode.value : this.userMode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('displayName: $displayName, ')
          ..write('userMode: $userMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, firebaseUid, displayName, userMode, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.firebaseUid == this.firebaseUid &&
          other.displayName == this.displayName &&
          other.userMode == this.userMode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> firebaseUid;
  final Value<String> displayName;
  final Value<String> userMode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.displayName = const Value.absent(),
    this.userMode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String firebaseUid,
    required String displayName,
    required String userMode,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : firebaseUid = Value(firebaseUid),
       displayName = Value(displayName),
       userMode = Value(userMode),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? firebaseUid,
    Expression<String>? displayName,
    Expression<String>? userMode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (displayName != null) 'display_name': displayName,
      if (userMode != null) 'user_mode': userMode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? firebaseUid,
    Value<String>? displayName,
    Value<String>? userMode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      displayName: displayName ?? this.displayName,
      userMode: userMode ?? this.userMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (userMode.present) {
      map['user_mode'] = Variable<String>(userMode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('displayName: $displayName, ')
          ..write('userMode: $userMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RewardsTable extends Rewards with TableInfo<$RewardsTable, Reward> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsThresholdMeta = const VerificationMeta(
    'pointsThreshold',
  );
  @override
  late final GeneratedColumn<int> pointsThreshold = GeneratedColumn<int>(
    'points_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRevealedMeta = const VerificationMeta(
    'isRevealed',
  );
  @override
  late final GeneratedColumn<bool> isRevealed = GeneratedColumn<bool>(
    'is_revealed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_revealed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEarnedMeta = const VerificationMeta(
    'isEarned',
  );
  @override
  late final GeneratedColumn<bool> isEarned = GeneratedColumn<bool>(
    'is_earned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_earned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _earnedAtMeta = const VerificationMeta(
    'earnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> earnedAt = GeneratedColumn<DateTime>(
    'earned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    title,
    description,
    pointsThreshold,
    isRevealed,
    isEarned,
    earnedAt,
    createdAt,
    updatedAt,
    curriculumId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rewards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reward> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('points_threshold')) {
      context.handle(
        _pointsThresholdMeta,
        pointsThreshold.isAcceptableOrUnknown(
          data['points_threshold']!,
          _pointsThresholdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pointsThresholdMeta);
    }
    if (data.containsKey('is_revealed')) {
      context.handle(
        _isRevealedMeta,
        isRevealed.isAcceptableOrUnknown(data['is_revealed']!, _isRevealedMeta),
      );
    }
    if (data.containsKey('is_earned')) {
      context.handle(
        _isEarnedMeta,
        isEarned.isAcceptableOrUnknown(data['is_earned']!, _isEarnedMeta),
      );
    }
    if (data.containsKey('earned_at')) {
      context.handle(
        _earnedAtMeta,
        earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reward map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reward(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      pointsThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_threshold'],
      )!,
      isRevealed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_revealed'],
      )!,
      isEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_earned'],
      )!,
      earnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}earned_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      ),
    );
  }

  @override
  $RewardsTable createAlias(String alias) {
    return $RewardsTable(attachedDatabase, alias);
  }
}

class Reward extends DataClass implements Insertable<Reward> {
  final int id;
  final int profileId;
  final String title;
  final String description;
  final int pointsThreshold;
  final bool isRevealed;
  final bool isEarned;
  final DateTime? earnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? curriculumId;
  const Reward({
    required this.id,
    required this.profileId,
    required this.title,
    required this.description,
    required this.pointsThreshold,
    required this.isRevealed,
    required this.isEarned,
    this.earnedAt,
    required this.createdAt,
    required this.updatedAt,
    this.curriculumId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['points_threshold'] = Variable<int>(pointsThreshold);
    map['is_revealed'] = Variable<bool>(isRevealed);
    map['is_earned'] = Variable<bool>(isEarned);
    if (!nullToAbsent || earnedAt != null) {
      map['earned_at'] = Variable<DateTime>(earnedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || curriculumId != null) {
      map['curriculum_id'] = Variable<String>(curriculumId);
    }
    return map;
  }

  RewardsCompanion toCompanion(bool nullToAbsent) {
    return RewardsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      title: Value(title),
      description: Value(description),
      pointsThreshold: Value(pointsThreshold),
      isRevealed: Value(isRevealed),
      isEarned: Value(isEarned),
      earnedAt: earnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(earnedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      curriculumId: curriculumId == null && nullToAbsent
          ? const Value.absent()
          : Value(curriculumId),
    );
  }

  factory Reward.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reward(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      pointsThreshold: serializer.fromJson<int>(json['pointsThreshold']),
      isRevealed: serializer.fromJson<bool>(json['isRevealed']),
      isEarned: serializer.fromJson<bool>(json['isEarned']),
      earnedAt: serializer.fromJson<DateTime?>(json['earnedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      curriculumId: serializer.fromJson<String?>(json['curriculumId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'pointsThreshold': serializer.toJson<int>(pointsThreshold),
      'isRevealed': serializer.toJson<bool>(isRevealed),
      'isEarned': serializer.toJson<bool>(isEarned),
      'earnedAt': serializer.toJson<DateTime?>(earnedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'curriculumId': serializer.toJson<String?>(curriculumId),
    };
  }

  Reward copyWith({
    int? id,
    int? profileId,
    String? title,
    String? description,
    int? pointsThreshold,
    bool? isRevealed,
    bool? isEarned,
    Value<DateTime?> earnedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> curriculumId = const Value.absent(),
  }) => Reward(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    title: title ?? this.title,
    description: description ?? this.description,
    pointsThreshold: pointsThreshold ?? this.pointsThreshold,
    isRevealed: isRevealed ?? this.isRevealed,
    isEarned: isEarned ?? this.isEarned,
    earnedAt: earnedAt.present ? earnedAt.value : this.earnedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    curriculumId: curriculumId.present ? curriculumId.value : this.curriculumId,
  );
  Reward copyWithCompanion(RewardsCompanion data) {
    return Reward(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      pointsThreshold: data.pointsThreshold.present
          ? data.pointsThreshold.value
          : this.pointsThreshold,
      isRevealed: data.isRevealed.present
          ? data.isRevealed.value
          : this.isRevealed,
      isEarned: data.isEarned.present ? data.isEarned.value : this.isEarned,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reward(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pointsThreshold: $pointsThreshold, ')
          ..write('isRevealed: $isRevealed, ')
          ..write('isEarned: $isEarned, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('curriculumId: $curriculumId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    title,
    description,
    pointsThreshold,
    isRevealed,
    isEarned,
    earnedAt,
    createdAt,
    updatedAt,
    curriculumId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reward &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.title == this.title &&
          other.description == this.description &&
          other.pointsThreshold == this.pointsThreshold &&
          other.isRevealed == this.isRevealed &&
          other.isEarned == this.isEarned &&
          other.earnedAt == this.earnedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.curriculumId == this.curriculumId);
}

class RewardsCompanion extends UpdateCompanion<Reward> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> title;
  final Value<String> description;
  final Value<int> pointsThreshold;
  final Value<bool> isRevealed;
  final Value<bool> isEarned;
  final Value<DateTime?> earnedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> curriculumId;
  const RewardsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.pointsThreshold = const Value.absent(),
    this.isRevealed = const Value.absent(),
    this.isEarned = const Value.absent(),
    this.earnedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.curriculumId = const Value.absent(),
  });
  RewardsCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String title,
    required String description,
    required int pointsThreshold,
    this.isRevealed = const Value.absent(),
    this.isEarned = const Value.absent(),
    this.earnedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.curriculumId = const Value.absent(),
  }) : title = Value(title),
       description = Value(description),
       pointsThreshold = Value(pointsThreshold);
  static Insertable<Reward> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? pointsThreshold,
    Expression<bool>? isRevealed,
    Expression<bool>? isEarned,
    Expression<DateTime>? earnedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? curriculumId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (pointsThreshold != null) 'points_threshold': pointsThreshold,
      if (isRevealed != null) 'is_revealed': isRevealed,
      if (isEarned != null) 'is_earned': isEarned,
      if (earnedAt != null) 'earned_at': earnedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (curriculumId != null) 'curriculum_id': curriculumId,
    });
  }

  RewardsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? title,
    Value<String>? description,
    Value<int>? pointsThreshold,
    Value<bool>? isRevealed,
    Value<bool>? isEarned,
    Value<DateTime?>? earnedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? curriculumId,
  }) {
    return RewardsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      description: description ?? this.description,
      pointsThreshold: pointsThreshold ?? this.pointsThreshold,
      isRevealed: isRevealed ?? this.isRevealed,
      isEarned: isEarned ?? this.isEarned,
      earnedAt: earnedAt ?? this.earnedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      curriculumId: curriculumId ?? this.curriculumId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (pointsThreshold.present) {
      map['points_threshold'] = Variable<int>(pointsThreshold.value);
    }
    if (isRevealed.present) {
      map['is_revealed'] = Variable<bool>(isRevealed.value);
    }
    if (isEarned.present) {
      map['is_earned'] = Variable<bool>(isEarned.value);
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<DateTime>(earnedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pointsThreshold: $pointsThreshold, ')
          ..write('isRevealed: $isRevealed, ')
          ..write('isEarned: $isEarned, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('curriculumId: $curriculumId')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationType,
    payload,
    queuedAt,
    retryCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;

  /// Type of operation: 'completion', 'bookmark', 'settings', 'streak', 'profile'
  final String operationType;

  /// JSON-encoded payload of the operation
  final String payload;

  /// When the operation was queued (UTC)
  final DateTime queuedAt;

  /// Number of retry attempts
  final int retryCount;

  /// Last error message (if any)
  final String? lastError;
  const SyncQueueData({
    required this.id,
    required this.operationType,
    required this.payload,
    required this.queuedAt,
    required this.retryCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_type'] = Variable<String>(operationType);
    map['payload'] = Variable<String>(payload);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      operationType: Value(operationType),
      payload: Value(payload),
      queuedAt: Value(queuedAt),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      operationType: serializer.fromJson<String>(json['operationType']),
      payload: serializer.fromJson<String>(json['payload']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operationType': serializer.toJson<String>(operationType),
      'payload': serializer.toJson<String>(payload),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? operationType,
    String? payload,
    DateTime? queuedAt,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
  }) => SyncQueueData(
    id: id ?? this.id,
    operationType: operationType ?? this.operationType,
    payload: payload ?? this.payload,
    queuedAt: queuedAt ?? this.queuedAt,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      payload: data.payload.present ? data.payload.value : this.payload,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('operationType: $operationType, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, operationType, payload, queuedAt, retryCount, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.operationType == this.operationType &&
          other.payload == this.payload &&
          other.queuedAt == this.queuedAt &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> operationType;
  final Value<String> payload;
  final Value<DateTime> queuedAt;
  final Value<int> retryCount;
  final Value<String?> lastError;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payload = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String operationType,
    required String payload,
    required DateTime queuedAt,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : operationType = Value(operationType),
       payload = Value(payload),
       queuedAt = Value(queuedAt);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? operationType,
    Expression<String>? payload,
    Expression<DateTime>? queuedAt,
    Expression<int>? retryCount,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationType != null) 'operation_type': operationType,
      if (payload != null) 'payload': payload,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? operationType,
    Value<String>? payload,
    Value<DateTime>? queuedAt,
    Value<int>? retryCount,
    Value<String?>? lastError,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('operationType: $operationType, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $TextCacheTable extends TextCache
    with TableInfo<$TextCacheTable, TextCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sefariaRefMeta = const VerificationMeta(
    'sefariaRef',
  );
  @override
  late final GeneratedColumn<String> sefariaRef = GeneratedColumn<String>(
    'sefaria_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hebrewTextMeta = const VerificationMeta(
    'hebrewText',
  );
  @override
  late final GeneratedColumn<String> hebrewText = GeneratedColumn<String>(
    'hebrew_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _englishTextMeta = const VerificationMeta(
    'englishText',
  );
  @override
  late final GeneratedColumn<String> englishText = GeneratedColumn<String>(
    'english_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sefariaRef,
    hebrewText,
    englishText,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('hebrew_text')) {
      context.handle(
        _hebrewTextMeta,
        hebrewText.isAcceptableOrUnknown(data['hebrew_text']!, _hebrewTextMeta),
      );
    } else if (isInserting) {
      context.missing(_hebrewTextMeta);
    }
    if (data.containsKey('english_text')) {
      context.handle(
        _englishTextMeta,
        englishText.isAcceptableOrUnknown(
          data['english_text']!,
          _englishTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_englishTextMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sefariaRef};
  @override
  TextCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextCacheData(
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      hebrewText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hebrew_text'],
      )!,
      englishText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}english_text'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $TextCacheTable createAlias(String alias) {
    return $TextCacheTable(attachedDatabase, alias);
  }
}

class TextCacheData extends DataClass implements Insertable<TextCacheData> {
  final String sefariaRef;
  final String hebrewText;
  final String englishText;
  final DateTime fetchedAt;
  const TextCacheData({
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['hebrew_text'] = Variable<String>(hebrewText);
    map['english_text'] = Variable<String>(englishText);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  TextCacheCompanion toCompanion(bool nullToAbsent) {
    return TextCacheCompanion(
      sefariaRef: Value(sefariaRef),
      hebrewText: Value(hebrewText),
      englishText: Value(englishText),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory TextCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextCacheData(
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      hebrewText: serializer.fromJson<String>(json['hebrewText']),
      englishText: serializer.fromJson<String>(json['englishText']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'hebrewText': serializer.toJson<String>(hebrewText),
      'englishText': serializer.toJson<String>(englishText),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  TextCacheData copyWith({
    String? sefariaRef,
    String? hebrewText,
    String? englishText,
    DateTime? fetchedAt,
  }) => TextCacheData(
    sefariaRef: sefariaRef ?? this.sefariaRef,
    hebrewText: hebrewText ?? this.hebrewText,
    englishText: englishText ?? this.englishText,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  TextCacheData copyWithCompanion(TextCacheCompanion data) {
    return TextCacheData(
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      hebrewText: data.hebrewText.present
          ? data.hebrewText.value
          : this.hebrewText,
      englishText: data.englishText.present
          ? data.englishText.value
          : this.englishText,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextCacheData(')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('hebrewText: $hebrewText, ')
          ..write('englishText: $englishText, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sefariaRef, hebrewText, englishText, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextCacheData &&
          other.sefariaRef == this.sefariaRef &&
          other.hebrewText == this.hebrewText &&
          other.englishText == this.englishText &&
          other.fetchedAt == this.fetchedAt);
}

class TextCacheCompanion extends UpdateCompanion<TextCacheData> {
  final Value<String> sefariaRef;
  final Value<String> hebrewText;
  final Value<String> englishText;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const TextCacheCompanion({
    this.sefariaRef = const Value.absent(),
    this.hebrewText = const Value.absent(),
    this.englishText = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextCacheCompanion.insert({
    required String sefariaRef,
    required String hebrewText,
    required String englishText,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : sefariaRef = Value(sefariaRef),
       hebrewText = Value(hebrewText),
       englishText = Value(englishText),
       fetchedAt = Value(fetchedAt);
  static Insertable<TextCacheData> custom({
    Expression<String>? sefariaRef,
    Expression<String>? hebrewText,
    Expression<String>? englishText,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (hebrewText != null) 'hebrew_text': hebrewText,
      if (englishText != null) 'english_text': englishText,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextCacheCompanion copyWith({
    Value<String>? sefariaRef,
    Value<String>? hebrewText,
    Value<String>? englishText,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return TextCacheCompanion(
      sefariaRef: sefariaRef ?? this.sefariaRef,
      hebrewText: hebrewText ?? this.hebrewText,
      englishText: englishText ?? this.englishText,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (hebrewText.present) {
      map['hebrew_text'] = Variable<String>(hebrewText.value);
    }
    if (englishText.present) {
      map['english_text'] = Variable<String>(englishText.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextCacheCompanion(')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('hebrewText: $hebrewText, ')
          ..write('englishText: $englishText, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreaksTable extends Streaks with TableInfo<$StreaksTable, Streak> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxStreakMeta = const VerificationMeta(
    'maxStreak',
  );
  @override
  late final GeneratedColumn<int> maxStreak = GeneratedColumn<int>(
    'max_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastCompletionDateMeta =
      const VerificationMeta('lastCompletionDate');
  @override
  late final GeneratedColumn<DateTime> lastCompletionDate =
      GeneratedColumn<DateTime>(
        'last_completion_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    currentStreak,
    maxStreak,
    lastCompletionDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streaks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Streak> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('max_streak')) {
      context.handle(
        _maxStreakMeta,
        maxStreak.isAcceptableOrUnknown(data['max_streak']!, _maxStreakMeta),
      );
    }
    if (data.containsKey('last_completion_date')) {
      context.handle(
        _lastCompletionDateMeta,
        lastCompletionDate.isAcceptableOrUnknown(
          data['last_completion_date']!,
          _lastCompletionDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Streak map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Streak(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
      )!,
      maxStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_streak'],
      )!,
      lastCompletionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_completion_date'],
      ),
    );
  }

  @override
  $StreaksTable createAlias(String alias) {
    return $StreaksTable(attachedDatabase, alias);
  }
}

class Streak extends DataClass implements Insertable<Streak> {
  final int id;
  final int profileId;
  final int currentStreak;
  final int maxStreak;
  final DateTime? lastCompletionDate;
  const Streak({
    required this.id,
    required this.profileId,
    required this.currentStreak,
    required this.maxStreak,
    this.lastCompletionDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['current_streak'] = Variable<int>(currentStreak);
    map['max_streak'] = Variable<int>(maxStreak);
    if (!nullToAbsent || lastCompletionDate != null) {
      map['last_completion_date'] = Variable<DateTime>(lastCompletionDate);
    }
    return map;
  }

  StreaksCompanion toCompanion(bool nullToAbsent) {
    return StreaksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      currentStreak: Value(currentStreak),
      maxStreak: Value(maxStreak),
      lastCompletionDate: lastCompletionDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCompletionDate),
    );
  }

  factory Streak.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Streak(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      maxStreak: serializer.fromJson<int>(json['maxStreak']),
      lastCompletionDate: serializer.fromJson<DateTime?>(
        json['lastCompletionDate'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'maxStreak': serializer.toJson<int>(maxStreak),
      'lastCompletionDate': serializer.toJson<DateTime?>(lastCompletionDate),
    };
  }

  Streak copyWith({
    int? id,
    int? profileId,
    int? currentStreak,
    int? maxStreak,
    Value<DateTime?> lastCompletionDate = const Value.absent(),
  }) => Streak(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    currentStreak: currentStreak ?? this.currentStreak,
    maxStreak: maxStreak ?? this.maxStreak,
    lastCompletionDate: lastCompletionDate.present
        ? lastCompletionDate.value
        : this.lastCompletionDate,
  );
  Streak copyWithCompanion(StreaksCompanion data) {
    return Streak(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      maxStreak: data.maxStreak.present ? data.maxStreak.value : this.maxStreak,
      lastCompletionDate: data.lastCompletionDate.present
          ? data.lastCompletionDate.value
          : this.lastCompletionDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Streak(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('maxStreak: $maxStreak, ')
          ..write('lastCompletionDate: $lastCompletionDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, currentStreak, maxStreak, lastCompletionDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Streak &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.currentStreak == this.currentStreak &&
          other.maxStreak == this.maxStreak &&
          other.lastCompletionDate == this.lastCompletionDate);
}

class StreaksCompanion extends UpdateCompanion<Streak> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<int> currentStreak;
  final Value<int> maxStreak;
  final Value<DateTime?> lastCompletionDate;
  const StreaksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.lastCompletionDate = const Value.absent(),
  });
  StreaksCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.lastCompletionDate = const Value.absent(),
  });
  static Insertable<Streak> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<int>? currentStreak,
    Expression<int>? maxStreak,
    Expression<DateTime>? lastCompletionDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (maxStreak != null) 'max_streak': maxStreak,
      if (lastCompletionDate != null)
        'last_completion_date': lastCompletionDate,
    });
  }

  StreaksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<int>? currentStreak,
    Value<int>? maxStreak,
    Value<DateTime?>? lastCompletionDate,
  }) {
    return StreaksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (maxStreak.present) {
      map['max_streak'] = Variable<int>(maxStreak.value);
    }
    if (lastCompletionDate.present) {
      map['last_completion_date'] = Variable<DateTime>(
        lastCompletionDate.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreaksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('maxStreak: $maxStreak, ')
          ..write('lastCompletionDate: $lastCompletionDate')
          ..write(')'))
        .toString();
  }
}

class $TextDownloadStatusesTable extends TextDownloadStatuses
    with TableInfo<$TextDownloadStatusesTable, TextDownloadStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextDownloadStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _curriculumIdMeta = const VerificationMeta(
    'curriculumId',
  );
  @override
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textVersionMeta = const VerificationMeta(
    'textVersion',
  );
  @override
  late final GeneratedColumn<String> textVersion = GeneratedColumn<String>(
    'text_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storedItemCountMeta = const VerificationMeta(
    'storedItemCount',
  );
  @override
  late final GeneratedColumn<int> storedItemCount = GeneratedColumn<int>(
    'stored_item_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    curriculumId,
    itemCount,
    textVersion,
    downloadedAt,
    storedItemCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_download_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextDownloadStatuse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('curriculum_id')) {
      context.handle(
        _curriculumIdMeta,
        curriculumId.isAcceptableOrUnknown(
          data['curriculum_id']!,
          _curriculumIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumIdMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    if (data.containsKey('text_version')) {
      context.handle(
        _textVersionMeta,
        textVersion.isAcceptableOrUnknown(
          data['text_version']!,
          _textVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textVersionMeta);
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    if (data.containsKey('stored_item_count')) {
      context.handle(
        _storedItemCountMeta,
        storedItemCount.isAcceptableOrUnknown(
          data['stored_item_count']!,
          _storedItemCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {curriculumId};
  @override
  TextDownloadStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextDownloadStatuse(
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      textVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_version'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
      storedItemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_item_count'],
      ),
    );
  }

  @override
  $TextDownloadStatusesTable createAlias(String alias) {
    return $TextDownloadStatusesTable(attachedDatabase, alias);
  }
}

class TextDownloadStatuse extends DataClass
    implements Insertable<TextDownloadStatuse> {
  /// curriculum_id from CurriculumId enum storageKey
  final String curriculumId;

  /// Number of text items downloaded for this curriculum
  final int itemCount;

  /// Version string of the text content
  final String textVersion;

  /// When the download completed
  final DateTime downloadedAt;

  /// Number of items stored so far during an in-progress download.
  /// Null when no partial download is in progress.
  final int? storedItemCount;
  const TextDownloadStatuse({
    required this.curriculumId,
    required this.itemCount,
    required this.textVersion,
    required this.downloadedAt,
    this.storedItemCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['item_count'] = Variable<int>(itemCount);
    map['text_version'] = Variable<String>(textVersion);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    if (!nullToAbsent || storedItemCount != null) {
      map['stored_item_count'] = Variable<int>(storedItemCount);
    }
    return map;
  }

  TextDownloadStatusesCompanion toCompanion(bool nullToAbsent) {
    return TextDownloadStatusesCompanion(
      curriculumId: Value(curriculumId),
      itemCount: Value(itemCount),
      textVersion: Value(textVersion),
      downloadedAt: Value(downloadedAt),
      storedItemCount: storedItemCount == null && nullToAbsent
          ? const Value.absent()
          : Value(storedItemCount),
    );
  }

  factory TextDownloadStatuse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextDownloadStatuse(
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      textVersion: serializer.fromJson<String>(json['textVersion']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
      storedItemCount: serializer.fromJson<int?>(json['storedItemCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'curriculumId': serializer.toJson<String>(curriculumId),
      'itemCount': serializer.toJson<int>(itemCount),
      'textVersion': serializer.toJson<String>(textVersion),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
      'storedItemCount': serializer.toJson<int?>(storedItemCount),
    };
  }

  TextDownloadStatuse copyWith({
    String? curriculumId,
    int? itemCount,
    String? textVersion,
    DateTime? downloadedAt,
    Value<int?> storedItemCount = const Value.absent(),
  }) => TextDownloadStatuse(
    curriculumId: curriculumId ?? this.curriculumId,
    itemCount: itemCount ?? this.itemCount,
    textVersion: textVersion ?? this.textVersion,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    storedItemCount: storedItemCount.present
        ? storedItemCount.value
        : this.storedItemCount,
  );
  TextDownloadStatuse copyWithCompanion(TextDownloadStatusesCompanion data) {
    return TextDownloadStatuse(
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      textVersion: data.textVersion.present
          ? data.textVersion.value
          : this.textVersion,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      storedItemCount: data.storedItemCount.present
          ? data.storedItemCount.value
          : this.storedItemCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextDownloadStatuse(')
          ..write('curriculumId: $curriculumId, ')
          ..write('itemCount: $itemCount, ')
          ..write('textVersion: $textVersion, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('storedItemCount: $storedItemCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    curriculumId,
    itemCount,
    textVersion,
    downloadedAt,
    storedItemCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextDownloadStatuse &&
          other.curriculumId == this.curriculumId &&
          other.itemCount == this.itemCount &&
          other.textVersion == this.textVersion &&
          other.downloadedAt == this.downloadedAt &&
          other.storedItemCount == this.storedItemCount);
}

class TextDownloadStatusesCompanion
    extends UpdateCompanion<TextDownloadStatuse> {
  final Value<String> curriculumId;
  final Value<int> itemCount;
  final Value<String> textVersion;
  final Value<DateTime> downloadedAt;
  final Value<int?> storedItemCount;
  final Value<int> rowid;
  const TextDownloadStatusesCompanion({
    this.curriculumId = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.textVersion = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.storedItemCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextDownloadStatusesCompanion.insert({
    required String curriculumId,
    required int itemCount,
    required String textVersion,
    required DateTime downloadedAt,
    this.storedItemCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       itemCount = Value(itemCount),
       textVersion = Value(textVersion),
       downloadedAt = Value(downloadedAt);
  static Insertable<TextDownloadStatuse> custom({
    Expression<String>? curriculumId,
    Expression<int>? itemCount,
    Expression<String>? textVersion,
    Expression<DateTime>? downloadedAt,
    Expression<int>? storedItemCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (itemCount != null) 'item_count': itemCount,
      if (textVersion != null) 'text_version': textVersion,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (storedItemCount != null) 'stored_item_count': storedItemCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextDownloadStatusesCompanion copyWith({
    Value<String>? curriculumId,
    Value<int>? itemCount,
    Value<String>? textVersion,
    Value<DateTime>? downloadedAt,
    Value<int?>? storedItemCount,
    Value<int>? rowid,
  }) {
    return TextDownloadStatusesCompanion(
      curriculumId: curriculumId ?? this.curriculumId,
      itemCount: itemCount ?? this.itemCount,
      textVersion: textVersion ?? this.textVersion,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      storedItemCount: storedItemCount ?? this.storedItemCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (textVersion.present) {
      map['text_version'] = Variable<String>(textVersion.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (storedItemCount.present) {
      map['stored_item_count'] = Variable<int>(storedItemCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextDownloadStatusesCompanion(')
          ..write('curriculumId: $curriculumId, ')
          ..write('itemCount: $itemCount, ')
          ..write('textVersion: $textVersion, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('storedItemCount: $storedItemCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ActiveCurriculaTable activeCurricula = $ActiveCurriculaTable(
    this,
  );
  late final $CurriculumTracksTable curriculumTracks = $CurriculumTracksTable(
    this,
  );
  late final $StageDefinitionsTable stageDefinitions = $StageDefinitionsTable(
    this,
  );
  late final $CompletionsTable completions = $CompletionsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $LearningOrderTable learningOrder = $LearningOrderTable(this);
  late final $PointConfigsTable pointConfigs = $PointConfigsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $RewardsTable rewards = $RewardsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $TextCacheTable textCache = $TextCacheTable(this);
  late final $StreaksTable streaks = $StreaksTable(this);
  late final $TextDownloadStatusesTable textDownloadStatuses =
      $TextDownloadStatusesTable(this);
  late final ActiveCurriculumDao activeCurriculumDao = ActiveCurriculumDao(
    this as AppDatabase,
  );
  late final CompletionDao completionDao = CompletionDao(this as AppDatabase);
  late final GoalDao goalDao = GoalDao(this as AppDatabase);
  late final PointConfigDao pointConfigDao = PointConfigDao(
    this as AppDatabase,
  );
  late final StageDao stageDao = StageDao(this as AppDatabase);
  late final BookmarkDao bookmarkDao = BookmarkDao(this as AppDatabase);
  late final LearningOrderDao learningOrderDao = LearningOrderDao(
    this as AppDatabase,
  );
  late final TrackDao trackDao = TrackDao(this as AppDatabase);
  late final ProfileDao profileDao = ProfileDao(this as AppDatabase);
  late final UserProfileDao userProfileDao = UserProfileDao(
    this as AppDatabase,
  );
  late final StreakDao streakDao = StreakDao(this as AppDatabase);
  late final RewardDao rewardDao = RewardDao(this as AppDatabase);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final TextCacheDao textCacheDao = TextCacheDao(this as AppDatabase);
  late final TextDownloadStatusDao textDownloadStatusDao =
      TextDownloadStatusDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activeCurricula,
    curriculumTracks,
    stageDefinitions,
    completions,
    bookmarks,
    goals,
    learningOrder,
    pointConfigs,
    profiles,
    userProfiles,
    rewards,
    syncQueue,
    textCache,
    streaks,
    textDownloadStatuses,
  ];
}

typedef $$ActiveCurriculaTableCreateCompanionBuilder =
    ActiveCurriculaCompanion Function({
      Value<int> profileId,
      required String curriculumId,
      required DateTime activatedAt,
      Value<int> rowid,
    });
typedef $$ActiveCurriculaTableUpdateCompanionBuilder =
    ActiveCurriculaCompanion Function({
      Value<int> profileId,
      Value<String> curriculumId,
      Value<DateTime> activatedAt,
      Value<int> rowid,
    });

class $$ActiveCurriculaTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveCurriculaTable> {
  $$ActiveCurriculaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveCurriculaTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveCurriculaTable> {
  $$ActiveCurriculaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveCurriculaTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveCurriculaTable> {
  $$ActiveCurriculaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => column,
  );
}

class $$ActiveCurriculaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveCurriculaTable,
          ActiveCurriculaData,
          $$ActiveCurriculaTableFilterComposer,
          $$ActiveCurriculaTableOrderingComposer,
          $$ActiveCurriculaTableAnnotationComposer,
          $$ActiveCurriculaTableCreateCompanionBuilder,
          $$ActiveCurriculaTableUpdateCompanionBuilder,
          (
            ActiveCurriculaData,
            BaseReferences<
              _$AppDatabase,
              $ActiveCurriculaTable,
              ActiveCurriculaData
            >,
          ),
          ActiveCurriculaData,
          PrefetchHooks Function()
        > {
  $$ActiveCurriculaTableTableManager(
    _$AppDatabase db,
    $ActiveCurriculaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveCurriculaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveCurriculaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveCurriculaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<DateTime> activatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveCurriculaCompanion(
                profileId: profileId,
                curriculumId: curriculumId,
                activatedAt: activatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required DateTime activatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActiveCurriculaCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                activatedAt: activatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveCurriculaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveCurriculaTable,
      ActiveCurriculaData,
      $$ActiveCurriculaTableFilterComposer,
      $$ActiveCurriculaTableOrderingComposer,
      $$ActiveCurriculaTableAnnotationComposer,
      $$ActiveCurriculaTableCreateCompanionBuilder,
      $$ActiveCurriculaTableUpdateCompanionBuilder,
      (
        ActiveCurriculaData,
        BaseReferences<
          _$AppDatabase,
          $ActiveCurriculaTable,
          ActiveCurriculaData
        >,
      ),
      ActiveCurriculaData,
      PrefetchHooks Function()
    >;
typedef $$CurriculumTracksTableCreateCompanionBuilder =
    CurriculumTracksCompanion Function({
      Value<int> profileId,
      required String curriculumId,
      required String trackType,
      Value<bool> isActive,
      required DateTime activatedAt,
      Value<DateTime?> deactivatedAt,
      Value<int> rowid,
    });
typedef $$CurriculumTracksTableUpdateCompanionBuilder =
    CurriculumTracksCompanion Function({
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> trackType,
      Value<bool> isActive,
      Value<DateTime> activatedAt,
      Value<DateTime?> deactivatedAt,
      Value<int> rowid,
    });

class $$CurriculumTracksTableFilterComposer
    extends Composer<_$AppDatabase, $CurriculumTracksTable> {
  $$CurriculumTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deactivatedAt => $composableBuilder(
    column: $table.deactivatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurriculumTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $CurriculumTracksTable> {
  $$CurriculumTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deactivatedAt => $composableBuilder(
    column: $table.deactivatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurriculumTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurriculumTracksTable> {
  $$CurriculumTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackType =>
      $composableBuilder(column: $table.trackType, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deactivatedAt => $composableBuilder(
    column: $table.deactivatedAt,
    builder: (column) => column,
  );
}

class $$CurriculumTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurriculumTracksTable,
          CurriculumTrack,
          $$CurriculumTracksTableFilterComposer,
          $$CurriculumTracksTableOrderingComposer,
          $$CurriculumTracksTableAnnotationComposer,
          $$CurriculumTracksTableCreateCompanionBuilder,
          $$CurriculumTracksTableUpdateCompanionBuilder,
          (
            CurriculumTrack,
            BaseReferences<
              _$AppDatabase,
              $CurriculumTracksTable,
              CurriculumTrack
            >,
          ),
          CurriculumTrack,
          PrefetchHooks Function()
        > {
  $$CurriculumTracksTableTableManager(
    _$AppDatabase db,
    $CurriculumTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurriculumTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurriculumTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurriculumTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> activatedAt = const Value.absent(),
                Value<DateTime?> deactivatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurriculumTracksCompanion(
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                isActive: isActive,
                activatedAt: activatedAt,
                deactivatedAt: deactivatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required String trackType,
                Value<bool> isActive = const Value.absent(),
                required DateTime activatedAt,
                Value<DateTime?> deactivatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                isActive: isActive,
                activatedAt: activatedAt,
                deactivatedAt: deactivatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurriculumTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurriculumTracksTable,
      CurriculumTrack,
      $$CurriculumTracksTableFilterComposer,
      $$CurriculumTracksTableOrderingComposer,
      $$CurriculumTracksTableAnnotationComposer,
      $$CurriculumTracksTableCreateCompanionBuilder,
      $$CurriculumTracksTableUpdateCompanionBuilder,
      (
        CurriculumTrack,
        BaseReferences<_$AppDatabase, $CurriculumTracksTable, CurriculumTrack>,
      ),
      CurriculumTrack,
      PrefetchHooks Function()
    >;
typedef $$StageDefinitionsTableCreateCompanionBuilder =
    StageDefinitionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required int stageOrder,
      required String stageName,
      required int delayDays,
      Value<bool> isDefault,
    });
typedef $$StageDefinitionsTableUpdateCompanionBuilder =
    StageDefinitionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> stageOrder,
      Value<String> stageName,
      Value<int> delayDays,
      Value<bool> isDefault,
    });

class $$StageDefinitionsTableFilterComposer
    extends Composer<_$AppDatabase, $StageDefinitionsTable> {
  $$StageDefinitionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stageName => $composableBuilder(
    column: $table.stageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delayDays => $composableBuilder(
    column: $table.delayDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StageDefinitionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StageDefinitionsTable> {
  $$StageDefinitionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stageName => $composableBuilder(
    column: $table.stageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delayDays => $composableBuilder(
    column: $table.delayDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StageDefinitionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StageDefinitionsTable> {
  $$StageDefinitionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stageName =>
      $composableBuilder(column: $table.stageName, builder: (column) => column);

  GeneratedColumn<int> get delayDays =>
      $composableBuilder(column: $table.delayDays, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$StageDefinitionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StageDefinitionsTable,
          StageDefinition,
          $$StageDefinitionsTableFilterComposer,
          $$StageDefinitionsTableOrderingComposer,
          $$StageDefinitionsTableAnnotationComposer,
          $$StageDefinitionsTableCreateCompanionBuilder,
          $$StageDefinitionsTableUpdateCompanionBuilder,
          (
            StageDefinition,
            BaseReferences<
              _$AppDatabase,
              $StageDefinitionsTable,
              StageDefinition
            >,
          ),
          StageDefinition,
          PrefetchHooks Function()
        > {
  $$StageDefinitionsTableTableManager(
    _$AppDatabase db,
    $StageDefinitionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StageDefinitionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StageDefinitionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StageDefinitionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<int> stageOrder = const Value.absent(),
                Value<String> stageName = const Value.absent(),
                Value<int> delayDays = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => StageDefinitionsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                stageName: stageName,
                delayDays: delayDays,
                isDefault: isDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required int stageOrder,
                required String stageName,
                required int delayDays,
                Value<bool> isDefault = const Value.absent(),
              }) => StageDefinitionsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                stageName: stageName,
                delayDays: delayDays,
                isDefault: isDefault,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StageDefinitionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StageDefinitionsTable,
      StageDefinition,
      $$StageDefinitionsTableFilterComposer,
      $$StageDefinitionsTableOrderingComposer,
      $$StageDefinitionsTableAnnotationComposer,
      $$StageDefinitionsTableCreateCompanionBuilder,
      $$StageDefinitionsTableUpdateCompanionBuilder,
      (
        StageDefinition,
        BaseReferences<_$AppDatabase, $StageDefinitionsTable, StageDefinition>,
      ),
      StageDefinition,
      PrefetchHooks Function()
    >;
typedef $$CompletionsTableCreateCompanionBuilder =
    CompletionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required String trackType,
      required DateTime completedAt,
      Value<int> points,
    });
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> stageId,
      Value<String> trackType,
      Value<DateTime> completedAt,
      Value<int> points,
    });

class $$CompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageId => $composableBuilder(
    column: $table.stageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageId => $composableBuilder(
    column: $table.stageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageId =>
      $composableBuilder(column: $table.stageId, builder: (column) => column);

  GeneratedColumn<String> get trackType =>
      $composableBuilder(column: $table.trackType, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);
}

class $$CompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompletionsTable,
          Completion,
          $$CompletionsTableFilterComposer,
          $$CompletionsTableOrderingComposer,
          $$CompletionsTableAnnotationComposer,
          $$CompletionsTableCreateCompanionBuilder,
          $$CompletionsTableUpdateCompanionBuilder,
          (
            Completion,
            BaseReferences<_$AppDatabase, $CompletionsTable, Completion>,
          ),
          Completion,
          PrefetchHooks Function()
        > {
  $$CompletionsTableTableManager(_$AppDatabase db, $CompletionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<int> stageId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> points = const Value.absent(),
              }) => CompletionsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                completedAt: completedAt,
                points: points,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required String sefariaRef,
                required int stageId,
                required String trackType,
                required DateTime completedAt,
                Value<int> points = const Value.absent(),
              }) => CompletionsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                completedAt: completedAt,
                points: points,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompletionsTable,
      Completion,
      $$CompletionsTableFilterComposer,
      $$CompletionsTableOrderingComposer,
      $$CompletionsTableAnnotationComposer,
      $$CompletionsTableCreateCompanionBuilder,
      $$CompletionsTableUpdateCompanionBuilder,
      (
        Completion,
        BaseReferences<_$AppDatabase, $CompletionsTable, Completion>,
      ),
      Completion,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required String trackType,
      required String sefariaRef,
      required DateTime updatedAt,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> trackType,
      Value<String> sefariaRef,
      Value<DateTime> updatedAt,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackType =>
      $composableBuilder(column: $table.trackType, builder: (column) => column);

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                sefariaRef: sefariaRef,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required String trackType,
                required String sefariaRef,
                required DateTime updatedAt,
              }) => BookmarksCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                sefariaRef: sefariaRef,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      Value<double> targetPercent,
      Value<DateTime?> targetDate,
      Value<String> description,
      Value<String> dateType,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<double> targetPercent,
      Value<DateTime?> targetDate,
      Value<String> description,
      Value<String> dateType,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetPercent => $composableBuilder(
    column: $table.targetPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateType => $composableBuilder(
    column: $table.dateType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetPercent => $composableBuilder(
    column: $table.targetPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateType => $composableBuilder(
    column: $table.dateType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetPercent => $composableBuilder(
    column: $table.targetPercent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dateType =>
      $composableBuilder(column: $table.dateType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
          Goal,
          PrefetchHooks Function()
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<double> targetPercent = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> dateType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                targetPercent: targetPercent,
                targetDate: targetDate,
                description: description,
                dateType: dateType,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                Value<double> targetPercent = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> dateType = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GoalsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                targetPercent: targetPercent,
                targetDate: targetDate,
                description: description,
                dateType: dateType,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
      Goal,
      PrefetchHooks Function()
    >;
typedef $$LearningOrderTableCreateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required String sefariaRef,
      required int userSortOrder,
    });
typedef $$LearningOrderTableUpdateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> userSortOrder,
    });

class $$LearningOrderTableFilterComposer
    extends Composer<_$AppDatabase, $LearningOrderTable> {
  $$LearningOrderTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userSortOrder => $composableBuilder(
    column: $table.userSortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningOrderTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningOrderTable> {
  $$LearningOrderTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userSortOrder => $composableBuilder(
    column: $table.userSortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningOrderTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningOrderTable> {
  $$LearningOrderTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userSortOrder => $composableBuilder(
    column: $table.userSortOrder,
    builder: (column) => column,
  );
}

class $$LearningOrderTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningOrderTable,
          LearningOrderData,
          $$LearningOrderTableFilterComposer,
          $$LearningOrderTableOrderingComposer,
          $$LearningOrderTableAnnotationComposer,
          $$LearningOrderTableCreateCompanionBuilder,
          $$LearningOrderTableUpdateCompanionBuilder,
          (
            LearningOrderData,
            BaseReferences<
              _$AppDatabase,
              $LearningOrderTable,
              LearningOrderData
            >,
          ),
          LearningOrderData,
          PrefetchHooks Function()
        > {
  $$LearningOrderTableTableManager(_$AppDatabase db, $LearningOrderTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningOrderTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningOrderTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningOrderTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<int> userSortOrder = const Value.absent(),
              }) => LearningOrderCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                userSortOrder: userSortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required String sefariaRef,
                required int userSortOrder,
              }) => LearningOrderCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                userSortOrder: userSortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningOrderTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningOrderTable,
      LearningOrderData,
      $$LearningOrderTableFilterComposer,
      $$LearningOrderTableOrderingComposer,
      $$LearningOrderTableAnnotationComposer,
      $$LearningOrderTableCreateCompanionBuilder,
      $$LearningOrderTableUpdateCompanionBuilder,
      (
        LearningOrderData,
        BaseReferences<_$AppDatabase, $LearningOrderTable, LearningOrderData>,
      ),
      LearningOrderData,
      PrefetchHooks Function()
    >;
typedef $$PointConfigsTableCreateCompanionBuilder =
    PointConfigsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required int stageOrder,
      required int points,
    });
typedef $$PointConfigsTableUpdateCompanionBuilder =
    PointConfigsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> stageOrder,
      Value<int> points,
    });

class $$PointConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $PointConfigsTable> {
  $$PointConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PointConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $PointConfigsTable> {
  $$PointConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PointConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointConfigsTable> {
  $$PointConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);
}

class $$PointConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PointConfigsTable,
          PointConfig,
          $$PointConfigsTableFilterComposer,
          $$PointConfigsTableOrderingComposer,
          $$PointConfigsTableAnnotationComposer,
          $$PointConfigsTableCreateCompanionBuilder,
          $$PointConfigsTableUpdateCompanionBuilder,
          (
            PointConfig,
            BaseReferences<_$AppDatabase, $PointConfigsTable, PointConfig>,
          ),
          PointConfig,
          PrefetchHooks Function()
        > {
  $$PointConfigsTableTableManager(_$AppDatabase db, $PointConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<int> stageOrder = const Value.absent(),
                Value<int> points = const Value.absent(),
              }) => PointConfigsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                points: points,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required int stageOrder,
                required int points,
              }) => PointConfigsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                points: points,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PointConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PointConfigsTable,
      PointConfig,
      $$PointConfigsTableFilterComposer,
      $$PointConfigsTableOrderingComposer,
      $$PointConfigsTableAnnotationComposer,
      $$PointConfigsTableCreateCompanionBuilder,
      $$PointConfigsTableUpdateCompanionBuilder,
      (
        PointConfig,
        BaseReferences<_$AppDatabase, $PointConfigsTable, PointConfig>,
      ),
      PointConfig,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      required int accountId,
      required String displayName,
      required String mode,
      Value<int> avatarIndex,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<String> displayName,
      Value<String> mode,
      Value<int> avatarIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> avatarIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                accountId: accountId,
                displayName: displayName,
                mode: mode,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required String displayName,
                required String mode,
                Value<int> avatarIndex = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => ProfilesCompanion.insert(
                id: id,
                accountId: accountId,
                displayName: displayName,
                mode: mode,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      required String firebaseUid,
      required String displayName,
      required String userMode,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> firebaseUid,
      Value<String> displayName,
      Value<String> userMode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userMode => $composableBuilder(
    column: $table.userMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userMode => $composableBuilder(
    column: $table.userMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userMode =>
      $composableBuilder(column: $table.userMode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> firebaseUid = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> userMode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                firebaseUid: firebaseUid,
                displayName: displayName,
                userMode: userMode,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String firebaseUid,
                required String displayName,
                required String userMode,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => UserProfilesCompanion.insert(
                id: id,
                firebaseUid: firebaseUid,
                displayName: displayName,
                userMode: userMode,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$RewardsTableCreateCompanionBuilder =
    RewardsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String title,
      required String description,
      required int pointsThreshold,
      Value<bool> isRevealed,
      Value<bool> isEarned,
      Value<DateTime?> earnedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> curriculumId,
    });
typedef $$RewardsTableUpdateCompanionBuilder =
    RewardsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> title,
      Value<String> description,
      Value<int> pointsThreshold,
      Value<bool> isRevealed,
      Value<bool> isEarned,
      Value<DateTime?> earnedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> curriculumId,
    });

class $$RewardsTableFilterComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsThreshold => $composableBuilder(
    column: $table.pointsThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRevealed => $composableBuilder(
    column: $table.isRevealed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEarned => $composableBuilder(
    column: $table.isEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewardsTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsThreshold => $composableBuilder(
    column: $table.pointsThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRevealed => $composableBuilder(
    column: $table.isRevealed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEarned => $composableBuilder(
    column: $table.isEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsThreshold => $composableBuilder(
    column: $table.pointsThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRevealed => $composableBuilder(
    column: $table.isRevealed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEarned =>
      $composableBuilder(column: $table.isEarned, builder: (column) => column);

  GeneratedColumn<DateTime> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );
}

class $$RewardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewardsTable,
          Reward,
          $$RewardsTableFilterComposer,
          $$RewardsTableOrderingComposer,
          $$RewardsTableAnnotationComposer,
          $$RewardsTableCreateCompanionBuilder,
          $$RewardsTableUpdateCompanionBuilder,
          (Reward, BaseReferences<_$AppDatabase, $RewardsTable, Reward>),
          Reward,
          PrefetchHooks Function()
        > {
  $$RewardsTableTableManager(_$AppDatabase db, $RewardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> pointsThreshold = const Value.absent(),
                Value<bool> isRevealed = const Value.absent(),
                Value<bool> isEarned = const Value.absent(),
                Value<DateTime?> earnedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> curriculumId = const Value.absent(),
              }) => RewardsCompanion(
                id: id,
                profileId: profileId,
                title: title,
                description: description,
                pointsThreshold: pointsThreshold,
                isRevealed: isRevealed,
                isEarned: isEarned,
                earnedAt: earnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                curriculumId: curriculumId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String title,
                required String description,
                required int pointsThreshold,
                Value<bool> isRevealed = const Value.absent(),
                Value<bool> isEarned = const Value.absent(),
                Value<DateTime?> earnedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> curriculumId = const Value.absent(),
              }) => RewardsCompanion.insert(
                id: id,
                profileId: profileId,
                title: title,
                description: description,
                pointsThreshold: pointsThreshold,
                isRevealed: isRevealed,
                isEarned: isEarned,
                earnedAt: earnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                curriculumId: curriculumId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewardsTable,
      Reward,
      $$RewardsTableFilterComposer,
      $$RewardsTableOrderingComposer,
      $$RewardsTableAnnotationComposer,
      $$RewardsTableCreateCompanionBuilder,
      $$RewardsTableUpdateCompanionBuilder,
      (Reward, BaseReferences<_$AppDatabase, $RewardsTable, Reward>),
      Reward,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String operationType,
      required String payload,
      required DateTime queuedAt,
      Value<int> retryCount,
      Value<String?> lastError,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> operationType,
      Value<String> payload,
      Value<DateTime> queuedAt,
      Value<int> retryCount,
      Value<String?> lastError,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                operationType: operationType,
                payload: payload,
                queuedAt: queuedAt,
                retryCount: retryCount,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationType,
                required String payload,
                required DateTime queuedAt,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                operationType: operationType,
                payload: payload,
                queuedAt: queuedAt,
                retryCount: retryCount,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$TextCacheTableCreateCompanionBuilder =
    TextCacheCompanion Function({
      required String sefariaRef,
      required String hebrewText,
      required String englishText,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$TextCacheTableUpdateCompanionBuilder =
    TextCacheCompanion Function({
      Value<String> sefariaRef,
      Value<String> hebrewText,
      Value<String> englishText,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$TextCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TextCacheTable> {
  $$TextCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hebrewText => $composableBuilder(
    column: $table.hebrewText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TextCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TextCacheTable> {
  $$TextCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hebrewText => $composableBuilder(
    column: $table.hebrewText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TextCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TextCacheTable> {
  $$TextCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hebrewText => $composableBuilder(
    column: $table.hebrewText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$TextCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TextCacheTable,
          TextCacheData,
          $$TextCacheTableFilterComposer,
          $$TextCacheTableOrderingComposer,
          $$TextCacheTableAnnotationComposer,
          $$TextCacheTableCreateCompanionBuilder,
          $$TextCacheTableUpdateCompanionBuilder,
          (
            TextCacheData,
            BaseReferences<_$AppDatabase, $TextCacheTable, TextCacheData>,
          ),
          TextCacheData,
          PrefetchHooks Function()
        > {
  $$TextCacheTableTableManager(_$AppDatabase db, $TextCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sefariaRef = const Value.absent(),
                Value<String> hebrewText = const Value.absent(),
                Value<String> englishText = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextCacheCompanion(
                sefariaRef: sefariaRef,
                hebrewText: hebrewText,
                englishText: englishText,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sefariaRef,
                required String hebrewText,
                required String englishText,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => TextCacheCompanion.insert(
                sefariaRef: sefariaRef,
                hebrewText: hebrewText,
                englishText: englishText,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TextCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TextCacheTable,
      TextCacheData,
      $$TextCacheTableFilterComposer,
      $$TextCacheTableOrderingComposer,
      $$TextCacheTableAnnotationComposer,
      $$TextCacheTableCreateCompanionBuilder,
      $$TextCacheTableUpdateCompanionBuilder,
      (
        TextCacheData,
        BaseReferences<_$AppDatabase, $TextCacheTable, TextCacheData>,
      ),
      TextCacheData,
      PrefetchHooks Function()
    >;
typedef $$StreaksTableCreateCompanionBuilder =
    StreaksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> currentStreak,
      Value<int> maxStreak,
      Value<DateTime?> lastCompletionDate,
    });
typedef $$StreaksTableUpdateCompanionBuilder =
    StreaksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> currentStreak,
      Value<int> maxStreak,
      Value<DateTime?> lastCompletionDate,
    });

class $$StreaksTableFilterComposer
    extends Composer<_$AppDatabase, $StreaksTable> {
  $$StreaksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxStreak => $composableBuilder(
    column: $table.maxStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCompletionDate => $composableBuilder(
    column: $table.lastCompletionDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreaksTableOrderingComposer
    extends Composer<_$AppDatabase, $StreaksTable> {
  $$StreaksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxStreak => $composableBuilder(
    column: $table.maxStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCompletionDate => $composableBuilder(
    column: $table.lastCompletionDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreaksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreaksTable> {
  $$StreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxStreak =>
      $composableBuilder(column: $table.maxStreak, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCompletionDate => $composableBuilder(
    column: $table.lastCompletionDate,
    builder: (column) => column,
  );
}

class $$StreaksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StreaksTable,
          Streak,
          $$StreaksTableFilterComposer,
          $$StreaksTableOrderingComposer,
          $$StreaksTableAnnotationComposer,
          $$StreaksTableCreateCompanionBuilder,
          $$StreaksTableUpdateCompanionBuilder,
          (Streak, BaseReferences<_$AppDatabase, $StreaksTable, Streak>),
          Streak,
          PrefetchHooks Function()
        > {
  $$StreaksTableTableManager(_$AppDatabase db, $StreaksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> maxStreak = const Value.absent(),
                Value<DateTime?> lastCompletionDate = const Value.absent(),
              }) => StreaksCompanion(
                id: id,
                profileId: profileId,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                lastCompletionDate: lastCompletionDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> maxStreak = const Value.absent(),
                Value<DateTime?> lastCompletionDate = const Value.absent(),
              }) => StreaksCompanion.insert(
                id: id,
                profileId: profileId,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                lastCompletionDate: lastCompletionDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreaksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StreaksTable,
      Streak,
      $$StreaksTableFilterComposer,
      $$StreaksTableOrderingComposer,
      $$StreaksTableAnnotationComposer,
      $$StreaksTableCreateCompanionBuilder,
      $$StreaksTableUpdateCompanionBuilder,
      (Streak, BaseReferences<_$AppDatabase, $StreaksTable, Streak>),
      Streak,
      PrefetchHooks Function()
    >;
typedef $$TextDownloadStatusesTableCreateCompanionBuilder =
    TextDownloadStatusesCompanion Function({
      required String curriculumId,
      required int itemCount,
      required String textVersion,
      required DateTime downloadedAt,
      Value<int?> storedItemCount,
      Value<int> rowid,
    });
typedef $$TextDownloadStatusesTableUpdateCompanionBuilder =
    TextDownloadStatusesCompanion Function({
      Value<String> curriculumId,
      Value<int> itemCount,
      Value<String> textVersion,
      Value<DateTime> downloadedAt,
      Value<int?> storedItemCount,
      Value<int> rowid,
    });

class $$TextDownloadStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $TextDownloadStatusesTable> {
  $$TextDownloadStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textVersion => $composableBuilder(
    column: $table.textVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedItemCount => $composableBuilder(
    column: $table.storedItemCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TextDownloadStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $TextDownloadStatusesTable> {
  $$TextDownloadStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textVersion => $composableBuilder(
    column: $table.textVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedItemCount => $composableBuilder(
    column: $table.storedItemCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TextDownloadStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TextDownloadStatusesTable> {
  $$TextDownloadStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<String> get textVersion => $composableBuilder(
    column: $table.textVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storedItemCount => $composableBuilder(
    column: $table.storedItemCount,
    builder: (column) => column,
  );
}

class $$TextDownloadStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TextDownloadStatusesTable,
          TextDownloadStatuse,
          $$TextDownloadStatusesTableFilterComposer,
          $$TextDownloadStatusesTableOrderingComposer,
          $$TextDownloadStatusesTableAnnotationComposer,
          $$TextDownloadStatusesTableCreateCompanionBuilder,
          $$TextDownloadStatusesTableUpdateCompanionBuilder,
          (
            TextDownloadStatuse,
            BaseReferences<
              _$AppDatabase,
              $TextDownloadStatusesTable,
              TextDownloadStatuse
            >,
          ),
          TextDownloadStatuse,
          PrefetchHooks Function()
        > {
  $$TextDownloadStatusesTableTableManager(
    _$AppDatabase db,
    $TextDownloadStatusesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextDownloadStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextDownloadStatusesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TextDownloadStatusesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> curriculumId = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<String> textVersion = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int?> storedItemCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextDownloadStatusesCompanion(
                curriculumId: curriculumId,
                itemCount: itemCount,
                textVersion: textVersion,
                downloadedAt: downloadedAt,
                storedItemCount: storedItemCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String curriculumId,
                required int itemCount,
                required String textVersion,
                required DateTime downloadedAt,
                Value<int?> storedItemCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextDownloadStatusesCompanion.insert(
                curriculumId: curriculumId,
                itemCount: itemCount,
                textVersion: textVersion,
                downloadedAt: downloadedAt,
                storedItemCount: storedItemCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TextDownloadStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TextDownloadStatusesTable,
      TextDownloadStatuse,
      $$TextDownloadStatusesTableFilterComposer,
      $$TextDownloadStatusesTableOrderingComposer,
      $$TextDownloadStatusesTableAnnotationComposer,
      $$TextDownloadStatusesTableCreateCompanionBuilder,
      $$TextDownloadStatusesTableUpdateCompanionBuilder,
      (
        TextDownloadStatuse,
        BaseReferences<
          _$AppDatabase,
          $TextDownloadStatusesTable,
          TextDownloadStatuse
        >,
      ),
      TextDownloadStatuse,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ActiveCurriculaTableTableManager get activeCurricula =>
      $$ActiveCurriculaTableTableManager(_db, _db.activeCurricula);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(_db, _db.curriculumTracks);
  $$StageDefinitionsTableTableManager get stageDefinitions =>
      $$StageDefinitionsTableTableManager(_db, _db.stageDefinitions);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$LearningOrderTableTableManager get learningOrder =>
      $$LearningOrderTableTableManager(_db, _db.learningOrder);
  $$PointConfigsTableTableManager get pointConfigs =>
      $$PointConfigsTableTableManager(_db, _db.pointConfigs);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$RewardsTableTableManager get rewards =>
      $$RewardsTableTableManager(_db, _db.rewards);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$TextCacheTableTableManager get textCache =>
      $$TextCacheTableTableManager(_db, _db.textCache);
  $$StreaksTableTableManager get streaks =>
      $$StreaksTableTableManager(_db, _db.streaks);
  $$TextDownloadStatusesTableTableManager get textDownloadStatuses =>
      $$TextDownloadStatusesTableTableManager(_db, _db.textDownloadStatuses);
}
