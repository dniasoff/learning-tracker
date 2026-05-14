// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_registry_database.dart';

// ignore_for_file: type=lint
class $DeviceAccountsTable extends DeviceAccounts
    with TableInfo<$DeviceAccountsTable, DeviceAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firebaseUidMeta = const VerificationMeta(
    'firebaseUid',
  );
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
    'firebase_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dbFileNameMeta = const VerificationMeta(
    'dbFileName',
  );
  @override
  late final GeneratedColumn<String> dbFileName = GeneratedColumn<String>(
    'db_file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    email,
    displayName,
    tier,
    firebaseUid,
    avatarIndex,
    createdAt,
    lastUsedAt,
    dbFileName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
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
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
        _firebaseUidMeta,
        firebaseUid.isAcceptableOrUnknown(
          data['firebase_uid']!,
          _firebaseUidMeta,
        ),
      );
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
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    if (data.containsKey('db_file_name')) {
      context.handle(
        _dbFileNameMeta,
        dbFileName.isAcceptableOrUnknown(
          data['db_file_name']!,
          _dbFileNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dbFileNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  DeviceAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceAccount(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      firebaseUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firebase_uid'],
      ),
      avatarIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avatar_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
      dbFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}db_file_name'],
      )!,
    );
  }

  @override
  $DeviceAccountsTable createAlias(String alias) {
    return $DeviceAccountsTable(attachedDatabase, alias);
  }
}

class DeviceAccount extends DataClass implements Insertable<DeviceAccount> {
  final String accountId;
  final String email;
  final String displayName;

  /// `cloudBorn` | `localBorn`
  final String tier;

  /// Firebase UID — null for local-born accounts.
  final String? firebaseUid;
  final int avatarIndex;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  /// The filename for this account's user database, e.g.
  /// `user_acc_abc123.db`. Unique so no two accounts share a file.
  final String dbFileName;
  const DeviceAccount({
    required this.accountId,
    required this.email,
    required this.displayName,
    required this.tier,
    this.firebaseUid,
    required this.avatarIndex,
    required this.createdAt,
    required this.lastUsedAt,
    required this.dbFileName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['email'] = Variable<String>(email);
    map['display_name'] = Variable<String>(displayName);
    map['tier'] = Variable<String>(tier);
    if (!nullToAbsent || firebaseUid != null) {
      map['firebase_uid'] = Variable<String>(firebaseUid);
    }
    map['avatar_index'] = Variable<int>(avatarIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    map['db_file_name'] = Variable<String>(dbFileName);
    return map;
  }

  DeviceAccountsCompanion toCompanion(bool nullToAbsent) {
    return DeviceAccountsCompanion(
      accountId: Value(accountId),
      email: Value(email),
      displayName: Value(displayName),
      tier: Value(tier),
      firebaseUid: firebaseUid == null && nullToAbsent
          ? const Value.absent()
          : Value(firebaseUid),
      avatarIndex: Value(avatarIndex),
      createdAt: Value(createdAt),
      lastUsedAt: Value(lastUsedAt),
      dbFileName: Value(dbFileName),
    );
  }

  factory DeviceAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceAccount(
      accountId: serializer.fromJson<String>(json['accountId']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String>(json['displayName']),
      tier: serializer.fromJson<String>(json['tier']),
      firebaseUid: serializer.fromJson<String?>(json['firebaseUid']),
      avatarIndex: serializer.fromJson<int>(json['avatarIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
      dbFileName: serializer.fromJson<String>(json['dbFileName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String>(displayName),
      'tier': serializer.toJson<String>(tier),
      'firebaseUid': serializer.toJson<String?>(firebaseUid),
      'avatarIndex': serializer.toJson<int>(avatarIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
      'dbFileName': serializer.toJson<String>(dbFileName),
    };
  }

  DeviceAccount copyWith({
    String? accountId,
    String? email,
    String? displayName,
    String? tier,
    Value<String?> firebaseUid = const Value.absent(),
    int? avatarIndex,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    String? dbFileName,
  }) => DeviceAccount(
    accountId: accountId ?? this.accountId,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    tier: tier ?? this.tier,
    firebaseUid: firebaseUid.present ? firebaseUid.value : this.firebaseUid,
    avatarIndex: avatarIndex ?? this.avatarIndex,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    dbFileName: dbFileName ?? this.dbFileName,
  );
  DeviceAccount copyWithCompanion(DeviceAccountsCompanion data) {
    return DeviceAccount(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      tier: data.tier.present ? data.tier.value : this.tier,
      firebaseUid: data.firebaseUid.present
          ? data.firebaseUid.value
          : this.firebaseUid,
      avatarIndex: data.avatarIndex.present
          ? data.avatarIndex.value
          : this.avatarIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      dbFileName: data.dbFileName.present
          ? data.dbFileName.value
          : this.dbFileName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceAccount(')
          ..write('accountId: $accountId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('tier: $tier, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('dbFileName: $dbFileName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    email,
    displayName,
    tier,
    firebaseUid,
    avatarIndex,
    createdAt,
    lastUsedAt,
    dbFileName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceAccount &&
          other.accountId == this.accountId &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.tier == this.tier &&
          other.firebaseUid == this.firebaseUid &&
          other.avatarIndex == this.avatarIndex &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.dbFileName == this.dbFileName);
}

class DeviceAccountsCompanion extends UpdateCompanion<DeviceAccount> {
  final Value<String> accountId;
  final Value<String> email;
  final Value<String> displayName;
  final Value<String> tier;
  final Value<String?> firebaseUid;
  final Value<int> avatarIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUsedAt;
  final Value<String> dbFileName;
  final Value<int> rowid;
  const DeviceAccountsCompanion({
    this.accountId = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.tier = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.avatarIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.dbFileName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceAccountsCompanion.insert({
    required String accountId,
    required String email,
    required String displayName,
    required String tier,
    this.firebaseUid = const Value.absent(),
    this.avatarIndex = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastUsedAt,
    required String dbFileName,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       email = Value(email),
       displayName = Value(displayName),
       tier = Value(tier),
       createdAt = Value(createdAt),
       lastUsedAt = Value(lastUsedAt),
       dbFileName = Value(dbFileName);
  static Insertable<DeviceAccount> custom({
    Expression<String>? accountId,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? tier,
    Expression<String>? firebaseUid,
    Expression<int>? avatarIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<String>? dbFileName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (tier != null) 'tier': tier,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (avatarIndex != null) 'avatar_index': avatarIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (dbFileName != null) 'db_file_name': dbFileName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceAccountsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? email,
    Value<String>? displayName,
    Value<String>? tier,
    Value<String?>? firebaseUid,
    Value<int>? avatarIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastUsedAt,
    Value<String>? dbFileName,
    Value<int>? rowid,
  }) {
    return DeviceAccountsCompanion(
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      tier: tier ?? this.tier,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      dbFileName: dbFileName ?? this.dbFileName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (avatarIndex.present) {
      map['avatar_index'] = Variable<int>(avatarIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (dbFileName.present) {
      map['db_file_name'] = Variable<String>(dbFileName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceAccountsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('tier: $tier, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('dbFileName: $dbFileName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceStateTable extends DeviceState
    with TableInfo<$DeviceStateTable, DeviceStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $DeviceStateTable createAlias(String alias) {
    return $DeviceStateTable(attachedDatabase, alias);
  }
}

class DeviceStateData extends DataClass implements Insertable<DeviceStateData> {
  final String key;
  final String? value;
  const DeviceStateData({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  DeviceStateCompanion toCompanion(bool nullToAbsent) {
    return DeviceStateCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory DeviceStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceStateData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  DeviceStateData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => DeviceStateData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  DeviceStateData copyWithCompanion(DeviceStateCompanion data) {
    return DeviceStateData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceStateData &&
          other.key == this.key &&
          other.value == this.value);
}

class DeviceStateCompanion extends UpdateCompanion<DeviceStateData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const DeviceStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceStateCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<DeviceStateData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceStateCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return DeviceStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DeviceRegistryDatabase extends GeneratedDatabase {
  _$DeviceRegistryDatabase(QueryExecutor e) : super(e);
  $DeviceRegistryDatabaseManager get managers =>
      $DeviceRegistryDatabaseManager(this);
  late final $DeviceAccountsTable deviceAccounts = $DeviceAccountsTable(this);
  late final $DeviceStateTable deviceState = $DeviceStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    deviceAccounts,
    deviceState,
  ];
}

typedef $$DeviceAccountsTableCreateCompanionBuilder =
    DeviceAccountsCompanion Function({
      required String accountId,
      required String email,
      required String displayName,
      required String tier,
      Value<String?> firebaseUid,
      Value<int> avatarIndex,
      required DateTime createdAt,
      required DateTime lastUsedAt,
      required String dbFileName,
      Value<int> rowid,
    });
typedef $$DeviceAccountsTableUpdateCompanionBuilder =
    DeviceAccountsCompanion Function({
      Value<String> accountId,
      Value<String> email,
      Value<String> displayName,
      Value<String> tier,
      Value<String?> firebaseUid,
      Value<int> avatarIndex,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsedAt,
      Value<String> dbFileName,
      Value<int> rowid,
    });

class $$DeviceAccountsTableFilterComposer
    extends Composer<_$DeviceRegistryDatabase, $DeviceAccountsTable> {
  $$DeviceAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
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

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dbFileName => $composableBuilder(
    column: $table.dbFileName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceAccountsTableOrderingComposer
    extends Composer<_$DeviceRegistryDatabase, $DeviceAccountsTable> {
  $$DeviceAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
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

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dbFileName => $composableBuilder(
    column: $table.dbFileName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceAccountsTableAnnotationComposer
    extends Composer<_$DeviceRegistryDatabase, $DeviceAccountsTable> {
  $$DeviceAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dbFileName => $composableBuilder(
    column: $table.dbFileName,
    builder: (column) => column,
  );
}

class $$DeviceAccountsTableTableManager
    extends
        RootTableManager<
          _$DeviceRegistryDatabase,
          $DeviceAccountsTable,
          DeviceAccount,
          $$DeviceAccountsTableFilterComposer,
          $$DeviceAccountsTableOrderingComposer,
          $$DeviceAccountsTableAnnotationComposer,
          $$DeviceAccountsTableCreateCompanionBuilder,
          $$DeviceAccountsTableUpdateCompanionBuilder,
          (
            DeviceAccount,
            BaseReferences<
              _$DeviceRegistryDatabase,
              $DeviceAccountsTable,
              DeviceAccount
            >,
          ),
          DeviceAccount,
          PrefetchHooks Function()
        > {
  $$DeviceAccountsTableTableManager(
    _$DeviceRegistryDatabase db,
    $DeviceAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String?> firebaseUid = const Value.absent(),
                Value<int> avatarIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
                Value<String> dbFileName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceAccountsCompanion(
                accountId: accountId,
                email: email,
                displayName: displayName,
                tier: tier,
                firebaseUid: firebaseUid,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                dbFileName: dbFileName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String email,
                required String displayName,
                required String tier,
                Value<String?> firebaseUid = const Value.absent(),
                Value<int> avatarIndex = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastUsedAt,
                required String dbFileName,
                Value<int> rowid = const Value.absent(),
              }) => DeviceAccountsCompanion.insert(
                accountId: accountId,
                email: email,
                displayName: displayName,
                tier: tier,
                firebaseUid: firebaseUid,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                dbFileName: dbFileName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceRegistryDatabase,
      $DeviceAccountsTable,
      DeviceAccount,
      $$DeviceAccountsTableFilterComposer,
      $$DeviceAccountsTableOrderingComposer,
      $$DeviceAccountsTableAnnotationComposer,
      $$DeviceAccountsTableCreateCompanionBuilder,
      $$DeviceAccountsTableUpdateCompanionBuilder,
      (
        DeviceAccount,
        BaseReferences<
          _$DeviceRegistryDatabase,
          $DeviceAccountsTable,
          DeviceAccount
        >,
      ),
      DeviceAccount,
      PrefetchHooks Function()
    >;
typedef $$DeviceStateTableCreateCompanionBuilder =
    DeviceStateCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$DeviceStateTableUpdateCompanionBuilder =
    DeviceStateCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$DeviceStateTableFilterComposer
    extends Composer<_$DeviceRegistryDatabase, $DeviceStateTable> {
  $$DeviceStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceStateTableOrderingComposer
    extends Composer<_$DeviceRegistryDatabase, $DeviceStateTable> {
  $$DeviceStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceStateTableAnnotationComposer
    extends Composer<_$DeviceRegistryDatabase, $DeviceStateTable> {
  $$DeviceStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DeviceStateTableTableManager
    extends
        RootTableManager<
          _$DeviceRegistryDatabase,
          $DeviceStateTable,
          DeviceStateData,
          $$DeviceStateTableFilterComposer,
          $$DeviceStateTableOrderingComposer,
          $$DeviceStateTableAnnotationComposer,
          $$DeviceStateTableCreateCompanionBuilder,
          $$DeviceStateTableUpdateCompanionBuilder,
          (
            DeviceStateData,
            BaseReferences<
              _$DeviceRegistryDatabase,
              $DeviceStateTable,
              DeviceStateData
            >,
          ),
          DeviceStateData,
          PrefetchHooks Function()
        > {
  $$DeviceStateTableTableManager(
    _$DeviceRegistryDatabase db,
    $DeviceStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceStateTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceRegistryDatabase,
      $DeviceStateTable,
      DeviceStateData,
      $$DeviceStateTableFilterComposer,
      $$DeviceStateTableOrderingComposer,
      $$DeviceStateTableAnnotationComposer,
      $$DeviceStateTableCreateCompanionBuilder,
      $$DeviceStateTableUpdateCompanionBuilder,
      (
        DeviceStateData,
        BaseReferences<
          _$DeviceRegistryDatabase,
          $DeviceStateTable,
          DeviceStateData
        >,
      ),
      DeviceStateData,
      PrefetchHooks Function()
    >;

class $DeviceRegistryDatabaseManager {
  final _$DeviceRegistryDatabase _db;
  $DeviceRegistryDatabaseManager(this._db);
  $$DeviceAccountsTableTableManager get deviceAccounts =>
      $$DeviceAccountsTableTableManager(_db, _db.deviceAccounts);
  $$DeviceStateTableTableManager get deviceState =>
      $$DeviceStateTableTableManager(_db, _db.deviceState);
}
