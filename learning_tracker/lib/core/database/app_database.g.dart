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

class $CurriculumScopesTable extends CurriculumScopes
    with TableInfo<$CurriculumScopesTable, CurriculumScope> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurriculumScopesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _scopeLevelMeta = const VerificationMeta(
    'scopeLevel',
  );
  @override
  late final GeneratedColumn<int> scopeLevel = GeneratedColumn<int>(
    'scope_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeValueMeta = const VerificationMeta(
    'scopeValue',
  );
  @override
  late final GeneratedColumn<String> scopeValue = GeneratedColumn<String>(
    'scope_value',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    scopeLevel,
    scopeValue,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'curriculum_scopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurriculumScope> instance, {
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
    if (data.containsKey('scope_level')) {
      context.handle(
        _scopeLevelMeta,
        scopeLevel.isAcceptableOrUnknown(data['scope_level']!, _scopeLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeLevelMeta);
    }
    if (data.containsKey('scope_value')) {
      context.handle(
        _scopeValueMeta,
        scopeValue.isAcceptableOrUnknown(data['scope_value']!, _scopeValueMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeValueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, scopeLevel, scopeValue},
  ];
  @override
  CurriculumScope map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurriculumScope(
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
      scopeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_level'],
      )!,
      scopeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_value'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CurriculumScopesTable createAlias(String alias) {
    return $CurriculumScopesTable(attachedDatabase, alias);
  }
}

class CurriculumScope extends DataClass implements Insertable<CurriculumScope> {
  final int id;
  final int profileId;
  final String curriculumId;

  /// Which hierarchy level the scope applies to (1-4, matching level1-level4).
  final int scopeLevel;

  /// The value at that level (e.g., "Seder Zeraim", "Berachos").
  final String scopeValue;
  final DateTime createdAt;
  const CurriculumScope({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.scopeLevel,
    required this.scopeValue,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['scope_level'] = Variable<int>(scopeLevel);
    map['scope_value'] = Variable<String>(scopeValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CurriculumScopesCompanion toCompanion(bool nullToAbsent) {
    return CurriculumScopesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      scopeLevel: Value(scopeLevel),
      scopeValue: Value(scopeValue),
      createdAt: Value(createdAt),
    );
  }

  factory CurriculumScope.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurriculumScope(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      scopeLevel: serializer.fromJson<int>(json['scopeLevel']),
      scopeValue: serializer.fromJson<String>(json['scopeValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'scopeLevel': serializer.toJson<int>(scopeLevel),
      'scopeValue': serializer.toJson<String>(scopeValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CurriculumScope copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? scopeLevel,
    String? scopeValue,
    DateTime? createdAt,
  }) => CurriculumScope(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    scopeLevel: scopeLevel ?? this.scopeLevel,
    scopeValue: scopeValue ?? this.scopeValue,
    createdAt: createdAt ?? this.createdAt,
  );
  CurriculumScope copyWithCompanion(CurriculumScopesCompanion data) {
    return CurriculumScope(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      scopeLevel: data.scopeLevel.present
          ? data.scopeLevel.value
          : this.scopeLevel,
      scopeValue: data.scopeValue.present
          ? data.scopeValue.value
          : this.scopeValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumScope(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('scopeLevel: $scopeLevel, ')
          ..write('scopeValue: $scopeValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    scopeLevel,
    scopeValue,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurriculumScope &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.scopeLevel == this.scopeLevel &&
          other.scopeValue == this.scopeValue &&
          other.createdAt == this.createdAt);
}

class CurriculumScopesCompanion extends UpdateCompanion<CurriculumScope> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> scopeLevel;
  final Value<String> scopeValue;
  final Value<DateTime> createdAt;
  const CurriculumScopesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.scopeLevel = const Value.absent(),
    this.scopeValue = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CurriculumScopesCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required int scopeLevel,
    required String scopeValue,
    required DateTime createdAt,
  }) : curriculumId = Value(curriculumId),
       scopeLevel = Value(scopeLevel),
       scopeValue = Value(scopeValue),
       createdAt = Value(createdAt);
  static Insertable<CurriculumScope> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? scopeLevel,
    Expression<String>? scopeValue,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (scopeLevel != null) 'scope_level': scopeLevel,
      if (scopeValue != null) 'scope_value': scopeValue,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CurriculumScopesCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? scopeLevel,
    Value<String>? scopeValue,
    Value<DateTime>? createdAt,
  }) {
    return CurriculumScopesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      scopeLevel: scopeLevel ?? this.scopeLevel,
      scopeValue: scopeValue ?? this.scopeValue,
      createdAt: createdAt ?? this.createdAt,
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
    if (scopeLevel.present) {
      map['scope_level'] = Variable<int>(scopeLevel.value);
    }
    if (scopeValue.present) {
      map['scope_value'] = Variable<String>(scopeValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumScopesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('scopeLevel: $scopeLevel, ')
          ..write('scopeValue: $scopeValue, ')
          ..write('createdAt: $createdAt')
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
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
    archivedAt,
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
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
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

  /// When this track was archived (null if not archived).
  /// Archived tracks are hidden from dashboard/scheduler but data is preserved.
  final DateTime? archivedAt;
  const CurriculumTrack({
    required this.profileId,
    required this.curriculumId,
    required this.trackType,
    required this.isActive,
    required this.activatedAt,
    this.deactivatedAt,
    this.archivedAt,
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
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
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
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
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
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
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
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  CurriculumTrack copyWith({
    int? profileId,
    String? curriculumId,
    String? trackType,
    bool? isActive,
    DateTime? activatedAt,
    Value<DateTime?> deactivatedAt = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => CurriculumTrack(
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackType: trackType ?? this.trackType,
    isActive: isActive ?? this.isActive,
    activatedAt: activatedAt ?? this.activatedAt,
    deactivatedAt: deactivatedAt.present
        ? deactivatedAt.value
        : this.deactivatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
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
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
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
          ..write('deactivatedAt: $deactivatedAt, ')
          ..write('archivedAt: $archivedAt')
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
    archivedAt,
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
          other.deactivatedAt == this.deactivatedAt &&
          other.archivedAt == this.archivedAt);
}

class CurriculumTracksCompanion extends UpdateCompanion<CurriculumTrack> {
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> trackType;
  final Value<bool> isActive;
  final Value<DateTime> activatedAt;
  final Value<DateTime?> deactivatedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const CurriculumTracksCompanion({
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.isActive = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.deactivatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurriculumTracksCompanion.insert({
    this.profileId = const Value.absent(),
    required String curriculumId,
    required String trackType,
    this.isActive = const Value.absent(),
    required DateTime activatedAt,
    this.deactivatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
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
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackType != null) 'track_type': trackType,
      if (isActive != null) 'is_active': isActive,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (deactivatedAt != null) 'deactivated_at': deactivatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
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
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return CurriculumTracksCompanion(
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackType: trackType ?? this.trackType,
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
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
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
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
          ..write('archivedAt: $archivedAt, ')
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
  static const VerificationMeta _scheduleTypeMeta = const VerificationMeta(
    'scheduleType',
  );
  @override
  late final GeneratedColumn<String> scheduleType = GeneratedColumn<String>(
    'schedule_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('delay'),
  );
  static const VerificationMeta _daysOfWeekMeta = const VerificationMeta(
    'daysOfWeek',
  );
  @override
  late final GeneratedColumn<String> daysOfWeek = GeneratedColumn<String>(
    'days_of_week',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rollingWindowSizeMeta = const VerificationMeta(
    'rollingWindowSize',
  );
  @override
  late final GeneratedColumn<int> rollingWindowSize = GeneratedColumn<int>(
    'rolling_window_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    scheduleType,
    daysOfWeek,
    rollingWindowSize,
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
    if (data.containsKey('schedule_type')) {
      context.handle(
        _scheduleTypeMeta,
        scheduleType.isAcceptableOrUnknown(
          data['schedule_type']!,
          _scheduleTypeMeta,
        ),
      );
    }
    if (data.containsKey('days_of_week')) {
      context.handle(
        _daysOfWeekMeta,
        daysOfWeek.isAcceptableOrUnknown(
          data['days_of_week']!,
          _daysOfWeekMeta,
        ),
      );
    }
    if (data.containsKey('rolling_window_size')) {
      context.handle(
        _rollingWindowSizeMeta,
        rollingWindowSize.isAcceptableOrUnknown(
          data['rolling_window_size']!,
          _rollingWindowSizeMeta,
        ),
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
      scheduleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_type'],
      )!,
      daysOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}days_of_week'],
      ),
      rollingWindowSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rolling_window_size'],
      ),
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
  final String scheduleType;
  final String? daysOfWeek;
  final int? rollingWindowSize;
  const StageDefinition({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
    required this.isDefault,
    required this.scheduleType,
    this.daysOfWeek,
    this.rollingWindowSize,
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
    map['schedule_type'] = Variable<String>(scheduleType);
    if (!nullToAbsent || daysOfWeek != null) {
      map['days_of_week'] = Variable<String>(daysOfWeek);
    }
    if (!nullToAbsent || rollingWindowSize != null) {
      map['rolling_window_size'] = Variable<int>(rollingWindowSize);
    }
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
      scheduleType: Value(scheduleType),
      daysOfWeek: daysOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(daysOfWeek),
      rollingWindowSize: rollingWindowSize == null && nullToAbsent
          ? const Value.absent()
          : Value(rollingWindowSize),
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
      scheduleType: serializer.fromJson<String>(json['scheduleType']),
      daysOfWeek: serializer.fromJson<String?>(json['daysOfWeek']),
      rollingWindowSize: serializer.fromJson<int?>(json['rollingWindowSize']),
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
      'scheduleType': serializer.toJson<String>(scheduleType),
      'daysOfWeek': serializer.toJson<String?>(daysOfWeek),
      'rollingWindowSize': serializer.toJson<int?>(rollingWindowSize),
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
    String? scheduleType,
    Value<String?> daysOfWeek = const Value.absent(),
    Value<int?> rollingWindowSize = const Value.absent(),
  }) => StageDefinition(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    stageOrder: stageOrder ?? this.stageOrder,
    stageName: stageName ?? this.stageName,
    delayDays: delayDays ?? this.delayDays,
    isDefault: isDefault ?? this.isDefault,
    scheduleType: scheduleType ?? this.scheduleType,
    daysOfWeek: daysOfWeek.present ? daysOfWeek.value : this.daysOfWeek,
    rollingWindowSize: rollingWindowSize.present
        ? rollingWindowSize.value
        : this.rollingWindowSize,
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
      scheduleType: data.scheduleType.present
          ? data.scheduleType.value
          : this.scheduleType,
      daysOfWeek: data.daysOfWeek.present
          ? data.daysOfWeek.value
          : this.daysOfWeek,
      rollingWindowSize: data.rollingWindowSize.present
          ? data.rollingWindowSize.value
          : this.rollingWindowSize,
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
          ..write('isDefault: $isDefault, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('daysOfWeek: $daysOfWeek, ')
          ..write('rollingWindowSize: $rollingWindowSize')
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
    scheduleType,
    daysOfWeek,
    rollingWindowSize,
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
          other.isDefault == this.isDefault &&
          other.scheduleType == this.scheduleType &&
          other.daysOfWeek == this.daysOfWeek &&
          other.rollingWindowSize == this.rollingWindowSize);
}

class StageDefinitionsCompanion extends UpdateCompanion<StageDefinition> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> stageOrder;
  final Value<String> stageName;
  final Value<int> delayDays;
  final Value<bool> isDefault;
  final Value<String> scheduleType;
  final Value<String?> daysOfWeek;
  final Value<int?> rollingWindowSize;
  const StageDefinitionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.stageName = const Value.absent(),
    this.delayDays = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.daysOfWeek = const Value.absent(),
    this.rollingWindowSize = const Value.absent(),
  });
  StageDefinitionsCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    this.isDefault = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.daysOfWeek = const Value.absent(),
    this.rollingWindowSize = const Value.absent(),
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
    Expression<String>? scheduleType,
    Expression<String>? daysOfWeek,
    Expression<int>? rollingWindowSize,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (stageName != null) 'stage_name': stageName,
      if (delayDays != null) 'delay_days': delayDays,
      if (isDefault != null) 'is_default': isDefault,
      if (scheduleType != null) 'schedule_type': scheduleType,
      if (daysOfWeek != null) 'days_of_week': daysOfWeek,
      if (rollingWindowSize != null) 'rolling_window_size': rollingWindowSize,
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
    Value<String>? scheduleType,
    Value<String?>? daysOfWeek,
    Value<int?>? rollingWindowSize,
  }) {
    return StageDefinitionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      stageOrder: stageOrder ?? this.stageOrder,
      stageName: stageName ?? this.stageName,
      delayDays: delayDays ?? this.delayDays,
      isDefault: isDefault ?? this.isDefault,
      scheduleType: scheduleType ?? this.scheduleType,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      rollingWindowSize: rollingWindowSize ?? this.rollingWindowSize,
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
    if (scheduleType.present) {
      map['schedule_type'] = Variable<String>(scheduleType.value);
    }
    if (daysOfWeek.present) {
      map['days_of_week'] = Variable<String>(daysOfWeek.value);
    }
    if (rollingWindowSize.present) {
      map['rolling_window_size'] = Variable<int>(rollingWindowSize.value);
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
          ..write('isDefault: $isDefault, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('daysOfWeek: $daysOfWeek, ')
          ..write('rollingWindowSize: $rollingWindowSize')
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

class $LearningLedgerTable extends LearningLedger
    with TableInfo<$LearningLedgerTable, LearningLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningLedgerTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _unitTypeMeta = const VerificationMeta(
    'unitType',
  );
  @override
  late final GeneratedColumn<String> unitType = GeneratedColumn<String>(
    'unit_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdentifierMeta = const VerificationMeta(
    'unitIdentifier',
  );
  @override
  late final GeneratedColumn<String> unitIdentifier = GeneratedColumn<String>(
    'unit_identifier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitDisplayNameHeMeta = const VerificationMeta(
    'unitDisplayNameHe',
  );
  @override
  late final GeneratedColumn<String> unitDisplayNameHe =
      GeneratedColumn<String>(
        'unit_display_name_he',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _unitDisplayNameEnMeta = const VerificationMeta(
    'unitDisplayNameEn',
  );
  @override
  late final GeneratedColumn<String> unitDisplayNameEn =
      GeneratedColumn<String>(
        'unit_display_name_en',
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _completionNumberMeta = const VerificationMeta(
    'completionNumber',
  );
  @override
  late final GeneratedColumn<int> completionNumber = GeneratedColumn<int>(
    'completion_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markedByMeta = const VerificationMeta(
    'markedBy',
  );
  @override
  late final GeneratedColumn<int> markedBy = GeneratedColumn<int>(
    'marked_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<bool> isManual = GeneratedColumn<bool>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    unitType,
    unitIdentifier,
    unitDisplayNameHe,
    unitDisplayNameEn,
    trackType,
    trackId,
    completedAt,
    completionNumber,
    markedBy,
    isManual,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningLedgerData> instance, {
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
    if (data.containsKey('unit_type')) {
      context.handle(
        _unitTypeMeta,
        unitType.isAcceptableOrUnknown(data['unit_type']!, _unitTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_unitTypeMeta);
    }
    if (data.containsKey('unit_identifier')) {
      context.handle(
        _unitIdentifierMeta,
        unitIdentifier.isAcceptableOrUnknown(
          data['unit_identifier']!,
          _unitIdentifierMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitIdentifierMeta);
    }
    if (data.containsKey('unit_display_name_he')) {
      context.handle(
        _unitDisplayNameHeMeta,
        unitDisplayNameHe.isAcceptableOrUnknown(
          data['unit_display_name_he']!,
          _unitDisplayNameHeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitDisplayNameHeMeta);
    }
    if (data.containsKey('unit_display_name_en')) {
      context.handle(
        _unitDisplayNameEnMeta,
        unitDisplayNameEn.isAcceptableOrUnknown(
          data['unit_display_name_en']!,
          _unitDisplayNameEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitDisplayNameEnMeta);
    }
    if (data.containsKey('track_type')) {
      context.handle(
        _trackTypeMeta,
        trackType.isAcceptableOrUnknown(data['track_type']!, _trackTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_trackTypeMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
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
    if (data.containsKey('completion_number')) {
      context.handle(
        _completionNumberMeta,
        completionNumber.isAcceptableOrUnknown(
          data['completion_number']!,
          _completionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completionNumberMeta);
    }
    if (data.containsKey('marked_by')) {
      context.handle(
        _markedByMeta,
        markedBy.isAcceptableOrUnknown(data['marked_by']!, _markedByMeta),
      );
    } else if (isInserting) {
      context.missing(_markedByMeta);
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningLedgerData(
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
      unitType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_type'],
      )!,
      unitIdentifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_identifier'],
      )!,
      unitDisplayNameHe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_display_name_he'],
      )!,
      unitDisplayNameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_display_name_en'],
      )!,
      trackType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_type'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      completionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_number'],
      )!,
      markedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}marked_by'],
      )!,
      isManual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LearningLedgerTable createAlias(String alias) {
    return $LearningLedgerTable(attachedDatabase, alias);
  }
}

class LearningLedgerData extends DataClass
    implements Insertable<LearningLedgerData> {
  final int id;
  final int profileId;
  final String curriculumId;
  final String unitType;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;
  final int? trackId;
  final DateTime completedAt;
  final int completionNumber;
  final int markedBy;
  final bool isManual;
  final DateTime createdAt;
  const LearningLedgerData({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.unitType,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    this.trackId,
    required this.completedAt,
    required this.completionNumber,
    required this.markedBy,
    required this.isManual,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['unit_type'] = Variable<String>(unitType);
    map['unit_identifier'] = Variable<String>(unitIdentifier);
    map['unit_display_name_he'] = Variable<String>(unitDisplayNameHe);
    map['unit_display_name_en'] = Variable<String>(unitDisplayNameEn);
    map['track_type'] = Variable<String>(trackType);
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<int>(trackId);
    }
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['completion_number'] = Variable<int>(completionNumber);
    map['marked_by'] = Variable<int>(markedBy);
    map['is_manual'] = Variable<bool>(isManual);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LearningLedgerCompanion toCompanion(bool nullToAbsent) {
    return LearningLedgerCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      unitType: Value(unitType),
      unitIdentifier: Value(unitIdentifier),
      unitDisplayNameHe: Value(unitDisplayNameHe),
      unitDisplayNameEn: Value(unitDisplayNameEn),
      trackType: Value(trackType),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      completedAt: Value(completedAt),
      completionNumber: Value(completionNumber),
      markedBy: Value(markedBy),
      isManual: Value(isManual),
      createdAt: Value(createdAt),
    );
  }

  factory LearningLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningLedgerData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      unitType: serializer.fromJson<String>(json['unitType']),
      unitIdentifier: serializer.fromJson<String>(json['unitIdentifier']),
      unitDisplayNameHe: serializer.fromJson<String>(json['unitDisplayNameHe']),
      unitDisplayNameEn: serializer.fromJson<String>(json['unitDisplayNameEn']),
      trackType: serializer.fromJson<String>(json['trackType']),
      trackId: serializer.fromJson<int?>(json['trackId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      completionNumber: serializer.fromJson<int>(json['completionNumber']),
      markedBy: serializer.fromJson<int>(json['markedBy']),
      isManual: serializer.fromJson<bool>(json['isManual']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'unitType': serializer.toJson<String>(unitType),
      'unitIdentifier': serializer.toJson<String>(unitIdentifier),
      'unitDisplayNameHe': serializer.toJson<String>(unitDisplayNameHe),
      'unitDisplayNameEn': serializer.toJson<String>(unitDisplayNameEn),
      'trackType': serializer.toJson<String>(trackType),
      'trackId': serializer.toJson<int?>(trackId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'completionNumber': serializer.toJson<int>(completionNumber),
      'markedBy': serializer.toJson<int>(markedBy),
      'isManual': serializer.toJson<bool>(isManual),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LearningLedgerData copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? unitType,
    String? unitIdentifier,
    String? unitDisplayNameHe,
    String? unitDisplayNameEn,
    String? trackType,
    Value<int?> trackId = const Value.absent(),
    DateTime? completedAt,
    int? completionNumber,
    int? markedBy,
    bool? isManual,
    DateTime? createdAt,
  }) => LearningLedgerData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    unitType: unitType ?? this.unitType,
    unitIdentifier: unitIdentifier ?? this.unitIdentifier,
    unitDisplayNameHe: unitDisplayNameHe ?? this.unitDisplayNameHe,
    unitDisplayNameEn: unitDisplayNameEn ?? this.unitDisplayNameEn,
    trackType: trackType ?? this.trackType,
    trackId: trackId.present ? trackId.value : this.trackId,
    completedAt: completedAt ?? this.completedAt,
    completionNumber: completionNumber ?? this.completionNumber,
    markedBy: markedBy ?? this.markedBy,
    isManual: isManual ?? this.isManual,
    createdAt: createdAt ?? this.createdAt,
  );
  LearningLedgerData copyWithCompanion(LearningLedgerCompanion data) {
    return LearningLedgerData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      unitType: data.unitType.present ? data.unitType.value : this.unitType,
      unitIdentifier: data.unitIdentifier.present
          ? data.unitIdentifier.value
          : this.unitIdentifier,
      unitDisplayNameHe: data.unitDisplayNameHe.present
          ? data.unitDisplayNameHe.value
          : this.unitDisplayNameHe,
      unitDisplayNameEn: data.unitDisplayNameEn.present
          ? data.unitDisplayNameEn.value
          : this.unitDisplayNameEn,
      trackType: data.trackType.present ? data.trackType.value : this.trackType,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completionNumber: data.completionNumber.present
          ? data.completionNumber.value
          : this.completionNumber,
      markedBy: data.markedBy.present ? data.markedBy.value : this.markedBy,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningLedgerData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('unitType: $unitType, ')
          ..write('unitIdentifier: $unitIdentifier, ')
          ..write('unitDisplayNameHe: $unitDisplayNameHe, ')
          ..write('unitDisplayNameEn: $unitDisplayNameEn, ')
          ..write('trackType: $trackType, ')
          ..write('trackId: $trackId, ')
          ..write('completedAt: $completedAt, ')
          ..write('completionNumber: $completionNumber, ')
          ..write('markedBy: $markedBy, ')
          ..write('isManual: $isManual, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    unitType,
    unitIdentifier,
    unitDisplayNameHe,
    unitDisplayNameEn,
    trackType,
    trackId,
    completedAt,
    completionNumber,
    markedBy,
    isManual,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningLedgerData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.unitType == this.unitType &&
          other.unitIdentifier == this.unitIdentifier &&
          other.unitDisplayNameHe == this.unitDisplayNameHe &&
          other.unitDisplayNameEn == this.unitDisplayNameEn &&
          other.trackType == this.trackType &&
          other.trackId == this.trackId &&
          other.completedAt == this.completedAt &&
          other.completionNumber == this.completionNumber &&
          other.markedBy == this.markedBy &&
          other.isManual == this.isManual &&
          other.createdAt == this.createdAt);
}

class LearningLedgerCompanion extends UpdateCompanion<LearningLedgerData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> unitType;
  final Value<String> unitIdentifier;
  final Value<String> unitDisplayNameHe;
  final Value<String> unitDisplayNameEn;
  final Value<String> trackType;
  final Value<int?> trackId;
  final Value<DateTime> completedAt;
  final Value<int> completionNumber;
  final Value<int> markedBy;
  final Value<bool> isManual;
  final Value<DateTime> createdAt;
  const LearningLedgerCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.unitType = const Value.absent(),
    this.unitIdentifier = const Value.absent(),
    this.unitDisplayNameHe = const Value.absent(),
    this.unitDisplayNameEn = const Value.absent(),
    this.trackType = const Value.absent(),
    this.trackId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completionNumber = const Value.absent(),
    this.markedBy = const Value.absent(),
    this.isManual = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LearningLedgerCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    required String curriculumId,
    required String unitType,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    this.trackId = const Value.absent(),
    required DateTime completedAt,
    required int completionNumber,
    required int markedBy,
    this.isManual = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       unitType = Value(unitType),
       unitIdentifier = Value(unitIdentifier),
       unitDisplayNameHe = Value(unitDisplayNameHe),
       unitDisplayNameEn = Value(unitDisplayNameEn),
       trackType = Value(trackType),
       completedAt = Value(completedAt),
       completionNumber = Value(completionNumber),
       markedBy = Value(markedBy);
  static Insertable<LearningLedgerData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? unitType,
    Expression<String>? unitIdentifier,
    Expression<String>? unitDisplayNameHe,
    Expression<String>? unitDisplayNameEn,
    Expression<String>? trackType,
    Expression<int>? trackId,
    Expression<DateTime>? completedAt,
    Expression<int>? completionNumber,
    Expression<int>? markedBy,
    Expression<bool>? isManual,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (unitType != null) 'unit_type': unitType,
      if (unitIdentifier != null) 'unit_identifier': unitIdentifier,
      if (unitDisplayNameHe != null) 'unit_display_name_he': unitDisplayNameHe,
      if (unitDisplayNameEn != null) 'unit_display_name_en': unitDisplayNameEn,
      if (trackType != null) 'track_type': trackType,
      if (trackId != null) 'track_id': trackId,
      if (completedAt != null) 'completed_at': completedAt,
      if (completionNumber != null) 'completion_number': completionNumber,
      if (markedBy != null) 'marked_by': markedBy,
      if (isManual != null) 'is_manual': isManual,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LearningLedgerCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? unitType,
    Value<String>? unitIdentifier,
    Value<String>? unitDisplayNameHe,
    Value<String>? unitDisplayNameEn,
    Value<String>? trackType,
    Value<int?>? trackId,
    Value<DateTime>? completedAt,
    Value<int>? completionNumber,
    Value<int>? markedBy,
    Value<bool>? isManual,
    Value<DateTime>? createdAt,
  }) {
    return LearningLedgerCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      unitType: unitType ?? this.unitType,
      unitIdentifier: unitIdentifier ?? this.unitIdentifier,
      unitDisplayNameHe: unitDisplayNameHe ?? this.unitDisplayNameHe,
      unitDisplayNameEn: unitDisplayNameEn ?? this.unitDisplayNameEn,
      trackType: trackType ?? this.trackType,
      trackId: trackId ?? this.trackId,
      completedAt: completedAt ?? this.completedAt,
      completionNumber: completionNumber ?? this.completionNumber,
      markedBy: markedBy ?? this.markedBy,
      isManual: isManual ?? this.isManual,
      createdAt: createdAt ?? this.createdAt,
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
    if (unitType.present) {
      map['unit_type'] = Variable<String>(unitType.value);
    }
    if (unitIdentifier.present) {
      map['unit_identifier'] = Variable<String>(unitIdentifier.value);
    }
    if (unitDisplayNameHe.present) {
      map['unit_display_name_he'] = Variable<String>(unitDisplayNameHe.value);
    }
    if (unitDisplayNameEn.present) {
      map['unit_display_name_en'] = Variable<String>(unitDisplayNameEn.value);
    }
    if (trackType.present) {
      map['track_type'] = Variable<String>(trackType.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completionNumber.present) {
      map['completion_number'] = Variable<int>(completionNumber.value);
    }
    if (markedBy.present) {
      map['marked_by'] = Variable<int>(markedBy.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<bool>(isManual.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningLedgerCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('unitType: $unitType, ')
          ..write('unitIdentifier: $unitIdentifier, ')
          ..write('unitDisplayNameHe: $unitDisplayNameHe, ')
          ..write('unitDisplayNameEn: $unitDisplayNameEn, ')
          ..write('trackType: $trackType, ')
          ..write('trackId: $trackId, ')
          ..write('completedAt: $completedAt, ')
          ..write('completionNumber: $completionNumber, ')
          ..write('markedBy: $markedBy, ')
          ..write('isManual: $isManual, ')
          ..write('createdAt: $createdAt')
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
  static const VerificationMeta _goalTypeMeta = const VerificationMeta(
    'goalType',
  );
  @override
  late final GeneratedColumn<String> goalType = GeneratedColumn<String>(
    'goal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('deadline'),
  );
  static const VerificationMeta _paceValueMeta = const VerificationMeta(
    'paceValue',
  );
  @override
  late final GeneratedColumn<int> paceValue = GeneratedColumn<int>(
    'pace_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paceUnitMeta = const VerificationMeta(
    'paceUnit',
  );
  @override
  late final GeneratedColumn<String> paceUnit = GeneratedColumn<String>(
    'pace_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _learningUnitMeta = const VerificationMeta(
    'learningUnit',
  );
  @override
  late final GeneratedColumn<String> learningUnit = GeneratedColumn<String>(
    'learning_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    goalType,
    paceValue,
    paceUnit,
    learningUnit,
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
    if (data.containsKey('goal_type')) {
      context.handle(
        _goalTypeMeta,
        goalType.isAcceptableOrUnknown(data['goal_type']!, _goalTypeMeta),
      );
    }
    if (data.containsKey('pace_value')) {
      context.handle(
        _paceValueMeta,
        paceValue.isAcceptableOrUnknown(data['pace_value']!, _paceValueMeta),
      );
    }
    if (data.containsKey('pace_unit')) {
      context.handle(
        _paceUnitMeta,
        paceUnit.isAcceptableOrUnknown(data['pace_unit']!, _paceUnitMeta),
      );
    }
    if (data.containsKey('learning_unit')) {
      context.handle(
        _learningUnitMeta,
        learningUnit.isAcceptableOrUnknown(
          data['learning_unit']!,
          _learningUnitMeta,
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
      goalType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_type'],
      )!,
      paceValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pace_value'],
      ),
      paceUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace_unit'],
      ),
      learningUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_unit'],
      ),
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
  final String goalType;
  final int? paceValue;
  final String? paceUnit;

  /// Learning unit: 'amud', 'daf', or null. Used for Bavli/Yerushalmi curricula.
  final String? learningUnit;
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
    required this.goalType,
    this.paceValue,
    this.paceUnit,
    this.learningUnit,
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
    map['goal_type'] = Variable<String>(goalType);
    if (!nullToAbsent || paceValue != null) {
      map['pace_value'] = Variable<int>(paceValue);
    }
    if (!nullToAbsent || paceUnit != null) {
      map['pace_unit'] = Variable<String>(paceUnit);
    }
    if (!nullToAbsent || learningUnit != null) {
      map['learning_unit'] = Variable<String>(learningUnit);
    }
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
      goalType: Value(goalType),
      paceValue: paceValue == null && nullToAbsent
          ? const Value.absent()
          : Value(paceValue),
      paceUnit: paceUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(paceUnit),
      learningUnit: learningUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(learningUnit),
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
      goalType: serializer.fromJson<String>(json['goalType']),
      paceValue: serializer.fromJson<int?>(json['paceValue']),
      paceUnit: serializer.fromJson<String?>(json['paceUnit']),
      learningUnit: serializer.fromJson<String?>(json['learningUnit']),
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
      'goalType': serializer.toJson<String>(goalType),
      'paceValue': serializer.toJson<int?>(paceValue),
      'paceUnit': serializer.toJson<String?>(paceUnit),
      'learningUnit': serializer.toJson<String?>(learningUnit),
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
    String? goalType,
    Value<int?> paceValue = const Value.absent(),
    Value<String?> paceUnit = const Value.absent(),
    Value<String?> learningUnit = const Value.absent(),
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
    goalType: goalType ?? this.goalType,
    paceValue: paceValue.present ? paceValue.value : this.paceValue,
    paceUnit: paceUnit.present ? paceUnit.value : this.paceUnit,
    learningUnit: learningUnit.present ? learningUnit.value : this.learningUnit,
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
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      paceValue: data.paceValue.present ? data.paceValue.value : this.paceValue,
      paceUnit: data.paceUnit.present ? data.paceUnit.value : this.paceUnit,
      learningUnit: data.learningUnit.present
          ? data.learningUnit.value
          : this.learningUnit,
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
          ..write('goalType: $goalType, ')
          ..write('paceValue: $paceValue, ')
          ..write('paceUnit: $paceUnit, ')
          ..write('learningUnit: $learningUnit, ')
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
    goalType,
    paceValue,
    paceUnit,
    learningUnit,
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
          other.goalType == this.goalType &&
          other.paceValue == this.paceValue &&
          other.paceUnit == this.paceUnit &&
          other.learningUnit == this.learningUnit &&
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
  final Value<String> goalType;
  final Value<int?> paceValue;
  final Value<String?> paceUnit;
  final Value<String?> learningUnit;
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
    this.goalType = const Value.absent(),
    this.paceValue = const Value.absent(),
    this.paceUnit = const Value.absent(),
    this.learningUnit = const Value.absent(),
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
    this.goalType = const Value.absent(),
    this.paceValue = const Value.absent(),
    this.paceUnit = const Value.absent(),
    this.learningUnit = const Value.absent(),
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
    Expression<String>? goalType,
    Expression<int>? paceValue,
    Expression<String>? paceUnit,
    Expression<String>? learningUnit,
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
      if (goalType != null) 'goal_type': goalType,
      if (paceValue != null) 'pace_value': paceValue,
      if (paceUnit != null) 'pace_unit': paceUnit,
      if (learningUnit != null) 'learning_unit': learningUnit,
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
    Value<String>? goalType,
    Value<int?>? paceValue,
    Value<String?>? paceUnit,
    Value<String?>? learningUnit,
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
      goalType: goalType ?? this.goalType,
      paceValue: paceValue ?? this.paceValue,
      paceUnit: paceUnit ?? this.paceUnit,
      learningUnit: learningUnit ?? this.learningUnit,
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
    if (goalType.present) {
      map['goal_type'] = Variable<String>(goalType.value);
    }
    if (paceValue.present) {
      map['pace_value'] = Variable<int>(paceValue.value);
    }
    if (paceUnit.present) {
      map['pace_unit'] = Variable<String>(paceUnit.value);
    }
    if (learningUnit.present) {
      map['learning_unit'] = Variable<String>(learningUnit.value);
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
          ..write('goalType: $goalType, ')
          ..write('paceValue: $paceValue, ')
          ..write('paceUnit: $paceUnit, ')
          ..write('learningUnit: $learningUnit, ')
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
  static const VerificationMeta _rewardModeMeta = const VerificationMeta(
    'rewardMode',
  );
  @override
  late final GeneratedColumn<String> rewardMode = GeneratedColumn<String>(
    'reward_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('specific'),
  );
  static const VerificationMeta _milestoneTypeMeta = const VerificationMeta(
    'milestoneType',
  );
  @override
  late final GeneratedColumn<String> milestoneType = GeneratedColumn<String>(
    'milestone_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('points'),
  );
  static const VerificationMeta _isVisibleMeta = const VerificationMeta(
    'isVisible',
  );
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
    'is_visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _poolIdMeta = const VerificationMeta('poolId');
  @override
  late final GeneratedColumn<int> poolId = GeneratedColumn<int>(
    'pool_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatIntervalMeta = const VerificationMeta(
    'repeatInterval',
  );
  @override
  late final GeneratedColumn<int> repeatInterval = GeneratedColumn<int>(
    'repeat_interval',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    rewardMode,
    milestoneType,
    isVisible,
    poolId,
    repeatInterval,
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
    if (data.containsKey('reward_mode')) {
      context.handle(
        _rewardModeMeta,
        rewardMode.isAcceptableOrUnknown(data['reward_mode']!, _rewardModeMeta),
      );
    }
    if (data.containsKey('milestone_type')) {
      context.handle(
        _milestoneTypeMeta,
        milestoneType.isAcceptableOrUnknown(
          data['milestone_type']!,
          _milestoneTypeMeta,
        ),
      );
    }
    if (data.containsKey('is_visible')) {
      context.handle(
        _isVisibleMeta,
        isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta),
      );
    }
    if (data.containsKey('pool_id')) {
      context.handle(
        _poolIdMeta,
        poolId.isAcceptableOrUnknown(data['pool_id']!, _poolIdMeta),
      );
    }
    if (data.containsKey('repeat_interval')) {
      context.handle(
        _repeatIntervalMeta,
        repeatInterval.isAcceptableOrUnknown(
          data['repeat_interval']!,
          _repeatIntervalMeta,
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
      rewardMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_mode'],
      )!,
      milestoneType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}milestone_type'],
      )!,
      isVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_visible'],
      )!,
      poolId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pool_id'],
      ),
      repeatInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_interval'],
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

  /// 'specific' (single reward) or 'pool' (child picks from pool)
  final String rewardMode;

  /// Milestone trigger: 'points', 'finish_masechta', 'finish_seder', 'every_n_items'
  final String milestoneType;

  /// Whether the reward is visible to the child (vs surprise)
  final bool isVisible;

  /// Links to reward_pools.id for pool-mode rewards
  final int? poolId;

  /// For 'every_n_items' milestone type — triggers every N completions
  final int? repeatInterval;
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
    required this.rewardMode,
    required this.milestoneType,
    required this.isVisible,
    this.poolId,
    this.repeatInterval,
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
    map['reward_mode'] = Variable<String>(rewardMode);
    map['milestone_type'] = Variable<String>(milestoneType);
    map['is_visible'] = Variable<bool>(isVisible);
    if (!nullToAbsent || poolId != null) {
      map['pool_id'] = Variable<int>(poolId);
    }
    if (!nullToAbsent || repeatInterval != null) {
      map['repeat_interval'] = Variable<int>(repeatInterval);
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
      rewardMode: Value(rewardMode),
      milestoneType: Value(milestoneType),
      isVisible: Value(isVisible),
      poolId: poolId == null && nullToAbsent
          ? const Value.absent()
          : Value(poolId),
      repeatInterval: repeatInterval == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatInterval),
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
      rewardMode: serializer.fromJson<String>(json['rewardMode']),
      milestoneType: serializer.fromJson<String>(json['milestoneType']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      poolId: serializer.fromJson<int?>(json['poolId']),
      repeatInterval: serializer.fromJson<int?>(json['repeatInterval']),
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
      'rewardMode': serializer.toJson<String>(rewardMode),
      'milestoneType': serializer.toJson<String>(milestoneType),
      'isVisible': serializer.toJson<bool>(isVisible),
      'poolId': serializer.toJson<int?>(poolId),
      'repeatInterval': serializer.toJson<int?>(repeatInterval),
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
    String? rewardMode,
    String? milestoneType,
    bool? isVisible,
    Value<int?> poolId = const Value.absent(),
    Value<int?> repeatInterval = const Value.absent(),
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
    rewardMode: rewardMode ?? this.rewardMode,
    milestoneType: milestoneType ?? this.milestoneType,
    isVisible: isVisible ?? this.isVisible,
    poolId: poolId.present ? poolId.value : this.poolId,
    repeatInterval: repeatInterval.present
        ? repeatInterval.value
        : this.repeatInterval,
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
      rewardMode: data.rewardMode.present
          ? data.rewardMode.value
          : this.rewardMode,
      milestoneType: data.milestoneType.present
          ? data.milestoneType.value
          : this.milestoneType,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      poolId: data.poolId.present ? data.poolId.value : this.poolId,
      repeatInterval: data.repeatInterval.present
          ? data.repeatInterval.value
          : this.repeatInterval,
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
          ..write('curriculumId: $curriculumId, ')
          ..write('rewardMode: $rewardMode, ')
          ..write('milestoneType: $milestoneType, ')
          ..write('isVisible: $isVisible, ')
          ..write('poolId: $poolId, ')
          ..write('repeatInterval: $repeatInterval')
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
    rewardMode,
    milestoneType,
    isVisible,
    poolId,
    repeatInterval,
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
          other.curriculumId == this.curriculumId &&
          other.rewardMode == this.rewardMode &&
          other.milestoneType == this.milestoneType &&
          other.isVisible == this.isVisible &&
          other.poolId == this.poolId &&
          other.repeatInterval == this.repeatInterval);
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
  final Value<String> rewardMode;
  final Value<String> milestoneType;
  final Value<bool> isVisible;
  final Value<int?> poolId;
  final Value<int?> repeatInterval;
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
    this.rewardMode = const Value.absent(),
    this.milestoneType = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.poolId = const Value.absent(),
    this.repeatInterval = const Value.absent(),
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
    this.rewardMode = const Value.absent(),
    this.milestoneType = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.poolId = const Value.absent(),
    this.repeatInterval = const Value.absent(),
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
    Expression<String>? rewardMode,
    Expression<String>? milestoneType,
    Expression<bool>? isVisible,
    Expression<int>? poolId,
    Expression<int>? repeatInterval,
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
      if (rewardMode != null) 'reward_mode': rewardMode,
      if (milestoneType != null) 'milestone_type': milestoneType,
      if (isVisible != null) 'is_visible': isVisible,
      if (poolId != null) 'pool_id': poolId,
      if (repeatInterval != null) 'repeat_interval': repeatInterval,
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
    Value<String>? rewardMode,
    Value<String>? milestoneType,
    Value<bool>? isVisible,
    Value<int?>? poolId,
    Value<int?>? repeatInterval,
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
      rewardMode: rewardMode ?? this.rewardMode,
      milestoneType: milestoneType ?? this.milestoneType,
      isVisible: isVisible ?? this.isVisible,
      poolId: poolId ?? this.poolId,
      repeatInterval: repeatInterval ?? this.repeatInterval,
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
    if (rewardMode.present) {
      map['reward_mode'] = Variable<String>(rewardMode.value);
    }
    if (milestoneType.present) {
      map['milestone_type'] = Variable<String>(milestoneType.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (poolId.present) {
      map['pool_id'] = Variable<int>(poolId.value);
    }
    if (repeatInterval.present) {
      map['repeat_interval'] = Variable<int>(repeatInterval.value);
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
          ..write('curriculumId: $curriculumId, ')
          ..write('rewardMode: $rewardMode, ')
          ..write('milestoneType: $milestoneType, ')
          ..write('isVisible: $isVisible, ')
          ..write('poolId: $poolId, ')
          ..write('repeatInterval: $repeatInterval')
          ..write(')'))
        .toString();
  }
}

class $RewardPoolsTable extends RewardPools
    with TableInfo<$RewardPoolsTable, RewardPool> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardPoolsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    profileId,
    isShared,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reward_pools';
  @override
  VerificationContext validateIntegrity(
    Insertable<RewardPool> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RewardPool map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewardPool(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RewardPoolsTable createAlias(String alias) {
    return $RewardPoolsTable(attachedDatabase, alias);
  }
}

class RewardPool extends DataClass implements Insertable<RewardPool> {
  final int id;
  final String name;
  final int profileId;
  final bool isShared;
  final DateTime createdAt;
  const RewardPool({
    required this.id,
    required this.name,
    required this.profileId,
    required this.isShared,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['profile_id'] = Variable<int>(profileId);
    map['is_shared'] = Variable<bool>(isShared);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RewardPoolsCompanion toCompanion(bool nullToAbsent) {
    return RewardPoolsCompanion(
      id: Value(id),
      name: Value(name),
      profileId: Value(profileId),
      isShared: Value(isShared),
      createdAt: Value(createdAt),
    );
  }

  factory RewardPool.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewardPool(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      profileId: serializer.fromJson<int>(json['profileId']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'profileId': serializer.toJson<int>(profileId),
      'isShared': serializer.toJson<bool>(isShared),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RewardPool copyWith({
    int? id,
    String? name,
    int? profileId,
    bool? isShared,
    DateTime? createdAt,
  }) => RewardPool(
    id: id ?? this.id,
    name: name ?? this.name,
    profileId: profileId ?? this.profileId,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
  );
  RewardPool copyWithCompanion(RewardPoolsCompanion data) {
    return RewardPool(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewardPool(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('profileId: $profileId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, profileId, isShared, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewardPool &&
          other.id == this.id &&
          other.name == this.name &&
          other.profileId == this.profileId &&
          other.isShared == this.isShared &&
          other.createdAt == this.createdAt);
}

class RewardPoolsCompanion extends UpdateCompanion<RewardPool> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> profileId;
  final Value<bool> isShared;
  final Value<DateTime> createdAt;
  const RewardPoolsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.profileId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RewardPoolsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int profileId,
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       profileId = Value(profileId);
  static Insertable<RewardPool> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? profileId,
    Expression<bool>? isShared,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (profileId != null) 'profile_id': profileId,
      if (isShared != null) 'is_shared': isShared,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RewardPoolsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? profileId,
    Value<bool>? isShared,
    Value<DateTime>? createdAt,
  }) {
    return RewardPoolsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      profileId: profileId ?? this.profileId,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardPoolsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('profileId: $profileId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RewardPoolItemsTable extends RewardPoolItems
    with TableInfo<$RewardPoolItemsTable, RewardPoolItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardPoolItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _poolIdMeta = const VerificationMeta('poolId');
  @override
  late final GeneratedColumn<int> poolId = GeneratedColumn<int>(
    'pool_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isUsedMeta = const VerificationMeta('isUsed');
  @override
  late final GeneratedColumn<bool> isUsed = GeneratedColumn<bool>(
    'is_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_used" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poolId,
    title,
    description,
    isUsed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reward_pool_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<RewardPoolItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pool_id')) {
      context.handle(
        _poolIdMeta,
        poolId.isAcceptableOrUnknown(data['pool_id']!, _poolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poolIdMeta);
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
    }
    if (data.containsKey('is_used')) {
      context.handle(
        _isUsedMeta,
        isUsed.isAcceptableOrUnknown(data['is_used']!, _isUsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RewardPoolItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewardPoolItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      poolId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pool_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      isUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_used'],
      )!,
    );
  }

  @override
  $RewardPoolItemsTable createAlias(String alias) {
    return $RewardPoolItemsTable(attachedDatabase, alias);
  }
}

class RewardPoolItem extends DataClass implements Insertable<RewardPoolItem> {
  final int id;
  final int poolId;
  final String title;
  final String description;
  final bool isUsed;
  const RewardPoolItem({
    required this.id,
    required this.poolId,
    required this.title,
    required this.description,
    required this.isUsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pool_id'] = Variable<int>(poolId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['is_used'] = Variable<bool>(isUsed);
    return map;
  }

  RewardPoolItemsCompanion toCompanion(bool nullToAbsent) {
    return RewardPoolItemsCompanion(
      id: Value(id),
      poolId: Value(poolId),
      title: Value(title),
      description: Value(description),
      isUsed: Value(isUsed),
    );
  }

  factory RewardPoolItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewardPoolItem(
      id: serializer.fromJson<int>(json['id']),
      poolId: serializer.fromJson<int>(json['poolId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      isUsed: serializer.fromJson<bool>(json['isUsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'poolId': serializer.toJson<int>(poolId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'isUsed': serializer.toJson<bool>(isUsed),
    };
  }

  RewardPoolItem copyWith({
    int? id,
    int? poolId,
    String? title,
    String? description,
    bool? isUsed,
  }) => RewardPoolItem(
    id: id ?? this.id,
    poolId: poolId ?? this.poolId,
    title: title ?? this.title,
    description: description ?? this.description,
    isUsed: isUsed ?? this.isUsed,
  );
  RewardPoolItem copyWithCompanion(RewardPoolItemsCompanion data) {
    return RewardPoolItem(
      id: data.id.present ? data.id.value : this.id,
      poolId: data.poolId.present ? data.poolId.value : this.poolId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      isUsed: data.isUsed.present ? data.isUsed.value : this.isUsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewardPoolItem(')
          ..write('id: $id, ')
          ..write('poolId: $poolId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isUsed: $isUsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, poolId, title, description, isUsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewardPoolItem &&
          other.id == this.id &&
          other.poolId == this.poolId &&
          other.title == this.title &&
          other.description == this.description &&
          other.isUsed == this.isUsed);
}

class RewardPoolItemsCompanion extends UpdateCompanion<RewardPoolItem> {
  final Value<int> id;
  final Value<int> poolId;
  final Value<String> title;
  final Value<String> description;
  final Value<bool> isUsed;
  const RewardPoolItemsCompanion({
    this.id = const Value.absent(),
    this.poolId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.isUsed = const Value.absent(),
  });
  RewardPoolItemsCompanion.insert({
    this.id = const Value.absent(),
    required int poolId,
    required String title,
    this.description = const Value.absent(),
    this.isUsed = const Value.absent(),
  }) : poolId = Value(poolId),
       title = Value(title);
  static Insertable<RewardPoolItem> custom({
    Expression<int>? id,
    Expression<int>? poolId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? isUsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poolId != null) 'pool_id': poolId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isUsed != null) 'is_used': isUsed,
    });
  }

  RewardPoolItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? poolId,
    Value<String>? title,
    Value<String>? description,
    Value<bool>? isUsed,
  }) {
    return RewardPoolItemsCompanion(
      id: id ?? this.id,
      poolId: poolId ?? this.poolId,
      title: title ?? this.title,
      description: description ?? this.description,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (poolId.present) {
      map['pool_id'] = Variable<int>(poolId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isUsed.present) {
      map['is_used'] = Variable<bool>(isUsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardPoolItemsCompanion(')
          ..write('id: $id, ')
          ..write('poolId: $poolId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isUsed: $isUsed')
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
  static const VerificationMeta _graceUsedDateMeta = const VerificationMeta(
    'graceUsedDate',
  );
  @override
  late final GeneratedColumn<DateTime> graceUsedDate =
      GeneratedColumn<DateTime>(
        'grace_used_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _gracePeriodDaysMeta = const VerificationMeta(
    'gracePeriodDays',
  );
  @override
  late final GeneratedColumn<int> gracePeriodDays = GeneratedColumn<int>(
    'grace_period_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    currentStreak,
    maxStreak,
    lastCompletionDate,
    graceUsedDate,
    gracePeriodDays,
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
    if (data.containsKey('grace_used_date')) {
      context.handle(
        _graceUsedDateMeta,
        graceUsedDate.isAcceptableOrUnknown(
          data['grace_used_date']!,
          _graceUsedDateMeta,
        ),
      );
    }
    if (data.containsKey('grace_period_days')) {
      context.handle(
        _gracePeriodDaysMeta,
        gracePeriodDays.isAcceptableOrUnknown(
          data['grace_period_days']!,
          _gracePeriodDaysMeta,
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
      graceUsedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}grace_used_date'],
      ),
      gracePeriodDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_period_days'],
      )!,
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
  final DateTime? graceUsedDate;
  final int gracePeriodDays;
  const Streak({
    required this.id,
    required this.profileId,
    required this.currentStreak,
    required this.maxStreak,
    this.lastCompletionDate,
    this.graceUsedDate,
    required this.gracePeriodDays,
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
    if (!nullToAbsent || graceUsedDate != null) {
      map['grace_used_date'] = Variable<DateTime>(graceUsedDate);
    }
    map['grace_period_days'] = Variable<int>(gracePeriodDays);
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
      graceUsedDate: graceUsedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(graceUsedDate),
      gracePeriodDays: Value(gracePeriodDays),
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
      graceUsedDate: serializer.fromJson<DateTime?>(json['graceUsedDate']),
      gracePeriodDays: serializer.fromJson<int>(json['gracePeriodDays']),
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
      'graceUsedDate': serializer.toJson<DateTime?>(graceUsedDate),
      'gracePeriodDays': serializer.toJson<int>(gracePeriodDays),
    };
  }

  Streak copyWith({
    int? id,
    int? profileId,
    int? currentStreak,
    int? maxStreak,
    Value<DateTime?> lastCompletionDate = const Value.absent(),
    Value<DateTime?> graceUsedDate = const Value.absent(),
    int? gracePeriodDays,
  }) => Streak(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    currentStreak: currentStreak ?? this.currentStreak,
    maxStreak: maxStreak ?? this.maxStreak,
    lastCompletionDate: lastCompletionDate.present
        ? lastCompletionDate.value
        : this.lastCompletionDate,
    graceUsedDate: graceUsedDate.present
        ? graceUsedDate.value
        : this.graceUsedDate,
    gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
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
      graceUsedDate: data.graceUsedDate.present
          ? data.graceUsedDate.value
          : this.graceUsedDate,
      gracePeriodDays: data.gracePeriodDays.present
          ? data.gracePeriodDays.value
          : this.gracePeriodDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Streak(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('maxStreak: $maxStreak, ')
          ..write('lastCompletionDate: $lastCompletionDate, ')
          ..write('graceUsedDate: $graceUsedDate, ')
          ..write('gracePeriodDays: $gracePeriodDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    currentStreak,
    maxStreak,
    lastCompletionDate,
    graceUsedDate,
    gracePeriodDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Streak &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.currentStreak == this.currentStreak &&
          other.maxStreak == this.maxStreak &&
          other.lastCompletionDate == this.lastCompletionDate &&
          other.graceUsedDate == this.graceUsedDate &&
          other.gracePeriodDays == this.gracePeriodDays);
}

class StreaksCompanion extends UpdateCompanion<Streak> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<int> currentStreak;
  final Value<int> maxStreak;
  final Value<DateTime?> lastCompletionDate;
  final Value<DateTime?> graceUsedDate;
  final Value<int> gracePeriodDays;
  const StreaksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.lastCompletionDate = const Value.absent(),
    this.graceUsedDate = const Value.absent(),
    this.gracePeriodDays = const Value.absent(),
  });
  StreaksCompanion.insert({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.lastCompletionDate = const Value.absent(),
    this.graceUsedDate = const Value.absent(),
    this.gracePeriodDays = const Value.absent(),
  });
  static Insertable<Streak> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<int>? currentStreak,
    Expression<int>? maxStreak,
    Expression<DateTime>? lastCompletionDate,
    Expression<DateTime>? graceUsedDate,
    Expression<int>? gracePeriodDays,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (maxStreak != null) 'max_streak': maxStreak,
      if (lastCompletionDate != null)
        'last_completion_date': lastCompletionDate,
      if (graceUsedDate != null) 'grace_used_date': graceUsedDate,
      if (gracePeriodDays != null) 'grace_period_days': gracePeriodDays,
    });
  }

  StreaksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<int>? currentStreak,
    Value<int>? maxStreak,
    Value<DateTime?>? lastCompletionDate,
    Value<DateTime?>? graceUsedDate,
    Value<int>? gracePeriodDays,
  }) {
    return StreaksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
      graceUsedDate: graceUsedDate ?? this.graceUsedDate,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
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
    if (graceUsedDate.present) {
      map['grace_used_date'] = Variable<DateTime>(graceUsedDate.value);
    }
    if (gracePeriodDays.present) {
      map['grace_period_days'] = Variable<int>(gracePeriodDays.value);
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
          ..write('lastCompletionDate: $lastCompletionDate, ')
          ..write('graceUsedDate: $graceUsedDate, ')
          ..write('gracePeriodDays: $gracePeriodDays')
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

class $ContentDownloadStatusesTable extends ContentDownloadStatuses
    with TableInfo<$ContentDownloadStatusesTable, ContentDownloadStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentDownloadStatusesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentVersionMeta = const VerificationMeta(
    'contentVersion',
  );
  @override
  late final GeneratedColumn<String> contentVersion = GeneratedColumn<String>(
    'content_version',
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
  @override
  List<GeneratedColumn> get $columns => [
    curriculumId,
    languageCode,
    contentVersion,
    itemCount,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_download_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentDownloadStatuse> instance, {
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
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageCodeMeta);
    }
    if (data.containsKey('content_version')) {
      context.handle(
        _contentVersionMeta,
        contentVersion.isAcceptableOrUnknown(
          data['content_version']!,
          _contentVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentVersionMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {curriculumId, languageCode};
  @override
  ContentDownloadStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentDownloadStatuse(
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      contentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_version'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
    );
  }

  @override
  $ContentDownloadStatusesTable createAlias(String alias) {
    return $ContentDownloadStatusesTable(attachedDatabase, alias);
  }
}

class ContentDownloadStatuse extends DataClass
    implements Insertable<ContentDownloadStatuse> {
  /// curriculum_id from CurriculumId enum storageKey
  final String curriculumId;

  /// Language code of the downloaded content (e.g. 'he', 'en')
  final String languageCode;

  /// Version string of the content
  final String contentVersion;

  /// Number of content items in this download
  final int itemCount;

  /// When the download completed
  final DateTime downloadedAt;
  const ContentDownloadStatuse({
    required this.curriculumId,
    required this.languageCode,
    required this.contentVersion,
    required this.itemCount,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['language_code'] = Variable<String>(languageCode);
    map['content_version'] = Variable<String>(contentVersion);
    map['item_count'] = Variable<int>(itemCount);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  ContentDownloadStatusesCompanion toCompanion(bool nullToAbsent) {
    return ContentDownloadStatusesCompanion(
      curriculumId: Value(curriculumId),
      languageCode: Value(languageCode),
      contentVersion: Value(contentVersion),
      itemCount: Value(itemCount),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory ContentDownloadStatuse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentDownloadStatuse(
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      contentVersion: serializer.fromJson<String>(json['contentVersion']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'curriculumId': serializer.toJson<String>(curriculumId),
      'languageCode': serializer.toJson<String>(languageCode),
      'contentVersion': serializer.toJson<String>(contentVersion),
      'itemCount': serializer.toJson<int>(itemCount),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  ContentDownloadStatuse copyWith({
    String? curriculumId,
    String? languageCode,
    String? contentVersion,
    int? itemCount,
    DateTime? downloadedAt,
  }) => ContentDownloadStatuse(
    curriculumId: curriculumId ?? this.curriculumId,
    languageCode: languageCode ?? this.languageCode,
    contentVersion: contentVersion ?? this.contentVersion,
    itemCount: itemCount ?? this.itemCount,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  ContentDownloadStatuse copyWithCompanion(
    ContentDownloadStatusesCompanion data,
  ) {
    return ContentDownloadStatuse(
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentDownloadStatuse(')
          ..write('curriculumId: $curriculumId, ')
          ..write('languageCode: $languageCode, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('itemCount: $itemCount, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    curriculumId,
    languageCode,
    contentVersion,
    itemCount,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentDownloadStatuse &&
          other.curriculumId == this.curriculumId &&
          other.languageCode == this.languageCode &&
          other.contentVersion == this.contentVersion &&
          other.itemCount == this.itemCount &&
          other.downloadedAt == this.downloadedAt);
}

class ContentDownloadStatusesCompanion
    extends UpdateCompanion<ContentDownloadStatuse> {
  final Value<String> curriculumId;
  final Value<String> languageCode;
  final Value<String> contentVersion;
  final Value<int> itemCount;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const ContentDownloadStatusesCompanion({
    this.curriculumId = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentDownloadStatusesCompanion.insert({
    required String curriculumId,
    required String languageCode,
    required String contentVersion,
    required int itemCount,
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       languageCode = Value(languageCode),
       contentVersion = Value(contentVersion),
       itemCount = Value(itemCount),
       downloadedAt = Value(downloadedAt);
  static Insertable<ContentDownloadStatuse> custom({
    Expression<String>? curriculumId,
    Expression<String>? languageCode,
    Expression<String>? contentVersion,
    Expression<int>? itemCount,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (languageCode != null) 'language_code': languageCode,
      if (contentVersion != null) 'content_version': contentVersion,
      if (itemCount != null) 'item_count': itemCount,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentDownloadStatusesCompanion copyWith({
    Value<String>? curriculumId,
    Value<String>? languageCode,
    Value<String>? contentVersion,
    Value<int>? itemCount,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return ContentDownloadStatusesCompanion(
      curriculumId: curriculumId ?? this.curriculumId,
      languageCode: languageCode ?? this.languageCode,
      contentVersion: contentVersion ?? this.contentVersion,
      itemCount: itemCount ?? this.itemCount,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<String>(contentVersion.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentDownloadStatusesCompanion(')
          ..write('curriculumId: $curriculumId, ')
          ..write('languageCode: $languageCode, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('itemCount: $itemCount, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningProgramsTable extends LearningPrograms
    with TableInfo<$LearningProgramsTable, LearningProgram> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningProgramsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _curriculumTypeMeta = const VerificationMeta(
    'curriculumType',
  );
  @override
  late final GeneratedColumn<String> curriculumType = GeneratedColumn<String>(
    'curriculum_type',
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
  static const VerificationMeta _stagesConfigMeta = const VerificationMeta(
    'stagesConfig',
  );
  @override
  late final GeneratedColumn<String> stagesConfig = GeneratedColumn<String>(
    'stages_config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasTestsMeta = const VerificationMeta(
    'hasTests',
  );
  @override
  late final GeneratedColumn<bool> hasTests = GeneratedColumn<bool>(
    'has_tests',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_tests" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _testConfigMeta = const VerificationMeta(
    'testConfig',
  );
  @override
  late final GeneratedColumn<String> testConfig = GeneratedColumn<String>(
    'test_config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
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
  static const VerificationMeta _apiSourceMeta = const VerificationMeta(
    'apiSource',
  );
  @override
  late final GeneratedColumn<String> apiSource = GeneratedColumn<String>(
    'api_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiProgramKeyMeta = const VerificationMeta(
    'apiProgramKey',
  );
  @override
  late final GeneratedColumn<String> apiProgramKey = GeneratedColumn<String>(
    'api_program_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCalendarProgramMeta = const VerificationMeta(
    'isCalendarProgram',
  );
  @override
  late final GeneratedColumn<bool> isCalendarProgram = GeneratedColumn<bool>(
    'is_calendar_program',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_calendar_program" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    displayName,
    description,
    curriculumType,
    isActive,
    stagesConfig,
    hasTests,
    testConfig,
    createdAt,
    apiSource,
    apiProgramKey,
    isCalendarProgram,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningProgram> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('curriculum_type')) {
      context.handle(
        _curriculumTypeMeta,
        curriculumType.isAcceptableOrUnknown(
          data['curriculum_type']!,
          _curriculumTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumTypeMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('stages_config')) {
      context.handle(
        _stagesConfigMeta,
        stagesConfig.isAcceptableOrUnknown(
          data['stages_config']!,
          _stagesConfigMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stagesConfigMeta);
    }
    if (data.containsKey('has_tests')) {
      context.handle(
        _hasTestsMeta,
        hasTests.isAcceptableOrUnknown(data['has_tests']!, _hasTestsMeta),
      );
    }
    if (data.containsKey('test_config')) {
      context.handle(
        _testConfigMeta,
        testConfig.isAcceptableOrUnknown(data['test_config']!, _testConfigMeta),
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
    if (data.containsKey('api_source')) {
      context.handle(
        _apiSourceMeta,
        apiSource.isAcceptableOrUnknown(data['api_source']!, _apiSourceMeta),
      );
    }
    if (data.containsKey('api_program_key')) {
      context.handle(
        _apiProgramKeyMeta,
        apiProgramKey.isAcceptableOrUnknown(
          data['api_program_key']!,
          _apiProgramKeyMeta,
        ),
      );
    }
    if (data.containsKey('is_calendar_program')) {
      context.handle(
        _isCalendarProgramMeta,
        isCalendarProgram.isAcceptableOrUnknown(
          data['is_calendar_program']!,
          _isCalendarProgramMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningProgram map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningProgram(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      curriculumType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_type'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      stagesConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stages_config'],
      )!,
      hasTests: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_tests'],
      )!,
      testConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}test_config'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      apiSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_source'],
      ),
      apiProgramKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_program_key'],
      ),
      isCalendarProgram: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_calendar_program'],
      )!,
    );
  }

  @override
  $LearningProgramsTable createAlias(String alias) {
    return $LearningProgramsTable(attachedDatabase, alias);
  }
}

class LearningProgram extends DataClass implements Insertable<LearningProgram> {
  final int id;
  final String name;
  final String displayName;
  final String description;
  final String curriculumType;
  final bool isActive;
  final String stagesConfig;
  final bool hasTests;
  final String testConfig;
  final DateTime createdAt;

  /// API source for calendar programs: 'sefaria', 'hebcal', or null (custom)
  final String? apiSource;

  /// Key identifying this program in the API response
  final String? apiProgramKey;

  /// Whether this is a calendar-linked program (vs custom/local)
  final bool isCalendarProgram;
  const LearningProgram({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.curriculumType,
    required this.isActive,
    required this.stagesConfig,
    required this.hasTests,
    required this.testConfig,
    required this.createdAt,
    this.apiSource,
    this.apiProgramKey,
    required this.isCalendarProgram,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['display_name'] = Variable<String>(displayName);
    map['description'] = Variable<String>(description);
    map['curriculum_type'] = Variable<String>(curriculumType);
    map['is_active'] = Variable<bool>(isActive);
    map['stages_config'] = Variable<String>(stagesConfig);
    map['has_tests'] = Variable<bool>(hasTests);
    map['test_config'] = Variable<String>(testConfig);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || apiSource != null) {
      map['api_source'] = Variable<String>(apiSource);
    }
    if (!nullToAbsent || apiProgramKey != null) {
      map['api_program_key'] = Variable<String>(apiProgramKey);
    }
    map['is_calendar_program'] = Variable<bool>(isCalendarProgram);
    return map;
  }

  LearningProgramsCompanion toCompanion(bool nullToAbsent) {
    return LearningProgramsCompanion(
      id: Value(id),
      name: Value(name),
      displayName: Value(displayName),
      description: Value(description),
      curriculumType: Value(curriculumType),
      isActive: Value(isActive),
      stagesConfig: Value(stagesConfig),
      hasTests: Value(hasTests),
      testConfig: Value(testConfig),
      createdAt: Value(createdAt),
      apiSource: apiSource == null && nullToAbsent
          ? const Value.absent()
          : Value(apiSource),
      apiProgramKey: apiProgramKey == null && nullToAbsent
          ? const Value.absent()
          : Value(apiProgramKey),
      isCalendarProgram: Value(isCalendarProgram),
    );
  }

  factory LearningProgram.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningProgram(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String>(json['displayName']),
      description: serializer.fromJson<String>(json['description']),
      curriculumType: serializer.fromJson<String>(json['curriculumType']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      stagesConfig: serializer.fromJson<String>(json['stagesConfig']),
      hasTests: serializer.fromJson<bool>(json['hasTests']),
      testConfig: serializer.fromJson<String>(json['testConfig']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      apiSource: serializer.fromJson<String?>(json['apiSource']),
      apiProgramKey: serializer.fromJson<String?>(json['apiProgramKey']),
      isCalendarProgram: serializer.fromJson<bool>(json['isCalendarProgram']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String>(displayName),
      'description': serializer.toJson<String>(description),
      'curriculumType': serializer.toJson<String>(curriculumType),
      'isActive': serializer.toJson<bool>(isActive),
      'stagesConfig': serializer.toJson<String>(stagesConfig),
      'hasTests': serializer.toJson<bool>(hasTests),
      'testConfig': serializer.toJson<String>(testConfig),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'apiSource': serializer.toJson<String?>(apiSource),
      'apiProgramKey': serializer.toJson<String?>(apiProgramKey),
      'isCalendarProgram': serializer.toJson<bool>(isCalendarProgram),
    };
  }

  LearningProgram copyWith({
    int? id,
    String? name,
    String? displayName,
    String? description,
    String? curriculumType,
    bool? isActive,
    String? stagesConfig,
    bool? hasTests,
    String? testConfig,
    DateTime? createdAt,
    Value<String?> apiSource = const Value.absent(),
    Value<String?> apiProgramKey = const Value.absent(),
    bool? isCalendarProgram,
  }) => LearningProgram(
    id: id ?? this.id,
    name: name ?? this.name,
    displayName: displayName ?? this.displayName,
    description: description ?? this.description,
    curriculumType: curriculumType ?? this.curriculumType,
    isActive: isActive ?? this.isActive,
    stagesConfig: stagesConfig ?? this.stagesConfig,
    hasTests: hasTests ?? this.hasTests,
    testConfig: testConfig ?? this.testConfig,
    createdAt: createdAt ?? this.createdAt,
    apiSource: apiSource.present ? apiSource.value : this.apiSource,
    apiProgramKey: apiProgramKey.present
        ? apiProgramKey.value
        : this.apiProgramKey,
    isCalendarProgram: isCalendarProgram ?? this.isCalendarProgram,
  );
  LearningProgram copyWithCompanion(LearningProgramsCompanion data) {
    return LearningProgram(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      description: data.description.present
          ? data.description.value
          : this.description,
      curriculumType: data.curriculumType.present
          ? data.curriculumType.value
          : this.curriculumType,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      stagesConfig: data.stagesConfig.present
          ? data.stagesConfig.value
          : this.stagesConfig,
      hasTests: data.hasTests.present ? data.hasTests.value : this.hasTests,
      testConfig: data.testConfig.present
          ? data.testConfig.value
          : this.testConfig,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      apiSource: data.apiSource.present ? data.apiSource.value : this.apiSource,
      apiProgramKey: data.apiProgramKey.present
          ? data.apiProgramKey.value
          : this.apiProgramKey,
      isCalendarProgram: data.isCalendarProgram.present
          ? data.isCalendarProgram.value
          : this.isCalendarProgram,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningProgram(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('description: $description, ')
          ..write('curriculumType: $curriculumType, ')
          ..write('isActive: $isActive, ')
          ..write('stagesConfig: $stagesConfig, ')
          ..write('hasTests: $hasTests, ')
          ..write('testConfig: $testConfig, ')
          ..write('createdAt: $createdAt, ')
          ..write('apiSource: $apiSource, ')
          ..write('apiProgramKey: $apiProgramKey, ')
          ..write('isCalendarProgram: $isCalendarProgram')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    displayName,
    description,
    curriculumType,
    isActive,
    stagesConfig,
    hasTests,
    testConfig,
    createdAt,
    apiSource,
    apiProgramKey,
    isCalendarProgram,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningProgram &&
          other.id == this.id &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.description == this.description &&
          other.curriculumType == this.curriculumType &&
          other.isActive == this.isActive &&
          other.stagesConfig == this.stagesConfig &&
          other.hasTests == this.hasTests &&
          other.testConfig == this.testConfig &&
          other.createdAt == this.createdAt &&
          other.apiSource == this.apiSource &&
          other.apiProgramKey == this.apiProgramKey &&
          other.isCalendarProgram == this.isCalendarProgram);
}

class LearningProgramsCompanion extends UpdateCompanion<LearningProgram> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> displayName;
  final Value<String> description;
  final Value<String> curriculumType;
  final Value<bool> isActive;
  final Value<String> stagesConfig;
  final Value<bool> hasTests;
  final Value<String> testConfig;
  final Value<DateTime> createdAt;
  final Value<String?> apiSource;
  final Value<String?> apiProgramKey;
  final Value<bool> isCalendarProgram;
  const LearningProgramsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.description = const Value.absent(),
    this.curriculumType = const Value.absent(),
    this.isActive = const Value.absent(),
    this.stagesConfig = const Value.absent(),
    this.hasTests = const Value.absent(),
    this.testConfig = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.apiSource = const Value.absent(),
    this.apiProgramKey = const Value.absent(),
    this.isCalendarProgram = const Value.absent(),
  });
  LearningProgramsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String displayName,
    this.description = const Value.absent(),
    required String curriculumType,
    this.isActive = const Value.absent(),
    required String stagesConfig,
    this.hasTests = const Value.absent(),
    this.testConfig = const Value.absent(),
    required DateTime createdAt,
    this.apiSource = const Value.absent(),
    this.apiProgramKey = const Value.absent(),
    this.isCalendarProgram = const Value.absent(),
  }) : name = Value(name),
       displayName = Value(displayName),
       curriculumType = Value(curriculumType),
       stagesConfig = Value(stagesConfig),
       createdAt = Value(createdAt);
  static Insertable<LearningProgram> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? description,
    Expression<String>? curriculumType,
    Expression<bool>? isActive,
    Expression<String>? stagesConfig,
    Expression<bool>? hasTests,
    Expression<String>? testConfig,
    Expression<DateTime>? createdAt,
    Expression<String>? apiSource,
    Expression<String>? apiProgramKey,
    Expression<bool>? isCalendarProgram,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (description != null) 'description': description,
      if (curriculumType != null) 'curriculum_type': curriculumType,
      if (isActive != null) 'is_active': isActive,
      if (stagesConfig != null) 'stages_config': stagesConfig,
      if (hasTests != null) 'has_tests': hasTests,
      if (testConfig != null) 'test_config': testConfig,
      if (createdAt != null) 'created_at': createdAt,
      if (apiSource != null) 'api_source': apiSource,
      if (apiProgramKey != null) 'api_program_key': apiProgramKey,
      if (isCalendarProgram != null) 'is_calendar_program': isCalendarProgram,
    });
  }

  LearningProgramsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? displayName,
    Value<String>? description,
    Value<String>? curriculumType,
    Value<bool>? isActive,
    Value<String>? stagesConfig,
    Value<bool>? hasTests,
    Value<String>? testConfig,
    Value<DateTime>? createdAt,
    Value<String?>? apiSource,
    Value<String?>? apiProgramKey,
    Value<bool>? isCalendarProgram,
  }) {
    return LearningProgramsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      curriculumType: curriculumType ?? this.curriculumType,
      isActive: isActive ?? this.isActive,
      stagesConfig: stagesConfig ?? this.stagesConfig,
      hasTests: hasTests ?? this.hasTests,
      testConfig: testConfig ?? this.testConfig,
      createdAt: createdAt ?? this.createdAt,
      apiSource: apiSource ?? this.apiSource,
      apiProgramKey: apiProgramKey ?? this.apiProgramKey,
      isCalendarProgram: isCalendarProgram ?? this.isCalendarProgram,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (curriculumType.present) {
      map['curriculum_type'] = Variable<String>(curriculumType.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (stagesConfig.present) {
      map['stages_config'] = Variable<String>(stagesConfig.value);
    }
    if (hasTests.present) {
      map['has_tests'] = Variable<bool>(hasTests.value);
    }
    if (testConfig.present) {
      map['test_config'] = Variable<String>(testConfig.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (apiSource.present) {
      map['api_source'] = Variable<String>(apiSource.value);
    }
    if (apiProgramKey.present) {
      map['api_program_key'] = Variable<String>(apiProgramKey.value);
    }
    if (isCalendarProgram.present) {
      map['is_calendar_program'] = Variable<bool>(isCalendarProgram.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningProgramsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('description: $description, ')
          ..write('curriculumType: $curriculumType, ')
          ..write('isActive: $isActive, ')
          ..write('stagesConfig: $stagesConfig, ')
          ..write('hasTests: $hasTests, ')
          ..write('testConfig: $testConfig, ')
          ..write('createdAt: $createdAt, ')
          ..write('apiSource: $apiSource, ')
          ..write('apiProgramKey: $apiProgramKey, ')
          ..write('isCalendarProgram: $isCalendarProgram')
          ..write(')'))
        .toString();
  }
}

class $ProfileProgramsTable extends ProfilePrograms
    with TableInfo<$ProfileProgramsTable, ProfileProgram> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileProgramsTable(this.attachedDatabase, [this._alias]);
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _curriculumTypeMeta = const VerificationMeta(
    'curriculumType',
  );
  @override
  late final GeneratedColumn<String> curriculumType = GeneratedColumn<String>(
    'curriculum_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<int> programId = GeneratedColumn<int>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackingStartDateMeta = const VerificationMeta(
    'trackingStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> trackingStartDate =
      GeneratedColumn<DateTime>(
        'tracking_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _trackingStartRefMeta = const VerificationMeta(
    'trackingStartRef',
  );
  @override
  late final GeneratedColumn<String> trackingStartRef = GeneratedColumn<String>(
    'tracking_start_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumType,
    programId,
    trackingStartDate,
    trackingStartRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileProgram> instance, {
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('curriculum_type')) {
      context.handle(
        _curriculumTypeMeta,
        curriculumType.isAcceptableOrUnknown(
          data['curriculum_type']!,
          _curriculumTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_curriculumTypeMeta);
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('tracking_start_date')) {
      context.handle(
        _trackingStartDateMeta,
        trackingStartDate.isAcceptableOrUnknown(
          data['tracking_start_date']!,
          _trackingStartDateMeta,
        ),
      );
    }
    if (data.containsKey('tracking_start_ref')) {
      context.handle(
        _trackingStartRefMeta,
        trackingStartRef.isAcceptableOrUnknown(
          data['tracking_start_ref']!,
          _trackingStartRefMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumType},
  ];
  @override
  ProfileProgram map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileProgram(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_type'],
      )!,
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_id'],
      )!,
      trackingStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tracking_start_date'],
      ),
      trackingStartRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tracking_start_ref'],
      ),
    );
  }

  @override
  $ProfileProgramsTable createAlias(String alias) {
    return $ProfileProgramsTable(attachedDatabase, alias);
  }
}

class ProfileProgram extends DataClass implements Insertable<ProfileProgram> {
  final int id;
  final int profileId;
  final String curriculumType;
  final int programId;

  /// Start date for tracking window (Path A onboarding)
  final DateTime? trackingStartDate;

  /// Sefaria ref of first item in tracking window
  final String? trackingStartRef;
  const ProfileProgram({
    required this.id,
    required this.profileId,
    required this.curriculumType,
    required this.programId,
    this.trackingStartDate,
    this.trackingStartRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_type'] = Variable<String>(curriculumType);
    map['program_id'] = Variable<int>(programId);
    if (!nullToAbsent || trackingStartDate != null) {
      map['tracking_start_date'] = Variable<DateTime>(trackingStartDate);
    }
    if (!nullToAbsent || trackingStartRef != null) {
      map['tracking_start_ref'] = Variable<String>(trackingStartRef);
    }
    return map;
  }

  ProfileProgramsCompanion toCompanion(bool nullToAbsent) {
    return ProfileProgramsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumType: Value(curriculumType),
      programId: Value(programId),
      trackingStartDate: trackingStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(trackingStartDate),
      trackingStartRef: trackingStartRef == null && nullToAbsent
          ? const Value.absent()
          : Value(trackingStartRef),
    );
  }

  factory ProfileProgram.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileProgram(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumType: serializer.fromJson<String>(json['curriculumType']),
      programId: serializer.fromJson<int>(json['programId']),
      trackingStartDate: serializer.fromJson<DateTime?>(
        json['trackingStartDate'],
      ),
      trackingStartRef: serializer.fromJson<String?>(json['trackingStartRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumType': serializer.toJson<String>(curriculumType),
      'programId': serializer.toJson<int>(programId),
      'trackingStartDate': serializer.toJson<DateTime?>(trackingStartDate),
      'trackingStartRef': serializer.toJson<String?>(trackingStartRef),
    };
  }

  ProfileProgram copyWith({
    int? id,
    int? profileId,
    String? curriculumType,
    int? programId,
    Value<DateTime?> trackingStartDate = const Value.absent(),
    Value<String?> trackingStartRef = const Value.absent(),
  }) => ProfileProgram(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumType: curriculumType ?? this.curriculumType,
    programId: programId ?? this.programId,
    trackingStartDate: trackingStartDate.present
        ? trackingStartDate.value
        : this.trackingStartDate,
    trackingStartRef: trackingStartRef.present
        ? trackingStartRef.value
        : this.trackingStartRef,
  );
  ProfileProgram copyWithCompanion(ProfileProgramsCompanion data) {
    return ProfileProgram(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumType: data.curriculumType.present
          ? data.curriculumType.value
          : this.curriculumType,
      programId: data.programId.present ? data.programId.value : this.programId,
      trackingStartDate: data.trackingStartDate.present
          ? data.trackingStartDate.value
          : this.trackingStartDate,
      trackingStartRef: data.trackingStartRef.present
          ? data.trackingStartRef.value
          : this.trackingStartRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileProgram(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumType: $curriculumType, ')
          ..write('programId: $programId, ')
          ..write('trackingStartDate: $trackingStartDate, ')
          ..write('trackingStartRef: $trackingStartRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumType,
    programId,
    trackingStartDate,
    trackingStartRef,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileProgram &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumType == this.curriculumType &&
          other.programId == this.programId &&
          other.trackingStartDate == this.trackingStartDate &&
          other.trackingStartRef == this.trackingStartRef);
}

class ProfileProgramsCompanion extends UpdateCompanion<ProfileProgram> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumType;
  final Value<int> programId;
  final Value<DateTime?> trackingStartDate;
  final Value<String?> trackingStartRef;
  const ProfileProgramsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumType = const Value.absent(),
    this.programId = const Value.absent(),
    this.trackingStartDate = const Value.absent(),
    this.trackingStartRef = const Value.absent(),
  });
  ProfileProgramsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumType,
    required int programId,
    this.trackingStartDate = const Value.absent(),
    this.trackingStartRef = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumType = Value(curriculumType),
       programId = Value(programId);
  static Insertable<ProfileProgram> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumType,
    Expression<int>? programId,
    Expression<DateTime>? trackingStartDate,
    Expression<String>? trackingStartRef,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumType != null) 'curriculum_type': curriculumType,
      if (programId != null) 'program_id': programId,
      if (trackingStartDate != null) 'tracking_start_date': trackingStartDate,
      if (trackingStartRef != null) 'tracking_start_ref': trackingStartRef,
    });
  }

  ProfileProgramsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumType,
    Value<int>? programId,
    Value<DateTime?>? trackingStartDate,
    Value<String?>? trackingStartRef,
  }) {
    return ProfileProgramsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumType: curriculumType ?? this.curriculumType,
      programId: programId ?? this.programId,
      trackingStartDate: trackingStartDate ?? this.trackingStartDate,
      trackingStartRef: trackingStartRef ?? this.trackingStartRef,
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
    if (curriculumType.present) {
      map['curriculum_type'] = Variable<String>(curriculumType.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<int>(programId.value);
    }
    if (trackingStartDate.present) {
      map['tracking_start_date'] = Variable<DateTime>(trackingStartDate.value);
    }
    if (trackingStartRef.present) {
      map['tracking_start_ref'] = Variable<String>(trackingStartRef.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileProgramsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumType: $curriculumType, ')
          ..write('programId: $programId, ')
          ..write('trackingStartDate: $trackingStartDate, ')
          ..write('trackingStartRef: $trackingStartRef')
          ..write(')'))
        .toString();
  }
}

class $TestDatesTable extends TestDates
    with TableInfo<$TestDatesTable, TestDate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestDatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<int> programId = GeneratedColumn<int>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testDateMeta = const VerificationMeta(
    'testDate',
  );
  @override
  late final GeneratedColumn<DateTime> testDate = GeneratedColumn<DateTime>(
    'test_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _materialDescriptionMeta =
      const VerificationMeta('materialDescription');
  @override
  late final GeneratedColumn<String> materialDescription =
      GeneratedColumn<String>(
        'material_description',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    programId,
    testDate,
    materialDescription,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_dates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TestDate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('test_date')) {
      context.handle(
        _testDateMeta,
        testDate.isAcceptableOrUnknown(data['test_date']!, _testDateMeta),
      );
    } else if (isInserting) {
      context.missing(_testDateMeta);
    }
    if (data.containsKey('material_description')) {
      context.handle(
        _materialDescriptionMeta,
        materialDescription.isAcceptableOrUnknown(
          data['material_description']!,
          _materialDescriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestDate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestDate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_id'],
      )!,
      testDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}test_date'],
      )!,
      materialDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}material_description'],
      )!,
    );
  }

  @override
  $TestDatesTable createAlias(String alias) {
    return $TestDatesTable(attachedDatabase, alias);
  }
}

class TestDate extends DataClass implements Insertable<TestDate> {
  final int id;
  final int programId;
  final DateTime testDate;
  final String materialDescription;
  const TestDate({
    required this.id,
    required this.programId,
    required this.testDate,
    required this.materialDescription,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['program_id'] = Variable<int>(programId);
    map['test_date'] = Variable<DateTime>(testDate);
    map['material_description'] = Variable<String>(materialDescription);
    return map;
  }

  TestDatesCompanion toCompanion(bool nullToAbsent) {
    return TestDatesCompanion(
      id: Value(id),
      programId: Value(programId),
      testDate: Value(testDate),
      materialDescription: Value(materialDescription),
    );
  }

  factory TestDate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestDate(
      id: serializer.fromJson<int>(json['id']),
      programId: serializer.fromJson<int>(json['programId']),
      testDate: serializer.fromJson<DateTime>(json['testDate']),
      materialDescription: serializer.fromJson<String>(
        json['materialDescription'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'programId': serializer.toJson<int>(programId),
      'testDate': serializer.toJson<DateTime>(testDate),
      'materialDescription': serializer.toJson<String>(materialDescription),
    };
  }

  TestDate copyWith({
    int? id,
    int? programId,
    DateTime? testDate,
    String? materialDescription,
  }) => TestDate(
    id: id ?? this.id,
    programId: programId ?? this.programId,
    testDate: testDate ?? this.testDate,
    materialDescription: materialDescription ?? this.materialDescription,
  );
  TestDate copyWithCompanion(TestDatesCompanion data) {
    return TestDate(
      id: data.id.present ? data.id.value : this.id,
      programId: data.programId.present ? data.programId.value : this.programId,
      testDate: data.testDate.present ? data.testDate.value : this.testDate,
      materialDescription: data.materialDescription.present
          ? data.materialDescription.value
          : this.materialDescription,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestDate(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('testDate: $testDate, ')
          ..write('materialDescription: $materialDescription')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, programId, testDate, materialDescription);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestDate &&
          other.id == this.id &&
          other.programId == this.programId &&
          other.testDate == this.testDate &&
          other.materialDescription == this.materialDescription);
}

class TestDatesCompanion extends UpdateCompanion<TestDate> {
  final Value<int> id;
  final Value<int> programId;
  final Value<DateTime> testDate;
  final Value<String> materialDescription;
  const TestDatesCompanion({
    this.id = const Value.absent(),
    this.programId = const Value.absent(),
    this.testDate = const Value.absent(),
    this.materialDescription = const Value.absent(),
  });
  TestDatesCompanion.insert({
    this.id = const Value.absent(),
    required int programId,
    required DateTime testDate,
    this.materialDescription = const Value.absent(),
  }) : programId = Value(programId),
       testDate = Value(testDate);
  static Insertable<TestDate> custom({
    Expression<int>? id,
    Expression<int>? programId,
    Expression<DateTime>? testDate,
    Expression<String>? materialDescription,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programId != null) 'program_id': programId,
      if (testDate != null) 'test_date': testDate,
      if (materialDescription != null)
        'material_description': materialDescription,
    });
  }

  TestDatesCompanion copyWith({
    Value<int>? id,
    Value<int>? programId,
    Value<DateTime>? testDate,
    Value<String>? materialDescription,
  }) {
    return TestDatesCompanion(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      testDate: testDate ?? this.testDate,
      materialDescription: materialDescription ?? this.materialDescription,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<int>(programId.value);
    }
    if (testDate.present) {
      map['test_date'] = Variable<DateTime>(testDate.value);
    }
    if (materialDescription.present) {
      map['material_description'] = Variable<String>(materialDescription.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestDatesCompanion(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('testDate: $testDate, ')
          ..write('materialDescription: $materialDescription')
          ..write(')'))
        .toString();
  }
}

class $TestScoresTable extends TestScores
    with TableInfo<$TestScoresTable, TestScore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestScoresTable(this.attachedDatabase, [this._alias]);
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<int> programId = GeneratedColumn<int>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testDateIdMeta = const VerificationMeta(
    'testDateId',
  );
  @override
  late final GeneratedColumn<int> testDateId = GeneratedColumn<int>(
    'test_date_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scorePercentageMeta = const VerificationMeta(
    'scorePercentage',
  );
  @override
  late final GeneratedColumn<int> scorePercentage = GeneratedColumn<int>(
    'score_percentage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    programId,
    testDateId,
    scorePercentage,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_scores';
  @override
  VerificationContext validateIntegrity(
    Insertable<TestScore> instance, {
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('test_date_id')) {
      context.handle(
        _testDateIdMeta,
        testDateId.isAcceptableOrUnknown(
          data['test_date_id']!,
          _testDateIdMeta,
        ),
      );
    }
    if (data.containsKey('score_percentage')) {
      context.handle(
        _scorePercentageMeta,
        scorePercentage.isAcceptableOrUnknown(
          data['score_percentage']!,
          _scorePercentageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scorePercentageMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestScore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestScore(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_id'],
      )!,
      testDateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_date_id'],
      ),
      scorePercentage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score_percentage'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TestScoresTable createAlias(String alias) {
    return $TestScoresTable(attachedDatabase, alias);
  }
}

class TestScore extends DataClass implements Insertable<TestScore> {
  final int id;
  final int profileId;
  final int programId;
  final int? testDateId;
  final int scorePercentage;
  final String notes;
  final DateTime createdAt;
  const TestScore({
    required this.id,
    required this.profileId,
    required this.programId,
    this.testDateId,
    required this.scorePercentage,
    required this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['program_id'] = Variable<int>(programId);
    if (!nullToAbsent || testDateId != null) {
      map['test_date_id'] = Variable<int>(testDateId);
    }
    map['score_percentage'] = Variable<int>(scorePercentage);
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TestScoresCompanion toCompanion(bool nullToAbsent) {
    return TestScoresCompanion(
      id: Value(id),
      profileId: Value(profileId),
      programId: Value(programId),
      testDateId: testDateId == null && nullToAbsent
          ? const Value.absent()
          : Value(testDateId),
      scorePercentage: Value(scorePercentage),
      notes: Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory TestScore.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestScore(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      programId: serializer.fromJson<int>(json['programId']),
      testDateId: serializer.fromJson<int?>(json['testDateId']),
      scorePercentage: serializer.fromJson<int>(json['scorePercentage']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'programId': serializer.toJson<int>(programId),
      'testDateId': serializer.toJson<int?>(testDateId),
      'scorePercentage': serializer.toJson<int>(scorePercentage),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TestScore copyWith({
    int? id,
    int? profileId,
    int? programId,
    Value<int?> testDateId = const Value.absent(),
    int? scorePercentage,
    String? notes,
    DateTime? createdAt,
  }) => TestScore(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    programId: programId ?? this.programId,
    testDateId: testDateId.present ? testDateId.value : this.testDateId,
    scorePercentage: scorePercentage ?? this.scorePercentage,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  TestScore copyWithCompanion(TestScoresCompanion data) {
    return TestScore(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      programId: data.programId.present ? data.programId.value : this.programId,
      testDateId: data.testDateId.present
          ? data.testDateId.value
          : this.testDateId,
      scorePercentage: data.scorePercentage.present
          ? data.scorePercentage.value
          : this.scorePercentage,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestScore(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('programId: $programId, ')
          ..write('testDateId: $testDateId, ')
          ..write('scorePercentage: $scorePercentage, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    programId,
    testDateId,
    scorePercentage,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestScore &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.programId == this.programId &&
          other.testDateId == this.testDateId &&
          other.scorePercentage == this.scorePercentage &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class TestScoresCompanion extends UpdateCompanion<TestScore> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<int> programId;
  final Value<int?> testDateId;
  final Value<int> scorePercentage;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  const TestScoresCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.programId = const Value.absent(),
    this.testDateId = const Value.absent(),
    this.scorePercentage = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TestScoresCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required int programId,
    this.testDateId = const Value.absent(),
    required int scorePercentage,
    this.notes = const Value.absent(),
    required DateTime createdAt,
  }) : profileId = Value(profileId),
       programId = Value(programId),
       scorePercentage = Value(scorePercentage),
       createdAt = Value(createdAt);
  static Insertable<TestScore> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<int>? programId,
    Expression<int>? testDateId,
    Expression<int>? scorePercentage,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (programId != null) 'program_id': programId,
      if (testDateId != null) 'test_date_id': testDateId,
      if (scorePercentage != null) 'score_percentage': scorePercentage,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TestScoresCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<int>? programId,
    Value<int?>? testDateId,
    Value<int>? scorePercentage,
    Value<String>? notes,
    Value<DateTime>? createdAt,
  }) {
    return TestScoresCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      programId: programId ?? this.programId,
      testDateId: testDateId ?? this.testDateId,
      scorePercentage: scorePercentage ?? this.scorePercentage,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
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
    if (programId.present) {
      map['program_id'] = Variable<int>(programId.value);
    }
    if (testDateId.present) {
      map['test_date_id'] = Variable<int>(testDateId.value);
    }
    if (scorePercentage.present) {
      map['score_percentage'] = Variable<int>(scorePercentage.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestScoresCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('programId: $programId, ')
          ..write('testDateId: $testDateId, ')
          ..write('scorePercentage: $scorePercentage, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StudyDayConfigsTable extends StudyDayConfigs
    with TableInfo<$StudyDayConfigsTable, StudyDayConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyDayConfigsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayTypeMeta = const VerificationMeta(
    'dayType',
  );
  @override
  late final GeneratedColumn<String> dayType = GeneratedColumn<String>(
    'day_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('study'),
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
    profileId,
    curriculumId,
    dayOfWeek,
    dayType,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_day_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyDayConfig> instance, {
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
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('day_type')) {
      context.handle(
        _dayTypeMeta,
        dayType.isAcceptableOrUnknown(data['day_type']!, _dayTypeMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {profileId, curriculumId, dayOfWeek};
  @override
  StudyDayConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyDayConfig(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      )!,
      dayType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_type'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StudyDayConfigsTable createAlias(String alias) {
    return $StudyDayConfigsTable(attachedDatabase, alias);
  }
}

class StudyDayConfig extends DataClass implements Insertable<StudyDayConfig> {
  final int profileId;
  final String curriculumId;
  final int dayOfWeek;
  final String dayType;
  final DateTime updatedAt;
  const StudyDayConfig({
    required this.profileId,
    required this.curriculumId,
    required this.dayOfWeek,
    required this.dayType,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['day_type'] = Variable<String>(dayType);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudyDayConfigsCompanion toCompanion(bool nullToAbsent) {
    return StudyDayConfigsCompanion(
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      dayOfWeek: Value(dayOfWeek),
      dayType: Value(dayType),
      updatedAt: Value(updatedAt),
    );
  }

  factory StudyDayConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyDayConfig(
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      dayOfWeek: serializer.fromJson<int>(json['dayOfWeek']),
      dayType: serializer.fromJson<String>(json['dayType']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'dayType': serializer.toJson<String>(dayType),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StudyDayConfig copyWith({
    int? profileId,
    String? curriculumId,
    int? dayOfWeek,
    String? dayType,
    DateTime? updatedAt,
  }) => StudyDayConfig(
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    dayType: dayType ?? this.dayType,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StudyDayConfig copyWithCompanion(StudyDayConfigsCompanion data) {
    return StudyDayConfig(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      dayType: data.dayType.present ? data.dayType.value : this.dayType,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyDayConfig(')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('dayType: $dayType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profileId, curriculumId, dayOfWeek, dayType, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyDayConfig &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.dayType == this.dayType &&
          other.updatedAt == this.updatedAt);
}

class StudyDayConfigsCompanion extends UpdateCompanion<StudyDayConfig> {
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> dayOfWeek;
  final Value<String> dayType;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudyDayConfigsCompanion({
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.dayType = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyDayConfigsCompanion.insert({
    this.profileId = const Value.absent(),
    required String curriculumId,
    required int dayOfWeek,
    this.dayType = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       dayOfWeek = Value(dayOfWeek),
       updatedAt = Value(updatedAt);
  static Insertable<StudyDayConfig> custom({
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? dayOfWeek,
    Expression<String>? dayType,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (dayType != null) 'day_type': dayType,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyDayConfigsCompanion copyWith({
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? dayOfWeek,
    Value<String>? dayType,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StudyDayConfigsCompanion(
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayType: dayType ?? this.dayType,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (dayType.present) {
      map['day_type'] = Variable<String>(dayType.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyDayConfigsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('dayType: $dayType, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarCacheTable extends CalendarCache
    with TableInfo<$CalendarCacheTable, CalendarCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarCacheTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseJsonMeta = const VerificationMeta(
    'responseJson',
  );
  @override
  late final GeneratedColumn<String> responseJson = GeneratedColumn<String>(
    'response_json',
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
    id,
    source,
    dateKey,
    responseJson,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('response_json')) {
      context.handle(
        _responseJsonMeta,
        responseJson.isAcceptableOrUnknown(
          data['response_json']!,
          _responseJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, dateKey},
  ];
  @override
  CalendarCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      responseJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CalendarCacheTable createAlias(String alias) {
    return $CalendarCacheTable(attachedDatabase, alias);
  }
}

class CalendarCacheData extends DataClass
    implements Insertable<CalendarCacheData> {
  final int id;

  /// API source: 'sefaria' or 'hebcal'
  final String source;

  /// Date key in 'YYYY-MM-DD' format
  final String dateKey;

  /// Full JSON response body
  final String responseJson;

  /// When the response was cached
  final DateTime fetchedAt;
  const CalendarCacheData({
    required this.id,
    required this.source,
    required this.dateKey,
    required this.responseJson,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['date_key'] = Variable<String>(dateKey);
    map['response_json'] = Variable<String>(responseJson);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CalendarCacheCompanion toCompanion(bool nullToAbsent) {
    return CalendarCacheCompanion(
      id: Value(id),
      source: Value(source),
      dateKey: Value(dateKey),
      responseJson: Value(responseJson),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CalendarCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarCacheData(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      responseJson: serializer.fromJson<String>(json['responseJson']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'dateKey': serializer.toJson<String>(dateKey),
      'responseJson': serializer.toJson<String>(responseJson),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CalendarCacheData copyWith({
    int? id,
    String? source,
    String? dateKey,
    String? responseJson,
    DateTime? fetchedAt,
  }) => CalendarCacheData(
    id: id ?? this.id,
    source: source ?? this.source,
    dateKey: dateKey ?? this.dateKey,
    responseJson: responseJson ?? this.responseJson,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CalendarCacheData copyWithCompanion(CalendarCacheCompanion data) {
    return CalendarCacheData(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      responseJson: data.responseJson.present
          ? data.responseJson.value
          : this.responseJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCacheData(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('dateKey: $dateKey, ')
          ..write('responseJson: $responseJson, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, source, dateKey, responseJson, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarCacheData &&
          other.id == this.id &&
          other.source == this.source &&
          other.dateKey == this.dateKey &&
          other.responseJson == this.responseJson &&
          other.fetchedAt == this.fetchedAt);
}

class CalendarCacheCompanion extends UpdateCompanion<CalendarCacheData> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> dateKey;
  final Value<String> responseJson;
  final Value<DateTime> fetchedAt;
  const CalendarCacheCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.responseJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  CalendarCacheCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String dateKey,
    required String responseJson,
    required DateTime fetchedAt,
  }) : source = Value(source),
       dateKey = Value(dateKey),
       responseJson = Value(responseJson),
       fetchedAt = Value(fetchedAt);
  static Insertable<CalendarCacheData> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? dateKey,
    Expression<String>? responseJson,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (dateKey != null) 'date_key': dateKey,
      if (responseJson != null) 'response_json': responseJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  CalendarCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? dateKey,
    Value<String>? responseJson,
    Value<DateTime>? fetchedAt,
  }) {
    return CalendarCacheCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      dateKey: dateKey ?? this.dateKey,
      responseJson: responseJson ?? this.responseJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (responseJson.present) {
      map['response_json'] = Variable<String>(responseJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCacheCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('dateKey: $dateKey, ')
          ..write('responseJson: $responseJson, ')
          ..write('fetchedAt: $fetchedAt')
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
  late final $CurriculumScopesTable curriculumScopes = $CurriculumScopesTable(
    this,
  );
  late final $CurriculumTracksTable curriculumTracks = $CurriculumTracksTable(
    this,
  );
  late final $StageDefinitionsTable stageDefinitions = $StageDefinitionsTable(
    this,
  );
  late final $CompletionsTable completions = $CompletionsTable(this);
  late final $LearningLedgerTable learningLedger = $LearningLedgerTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $LearningOrderTable learningOrder = $LearningOrderTable(this);
  late final $PointConfigsTable pointConfigs = $PointConfigsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $RewardsTable rewards = $RewardsTable(this);
  late final $RewardPoolsTable rewardPools = $RewardPoolsTable(this);
  late final $RewardPoolItemsTable rewardPoolItems = $RewardPoolItemsTable(
    this,
  );
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $TextCacheTable textCache = $TextCacheTable(this);
  late final $StreaksTable streaks = $StreaksTable(this);
  late final $TextDownloadStatusesTable textDownloadStatuses =
      $TextDownloadStatusesTable(this);
  late final $ContentDownloadStatusesTable contentDownloadStatuses =
      $ContentDownloadStatusesTable(this);
  late final $LearningProgramsTable learningPrograms = $LearningProgramsTable(
    this,
  );
  late final $ProfileProgramsTable profilePrograms = $ProfileProgramsTable(
    this,
  );
  late final $TestDatesTable testDates = $TestDatesTable(this);
  late final $TestScoresTable testScores = $TestScoresTable(this);
  late final $StudyDayConfigsTable studyDayConfigs = $StudyDayConfigsTable(
    this,
  );
  late final $CalendarCacheTable calendarCache = $CalendarCacheTable(this);
  late final ActiveCurriculumDao activeCurriculumDao = ActiveCurriculumDao(
    this as AppDatabase,
  );
  late final CurriculumScopeDao curriculumScopeDao = CurriculumScopeDao(
    this as AppDatabase,
  );
  late final CompletionDao completionDao = CompletionDao(this as AppDatabase);
  late final LearningLedgerDao learningLedgerDao = LearningLedgerDao(
    this as AppDatabase,
  );
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
  late final RewardPoolDao rewardPoolDao = RewardPoolDao(this as AppDatabase);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final TextCacheDao textCacheDao = TextCacheDao(this as AppDatabase);
  late final TextDownloadStatusDao textDownloadStatusDao =
      TextDownloadStatusDao(this as AppDatabase);
  late final ContentDownloadStatusDao contentDownloadStatusDao =
      ContentDownloadStatusDao(this as AppDatabase);
  late final LearningProgramDao learningProgramDao = LearningProgramDao(
    this as AppDatabase,
  );
  late final ProfileProgramDao profileProgramDao = ProfileProgramDao(
    this as AppDatabase,
  );
  late final TestDateDao testDateDao = TestDateDao(this as AppDatabase);
  late final TestScoreDao testScoreDao = TestScoreDao(this as AppDatabase);
  late final StudyDayConfigDao studyDayConfigDao = StudyDayConfigDao(
    this as AppDatabase,
  );
  late final CalendarCacheDao calendarCacheDao = CalendarCacheDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activeCurricula,
    curriculumScopes,
    curriculumTracks,
    stageDefinitions,
    completions,
    learningLedger,
    bookmarks,
    goals,
    learningOrder,
    pointConfigs,
    profiles,
    userProfiles,
    rewards,
    rewardPools,
    rewardPoolItems,
    syncQueue,
    textCache,
    streaks,
    textDownloadStatuses,
    contentDownloadStatuses,
    learningPrograms,
    profilePrograms,
    testDates,
    testScores,
    studyDayConfigs,
    calendarCache,
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
typedef $$CurriculumScopesTableCreateCompanionBuilder =
    CurriculumScopesCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required int scopeLevel,
      required String scopeValue,
      required DateTime createdAt,
    });
typedef $$CurriculumScopesTableUpdateCompanionBuilder =
    CurriculumScopesCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> scopeLevel,
      Value<String> scopeValue,
      Value<DateTime> createdAt,
    });

class $$CurriculumScopesTableFilterComposer
    extends Composer<_$AppDatabase, $CurriculumScopesTable> {
  $$CurriculumScopesTableFilterComposer({
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

  ColumnFilters<int> get scopeLevel => $composableBuilder(
    column: $table.scopeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeValue => $composableBuilder(
    column: $table.scopeValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurriculumScopesTableOrderingComposer
    extends Composer<_$AppDatabase, $CurriculumScopesTable> {
  $$CurriculumScopesTableOrderingComposer({
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

  ColumnOrderings<int> get scopeLevel => $composableBuilder(
    column: $table.scopeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeValue => $composableBuilder(
    column: $table.scopeValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurriculumScopesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurriculumScopesTable> {
  $$CurriculumScopesTableAnnotationComposer({
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

  GeneratedColumn<int> get scopeLevel => $composableBuilder(
    column: $table.scopeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scopeValue => $composableBuilder(
    column: $table.scopeValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CurriculumScopesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurriculumScopesTable,
          CurriculumScope,
          $$CurriculumScopesTableFilterComposer,
          $$CurriculumScopesTableOrderingComposer,
          $$CurriculumScopesTableAnnotationComposer,
          $$CurriculumScopesTableCreateCompanionBuilder,
          $$CurriculumScopesTableUpdateCompanionBuilder,
          (
            CurriculumScope,
            BaseReferences<
              _$AppDatabase,
              $CurriculumScopesTable,
              CurriculumScope
            >,
          ),
          CurriculumScope,
          PrefetchHooks Function()
        > {
  $$CurriculumScopesTableTableManager(
    _$AppDatabase db,
    $CurriculumScopesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurriculumScopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurriculumScopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurriculumScopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<int> scopeLevel = const Value.absent(),
                Value<String> scopeValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CurriculumScopesCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                scopeLevel: scopeLevel,
                scopeValue: scopeValue,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required int scopeLevel,
                required String scopeValue,
                required DateTime createdAt,
              }) => CurriculumScopesCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                scopeLevel: scopeLevel,
                scopeValue: scopeValue,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurriculumScopesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurriculumScopesTable,
      CurriculumScope,
      $$CurriculumScopesTableFilterComposer,
      $$CurriculumScopesTableOrderingComposer,
      $$CurriculumScopesTableAnnotationComposer,
      $$CurriculumScopesTableCreateCompanionBuilder,
      $$CurriculumScopesTableUpdateCompanionBuilder,
      (
        CurriculumScope,
        BaseReferences<_$AppDatabase, $CurriculumScopesTable, CurriculumScope>,
      ),
      CurriculumScope,
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
      Value<DateTime?> archivedAt,
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
      Value<DateTime?> archivedAt,
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

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
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
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurriculumTracksCompanion(
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                isActive: isActive,
                activatedAt: activatedAt,
                deactivatedAt: deactivatedAt,
                archivedAt: archivedAt,
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
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                isActive: isActive,
                activatedAt: activatedAt,
                deactivatedAt: deactivatedAt,
                archivedAt: archivedAt,
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
      Value<String> scheduleType,
      Value<String?> daysOfWeek,
      Value<int?> rollingWindowSize,
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
      Value<String> scheduleType,
      Value<String?> daysOfWeek,
      Value<int?> rollingWindowSize,
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

  ColumnFilters<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rollingWindowSize => $composableBuilder(
    column: $table.rollingWindowSize,
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

  ColumnOrderings<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rollingWindowSize => $composableBuilder(
    column: $table.rollingWindowSize,
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

  GeneratedColumn<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rollingWindowSize => $composableBuilder(
    column: $table.rollingWindowSize,
    builder: (column) => column,
  );
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
                Value<String> scheduleType = const Value.absent(),
                Value<String?> daysOfWeek = const Value.absent(),
                Value<int?> rollingWindowSize = const Value.absent(),
              }) => StageDefinitionsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                stageName: stageName,
                delayDays: delayDays,
                isDefault: isDefault,
                scheduleType: scheduleType,
                daysOfWeek: daysOfWeek,
                rollingWindowSize: rollingWindowSize,
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
                Value<String> scheduleType = const Value.absent(),
                Value<String?> daysOfWeek = const Value.absent(),
                Value<int?> rollingWindowSize = const Value.absent(),
              }) => StageDefinitionsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                stageName: stageName,
                delayDays: delayDays,
                isDefault: isDefault,
                scheduleType: scheduleType,
                daysOfWeek: daysOfWeek,
                rollingWindowSize: rollingWindowSize,
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
typedef $$LearningLedgerTableCreateCompanionBuilder =
    LearningLedgerCompanion Function({
      Value<int> id,
      Value<int> profileId,
      required String curriculumId,
      required String unitType,
      required String unitIdentifier,
      required String unitDisplayNameHe,
      required String unitDisplayNameEn,
      required String trackType,
      Value<int?> trackId,
      required DateTime completedAt,
      required int completionNumber,
      required int markedBy,
      Value<bool> isManual,
      Value<DateTime> createdAt,
    });
typedef $$LearningLedgerTableUpdateCompanionBuilder =
    LearningLedgerCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> unitType,
      Value<String> unitIdentifier,
      Value<String> unitDisplayNameHe,
      Value<String> unitDisplayNameEn,
      Value<String> trackType,
      Value<int?> trackId,
      Value<DateTime> completedAt,
      Value<int> completionNumber,
      Value<int> markedBy,
      Value<bool> isManual,
      Value<DateTime> createdAt,
    });

class $$LearningLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $LearningLedgerTable> {
  $$LearningLedgerTableFilterComposer({
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

  ColumnFilters<String> get unitType => $composableBuilder(
    column: $table.unitType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitIdentifier => $composableBuilder(
    column: $table.unitIdentifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitDisplayNameHe => $composableBuilder(
    column: $table.unitDisplayNameHe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitDisplayNameEn => $composableBuilder(
    column: $table.unitDisplayNameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionNumber => $composableBuilder(
    column: $table.completionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get markedBy => $composableBuilder(
    column: $table.markedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningLedgerTable> {
  $$LearningLedgerTableOrderingComposer({
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

  ColumnOrderings<String> get unitType => $composableBuilder(
    column: $table.unitType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitIdentifier => $composableBuilder(
    column: $table.unitIdentifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitDisplayNameHe => $composableBuilder(
    column: $table.unitDisplayNameHe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitDisplayNameEn => $composableBuilder(
    column: $table.unitDisplayNameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionNumber => $composableBuilder(
    column: $table.completionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get markedBy => $composableBuilder(
    column: $table.markedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningLedgerTable> {
  $$LearningLedgerTableAnnotationComposer({
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

  GeneratedColumn<String> get unitType =>
      $composableBuilder(column: $table.unitType, builder: (column) => column);

  GeneratedColumn<String> get unitIdentifier => $composableBuilder(
    column: $table.unitIdentifier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitDisplayNameHe => $composableBuilder(
    column: $table.unitDisplayNameHe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitDisplayNameEn => $composableBuilder(
    column: $table.unitDisplayNameEn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackType =>
      $composableBuilder(column: $table.trackType, builder: (column) => column);

  GeneratedColumn<int> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionNumber => $composableBuilder(
    column: $table.completionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get markedBy =>
      $composableBuilder(column: $table.markedBy, builder: (column) => column);

  GeneratedColumn<bool> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LearningLedgerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningLedgerTable,
          LearningLedgerData,
          $$LearningLedgerTableFilterComposer,
          $$LearningLedgerTableOrderingComposer,
          $$LearningLedgerTableAnnotationComposer,
          $$LearningLedgerTableCreateCompanionBuilder,
          $$LearningLedgerTableUpdateCompanionBuilder,
          (
            LearningLedgerData,
            BaseReferences<
              _$AppDatabase,
              $LearningLedgerTable,
              LearningLedgerData
            >,
          ),
          LearningLedgerData,
          PrefetchHooks Function()
        > {
  $$LearningLedgerTableTableManager(
    _$AppDatabase db,
    $LearningLedgerTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> unitType = const Value.absent(),
                Value<String> unitIdentifier = const Value.absent(),
                Value<String> unitDisplayNameHe = const Value.absent(),
                Value<String> unitDisplayNameEn = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<int?> trackId = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> completionNumber = const Value.absent(),
                Value<int> markedBy = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LearningLedgerCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                unitType: unitType,
                unitIdentifier: unitIdentifier,
                unitDisplayNameHe: unitDisplayNameHe,
                unitDisplayNameEn: unitDisplayNameEn,
                trackType: trackType,
                trackId: trackId,
                completedAt: completedAt,
                completionNumber: completionNumber,
                markedBy: markedBy,
                isManual: isManual,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required String unitType,
                required String unitIdentifier,
                required String unitDisplayNameHe,
                required String unitDisplayNameEn,
                required String trackType,
                Value<int?> trackId = const Value.absent(),
                required DateTime completedAt,
                required int completionNumber,
                required int markedBy,
                Value<bool> isManual = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LearningLedgerCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                unitType: unitType,
                unitIdentifier: unitIdentifier,
                unitDisplayNameHe: unitDisplayNameHe,
                unitDisplayNameEn: unitDisplayNameEn,
                trackType: trackType,
                trackId: trackId,
                completedAt: completedAt,
                completionNumber: completionNumber,
                markedBy: markedBy,
                isManual: isManual,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningLedgerTable,
      LearningLedgerData,
      $$LearningLedgerTableFilterComposer,
      $$LearningLedgerTableOrderingComposer,
      $$LearningLedgerTableAnnotationComposer,
      $$LearningLedgerTableCreateCompanionBuilder,
      $$LearningLedgerTableUpdateCompanionBuilder,
      (
        LearningLedgerData,
        BaseReferences<_$AppDatabase, $LearningLedgerTable, LearningLedgerData>,
      ),
      LearningLedgerData,
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
      Value<String> goalType,
      Value<int?> paceValue,
      Value<String?> paceUnit,
      Value<String?> learningUnit,
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
      Value<String> goalType,
      Value<int?> paceValue,
      Value<String?> paceUnit,
      Value<String?> learningUnit,
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

  ColumnFilters<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paceValue => $composableBuilder(
    column: $table.paceValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paceUnit => $composableBuilder(
    column: $table.paceUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningUnit => $composableBuilder(
    column: $table.learningUnit,
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

  ColumnOrderings<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paceValue => $composableBuilder(
    column: $table.paceValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paceUnit => $composableBuilder(
    column: $table.paceUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningUnit => $composableBuilder(
    column: $table.learningUnit,
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

  GeneratedColumn<String> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<int> get paceValue =>
      $composableBuilder(column: $table.paceValue, builder: (column) => column);

  GeneratedColumn<String> get paceUnit =>
      $composableBuilder(column: $table.paceUnit, builder: (column) => column);

  GeneratedColumn<String> get learningUnit => $composableBuilder(
    column: $table.learningUnit,
    builder: (column) => column,
  );

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
                Value<String> goalType = const Value.absent(),
                Value<int?> paceValue = const Value.absent(),
                Value<String?> paceUnit = const Value.absent(),
                Value<String?> learningUnit = const Value.absent(),
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
                goalType: goalType,
                paceValue: paceValue,
                paceUnit: paceUnit,
                learningUnit: learningUnit,
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
                Value<String> goalType = const Value.absent(),
                Value<int?> paceValue = const Value.absent(),
                Value<String?> paceUnit = const Value.absent(),
                Value<String?> learningUnit = const Value.absent(),
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
                goalType: goalType,
                paceValue: paceValue,
                paceUnit: paceUnit,
                learningUnit: learningUnit,
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
      Value<String> rewardMode,
      Value<String> milestoneType,
      Value<bool> isVisible,
      Value<int?> poolId,
      Value<int?> repeatInterval,
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
      Value<String> rewardMode,
      Value<String> milestoneType,
      Value<bool> isVisible,
      Value<int?> poolId,
      Value<int?> repeatInterval,
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

  ColumnFilters<String> get rewardMode => $composableBuilder(
    column: $table.rewardMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get milestoneType => $composableBuilder(
    column: $table.milestoneType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get poolId => $composableBuilder(
    column: $table.poolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
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

  ColumnOrderings<String> get rewardMode => $composableBuilder(
    column: $table.rewardMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get milestoneType => $composableBuilder(
    column: $table.milestoneType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get poolId => $composableBuilder(
    column: $table.poolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
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

  GeneratedColumn<String> get rewardMode => $composableBuilder(
    column: $table.rewardMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get milestoneType => $composableBuilder(
    column: $table.milestoneType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);

  GeneratedColumn<int> get poolId =>
      $composableBuilder(column: $table.poolId, builder: (column) => column);

  GeneratedColumn<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
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
                Value<String> rewardMode = const Value.absent(),
                Value<String> milestoneType = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<int?> poolId = const Value.absent(),
                Value<int?> repeatInterval = const Value.absent(),
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
                rewardMode: rewardMode,
                milestoneType: milestoneType,
                isVisible: isVisible,
                poolId: poolId,
                repeatInterval: repeatInterval,
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
                Value<String> rewardMode = const Value.absent(),
                Value<String> milestoneType = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<int?> poolId = const Value.absent(),
                Value<int?> repeatInterval = const Value.absent(),
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
                rewardMode: rewardMode,
                milestoneType: milestoneType,
                isVisible: isVisible,
                poolId: poolId,
                repeatInterval: repeatInterval,
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
typedef $$RewardPoolsTableCreateCompanionBuilder =
    RewardPoolsCompanion Function({
      Value<int> id,
      required String name,
      required int profileId,
      Value<bool> isShared,
      Value<DateTime> createdAt,
    });
typedef $$RewardPoolsTableUpdateCompanionBuilder =
    RewardPoolsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> profileId,
      Value<bool> isShared,
      Value<DateTime> createdAt,
    });

class $$RewardPoolsTableFilterComposer
    extends Composer<_$AppDatabase, $RewardPoolsTable> {
  $$RewardPoolsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewardPoolsTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardPoolsTable> {
  $$RewardPoolsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewardPoolsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardPoolsTable> {
  $$RewardPoolsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RewardPoolsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewardPoolsTable,
          RewardPool,
          $$RewardPoolsTableFilterComposer,
          $$RewardPoolsTableOrderingComposer,
          $$RewardPoolsTableAnnotationComposer,
          $$RewardPoolsTableCreateCompanionBuilder,
          $$RewardPoolsTableUpdateCompanionBuilder,
          (
            RewardPool,
            BaseReferences<_$AppDatabase, $RewardPoolsTable, RewardPool>,
          ),
          RewardPool,
          PrefetchHooks Function()
        > {
  $$RewardPoolsTableTableManager(_$AppDatabase db, $RewardPoolsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardPoolsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardPoolsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardPoolsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RewardPoolsCompanion(
                id: id,
                name: name,
                profileId: profileId,
                isShared: isShared,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int profileId,
                Value<bool> isShared = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RewardPoolsCompanion.insert(
                id: id,
                name: name,
                profileId: profileId,
                isShared: isShared,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewardPoolsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewardPoolsTable,
      RewardPool,
      $$RewardPoolsTableFilterComposer,
      $$RewardPoolsTableOrderingComposer,
      $$RewardPoolsTableAnnotationComposer,
      $$RewardPoolsTableCreateCompanionBuilder,
      $$RewardPoolsTableUpdateCompanionBuilder,
      (
        RewardPool,
        BaseReferences<_$AppDatabase, $RewardPoolsTable, RewardPool>,
      ),
      RewardPool,
      PrefetchHooks Function()
    >;
typedef $$RewardPoolItemsTableCreateCompanionBuilder =
    RewardPoolItemsCompanion Function({
      Value<int> id,
      required int poolId,
      required String title,
      Value<String> description,
      Value<bool> isUsed,
    });
typedef $$RewardPoolItemsTableUpdateCompanionBuilder =
    RewardPoolItemsCompanion Function({
      Value<int> id,
      Value<int> poolId,
      Value<String> title,
      Value<String> description,
      Value<bool> isUsed,
    });

class $$RewardPoolItemsTableFilterComposer
    extends Composer<_$AppDatabase, $RewardPoolItemsTable> {
  $$RewardPoolItemsTableFilterComposer({
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

  ColumnFilters<int> get poolId => $composableBuilder(
    column: $table.poolId,
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

  ColumnFilters<bool> get isUsed => $composableBuilder(
    column: $table.isUsed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewardPoolItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardPoolItemsTable> {
  $$RewardPoolItemsTableOrderingComposer({
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

  ColumnOrderings<int> get poolId => $composableBuilder(
    column: $table.poolId,
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

  ColumnOrderings<bool> get isUsed => $composableBuilder(
    column: $table.isUsed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewardPoolItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardPoolItemsTable> {
  $$RewardPoolItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get poolId =>
      $composableBuilder(column: $table.poolId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isUsed =>
      $composableBuilder(column: $table.isUsed, builder: (column) => column);
}

class $$RewardPoolItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewardPoolItemsTable,
          RewardPoolItem,
          $$RewardPoolItemsTableFilterComposer,
          $$RewardPoolItemsTableOrderingComposer,
          $$RewardPoolItemsTableAnnotationComposer,
          $$RewardPoolItemsTableCreateCompanionBuilder,
          $$RewardPoolItemsTableUpdateCompanionBuilder,
          (
            RewardPoolItem,
            BaseReferences<
              _$AppDatabase,
              $RewardPoolItemsTable,
              RewardPoolItem
            >,
          ),
          RewardPoolItem,
          PrefetchHooks Function()
        > {
  $$RewardPoolItemsTableTableManager(
    _$AppDatabase db,
    $RewardPoolItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardPoolItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardPoolItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardPoolItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> poolId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> isUsed = const Value.absent(),
              }) => RewardPoolItemsCompanion(
                id: id,
                poolId: poolId,
                title: title,
                description: description,
                isUsed: isUsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int poolId,
                required String title,
                Value<String> description = const Value.absent(),
                Value<bool> isUsed = const Value.absent(),
              }) => RewardPoolItemsCompanion.insert(
                id: id,
                poolId: poolId,
                title: title,
                description: description,
                isUsed: isUsed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewardPoolItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewardPoolItemsTable,
      RewardPoolItem,
      $$RewardPoolItemsTableFilterComposer,
      $$RewardPoolItemsTableOrderingComposer,
      $$RewardPoolItemsTableAnnotationComposer,
      $$RewardPoolItemsTableCreateCompanionBuilder,
      $$RewardPoolItemsTableUpdateCompanionBuilder,
      (
        RewardPoolItem,
        BaseReferences<_$AppDatabase, $RewardPoolItemsTable, RewardPoolItem>,
      ),
      RewardPoolItem,
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
      Value<DateTime?> graceUsedDate,
      Value<int> gracePeriodDays,
    });
typedef $$StreaksTableUpdateCompanionBuilder =
    StreaksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> currentStreak,
      Value<int> maxStreak,
      Value<DateTime?> lastCompletionDate,
      Value<DateTime?> graceUsedDate,
      Value<int> gracePeriodDays,
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

  ColumnFilters<DateTime> get graceUsedDate => $composableBuilder(
    column: $table.graceUsedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gracePeriodDays => $composableBuilder(
    column: $table.gracePeriodDays,
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

  ColumnOrderings<DateTime> get graceUsedDate => $composableBuilder(
    column: $table.graceUsedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gracePeriodDays => $composableBuilder(
    column: $table.gracePeriodDays,
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

  GeneratedColumn<DateTime> get graceUsedDate => $composableBuilder(
    column: $table.graceUsedDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gracePeriodDays => $composableBuilder(
    column: $table.gracePeriodDays,
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
                Value<DateTime?> graceUsedDate = const Value.absent(),
                Value<int> gracePeriodDays = const Value.absent(),
              }) => StreaksCompanion(
                id: id,
                profileId: profileId,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                lastCompletionDate: lastCompletionDate,
                graceUsedDate: graceUsedDate,
                gracePeriodDays: gracePeriodDays,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> maxStreak = const Value.absent(),
                Value<DateTime?> lastCompletionDate = const Value.absent(),
                Value<DateTime?> graceUsedDate = const Value.absent(),
                Value<int> gracePeriodDays = const Value.absent(),
              }) => StreaksCompanion.insert(
                id: id,
                profileId: profileId,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                lastCompletionDate: lastCompletionDate,
                graceUsedDate: graceUsedDate,
                gracePeriodDays: gracePeriodDays,
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
typedef $$ContentDownloadStatusesTableCreateCompanionBuilder =
    ContentDownloadStatusesCompanion Function({
      required String curriculumId,
      required String languageCode,
      required String contentVersion,
      required int itemCount,
      required DateTime downloadedAt,
      Value<int> rowid,
    });
typedef $$ContentDownloadStatusesTableUpdateCompanionBuilder =
    ContentDownloadStatusesCompanion Function({
      Value<String> curriculumId,
      Value<String> languageCode,
      Value<String> contentVersion,
      Value<int> itemCount,
      Value<DateTime> downloadedAt,
      Value<int> rowid,
    });

class $$ContentDownloadStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $ContentDownloadStatusesTable> {
  $$ContentDownloadStatusesTableFilterComposer({
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

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentDownloadStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentDownloadStatusesTable> {
  $$ContentDownloadStatusesTableOrderingComposer({
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

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentDownloadStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentDownloadStatusesTable> {
  $$ContentDownloadStatusesTableAnnotationComposer({
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

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$ContentDownloadStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentDownloadStatusesTable,
          ContentDownloadStatuse,
          $$ContentDownloadStatusesTableFilterComposer,
          $$ContentDownloadStatusesTableOrderingComposer,
          $$ContentDownloadStatusesTableAnnotationComposer,
          $$ContentDownloadStatusesTableCreateCompanionBuilder,
          $$ContentDownloadStatusesTableUpdateCompanionBuilder,
          (
            ContentDownloadStatuse,
            BaseReferences<
              _$AppDatabase,
              $ContentDownloadStatusesTable,
              ContentDownloadStatuse
            >,
          ),
          ContentDownloadStatuse,
          PrefetchHooks Function()
        > {
  $$ContentDownloadStatusesTableTableManager(
    _$AppDatabase db,
    $ContentDownloadStatusesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentDownloadStatusesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ContentDownloadStatusesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContentDownloadStatusesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> curriculumId = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<String> contentVersion = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentDownloadStatusesCompanion(
                curriculumId: curriculumId,
                languageCode: languageCode,
                contentVersion: contentVersion,
                itemCount: itemCount,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String curriculumId,
                required String languageCode,
                required String contentVersion,
                required int itemCount,
                required DateTime downloadedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentDownloadStatusesCompanion.insert(
                curriculumId: curriculumId,
                languageCode: languageCode,
                contentVersion: contentVersion,
                itemCount: itemCount,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentDownloadStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentDownloadStatusesTable,
      ContentDownloadStatuse,
      $$ContentDownloadStatusesTableFilterComposer,
      $$ContentDownloadStatusesTableOrderingComposer,
      $$ContentDownloadStatusesTableAnnotationComposer,
      $$ContentDownloadStatusesTableCreateCompanionBuilder,
      $$ContentDownloadStatusesTableUpdateCompanionBuilder,
      (
        ContentDownloadStatuse,
        BaseReferences<
          _$AppDatabase,
          $ContentDownloadStatusesTable,
          ContentDownloadStatuse
        >,
      ),
      ContentDownloadStatuse,
      PrefetchHooks Function()
    >;
typedef $$LearningProgramsTableCreateCompanionBuilder =
    LearningProgramsCompanion Function({
      Value<int> id,
      required String name,
      required String displayName,
      Value<String> description,
      required String curriculumType,
      Value<bool> isActive,
      required String stagesConfig,
      Value<bool> hasTests,
      Value<String> testConfig,
      required DateTime createdAt,
      Value<String?> apiSource,
      Value<String?> apiProgramKey,
      Value<bool> isCalendarProgram,
    });
typedef $$LearningProgramsTableUpdateCompanionBuilder =
    LearningProgramsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> displayName,
      Value<String> description,
      Value<String> curriculumType,
      Value<bool> isActive,
      Value<String> stagesConfig,
      Value<bool> hasTests,
      Value<String> testConfig,
      Value<DateTime> createdAt,
      Value<String?> apiSource,
      Value<String?> apiProgramKey,
      Value<bool> isCalendarProgram,
    });

class $$LearningProgramsTableFilterComposer
    extends Composer<_$AppDatabase, $LearningProgramsTable> {
  $$LearningProgramsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumType => $composableBuilder(
    column: $table.curriculumType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stagesConfig => $composableBuilder(
    column: $table.stagesConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasTests => $composableBuilder(
    column: $table.hasTests,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get testConfig => $composableBuilder(
    column: $table.testConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiSource => $composableBuilder(
    column: $table.apiSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiProgramKey => $composableBuilder(
    column: $table.apiProgramKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCalendarProgram => $composableBuilder(
    column: $table.isCalendarProgram,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningProgramsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningProgramsTable> {
  $$LearningProgramsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumType => $composableBuilder(
    column: $table.curriculumType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stagesConfig => $composableBuilder(
    column: $table.stagesConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasTests => $composableBuilder(
    column: $table.hasTests,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get testConfig => $composableBuilder(
    column: $table.testConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiSource => $composableBuilder(
    column: $table.apiSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiProgramKey => $composableBuilder(
    column: $table.apiProgramKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCalendarProgram => $composableBuilder(
    column: $table.isCalendarProgram,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningProgramsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningProgramsTable> {
  $$LearningProgramsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get curriculumType => $composableBuilder(
    column: $table.curriculumType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get stagesConfig => $composableBuilder(
    column: $table.stagesConfig,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasTests =>
      $composableBuilder(column: $table.hasTests, builder: (column) => column);

  GeneratedColumn<String> get testConfig => $composableBuilder(
    column: $table.testConfig,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get apiSource =>
      $composableBuilder(column: $table.apiSource, builder: (column) => column);

  GeneratedColumn<String> get apiProgramKey => $composableBuilder(
    column: $table.apiProgramKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCalendarProgram => $composableBuilder(
    column: $table.isCalendarProgram,
    builder: (column) => column,
  );
}

class $$LearningProgramsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningProgramsTable,
          LearningProgram,
          $$LearningProgramsTableFilterComposer,
          $$LearningProgramsTableOrderingComposer,
          $$LearningProgramsTableAnnotationComposer,
          $$LearningProgramsTableCreateCompanionBuilder,
          $$LearningProgramsTableUpdateCompanionBuilder,
          (
            LearningProgram,
            BaseReferences<
              _$AppDatabase,
              $LearningProgramsTable,
              LearningProgram
            >,
          ),
          LearningProgram,
          PrefetchHooks Function()
        > {
  $$LearningProgramsTableTableManager(
    _$AppDatabase db,
    $LearningProgramsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> curriculumType = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> stagesConfig = const Value.absent(),
                Value<bool> hasTests = const Value.absent(),
                Value<String> testConfig = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> apiSource = const Value.absent(),
                Value<String?> apiProgramKey = const Value.absent(),
                Value<bool> isCalendarProgram = const Value.absent(),
              }) => LearningProgramsCompanion(
                id: id,
                name: name,
                displayName: displayName,
                description: description,
                curriculumType: curriculumType,
                isActive: isActive,
                stagesConfig: stagesConfig,
                hasTests: hasTests,
                testConfig: testConfig,
                createdAt: createdAt,
                apiSource: apiSource,
                apiProgramKey: apiProgramKey,
                isCalendarProgram: isCalendarProgram,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String displayName,
                Value<String> description = const Value.absent(),
                required String curriculumType,
                Value<bool> isActive = const Value.absent(),
                required String stagesConfig,
                Value<bool> hasTests = const Value.absent(),
                Value<String> testConfig = const Value.absent(),
                required DateTime createdAt,
                Value<String?> apiSource = const Value.absent(),
                Value<String?> apiProgramKey = const Value.absent(),
                Value<bool> isCalendarProgram = const Value.absent(),
              }) => LearningProgramsCompanion.insert(
                id: id,
                name: name,
                displayName: displayName,
                description: description,
                curriculumType: curriculumType,
                isActive: isActive,
                stagesConfig: stagesConfig,
                hasTests: hasTests,
                testConfig: testConfig,
                createdAt: createdAt,
                apiSource: apiSource,
                apiProgramKey: apiProgramKey,
                isCalendarProgram: isCalendarProgram,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningProgramsTable,
      LearningProgram,
      $$LearningProgramsTableFilterComposer,
      $$LearningProgramsTableOrderingComposer,
      $$LearningProgramsTableAnnotationComposer,
      $$LearningProgramsTableCreateCompanionBuilder,
      $$LearningProgramsTableUpdateCompanionBuilder,
      (
        LearningProgram,
        BaseReferences<_$AppDatabase, $LearningProgramsTable, LearningProgram>,
      ),
      LearningProgram,
      PrefetchHooks Function()
    >;
typedef $$ProfileProgramsTableCreateCompanionBuilder =
    ProfileProgramsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumType,
      required int programId,
      Value<DateTime?> trackingStartDate,
      Value<String?> trackingStartRef,
    });
typedef $$ProfileProgramsTableUpdateCompanionBuilder =
    ProfileProgramsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumType,
      Value<int> programId,
      Value<DateTime?> trackingStartDate,
      Value<String?> trackingStartRef,
    });

class $$ProfileProgramsTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileProgramsTable> {
  $$ProfileProgramsTableFilterComposer({
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

  ColumnFilters<String> get curriculumType => $composableBuilder(
    column: $table.curriculumType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trackingStartDate => $composableBuilder(
    column: $table.trackingStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackingStartRef => $composableBuilder(
    column: $table.trackingStartRef,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileProgramsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileProgramsTable> {
  $$ProfileProgramsTableOrderingComposer({
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

  ColumnOrderings<String> get curriculumType => $composableBuilder(
    column: $table.curriculumType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trackingStartDate => $composableBuilder(
    column: $table.trackingStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackingStartRef => $composableBuilder(
    column: $table.trackingStartRef,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileProgramsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileProgramsTable> {
  $$ProfileProgramsTableAnnotationComposer({
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

  GeneratedColumn<String> get curriculumType => $composableBuilder(
    column: $table.curriculumType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<DateTime> get trackingStartDate => $composableBuilder(
    column: $table.trackingStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackingStartRef => $composableBuilder(
    column: $table.trackingStartRef,
    builder: (column) => column,
  );
}

class $$ProfileProgramsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileProgramsTable,
          ProfileProgram,
          $$ProfileProgramsTableFilterComposer,
          $$ProfileProgramsTableOrderingComposer,
          $$ProfileProgramsTableAnnotationComposer,
          $$ProfileProgramsTableCreateCompanionBuilder,
          $$ProfileProgramsTableUpdateCompanionBuilder,
          (
            ProfileProgram,
            BaseReferences<
              _$AppDatabase,
              $ProfileProgramsTable,
              ProfileProgram
            >,
          ),
          ProfileProgram,
          PrefetchHooks Function()
        > {
  $$ProfileProgramsTableTableManager(
    _$AppDatabase db,
    $ProfileProgramsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumType = const Value.absent(),
                Value<int> programId = const Value.absent(),
                Value<DateTime?> trackingStartDate = const Value.absent(),
                Value<String?> trackingStartRef = const Value.absent(),
              }) => ProfileProgramsCompanion(
                id: id,
                profileId: profileId,
                curriculumType: curriculumType,
                programId: programId,
                trackingStartDate: trackingStartDate,
                trackingStartRef: trackingStartRef,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumType,
                required int programId,
                Value<DateTime?> trackingStartDate = const Value.absent(),
                Value<String?> trackingStartRef = const Value.absent(),
              }) => ProfileProgramsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumType: curriculumType,
                programId: programId,
                trackingStartDate: trackingStartDate,
                trackingStartRef: trackingStartRef,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileProgramsTable,
      ProfileProgram,
      $$ProfileProgramsTableFilterComposer,
      $$ProfileProgramsTableOrderingComposer,
      $$ProfileProgramsTableAnnotationComposer,
      $$ProfileProgramsTableCreateCompanionBuilder,
      $$ProfileProgramsTableUpdateCompanionBuilder,
      (
        ProfileProgram,
        BaseReferences<_$AppDatabase, $ProfileProgramsTable, ProfileProgram>,
      ),
      ProfileProgram,
      PrefetchHooks Function()
    >;
typedef $$TestDatesTableCreateCompanionBuilder =
    TestDatesCompanion Function({
      Value<int> id,
      required int programId,
      required DateTime testDate,
      Value<String> materialDescription,
    });
typedef $$TestDatesTableUpdateCompanionBuilder =
    TestDatesCompanion Function({
      Value<int> id,
      Value<int> programId,
      Value<DateTime> testDate,
      Value<String> materialDescription,
    });

class $$TestDatesTableFilterComposer
    extends Composer<_$AppDatabase, $TestDatesTable> {
  $$TestDatesTableFilterComposer({
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

  ColumnFilters<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get testDate => $composableBuilder(
    column: $table.testDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get materialDescription => $composableBuilder(
    column: $table.materialDescription,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TestDatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TestDatesTable> {
  $$TestDatesTableOrderingComposer({
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

  ColumnOrderings<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get testDate => $composableBuilder(
    column: $table.testDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get materialDescription => $composableBuilder(
    column: $table.materialDescription,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TestDatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestDatesTable> {
  $$TestDatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<DateTime> get testDate =>
      $composableBuilder(column: $table.testDate, builder: (column) => column);

  GeneratedColumn<String> get materialDescription => $composableBuilder(
    column: $table.materialDescription,
    builder: (column) => column,
  );
}

class $$TestDatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TestDatesTable,
          TestDate,
          $$TestDatesTableFilterComposer,
          $$TestDatesTableOrderingComposer,
          $$TestDatesTableAnnotationComposer,
          $$TestDatesTableCreateCompanionBuilder,
          $$TestDatesTableUpdateCompanionBuilder,
          (TestDate, BaseReferences<_$AppDatabase, $TestDatesTable, TestDate>),
          TestDate,
          PrefetchHooks Function()
        > {
  $$TestDatesTableTableManager(_$AppDatabase db, $TestDatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestDatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestDatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestDatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> programId = const Value.absent(),
                Value<DateTime> testDate = const Value.absent(),
                Value<String> materialDescription = const Value.absent(),
              }) => TestDatesCompanion(
                id: id,
                programId: programId,
                testDate: testDate,
                materialDescription: materialDescription,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int programId,
                required DateTime testDate,
                Value<String> materialDescription = const Value.absent(),
              }) => TestDatesCompanion.insert(
                id: id,
                programId: programId,
                testDate: testDate,
                materialDescription: materialDescription,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TestDatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TestDatesTable,
      TestDate,
      $$TestDatesTableFilterComposer,
      $$TestDatesTableOrderingComposer,
      $$TestDatesTableAnnotationComposer,
      $$TestDatesTableCreateCompanionBuilder,
      $$TestDatesTableUpdateCompanionBuilder,
      (TestDate, BaseReferences<_$AppDatabase, $TestDatesTable, TestDate>),
      TestDate,
      PrefetchHooks Function()
    >;
typedef $$TestScoresTableCreateCompanionBuilder =
    TestScoresCompanion Function({
      Value<int> id,
      required int profileId,
      required int programId,
      Value<int?> testDateId,
      required int scorePercentage,
      Value<String> notes,
      required DateTime createdAt,
    });
typedef $$TestScoresTableUpdateCompanionBuilder =
    TestScoresCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<int> programId,
      Value<int?> testDateId,
      Value<int> scorePercentage,
      Value<String> notes,
      Value<DateTime> createdAt,
    });

class $$TestScoresTableFilterComposer
    extends Composer<_$AppDatabase, $TestScoresTable> {
  $$TestScoresTableFilterComposer({
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

  ColumnFilters<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testDateId => $composableBuilder(
    column: $table.testDateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scorePercentage => $composableBuilder(
    column: $table.scorePercentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TestScoresTableOrderingComposer
    extends Composer<_$AppDatabase, $TestScoresTable> {
  $$TestScoresTableOrderingComposer({
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

  ColumnOrderings<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testDateId => $composableBuilder(
    column: $table.testDateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scorePercentage => $composableBuilder(
    column: $table.scorePercentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TestScoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestScoresTable> {
  $$TestScoresTableAnnotationComposer({
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

  GeneratedColumn<int> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<int> get testDateId => $composableBuilder(
    column: $table.testDateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scorePercentage => $composableBuilder(
    column: $table.scorePercentage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TestScoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TestScoresTable,
          TestScore,
          $$TestScoresTableFilterComposer,
          $$TestScoresTableOrderingComposer,
          $$TestScoresTableAnnotationComposer,
          $$TestScoresTableCreateCompanionBuilder,
          $$TestScoresTableUpdateCompanionBuilder,
          (
            TestScore,
            BaseReferences<_$AppDatabase, $TestScoresTable, TestScore>,
          ),
          TestScore,
          PrefetchHooks Function()
        > {
  $$TestScoresTableTableManager(_$AppDatabase db, $TestScoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestScoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestScoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestScoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> programId = const Value.absent(),
                Value<int?> testDateId = const Value.absent(),
                Value<int> scorePercentage = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TestScoresCompanion(
                id: id,
                profileId: profileId,
                programId: programId,
                testDateId: testDateId,
                scorePercentage: scorePercentage,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required int programId,
                Value<int?> testDateId = const Value.absent(),
                required int scorePercentage,
                Value<String> notes = const Value.absent(),
                required DateTime createdAt,
              }) => TestScoresCompanion.insert(
                id: id,
                profileId: profileId,
                programId: programId,
                testDateId: testDateId,
                scorePercentage: scorePercentage,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TestScoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TestScoresTable,
      TestScore,
      $$TestScoresTableFilterComposer,
      $$TestScoresTableOrderingComposer,
      $$TestScoresTableAnnotationComposer,
      $$TestScoresTableCreateCompanionBuilder,
      $$TestScoresTableUpdateCompanionBuilder,
      (TestScore, BaseReferences<_$AppDatabase, $TestScoresTable, TestScore>),
      TestScore,
      PrefetchHooks Function()
    >;
typedef $$StudyDayConfigsTableCreateCompanionBuilder =
    StudyDayConfigsCompanion Function({
      Value<int> profileId,
      required String curriculumId,
      required int dayOfWeek,
      Value<String> dayType,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StudyDayConfigsTableUpdateCompanionBuilder =
    StudyDayConfigsCompanion Function({
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> dayOfWeek,
      Value<String> dayType,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StudyDayConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $StudyDayConfigsTable> {
  $$StudyDayConfigsTableFilterComposer({
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

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayType => $composableBuilder(
    column: $table.dayType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudyDayConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyDayConfigsTable> {
  $$StudyDayConfigsTableOrderingComposer({
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

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayType => $composableBuilder(
    column: $table.dayType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyDayConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyDayConfigsTable> {
  $$StudyDayConfigsTableAnnotationComposer({
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

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<String> get dayType =>
      $composableBuilder(column: $table.dayType, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StudyDayConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyDayConfigsTable,
          StudyDayConfig,
          $$StudyDayConfigsTableFilterComposer,
          $$StudyDayConfigsTableOrderingComposer,
          $$StudyDayConfigsTableAnnotationComposer,
          $$StudyDayConfigsTableCreateCompanionBuilder,
          $$StudyDayConfigsTableUpdateCompanionBuilder,
          (
            StudyDayConfig,
            BaseReferences<
              _$AppDatabase,
              $StudyDayConfigsTable,
              StudyDayConfig
            >,
          ),
          StudyDayConfig,
          PrefetchHooks Function()
        > {
  $$StudyDayConfigsTableTableManager(
    _$AppDatabase db,
    $StudyDayConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyDayConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyDayConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyDayConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<int> dayOfWeek = const Value.absent(),
                Value<String> dayType = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyDayConfigsCompanion(
                profileId: profileId,
                curriculumId: curriculumId,
                dayOfWeek: dayOfWeek,
                dayType: dayType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                required String curriculumId,
                required int dayOfWeek,
                Value<String> dayType = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StudyDayConfigsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                dayOfWeek: dayOfWeek,
                dayType: dayType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyDayConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyDayConfigsTable,
      StudyDayConfig,
      $$StudyDayConfigsTableFilterComposer,
      $$StudyDayConfigsTableOrderingComposer,
      $$StudyDayConfigsTableAnnotationComposer,
      $$StudyDayConfigsTableCreateCompanionBuilder,
      $$StudyDayConfigsTableUpdateCompanionBuilder,
      (
        StudyDayConfig,
        BaseReferences<_$AppDatabase, $StudyDayConfigsTable, StudyDayConfig>,
      ),
      StudyDayConfig,
      PrefetchHooks Function()
    >;
typedef $$CalendarCacheTableCreateCompanionBuilder =
    CalendarCacheCompanion Function({
      Value<int> id,
      required String source,
      required String dateKey,
      required String responseJson,
      required DateTime fetchedAt,
    });
typedef $$CalendarCacheTableUpdateCompanionBuilder =
    CalendarCacheCompanion Function({
      Value<int> id,
      Value<String> source,
      Value<String> dateKey,
      Value<String> responseJson,
      Value<DateTime> fetchedAt,
    });

class $$CalendarCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarCacheTable> {
  $$CalendarCacheTableFilterComposer({
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseJson => $composableBuilder(
    column: $table.responseJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarCacheTable> {
  $$CalendarCacheTableOrderingComposer({
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseJson => $composableBuilder(
    column: $table.responseJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarCacheTable> {
  $$CalendarCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<String> get responseJson => $composableBuilder(
    column: $table.responseJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CalendarCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarCacheTable,
          CalendarCacheData,
          $$CalendarCacheTableFilterComposer,
          $$CalendarCacheTableOrderingComposer,
          $$CalendarCacheTableAnnotationComposer,
          $$CalendarCacheTableCreateCompanionBuilder,
          $$CalendarCacheTableUpdateCompanionBuilder,
          (
            CalendarCacheData,
            BaseReferences<
              _$AppDatabase,
              $CalendarCacheTable,
              CalendarCacheData
            >,
          ),
          CalendarCacheData,
          PrefetchHooks Function()
        > {
  $$CalendarCacheTableTableManager(_$AppDatabase db, $CalendarCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> responseJson = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => CalendarCacheCompanion(
                id: id,
                source: source,
                dateKey: dateKey,
                responseJson: responseJson,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String dateKey,
                required String responseJson,
                required DateTime fetchedAt,
              }) => CalendarCacheCompanion.insert(
                id: id,
                source: source,
                dateKey: dateKey,
                responseJson: responseJson,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarCacheTable,
      CalendarCacheData,
      $$CalendarCacheTableFilterComposer,
      $$CalendarCacheTableOrderingComposer,
      $$CalendarCacheTableAnnotationComposer,
      $$CalendarCacheTableCreateCompanionBuilder,
      $$CalendarCacheTableUpdateCompanionBuilder,
      (
        CalendarCacheData,
        BaseReferences<_$AppDatabase, $CalendarCacheTable, CalendarCacheData>,
      ),
      CalendarCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ActiveCurriculaTableTableManager get activeCurricula =>
      $$ActiveCurriculaTableTableManager(_db, _db.activeCurricula);
  $$CurriculumScopesTableTableManager get curriculumScopes =>
      $$CurriculumScopesTableTableManager(_db, _db.curriculumScopes);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(_db, _db.curriculumTracks);
  $$StageDefinitionsTableTableManager get stageDefinitions =>
      $$StageDefinitionsTableTableManager(_db, _db.stageDefinitions);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
  $$LearningLedgerTableTableManager get learningLedger =>
      $$LearningLedgerTableTableManager(_db, _db.learningLedger);
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
  $$RewardPoolsTableTableManager get rewardPools =>
      $$RewardPoolsTableTableManager(_db, _db.rewardPools);
  $$RewardPoolItemsTableTableManager get rewardPoolItems =>
      $$RewardPoolItemsTableTableManager(_db, _db.rewardPoolItems);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$TextCacheTableTableManager get textCache =>
      $$TextCacheTableTableManager(_db, _db.textCache);
  $$StreaksTableTableManager get streaks =>
      $$StreaksTableTableManager(_db, _db.streaks);
  $$TextDownloadStatusesTableTableManager get textDownloadStatuses =>
      $$TextDownloadStatusesTableTableManager(_db, _db.textDownloadStatuses);
  $$ContentDownloadStatusesTableTableManager get contentDownloadStatuses =>
      $$ContentDownloadStatusesTableTableManager(
        _db,
        _db.contentDownloadStatuses,
      );
  $$LearningProgramsTableTableManager get learningPrograms =>
      $$LearningProgramsTableTableManager(_db, _db.learningPrograms);
  $$ProfileProgramsTableTableManager get profilePrograms =>
      $$ProfileProgramsTableTableManager(_db, _db.profilePrograms);
  $$TestDatesTableTableManager get testDates =>
      $$TestDatesTableTableManager(_db, _db.testDates);
  $$TestScoresTableTableManager get testScores =>
      $$TestScoresTableTableManager(_db, _db.testScores);
  $$StudyDayConfigsTableTableManager get studyDayConfigs =>
      $$StudyDayConfigsTableTableManager(_db, _db.studyDayConfigs);
  $$CalendarCacheTableTableManager get calendarCache =>
      $$CalendarCacheTableTableManager(_db, _db.calendarCache);
}
