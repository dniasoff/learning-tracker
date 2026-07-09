// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    email,
    firebaseUid,
    passwordHash,
    tier,
    displayName,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
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
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
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
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      firebaseUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firebase_uid'],
      ),
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      ),
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
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
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;

  /// Email is the stable identity for both tiers.
  final String email;

  /// Populated only for cloud-born (or upgraded) accounts.
  final String? firebaseUid;

  /// argon2id password hash — populated only for local-born accounts.
  /// Cleared when a local-born account is upgraded to cloud-born.
  final String? passwordHash;

  /// `cloudBorn` | `localBorn`. Set at signup, immutable except via upgrade.
  final String tier;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Account({
    required this.id,
    required this.email,
    this.firebaseUid,
    this.passwordHash,
    required this.tier,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || firebaseUid != null) {
      map['firebase_uid'] = Variable<String>(firebaseUid);
    }
    if (!nullToAbsent || passwordHash != null) {
      map['password_hash'] = Variable<String>(passwordHash);
    }
    map['tier'] = Variable<String>(tier);
    map['display_name'] = Variable<String>(displayName);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      email: Value(email),
      firebaseUid: firebaseUid == null && nullToAbsent
          ? const Value.absent()
          : Value(firebaseUid),
      passwordHash: passwordHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordHash),
      tier: Value(tier),
      displayName: Value(displayName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      firebaseUid: serializer.fromJson<String?>(json['firebaseUid']),
      passwordHash: serializer.fromJson<String?>(json['passwordHash']),
      tier: serializer.fromJson<String>(json['tier']),
      displayName: serializer.fromJson<String>(json['displayName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'email': serializer.toJson<String>(email),
      'firebaseUid': serializer.toJson<String?>(firebaseUid),
      'passwordHash': serializer.toJson<String?>(passwordHash),
      'tier': serializer.toJson<String>(tier),
      'displayName': serializer.toJson<String>(displayName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Account copyWith({
    int? id,
    String? email,
    Value<String?> firebaseUid = const Value.absent(),
    Value<String?> passwordHash = const Value.absent(),
    String? tier,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Account(
    id: id ?? this.id,
    email: email ?? this.email,
    firebaseUid: firebaseUid.present ? firebaseUid.value : this.firebaseUid,
    passwordHash: passwordHash.present ? passwordHash.value : this.passwordHash,
    tier: tier ?? this.tier,
    displayName: displayName ?? this.displayName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      firebaseUid: data.firebaseUid.present
          ? data.firebaseUid.value
          : this.firebaseUid,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      tier: data.tier.present ? data.tier.value : this.tier,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('tier: $tier, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    firebaseUid,
    passwordHash,
    tier,
    displayName,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.email == this.email &&
          other.firebaseUid == this.firebaseUid &&
          other.passwordHash == this.passwordHash &&
          other.tier == this.tier &&
          other.displayName == this.displayName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String> email;
  final Value<String?> firebaseUid;
  final Value<String?> passwordHash;
  final Value<String> tier;
  final Value<String> displayName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.tier = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String email,
    this.firebaseUid = const Value.absent(),
    this.passwordHash = const Value.absent(),
    required String tier,
    required String displayName,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : email = Value(email),
       tier = Value(tier),
       displayName = Value(displayName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? email,
    Expression<String>? firebaseUid,
    Expression<String>? passwordHash,
    Expression<String>? tier,
    Expression<String>? displayName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (tier != null) 'tier': tier,
      if (displayName != null) 'display_name': displayName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? email,
    Value<String?>? firebaseUid,
    Value<String?>? passwordHash,
    Value<String>? tier,
    Value<String>? displayName,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      passwordHash: passwordHash ?? this.passwordHash,
      tier: tier ?? this.tier,
      displayName: displayName ?? this.displayName,
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
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
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
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('tier: $tier, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LearnerProfilesTable extends LearnerProfiles
    with TableInfo<$LearnerProfilesTable, LearnerProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnerProfilesTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
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
    $customConstraints: 'NOT NULL CHECK (mode IN (\'adult\', \'child\'))',
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
    defaultValue: const Constant<int>(0),
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
  static const VerificationMeta _isTutoredMeta = const VerificationMeta(
    'isTutored',
  );
  @override
  late final GeneratedColumn<bool> isTutored = GeneratedColumn<bool>(
    'is_tutored',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK ("is_tutored" IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _tutorParentUidMeta = const VerificationMeta(
    'tutorParentUid',
  );
  @override
  late final GeneratedColumn<String> tutorParentUid = GeneratedColumn<String>(
    'tutor_parent_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tutorRemoteProfileIdMeta =
      const VerificationMeta('tutorRemoteProfileId');
  @override
  late final GeneratedColumn<String> tutorRemoteProfileId =
      GeneratedColumn<String>(
        'tutor_remote_profile_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tutorGrantIdMeta = const VerificationMeta(
    'tutorGrantId',
  );
  @override
  late final GeneratedColumn<String> tutorGrantId = GeneratedColumn<String>(
    'tutor_grant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    isTutored,
    tutorParentUid,
    tutorRemoteProfileId,
    tutorGrantId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learner_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnerProfile> instance, {
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
    if (data.containsKey('is_tutored')) {
      context.handle(
        _isTutoredMeta,
        isTutored.isAcceptableOrUnknown(data['is_tutored']!, _isTutoredMeta),
      );
    }
    if (data.containsKey('tutor_parent_uid')) {
      context.handle(
        _tutorParentUidMeta,
        tutorParentUid.isAcceptableOrUnknown(
          data['tutor_parent_uid']!,
          _tutorParentUidMeta,
        ),
      );
    }
    if (data.containsKey('tutor_remote_profile_id')) {
      context.handle(
        _tutorRemoteProfileIdMeta,
        tutorRemoteProfileId.isAcceptableOrUnknown(
          data['tutor_remote_profile_id']!,
          _tutorRemoteProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('tutor_grant_id')) {
      context.handle(
        _tutorGrantIdMeta,
        tutorGrantId.isAcceptableOrUnknown(
          data['tutor_grant_id']!,
          _tutorGrantIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearnerProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnerProfile(
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
      isTutored: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_tutored'],
      )!,
      tutorParentUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tutor_parent_uid'],
      ),
      tutorRemoteProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tutor_remote_profile_id'],
      ),
      tutorGrantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tutor_grant_id'],
      ),
    );
  }

  @override
  $LearnerProfilesTable createAlias(String alias) {
    return $LearnerProfilesTable(attachedDatabase, alias);
  }
}

class LearnerProfile extends DataClass implements Insertable<LearnerProfile> {
  final int id;

  /// W3.25: FK → accounts(id) CASCADE DELETE.
  final int accountId;
  final String displayName;

  /// Profile mode — exactly 'adult' or 'child'. Enforced by CHECK constraint
  /// (schema v26, WS9.enum). Read via [ProfileMode.fromStorageKey].
  final String mode;
  final int avatarIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Tutor "talmid view" mirror (schema v28). When true, this is NOT one of
  /// the account's own learners — it is a read-only local mirror of a child
  /// that lives in another user's (the parent's) account, pulled in because
  /// this device's user is an active tutor for that child. Mirror rows must
  /// never be pushed up this account's own outbox.
  final bool isTutored;

  /// For a tutored mirror: the parent (owner) account's Firebase UID, the
  /// child's profile id within that account, and the tutor grant id. Used to
  /// resolve the source namespace for the pull and to route permitted edits
  /// back to the parent's namespace via Cloud Functions. Null for own profiles.
  final String? tutorParentUid;
  final String? tutorRemoteProfileId;
  final String? tutorGrantId;
  const LearnerProfile({
    required this.id,
    required this.accountId,
    required this.displayName,
    required this.mode,
    required this.avatarIndex,
    required this.createdAt,
    required this.updatedAt,
    required this.isTutored,
    this.tutorParentUid,
    this.tutorRemoteProfileId,
    this.tutorGrantId,
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
    map['is_tutored'] = Variable<bool>(isTutored);
    if (!nullToAbsent || tutorParentUid != null) {
      map['tutor_parent_uid'] = Variable<String>(tutorParentUid);
    }
    if (!nullToAbsent || tutorRemoteProfileId != null) {
      map['tutor_remote_profile_id'] = Variable<String>(tutorRemoteProfileId);
    }
    if (!nullToAbsent || tutorGrantId != null) {
      map['tutor_grant_id'] = Variable<String>(tutorGrantId);
    }
    return map;
  }

  LearnerProfilesCompanion toCompanion(bool nullToAbsent) {
    return LearnerProfilesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      displayName: Value(displayName),
      mode: Value(mode),
      avatarIndex: Value(avatarIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isTutored: Value(isTutored),
      tutorParentUid: tutorParentUid == null && nullToAbsent
          ? const Value.absent()
          : Value(tutorParentUid),
      tutorRemoteProfileId: tutorRemoteProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(tutorRemoteProfileId),
      tutorGrantId: tutorGrantId == null && nullToAbsent
          ? const Value.absent()
          : Value(tutorGrantId),
    );
  }

  factory LearnerProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnerProfile(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      mode: serializer.fromJson<String>(json['mode']),
      avatarIndex: serializer.fromJson<int>(json['avatarIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isTutored: serializer.fromJson<bool>(json['isTutored']),
      tutorParentUid: serializer.fromJson<String?>(json['tutorParentUid']),
      tutorRemoteProfileId: serializer.fromJson<String?>(
        json['tutorRemoteProfileId'],
      ),
      tutorGrantId: serializer.fromJson<String?>(json['tutorGrantId']),
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
      'isTutored': serializer.toJson<bool>(isTutored),
      'tutorParentUid': serializer.toJson<String?>(tutorParentUid),
      'tutorRemoteProfileId': serializer.toJson<String?>(tutorRemoteProfileId),
      'tutorGrantId': serializer.toJson<String?>(tutorGrantId),
    };
  }

  LearnerProfile copyWith({
    int? id,
    int? accountId,
    String? displayName,
    String? mode,
    int? avatarIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isTutored,
    Value<String?> tutorParentUid = const Value.absent(),
    Value<String?> tutorRemoteProfileId = const Value.absent(),
    Value<String?> tutorGrantId = const Value.absent(),
  }) => LearnerProfile(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    displayName: displayName ?? this.displayName,
    mode: mode ?? this.mode,
    avatarIndex: avatarIndex ?? this.avatarIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isTutored: isTutored ?? this.isTutored,
    tutorParentUid: tutorParentUid.present
        ? tutorParentUid.value
        : this.tutorParentUid,
    tutorRemoteProfileId: tutorRemoteProfileId.present
        ? tutorRemoteProfileId.value
        : this.tutorRemoteProfileId,
    tutorGrantId: tutorGrantId.present ? tutorGrantId.value : this.tutorGrantId,
  );
  LearnerProfile copyWithCompanion(LearnerProfilesCompanion data) {
    return LearnerProfile(
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
      isTutored: data.isTutored.present ? data.isTutored.value : this.isTutored,
      tutorParentUid: data.tutorParentUid.present
          ? data.tutorParentUid.value
          : this.tutorParentUid,
      tutorRemoteProfileId: data.tutorRemoteProfileId.present
          ? data.tutorRemoteProfileId.value
          : this.tutorRemoteProfileId,
      tutorGrantId: data.tutorGrantId.present
          ? data.tutorGrantId.value
          : this.tutorGrantId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnerProfile(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('displayName: $displayName, ')
          ..write('mode: $mode, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isTutored: $isTutored, ')
          ..write('tutorParentUid: $tutorParentUid, ')
          ..write('tutorRemoteProfileId: $tutorRemoteProfileId, ')
          ..write('tutorGrantId: $tutorGrantId')
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
    isTutored,
    tutorParentUid,
    tutorRemoteProfileId,
    tutorGrantId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnerProfile &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.displayName == this.displayName &&
          other.mode == this.mode &&
          other.avatarIndex == this.avatarIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isTutored == this.isTutored &&
          other.tutorParentUid == this.tutorParentUid &&
          other.tutorRemoteProfileId == this.tutorRemoteProfileId &&
          other.tutorGrantId == this.tutorGrantId);
}

class LearnerProfilesCompanion extends UpdateCompanion<LearnerProfile> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> displayName;
  final Value<String> mode;
  final Value<int> avatarIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isTutored;
  final Value<String?> tutorParentUid;
  final Value<String?> tutorRemoteProfileId;
  final Value<String?> tutorGrantId;
  const LearnerProfilesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.mode = const Value.absent(),
    this.avatarIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isTutored = const Value.absent(),
    this.tutorParentUid = const Value.absent(),
    this.tutorRemoteProfileId = const Value.absent(),
    this.tutorGrantId = const Value.absent(),
  });
  LearnerProfilesCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String displayName,
    required String mode,
    this.avatarIndex = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isTutored = const Value.absent(),
    this.tutorParentUid = const Value.absent(),
    this.tutorRemoteProfileId = const Value.absent(),
    this.tutorGrantId = const Value.absent(),
  }) : accountId = Value(accountId),
       displayName = Value(displayName),
       mode = Value(mode),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LearnerProfile> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? displayName,
    Expression<String>? mode,
    Expression<int>? avatarIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isTutored,
    Expression<String>? tutorParentUid,
    Expression<String>? tutorRemoteProfileId,
    Expression<String>? tutorGrantId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (displayName != null) 'display_name': displayName,
      if (mode != null) 'mode': mode,
      if (avatarIndex != null) 'avatar_index': avatarIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isTutored != null) 'is_tutored': isTutored,
      if (tutorParentUid != null) 'tutor_parent_uid': tutorParentUid,
      if (tutorRemoteProfileId != null)
        'tutor_remote_profile_id': tutorRemoteProfileId,
      if (tutorGrantId != null) 'tutor_grant_id': tutorGrantId,
    });
  }

  LearnerProfilesCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? displayName,
    Value<String>? mode,
    Value<int>? avatarIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isTutored,
    Value<String?>? tutorParentUid,
    Value<String?>? tutorRemoteProfileId,
    Value<String?>? tutorGrantId,
  }) {
    return LearnerProfilesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      displayName: displayName ?? this.displayName,
      mode: mode ?? this.mode,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isTutored: isTutored ?? this.isTutored,
      tutorParentUid: tutorParentUid ?? this.tutorParentUid,
      tutorRemoteProfileId: tutorRemoteProfileId ?? this.tutorRemoteProfileId,
      tutorGrantId: tutorGrantId ?? this.tutorGrantId,
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
    if (isTutored.present) {
      map['is_tutored'] = Variable<bool>(isTutored.value);
    }
    if (tutorParentUid.present) {
      map['tutor_parent_uid'] = Variable<String>(tutorParentUid.value);
    }
    if (tutorRemoteProfileId.present) {
      map['tutor_remote_profile_id'] = Variable<String>(
        tutorRemoteProfileId.value,
      );
    }
    if (tutorGrantId.present) {
      map['tutor_grant_id'] = Variable<String>(tutorGrantId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnerProfilesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('displayName: $displayName, ')
          ..write('mode: $mode, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isTutored: $isTutored, ')
          ..write('tutorParentUid: $tutorParentUid, ')
          ..write('tutorRemoteProfileId: $tutorRemoteProfileId, ')
          ..write('tutorGrantId: $tutorGrantId')
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
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _stateChangedAtMeta = const VerificationMeta(
    'stateChangedAt',
  );
  @override
  late final GeneratedColumn<DateTime> stateChangedAt =
      GeneratedColumn<DateTime>(
        'state_changed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
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
  static const VerificationMeta _paceResetDateMeta = const VerificationMeta(
    'paceResetDate',
  );
  @override
  late final GeneratedColumn<DateTime> paceResetDate =
      GeneratedColumn<DateTime>(
        'pace_reset_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastReorderAtMeta = const VerificationMeta(
    'lastReorderAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReorderAt =
      GeneratedColumn<DateTime>(
        'last_reorder_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    state,
    stateChangedAt,
    activatedAt,
    paceResetDate,
    lastReorderAt,
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
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('state_changed_at')) {
      context.handle(
        _stateChangedAtMeta,
        stateChangedAt.isAcceptableOrUnknown(
          data['state_changed_at']!,
          _stateChangedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stateChangedAtMeta);
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
    if (data.containsKey('pace_reset_date')) {
      context.handle(
        _paceResetDateMeta,
        paceResetDate.isAcceptableOrUnknown(
          data['pace_reset_date']!,
          _paceResetDateMeta,
        ),
      );
    }
    if (data.containsKey('last_reorder_at')) {
      context.handle(
        _lastReorderAtMeta,
        lastReorderAt.isAcceptableOrUnknown(
          data['last_reorder_at']!,
          _lastReorderAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId},
  ];
  @override
  CurriculumTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurriculumTrack(
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
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      stateChangedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}state_changed_at'],
      )!,
      activatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}activated_at'],
      )!,
      paceResetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pace_reset_date'],
      ),
      lastReorderAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reorder_at'],
      ),
    );
  }

  @override
  $CurriculumTracksTable createAlias(String alias) {
    return $CurriculumTracksTable(attachedDatabase, alias);
  }
}

class CurriculumTrack extends DataClass implements Insertable<CurriculumTrack> {
  /// Auto-increment primary key for FK references from other tables.
  final int id;
  final int profileId;

  /// curriculum_id from CurriculumId enum storageKey
  final String curriculumId;

  /// Unified lifecycle state. One of: 'active', 'retired', 'archived', 'deleted'.
  ///
  /// active  — track is in use; displayed in the UI.
  /// retired — track was deactivated by the user; hidden but not purged.
  /// archived — track reached a natural completion milestone.
  /// deleted — track was soft-deleted (deleteTrackAndData); awaits purge.
  final String state;

  /// When [state] was last changed (UTC). Acts as the LWW timestamp for sync.
  final DateTime stateChangedAt;

  /// When this track was activated (or reactivated) for this curriculum.
  final DateTime activatedAt;

  /// Date when pace was last reset (for Reset Pace recovery action).
  /// Null if pace has never been reset.
  final DateTime? paceResetDate;

  /// UTC timestamp of the most recent content-order change for this track.
  ///
  /// Set to [activatedAt] on track creation so the initial (default) order is
  /// treated as "just reordered" and no prior tasks are amnestied on first
  /// activation. Updated every time the user reorders sedarim, masechtos, or
  /// whole-curriculum items for this track.
  ///
  /// The projection filter uses this to filter out overdue items whose
  /// [scheduledDate] is strictly before this timestamp — i.e. items that were
  /// scheduled before the last reorder are amnestied (cleared) and will
  /// re-project from today's date forward.
  ///
  /// Null rows (from rows created before this column existed) are treated as
  /// [DateTime.fromMillisecondsSinceEpoch(0)] — "never amnestied" — so all
  /// historic overdue tasks remain visible.
  final DateTime? lastReorderAt;
  const CurriculumTrack({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.state,
    required this.stateChangedAt,
    required this.activatedAt,
    this.paceResetDate,
    this.lastReorderAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['state'] = Variable<String>(state);
    map['state_changed_at'] = Variable<DateTime>(stateChangedAt);
    map['activated_at'] = Variable<DateTime>(activatedAt);
    if (!nullToAbsent || paceResetDate != null) {
      map['pace_reset_date'] = Variable<DateTime>(paceResetDate);
    }
    if (!nullToAbsent || lastReorderAt != null) {
      map['last_reorder_at'] = Variable<DateTime>(lastReorderAt);
    }
    return map;
  }

  CurriculumTracksCompanion toCompanion(bool nullToAbsent) {
    return CurriculumTracksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      state: Value(state),
      stateChangedAt: Value(stateChangedAt),
      activatedAt: Value(activatedAt),
      paceResetDate: paceResetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(paceResetDate),
      lastReorderAt: lastReorderAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReorderAt),
    );
  }

  factory CurriculumTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurriculumTrack(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      state: serializer.fromJson<String>(json['state']),
      stateChangedAt: serializer.fromJson<DateTime>(json['stateChangedAt']),
      activatedAt: serializer.fromJson<DateTime>(json['activatedAt']),
      paceResetDate: serializer.fromJson<DateTime?>(json['paceResetDate']),
      lastReorderAt: serializer.fromJson<DateTime?>(json['lastReorderAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'state': serializer.toJson<String>(state),
      'stateChangedAt': serializer.toJson<DateTime>(stateChangedAt),
      'activatedAt': serializer.toJson<DateTime>(activatedAt),
      'paceResetDate': serializer.toJson<DateTime?>(paceResetDate),
      'lastReorderAt': serializer.toJson<DateTime?>(lastReorderAt),
    };
  }

  CurriculumTrack copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? state,
    DateTime? stateChangedAt,
    DateTime? activatedAt,
    Value<DateTime?> paceResetDate = const Value.absent(),
    Value<DateTime?> lastReorderAt = const Value.absent(),
  }) => CurriculumTrack(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    state: state ?? this.state,
    stateChangedAt: stateChangedAt ?? this.stateChangedAt,
    activatedAt: activatedAt ?? this.activatedAt,
    paceResetDate: paceResetDate.present
        ? paceResetDate.value
        : this.paceResetDate,
    lastReorderAt: lastReorderAt.present
        ? lastReorderAt.value
        : this.lastReorderAt,
  );
  CurriculumTrack copyWithCompanion(CurriculumTracksCompanion data) {
    return CurriculumTrack(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      state: data.state.present ? data.state.value : this.state,
      stateChangedAt: data.stateChangedAt.present
          ? data.stateChangedAt.value
          : this.stateChangedAt,
      activatedAt: data.activatedAt.present
          ? data.activatedAt.value
          : this.activatedAt,
      paceResetDate: data.paceResetDate.present
          ? data.paceResetDate.value
          : this.paceResetDate,
      lastReorderAt: data.lastReorderAt.present
          ? data.lastReorderAt.value
          : this.lastReorderAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumTrack(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('state: $state, ')
          ..write('stateChangedAt: $stateChangedAt, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('paceResetDate: $paceResetDate, ')
          ..write('lastReorderAt: $lastReorderAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    state,
    stateChangedAt,
    activatedAt,
    paceResetDate,
    lastReorderAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurriculumTrack &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.state == this.state &&
          other.stateChangedAt == this.stateChangedAt &&
          other.activatedAt == this.activatedAt &&
          other.paceResetDate == this.paceResetDate &&
          other.lastReorderAt == this.lastReorderAt);
}

class CurriculumTracksCompanion extends UpdateCompanion<CurriculumTrack> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> state;
  final Value<DateTime> stateChangedAt;
  final Value<DateTime> activatedAt;
  final Value<DateTime?> paceResetDate;
  final Value<DateTime?> lastReorderAt;
  const CurriculumTracksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.state = const Value.absent(),
    this.stateChangedAt = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.paceResetDate = const Value.absent(),
    this.lastReorderAt = const Value.absent(),
  });
  CurriculumTracksCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    this.state = const Value.absent(),
    required DateTime stateChangedAt,
    required DateTime activatedAt,
    this.paceResetDate = const Value.absent(),
    this.lastReorderAt = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       stateChangedAt = Value(stateChangedAt),
       activatedAt = Value(activatedAt);
  static Insertable<CurriculumTrack> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? state,
    Expression<DateTime>? stateChangedAt,
    Expression<DateTime>? activatedAt,
    Expression<DateTime>? paceResetDate,
    Expression<DateTime>? lastReorderAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (state != null) 'state': state,
      if (stateChangedAt != null) 'state_changed_at': stateChangedAt,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (paceResetDate != null) 'pace_reset_date': paceResetDate,
      if (lastReorderAt != null) 'last_reorder_at': lastReorderAt,
    });
  }

  CurriculumTracksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? state,
    Value<DateTime>? stateChangedAt,
    Value<DateTime>? activatedAt,
    Value<DateTime?>? paceResetDate,
    Value<DateTime?>? lastReorderAt,
  }) {
    return CurriculumTracksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      state: state ?? this.state,
      stateChangedAt: stateChangedAt ?? this.stateChangedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      paceResetDate: paceResetDate ?? this.paceResetDate,
      lastReorderAt: lastReorderAt ?? this.lastReorderAt,
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
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (stateChangedAt.present) {
      map['state_changed_at'] = Variable<DateTime>(stateChangedAt.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<DateTime>(activatedAt.value);
    }
    if (paceResetDate.present) {
      map['pace_reset_date'] = Variable<DateTime>(paceResetDate.value);
    }
    if (lastReorderAt.present) {
      map['last_reorder_at'] = Variable<DateTime>(lastReorderAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumTracksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('state: $state, ')
          ..write('stateChangedAt: $stateChangedAt, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('paceResetDate: $paceResetDate, ')
          ..write('lastReorderAt: $lastReorderAt')
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id)',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    trackId,
    scopeLevel,
    scopeValue,
    createdAt,
    updatedAt,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, scopeLevel, scopeValue, trackId},
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
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

  /// W3.25: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final int trackId;

  /// Which hierarchy level the scope applies to (1-4, matching level1-level4).
  final int scopeLevel;

  /// The value at that level (e.g., "Seder Zeraim", "Berachos").
  final String scopeValue;
  final DateTime createdAt;

  /// W3.23: LWW timestamp for sync.
  final DateTime updatedAt;
  const CurriculumScope({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.scopeLevel,
    required this.scopeValue,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_id'] = Variable<int>(trackId);
    map['scope_level'] = Variable<int>(scopeLevel);
    map['scope_value'] = Variable<String>(scopeValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CurriculumScopesCompanion toCompanion(bool nullToAbsent) {
    return CurriculumScopesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackId: Value(trackId),
      scopeLevel: Value(scopeLevel),
      scopeValue: Value(scopeValue),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
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
      trackId: serializer.fromJson<int>(json['trackId']),
      scopeLevel: serializer.fromJson<int>(json['scopeLevel']),
      scopeValue: serializer.fromJson<String>(json['scopeValue']),
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
      'trackId': serializer.toJson<int>(trackId),
      'scopeLevel': serializer.toJson<int>(scopeLevel),
      'scopeValue': serializer.toJson<String>(scopeValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CurriculumScope copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? trackId,
    int? scopeLevel,
    String? scopeValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurriculumScope(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
    scopeLevel: scopeLevel ?? this.scopeLevel,
    scopeValue: scopeValue ?? this.scopeValue,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CurriculumScope copyWithCompanion(CurriculumScopesCompanion data) {
    return CurriculumScope(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      scopeLevel: data.scopeLevel.present
          ? data.scopeLevel.value
          : this.scopeLevel,
      scopeValue: data.scopeValue.present
          ? data.scopeValue.value
          : this.scopeValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumScope(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackId: $trackId, ')
          ..write('scopeLevel: $scopeLevel, ')
          ..write('scopeValue: $scopeValue, ')
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
    trackId,
    scopeLevel,
    scopeValue,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurriculumScope &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackId == this.trackId &&
          other.scopeLevel == this.scopeLevel &&
          other.scopeValue == this.scopeValue &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CurriculumScopesCompanion extends UpdateCompanion<CurriculumScope> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<int> scopeLevel;
  final Value<String> scopeValue;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CurriculumScopesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.scopeLevel = const Value.absent(),
    this.scopeValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CurriculumScopesCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int scopeLevel,
    required String scopeValue,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       scopeLevel = Value(scopeLevel),
       scopeValue = Value(scopeValue),
       createdAt = Value(createdAt);
  static Insertable<CurriculumScope> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
    Expression<int>? scopeLevel,
    Expression<String>? scopeValue,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (scopeLevel != null) 'scope_level': scopeLevel,
      if (scopeValue != null) 'scope_value': scopeValue,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CurriculumScopesCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? trackId,
    Value<int>? scopeLevel,
    Value<String>? scopeValue,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CurriculumScopesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
      scopeLevel: scopeLevel ?? this.scopeLevel,
      scopeValue: scopeValue ?? this.scopeValue,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumScopesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackId: $trackId, ')
          ..write('scopeLevel: $scopeLevel, ')
          ..write('scopeValue: $scopeValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id)',
    ),
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
  static const VerificationMeta _scheduleMeta = const VerificationMeta(
    'schedule',
  );
  @override
  late final GeneratedColumn<String> schedule = GeneratedColumn<String>(
    'schedule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{"type":"delay","delay_days":0}'),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    trackId,
    stageOrder,
    stageName,
    isDefault,
    schedule,
    updatedAt,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('schedule')) {
      context.handle(
        _scheduleMeta,
        schedule.isAcceptableOrUnknown(data['schedule']!, _scheduleMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, stageOrder, trackId},
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      stageOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_order'],
      )!,
      stageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage_name'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      schedule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final int trackId;
  final int stageOrder;
  final String stageName;
  final bool isDefault;

  /// JSON-encoded ScheduleSpec, e.g. {"type":"delay","delay_days":7}.
  /// Replaces the former quartet: scheduleType / daysOfWeek /
  /// rollingWindowSize / delayDays.
  final String schedule;

  /// W3.23: last-write-wins timestamp for sync.
  final DateTime updatedAt;
  const StageDefinition({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.stageOrder,
    required this.stageName,
    required this.isDefault,
    required this.schedule,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_id'] = Variable<int>(trackId);
    map['stage_order'] = Variable<int>(stageOrder);
    map['stage_name'] = Variable<String>(stageName);
    map['is_default'] = Variable<bool>(isDefault);
    map['schedule'] = Variable<String>(schedule);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StageDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return StageDefinitionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackId: Value(trackId),
      stageOrder: Value(stageOrder),
      stageName: Value(stageName),
      isDefault: Value(isDefault),
      schedule: Value(schedule),
      updatedAt: Value(updatedAt),
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
      trackId: serializer.fromJson<int>(json['trackId']),
      stageOrder: serializer.fromJson<int>(json['stageOrder']),
      stageName: serializer.fromJson<String>(json['stageName']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      schedule: serializer.fromJson<String>(json['schedule']),
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
      'trackId': serializer.toJson<int>(trackId),
      'stageOrder': serializer.toJson<int>(stageOrder),
      'stageName': serializer.toJson<String>(stageName),
      'isDefault': serializer.toJson<bool>(isDefault),
      'schedule': serializer.toJson<String>(schedule),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StageDefinition copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? trackId,
    int? stageOrder,
    String? stageName,
    bool? isDefault,
    String? schedule,
    DateTime? updatedAt,
  }) => StageDefinition(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
    stageOrder: stageOrder ?? this.stageOrder,
    stageName: stageName ?? this.stageName,
    isDefault: isDefault ?? this.isDefault,
    schedule: schedule ?? this.schedule,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StageDefinition copyWithCompanion(StageDefinitionsCompanion data) {
    return StageDefinition(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      stageOrder: data.stageOrder.present
          ? data.stageOrder.value
          : this.stageOrder,
      stageName: data.stageName.present ? data.stageName.value : this.stageName,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      schedule: data.schedule.present ? data.schedule.value : this.schedule,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StageDefinition(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackId: $trackId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('stageName: $stageName, ')
          ..write('isDefault: $isDefault, ')
          ..write('schedule: $schedule, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    trackId,
    stageOrder,
    stageName,
    isDefault,
    schedule,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StageDefinition &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackId == this.trackId &&
          other.stageOrder == this.stageOrder &&
          other.stageName == this.stageName &&
          other.isDefault == this.isDefault &&
          other.schedule == this.schedule &&
          other.updatedAt == this.updatedAt);
}

class StageDefinitionsCompanion extends UpdateCompanion<StageDefinition> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<int> stageOrder;
  final Value<String> stageName;
  final Value<bool> isDefault;
  final Value<String> schedule;
  final Value<DateTime> updatedAt;
  const StageDefinitionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.stageName = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.schedule = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StageDefinitionsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int stageOrder,
    required String stageName,
    this.isDefault = const Value.absent(),
    this.schedule = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       stageOrder = Value(stageOrder),
       stageName = Value(stageName);
  static Insertable<StageDefinition> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
    Expression<int>? stageOrder,
    Expression<String>? stageName,
    Expression<bool>? isDefault,
    Expression<String>? schedule,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (stageName != null) 'stage_name': stageName,
      if (isDefault != null) 'is_default': isDefault,
      if (schedule != null) 'schedule': schedule,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StageDefinitionsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? trackId,
    Value<int>? stageOrder,
    Value<String>? stageName,
    Value<bool>? isDefault,
    Value<String>? schedule,
    Value<DateTime>? updatedAt,
  }) {
    return StageDefinitionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
      stageOrder: stageOrder ?? this.stageOrder,
      stageName: stageName ?? this.stageName,
      isDefault: isDefault ?? this.isDefault,
      schedule: schedule ?? this.schedule,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (stageOrder.present) {
      map['stage_order'] = Variable<int>(stageOrder.value);
    }
    if (stageName.present) {
      map['stage_name'] = Variable<String>(stageName.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (schedule.present) {
      map['schedule'] = Variable<String>(schedule.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StageDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackId: $trackId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('stageName: $stageName, ')
          ..write('isDefault: $isDefault, ')
          ..write('schedule: $schedule, ')
          ..write('updatedAt: $updatedAt')
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
    requiredDuringInsert: true,
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id)',
    ),
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
    trackId,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
    {profileId, curriculumId, stageOrder, trackId},
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
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
  final int trackId;
  final int stageOrder;
  final int points;
  const PointConfig({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.stageOrder,
    required this.points,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_id'] = Variable<int>(trackId);
    map['stage_order'] = Variable<int>(stageOrder);
    map['points'] = Variable<int>(points);
    return map;
  }

  PointConfigsCompanion toCompanion(bool nullToAbsent) {
    return PointConfigsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackId: Value(trackId),
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
      trackId: serializer.fromJson<int>(json['trackId']),
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
      'trackId': serializer.toJson<int>(trackId),
      'stageOrder': serializer.toJson<int>(stageOrder),
      'points': serializer.toJson<int>(points),
    };
  }

  PointConfig copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? trackId,
    int? stageOrder,
    int? points,
  }) => PointConfig(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
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
          ..write('trackId: $trackId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('points: $points')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, curriculumId, trackId, stageOrder, points);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointConfig &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackId == this.trackId &&
          other.stageOrder == this.stageOrder &&
          other.points == this.points);
}

class PointConfigsCompanion extends UpdateCompanion<PointConfig> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<int> stageOrder;
  final Value<int> points;
  const PointConfigsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.points = const Value.absent(),
  });
  PointConfigsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int stageOrder,
    required int points,
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       stageOrder = Value(stageOrder),
       points = Value(points);
  static Insertable<PointConfig> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
    Expression<int>? stageOrder,
    Expression<int>? points,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (points != null) 'points': points,
    });
  }

  PointConfigsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? trackId,
    Value<int>? stageOrder,
    Value<int>? points,
  }) {
    return PointConfigsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
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
          ..write('trackId: $trackId, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('points: $points')
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
    requiredDuringInsert: true,
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id)',
    ),
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
    trackId,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {
    profileId,
    curriculumId,
    dayOfWeek,
    trackId,
  };
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
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
  final int trackId;
  final int dayOfWeek;
  final String dayType;
  final DateTime updatedAt;
  const StudyDayConfig({
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.dayOfWeek,
    required this.dayType,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_id'] = Variable<int>(trackId);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['day_type'] = Variable<String>(dayType);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudyDayConfigsCompanion toCompanion(bool nullToAbsent) {
    return StudyDayConfigsCompanion(
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackId: Value(trackId),
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
      trackId: serializer.fromJson<int>(json['trackId']),
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
      'trackId': serializer.toJson<int>(trackId),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'dayType': serializer.toJson<String>(dayType),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StudyDayConfig copyWith({
    int? profileId,
    String? curriculumId,
    int? trackId,
    int? dayOfWeek,
    String? dayType,
    DateTime? updatedAt,
  }) => StudyDayConfig(
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
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
          ..write('trackId: $trackId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('dayType: $dayType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    curriculumId,
    trackId,
    dayOfWeek,
    dayType,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyDayConfig &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackId == this.trackId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.dayType == this.dayType &&
          other.updatedAt == this.updatedAt);
}

class StudyDayConfigsCompanion extends UpdateCompanion<StudyDayConfig> {
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<int> dayOfWeek;
  final Value<String> dayType;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudyDayConfigsCompanion({
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.dayType = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyDayConfigsCompanion.insert({
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int dayOfWeek,
    this.dayType = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       dayOfWeek = Value(dayOfWeek),
       updatedAt = Value(updatedAt);
  static Insertable<StudyDayConfig> custom({
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
    Expression<int>? dayOfWeek,
    Expression<String>? dayType,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (dayType != null) 'day_type': dayType,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyDayConfigsCompanion copyWith({
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? trackId,
    Value<int>? dayOfWeek,
    Value<String>? dayType,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StudyDayConfigsCompanion(
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
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
          ..write('trackId: $trackId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('dayType: $dayType, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletionEventsTable extends CompletionEvents
    with TableInfo<$CompletionEventsTable, CompletionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionEventsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _eventTimestampMeta = const VerificationMeta(
    'eventTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> eventTimestamp =
      GeneratedColumn<DateTime>(
        'event_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _purgedAtMeta = const VerificationMeta(
    'purgedAt',
  );
  @override
  late final GeneratedColumn<DateTime> purgedAt = GeneratedColumn<DateTime>(
    'purged_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    sefariaRef,
    stageId,
    trackType,
    trackId,
    points,
    eventTimestamp,
    createdAt,
    purgedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completion_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletionEvent> instance, {
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('event_timestamp')) {
      context.handle(
        _eventTimestampMeta,
        eventTimestamp.isAcceptableOrUnknown(
          data['event_timestamp']!,
          _eventTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eventTimestampMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('purged_at')) {
      context.handle(
        _purgedAtMeta,
        purgedAt.isAcceptableOrUnknown(data['purged_at']!, _purgedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletionEvent(
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      eventTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_timestamp'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      purgedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}purged_at'],
      ),
    );
  }

  @override
  $CompletionEventsTable createAlias(String alias) {
    return $CompletionEventsTable(attachedDatabase, alias);
  }
}

class CompletionEvent extends DataClass implements Insertable<CompletionEvent> {
  final int id;

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;

  /// FK → CurriculumTracks.id. Added v20 to enable the completions view.
  /// Nullable for legacy rows that pre-date this column.
  final int? trackId;
  final int points;
  final DateTime eventTimestamp;
  final DateTime createdAt;

  /// C3: tombstone timestamp set by purgeHistory instead of deleting the row.
  /// null = active; non-null = purged at this UTC timestamp.
  final DateTime? purgedAt;
  const CompletionEvent({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    this.trackId,
    required this.points,
    required this.eventTimestamp,
    required this.createdAt,
    this.purgedAt,
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
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<int>(trackId);
    }
    map['points'] = Variable<int>(points);
    map['event_timestamp'] = Variable<DateTime>(eventTimestamp);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || purgedAt != null) {
      map['purged_at'] = Variable<DateTime>(purgedAt);
    }
    return map;
  }

  CompletionEventsCompanion toCompanion(bool nullToAbsent) {
    return CompletionEventsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      sefariaRef: Value(sefariaRef),
      stageId: Value(stageId),
      trackType: Value(trackType),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      points: Value(points),
      eventTimestamp: Value(eventTimestamp),
      createdAt: Value(createdAt),
      purgedAt: purgedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(purgedAt),
    );
  }

  factory CompletionEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletionEvent(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      stageId: serializer.fromJson<int>(json['stageId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      trackId: serializer.fromJson<int?>(json['trackId']),
      points: serializer.fromJson<int>(json['points']),
      eventTimestamp: serializer.fromJson<DateTime>(json['eventTimestamp']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      purgedAt: serializer.fromJson<DateTime?>(json['purgedAt']),
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
      'trackId': serializer.toJson<int?>(trackId),
      'points': serializer.toJson<int>(points),
      'eventTimestamp': serializer.toJson<DateTime>(eventTimestamp),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'purgedAt': serializer.toJson<DateTime?>(purgedAt),
    };
  }

  CompletionEvent copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? stageId,
    String? trackType,
    Value<int?> trackId = const Value.absent(),
    int? points,
    DateTime? eventTimestamp,
    DateTime? createdAt,
    Value<DateTime?> purgedAt = const Value.absent(),
  }) => CompletionEvent(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    stageId: stageId ?? this.stageId,
    trackType: trackType ?? this.trackType,
    trackId: trackId.present ? trackId.value : this.trackId,
    points: points ?? this.points,
    eventTimestamp: eventTimestamp ?? this.eventTimestamp,
    createdAt: createdAt ?? this.createdAt,
    purgedAt: purgedAt.present ? purgedAt.value : this.purgedAt,
  );
  CompletionEvent copyWithCompanion(CompletionEventsCompanion data) {
    return CompletionEvent(
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      points: data.points.present ? data.points.value : this.points,
      eventTimestamp: data.eventTimestamp.present
          ? data.eventTimestamp.value
          : this.eventTimestamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      purgedAt: data.purgedAt.present ? data.purgedAt.value : this.purgedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletionEvent(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('trackId: $trackId, ')
          ..write('points: $points, ')
          ..write('eventTimestamp: $eventTimestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('purgedAt: $purgedAt')
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
    trackId,
    points,
    eventTimestamp,
    createdAt,
    purgedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletionEvent &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.sefariaRef == this.sefariaRef &&
          other.stageId == this.stageId &&
          other.trackType == this.trackType &&
          other.trackId == this.trackId &&
          other.points == this.points &&
          other.eventTimestamp == this.eventTimestamp &&
          other.createdAt == this.createdAt &&
          other.purgedAt == this.purgedAt);
}

class CompletionEventsCompanion extends UpdateCompanion<CompletionEvent> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> stageId;
  final Value<String> trackType;
  final Value<int?> trackId;
  final Value<int> points;
  final Value<DateTime> eventTimestamp;
  final Value<DateTime> createdAt;
  final Value<DateTime?> purgedAt;
  const CompletionEventsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.stageId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.trackId = const Value.absent(),
    this.points = const Value.absent(),
    this.eventTimestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.purgedAt = const Value.absent(),
  });
  CompletionEventsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    this.trackId = const Value.absent(),
    this.points = const Value.absent(),
    required DateTime eventTimestamp,
    this.createdAt = const Value.absent(),
    this.purgedAt = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       sefariaRef = Value(sefariaRef),
       stageId = Value(stageId),
       trackType = Value(trackType),
       eventTimestamp = Value(eventTimestamp);
  static Insertable<CompletionEvent> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? sefariaRef,
    Expression<int>? stageId,
    Expression<String>? trackType,
    Expression<int>? trackId,
    Expression<int>? points,
    Expression<DateTime>? eventTimestamp,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? purgedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (stageId != null) 'stage_id': stageId,
      if (trackType != null) 'track_type': trackType,
      if (trackId != null) 'track_id': trackId,
      if (points != null) 'points': points,
      if (eventTimestamp != null) 'event_timestamp': eventTimestamp,
      if (createdAt != null) 'created_at': createdAt,
      if (purgedAt != null) 'purged_at': purgedAt,
    });
  }

  CompletionEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? stageId,
    Value<String>? trackType,
    Value<int?>? trackId,
    Value<int>? points,
    Value<DateTime>? eventTimestamp,
    Value<DateTime>? createdAt,
    Value<DateTime?>? purgedAt,
  }) {
    return CompletionEventsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      stageId: stageId ?? this.stageId,
      trackType: trackType ?? this.trackType,
      trackId: trackId ?? this.trackId,
      points: points ?? this.points,
      eventTimestamp: eventTimestamp ?? this.eventTimestamp,
      createdAt: createdAt ?? this.createdAt,
      purgedAt: purgedAt ?? this.purgedAt,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (eventTimestamp.present) {
      map['event_timestamp'] = Variable<DateTime>(eventTimestamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (purgedAt.present) {
      map['purged_at'] = Variable<DateTime>(purgedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionEventsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('trackId: $trackId, ')
          ..write('points: $points, ')
          ..write('eventTimestamp: $eventTimestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('purgedAt: $purgedAt')
          ..write(')'))
        .toString();
  }
}

class $DailyPlansTable extends DailyPlans
    with TableInfo<$DailyPlansTable, DailyPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyPlansTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _planDateMeta = const VerificationMeta(
    'planDate',
  );
  @override
  late final GeneratedColumn<DateTime> planDate = GeneratedColumn<DateTime>(
    'plan_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _stageDefinitionIdMeta = const VerificationMeta(
    'stageDefinitionId',
  );
  @override
  late final GeneratedColumn<int> stageDefinitionId = GeneratedColumn<int>(
    'stage_definition_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackLabelMeta = const VerificationMeta(
    'trackLabel',
  );
  @override
  late final GeneratedColumn<String> trackLabel = GeneratedColumn<String>(
    'track_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isOverdueMeta = const VerificationMeta(
    'isOverdue',
  );
  @override
  late final GeneratedColumn<bool> isOverdue = GeneratedColumn<bool>(
    'is_overdue',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_overdue" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _estimatedEffortMinutesMeta =
      const VerificationMeta('estimatedEffortMinutes');
  @override
  late final GeneratedColumn<int> estimatedEffortMinutes = GeneratedColumn<int>(
    'estimated_effort_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
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
    planDate,
    sefariaRef,
    stageOrder,
    stageDefinitionId,
    trackId,
    trackLabel,
    priority,
    isOverdue,
    reason,
    stageName,
    estimatedEffortMinutes,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyPlan> instance, {
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
    if (data.containsKey('plan_date')) {
      context.handle(
        _planDateMeta,
        planDate.isAcceptableOrUnknown(data['plan_date']!, _planDateMeta),
      );
    } else if (isInserting) {
      context.missing(_planDateMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('stage_order')) {
      context.handle(
        _stageOrderMeta,
        stageOrder.isAcceptableOrUnknown(data['stage_order']!, _stageOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_stageOrderMeta);
    }
    if (data.containsKey('stage_definition_id')) {
      context.handle(
        _stageDefinitionIdMeta,
        stageDefinitionId.isAcceptableOrUnknown(
          data['stage_definition_id']!,
          _stageDefinitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stageDefinitionIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('track_label')) {
      context.handle(
        _trackLabelMeta,
        trackLabel.isAcceptableOrUnknown(data['track_label']!, _trackLabelMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('is_overdue')) {
      context.handle(
        _isOverdueMeta,
        isOverdue.isAcceptableOrUnknown(data['is_overdue']!, _isOverdueMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('stage_name')) {
      context.handle(
        _stageNameMeta,
        stageName.isAcceptableOrUnknown(data['stage_name']!, _stageNameMeta),
      );
    }
    if (data.containsKey('estimated_effort_minutes')) {
      context.handle(
        _estimatedEffortMinutesMeta,
        estimatedEffortMinutes.isAcceptableOrUnknown(
          data['estimated_effort_minutes']!,
          _estimatedEffortMinutesMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, curriculumId, planDate, sefariaRef, stageOrder, trackId},
  ];
  @override
  DailyPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyPlan(
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
      planDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}plan_date'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      stageOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_order'],
      )!,
      stageDefinitionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_definition_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      trackLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_label'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      isOverdue: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_overdue'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      stageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage_name'],
      )!,
      estimatedEffortMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_effort_minutes'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DailyPlansTable createAlias(String alias) {
    return $DailyPlansTable(attachedDatabase, alias);
  }
}

class DailyPlan extends DataClass implements Insertable<DailyPlan> {
  final int id;
  final int profileId;
  final String curriculumId;

  /// Local date (midnight, stored as UTC-normalized midnight of the local day)
  /// that this plan entry belongs to.
  final DateTime planDate;
  final String sefariaRef;
  final int stageOrder;
  final int stageDefinitionId;
  final int trackId;
  final String trackLabel;

  /// Enum name of DailyTaskPriority (e.g., "overdueChazara").
  final String priority;
  final bool isOverdue;
  final String reason;
  final String stageName;
  final int estimatedEffortMinutes;

  /// Position within the day's plan (stable ordering for rendering).
  final int sortOrder;
  final DateTime createdAt;
  const DailyPlan({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.planDate,
    required this.sefariaRef,
    required this.stageOrder,
    required this.stageDefinitionId,
    required this.trackId,
    required this.trackLabel,
    required this.priority,
    required this.isOverdue,
    required this.reason,
    required this.stageName,
    required this.estimatedEffortMinutes,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['plan_date'] = Variable<DateTime>(planDate);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['stage_order'] = Variable<int>(stageOrder);
    map['stage_definition_id'] = Variable<int>(stageDefinitionId);
    map['track_id'] = Variable<int>(trackId);
    map['track_label'] = Variable<String>(trackLabel);
    map['priority'] = Variable<String>(priority);
    map['is_overdue'] = Variable<bool>(isOverdue);
    map['reason'] = Variable<String>(reason);
    map['stage_name'] = Variable<String>(stageName);
    map['estimated_effort_minutes'] = Variable<int>(estimatedEffortMinutes);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DailyPlansCompanion toCompanion(bool nullToAbsent) {
    return DailyPlansCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      planDate: Value(planDate),
      sefariaRef: Value(sefariaRef),
      stageOrder: Value(stageOrder),
      stageDefinitionId: Value(stageDefinitionId),
      trackId: Value(trackId),
      trackLabel: Value(trackLabel),
      priority: Value(priority),
      isOverdue: Value(isOverdue),
      reason: Value(reason),
      stageName: Value(stageName),
      estimatedEffortMinutes: Value(estimatedEffortMinutes),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory DailyPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyPlan(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      planDate: serializer.fromJson<DateTime>(json['planDate']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      stageOrder: serializer.fromJson<int>(json['stageOrder']),
      stageDefinitionId: serializer.fromJson<int>(json['stageDefinitionId']),
      trackId: serializer.fromJson<int>(json['trackId']),
      trackLabel: serializer.fromJson<String>(json['trackLabel']),
      priority: serializer.fromJson<String>(json['priority']),
      isOverdue: serializer.fromJson<bool>(json['isOverdue']),
      reason: serializer.fromJson<String>(json['reason']),
      stageName: serializer.fromJson<String>(json['stageName']),
      estimatedEffortMinutes: serializer.fromJson<int>(
        json['estimatedEffortMinutes'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
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
      'planDate': serializer.toJson<DateTime>(planDate),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'stageOrder': serializer.toJson<int>(stageOrder),
      'stageDefinitionId': serializer.toJson<int>(stageDefinitionId),
      'trackId': serializer.toJson<int>(trackId),
      'trackLabel': serializer.toJson<String>(trackLabel),
      'priority': serializer.toJson<String>(priority),
      'isOverdue': serializer.toJson<bool>(isOverdue),
      'reason': serializer.toJson<String>(reason),
      'stageName': serializer.toJson<String>(stageName),
      'estimatedEffortMinutes': serializer.toJson<int>(estimatedEffortMinutes),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DailyPlan copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    DateTime? planDate,
    String? sefariaRef,
    int? stageOrder,
    int? stageDefinitionId,
    int? trackId,
    String? trackLabel,
    String? priority,
    bool? isOverdue,
    String? reason,
    String? stageName,
    int? estimatedEffortMinutes,
    int? sortOrder,
    DateTime? createdAt,
  }) => DailyPlan(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    planDate: planDate ?? this.planDate,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    stageOrder: stageOrder ?? this.stageOrder,
    stageDefinitionId: stageDefinitionId ?? this.stageDefinitionId,
    trackId: trackId ?? this.trackId,
    trackLabel: trackLabel ?? this.trackLabel,
    priority: priority ?? this.priority,
    isOverdue: isOverdue ?? this.isOverdue,
    reason: reason ?? this.reason,
    stageName: stageName ?? this.stageName,
    estimatedEffortMinutes:
        estimatedEffortMinutes ?? this.estimatedEffortMinutes,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  DailyPlan copyWithCompanion(DailyPlansCompanion data) {
    return DailyPlan(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      planDate: data.planDate.present ? data.planDate.value : this.planDate,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      stageOrder: data.stageOrder.present
          ? data.stageOrder.value
          : this.stageOrder,
      stageDefinitionId: data.stageDefinitionId.present
          ? data.stageDefinitionId.value
          : this.stageDefinitionId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      trackLabel: data.trackLabel.present
          ? data.trackLabel.value
          : this.trackLabel,
      priority: data.priority.present ? data.priority.value : this.priority,
      isOverdue: data.isOverdue.present ? data.isOverdue.value : this.isOverdue,
      reason: data.reason.present ? data.reason.value : this.reason,
      stageName: data.stageName.present ? data.stageName.value : this.stageName,
      estimatedEffortMinutes: data.estimatedEffortMinutes.present
          ? data.estimatedEffortMinutes.value
          : this.estimatedEffortMinutes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyPlan(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('planDate: $planDate, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('stageDefinitionId: $stageDefinitionId, ')
          ..write('trackId: $trackId, ')
          ..write('trackLabel: $trackLabel, ')
          ..write('priority: $priority, ')
          ..write('isOverdue: $isOverdue, ')
          ..write('reason: $reason, ')
          ..write('stageName: $stageName, ')
          ..write('estimatedEffortMinutes: $estimatedEffortMinutes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    planDate,
    sefariaRef,
    stageOrder,
    stageDefinitionId,
    trackId,
    trackLabel,
    priority,
    isOverdue,
    reason,
    stageName,
    estimatedEffortMinutes,
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyPlan &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.planDate == this.planDate &&
          other.sefariaRef == this.sefariaRef &&
          other.stageOrder == this.stageOrder &&
          other.stageDefinitionId == this.stageDefinitionId &&
          other.trackId == this.trackId &&
          other.trackLabel == this.trackLabel &&
          other.priority == this.priority &&
          other.isOverdue == this.isOverdue &&
          other.reason == this.reason &&
          other.stageName == this.stageName &&
          other.estimatedEffortMinutes == this.estimatedEffortMinutes &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class DailyPlansCompanion extends UpdateCompanion<DailyPlan> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<DateTime> planDate;
  final Value<String> sefariaRef;
  final Value<int> stageOrder;
  final Value<int> stageDefinitionId;
  final Value<int> trackId;
  final Value<String> trackLabel;
  final Value<String> priority;
  final Value<bool> isOverdue;
  final Value<String> reason;
  final Value<String> stageName;
  final Value<int> estimatedEffortMinutes;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const DailyPlansCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.planDate = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.stageDefinitionId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.trackLabel = const Value.absent(),
    this.priority = const Value.absent(),
    this.isOverdue = const Value.absent(),
    this.reason = const Value.absent(),
    this.stageName = const Value.absent(),
    this.estimatedEffortMinutes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DailyPlansCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required DateTime planDate,
    required String sefariaRef,
    required int stageOrder,
    required int stageDefinitionId,
    required int trackId,
    this.trackLabel = const Value.absent(),
    required String priority,
    this.isOverdue = const Value.absent(),
    this.reason = const Value.absent(),
    this.stageName = const Value.absent(),
    this.estimatedEffortMinutes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       planDate = Value(planDate),
       sefariaRef = Value(sefariaRef),
       stageOrder = Value(stageOrder),
       stageDefinitionId = Value(stageDefinitionId),
       trackId = Value(trackId),
       priority = Value(priority),
       createdAt = Value(createdAt);
  static Insertable<DailyPlan> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<DateTime>? planDate,
    Expression<String>? sefariaRef,
    Expression<int>? stageOrder,
    Expression<int>? stageDefinitionId,
    Expression<int>? trackId,
    Expression<String>? trackLabel,
    Expression<String>? priority,
    Expression<bool>? isOverdue,
    Expression<String>? reason,
    Expression<String>? stageName,
    Expression<int>? estimatedEffortMinutes,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (planDate != null) 'plan_date': planDate,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (stageDefinitionId != null) 'stage_definition_id': stageDefinitionId,
      if (trackId != null) 'track_id': trackId,
      if (trackLabel != null) 'track_label': trackLabel,
      if (priority != null) 'priority': priority,
      if (isOverdue != null) 'is_overdue': isOverdue,
      if (reason != null) 'reason': reason,
      if (stageName != null) 'stage_name': stageName,
      if (estimatedEffortMinutes != null)
        'estimated_effort_minutes': estimatedEffortMinutes,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DailyPlansCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<DateTime>? planDate,
    Value<String>? sefariaRef,
    Value<int>? stageOrder,
    Value<int>? stageDefinitionId,
    Value<int>? trackId,
    Value<String>? trackLabel,
    Value<String>? priority,
    Value<bool>? isOverdue,
    Value<String>? reason,
    Value<String>? stageName,
    Value<int>? estimatedEffortMinutes,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return DailyPlansCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      planDate: planDate ?? this.planDate,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      stageOrder: stageOrder ?? this.stageOrder,
      stageDefinitionId: stageDefinitionId ?? this.stageDefinitionId,
      trackId: trackId ?? this.trackId,
      trackLabel: trackLabel ?? this.trackLabel,
      priority: priority ?? this.priority,
      isOverdue: isOverdue ?? this.isOverdue,
      reason: reason ?? this.reason,
      stageName: stageName ?? this.stageName,
      estimatedEffortMinutes:
          estimatedEffortMinutes ?? this.estimatedEffortMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (planDate.present) {
      map['plan_date'] = Variable<DateTime>(planDate.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (stageOrder.present) {
      map['stage_order'] = Variable<int>(stageOrder.value);
    }
    if (stageDefinitionId.present) {
      map['stage_definition_id'] = Variable<int>(stageDefinitionId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (trackLabel.present) {
      map['track_label'] = Variable<String>(trackLabel.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (isOverdue.present) {
      map['is_overdue'] = Variable<bool>(isOverdue.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (stageName.present) {
      map['stage_name'] = Variable<String>(stageName.value);
    }
    if (estimatedEffortMinutes.present) {
      map['estimated_effort_minutes'] = Variable<int>(
        estimatedEffortMinutes.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyPlansCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('planDate: $planDate, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageOrder: $stageOrder, ')
          ..write('stageDefinitionId: $stageDefinitionId, ')
          ..write('trackId: $trackId, ')
          ..write('trackLabel: $trackLabel, ')
          ..write('priority: $priority, ')
          ..write('isOverdue: $isOverdue, ')
          ..write('reason: $reason, ')
          ..write('stageName: $stageName, ')
          ..write('estimatedEffortMinutes: $estimatedEffortMinutes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ulidMeta = const VerificationMeta('ulid');
  @override
  late final GeneratedColumn<String> ulid = GeneratedColumn<String>(
    'ulid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newUlid,
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
  static const VerificationMeta _entryScopeMeta = const VerificationMeta(
    'entryScope',
  );
  @override
  late final GeneratedColumn<String> entryScope = GeneratedColumn<String>(
    'entry_scope',
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id) ON DELETE SET NULL',
    ),
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
    ulid,
    curriculumId,
    entryScope,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('ulid')) {
      context.handle(
        _ulidMeta,
        ulid.isAcceptableOrUnknown(data['ulid']!, _ulidMeta),
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
    if (data.containsKey('entry_scope')) {
      context.handle(
        _entryScopeMeta,
        entryScope.isAcceptableOrUnknown(data['entry_scope']!, _entryScopeMeta),
      );
    } else if (isInserting) {
      context.missing(_entryScopeMeta);
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
      ulid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ulid'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      entryScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_scope'],
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;

  /// ULID identifying the logical ledger entry across devices. Two devices
  /// writing the same entry use the same ULID so the UNIQUE composite
  /// `(profileId, ulid)` collapses duplicates. Auto-generated client-side
  /// when omitted on insert.
  final String ulid;
  final String curriculumId;

  /// Scope of the learning ledger entry: 'seder', 'masechta', 'sefer'.
  final String entryScope;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;

  /// Nullable FK. ON DELETE SET NULL so ledger entries survive track deletion
  /// (purgeHistory hard-deletes the track row but ledger rows are append-only).
  final int? trackId;
  final DateTime completedAt;
  final int completionNumber;
  final int markedBy;
  final bool isManual;
  final DateTime createdAt;
  const LearningLedgerData({
    required this.id,
    required this.profileId,
    required this.ulid,
    required this.curriculumId,
    required this.entryScope,
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
    map['ulid'] = Variable<String>(ulid);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['entry_scope'] = Variable<String>(entryScope);
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
      ulid: Value(ulid),
      curriculumId: Value(curriculumId),
      entryScope: Value(entryScope),
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
      ulid: serializer.fromJson<String>(json['ulid']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      entryScope: serializer.fromJson<String>(json['entryScope']),
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
      'ulid': serializer.toJson<String>(ulid),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'entryScope': serializer.toJson<String>(entryScope),
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
    String? ulid,
    String? curriculumId,
    String? entryScope,
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
    ulid: ulid ?? this.ulid,
    curriculumId: curriculumId ?? this.curriculumId,
    entryScope: entryScope ?? this.entryScope,
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
      ulid: data.ulid.present ? data.ulid.value : this.ulid,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      entryScope: data.entryScope.present
          ? data.entryScope.value
          : this.entryScope,
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
          ..write('ulid: $ulid, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('entryScope: $entryScope, ')
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
    ulid,
    curriculumId,
    entryScope,
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
          other.ulid == this.ulid &&
          other.curriculumId == this.curriculumId &&
          other.entryScope == this.entryScope &&
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
  final Value<String> ulid;
  final Value<String> curriculumId;
  final Value<String> entryScope;
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
    this.ulid = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.entryScope = const Value.absent(),
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
    required int profileId,
    this.ulid = const Value.absent(),
    required String curriculumId,
    required String entryScope,
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
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       entryScope = Value(entryScope),
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
    Expression<String>? ulid,
    Expression<String>? curriculumId,
    Expression<String>? entryScope,
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
      if (ulid != null) 'ulid': ulid,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (entryScope != null) 'entry_scope': entryScope,
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
    Value<String>? ulid,
    Value<String>? curriculumId,
    Value<String>? entryScope,
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
      ulid: ulid ?? this.ulid,
      curriculumId: curriculumId ?? this.curriculumId,
      entryScope: entryScope ?? this.entryScope,
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
    if (ulid.present) {
      map['ulid'] = Variable<String>(ulid.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (entryScope.present) {
      map['entry_scope'] = Variable<String>(entryScope.value);
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
          ..write('ulid: $ulid, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('entryScope: $entryScope, ')
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id) ON DELETE CASCADE',
    ),
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
    trackId,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
    {profileId, curriculumId, trackId},
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;

  /// FK to curriculum_tracks.id. ON DELETE CASCADE so bookmarks are removed
  /// when a track is hard-deleted (purgeHistory), preserving referential
  /// integrity after PRAGMA foreign_keys = ON is enabled in C2.
  final int trackId;
  final String sefariaRef;
  final DateTime updatedAt;
  const Bookmark({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.sefariaRef,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_id'] = Variable<int>(trackId);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackId: Value(trackId),
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
      trackId: serializer.fromJson<int>(json['trackId']),
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
      'trackId': serializer.toJson<int>(trackId),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bookmark copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? trackId,
    String? sefariaRef,
    DateTime? updatedAt,
  }) => Bookmark(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
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
          ..write('trackId: $trackId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, curriculumId, trackId, sefariaRef, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackId == this.trackId &&
          other.sefariaRef == this.sefariaRef &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<String> sefariaRef;
  final Value<DateTime> updatedAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required int trackId,
    required String sefariaRef,
    required DateTime updatedAt,
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       sefariaRef = Value(sefariaRef),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
    Expression<String>? sefariaRef,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? trackId,
    Value<String>? sefariaRef,
    Value<DateTime>? updatedAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
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
          ..write('trackId: $trackId, ')
          ..write('sefariaRef: $sefariaRef, ')
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _learningOrderVersionMeta =
      const VerificationMeta('learningOrderVersion');
  @override
  late final GeneratedColumn<int> learningOrderVersion = GeneratedColumn<int>(
    'learning_order_version',
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
    curriculumId,
    sefariaRef,
    userSortOrder,
    updatedAt,
    learningOrderVersion,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('learning_order_version')) {
      context.handle(
        _learningOrderVersionMeta,
        learningOrderVersion.isAcceptableOrUnknown(
          data['learning_order_version']!,
          _learningOrderVersionMeta,
        ),
      );
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      learningOrderVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}learning_order_version'],
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

  /// W3.25: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int userSortOrder;
  final DateTime updatedAt;

  /// The content-DB seed version ([SeedMetadata.version]) against which this
  /// order was last saved.
  ///
  /// Default 1 is safe for existing rows: if the current seed version exceeds
  /// the saved version the order is considered stale and the projection is
  /// re-amnestied (last_reorder_at set to nowUtc) so overdue tasks reset.
  /// See §10.1 of the architecture spec.
  final int learningOrderVersion;
  const LearningOrderData({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.userSortOrder,
    required this.updatedAt,
    required this.learningOrderVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['user_sort_order'] = Variable<int>(userSortOrder);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['learning_order_version'] = Variable<int>(learningOrderVersion);
    return map;
  }

  LearningOrderCompanion toCompanion(bool nullToAbsent) {
    return LearningOrderCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      sefariaRef: Value(sefariaRef),
      userSortOrder: Value(userSortOrder),
      updatedAt: Value(updatedAt),
      learningOrderVersion: Value(learningOrderVersion),
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
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      learningOrderVersion: serializer.fromJson<int>(
        json['learningOrderVersion'],
      ),
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
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'learningOrderVersion': serializer.toJson<int>(learningOrderVersion),
    };
  }

  LearningOrderData copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? userSortOrder,
    DateTime? updatedAt,
    int? learningOrderVersion,
  }) => LearningOrderData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    userSortOrder: userSortOrder ?? this.userSortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    learningOrderVersion: learningOrderVersion ?? this.learningOrderVersion,
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
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      learningOrderVersion: data.learningOrderVersion.present
          ? data.learningOrderVersion.value
          : this.learningOrderVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningOrderData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('userSortOrder: $userSortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('learningOrderVersion: $learningOrderVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    sefariaRef,
    userSortOrder,
    updatedAt,
    learningOrderVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningOrderData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.sefariaRef == this.sefariaRef &&
          other.userSortOrder == this.userSortOrder &&
          other.updatedAt == this.updatedAt &&
          other.learningOrderVersion == this.learningOrderVersion);
}

class LearningOrderCompanion extends UpdateCompanion<LearningOrderData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> userSortOrder;
  final Value<DateTime> updatedAt;
  final Value<int> learningOrderVersion;
  const LearningOrderCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.userSortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.learningOrderVersion = const Value.absent(),
  });
  LearningOrderCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int userSortOrder,
    this.updatedAt = const Value.absent(),
    this.learningOrderVersion = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       sefariaRef = Value(sefariaRef),
       userSortOrder = Value(userSortOrder);
  static Insertable<LearningOrderData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? sefariaRef,
    Expression<int>? userSortOrder,
    Expression<DateTime>? updatedAt,
    Expression<int>? learningOrderVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (userSortOrder != null) 'user_sort_order': userSortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (learningOrderVersion != null)
        'learning_order_version': learningOrderVersion,
    });
  }

  LearningOrderCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? userSortOrder,
    Value<DateTime>? updatedAt,
    Value<int>? learningOrderVersion,
  }) {
    return LearningOrderCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      userSortOrder: userSortOrder ?? this.userSortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      learningOrderVersion: learningOrderVersion ?? this.learningOrderVersion,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (learningOrderVersion.present) {
      map['learning_order_version'] = Variable<int>(learningOrderVersion.value);
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
          ..write('userSortOrder: $userSortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('learningOrderVersion: $learningOrderVersion')
          ..write(')'))
        .toString();
  }
}

class $TrackLearningOrderTable extends TrackLearningOrder
    with TableInfo<$TrackLearningOrderTable, TrackLearningOrderData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackLearningOrderTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, trackId, sefariaRef, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_learning_order';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackLearningOrderData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trackId, sefariaRef},
  ];
  @override
  TrackLearningOrderData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackLearningOrderData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TrackLearningOrderTable createAlias(String alias) {
    return $TrackLearningOrderTable(attachedDatabase, alias);
  }
}

class TrackLearningOrderData extends DataClass
    implements Insertable<TrackLearningOrderData> {
  final int id;
  final int trackId;
  final String sefariaRef;
  final int sortOrder;
  const TrackLearningOrderData({
    required this.id,
    required this.trackId,
    required this.sefariaRef,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TrackLearningOrderCompanion toCompanion(bool nullToAbsent) {
    return TrackLearningOrderCompanion(
      id: Value(id),
      trackId: Value(trackId),
      sefariaRef: Value(sefariaRef),
      sortOrder: Value(sortOrder),
    );
  }

  factory TrackLearningOrderData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackLearningOrderData(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TrackLearningOrderData copyWith({
    int? id,
    int? trackId,
    String? sefariaRef,
    int? sortOrder,
  }) => TrackLearningOrderData(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  TrackLearningOrderData copyWithCompanion(TrackLearningOrderCompanion data) {
    return TrackLearningOrderData(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackLearningOrderData(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackId, sefariaRef, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackLearningOrderData &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.sefariaRef == this.sefariaRef &&
          other.sortOrder == this.sortOrder);
}

class TrackLearningOrderCompanion
    extends UpdateCompanion<TrackLearningOrderData> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<String> sefariaRef;
  final Value<int> sortOrder;
  const TrackLearningOrderCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  TrackLearningOrderCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required String sefariaRef,
    required int sortOrder,
  }) : trackId = Value(trackId),
       sefariaRef = Value(sefariaRef),
       sortOrder = Value(sortOrder);
  static Insertable<TrackLearningOrderData> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<String>? sefariaRef,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  TrackLearningOrderCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<String>? sefariaRef,
    Value<int>? sortOrder,
  }) {
    return TrackLearningOrderCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackLearningOrderCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('sortOrder: $sortOrder')
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id)',
    ),
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
  static const VerificationMeta _pacePeriodMeta = const VerificationMeta(
    'pacePeriod',
  );
  @override
  late final GeneratedColumn<String> pacePeriod = GeneratedColumn<String>(
    'pace_period',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paceGranularityMeta = const VerificationMeta(
    'paceGranularity',
  );
  @override
  late final GeneratedColumn<String> paceGranularity = GeneratedColumn<String>(
    'pace_granularity',
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
    trackId,
    targetPercent,
    targetDate,
    description,
    dateType,
    goalType,
    paceValue,
    pacePeriod,
    paceGranularity,
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
    if (data.containsKey('pace_period')) {
      context.handle(
        _pacePeriodMeta,
        pacePeriod.isAcceptableOrUnknown(data['pace_period']!, _pacePeriodMeta),
      );
    }
    if (data.containsKey('pace_granularity')) {
      context.handle(
        _paceGranularityMeta,
        paceGranularity.isAcceptableOrUnknown(
          data['pace_granularity']!,
          _paceGranularityMeta,
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
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
      pacePeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace_period'],
      ),
      paceGranularity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace_granularity'],
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final int trackId;
  final double targetPercent;
  final DateTime? targetDate;
  final String description;
  final String dateType;
  final String goalType;
  final int? paceValue;

  /// Pace period unit: 'day', 'week', 'month', or null.
  final String? pacePeriod;

  /// Learning unit: 'amud', 'daf', or null. Used for Bavli/Yerushalmi curricula.
  final String? paceGranularity;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Goal({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.targetPercent,
    this.targetDate,
    required this.description,
    required this.dateType,
    required this.goalType,
    this.paceValue,
    this.pacePeriod,
    this.paceGranularity,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_id'] = Variable<int>(trackId);
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
    if (!nullToAbsent || pacePeriod != null) {
      map['pace_period'] = Variable<String>(pacePeriod);
    }
    if (!nullToAbsent || paceGranularity != null) {
      map['pace_granularity'] = Variable<String>(paceGranularity);
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
      trackId: Value(trackId),
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
      pacePeriod: pacePeriod == null && nullToAbsent
          ? const Value.absent()
          : Value(pacePeriod),
      paceGranularity: paceGranularity == null && nullToAbsent
          ? const Value.absent()
          : Value(paceGranularity),
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
      trackId: serializer.fromJson<int>(json['trackId']),
      targetPercent: serializer.fromJson<double>(json['targetPercent']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      description: serializer.fromJson<String>(json['description']),
      dateType: serializer.fromJson<String>(json['dateType']),
      goalType: serializer.fromJson<String>(json['goalType']),
      paceValue: serializer.fromJson<int?>(json['paceValue']),
      pacePeriod: serializer.fromJson<String?>(json['pacePeriod']),
      paceGranularity: serializer.fromJson<String?>(json['paceGranularity']),
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
      'trackId': serializer.toJson<int>(trackId),
      'targetPercent': serializer.toJson<double>(targetPercent),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'description': serializer.toJson<String>(description),
      'dateType': serializer.toJson<String>(dateType),
      'goalType': serializer.toJson<String>(goalType),
      'paceValue': serializer.toJson<int?>(paceValue),
      'pacePeriod': serializer.toJson<String?>(pacePeriod),
      'paceGranularity': serializer.toJson<String?>(paceGranularity),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Goal copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    int? trackId,
    double? targetPercent,
    Value<DateTime?> targetDate = const Value.absent(),
    String? description,
    String? dateType,
    String? goalType,
    Value<int?> paceValue = const Value.absent(),
    Value<String?> pacePeriod = const Value.absent(),
    Value<String?> paceGranularity = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Goal(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
    targetPercent: targetPercent ?? this.targetPercent,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    description: description ?? this.description,
    dateType: dateType ?? this.dateType,
    goalType: goalType ?? this.goalType,
    paceValue: paceValue.present ? paceValue.value : this.paceValue,
    pacePeriod: pacePeriod.present ? pacePeriod.value : this.pacePeriod,
    paceGranularity: paceGranularity.present
        ? paceGranularity.value
        : this.paceGranularity,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
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
      pacePeriod: data.pacePeriod.present
          ? data.pacePeriod.value
          : this.pacePeriod,
      paceGranularity: data.paceGranularity.present
          ? data.paceGranularity.value
          : this.paceGranularity,
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
          ..write('trackId: $trackId, ')
          ..write('targetPercent: $targetPercent, ')
          ..write('targetDate: $targetDate, ')
          ..write('description: $description, ')
          ..write('dateType: $dateType, ')
          ..write('goalType: $goalType, ')
          ..write('paceValue: $paceValue, ')
          ..write('pacePeriod: $pacePeriod, ')
          ..write('paceGranularity: $paceGranularity, ')
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
    trackId,
    targetPercent,
    targetDate,
    description,
    dateType,
    goalType,
    paceValue,
    pacePeriod,
    paceGranularity,
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
          other.trackId == this.trackId &&
          other.targetPercent == this.targetPercent &&
          other.targetDate == this.targetDate &&
          other.description == this.description &&
          other.dateType == this.dateType &&
          other.goalType == this.goalType &&
          other.paceValue == this.paceValue &&
          other.pacePeriod == this.pacePeriod &&
          other.paceGranularity == this.paceGranularity &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<double> targetPercent;
  final Value<DateTime?> targetDate;
  final Value<String> description;
  final Value<String> dateType;
  final Value<String> goalType;
  final Value<int?> paceValue;
  final Value<String?> pacePeriod;
  final Value<String?> paceGranularity;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.targetPercent = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.description = const Value.absent(),
    this.dateType = const Value.absent(),
    this.goalType = const Value.absent(),
    this.paceValue = const Value.absent(),
    this.pacePeriod = const Value.absent(),
    this.paceGranularity = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required int trackId,
    this.targetPercent = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.description = const Value.absent(),
    this.dateType = const Value.absent(),
    this.goalType = const Value.absent(),
    this.paceValue = const Value.absent(),
    this.pacePeriod = const Value.absent(),
    this.paceGranularity = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Goal> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
    Expression<double>? targetPercent,
    Expression<DateTime>? targetDate,
    Expression<String>? description,
    Expression<String>? dateType,
    Expression<String>? goalType,
    Expression<int>? paceValue,
    Expression<String>? pacePeriod,
    Expression<String>? paceGranularity,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (targetPercent != null) 'target_percent': targetPercent,
      if (targetDate != null) 'target_date': targetDate,
      if (description != null) 'description': description,
      if (dateType != null) 'date_type': dateType,
      if (goalType != null) 'goal_type': goalType,
      if (paceValue != null) 'pace_value': paceValue,
      if (pacePeriod != null) 'pace_period': pacePeriod,
      if (paceGranularity != null) 'pace_granularity': paceGranularity,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GoalsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<int>? trackId,
    Value<double>? targetPercent,
    Value<DateTime?>? targetDate,
    Value<String>? description,
    Value<String>? dateType,
    Value<String>? goalType,
    Value<int?>? paceValue,
    Value<String?>? pacePeriod,
    Value<String?>? paceGranularity,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
      targetPercent: targetPercent ?? this.targetPercent,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
      dateType: dateType ?? this.dateType,
      goalType: goalType ?? this.goalType,
      paceValue: paceValue ?? this.paceValue,
      pacePeriod: pacePeriod ?? this.pacePeriod,
      paceGranularity: paceGranularity ?? this.paceGranularity,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
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
    if (pacePeriod.present) {
      map['pace_period'] = Variable<String>(pacePeriod.value);
    }
    if (paceGranularity.present) {
      map['pace_granularity'] = Variable<String>(paceGranularity.value);
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
          ..write('trackId: $trackId, ')
          ..write('targetPercent: $targetPercent, ')
          ..write('targetDate: $targetDate, ')
          ..write('description: $description, ')
          ..write('dateType: $dateType, ')
          ..write('goalType: $goalType, ')
          ..write('paceValue: $paceValue, ')
          ..write('pacePeriod: $pacePeriod, ')
          ..write('paceGranularity: $paceGranularity, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $StreakEventsTable extends StreakEvents
    with TableInfo<$StreakEventsTable, StreakEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakEventsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayUtcMeta = const VerificationMeta('dayUtc');
  @override
  late final GeneratedColumn<DateTime> dayUtc = GeneratedColumn<DateTime>(
    'day_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTimestampMeta = const VerificationMeta(
    'eventTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> eventTimestamp =
      GeneratedColumn<DateTime>(
        'event_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _clientDeviceIdMeta = const VerificationMeta(
    'clientDeviceId',
  );
  @override
  late final GeneratedColumn<String> clientDeviceId = GeneratedColumn<String>(
    'client_device_id',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    eventType,
    dayUtc,
    eventTimestamp,
    clientDeviceId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<StreakEvent> instance, {
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
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('day_utc')) {
      context.handle(
        _dayUtcMeta,
        dayUtc.isAcceptableOrUnknown(data['day_utc']!, _dayUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_dayUtcMeta);
    }
    if (data.containsKey('event_timestamp')) {
      context.handle(
        _eventTimestampMeta,
        eventTimestamp.isAcceptableOrUnknown(
          data['event_timestamp']!,
          _eventTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eventTimestampMeta);
    }
    if (data.containsKey('client_device_id')) {
      context.handle(
        _clientDeviceIdMeta,
        clientDeviceId.isAcceptableOrUnknown(
          data['client_device_id']!,
          _clientDeviceIdMeta,
        ),
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
  StreakEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      dayUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day_utc'],
      )!,
      eventTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_timestamp'],
      )!,
      clientDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_device_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StreakEventsTable createAlias(String alias) {
    return $StreakEventsTable(attachedDatabase, alias);
  }
}

class StreakEvent extends DataClass implements Insertable<StreakEvent> {
  final int id;

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;

  /// `completion` | `day_boundary` | `manual_adjust`
  final String eventType;

  /// UTC date this event belongs to, normalised to midnight. Used as part
  /// of the natural-key dedup key — two completions on the same UTC day for
  /// the same profile collapse to one row.
  final DateTime dayUtc;

  /// UTC timestamp of the real-world moment the event occurred.
  /// Used for ordering inside a single day.
  final DateTime eventTimestamp;

  /// Optional device hint for diagnostics. No security bearing.
  final String? clientDeviceId;
  final DateTime createdAt;
  const StreakEvent({
    required this.id,
    required this.profileId,
    required this.eventType,
    required this.dayUtc,
    required this.eventTimestamp,
    this.clientDeviceId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['event_type'] = Variable<String>(eventType);
    map['day_utc'] = Variable<DateTime>(dayUtc);
    map['event_timestamp'] = Variable<DateTime>(eventTimestamp);
    if (!nullToAbsent || clientDeviceId != null) {
      map['client_device_id'] = Variable<String>(clientDeviceId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StreakEventsCompanion toCompanion(bool nullToAbsent) {
    return StreakEventsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      eventType: Value(eventType),
      dayUtc: Value(dayUtc),
      eventTimestamp: Value(eventTimestamp),
      clientDeviceId: clientDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientDeviceId),
      createdAt: Value(createdAt),
    );
  }

  factory StreakEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakEvent(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      dayUtc: serializer.fromJson<DateTime>(json['dayUtc']),
      eventTimestamp: serializer.fromJson<DateTime>(json['eventTimestamp']),
      clientDeviceId: serializer.fromJson<String?>(json['clientDeviceId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'eventType': serializer.toJson<String>(eventType),
      'dayUtc': serializer.toJson<DateTime>(dayUtc),
      'eventTimestamp': serializer.toJson<DateTime>(eventTimestamp),
      'clientDeviceId': serializer.toJson<String?>(clientDeviceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StreakEvent copyWith({
    int? id,
    int? profileId,
    String? eventType,
    DateTime? dayUtc,
    DateTime? eventTimestamp,
    Value<String?> clientDeviceId = const Value.absent(),
    DateTime? createdAt,
  }) => StreakEvent(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    eventType: eventType ?? this.eventType,
    dayUtc: dayUtc ?? this.dayUtc,
    eventTimestamp: eventTimestamp ?? this.eventTimestamp,
    clientDeviceId: clientDeviceId.present
        ? clientDeviceId.value
        : this.clientDeviceId,
    createdAt: createdAt ?? this.createdAt,
  );
  StreakEvent copyWithCompanion(StreakEventsCompanion data) {
    return StreakEvent(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      dayUtc: data.dayUtc.present ? data.dayUtc.value : this.dayUtc,
      eventTimestamp: data.eventTimestamp.present
          ? data.eventTimestamp.value
          : this.eventTimestamp,
      clientDeviceId: data.clientDeviceId.present
          ? data.clientDeviceId.value
          : this.clientDeviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakEvent(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('eventType: $eventType, ')
          ..write('dayUtc: $dayUtc, ')
          ..write('eventTimestamp: $eventTimestamp, ')
          ..write('clientDeviceId: $clientDeviceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    eventType,
    dayUtc,
    eventTimestamp,
    clientDeviceId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakEvent &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.eventType == this.eventType &&
          other.dayUtc == this.dayUtc &&
          other.eventTimestamp == this.eventTimestamp &&
          other.clientDeviceId == this.clientDeviceId &&
          other.createdAt == this.createdAt);
}

class StreakEventsCompanion extends UpdateCompanion<StreakEvent> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> eventType;
  final Value<DateTime> dayUtc;
  final Value<DateTime> eventTimestamp;
  final Value<String?> clientDeviceId;
  final Value<DateTime> createdAt;
  const StreakEventsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.dayUtc = const Value.absent(),
    this.eventTimestamp = const Value.absent(),
    this.clientDeviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StreakEventsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String eventType,
    required DateTime dayUtc,
    required DateTime eventTimestamp,
    this.clientDeviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : profileId = Value(profileId),
       eventType = Value(eventType),
       dayUtc = Value(dayUtc),
       eventTimestamp = Value(eventTimestamp);
  static Insertable<StreakEvent> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? eventType,
    Expression<DateTime>? dayUtc,
    Expression<DateTime>? eventTimestamp,
    Expression<String>? clientDeviceId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (eventType != null) 'event_type': eventType,
      if (dayUtc != null) 'day_utc': dayUtc,
      if (eventTimestamp != null) 'event_timestamp': eventTimestamp,
      if (clientDeviceId != null) 'client_device_id': clientDeviceId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StreakEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? eventType,
    Value<DateTime>? dayUtc,
    Value<DateTime>? eventTimestamp,
    Value<String?>? clientDeviceId,
    Value<DateTime>? createdAt,
  }) {
    return StreakEventsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      eventType: eventType ?? this.eventType,
      dayUtc: dayUtc ?? this.dayUtc,
      eventTimestamp: eventTimestamp ?? this.eventTimestamp,
      clientDeviceId: clientDeviceId ?? this.clientDeviceId,
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
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (dayUtc.present) {
      map['day_utc'] = Variable<DateTime>(dayUtc.value);
    }
    if (eventTimestamp.present) {
      map['event_timestamp'] = Variable<DateTime>(eventTimestamp.value);
    }
    if (clientDeviceId.present) {
      map['client_device_id'] = Variable<String>(clientDeviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakEventsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('eventType: $eventType, ')
          ..write('dayUtc: $dayUtc, ')
          ..write('eventTimestamp: $eventTimestamp, ')
          ..write('clientDeviceId: $clientDeviceId, ')
          ..write('createdAt: $createdAt')
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

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityKindMeta = const VerificationMeta(
    'entityKind',
  );
  @override
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
    'entity_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityKeyMeta = const VerificationMeta(
    'entityKey',
  );
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'entity_key',
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
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
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
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    entityKind,
    entityKey,
    payload,
    createdAt,
    attempts,
    lastError,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
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
    if (data.containsKey('entity_kind')) {
      context.handle(
        _entityKindMeta,
        entityKind.isAcceptableOrUnknown(data['entity_kind']!, _entityKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKindMeta);
    }
    if (data.containsKey('entity_key')) {
      context.handle(
        _entityKeyMeta,
        entityKey.isAcceptableOrUnknown(data['entity_key']!, _entityKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      entityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_kind'],
      )!,
      entityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  /// Auto-increment primary key.
  final int id;

  /// Profile that owns this mutation.
  final int profileId;

  /// Logical entity kind, e.g. `completion`, `streak`, `settings`, `track`.
  /// Used by OutboxProcessor to route to the correct PushPipeline method.
  final String entityKind;

  /// Stable business key for the entity (used for idempotency on re-push).
  final String entityKey;

  /// JSON-encoded mutation payload.
  final String payload;

  /// When this row was written (UTC).
  final DateTime createdAt;

  /// Number of push attempts made so far.
  final int attempts;

  /// Last error message, if any push attempt failed.
  final String? lastError;

  /// Timestamp of the last push attempt (UTC).
  final DateTime? lastAttemptAt;
  const OutboxData({
    required this.id,
    required this.profileId,
    required this.entityKind,
    required this.entityKey,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['entity_kind'] = Variable<String>(entityKind);
    map['entity_key'] = Variable<String>(entityKey);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      profileId: Value(profileId),
      entityKind: Value(entityKind),
      entityKey: Value(entityKey),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      entityKind: serializer.fromJson<String>(json['entityKind']),
      entityKey: serializer.fromJson<String>(json['entityKey']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'entityKind': serializer.toJson<String>(entityKind),
      'entityKey': serializer.toJson<String>(entityKey),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  OutboxData copyWith({
    int? id,
    int? profileId,
    String? entityKind,
    String? entityKey,
    String? payload,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => OutboxData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    entityKind: entityKind ?? this.entityKind,
    entityKey: entityKey ?? this.entityKey,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      entityKind: data.entityKind.present
          ? data.entityKind.value
          : this.entityKind,
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityKey: $entityKey, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    entityKind,
    entityKey,
    payload,
    createdAt,
    attempts,
    lastError,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.entityKind == this.entityKind &&
          other.entityKey == this.entityKey &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> entityKind;
  final Value<String> entityKey;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime?> lastAttemptAt;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String entityKind,
    required String entityKey,
    required String payload,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
  }) : profileId = Value(profileId),
       entityKind = Value(entityKind),
       entityKey = Value(entityKey),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? entityKind,
    Expression<String>? entityKey,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? lastAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (entityKind != null) 'entity_kind': entityKind,
      if (entityKey != null) 'entity_key': entityKey,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? entityKind,
    Value<String>? entityKey,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime?>? lastAttemptAt,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      entityKind: entityKind ?? this.entityKind,
      entityKey: entityKey ?? this.entityKey,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
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
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityKey: $entityKey, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }
}

class $SacredWindowEntriesTable extends SacredWindowEntries
    with TableInfo<$SacredWindowEntriesTable, SacredWindowEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SacredWindowEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startUtc = GeneratedColumn<DateTime>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtcMeta = const VerificationMeta('endUtc');
  @override
  late final GeneratedColumn<DateTime> endUtc = GeneratedColumn<DateTime>(
    'end_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inIsraelMeta = const VerificationMeta(
    'inIsrael',
  );
  @override
  late final GeneratedColumn<bool> inIsrael = GeneratedColumn<bool>(
    'in_israel',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_israel" IN (0, 1))',
    ),
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
    startUtc,
    endUtc,
    kind,
    lat,
    lng,
    inIsrael,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sacred_window_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SacredWindowEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('end_utc')) {
      context.handle(
        _endUtcMeta,
        endUtc.isAcceptableOrUnknown(data['end_utc']!, _endUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_endUtcMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('in_israel')) {
      context.handle(
        _inIsraelMeta,
        inIsrael.isAcceptableOrUnknown(data['in_israel']!, _inIsraelMeta),
      );
    } else if (isInserting) {
      context.missing(_inIsraelMeta);
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
  SacredWindowEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SacredWindowEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_utc'],
      )!,
      endUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_utc'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      inIsrael: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_israel'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SacredWindowEntriesTable createAlias(String alias) {
    return $SacredWindowEntriesTable(attachedDatabase, alias);
  }
}

class SacredWindowEntry extends DataClass
    implements Insertable<SacredWindowEntry> {
  final int id;
  final DateTime startUtc;
  final DateTime endUtc;

  /// 'shabbos' | 'yomTov' | 'shabbosYomTov' | 'yomKippur'
  final String kind;

  /// Device latitude — null when coordinates are not available.
  final double? lat;

  /// Device longitude — null when coordinates are not available.
  final double? lng;
  final bool inIsrael;
  final DateTime createdAt;
  const SacredWindowEntry({
    required this.id,
    required this.startUtc,
    required this.endUtc,
    required this.kind,
    this.lat,
    this.lng,
    required this.inIsrael,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_utc'] = Variable<DateTime>(startUtc);
    map['end_utc'] = Variable<DateTime>(endUtc);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    map['in_israel'] = Variable<bool>(inIsrael);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SacredWindowEntriesCompanion toCompanion(bool nullToAbsent) {
    return SacredWindowEntriesCompanion(
      id: Value(id),
      startUtc: Value(startUtc),
      endUtc: Value(endUtc),
      kind: Value(kind),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      inIsrael: Value(inIsrael),
      createdAt: Value(createdAt),
    );
  }

  factory SacredWindowEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SacredWindowEntry(
      id: serializer.fromJson<int>(json['id']),
      startUtc: serializer.fromJson<DateTime>(json['startUtc']),
      endUtc: serializer.fromJson<DateTime>(json['endUtc']),
      kind: serializer.fromJson<String>(json['kind']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      inIsrael: serializer.fromJson<bool>(json['inIsrael']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startUtc': serializer.toJson<DateTime>(startUtc),
      'endUtc': serializer.toJson<DateTime>(endUtc),
      'kind': serializer.toJson<String>(kind),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'inIsrael': serializer.toJson<bool>(inIsrael),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SacredWindowEntry copyWith({
    int? id,
    DateTime? startUtc,
    DateTime? endUtc,
    String? kind,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    bool? inIsrael,
    DateTime? createdAt,
  }) => SacredWindowEntry(
    id: id ?? this.id,
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc ?? this.endUtc,
    kind: kind ?? this.kind,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    inIsrael: inIsrael ?? this.inIsrael,
    createdAt: createdAt ?? this.createdAt,
  );
  SacredWindowEntry copyWithCompanion(SacredWindowEntriesCompanion data) {
    return SacredWindowEntry(
      id: data.id.present ? data.id.value : this.id,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      endUtc: data.endUtc.present ? data.endUtc.value : this.endUtc,
      kind: data.kind.present ? data.kind.value : this.kind,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      inIsrael: data.inIsrael.present ? data.inIsrael.value : this.inIsrael,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SacredWindowEntry(')
          ..write('id: $id, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('kind: $kind, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('inIsrael: $inIsrael, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startUtc, endUtc, kind, lat, lng, inIsrael, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SacredWindowEntry &&
          other.id == this.id &&
          other.startUtc == this.startUtc &&
          other.endUtc == this.endUtc &&
          other.kind == this.kind &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.inIsrael == this.inIsrael &&
          other.createdAt == this.createdAt);
}

class SacredWindowEntriesCompanion extends UpdateCompanion<SacredWindowEntry> {
  final Value<int> id;
  final Value<DateTime> startUtc;
  final Value<DateTime> endUtc;
  final Value<String> kind;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<bool> inIsrael;
  final Value<DateTime> createdAt;
  const SacredWindowEntriesCompanion({
    this.id = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.endUtc = const Value.absent(),
    this.kind = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.inIsrael = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SacredWindowEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startUtc,
    required DateTime endUtc,
    required String kind,
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    required bool inIsrael,
    this.createdAt = const Value.absent(),
  }) : startUtc = Value(startUtc),
       endUtc = Value(endUtc),
       kind = Value(kind),
       inIsrael = Value(inIsrael);
  static Insertable<SacredWindowEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? startUtc,
    Expression<DateTime>? endUtc,
    Expression<String>? kind,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<bool>? inIsrael,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startUtc != null) 'start_utc': startUtc,
      if (endUtc != null) 'end_utc': endUtc,
      if (kind != null) 'kind': kind,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (inIsrael != null) 'in_israel': inIsrael,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SacredWindowEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startUtc,
    Value<DateTime>? endUtc,
    Value<String>? kind,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<bool>? inIsrael,
    Value<DateTime>? createdAt,
  }) {
    return SacredWindowEntriesCompanion(
      id: id ?? this.id,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      kind: kind ?? this.kind,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      inIsrael: inIsrael ?? this.inIsrael,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<DateTime>(startUtc.value);
    }
    if (endUtc.present) {
      map['end_utc'] = Variable<DateTime>(endUtc.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (inIsrael.present) {
      map['in_israel'] = Variable<bool>(inIsrael.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SacredWindowEntriesCompanion(')
          ..write('id: $id, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('kind: $kind, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('inIsrael: $inIsrael, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PriorCompletionImportsTable extends PriorCompletionImports
    with TableInfo<$PriorCompletionImportsTable, PriorCompletionImport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriorCompletionImportsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
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
    sefariaRef,
    stageId,
    trackType,
    source,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prior_completion_imports';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriorCompletionImport> instance, {
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
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PriorCompletionImport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriorCompletionImport(
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
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $PriorCompletionImportsTable createAlias(String alias) {
    return $PriorCompletionImportsTable(attachedDatabase, alias);
  }
}

class PriorCompletionImport extends DataClass
    implements Insertable<PriorCompletionImport> {
  final int id;

  /// FK → learner_profiles(id) CASCADE DELETE — mirrors the FK on
  /// completion_events so profile deletion cascades cleanly.
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;

  /// The [CompletionSource] that produced this import row.
  ///
  /// Stored as the enum name string so SQL queries can distinguish
  /// [CompletionSource.bulkInTrack] from [CompletionSource.lifetimeOnly]
  /// without an extra join.  Only `bulkInTrack` and `lifetimeOnly` are valid
  /// values; [CompletionSource.live] completions never enter this table.
  final String source;
  final DateTime importedAt;
  const PriorCompletionImport({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    required this.source,
    required this.importedAt,
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
    map['source'] = Variable<String>(source);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  PriorCompletionImportsCompanion toCompanion(bool nullToAbsent) {
    return PriorCompletionImportsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      sefariaRef: Value(sefariaRef),
      stageId: Value(stageId),
      trackType: Value(trackType),
      source: Value(source),
      importedAt: Value(importedAt),
    );
  }

  factory PriorCompletionImport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriorCompletionImport(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      stageId: serializer.fromJson<int>(json['stageId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      source: serializer.fromJson<String>(json['source']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
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
      'source': serializer.toJson<String>(source),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  PriorCompletionImport copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? stageId,
    String? trackType,
    String? source,
    DateTime? importedAt,
  }) => PriorCompletionImport(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    stageId: stageId ?? this.stageId,
    trackType: trackType ?? this.trackType,
    source: source ?? this.source,
    importedAt: importedAt ?? this.importedAt,
  );
  PriorCompletionImport copyWithCompanion(
    PriorCompletionImportsCompanion data,
  ) {
    return PriorCompletionImport(
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
      source: data.source.present ? data.source.value : this.source,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriorCompletionImport(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('source: $source, ')
          ..write('importedAt: $importedAt')
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
    source,
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriorCompletionImport &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.sefariaRef == this.sefariaRef &&
          other.stageId == this.stageId &&
          other.trackType == this.trackType &&
          other.source == this.source &&
          other.importedAt == this.importedAt);
}

class PriorCompletionImportsCompanion
    extends UpdateCompanion<PriorCompletionImport> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> stageId;
  final Value<String> trackType;
  final Value<String> source;
  final Value<DateTime> importedAt;
  const PriorCompletionImportsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.stageId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.source = const Value.absent(),
    this.importedAt = const Value.absent(),
  });
  PriorCompletionImportsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required String source,
    this.importedAt = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       sefariaRef = Value(sefariaRef),
       stageId = Value(stageId),
       trackType = Value(trackType),
       source = Value(source);
  static Insertable<PriorCompletionImport> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? sefariaRef,
    Expression<int>? stageId,
    Expression<String>? trackType,
    Expression<String>? source,
    Expression<DateTime>? importedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (stageId != null) 'stage_id': stageId,
      if (trackType != null) 'track_type': trackType,
      if (source != null) 'source': source,
      if (importedAt != null) 'imported_at': importedAt,
    });
  }

  PriorCompletionImportsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? stageId,
    Value<String>? trackType,
    Value<String>? source,
    Value<DateTime>? importedAt,
  }) {
    return PriorCompletionImportsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      stageId: stageId ?? this.stageId,
      trackType: trackType ?? this.trackType,
      source: source ?? this.source,
      importedAt: importedAt ?? this.importedAt,
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
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriorCompletionImportsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('source: $source, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncKvTable extends SyncKv with TableInfo<$SyncKvTable, SyncKvData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityKeyMeta = const VerificationMeta(
    'entityKey',
  );
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'entity_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMsMeta = const VerificationMeta(
    'syncedAtMs',
  );
  @override
  late final GeneratedColumn<int> syncedAtMs = GeneratedColumn<int>(
    'synced_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    kind,
    entityKey,
    updatedAtMs,
    syncedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncKvData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_key')) {
      context.handle(
        _entityKeyMeta,
        entityKey.isAcceptableOrUnknown(data['entity_key']!, _entityKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKeyMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('synced_at_ms')) {
      context.handle(
        _syncedAtMsMeta,
        syncedAtMs.isAcceptableOrUnknown(
          data['synced_at_ms']!,
          _syncedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, entityKey};
  @override
  SyncKvData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncKvData(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_key'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      syncedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at_ms'],
      ),
    );
  }

  @override
  $SyncKvTable createAlias(String alias) {
    return $SyncKvTable(attachedDatabase, alias);
  }
}

class SyncKvData extends DataClass implements Insertable<SyncKvData> {
  /// Entity kind — matches [EntityKind] constants (e.g. `bookmark`,
  /// `settings`, `stage_definition`).
  final String kind;

  /// Natural key of the entity within [kind]. Format is per-kind and
  /// defined by the individual merger (e.g. `${curriculumId}|${trackType}`
  /// for bookmarks).
  final String entityKey;

  /// Last-applied client `updated_at` for this `(kind, entityKey)`.
  final int updatedAtMs;

  /// Last-known Firestore server timestamp (`synced_at`) for this
  /// `(kind, entityKey)`. Used as the tie-breaker when client `updated_at`
  /// values are within ±5 s on two devices.
  final int? syncedAtMs;
  const SyncKvData({
    required this.kind,
    required this.entityKey,
    required this.updatedAtMs,
    this.syncedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['entity_key'] = Variable<String>(entityKey);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || syncedAtMs != null) {
      map['synced_at_ms'] = Variable<int>(syncedAtMs);
    }
    return map;
  }

  SyncKvCompanion toCompanion(bool nullToAbsent) {
    return SyncKvCompanion(
      kind: Value(kind),
      entityKey: Value(entityKey),
      updatedAtMs: Value(updatedAtMs),
      syncedAtMs: syncedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAtMs),
    );
  }

  factory SyncKvData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncKvData(
      kind: serializer.fromJson<String>(json['kind']),
      entityKey: serializer.fromJson<String>(json['entityKey']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      syncedAtMs: serializer.fromJson<int?>(json['syncedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'entityKey': serializer.toJson<String>(entityKey),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'syncedAtMs': serializer.toJson<int?>(syncedAtMs),
    };
  }

  SyncKvData copyWith({
    String? kind,
    String? entityKey,
    int? updatedAtMs,
    Value<int?> syncedAtMs = const Value.absent(),
  }) => SyncKvData(
    kind: kind ?? this.kind,
    entityKey: entityKey ?? this.entityKey,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    syncedAtMs: syncedAtMs.present ? syncedAtMs.value : this.syncedAtMs,
  );
  SyncKvData copyWithCompanion(SyncKvCompanion data) {
    return SyncKvData(
      kind: data.kind.present ? data.kind.value : this.kind,
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      syncedAtMs: data.syncedAtMs.present
          ? data.syncedAtMs.value
          : this.syncedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncKvData(')
          ..write('kind: $kind, ')
          ..write('entityKey: $entityKey, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('syncedAtMs: $syncedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, entityKey, updatedAtMs, syncedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncKvData &&
          other.kind == this.kind &&
          other.entityKey == this.entityKey &&
          other.updatedAtMs == this.updatedAtMs &&
          other.syncedAtMs == this.syncedAtMs);
}

class SyncKvCompanion extends UpdateCompanion<SyncKvData> {
  final Value<String> kind;
  final Value<String> entityKey;
  final Value<int> updatedAtMs;
  final Value<int?> syncedAtMs;
  final Value<int> rowid;
  const SyncKvCompanion({
    this.kind = const Value.absent(),
    this.entityKey = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.syncedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncKvCompanion.insert({
    required String kind,
    required String entityKey,
    required int updatedAtMs,
    this.syncedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       entityKey = Value(entityKey),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<SyncKvData> custom({
    Expression<String>? kind,
    Expression<String>? entityKey,
    Expression<int>? updatedAtMs,
    Expression<int>? syncedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (entityKey != null) 'entity_key': entityKey,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (syncedAtMs != null) 'synced_at_ms': syncedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncKvCompanion copyWith({
    Value<String>? kind,
    Value<String>? entityKey,
    Value<int>? updatedAtMs,
    Value<int?>? syncedAtMs,
    Value<int>? rowid,
  }) {
    return SyncKvCompanion(
      kind: kind ?? this.kind,
      entityKey: entityKey ?? this.entityKey,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      syncedAtMs: syncedAtMs ?? this.syncedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (syncedAtMs.present) {
      map['synced_at_ms'] = Variable<int>(syncedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncKvCompanion(')
          ..write('kind: $kind, ')
          ..write('entityKey: $entityKey, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('syncedAtMs: $syncedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PointsBalanceTable extends PointsBalance
    with TableInfo<$PointsBalanceTable, PointsBalanceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsBalanceTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _balanceMeta = const VerificationMeta(
    'balance',
  );
  @override
  late final GeneratedColumn<int> balance = GeneratedColumn<int>(
    'balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
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
  List<GeneratedColumn> get $columns => [profileId, balance, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points_balance';
  @override
  VerificationContext validateIntegrity(
    Insertable<PointsBalanceData> instance, {
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
    if (data.containsKey('balance')) {
      context.handle(
        _balanceMeta,
        balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta),
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
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  PointsBalanceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PointsBalanceData(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      balance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PointsBalanceTable createAlias(String alias) {
    return $PointsBalanceTable(attachedDatabase, alias);
  }
}

class PointsBalanceData extends DataClass
    implements Insertable<PointsBalanceData> {
  /// FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;

  /// Current debitable balance. Never negative (enforced in PointsBalanceDao).
  final int balance;
  final DateTime updatedAt;
  const PointsBalanceData({
    required this.profileId,
    required this.balance,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['balance'] = Variable<int>(balance);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PointsBalanceCompanion toCompanion(bool nullToAbsent) {
    return PointsBalanceCompanion(
      profileId: Value(profileId),
      balance: Value(balance),
      updatedAt: Value(updatedAt),
    );
  }

  factory PointsBalanceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PointsBalanceData(
      profileId: serializer.fromJson<int>(json['profileId']),
      balance: serializer.fromJson<int>(json['balance']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<int>(profileId),
      'balance': serializer.toJson<int>(balance),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PointsBalanceData copyWith({
    int? profileId,
    int? balance,
    DateTime? updatedAt,
  }) => PointsBalanceData(
    profileId: profileId ?? this.profileId,
    balance: balance ?? this.balance,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PointsBalanceData copyWithCompanion(PointsBalanceCompanion data) {
    return PointsBalanceData(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      balance: data.balance.present ? data.balance.value : this.balance,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PointsBalanceData(')
          ..write('profileId: $profileId, ')
          ..write('balance: $balance, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, balance, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointsBalanceData &&
          other.profileId == this.profileId &&
          other.balance == this.balance &&
          other.updatedAt == this.updatedAt);
}

class PointsBalanceCompanion extends UpdateCompanion<PointsBalanceData> {
  final Value<int> profileId;
  final Value<int> balance;
  final Value<DateTime> updatedAt;
  const PointsBalanceCompanion({
    this.profileId = const Value.absent(),
    this.balance = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PointsBalanceCompanion.insert({
    this.profileId = const Value.absent(),
    this.balance = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<PointsBalanceData> custom({
    Expression<int>? profileId,
    Expression<int>? balance,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (balance != null) 'balance': balance,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PointsBalanceCompanion copyWith({
    Value<int>? profileId,
    Value<int>? balance,
    Value<DateTime>? updatedAt,
  }) {
    return PointsBalanceCompanion(
      profileId: profileId ?? this.profileId,
      balance: balance ?? this.balance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (balance.present) {
      map['balance'] = Variable<int>(balance.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsBalanceCompanion(')
          ..write('profileId: $profileId, ')
          ..write('balance: $balance, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PointsLedgerTable extends PointsLedger
    with TableInfo<$PointsLedgerTable, PointsLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsLedgerTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _entryKindMeta = const VerificationMeta(
    'entryKind',
  );
  @override
  late final GeneratedColumn<String> entryKind = GeneratedColumn<String>(
    'entry_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<int> delta = GeneratedColumn<int>(
    'delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _redemptionIdMeta = const VerificationMeta(
    'redemptionId',
  );
  @override
  late final GeneratedColumn<int> redemptionId = GeneratedColumn<int>(
    'redemption_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _ulidMeta = const VerificationMeta('ulid');
  @override
  late final GeneratedColumn<String> ulid = GeneratedColumn<String>(
    'ulid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncEnqueuedAtMeta = const VerificationMeta(
    'syncEnqueuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncEnqueuedAt =
      GeneratedColumn<DateTime>(
        'sync_enqueued_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    entryKind,
    delta,
    note,
    redemptionId,
    createdAt,
    ulid,
    syncEnqueuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<PointsLedgerData> instance, {
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
    if (data.containsKey('entry_kind')) {
      context.handle(
        _entryKindMeta,
        entryKind.isAcceptableOrUnknown(data['entry_kind']!, _entryKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKindMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
        _deltaMeta,
        delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('redemption_id')) {
      context.handle(
        _redemptionIdMeta,
        redemptionId.isAcceptableOrUnknown(
          data['redemption_id']!,
          _redemptionIdMeta,
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
    if (data.containsKey('ulid')) {
      context.handle(
        _ulidMeta,
        ulid.isAcceptableOrUnknown(data['ulid']!, _ulidMeta),
      );
    }
    if (data.containsKey('sync_enqueued_at')) {
      context.handle(
        _syncEnqueuedAtMeta,
        syncEnqueuedAt.isAcceptableOrUnknown(
          data['sync_enqueued_at']!,
          _syncEnqueuedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PointsLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PointsLedgerData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      entryKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_kind'],
      )!,
      delta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      redemptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}redemption_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      ulid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ulid'],
      ),
      syncEnqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sync_enqueued_at'],
      ),
    );
  }

  @override
  $PointsLedgerTable createAlias(String alias) {
    return $PointsLedgerTable(attachedDatabase, alias);
  }
}

class PointsLedgerData extends DataClass
    implements Insertable<PointsLedgerData> {
  final int id;

  /// FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;

  /// `completion` | `redemption_debit` | `redemption_refund`
  /// | `parent_add` | `parent_deduct`
  final String entryKind;

  /// Signed delta applied to [PointsBalance.balance].
  /// Positive = credit; negative = debit.
  final int delta;

  /// Optional description (note from parent, reward title, etc.).
  final String? note;

  /// Optional FK to [RewardRedemptions.id] for redemption-related entries.
  final int? redemptionId;
  final DateTime createdAt;

  /// Stable, lexicographically-sortable, cross-device id for append-only
  /// cloud sync (schema v27, WS9 Wave-B). Nullable on existing rows; the
  /// Wave-B sync agent backfills + populates this going forward, and uses it
  /// as the deterministic Firestore document id for ledger entries.
  final String? ulid;

  /// D14 — set once this row has been enqueued onto the cloud-sync outbox
  /// (or pulled FROM the cloud, in which case it is already remote).
  ///
  /// `null` means the row was written while no sync sink was wired (e.g. a
  /// cloud-born account's first credit before the features layer registered
  /// the sink) and has never been queued for push. The startup/post-wire
  /// reconciliation re-enqueues every `null`-marker row exactly once so no
  /// ledger entry is permanently stranded off the cloud. Local-born rows stay
  /// `null` forever (correct — they have no cloud destination until upgrade).
  final DateTime? syncEnqueuedAt;
  const PointsLedgerData({
    required this.id,
    required this.profileId,
    required this.entryKind,
    required this.delta,
    this.note,
    this.redemptionId,
    required this.createdAt,
    this.ulid,
    this.syncEnqueuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['entry_kind'] = Variable<String>(entryKind);
    map['delta'] = Variable<int>(delta);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || redemptionId != null) {
      map['redemption_id'] = Variable<int>(redemptionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || ulid != null) {
      map['ulid'] = Variable<String>(ulid);
    }
    if (!nullToAbsent || syncEnqueuedAt != null) {
      map['sync_enqueued_at'] = Variable<DateTime>(syncEnqueuedAt);
    }
    return map;
  }

  PointsLedgerCompanion toCompanion(bool nullToAbsent) {
    return PointsLedgerCompanion(
      id: Value(id),
      profileId: Value(profileId),
      entryKind: Value(entryKind),
      delta: Value(delta),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      redemptionId: redemptionId == null && nullToAbsent
          ? const Value.absent()
          : Value(redemptionId),
      createdAt: Value(createdAt),
      ulid: ulid == null && nullToAbsent ? const Value.absent() : Value(ulid),
      syncEnqueuedAt: syncEnqueuedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncEnqueuedAt),
    );
  }

  factory PointsLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PointsLedgerData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      entryKind: serializer.fromJson<String>(json['entryKind']),
      delta: serializer.fromJson<int>(json['delta']),
      note: serializer.fromJson<String?>(json['note']),
      redemptionId: serializer.fromJson<int?>(json['redemptionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      ulid: serializer.fromJson<String?>(json['ulid']),
      syncEnqueuedAt: serializer.fromJson<DateTime?>(json['syncEnqueuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'entryKind': serializer.toJson<String>(entryKind),
      'delta': serializer.toJson<int>(delta),
      'note': serializer.toJson<String?>(note),
      'redemptionId': serializer.toJson<int?>(redemptionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'ulid': serializer.toJson<String?>(ulid),
      'syncEnqueuedAt': serializer.toJson<DateTime?>(syncEnqueuedAt),
    };
  }

  PointsLedgerData copyWith({
    int? id,
    int? profileId,
    String? entryKind,
    int? delta,
    Value<String?> note = const Value.absent(),
    Value<int?> redemptionId = const Value.absent(),
    DateTime? createdAt,
    Value<String?> ulid = const Value.absent(),
    Value<DateTime?> syncEnqueuedAt = const Value.absent(),
  }) => PointsLedgerData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    entryKind: entryKind ?? this.entryKind,
    delta: delta ?? this.delta,
    note: note.present ? note.value : this.note,
    redemptionId: redemptionId.present ? redemptionId.value : this.redemptionId,
    createdAt: createdAt ?? this.createdAt,
    ulid: ulid.present ? ulid.value : this.ulid,
    syncEnqueuedAt: syncEnqueuedAt.present
        ? syncEnqueuedAt.value
        : this.syncEnqueuedAt,
  );
  PointsLedgerData copyWithCompanion(PointsLedgerCompanion data) {
    return PointsLedgerData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      entryKind: data.entryKind.present ? data.entryKind.value : this.entryKind,
      delta: data.delta.present ? data.delta.value : this.delta,
      note: data.note.present ? data.note.value : this.note,
      redemptionId: data.redemptionId.present
          ? data.redemptionId.value
          : this.redemptionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      ulid: data.ulid.present ? data.ulid.value : this.ulid,
      syncEnqueuedAt: data.syncEnqueuedAt.present
          ? data.syncEnqueuedAt.value
          : this.syncEnqueuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PointsLedgerData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('entryKind: $entryKind, ')
          ..write('delta: $delta, ')
          ..write('note: $note, ')
          ..write('redemptionId: $redemptionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('ulid: $ulid, ')
          ..write('syncEnqueuedAt: $syncEnqueuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    entryKind,
    delta,
    note,
    redemptionId,
    createdAt,
    ulid,
    syncEnqueuedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointsLedgerData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.entryKind == this.entryKind &&
          other.delta == this.delta &&
          other.note == this.note &&
          other.redemptionId == this.redemptionId &&
          other.createdAt == this.createdAt &&
          other.ulid == this.ulid &&
          other.syncEnqueuedAt == this.syncEnqueuedAt);
}

class PointsLedgerCompanion extends UpdateCompanion<PointsLedgerData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> entryKind;
  final Value<int> delta;
  final Value<String?> note;
  final Value<int?> redemptionId;
  final Value<DateTime> createdAt;
  final Value<String?> ulid;
  final Value<DateTime?> syncEnqueuedAt;
  const PointsLedgerCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.entryKind = const Value.absent(),
    this.delta = const Value.absent(),
    this.note = const Value.absent(),
    this.redemptionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.ulid = const Value.absent(),
    this.syncEnqueuedAt = const Value.absent(),
  });
  PointsLedgerCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String entryKind,
    required int delta,
    this.note = const Value.absent(),
    this.redemptionId = const Value.absent(),
    required DateTime createdAt,
    this.ulid = const Value.absent(),
    this.syncEnqueuedAt = const Value.absent(),
  }) : profileId = Value(profileId),
       entryKind = Value(entryKind),
       delta = Value(delta),
       createdAt = Value(createdAt);
  static Insertable<PointsLedgerData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? entryKind,
    Expression<int>? delta,
    Expression<String>? note,
    Expression<int>? redemptionId,
    Expression<DateTime>? createdAt,
    Expression<String>? ulid,
    Expression<DateTime>? syncEnqueuedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (entryKind != null) 'entry_kind': entryKind,
      if (delta != null) 'delta': delta,
      if (note != null) 'note': note,
      if (redemptionId != null) 'redemption_id': redemptionId,
      if (createdAt != null) 'created_at': createdAt,
      if (ulid != null) 'ulid': ulid,
      if (syncEnqueuedAt != null) 'sync_enqueued_at': syncEnqueuedAt,
    });
  }

  PointsLedgerCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? entryKind,
    Value<int>? delta,
    Value<String?>? note,
    Value<int?>? redemptionId,
    Value<DateTime>? createdAt,
    Value<String?>? ulid,
    Value<DateTime?>? syncEnqueuedAt,
  }) {
    return PointsLedgerCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      entryKind: entryKind ?? this.entryKind,
      delta: delta ?? this.delta,
      note: note ?? this.note,
      redemptionId: redemptionId ?? this.redemptionId,
      createdAt: createdAt ?? this.createdAt,
      ulid: ulid ?? this.ulid,
      syncEnqueuedAt: syncEnqueuedAt ?? this.syncEnqueuedAt,
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
    if (entryKind.present) {
      map['entry_kind'] = Variable<String>(entryKind.value);
    }
    if (delta.present) {
      map['delta'] = Variable<int>(delta.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (redemptionId.present) {
      map['redemption_id'] = Variable<int>(redemptionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (ulid.present) {
      map['ulid'] = Variable<String>(ulid.value);
    }
    if (syncEnqueuedAt.present) {
      map['sync_enqueued_at'] = Variable<DateTime>(syncEnqueuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsLedgerCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('entryKind: $entryKind, ')
          ..write('delta: $delta, ')
          ..write('note: $note, ')
          ..write('redemptionId: $redemptionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('ulid: $ulid, ')
          ..write('syncEnqueuedAt: $syncEnqueuedAt')
          ..write(')'))
        .toString();
  }
}

class $RewardRedemptionsTable extends RewardRedemptions
    with TableInfo<$RewardRedemptionsTable, RewardRedemption> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardRedemptionsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learner_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _rewardTitleMeta = const VerificationMeta(
    'rewardTitle',
  );
  @override
  late final GeneratedColumn<String> rewardTitle = GeneratedColumn<String>(
    'reward_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconIndexMeta = const VerificationMeta(
    'iconIndex',
  );
  @override
  late final GeneratedColumn<int> iconIndex = GeneratedColumn<int>(
    'icon_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _pointsCostMeta = const VerificationMeta(
    'pointsCost',
  );
  @override
  late final GeneratedColumn<int> pointsCost = GeneratedColumn<int>(
    'points_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant<String>('pending_fulfilment'),
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
  static const VerificationMeta _ulidMeta = const VerificationMeta('ulid');
  @override
  late final GeneratedColumn<String> ulid = GeneratedColumn<String>(
    'ulid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    rewardTitle,
    iconIndex,
    pointsCost,
    status,
    createdAt,
    updatedAt,
    ulid,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reward_redemptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RewardRedemption> instance, {
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
    if (data.containsKey('reward_title')) {
      context.handle(
        _rewardTitleMeta,
        rewardTitle.isAcceptableOrUnknown(
          data['reward_title']!,
          _rewardTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rewardTitleMeta);
    }
    if (data.containsKey('icon_index')) {
      context.handle(
        _iconIndexMeta,
        iconIndex.isAcceptableOrUnknown(data['icon_index']!, _iconIndexMeta),
      );
    }
    if (data.containsKey('points_cost')) {
      context.handle(
        _pointsCostMeta,
        pointsCost.isAcceptableOrUnknown(data['points_cost']!, _pointsCostMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsCostMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('ulid')) {
      context.handle(
        _ulidMeta,
        ulid.isAcceptableOrUnknown(data['ulid']!, _ulidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RewardRedemption map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewardRedemption(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      rewardTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_title'],
      )!,
      iconIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_index'],
      )!,
      pointsCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_cost'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      ulid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ulid'],
      ),
    );
  }

  @override
  $RewardRedemptionsTable createAlias(String alias) {
    return $RewardRedemptionsTable(attachedDatabase, alias);
  }
}

class RewardRedemption extends DataClass
    implements Insertable<RewardRedemption> {
  final int id;

  /// FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;

  /// Snapshot of the reward title at redemption time.
  final String rewardTitle;

  /// Snapshot of the reward icon index at redemption time.
  final int iconIndex;

  /// Points that were debited from the balance when this was created.
  final int pointsCost;

  /// `pending_fulfilment` | `fulfilled` | `declined`
  final String status;
  final DateTime createdAt;

  /// Last-write-wins timestamp for cloud sync (already present pre-v27; used
  /// as the LWW field by the Wave-B sync agent).
  final DateTime updatedAt;

  /// Stable, lexicographically-sortable, cross-device id for cloud sync
  /// (schema v27, WS9 Wave-B). Nullable on existing rows; the Wave-B sync
  /// agent backfills + populates this and uses it as the deterministic
  /// Firestore document id for redemptions.
  final String? ulid;
  const RewardRedemption({
    required this.id,
    required this.profileId,
    required this.rewardTitle,
    required this.iconIndex,
    required this.pointsCost,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ulid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['reward_title'] = Variable<String>(rewardTitle);
    map['icon_index'] = Variable<int>(iconIndex);
    map['points_cost'] = Variable<int>(pointsCost);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || ulid != null) {
      map['ulid'] = Variable<String>(ulid);
    }
    return map;
  }

  RewardRedemptionsCompanion toCompanion(bool nullToAbsent) {
    return RewardRedemptionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      rewardTitle: Value(rewardTitle),
      iconIndex: Value(iconIndex),
      pointsCost: Value(pointsCost),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      ulid: ulid == null && nullToAbsent ? const Value.absent() : Value(ulid),
    );
  }

  factory RewardRedemption.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewardRedemption(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      rewardTitle: serializer.fromJson<String>(json['rewardTitle']),
      iconIndex: serializer.fromJson<int>(json['iconIndex']),
      pointsCost: serializer.fromJson<int>(json['pointsCost']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      ulid: serializer.fromJson<String?>(json['ulid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'rewardTitle': serializer.toJson<String>(rewardTitle),
      'iconIndex': serializer.toJson<int>(iconIndex),
      'pointsCost': serializer.toJson<int>(pointsCost),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'ulid': serializer.toJson<String?>(ulid),
    };
  }

  RewardRedemption copyWith({
    int? id,
    int? profileId,
    String? rewardTitle,
    int? iconIndex,
    int? pointsCost,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> ulid = const Value.absent(),
  }) => RewardRedemption(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    rewardTitle: rewardTitle ?? this.rewardTitle,
    iconIndex: iconIndex ?? this.iconIndex,
    pointsCost: pointsCost ?? this.pointsCost,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    ulid: ulid.present ? ulid.value : this.ulid,
  );
  RewardRedemption copyWithCompanion(RewardRedemptionsCompanion data) {
    return RewardRedemption(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      rewardTitle: data.rewardTitle.present
          ? data.rewardTitle.value
          : this.rewardTitle,
      iconIndex: data.iconIndex.present ? data.iconIndex.value : this.iconIndex,
      pointsCost: data.pointsCost.present
          ? data.pointsCost.value
          : this.pointsCost,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      ulid: data.ulid.present ? data.ulid.value : this.ulid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewardRedemption(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('rewardTitle: $rewardTitle, ')
          ..write('iconIndex: $iconIndex, ')
          ..write('pointsCost: $pointsCost, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('ulid: $ulid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    rewardTitle,
    iconIndex,
    pointsCost,
    status,
    createdAt,
    updatedAt,
    ulid,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewardRedemption &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.rewardTitle == this.rewardTitle &&
          other.iconIndex == this.iconIndex &&
          other.pointsCost == this.pointsCost &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.ulid == this.ulid);
}

class RewardRedemptionsCompanion extends UpdateCompanion<RewardRedemption> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> rewardTitle;
  final Value<int> iconIndex;
  final Value<int> pointsCost;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> ulid;
  const RewardRedemptionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rewardTitle = const Value.absent(),
    this.iconIndex = const Value.absent(),
    this.pointsCost = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.ulid = const Value.absent(),
  });
  RewardRedemptionsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String rewardTitle,
    this.iconIndex = const Value.absent(),
    required int pointsCost,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.ulid = const Value.absent(),
  }) : profileId = Value(profileId),
       rewardTitle = Value(rewardTitle),
       pointsCost = Value(pointsCost),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RewardRedemption> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? rewardTitle,
    Expression<int>? iconIndex,
    Expression<int>? pointsCost,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? ulid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (rewardTitle != null) 'reward_title': rewardTitle,
      if (iconIndex != null) 'icon_index': iconIndex,
      if (pointsCost != null) 'points_cost': pointsCost,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (ulid != null) 'ulid': ulid,
    });
  }

  RewardRedemptionsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? rewardTitle,
    Value<int>? iconIndex,
    Value<int>? pointsCost,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? ulid,
  }) {
    return RewardRedemptionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      rewardTitle: rewardTitle ?? this.rewardTitle,
      iconIndex: iconIndex ?? this.iconIndex,
      pointsCost: pointsCost ?? this.pointsCost,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ulid: ulid ?? this.ulid,
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
    if (rewardTitle.present) {
      map['reward_title'] = Variable<String>(rewardTitle.value);
    }
    if (iconIndex.present) {
      map['icon_index'] = Variable<int>(iconIndex.value);
    }
    if (pointsCost.present) {
      map['points_cost'] = Variable<int>(pointsCost.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (ulid.present) {
      map['ulid'] = Variable<String>(ulid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardRedemptionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('rewardTitle: $rewardTitle, ')
          ..write('iconIndex: $iconIndex, ')
          ..write('pointsCost: $pointsCost, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('ulid: $ulid')
          ..write(')'))
        .toString();
  }
}

class CompletionsViewData extends DataClass {
  final int id;
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;
  final int? trackId;
  final int points;
  final DateTime eventTimestamp;
  const CompletionsViewData({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    this.trackId,
    required this.points,
    required this.eventTimestamp,
  });
  factory CompletionsViewData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletionsViewData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      stageId: serializer.fromJson<int>(json['stageId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      trackId: serializer.fromJson<int?>(json['trackId']),
      points: serializer.fromJson<int>(json['points']),
      eventTimestamp: serializer.fromJson<DateTime>(json['eventTimestamp']),
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
      'trackId': serializer.toJson<int?>(trackId),
      'points': serializer.toJson<int>(points),
      'eventTimestamp': serializer.toJson<DateTime>(eventTimestamp),
    };
  }

  CompletionsViewData copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? stageId,
    String? trackType,
    Value<int?> trackId = const Value.absent(),
    int? points,
    DateTime? eventTimestamp,
  }) => CompletionsViewData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    stageId: stageId ?? this.stageId,
    trackType: trackType ?? this.trackType,
    trackId: trackId.present ? trackId.value : this.trackId,
    points: points ?? this.points,
    eventTimestamp: eventTimestamp ?? this.eventTimestamp,
  );
  @override
  String toString() {
    return (StringBuffer('CompletionsViewData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('stageId: $stageId, ')
          ..write('trackType: $trackType, ')
          ..write('trackId: $trackId, ')
          ..write('points: $points, ')
          ..write('eventTimestamp: $eventTimestamp')
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
    trackId,
    points,
    eventTimestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletionsViewData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.sefariaRef == this.sefariaRef &&
          other.stageId == this.stageId &&
          other.trackType == this.trackType &&
          other.trackId == this.trackId &&
          other.points == this.points &&
          other.eventTimestamp == this.eventTimestamp);
}

class $CompletionsViewView
    extends ViewInfo<$CompletionsViewView, CompletionsViewData>
    implements HasResultSet {
  final String? _alias;
  @override
  final _$UserDatabase attachedDatabase;
  $CompletionsViewView(this.attachedDatabase, [this._alias]);
  $CompletionEventsTable get completionEvents =>
      attachedDatabase.completionEvents.createAlias('t0');
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    sefariaRef,
    stageId,
    trackType,
    trackId,
    points,
    eventTimestamp,
  ];
  @override
  String get aliasedName => _alias ?? entityName;
  @override
  String get entityName => 'completions_view';
  @override
  Map<SqlDialect, String>? get createViewStatements => null;
  @override
  $CompletionsViewView get asDslTable => this;
  @override
  CompletionsViewData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletionsViewData(
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      eventTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_timestamp'],
      )!,
    );
  }

  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.id, false),
    type: DriftSqlType.int,
  );
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.profileId, false),
    type: DriftSqlType.int,
  );
  late final GeneratedColumn<String> curriculumId = GeneratedColumn<String>(
    'curriculum_id',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.curriculumId, false),
    type: DriftSqlType.string,
  );
  late final GeneratedColumn<String> sefariaRef = GeneratedColumn<String>(
    'sefaria_ref',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.sefariaRef, false),
    type: DriftSqlType.string,
  );
  late final GeneratedColumn<int> stageId = GeneratedColumn<int>(
    'stage_id',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.stageId, false),
    type: DriftSqlType.int,
  );
  late final GeneratedColumn<String> trackType = GeneratedColumn<String>(
    'track_type',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.trackType, false),
    type: DriftSqlType.string,
  );
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    true,
    generatedAs: GeneratedAs(completionEvents.trackId, false),
    type: DriftSqlType.int,
  );
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    generatedAs: GeneratedAs(completionEvents.points, false),
    type: DriftSqlType.int,
  );
  late final GeneratedColumn<DateTime> eventTimestamp =
      GeneratedColumn<DateTime>(
        'event_timestamp',
        aliasedName,
        false,
        generatedAs: GeneratedAs(completionEvents.eventTimestamp, false),
        type: DriftSqlType.dateTime,
      );
  @override
  $CompletionsViewView createAlias(String alias) {
    return $CompletionsViewView(attachedDatabase, alias);
  }

  @override
  Query? get query =>
      (attachedDatabase.selectOnly(completionEvents)..addColumns($columns));
  @override
  Set<String> get readTables => const {'completion_events'};
}

abstract class _$UserDatabase extends GeneratedDatabase {
  _$UserDatabase(QueryExecutor e) : super(e);
  $UserDatabaseManager get managers => $UserDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $LearnerProfilesTable learnerProfiles = $LearnerProfilesTable(
    this,
  );
  late final $CurriculumTracksTable curriculumTracks = $CurriculumTracksTable(
    this,
  );
  late final $CurriculumScopesTable curriculumScopes = $CurriculumScopesTable(
    this,
  );
  late final $ProfileProgramsTable profilePrograms = $ProfileProgramsTable(
    this,
  );
  late final $StageDefinitionsTable stageDefinitions = $StageDefinitionsTable(
    this,
  );
  late final $PointConfigsTable pointConfigs = $PointConfigsTable(this);
  late final $StudyDayConfigsTable studyDayConfigs = $StudyDayConfigsTable(
    this,
  );
  late final $CompletionEventsTable completionEvents = $CompletionEventsTable(
    this,
  );
  late final $DailyPlansTable dailyPlans = $DailyPlansTable(this);
  late final $LearningLedgerTable learningLedger = $LearningLedgerTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $LearningOrderTable learningOrder = $LearningOrderTable(this);
  late final $TrackLearningOrderTable trackLearningOrder =
      $TrackLearningOrderTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $StreakEventsTable streakEvents = $StreakEventsTable(this);
  late final $TextDownloadStatusesTable textDownloadStatuses =
      $TextDownloadStatusesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SacredWindowEntriesTable sacredWindowEntries =
      $SacredWindowEntriesTable(this);
  late final $PriorCompletionImportsTable priorCompletionImports =
      $PriorCompletionImportsTable(this);
  late final $SyncKvTable syncKv = $SyncKvTable(this);
  late final $PointsBalanceTable pointsBalance = $PointsBalanceTable(this);
  late final $PointsLedgerTable pointsLedger = $PointsLedgerTable(this);
  late final $RewardRedemptionsTable rewardRedemptions =
      $RewardRedemptionsTable(this);
  late final $CompletionsViewView completionsView = $CompletionsViewView(this);
  late final Index completionEventsNaturalKey = Index(
    'completion_events_natural_key',
    'CREATE UNIQUE INDEX completion_events_natural_key ON completion_events (profile_id, sefaria_ref, stage_id, track_type, curriculum_id)',
  );
  late final Index learningLedgerProfileCreated = Index(
    'learning_ledger_profile_created',
    'CREATE INDEX learning_ledger_profile_created ON learning_ledger (profile_id, created_at)',
  );
  late final Index learningLedgerProfileUlid = Index(
    'learning_ledger_profile_ulid',
    'CREATE UNIQUE INDEX learning_ledger_profile_ulid ON learning_ledger (profile_id, ulid)',
  );
  late final Index goalsProfileCurriculum = Index(
    'goals_profile_curriculum',
    'CREATE INDEX goals_profile_curriculum ON goals (profile_id, curriculum_id)',
  );
  late final Index streakEventsNaturalKey = Index(
    'streak_events_natural_key',
    'CREATE UNIQUE INDEX streak_events_natural_key ON streak_events (profile_id, day_utc, event_type)',
  );
  late final Index outboxProfileKind = Index(
    'outbox_profile_kind',
    'CREATE INDEX outbox_profile_kind ON outbox (profile_id, entity_kind)',
  );
  late final Index pointsLedgerProfileUlid = Index(
    'points_ledger_profile_ulid',
    'CREATE UNIQUE INDEX points_ledger_profile_ulid ON points_ledger (profile_id, ulid)',
  );
  late final Index rewardRedemptionsProfileUlid = Index(
    'reward_redemptions_profile_ulid',
    'CREATE UNIQUE INDEX reward_redemptions_profile_ulid ON reward_redemptions (profile_id, ulid)',
  );
  late final ActiveCurriculumDao activeCurriculumDao = ActiveCurriculumDao(
    this as UserDatabase,
  );
  late final CurriculumScopeDao curriculumScopeDao = CurriculumScopeDao(
    this as UserDatabase,
  );
  late final CompletionDao completionDao = CompletionDao(this as UserDatabase);
  late final CompletionEventDao completionEventDao = CompletionEventDao(
    this as UserDatabase,
  );
  late final DailyPlanDao dailyPlanDao = DailyPlanDao(this as UserDatabase);
  late final LearningLedgerDao learningLedgerDao = LearningLedgerDao(
    this as UserDatabase,
  );
  late final GoalDao goalDao = GoalDao(this as UserDatabase);
  late final PointConfigDao pointConfigDao = PointConfigDao(
    this as UserDatabase,
  );
  late final PointsBalanceDao pointsBalanceDao = PointsBalanceDao(
    this as UserDatabase,
  );
  late final StageDao stageDao = StageDao(this as UserDatabase);
  late final BookmarkDao bookmarkDao = BookmarkDao(this as UserDatabase);
  late final LearningOrderDao learningOrderDao = LearningOrderDao(
    this as UserDatabase,
  );
  late final TrackLearningOrderDao trackLearningOrderDao =
      TrackLearningOrderDao(this as UserDatabase);
  late final TrackDao trackDao = TrackDao(this as UserDatabase);
  late final ProfileDao profileDao = ProfileDao(this as UserDatabase);
  late final UserProfileDao userProfileDao = UserProfileDao(
    this as UserDatabase,
  );
  late final StreakEventDao streakEventDao = StreakEventDao(
    this as UserDatabase,
  );
  late final TextDownloadStatusDao textDownloadStatusDao =
      TextDownloadStatusDao(this as UserDatabase);
  late final StudyDayConfigDao studyDayConfigDao = StudyDayConfigDao(
    this as UserDatabase,
  );
  late final ProfileProgramDao profileProgramDao = ProfileProgramDao(
    this as UserDatabase,
  );
  late final OutboxDao outboxDao = OutboxDao(this as UserDatabase);
  late final SacredWindowDao sacredWindowDao = SacredWindowDao(
    this as UserDatabase,
  );
  late final PriorCompletionImportDao priorCompletionImportDao =
      PriorCompletionImportDao(this as UserDatabase);
  late final SyncKvDao syncKvDao = SyncKvDao(this as UserDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    learnerProfiles,
    curriculumTracks,
    curriculumScopes,
    profilePrograms,
    stageDefinitions,
    pointConfigs,
    studyDayConfigs,
    completionEvents,
    dailyPlans,
    learningLedger,
    bookmarks,
    learningOrder,
    trackLearningOrder,
    goals,
    streakEvents,
    textDownloadStatuses,
    outbox,
    sacredWindowEntries,
    priorCompletionImports,
    syncKv,
    pointsBalance,
    pointsLedger,
    rewardRedemptions,
    completionsView,
    completionEventsNaturalKey,
    learningLedgerProfileCreated,
    learningLedgerProfileUlid,
    goalsProfileCurriculum,
    streakEventsNaturalKey,
    outboxProfileKind,
    pointsLedgerProfileUlid,
    rewardRedemptionsProfileUlid,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learner_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('curriculum_scopes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stage_definitions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('completion_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_ledger', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'curriculum_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_ledger', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bookmarks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'curriculum_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bookmarks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_order', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goals', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('streak_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('prior_completion_imports', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('points_balance', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('points_ledger', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reward_redemptions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      required String email,
      Value<String?> firebaseUid,
      Value<String?> passwordHash,
      required String tier,
      required String displayName,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      Value<String> email,
      Value<String?> firebaseUid,
      Value<String?> passwordHash,
      Value<String> tier,
      Value<String> displayName,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$UserDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LearnerProfilesTable, List<LearnerProfile>>
  _learnerProfilesRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.learnerProfiles,
    aliasName: $_aliasNameGenerator(
      db.accounts.id,
      db.learnerProfiles.accountId,
    ),
  );

  $$LearnerProfilesTableProcessedTableManager get learnerProfilesRefs {
    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _learnerProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$UserDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
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

  Expression<bool> learnerProfilesRefs(
    Expression<bool> Function($$LearnerProfilesTableFilterComposer f) f,
  ) {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$UserDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
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

class $$AccountsTableAnnotationComposer
    extends Composer<_$UserDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> learnerProfilesRefs<T extends Object>(
    Expression<T> Function($$LearnerProfilesTableAnnotationComposer a) f,
  ) {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({bool learnerProfilesRefs})
        > {
  $$AccountsTableTableManager(_$UserDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String?> firebaseUid = const Value.absent(),
                Value<String?> passwordHash = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                email: email,
                firebaseUid: firebaseUid,
                passwordHash: passwordHash,
                tier: tier,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String email,
                Value<String?> firebaseUid = const Value.absent(),
                Value<String?> passwordHash = const Value.absent(),
                required String tier,
                required String displayName,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => AccountsCompanion.insert(
                id: id,
                email: email,
                firebaseUid: firebaseUid,
                passwordHash: passwordHash,
                tier: tier,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({learnerProfilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (learnerProfilesRefs) db.learnerProfiles,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (learnerProfilesRefs)
                    await $_getPrefetchedData<
                      Account,
                      $AccountsTable,
                      LearnerProfile
                    >(
                      currentTable: table,
                      referencedTable: $$AccountsTableReferences
                          ._learnerProfilesRefsTable(db),
                      managerFromTypedResult: (p0) => $$AccountsTableReferences(
                        db,
                        table,
                        p0,
                      ).learnerProfilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.accountId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({bool learnerProfilesRefs})
    >;
typedef $$LearnerProfilesTableCreateCompanionBuilder =
    LearnerProfilesCompanion Function({
      Value<int> id,
      required int accountId,
      required String displayName,
      required String mode,
      Value<int> avatarIndex,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isTutored,
      Value<String?> tutorParentUid,
      Value<String?> tutorRemoteProfileId,
      Value<String?> tutorGrantId,
    });
typedef $$LearnerProfilesTableUpdateCompanionBuilder =
    LearnerProfilesCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<String> displayName,
      Value<String> mode,
      Value<int> avatarIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isTutored,
      Value<String?> tutorParentUid,
      Value<String?> tutorRemoteProfileId,
      Value<String?> tutorGrantId,
    });

final class $$LearnerProfilesTableReferences
    extends
        BaseReferences<_$UserDatabase, $LearnerProfilesTable, LearnerProfile> {
  $$LearnerProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$UserDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.learnerProfiles.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CurriculumScopesTable, List<CurriculumScope>>
  _curriculumScopesRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.curriculumScopes,
        aliasName: $_aliasNameGenerator(
          db.learnerProfiles.id,
          db.curriculumScopes.profileId,
        ),
      );

  $$CurriculumScopesTableProcessedTableManager get curriculumScopesRefs {
    final manager = $$CurriculumScopesTableTableManager(
      $_db,
      $_db.curriculumScopes,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _curriculumScopesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StageDefinitionsTable, List<StageDefinition>>
  _stageDefinitionsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.stageDefinitions,
        aliasName: $_aliasNameGenerator(
          db.learnerProfiles.id,
          db.stageDefinitions.profileId,
        ),
      );

  $$StageDefinitionsTableProcessedTableManager get stageDefinitionsRefs {
    final manager = $$StageDefinitionsTableTableManager(
      $_db,
      $_db.stageDefinitions,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stageDefinitionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CompletionEventsTable, List<CompletionEvent>>
  _completionEventsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.completionEvents,
        aliasName: $_aliasNameGenerator(
          db.learnerProfiles.id,
          db.completionEvents.profileId,
        ),
      );

  $$CompletionEventsTableProcessedTableManager get completionEventsRefs {
    final manager = $$CompletionEventsTableTableManager(
      $_db,
      $_db.completionEvents,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _completionEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningLedgerTable, List<LearningLedgerData>>
  _learningLedgerRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.learningLedger,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.learningLedger.profileId,
    ),
  );

  $$LearningLedgerTableProcessedTableManager get learningLedgerRefs {
    final manager = $$LearningLedgerTableTableManager(
      $_db,
      $_db.learningLedger,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_learningLedgerRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.bookmarks.profileId,
    ),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningOrderTable, List<LearningOrderData>>
  _learningOrderRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.learningOrder,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.learningOrder.profileId,
    ),
  );

  $$LearningOrderTableProcessedTableManager get learningOrderRefs {
    final manager = $$LearningOrderTableTableManager(
      $_db,
      $_db.learningOrder,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_learningOrderRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GoalsTable, List<Goal>> _goalsRefsTable(
    _$UserDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.goals,
    aliasName: $_aliasNameGenerator(db.learnerProfiles.id, db.goals.profileId),
  );

  $$GoalsTableProcessedTableManager get goalsRefs {
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StreakEventsTable, List<StreakEvent>>
  _streakEventsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.streakEvents,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.streakEvents.profileId,
    ),
  );

  $$StreakEventsTableProcessedTableManager get streakEventsRefs {
    final manager = $$StreakEventsTableTableManager(
      $_db,
      $_db.streakEvents,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_streakEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PriorCompletionImportsTable,
    List<PriorCompletionImport>
  >
  _priorCompletionImportsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.priorCompletionImports,
        aliasName: $_aliasNameGenerator(
          db.learnerProfiles.id,
          db.priorCompletionImports.profileId,
        ),
      );

  $$PriorCompletionImportsTableProcessedTableManager
  get priorCompletionImportsRefs {
    final manager = $$PriorCompletionImportsTableTableManager(
      $_db,
      $_db.priorCompletionImports,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _priorCompletionImportsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PointsBalanceTable, List<PointsBalanceData>>
  _pointsBalanceRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.pointsBalance,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.pointsBalance.profileId,
    ),
  );

  $$PointsBalanceTableProcessedTableManager get pointsBalanceRefs {
    final manager = $$PointsBalanceTableTableManager(
      $_db,
      $_db.pointsBalance,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsBalanceRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PointsLedgerTable, List<PointsLedgerData>>
  _pointsLedgerRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.pointsLedger,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.pointsLedger.profileId,
    ),
  );

  $$PointsLedgerTableProcessedTableManager get pointsLedgerRefs {
    final manager = $$PointsLedgerTableTableManager(
      $_db,
      $_db.pointsLedger,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsLedgerRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RewardRedemptionsTable, List<RewardRedemption>>
  _rewardRedemptionsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.rewardRedemptions,
        aliasName: $_aliasNameGenerator(
          db.learnerProfiles.id,
          db.rewardRedemptions.profileId,
        ),
      );

  $$RewardRedemptionsTableProcessedTableManager get rewardRedemptionsRefs {
    final manager = $$RewardRedemptionsTableTableManager(
      $_db,
      $_db.rewardRedemptions,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _rewardRedemptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LearnerProfilesTableFilterComposer
    extends Composer<_$UserDatabase, $LearnerProfilesTable> {
  $$LearnerProfilesTableFilterComposer({
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

  ColumnFilters<bool> get isTutored => $composableBuilder(
    column: $table.isTutored,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tutorParentUid => $composableBuilder(
    column: $table.tutorParentUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tutorRemoteProfileId => $composableBuilder(
    column: $table.tutorRemoteProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tutorGrantId => $composableBuilder(
    column: $table.tutorGrantId,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> curriculumScopesRefs(
    Expression<bool> Function($$CurriculumScopesTableFilterComposer f) f,
  ) {
    final $$CurriculumScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.curriculumScopes,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumScopesTableFilterComposer(
            $db: $db,
            $table: $db.curriculumScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stageDefinitionsRefs(
    Expression<bool> Function($$StageDefinitionsTableFilterComposer f) f,
  ) {
    final $$StageDefinitionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageDefinitions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageDefinitionsTableFilterComposer(
            $db: $db,
            $table: $db.stageDefinitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> completionEventsRefs(
    Expression<bool> Function($$CompletionEventsTableFilterComposer f) f,
  ) {
    final $$CompletionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completionEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionEventsTableFilterComposer(
            $db: $db,
            $table: $db.completionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningLedgerRefs(
    Expression<bool> Function($$LearningLedgerTableFilterComposer f) f,
  ) {
    final $$LearningLedgerTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningLedger,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningLedgerTableFilterComposer(
            $db: $db,
            $table: $db.learningLedger,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningOrderRefs(
    Expression<bool> Function($$LearningOrderTableFilterComposer f) f,
  ) {
    final $$LearningOrderTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningOrder,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningOrderTableFilterComposer(
            $db: $db,
            $table: $db.learningOrder,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> goalsRefs(
    Expression<bool> Function($$GoalsTableFilterComposer f) f,
  ) {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> streakEventsRefs(
    Expression<bool> Function($$StreakEventsTableFilterComposer f) f,
  ) {
    final $$StreakEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.streakEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StreakEventsTableFilterComposer(
            $db: $db,
            $table: $db.streakEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> priorCompletionImportsRefs(
    Expression<bool> Function($$PriorCompletionImportsTableFilterComposer f) f,
  ) {
    final $$PriorCompletionImportsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.priorCompletionImports,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PriorCompletionImportsTableFilterComposer(
                $db: $db,
                $table: $db.priorCompletionImports,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> pointsBalanceRefs(
    Expression<bool> Function($$PointsBalanceTableFilterComposer f) f,
  ) {
    final $$PointsBalanceTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointsBalance,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsBalanceTableFilterComposer(
            $db: $db,
            $table: $db.pointsBalance,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pointsLedgerRefs(
    Expression<bool> Function($$PointsLedgerTableFilterComposer f) f,
  ) {
    final $$PointsLedgerTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointsLedger,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsLedgerTableFilterComposer(
            $db: $db,
            $table: $db.pointsLedger,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rewardRedemptionsRefs(
    Expression<bool> Function($$RewardRedemptionsTableFilterComposer f) f,
  ) {
    final $$RewardRedemptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rewardRedemptions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RewardRedemptionsTableFilterComposer(
            $db: $db,
            $table: $db.rewardRedemptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LearnerProfilesTableOrderingComposer
    extends Composer<_$UserDatabase, $LearnerProfilesTable> {
  $$LearnerProfilesTableOrderingComposer({
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

  ColumnOrderings<bool> get isTutored => $composableBuilder(
    column: $table.isTutored,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tutorParentUid => $composableBuilder(
    column: $table.tutorParentUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tutorRemoteProfileId => $composableBuilder(
    column: $table.tutorRemoteProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tutorGrantId => $composableBuilder(
    column: $table.tutorGrantId,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnerProfilesTableAnnotationComposer
    extends Composer<_$UserDatabase, $LearnerProfilesTable> {
  $$LearnerProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<bool> get isTutored =>
      $composableBuilder(column: $table.isTutored, builder: (column) => column);

  GeneratedColumn<String> get tutorParentUid => $composableBuilder(
    column: $table.tutorParentUid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tutorRemoteProfileId => $composableBuilder(
    column: $table.tutorRemoteProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tutorGrantId => $composableBuilder(
    column: $table.tutorGrantId,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> curriculumScopesRefs<T extends Object>(
    Expression<T> Function($$CurriculumScopesTableAnnotationComposer a) f,
  ) {
    final $$CurriculumScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.curriculumScopes,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stageDefinitionsRefs<T extends Object>(
    Expression<T> Function($$StageDefinitionsTableAnnotationComposer a) f,
  ) {
    final $$StageDefinitionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageDefinitions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageDefinitionsTableAnnotationComposer(
            $db: $db,
            $table: $db.stageDefinitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> completionEventsRefs<T extends Object>(
    Expression<T> Function($$CompletionEventsTableAnnotationComposer a) f,
  ) {
    final $$CompletionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completionEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.completionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningLedgerRefs<T extends Object>(
    Expression<T> Function($$LearningLedgerTableAnnotationComposer a) f,
  ) {
    final $$LearningLedgerTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningLedger,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningLedgerTableAnnotationComposer(
            $db: $db,
            $table: $db.learningLedger,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningOrderRefs<T extends Object>(
    Expression<T> Function($$LearningOrderTableAnnotationComposer a) f,
  ) {
    final $$LearningOrderTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningOrder,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningOrderTableAnnotationComposer(
            $db: $db,
            $table: $db.learningOrder,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> goalsRefs<T extends Object>(
    Expression<T> Function($$GoalsTableAnnotationComposer a) f,
  ) {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> streakEventsRefs<T extends Object>(
    Expression<T> Function($$StreakEventsTableAnnotationComposer a) f,
  ) {
    final $$StreakEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.streakEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StreakEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.streakEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> priorCompletionImportsRefs<T extends Object>(
    Expression<T> Function($$PriorCompletionImportsTableAnnotationComposer a) f,
  ) {
    final $$PriorCompletionImportsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.priorCompletionImports,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PriorCompletionImportsTableAnnotationComposer(
                $db: $db,
                $table: $db.priorCompletionImports,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pointsBalanceRefs<T extends Object>(
    Expression<T> Function($$PointsBalanceTableAnnotationComposer a) f,
  ) {
    final $$PointsBalanceTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointsBalance,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsBalanceTableAnnotationComposer(
            $db: $db,
            $table: $db.pointsBalance,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pointsLedgerRefs<T extends Object>(
    Expression<T> Function($$PointsLedgerTableAnnotationComposer a) f,
  ) {
    final $$PointsLedgerTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointsLedger,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsLedgerTableAnnotationComposer(
            $db: $db,
            $table: $db.pointsLedger,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rewardRedemptionsRefs<T extends Object>(
    Expression<T> Function($$RewardRedemptionsTableAnnotationComposer a) f,
  ) {
    final $$RewardRedemptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.rewardRedemptions,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RewardRedemptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.rewardRedemptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LearnerProfilesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $LearnerProfilesTable,
          LearnerProfile,
          $$LearnerProfilesTableFilterComposer,
          $$LearnerProfilesTableOrderingComposer,
          $$LearnerProfilesTableAnnotationComposer,
          $$LearnerProfilesTableCreateCompanionBuilder,
          $$LearnerProfilesTableUpdateCompanionBuilder,
          (LearnerProfile, $$LearnerProfilesTableReferences),
          LearnerProfile,
          PrefetchHooks Function({
            bool accountId,
            bool curriculumScopesRefs,
            bool stageDefinitionsRefs,
            bool completionEventsRefs,
            bool learningLedgerRefs,
            bool bookmarksRefs,
            bool learningOrderRefs,
            bool goalsRefs,
            bool streakEventsRefs,
            bool priorCompletionImportsRefs,
            bool pointsBalanceRefs,
            bool pointsLedgerRefs,
            bool rewardRedemptionsRefs,
          })
        > {
  $$LearnerProfilesTableTableManager(
    _$UserDatabase db,
    $LearnerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearnerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> avatarIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isTutored = const Value.absent(),
                Value<String?> tutorParentUid = const Value.absent(),
                Value<String?> tutorRemoteProfileId = const Value.absent(),
                Value<String?> tutorGrantId = const Value.absent(),
              }) => LearnerProfilesCompanion(
                id: id,
                accountId: accountId,
                displayName: displayName,
                mode: mode,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isTutored: isTutored,
                tutorParentUid: tutorParentUid,
                tutorRemoteProfileId: tutorRemoteProfileId,
                tutorGrantId: tutorGrantId,
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
                Value<bool> isTutored = const Value.absent(),
                Value<String?> tutorParentUid = const Value.absent(),
                Value<String?> tutorRemoteProfileId = const Value.absent(),
                Value<String?> tutorGrantId = const Value.absent(),
              }) => LearnerProfilesCompanion.insert(
                id: id,
                accountId: accountId,
                displayName: displayName,
                mode: mode,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isTutored: isTutored,
                tutorParentUid: tutorParentUid,
                tutorRemoteProfileId: tutorRemoteProfileId,
                tutorGrantId: tutorGrantId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearnerProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                curriculumScopesRefs = false,
                stageDefinitionsRefs = false,
                completionEventsRefs = false,
                learningLedgerRefs = false,
                bookmarksRefs = false,
                learningOrderRefs = false,
                goalsRefs = false,
                streakEventsRefs = false,
                priorCompletionImportsRefs = false,
                pointsBalanceRefs = false,
                pointsLedgerRefs = false,
                rewardRedemptionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (curriculumScopesRefs) db.curriculumScopes,
                    if (stageDefinitionsRefs) db.stageDefinitions,
                    if (completionEventsRefs) db.completionEvents,
                    if (learningLedgerRefs) db.learningLedger,
                    if (bookmarksRefs) db.bookmarks,
                    if (learningOrderRefs) db.learningOrder,
                    if (goalsRefs) db.goals,
                    if (streakEventsRefs) db.streakEvents,
                    if (priorCompletionImportsRefs) db.priorCompletionImports,
                    if (pointsBalanceRefs) db.pointsBalance,
                    if (pointsLedgerRefs) db.pointsLedger,
                    if (rewardRedemptionsRefs) db.rewardRedemptions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$LearnerProfilesTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$LearnerProfilesTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (curriculumScopesRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          CurriculumScope
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._curriculumScopesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).curriculumScopesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stageDefinitionsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          StageDefinition
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._stageDefinitionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).stageDefinitionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (completionEventsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          CompletionEvent
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._completionEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).completionEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningLedgerRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          LearningLedgerData
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._learningLedgerRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningLedgerRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          Bookmark
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningOrderRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          LearningOrderData
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._learningOrderRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningOrderRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (goalsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          Goal
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._goalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).goalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (streakEventsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          StreakEvent
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._streakEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).streakEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (priorCompletionImportsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          PriorCompletionImport
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._priorCompletionImportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).priorCompletionImportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pointsBalanceRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          PointsBalanceData
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._pointsBalanceRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).pointsBalanceRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pointsLedgerRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          PointsLedgerData
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._pointsLedgerRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).pointsLedgerRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (rewardRedemptionsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          RewardRedemption
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._rewardRedemptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).rewardRedemptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LearnerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $LearnerProfilesTable,
      LearnerProfile,
      $$LearnerProfilesTableFilterComposer,
      $$LearnerProfilesTableOrderingComposer,
      $$LearnerProfilesTableAnnotationComposer,
      $$LearnerProfilesTableCreateCompanionBuilder,
      $$LearnerProfilesTableUpdateCompanionBuilder,
      (LearnerProfile, $$LearnerProfilesTableReferences),
      LearnerProfile,
      PrefetchHooks Function({
        bool accountId,
        bool curriculumScopesRefs,
        bool stageDefinitionsRefs,
        bool completionEventsRefs,
        bool learningLedgerRefs,
        bool bookmarksRefs,
        bool learningOrderRefs,
        bool goalsRefs,
        bool streakEventsRefs,
        bool priorCompletionImportsRefs,
        bool pointsBalanceRefs,
        bool pointsLedgerRefs,
        bool rewardRedemptionsRefs,
      })
    >;
typedef $$CurriculumTracksTableCreateCompanionBuilder =
    CurriculumTracksCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      Value<String> state,
      required DateTime stateChangedAt,
      required DateTime activatedAt,
      Value<DateTime?> paceResetDate,
      Value<DateTime?> lastReorderAt,
    });
typedef $$CurriculumTracksTableUpdateCompanionBuilder =
    CurriculumTracksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> state,
      Value<DateTime> stateChangedAt,
      Value<DateTime> activatedAt,
      Value<DateTime?> paceResetDate,
      Value<DateTime?> lastReorderAt,
    });

final class $$CurriculumTracksTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $CurriculumTracksTable,
          CurriculumTrack
        > {
  $$CurriculumTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CurriculumScopesTable, List<CurriculumScope>>
  _curriculumScopesRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.curriculumScopes,
        aliasName: $_aliasNameGenerator(
          db.curriculumTracks.id,
          db.curriculumScopes.trackId,
        ),
      );

  $$CurriculumScopesTableProcessedTableManager get curriculumScopesRefs {
    final manager = $$CurriculumScopesTableTableManager(
      $_db,
      $_db.curriculumScopes,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _curriculumScopesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StageDefinitionsTable, List<StageDefinition>>
  _stageDefinitionsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.stageDefinitions,
        aliasName: $_aliasNameGenerator(
          db.curriculumTracks.id,
          db.stageDefinitions.trackId,
        ),
      );

  $$StageDefinitionsTableProcessedTableManager get stageDefinitionsRefs {
    final manager = $$StageDefinitionsTableTableManager(
      $_db,
      $_db.stageDefinitions,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stageDefinitionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PointConfigsTable, List<PointConfig>>
  _pointConfigsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.pointConfigs,
    aliasName: $_aliasNameGenerator(
      db.curriculumTracks.id,
      db.pointConfigs.trackId,
    ),
  );

  $$PointConfigsTableProcessedTableManager get pointConfigsRefs {
    final manager = $$PointConfigsTableTableManager(
      $_db,
      $_db.pointConfigs,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointConfigsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StudyDayConfigsTable, List<StudyDayConfig>>
  _studyDayConfigsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.studyDayConfigs,
    aliasName: $_aliasNameGenerator(
      db.curriculumTracks.id,
      db.studyDayConfigs.trackId,
    ),
  );

  $$StudyDayConfigsTableProcessedTableManager get studyDayConfigsRefs {
    final manager = $$StudyDayConfigsTableTableManager(
      $_db,
      $_db.studyDayConfigs,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _studyDayConfigsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningLedgerTable, List<LearningLedgerData>>
  _learningLedgerRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.learningLedger,
    aliasName: $_aliasNameGenerator(
      db.curriculumTracks.id,
      db.learningLedger.trackId,
    ),
  );

  $$LearningLedgerTableProcessedTableManager get learningLedgerRefs {
    final manager = $$LearningLedgerTableTableManager(
      $_db,
      $_db.learningLedger,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_learningLedgerRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(
      db.curriculumTracks.id,
      db.bookmarks.trackId,
    ),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GoalsTable, List<Goal>> _goalsRefsTable(
    _$UserDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.goals,
    aliasName: $_aliasNameGenerator(db.curriculumTracks.id, db.goals.trackId),
  );

  $$GoalsTableProcessedTableManager get goalsRefs {
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CurriculumTracksTableFilterComposer
    extends Composer<_$UserDatabase, $CurriculumTracksTable> {
  $$CurriculumTracksTableFilterComposer({
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

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get stateChangedAt => $composableBuilder(
    column: $table.stateChangedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paceResetDate => $composableBuilder(
    column: $table.paceResetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReorderAt => $composableBuilder(
    column: $table.lastReorderAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> curriculumScopesRefs(
    Expression<bool> Function($$CurriculumScopesTableFilterComposer f) f,
  ) {
    final $$CurriculumScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.curriculumScopes,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumScopesTableFilterComposer(
            $db: $db,
            $table: $db.curriculumScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stageDefinitionsRefs(
    Expression<bool> Function($$StageDefinitionsTableFilterComposer f) f,
  ) {
    final $$StageDefinitionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageDefinitions,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageDefinitionsTableFilterComposer(
            $db: $db,
            $table: $db.stageDefinitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pointConfigsRefs(
    Expression<bool> Function($$PointConfigsTableFilterComposer f) f,
  ) {
    final $$PointConfigsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointConfigs,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointConfigsTableFilterComposer(
            $db: $db,
            $table: $db.pointConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studyDayConfigsRefs(
    Expression<bool> Function($$StudyDayConfigsTableFilterComposer f) f,
  ) {
    final $$StudyDayConfigsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studyDayConfigs,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyDayConfigsTableFilterComposer(
            $db: $db,
            $table: $db.studyDayConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningLedgerRefs(
    Expression<bool> Function($$LearningLedgerTableFilterComposer f) f,
  ) {
    final $$LearningLedgerTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningLedger,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningLedgerTableFilterComposer(
            $db: $db,
            $table: $db.learningLedger,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> goalsRefs(
    Expression<bool> Function($$GoalsTableFilterComposer f) f,
  ) {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CurriculumTracksTableOrderingComposer
    extends Composer<_$UserDatabase, $CurriculumTracksTable> {
  $$CurriculumTracksTableOrderingComposer({
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

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get stateChangedAt => $composableBuilder(
    column: $table.stateChangedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paceResetDate => $composableBuilder(
    column: $table.paceResetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReorderAt => $composableBuilder(
    column: $table.lastReorderAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurriculumTracksTableAnnotationComposer
    extends Composer<_$UserDatabase, $CurriculumTracksTable> {
  $$CurriculumTracksTableAnnotationComposer({
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

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get stateChangedAt => $composableBuilder(
    column: $table.stateChangedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get paceResetDate => $composableBuilder(
    column: $table.paceResetDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReorderAt => $composableBuilder(
    column: $table.lastReorderAt,
    builder: (column) => column,
  );

  Expression<T> curriculumScopesRefs<T extends Object>(
    Expression<T> Function($$CurriculumScopesTableAnnotationComposer a) f,
  ) {
    final $$CurriculumScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.curriculumScopes,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stageDefinitionsRefs<T extends Object>(
    Expression<T> Function($$StageDefinitionsTableAnnotationComposer a) f,
  ) {
    final $$StageDefinitionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageDefinitions,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageDefinitionsTableAnnotationComposer(
            $db: $db,
            $table: $db.stageDefinitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pointConfigsRefs<T extends Object>(
    Expression<T> Function($$PointConfigsTableAnnotationComposer a) f,
  ) {
    final $$PointConfigsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointConfigs,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointConfigsTableAnnotationComposer(
            $db: $db,
            $table: $db.pointConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> studyDayConfigsRefs<T extends Object>(
    Expression<T> Function($$StudyDayConfigsTableAnnotationComposer a) f,
  ) {
    final $$StudyDayConfigsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studyDayConfigs,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyDayConfigsTableAnnotationComposer(
            $db: $db,
            $table: $db.studyDayConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningLedgerRefs<T extends Object>(
    Expression<T> Function($$LearningLedgerTableAnnotationComposer a) f,
  ) {
    final $$LearningLedgerTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningLedger,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningLedgerTableAnnotationComposer(
            $db: $db,
            $table: $db.learningLedger,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> goalsRefs<T extends Object>(
    Expression<T> Function($$GoalsTableAnnotationComposer a) f,
  ) {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CurriculumTracksTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $CurriculumTracksTable,
          CurriculumTrack,
          $$CurriculumTracksTableFilterComposer,
          $$CurriculumTracksTableOrderingComposer,
          $$CurriculumTracksTableAnnotationComposer,
          $$CurriculumTracksTableCreateCompanionBuilder,
          $$CurriculumTracksTableUpdateCompanionBuilder,
          (CurriculumTrack, $$CurriculumTracksTableReferences),
          CurriculumTrack,
          PrefetchHooks Function({
            bool curriculumScopesRefs,
            bool stageDefinitionsRefs,
            bool pointConfigsRefs,
            bool studyDayConfigsRefs,
            bool learningLedgerRefs,
            bool bookmarksRefs,
            bool goalsRefs,
          })
        > {
  $$CurriculumTracksTableTableManager(
    _$UserDatabase db,
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
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> stateChangedAt = const Value.absent(),
                Value<DateTime> activatedAt = const Value.absent(),
                Value<DateTime?> paceResetDate = const Value.absent(),
                Value<DateTime?> lastReorderAt = const Value.absent(),
              }) => CurriculumTracksCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                state: state,
                stateChangedAt: stateChangedAt,
                activatedAt: activatedAt,
                paceResetDate: paceResetDate,
                lastReorderAt: lastReorderAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                Value<String> state = const Value.absent(),
                required DateTime stateChangedAt,
                required DateTime activatedAt,
                Value<DateTime?> paceResetDate = const Value.absent(),
                Value<DateTime?> lastReorderAt = const Value.absent(),
              }) => CurriculumTracksCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                state: state,
                stateChangedAt: stateChangedAt,
                activatedAt: activatedAt,
                paceResetDate: paceResetDate,
                lastReorderAt: lastReorderAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CurriculumTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                curriculumScopesRefs = false,
                stageDefinitionsRefs = false,
                pointConfigsRefs = false,
                studyDayConfigsRefs = false,
                learningLedgerRefs = false,
                bookmarksRefs = false,
                goalsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (curriculumScopesRefs) db.curriculumScopes,
                    if (stageDefinitionsRefs) db.stageDefinitions,
                    if (pointConfigsRefs) db.pointConfigs,
                    if (studyDayConfigsRefs) db.studyDayConfigs,
                    if (learningLedgerRefs) db.learningLedger,
                    if (bookmarksRefs) db.bookmarks,
                    if (goalsRefs) db.goals,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (curriculumScopesRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          CurriculumScope
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._curriculumScopesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).curriculumScopesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stageDefinitionsRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          StageDefinition
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._stageDefinitionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).stageDefinitionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pointConfigsRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          PointConfig
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._pointConfigsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).pointConfigsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (studyDayConfigsRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          StudyDayConfig
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._studyDayConfigsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).studyDayConfigsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningLedgerRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          LearningLedgerData
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._learningLedgerRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).learningLedgerRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          Bookmark
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (goalsRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          Goal
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._goalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).goalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CurriculumTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $CurriculumTracksTable,
      CurriculumTrack,
      $$CurriculumTracksTableFilterComposer,
      $$CurriculumTracksTableOrderingComposer,
      $$CurriculumTracksTableAnnotationComposer,
      $$CurriculumTracksTableCreateCompanionBuilder,
      $$CurriculumTracksTableUpdateCompanionBuilder,
      (CurriculumTrack, $$CurriculumTracksTableReferences),
      CurriculumTrack,
      PrefetchHooks Function({
        bool curriculumScopesRefs,
        bool stageDefinitionsRefs,
        bool pointConfigsRefs,
        bool studyDayConfigsRefs,
        bool learningLedgerRefs,
        bool bookmarksRefs,
        bool goalsRefs,
      })
    >;
typedef $$CurriculumScopesTableCreateCompanionBuilder =
    CurriculumScopesCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required int trackId,
      required int scopeLevel,
      required String scopeValue,
      required DateTime createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$CurriculumScopesTableUpdateCompanionBuilder =
    CurriculumScopesCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> trackId,
      Value<int> scopeLevel,
      Value<String> scopeValue,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$CurriculumScopesTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $CurriculumScopesTable,
          CurriculumScope
        > {
  $$CurriculumScopesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(
          db.curriculumScopes.profileId,
          db.learnerProfiles.id,
        ),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(
          db.curriculumScopes.trackId,
          db.curriculumTracks.id,
        ),
      );

  $$CurriculumTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CurriculumScopesTableFilterComposer
    extends Composer<_$UserDatabase, $CurriculumScopesTable> {
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CurriculumScopesTableOrderingComposer
    extends Composer<_$UserDatabase, $CurriculumScopesTable> {
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CurriculumScopesTableAnnotationComposer
    extends Composer<_$UserDatabase, $CurriculumScopesTable> {
  $$CurriculumScopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CurriculumScopesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $CurriculumScopesTable,
          CurriculumScope,
          $$CurriculumScopesTableFilterComposer,
          $$CurriculumScopesTableOrderingComposer,
          $$CurriculumScopesTableAnnotationComposer,
          $$CurriculumScopesTableCreateCompanionBuilder,
          $$CurriculumScopesTableUpdateCompanionBuilder,
          (CurriculumScope, $$CurriculumScopesTableReferences),
          CurriculumScope,
          PrefetchHooks Function({bool profileId, bool trackId})
        > {
  $$CurriculumScopesTableTableManager(
    _$UserDatabase db,
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
                Value<int> trackId = const Value.absent(),
                Value<int> scopeLevel = const Value.absent(),
                Value<String> scopeValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CurriculumScopesCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                scopeLevel: scopeLevel,
                scopeValue: scopeValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required int trackId,
                required int scopeLevel,
                required String scopeValue,
                required DateTime createdAt,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CurriculumScopesCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                scopeLevel: scopeLevel,
                scopeValue: scopeValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CurriculumScopesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$CurriculumScopesTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$CurriculumScopesTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$CurriculumScopesTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$CurriculumScopesTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CurriculumScopesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $CurriculumScopesTable,
      CurriculumScope,
      $$CurriculumScopesTableFilterComposer,
      $$CurriculumScopesTableOrderingComposer,
      $$CurriculumScopesTableAnnotationComposer,
      $$CurriculumScopesTableCreateCompanionBuilder,
      $$CurriculumScopesTableUpdateCompanionBuilder,
      (CurriculumScope, $$CurriculumScopesTableReferences),
      CurriculumScope,
      PrefetchHooks Function({bool profileId, bool trackId})
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
    extends Composer<_$UserDatabase, $ProfileProgramsTable> {
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
    extends Composer<_$UserDatabase, $ProfileProgramsTable> {
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
    extends Composer<_$UserDatabase, $ProfileProgramsTable> {
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
          _$UserDatabase,
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
              _$UserDatabase,
              $ProfileProgramsTable,
              ProfileProgram
            >,
          ),
          ProfileProgram,
          PrefetchHooks Function()
        > {
  $$ProfileProgramsTableTableManager(
    _$UserDatabase db,
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
      _$UserDatabase,
      $ProfileProgramsTable,
      ProfileProgram,
      $$ProfileProgramsTableFilterComposer,
      $$ProfileProgramsTableOrderingComposer,
      $$ProfileProgramsTableAnnotationComposer,
      $$ProfileProgramsTableCreateCompanionBuilder,
      $$ProfileProgramsTableUpdateCompanionBuilder,
      (
        ProfileProgram,
        BaseReferences<_$UserDatabase, $ProfileProgramsTable, ProfileProgram>,
      ),
      ProfileProgram,
      PrefetchHooks Function()
    >;
typedef $$StageDefinitionsTableCreateCompanionBuilder =
    StageDefinitionsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required int trackId,
      required int stageOrder,
      required String stageName,
      Value<bool> isDefault,
      Value<String> schedule,
      Value<DateTime> updatedAt,
    });
typedef $$StageDefinitionsTableUpdateCompanionBuilder =
    StageDefinitionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> trackId,
      Value<int> stageOrder,
      Value<String> stageName,
      Value<bool> isDefault,
      Value<String> schedule,
      Value<DateTime> updatedAt,
    });

final class $$StageDefinitionsTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $StageDefinitionsTable,
          StageDefinition
        > {
  $$StageDefinitionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(
          db.stageDefinitions.profileId,
          db.learnerProfiles.id,
        ),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(
          db.stageDefinitions.trackId,
          db.curriculumTracks.id,
        ),
      );

  $$CurriculumTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StageDefinitionsTableFilterComposer
    extends Composer<_$UserDatabase, $StageDefinitionsTable> {
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

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedule => $composableBuilder(
    column: $table.schedule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageDefinitionsTableOrderingComposer
    extends Composer<_$UserDatabase, $StageDefinitionsTable> {
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

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedule => $composableBuilder(
    column: $table.schedule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageDefinitionsTableAnnotationComposer
    extends Composer<_$UserDatabase, $StageDefinitionsTable> {
  $$StageDefinitionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get schedule =>
      $composableBuilder(column: $table.schedule, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageDefinitionsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $StageDefinitionsTable,
          StageDefinition,
          $$StageDefinitionsTableFilterComposer,
          $$StageDefinitionsTableOrderingComposer,
          $$StageDefinitionsTableAnnotationComposer,
          $$StageDefinitionsTableCreateCompanionBuilder,
          $$StageDefinitionsTableUpdateCompanionBuilder,
          (StageDefinition, $$StageDefinitionsTableReferences),
          StageDefinition,
          PrefetchHooks Function({bool profileId, bool trackId})
        > {
  $$StageDefinitionsTableTableManager(
    _$UserDatabase db,
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
                Value<int> trackId = const Value.absent(),
                Value<int> stageOrder = const Value.absent(),
                Value<String> stageName = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String> schedule = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StageDefinitionsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                stageOrder: stageOrder,
                stageName: stageName,
                isDefault: isDefault,
                schedule: schedule,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required int trackId,
                required int stageOrder,
                required String stageName,
                Value<bool> isDefault = const Value.absent(),
                Value<String> schedule = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StageDefinitionsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                stageOrder: stageOrder,
                stageName: stageName,
                isDefault: isDefault,
                schedule: schedule,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StageDefinitionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$StageDefinitionsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$StageDefinitionsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$StageDefinitionsTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$StageDefinitionsTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StageDefinitionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $StageDefinitionsTable,
      StageDefinition,
      $$StageDefinitionsTableFilterComposer,
      $$StageDefinitionsTableOrderingComposer,
      $$StageDefinitionsTableAnnotationComposer,
      $$StageDefinitionsTableCreateCompanionBuilder,
      $$StageDefinitionsTableUpdateCompanionBuilder,
      (StageDefinition, $$StageDefinitionsTableReferences),
      StageDefinition,
      PrefetchHooks Function({bool profileId, bool trackId})
    >;
typedef $$PointConfigsTableCreateCompanionBuilder =
    PointConfigsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required int trackId,
      required int stageOrder,
      required int points,
    });
typedef $$PointConfigsTableUpdateCompanionBuilder =
    PointConfigsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> trackId,
      Value<int> stageOrder,
      Value<int> points,
    });

final class $$PointConfigsTableReferences
    extends BaseReferences<_$UserDatabase, $PointConfigsTable, PointConfig> {
  $$PointConfigsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(db.pointConfigs.trackId, db.curriculumTracks.id),
      );

  $$CurriculumTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PointConfigsTableFilterComposer
    extends Composer<_$UserDatabase, $PointConfigsTable> {
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

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointConfigsTableOrderingComposer
    extends Composer<_$UserDatabase, $PointConfigsTable> {
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

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointConfigsTableAnnotationComposer
    extends Composer<_$UserDatabase, $PointConfigsTable> {
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

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointConfigsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $PointConfigsTable,
          PointConfig,
          $$PointConfigsTableFilterComposer,
          $$PointConfigsTableOrderingComposer,
          $$PointConfigsTableAnnotationComposer,
          $$PointConfigsTableCreateCompanionBuilder,
          $$PointConfigsTableUpdateCompanionBuilder,
          (PointConfig, $$PointConfigsTableReferences),
          PointConfig,
          PrefetchHooks Function({bool trackId})
        > {
  $$PointConfigsTableTableManager(_$UserDatabase db, $PointConfigsTable table)
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
                Value<int> trackId = const Value.absent(),
                Value<int> stageOrder = const Value.absent(),
                Value<int> points = const Value.absent(),
              }) => PointConfigsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                stageOrder: stageOrder,
                points: points,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required int trackId,
                required int stageOrder,
                required int points,
              }) => PointConfigsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                stageOrder: stageOrder,
                points: points,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PointConfigsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$PointConfigsTableReferences
                                    ._trackIdTable(db),
                                referencedColumn: $$PointConfigsTableReferences
                                    ._trackIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PointConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $PointConfigsTable,
      PointConfig,
      $$PointConfigsTableFilterComposer,
      $$PointConfigsTableOrderingComposer,
      $$PointConfigsTableAnnotationComposer,
      $$PointConfigsTableCreateCompanionBuilder,
      $$PointConfigsTableUpdateCompanionBuilder,
      (PointConfig, $$PointConfigsTableReferences),
      PointConfig,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$StudyDayConfigsTableCreateCompanionBuilder =
    StudyDayConfigsCompanion Function({
      required int profileId,
      required String curriculumId,
      required int trackId,
      required int dayOfWeek,
      Value<String> dayType,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StudyDayConfigsTableUpdateCompanionBuilder =
    StudyDayConfigsCompanion Function({
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> trackId,
      Value<int> dayOfWeek,
      Value<String> dayType,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$StudyDayConfigsTableReferences
    extends
        BaseReferences<_$UserDatabase, $StudyDayConfigsTable, StudyDayConfig> {
  $$StudyDayConfigsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(
          db.studyDayConfigs.trackId,
          db.curriculumTracks.id,
        ),
      );

  $$CurriculumTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StudyDayConfigsTableFilterComposer
    extends Composer<_$UserDatabase, $StudyDayConfigsTable> {
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

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudyDayConfigsTableOrderingComposer
    extends Composer<_$UserDatabase, $StudyDayConfigsTable> {
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

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudyDayConfigsTableAnnotationComposer
    extends Composer<_$UserDatabase, $StudyDayConfigsTable> {
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

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudyDayConfigsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $StudyDayConfigsTable,
          StudyDayConfig,
          $$StudyDayConfigsTableFilterComposer,
          $$StudyDayConfigsTableOrderingComposer,
          $$StudyDayConfigsTableAnnotationComposer,
          $$StudyDayConfigsTableCreateCompanionBuilder,
          $$StudyDayConfigsTableUpdateCompanionBuilder,
          (StudyDayConfig, $$StudyDayConfigsTableReferences),
          StudyDayConfig,
          PrefetchHooks Function({bool trackId})
        > {
  $$StudyDayConfigsTableTableManager(
    _$UserDatabase db,
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
                Value<int> trackId = const Value.absent(),
                Value<int> dayOfWeek = const Value.absent(),
                Value<String> dayType = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyDayConfigsCompanion(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                dayOfWeek: dayOfWeek,
                dayType: dayType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int profileId,
                required String curriculumId,
                required int trackId,
                required int dayOfWeek,
                Value<String> dayType = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StudyDayConfigsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                dayOfWeek: dayOfWeek,
                dayType: dayType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudyDayConfigsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable:
                                    $$StudyDayConfigsTableReferences
                                        ._trackIdTable(db),
                                referencedColumn:
                                    $$StudyDayConfigsTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StudyDayConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $StudyDayConfigsTable,
      StudyDayConfig,
      $$StudyDayConfigsTableFilterComposer,
      $$StudyDayConfigsTableOrderingComposer,
      $$StudyDayConfigsTableAnnotationComposer,
      $$StudyDayConfigsTableCreateCompanionBuilder,
      $$StudyDayConfigsTableUpdateCompanionBuilder,
      (StudyDayConfig, $$StudyDayConfigsTableReferences),
      StudyDayConfig,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$CompletionEventsTableCreateCompanionBuilder =
    CompletionEventsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required String trackType,
      Value<int?> trackId,
      Value<int> points,
      required DateTime eventTimestamp,
      Value<DateTime> createdAt,
      Value<DateTime?> purgedAt,
    });
typedef $$CompletionEventsTableUpdateCompanionBuilder =
    CompletionEventsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> stageId,
      Value<String> trackType,
      Value<int?> trackId,
      Value<int> points,
      Value<DateTime> eventTimestamp,
      Value<DateTime> createdAt,
      Value<DateTime?> purgedAt,
    });

final class $$CompletionEventsTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $CompletionEventsTable,
          CompletionEvent
        > {
  $$CompletionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(
          db.completionEvents.profileId,
          db.learnerProfiles.id,
        ),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CompletionEventsTableFilterComposer
    extends Composer<_$UserDatabase, $CompletionEventsTable> {
  $$CompletionEventsTableFilterComposer({
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

  ColumnFilters<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventTimestamp => $composableBuilder(
    column: $table.eventTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get purgedAt => $composableBuilder(
    column: $table.purgedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionEventsTableOrderingComposer
    extends Composer<_$UserDatabase, $CompletionEventsTable> {
  $$CompletionEventsTableOrderingComposer({
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

  ColumnOrderings<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventTimestamp => $composableBuilder(
    column: $table.eventTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get purgedAt => $composableBuilder(
    column: $table.purgedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionEventsTableAnnotationComposer
    extends Composer<_$UserDatabase, $CompletionEventsTable> {
  $$CompletionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<int> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<DateTime> get eventTimestamp => $composableBuilder(
    column: $table.eventTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get purgedAt =>
      $composableBuilder(column: $table.purgedAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionEventsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $CompletionEventsTable,
          CompletionEvent,
          $$CompletionEventsTableFilterComposer,
          $$CompletionEventsTableOrderingComposer,
          $$CompletionEventsTableAnnotationComposer,
          $$CompletionEventsTableCreateCompanionBuilder,
          $$CompletionEventsTableUpdateCompanionBuilder,
          (CompletionEvent, $$CompletionEventsTableReferences),
          CompletionEvent,
          PrefetchHooks Function({bool profileId})
        > {
  $$CompletionEventsTableTableManager(
    _$UserDatabase db,
    $CompletionEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<int> stageId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<int?> trackId = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<DateTime> eventTimestamp = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> purgedAt = const Value.absent(),
              }) => CompletionEventsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                trackId: trackId,
                points: points,
                eventTimestamp: eventTimestamp,
                createdAt: createdAt,
                purgedAt: purgedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required String sefariaRef,
                required int stageId,
                required String trackType,
                Value<int?> trackId = const Value.absent(),
                Value<int> points = const Value.absent(),
                required DateTime eventTimestamp,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> purgedAt = const Value.absent(),
              }) => CompletionEventsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                trackId: trackId,
                points: points,
                eventTimestamp: eventTimestamp,
                createdAt: createdAt,
                purgedAt: purgedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CompletionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$CompletionEventsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$CompletionEventsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CompletionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $CompletionEventsTable,
      CompletionEvent,
      $$CompletionEventsTableFilterComposer,
      $$CompletionEventsTableOrderingComposer,
      $$CompletionEventsTableAnnotationComposer,
      $$CompletionEventsTableCreateCompanionBuilder,
      $$CompletionEventsTableUpdateCompanionBuilder,
      (CompletionEvent, $$CompletionEventsTableReferences),
      CompletionEvent,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$DailyPlansTableCreateCompanionBuilder =
    DailyPlansCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required DateTime planDate,
      required String sefariaRef,
      required int stageOrder,
      required int stageDefinitionId,
      required int trackId,
      Value<String> trackLabel,
      required String priority,
      Value<bool> isOverdue,
      Value<String> reason,
      Value<String> stageName,
      Value<int> estimatedEffortMinutes,
      Value<int> sortOrder,
      required DateTime createdAt,
    });
typedef $$DailyPlansTableUpdateCompanionBuilder =
    DailyPlansCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<DateTime> planDate,
      Value<String> sefariaRef,
      Value<int> stageOrder,
      Value<int> stageDefinitionId,
      Value<int> trackId,
      Value<String> trackLabel,
      Value<String> priority,
      Value<bool> isOverdue,
      Value<String> reason,
      Value<String> stageName,
      Value<int> estimatedEffortMinutes,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

class $$DailyPlansTableFilterComposer
    extends Composer<_$UserDatabase, $DailyPlansTable> {
  $$DailyPlansTableFilterComposer({
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

  ColumnFilters<DateTime> get planDate => $composableBuilder(
    column: $table.planDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageDefinitionId => $composableBuilder(
    column: $table.stageDefinitionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackLabel => $composableBuilder(
    column: $table.trackLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOverdue => $composableBuilder(
    column: $table.isOverdue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stageName => $composableBuilder(
    column: $table.stageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedEffortMinutes => $composableBuilder(
    column: $table.estimatedEffortMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyPlansTableOrderingComposer
    extends Composer<_$UserDatabase, $DailyPlansTable> {
  $$DailyPlansTableOrderingComposer({
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

  ColumnOrderings<DateTime> get planDate => $composableBuilder(
    column: $table.planDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageDefinitionId => $composableBuilder(
    column: $table.stageDefinitionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackLabel => $composableBuilder(
    column: $table.trackLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOverdue => $composableBuilder(
    column: $table.isOverdue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stageName => $composableBuilder(
    column: $table.stageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedEffortMinutes => $composableBuilder(
    column: $table.estimatedEffortMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyPlansTableAnnotationComposer
    extends Composer<_$UserDatabase, $DailyPlansTable> {
  $$DailyPlansTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get planDate =>
      $composableBuilder(column: $table.planDate, builder: (column) => column);

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageOrder => $composableBuilder(
    column: $table.stageOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageDefinitionId => $composableBuilder(
    column: $table.stageDefinitionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get trackLabel => $composableBuilder(
    column: $table.trackLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get isOverdue =>
      $composableBuilder(column: $table.isOverdue, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get stageName =>
      $composableBuilder(column: $table.stageName, builder: (column) => column);

  GeneratedColumn<int> get estimatedEffortMinutes => $composableBuilder(
    column: $table.estimatedEffortMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DailyPlansTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $DailyPlansTable,
          DailyPlan,
          $$DailyPlansTableFilterComposer,
          $$DailyPlansTableOrderingComposer,
          $$DailyPlansTableAnnotationComposer,
          $$DailyPlansTableCreateCompanionBuilder,
          $$DailyPlansTableUpdateCompanionBuilder,
          (
            DailyPlan,
            BaseReferences<_$UserDatabase, $DailyPlansTable, DailyPlan>,
          ),
          DailyPlan,
          PrefetchHooks Function()
        > {
  $$DailyPlansTableTableManager(_$UserDatabase db, $DailyPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<DateTime> planDate = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<int> stageOrder = const Value.absent(),
                Value<int> stageDefinitionId = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<String> trackLabel = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<bool> isOverdue = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> stageName = const Value.absent(),
                Value<int> estimatedEffortMinutes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DailyPlansCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                planDate: planDate,
                sefariaRef: sefariaRef,
                stageOrder: stageOrder,
                stageDefinitionId: stageDefinitionId,
                trackId: trackId,
                trackLabel: trackLabel,
                priority: priority,
                isOverdue: isOverdue,
                reason: reason,
                stageName: stageName,
                estimatedEffortMinutes: estimatedEffortMinutes,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required DateTime planDate,
                required String sefariaRef,
                required int stageOrder,
                required int stageDefinitionId,
                required int trackId,
                Value<String> trackLabel = const Value.absent(),
                required String priority,
                Value<bool> isOverdue = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> stageName = const Value.absent(),
                Value<int> estimatedEffortMinutes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
              }) => DailyPlansCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                planDate: planDate,
                sefariaRef: sefariaRef,
                stageOrder: stageOrder,
                stageDefinitionId: stageDefinitionId,
                trackId: trackId,
                trackLabel: trackLabel,
                priority: priority,
                isOverdue: isOverdue,
                reason: reason,
                stageName: stageName,
                estimatedEffortMinutes: estimatedEffortMinutes,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $DailyPlansTable,
      DailyPlan,
      $$DailyPlansTableFilterComposer,
      $$DailyPlansTableOrderingComposer,
      $$DailyPlansTableAnnotationComposer,
      $$DailyPlansTableCreateCompanionBuilder,
      $$DailyPlansTableUpdateCompanionBuilder,
      (DailyPlan, BaseReferences<_$UserDatabase, $DailyPlansTable, DailyPlan>),
      DailyPlan,
      PrefetchHooks Function()
    >;
typedef $$LearningLedgerTableCreateCompanionBuilder =
    LearningLedgerCompanion Function({
      Value<int> id,
      required int profileId,
      Value<String> ulid,
      required String curriculumId,
      required String entryScope,
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
      Value<String> ulid,
      Value<String> curriculumId,
      Value<String> entryScope,
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

final class $$LearningLedgerTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $LearningLedgerTable,
          LearningLedgerData
        > {
  $$LearningLedgerTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(
          db.learningLedger.profileId,
          db.learnerProfiles.id,
        ),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(db.learningLedger.trackId, db.curriculumTracks.id),
      );

  $$CurriculumTracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<int>('track_id');
    if ($_column == null) return null;
    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningLedgerTableFilterComposer
    extends Composer<_$UserDatabase, $LearningLedgerTable> {
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

  ColumnFilters<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryScope => $composableBuilder(
    column: $table.entryScope,
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

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningLedgerTableOrderingComposer
    extends Composer<_$UserDatabase, $LearningLedgerTable> {
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

  ColumnOrderings<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryScope => $composableBuilder(
    column: $table.entryScope,
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

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningLedgerTableAnnotationComposer
    extends Composer<_$UserDatabase, $LearningLedgerTable> {
  $$LearningLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ulid =>
      $composableBuilder(column: $table.ulid, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryScope => $composableBuilder(
    column: $table.entryScope,
    builder: (column) => column,
  );

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

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningLedgerTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $LearningLedgerTable,
          LearningLedgerData,
          $$LearningLedgerTableFilterComposer,
          $$LearningLedgerTableOrderingComposer,
          $$LearningLedgerTableAnnotationComposer,
          $$LearningLedgerTableCreateCompanionBuilder,
          $$LearningLedgerTableUpdateCompanionBuilder,
          (LearningLedgerData, $$LearningLedgerTableReferences),
          LearningLedgerData,
          PrefetchHooks Function({bool profileId, bool trackId})
        > {
  $$LearningLedgerTableTableManager(
    _$UserDatabase db,
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
                Value<String> ulid = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> entryScope = const Value.absent(),
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
                ulid: ulid,
                curriculumId: curriculumId,
                entryScope: entryScope,
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
                required int profileId,
                Value<String> ulid = const Value.absent(),
                required String curriculumId,
                required String entryScope,
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
                ulid: ulid,
                curriculumId: curriculumId,
                entryScope: entryScope,
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
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearningLedgerTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$LearningLedgerTableReferences
                                    ._profileIdTable(db),
                                referencedColumn:
                                    $$LearningLedgerTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$LearningLedgerTableReferences
                                    ._trackIdTable(db),
                                referencedColumn:
                                    $$LearningLedgerTableReferences
                                        ._trackIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $LearningLedgerTable,
      LearningLedgerData,
      $$LearningLedgerTableFilterComposer,
      $$LearningLedgerTableOrderingComposer,
      $$LearningLedgerTableAnnotationComposer,
      $$LearningLedgerTableCreateCompanionBuilder,
      $$LearningLedgerTableUpdateCompanionBuilder,
      (LearningLedgerData, $$LearningLedgerTableReferences),
      LearningLedgerData,
      PrefetchHooks Function({bool profileId, bool trackId})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required int trackId,
      required String sefariaRef,
      required DateTime updatedAt,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> trackId,
      Value<String> sefariaRef,
      Value<DateTime> updatedAt,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$UserDatabase, $BookmarksTable, Bookmark> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.bookmarks.profileId, db.learnerProfiles.id),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(db.bookmarks.trackId, db.curriculumTracks.id),
      );

  $$CurriculumTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$UserDatabase, $BookmarksTable> {
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

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
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

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$UserDatabase, $BookmarksTable> {
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

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
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

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$UserDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, $$BookmarksTableReferences),
          Bookmark,
          PrefetchHooks Function({bool profileId, bool trackId})
        > {
  $$BookmarksTableTableManager(_$UserDatabase db, $BookmarksTable table)
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
                Value<int> trackId = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                sefariaRef: sefariaRef,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required int trackId,
                required String sefariaRef,
                required DateTime updatedAt,
              }) => BookmarksCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                sefariaRef: sefariaRef,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$BookmarksTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$BookmarksTableReferences
                                    ._trackIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._trackIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, $$BookmarksTableReferences),
      Bookmark,
      PrefetchHooks Function({bool profileId, bool trackId})
    >;
typedef $$LearningOrderTableCreateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required String sefariaRef,
      required int userSortOrder,
      Value<DateTime> updatedAt,
      Value<int> learningOrderVersion,
    });
typedef $$LearningOrderTableUpdateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> userSortOrder,
      Value<DateTime> updatedAt,
      Value<int> learningOrderVersion,
    });

final class $$LearningOrderTableReferences
    extends
        BaseReferences<_$UserDatabase, $LearningOrderTable, LearningOrderData> {
  $$LearningOrderTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.learningOrder.profileId, db.learnerProfiles.id),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningOrderTableFilterComposer
    extends Composer<_$UserDatabase, $LearningOrderTable> {
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get learningOrderVersion => $composableBuilder(
    column: $table.learningOrderVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningOrderTableOrderingComposer
    extends Composer<_$UserDatabase, $LearningOrderTable> {
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get learningOrderVersion => $composableBuilder(
    column: $table.learningOrderVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningOrderTableAnnotationComposer
    extends Composer<_$UserDatabase, $LearningOrderTable> {
  $$LearningOrderTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get learningOrderVersion => $composableBuilder(
    column: $table.learningOrderVersion,
    builder: (column) => column,
  );

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningOrderTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $LearningOrderTable,
          LearningOrderData,
          $$LearningOrderTableFilterComposer,
          $$LearningOrderTableOrderingComposer,
          $$LearningOrderTableAnnotationComposer,
          $$LearningOrderTableCreateCompanionBuilder,
          $$LearningOrderTableUpdateCompanionBuilder,
          (LearningOrderData, $$LearningOrderTableReferences),
          LearningOrderData,
          PrefetchHooks Function({bool profileId})
        > {
  $$LearningOrderTableTableManager(_$UserDatabase db, $LearningOrderTable table)
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> learningOrderVersion = const Value.absent(),
              }) => LearningOrderCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                userSortOrder: userSortOrder,
                updatedAt: updatedAt,
                learningOrderVersion: learningOrderVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required String sefariaRef,
                required int userSortOrder,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> learningOrderVersion = const Value.absent(),
              }) => LearningOrderCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                userSortOrder: userSortOrder,
                updatedAt: updatedAt,
                learningOrderVersion: learningOrderVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearningOrderTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$LearningOrderTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$LearningOrderTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningOrderTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $LearningOrderTable,
      LearningOrderData,
      $$LearningOrderTableFilterComposer,
      $$LearningOrderTableOrderingComposer,
      $$LearningOrderTableAnnotationComposer,
      $$LearningOrderTableCreateCompanionBuilder,
      $$LearningOrderTableUpdateCompanionBuilder,
      (LearningOrderData, $$LearningOrderTableReferences),
      LearningOrderData,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$TrackLearningOrderTableCreateCompanionBuilder =
    TrackLearningOrderCompanion Function({
      Value<int> id,
      required int trackId,
      required String sefariaRef,
      required int sortOrder,
    });
typedef $$TrackLearningOrderTableUpdateCompanionBuilder =
    TrackLearningOrderCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<String> sefariaRef,
      Value<int> sortOrder,
    });

class $$TrackLearningOrderTableFilterComposer
    extends Composer<_$UserDatabase, $TrackLearningOrderTable> {
  $$TrackLearningOrderTableFilterComposer({
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

  ColumnFilters<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackLearningOrderTableOrderingComposer
    extends Composer<_$UserDatabase, $TrackLearningOrderTable> {
  $$TrackLearningOrderTableOrderingComposer({
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

  ColumnOrderings<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackLearningOrderTableAnnotationComposer
    extends Composer<_$UserDatabase, $TrackLearningOrderTable> {
  $$TrackLearningOrderTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$TrackLearningOrderTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $TrackLearningOrderTable,
          TrackLearningOrderData,
          $$TrackLearningOrderTableFilterComposer,
          $$TrackLearningOrderTableOrderingComposer,
          $$TrackLearningOrderTableAnnotationComposer,
          $$TrackLearningOrderTableCreateCompanionBuilder,
          $$TrackLearningOrderTableUpdateCompanionBuilder,
          (
            TrackLearningOrderData,
            BaseReferences<
              _$UserDatabase,
              $TrackLearningOrderTable,
              TrackLearningOrderData
            >,
          ),
          TrackLearningOrderData,
          PrefetchHooks Function()
        > {
  $$TrackLearningOrderTableTableManager(
    _$UserDatabase db,
    $TrackLearningOrderTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackLearningOrderTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackLearningOrderTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackLearningOrderTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => TrackLearningOrderCompanion(
                id: id,
                trackId: trackId,
                sefariaRef: sefariaRef,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required String sefariaRef,
                required int sortOrder,
              }) => TrackLearningOrderCompanion.insert(
                id: id,
                trackId: trackId,
                sefariaRef: sefariaRef,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackLearningOrderTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $TrackLearningOrderTable,
      TrackLearningOrderData,
      $$TrackLearningOrderTableFilterComposer,
      $$TrackLearningOrderTableOrderingComposer,
      $$TrackLearningOrderTableAnnotationComposer,
      $$TrackLearningOrderTableCreateCompanionBuilder,
      $$TrackLearningOrderTableUpdateCompanionBuilder,
      (
        TrackLearningOrderData,
        BaseReferences<
          _$UserDatabase,
          $TrackLearningOrderTable,
          TrackLearningOrderData
        >,
      ),
      TrackLearningOrderData,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required int trackId,
      Value<double> targetPercent,
      Value<DateTime?> targetDate,
      Value<String> description,
      Value<String> dateType,
      Value<String> goalType,
      Value<int?> paceValue,
      Value<String?> pacePeriod,
      Value<String?> paceGranularity,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<int> trackId,
      Value<double> targetPercent,
      Value<DateTime?> targetDate,
      Value<String> description,
      Value<String> dateType,
      Value<String> goalType,
      Value<int?> paceValue,
      Value<String?> pacePeriod,
      Value<String?> paceGranularity,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$GoalsTableReferences
    extends BaseReferences<_$UserDatabase, $GoalsTable, Goal> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.goals.profileId, db.learnerProfiles.id),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CurriculumTracksTable _trackIdTable(_$UserDatabase db) =>
      db.curriculumTracks.createAlias(
        $_aliasNameGenerator(db.goals.trackId, db.curriculumTracks.id),
      );

  $$CurriculumTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$CurriculumTracksTableTableManager(
      $_db,
      $_db.curriculumTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalsTableFilterComposer extends Composer<_$UserDatabase, $GoalsTable> {
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

  ColumnFilters<String> get pacePeriod => $composableBuilder(
    column: $table.pacePeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paceGranularity => $composableBuilder(
    column: $table.paceGranularity,
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

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableFilterComposer get trackId {
    final $$CurriculumTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableFilterComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$UserDatabase, $GoalsTable> {
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

  ColumnOrderings<String> get pacePeriod => $composableBuilder(
    column: $table.pacePeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paceGranularity => $composableBuilder(
    column: $table.paceGranularity,
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

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableOrderingComposer get trackId {
    final $$CurriculumTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableOrderingComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$UserDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<String> get pacePeriod => $composableBuilder(
    column: $table.pacePeriod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paceGranularity => $composableBuilder(
    column: $table.paceGranularity,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CurriculumTracksTableAnnotationComposer get trackId {
    final $$CurriculumTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.curriculumTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurriculumTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.curriculumTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, $$GoalsTableReferences),
          Goal,
          PrefetchHooks Function({bool profileId, bool trackId})
        > {
  $$GoalsTableTableManager(_$UserDatabase db, $GoalsTable table)
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
                Value<int> trackId = const Value.absent(),
                Value<double> targetPercent = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> dateType = const Value.absent(),
                Value<String> goalType = const Value.absent(),
                Value<int?> paceValue = const Value.absent(),
                Value<String?> pacePeriod = const Value.absent(),
                Value<String?> paceGranularity = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                targetPercent: targetPercent,
                targetDate: targetDate,
                description: description,
                dateType: dateType,
                goalType: goalType,
                paceValue: paceValue,
                pacePeriod: pacePeriod,
                paceGranularity: paceGranularity,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required int trackId,
                Value<double> targetPercent = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> dateType = const Value.absent(),
                Value<String> goalType = const Value.absent(),
                Value<int?> paceValue = const Value.absent(),
                Value<String?> pacePeriod = const Value.absent(),
                Value<String?> paceGranularity = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GoalsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                targetPercent: targetPercent,
                targetDate: targetDate,
                description: description,
                dateType: dateType,
                goalType: goalType,
                paceValue: paceValue,
                pacePeriod: pacePeriod,
                paceGranularity: paceGranularity,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GoalsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$GoalsTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$GoalsTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$GoalsTableReferences
                                    ._trackIdTable(db),
                                referencedColumn: $$GoalsTableReferences
                                    ._trackIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, $$GoalsTableReferences),
      Goal,
      PrefetchHooks Function({bool profileId, bool trackId})
    >;
typedef $$StreakEventsTableCreateCompanionBuilder =
    StreakEventsCompanion Function({
      Value<int> id,
      required int profileId,
      required String eventType,
      required DateTime dayUtc,
      required DateTime eventTimestamp,
      Value<String?> clientDeviceId,
      Value<DateTime> createdAt,
    });
typedef $$StreakEventsTableUpdateCompanionBuilder =
    StreakEventsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> eventType,
      Value<DateTime> dayUtc,
      Value<DateTime> eventTimestamp,
      Value<String?> clientDeviceId,
      Value<DateTime> createdAt,
    });

final class $$StreakEventsTableReferences
    extends BaseReferences<_$UserDatabase, $StreakEventsTable, StreakEvent> {
  $$StreakEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.streakEvents.profileId, db.learnerProfiles.id),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StreakEventsTableFilterComposer
    extends Composer<_$UserDatabase, $StreakEventsTable> {
  $$StreakEventsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dayUtc => $composableBuilder(
    column: $table.dayUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventTimestamp => $composableBuilder(
    column: $table.eventTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientDeviceId => $composableBuilder(
    column: $table.clientDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StreakEventsTableOrderingComposer
    extends Composer<_$UserDatabase, $StreakEventsTable> {
  $$StreakEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dayUtc => $composableBuilder(
    column: $table.dayUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventTimestamp => $composableBuilder(
    column: $table.eventTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientDeviceId => $composableBuilder(
    column: $table.clientDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StreakEventsTableAnnotationComposer
    extends Composer<_$UserDatabase, $StreakEventsTable> {
  $$StreakEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get dayUtc =>
      $composableBuilder(column: $table.dayUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get eventTimestamp => $composableBuilder(
    column: $table.eventTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientDeviceId => $composableBuilder(
    column: $table.clientDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StreakEventsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $StreakEventsTable,
          StreakEvent,
          $$StreakEventsTableFilterComposer,
          $$StreakEventsTableOrderingComposer,
          $$StreakEventsTableAnnotationComposer,
          $$StreakEventsTableCreateCompanionBuilder,
          $$StreakEventsTableUpdateCompanionBuilder,
          (StreakEvent, $$StreakEventsTableReferences),
          StreakEvent,
          PrefetchHooks Function({bool profileId})
        > {
  $$StreakEventsTableTableManager(_$UserDatabase db, $StreakEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<DateTime> dayUtc = const Value.absent(),
                Value<DateTime> eventTimestamp = const Value.absent(),
                Value<String?> clientDeviceId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StreakEventsCompanion(
                id: id,
                profileId: profileId,
                eventType: eventType,
                dayUtc: dayUtc,
                eventTimestamp: eventTimestamp,
                clientDeviceId: clientDeviceId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String eventType,
                required DateTime dayUtc,
                required DateTime eventTimestamp,
                Value<String?> clientDeviceId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StreakEventsCompanion.insert(
                id: id,
                profileId: profileId,
                eventType: eventType,
                dayUtc: dayUtc,
                eventTimestamp: eventTimestamp,
                clientDeviceId: clientDeviceId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StreakEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$StreakEventsTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$StreakEventsTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StreakEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $StreakEventsTable,
      StreakEvent,
      $$StreakEventsTableFilterComposer,
      $$StreakEventsTableOrderingComposer,
      $$StreakEventsTableAnnotationComposer,
      $$StreakEventsTableCreateCompanionBuilder,
      $$StreakEventsTableUpdateCompanionBuilder,
      (StreakEvent, $$StreakEventsTableReferences),
      StreakEvent,
      PrefetchHooks Function({bool profileId})
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
    extends Composer<_$UserDatabase, $TextDownloadStatusesTable> {
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
    extends Composer<_$UserDatabase, $TextDownloadStatusesTable> {
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
    extends Composer<_$UserDatabase, $TextDownloadStatusesTable> {
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
          _$UserDatabase,
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
              _$UserDatabase,
              $TextDownloadStatusesTable,
              TextDownloadStatuse
            >,
          ),
          TextDownloadStatuse,
          PrefetchHooks Function()
        > {
  $$TextDownloadStatusesTableTableManager(
    _$UserDatabase db,
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
      _$UserDatabase,
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
          _$UserDatabase,
          $TextDownloadStatusesTable,
          TextDownloadStatuse
        >,
      ),
      TextDownloadStatuse,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required int profileId,
      required String entityKind,
      required String entityKey,
      required String payload,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime?> lastAttemptAt,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> entityKind,
      Value<String> entityKey,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime?> lastAttemptAt,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$UserDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
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

  ColumnFilters<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$UserDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
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

  ColumnOrderings<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$UserDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
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

  GeneratedColumn<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxData,
            BaseReferences<_$UserDatabase, $OutboxTable, OutboxData>,
          ),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$UserDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> entityKind = const Value.absent(),
                Value<String> entityKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                profileId: profileId,
                entityKind: entityKind,
                entityKey: entityKey,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String entityKind,
                required String entityKey,
                required String payload,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                profileId: profileId,
                entityKind: entityKind,
                entityKey: entityKey,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$UserDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$SacredWindowEntriesTableCreateCompanionBuilder =
    SacredWindowEntriesCompanion Function({
      Value<int> id,
      required DateTime startUtc,
      required DateTime endUtc,
      required String kind,
      Value<double?> lat,
      Value<double?> lng,
      required bool inIsrael,
      Value<DateTime> createdAt,
    });
typedef $$SacredWindowEntriesTableUpdateCompanionBuilder =
    SacredWindowEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> startUtc,
      Value<DateTime> endUtc,
      Value<String> kind,
      Value<double?> lat,
      Value<double?> lng,
      Value<bool> inIsrael,
      Value<DateTime> createdAt,
    });

class $$SacredWindowEntriesTableFilterComposer
    extends Composer<_$UserDatabase, $SacredWindowEntriesTable> {
  $$SacredWindowEntriesTableFilterComposer({
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

  ColumnFilters<DateTime> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inIsrael => $composableBuilder(
    column: $table.inIsrael,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SacredWindowEntriesTableOrderingComposer
    extends Composer<_$UserDatabase, $SacredWindowEntriesTable> {
  $$SacredWindowEntriesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inIsrael => $composableBuilder(
    column: $table.inIsrael,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SacredWindowEntriesTableAnnotationComposer
    extends Composer<_$UserDatabase, $SacredWindowEntriesTable> {
  $$SacredWindowEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get endUtc =>
      $composableBuilder(column: $table.endUtc, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<bool> get inIsrael =>
      $composableBuilder(column: $table.inIsrael, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SacredWindowEntriesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $SacredWindowEntriesTable,
          SacredWindowEntry,
          $$SacredWindowEntriesTableFilterComposer,
          $$SacredWindowEntriesTableOrderingComposer,
          $$SacredWindowEntriesTableAnnotationComposer,
          $$SacredWindowEntriesTableCreateCompanionBuilder,
          $$SacredWindowEntriesTableUpdateCompanionBuilder,
          (
            SacredWindowEntry,
            BaseReferences<
              _$UserDatabase,
              $SacredWindowEntriesTable,
              SacredWindowEntry
            >,
          ),
          SacredWindowEntry,
          PrefetchHooks Function()
        > {
  $$SacredWindowEntriesTableTableManager(
    _$UserDatabase db,
    $SacredWindowEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SacredWindowEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SacredWindowEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SacredWindowEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startUtc = const Value.absent(),
                Value<DateTime> endUtc = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<bool> inIsrael = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SacredWindowEntriesCompanion(
                id: id,
                startUtc: startUtc,
                endUtc: endUtc,
                kind: kind,
                lat: lat,
                lng: lng,
                inIsrael: inIsrael,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startUtc,
                required DateTime endUtc,
                required String kind,
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                required bool inIsrael,
                Value<DateTime> createdAt = const Value.absent(),
              }) => SacredWindowEntriesCompanion.insert(
                id: id,
                startUtc: startUtc,
                endUtc: endUtc,
                kind: kind,
                lat: lat,
                lng: lng,
                inIsrael: inIsrael,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SacredWindowEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $SacredWindowEntriesTable,
      SacredWindowEntry,
      $$SacredWindowEntriesTableFilterComposer,
      $$SacredWindowEntriesTableOrderingComposer,
      $$SacredWindowEntriesTableAnnotationComposer,
      $$SacredWindowEntriesTableCreateCompanionBuilder,
      $$SacredWindowEntriesTableUpdateCompanionBuilder,
      (
        SacredWindowEntry,
        BaseReferences<
          _$UserDatabase,
          $SacredWindowEntriesTable,
          SacredWindowEntry
        >,
      ),
      SacredWindowEntry,
      PrefetchHooks Function()
    >;
typedef $$PriorCompletionImportsTableCreateCompanionBuilder =
    PriorCompletionImportsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required String trackType,
      required String source,
      Value<DateTime> importedAt,
    });
typedef $$PriorCompletionImportsTableUpdateCompanionBuilder =
    PriorCompletionImportsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> stageId,
      Value<String> trackType,
      Value<String> source,
      Value<DateTime> importedAt,
    });

final class $$PriorCompletionImportsTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $PriorCompletionImportsTable,
          PriorCompletionImport
        > {
  $$PriorCompletionImportsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(
          db.priorCompletionImports.profileId,
          db.learnerProfiles.id,
        ),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PriorCompletionImportsTableFilterComposer
    extends Composer<_$UserDatabase, $PriorCompletionImportsTable> {
  $$PriorCompletionImportsTableFilterComposer({
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriorCompletionImportsTableOrderingComposer
    extends Composer<_$UserDatabase, $PriorCompletionImportsTable> {
  $$PriorCompletionImportsTableOrderingComposer({
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriorCompletionImportsTableAnnotationComposer
    extends Composer<_$UserDatabase, $PriorCompletionImportsTable> {
  $$PriorCompletionImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriorCompletionImportsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $PriorCompletionImportsTable,
          PriorCompletionImport,
          $$PriorCompletionImportsTableFilterComposer,
          $$PriorCompletionImportsTableOrderingComposer,
          $$PriorCompletionImportsTableAnnotationComposer,
          $$PriorCompletionImportsTableCreateCompanionBuilder,
          $$PriorCompletionImportsTableUpdateCompanionBuilder,
          (PriorCompletionImport, $$PriorCompletionImportsTableReferences),
          PriorCompletionImport,
          PrefetchHooks Function({bool profileId})
        > {
  $$PriorCompletionImportsTableTableManager(
    _$UserDatabase db,
    $PriorCompletionImportsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriorCompletionImportsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PriorCompletionImportsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PriorCompletionImportsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<int> stageId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
              }) => PriorCompletionImportsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                source: source,
                importedAt: importedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required String sefariaRef,
                required int stageId,
                required String trackType,
                required String source,
                Value<DateTime> importedAt = const Value.absent(),
              }) => PriorCompletionImportsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                source: source,
                importedAt: importedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PriorCompletionImportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$PriorCompletionImportsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$PriorCompletionImportsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PriorCompletionImportsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $PriorCompletionImportsTable,
      PriorCompletionImport,
      $$PriorCompletionImportsTableFilterComposer,
      $$PriorCompletionImportsTableOrderingComposer,
      $$PriorCompletionImportsTableAnnotationComposer,
      $$PriorCompletionImportsTableCreateCompanionBuilder,
      $$PriorCompletionImportsTableUpdateCompanionBuilder,
      (PriorCompletionImport, $$PriorCompletionImportsTableReferences),
      PriorCompletionImport,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$SyncKvTableCreateCompanionBuilder =
    SyncKvCompanion Function({
      required String kind,
      required String entityKey,
      required int updatedAtMs,
      Value<int?> syncedAtMs,
      Value<int> rowid,
    });
typedef $$SyncKvTableUpdateCompanionBuilder =
    SyncKvCompanion Function({
      Value<String> kind,
      Value<String> entityKey,
      Value<int> updatedAtMs,
      Value<int?> syncedAtMs,
      Value<int> rowid,
    });

class $$SyncKvTableFilterComposer
    extends Composer<_$UserDatabase, $SyncKvTable> {
  $$SyncKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAtMs => $composableBuilder(
    column: $table.syncedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncKvTableOrderingComposer
    extends Composer<_$UserDatabase, $SyncKvTable> {
  $$SyncKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAtMs => $composableBuilder(
    column: $table.syncedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncKvTableAnnotationComposer
    extends Composer<_$UserDatabase, $SyncKvTable> {
  $$SyncKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedAtMs => $composableBuilder(
    column: $table.syncedAtMs,
    builder: (column) => column,
  );
}

class $$SyncKvTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $SyncKvTable,
          SyncKvData,
          $$SyncKvTableFilterComposer,
          $$SyncKvTableOrderingComposer,
          $$SyncKvTableAnnotationComposer,
          $$SyncKvTableCreateCompanionBuilder,
          $$SyncKvTableUpdateCompanionBuilder,
          (
            SyncKvData,
            BaseReferences<_$UserDatabase, $SyncKvTable, SyncKvData>,
          ),
          SyncKvData,
          PrefetchHooks Function()
        > {
  $$SyncKvTableTableManager(_$UserDatabase db, $SyncKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> entityKey = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> syncedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncKvCompanion(
                kind: kind,
                entityKey: entityKey,
                updatedAtMs: updatedAtMs,
                syncedAtMs: syncedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String entityKey,
                required int updatedAtMs,
                Value<int?> syncedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncKvCompanion.insert(
                kind: kind,
                entityKey: entityKey,
                updatedAtMs: updatedAtMs,
                syncedAtMs: syncedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncKvTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $SyncKvTable,
      SyncKvData,
      $$SyncKvTableFilterComposer,
      $$SyncKvTableOrderingComposer,
      $$SyncKvTableAnnotationComposer,
      $$SyncKvTableCreateCompanionBuilder,
      $$SyncKvTableUpdateCompanionBuilder,
      (SyncKvData, BaseReferences<_$UserDatabase, $SyncKvTable, SyncKvData>),
      SyncKvData,
      PrefetchHooks Function()
    >;
typedef $$PointsBalanceTableCreateCompanionBuilder =
    PointsBalanceCompanion Function({
      Value<int> profileId,
      Value<int> balance,
      required DateTime updatedAt,
    });
typedef $$PointsBalanceTableUpdateCompanionBuilder =
    PointsBalanceCompanion Function({
      Value<int> profileId,
      Value<int> balance,
      Value<DateTime> updatedAt,
    });

final class $$PointsBalanceTableReferences
    extends
        BaseReferences<_$UserDatabase, $PointsBalanceTable, PointsBalanceData> {
  $$PointsBalanceTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.pointsBalance.profileId, db.learnerProfiles.id),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PointsBalanceTableFilterComposer
    extends Composer<_$UserDatabase, $PointsBalanceTable> {
  $$PointsBalanceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsBalanceTableOrderingComposer
    extends Composer<_$UserDatabase, $PointsBalanceTable> {
  $$PointsBalanceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsBalanceTableAnnotationComposer
    extends Composer<_$UserDatabase, $PointsBalanceTable> {
  $$PointsBalanceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsBalanceTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $PointsBalanceTable,
          PointsBalanceData,
          $$PointsBalanceTableFilterComposer,
          $$PointsBalanceTableOrderingComposer,
          $$PointsBalanceTableAnnotationComposer,
          $$PointsBalanceTableCreateCompanionBuilder,
          $$PointsBalanceTableUpdateCompanionBuilder,
          (PointsBalanceData, $$PointsBalanceTableReferences),
          PointsBalanceData,
          PrefetchHooks Function({bool profileId})
        > {
  $$PointsBalanceTableTableManager(_$UserDatabase db, $PointsBalanceTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsBalanceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsBalanceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsBalanceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<int> balance = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PointsBalanceCompanion(
                profileId: profileId,
                balance: balance,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<int> balance = const Value.absent(),
                required DateTime updatedAt,
              }) => PointsBalanceCompanion.insert(
                profileId: profileId,
                balance: balance,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PointsBalanceTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$PointsBalanceTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$PointsBalanceTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PointsBalanceTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $PointsBalanceTable,
      PointsBalanceData,
      $$PointsBalanceTableFilterComposer,
      $$PointsBalanceTableOrderingComposer,
      $$PointsBalanceTableAnnotationComposer,
      $$PointsBalanceTableCreateCompanionBuilder,
      $$PointsBalanceTableUpdateCompanionBuilder,
      (PointsBalanceData, $$PointsBalanceTableReferences),
      PointsBalanceData,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$PointsLedgerTableCreateCompanionBuilder =
    PointsLedgerCompanion Function({
      Value<int> id,
      required int profileId,
      required String entryKind,
      required int delta,
      Value<String?> note,
      Value<int?> redemptionId,
      required DateTime createdAt,
      Value<String?> ulid,
      Value<DateTime?> syncEnqueuedAt,
    });
typedef $$PointsLedgerTableUpdateCompanionBuilder =
    PointsLedgerCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> entryKind,
      Value<int> delta,
      Value<String?> note,
      Value<int?> redemptionId,
      Value<DateTime> createdAt,
      Value<String?> ulid,
      Value<DateTime?> syncEnqueuedAt,
    });

final class $$PointsLedgerTableReferences
    extends
        BaseReferences<_$UserDatabase, $PointsLedgerTable, PointsLedgerData> {
  $$PointsLedgerTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.pointsLedger.profileId, db.learnerProfiles.id),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PointsLedgerTableFilterComposer
    extends Composer<_$UserDatabase, $PointsLedgerTable> {
  $$PointsLedgerTableFilterComposer({
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

  ColumnFilters<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get redemptionId => $composableBuilder(
    column: $table.redemptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncEnqueuedAt => $composableBuilder(
    column: $table.syncEnqueuedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsLedgerTableOrderingComposer
    extends Composer<_$UserDatabase, $PointsLedgerTable> {
  $$PointsLedgerTableOrderingComposer({
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

  ColumnOrderings<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get redemptionId => $composableBuilder(
    column: $table.redemptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncEnqueuedAt => $composableBuilder(
    column: $table.syncEnqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsLedgerTableAnnotationComposer
    extends Composer<_$UserDatabase, $PointsLedgerTable> {
  $$PointsLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entryKind =>
      $composableBuilder(column: $table.entryKind, builder: (column) => column);

  GeneratedColumn<int> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get redemptionId => $composableBuilder(
    column: $table.redemptionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get ulid =>
      $composableBuilder(column: $table.ulid, builder: (column) => column);

  GeneratedColumn<DateTime> get syncEnqueuedAt => $composableBuilder(
    column: $table.syncEnqueuedAt,
    builder: (column) => column,
  );

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsLedgerTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $PointsLedgerTable,
          PointsLedgerData,
          $$PointsLedgerTableFilterComposer,
          $$PointsLedgerTableOrderingComposer,
          $$PointsLedgerTableAnnotationComposer,
          $$PointsLedgerTableCreateCompanionBuilder,
          $$PointsLedgerTableUpdateCompanionBuilder,
          (PointsLedgerData, $$PointsLedgerTableReferences),
          PointsLedgerData,
          PrefetchHooks Function({bool profileId})
        > {
  $$PointsLedgerTableTableManager(_$UserDatabase db, $PointsLedgerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> entryKind = const Value.absent(),
                Value<int> delta = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> redemptionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> ulid = const Value.absent(),
                Value<DateTime?> syncEnqueuedAt = const Value.absent(),
              }) => PointsLedgerCompanion(
                id: id,
                profileId: profileId,
                entryKind: entryKind,
                delta: delta,
                note: note,
                redemptionId: redemptionId,
                createdAt: createdAt,
                ulid: ulid,
                syncEnqueuedAt: syncEnqueuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String entryKind,
                required int delta,
                Value<String?> note = const Value.absent(),
                Value<int?> redemptionId = const Value.absent(),
                required DateTime createdAt,
                Value<String?> ulid = const Value.absent(),
                Value<DateTime?> syncEnqueuedAt = const Value.absent(),
              }) => PointsLedgerCompanion.insert(
                id: id,
                profileId: profileId,
                entryKind: entryKind,
                delta: delta,
                note: note,
                redemptionId: redemptionId,
                createdAt: createdAt,
                ulid: ulid,
                syncEnqueuedAt: syncEnqueuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PointsLedgerTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$PointsLedgerTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$PointsLedgerTableReferences
                                    ._profileIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PointsLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $PointsLedgerTable,
      PointsLedgerData,
      $$PointsLedgerTableFilterComposer,
      $$PointsLedgerTableOrderingComposer,
      $$PointsLedgerTableAnnotationComposer,
      $$PointsLedgerTableCreateCompanionBuilder,
      $$PointsLedgerTableUpdateCompanionBuilder,
      (PointsLedgerData, $$PointsLedgerTableReferences),
      PointsLedgerData,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$RewardRedemptionsTableCreateCompanionBuilder =
    RewardRedemptionsCompanion Function({
      Value<int> id,
      required int profileId,
      required String rewardTitle,
      Value<int> iconIndex,
      required int pointsCost,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> ulid,
    });
typedef $$RewardRedemptionsTableUpdateCompanionBuilder =
    RewardRedemptionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> rewardTitle,
      Value<int> iconIndex,
      Value<int> pointsCost,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> ulid,
    });

final class $$RewardRedemptionsTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $RewardRedemptionsTable,
          RewardRedemption
        > {
  $$RewardRedemptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(
          db.rewardRedemptions.profileId,
          db.learnerProfiles.id,
        ),
      );

  $$LearnerProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$LearnerProfilesTableTableManager(
      $_db,
      $_db.learnerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RewardRedemptionsTableFilterComposer
    extends Composer<_$UserDatabase, $RewardRedemptionsTable> {
  $$RewardRedemptionsTableFilterComposer({
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

  ColumnFilters<String> get rewardTitle => $composableBuilder(
    column: $table.rewardTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconIndex => $composableBuilder(
    column: $table.iconIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsCost => $composableBuilder(
    column: $table.pointsCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnFilters(column),
  );

  $$LearnerProfilesTableFilterComposer get profileId {
    final $$LearnerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RewardRedemptionsTableOrderingComposer
    extends Composer<_$UserDatabase, $RewardRedemptionsTable> {
  $$RewardRedemptionsTableOrderingComposer({
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

  ColumnOrderings<String> get rewardTitle => $composableBuilder(
    column: $table.rewardTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconIndex => $composableBuilder(
    column: $table.iconIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsCost => $composableBuilder(
    column: $table.pointsCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearnerProfilesTableOrderingComposer get profileId {
    final $$LearnerProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RewardRedemptionsTableAnnotationComposer
    extends Composer<_$UserDatabase, $RewardRedemptionsTable> {
  $$RewardRedemptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rewardTitle => $composableBuilder(
    column: $table.rewardTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get iconIndex =>
      $composableBuilder(column: $table.iconIndex, builder: (column) => column);

  GeneratedColumn<int> get pointsCost => $composableBuilder(
    column: $table.pointsCost,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get ulid =>
      $composableBuilder(column: $table.ulid, builder: (column) => column);

  $$LearnerProfilesTableAnnotationComposer get profileId {
    final $$LearnerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.learnerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RewardRedemptionsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $RewardRedemptionsTable,
          RewardRedemption,
          $$RewardRedemptionsTableFilterComposer,
          $$RewardRedemptionsTableOrderingComposer,
          $$RewardRedemptionsTableAnnotationComposer,
          $$RewardRedemptionsTableCreateCompanionBuilder,
          $$RewardRedemptionsTableUpdateCompanionBuilder,
          (RewardRedemption, $$RewardRedemptionsTableReferences),
          RewardRedemption,
          PrefetchHooks Function({bool profileId})
        > {
  $$RewardRedemptionsTableTableManager(
    _$UserDatabase db,
    $RewardRedemptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardRedemptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardRedemptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardRedemptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> rewardTitle = const Value.absent(),
                Value<int> iconIndex = const Value.absent(),
                Value<int> pointsCost = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> ulid = const Value.absent(),
              }) => RewardRedemptionsCompanion(
                id: id,
                profileId: profileId,
                rewardTitle: rewardTitle,
                iconIndex: iconIndex,
                pointsCost: pointsCost,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                ulid: ulid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String rewardTitle,
                Value<int> iconIndex = const Value.absent(),
                required int pointsCost,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> ulid = const Value.absent(),
              }) => RewardRedemptionsCompanion.insert(
                id: id,
                profileId: profileId,
                rewardTitle: rewardTitle,
                iconIndex: iconIndex,
                pointsCost: pointsCost,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                ulid: ulid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RewardRedemptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$RewardRedemptionsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$RewardRedemptionsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RewardRedemptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $RewardRedemptionsTable,
      RewardRedemption,
      $$RewardRedemptionsTableFilterComposer,
      $$RewardRedemptionsTableOrderingComposer,
      $$RewardRedemptionsTableAnnotationComposer,
      $$RewardRedemptionsTableCreateCompanionBuilder,
      $$RewardRedemptionsTableUpdateCompanionBuilder,
      (RewardRedemption, $$RewardRedemptionsTableReferences),
      RewardRedemption,
      PrefetchHooks Function({bool profileId})
    >;

class $UserDatabaseManager {
  final _$UserDatabase _db;
  $UserDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(_db, _db.learnerProfiles);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(_db, _db.curriculumTracks);
  $$CurriculumScopesTableTableManager get curriculumScopes =>
      $$CurriculumScopesTableTableManager(_db, _db.curriculumScopes);
  $$ProfileProgramsTableTableManager get profilePrograms =>
      $$ProfileProgramsTableTableManager(_db, _db.profilePrograms);
  $$StageDefinitionsTableTableManager get stageDefinitions =>
      $$StageDefinitionsTableTableManager(_db, _db.stageDefinitions);
  $$PointConfigsTableTableManager get pointConfigs =>
      $$PointConfigsTableTableManager(_db, _db.pointConfigs);
  $$StudyDayConfigsTableTableManager get studyDayConfigs =>
      $$StudyDayConfigsTableTableManager(_db, _db.studyDayConfigs);
  $$CompletionEventsTableTableManager get completionEvents =>
      $$CompletionEventsTableTableManager(_db, _db.completionEvents);
  $$DailyPlansTableTableManager get dailyPlans =>
      $$DailyPlansTableTableManager(_db, _db.dailyPlans);
  $$LearningLedgerTableTableManager get learningLedger =>
      $$LearningLedgerTableTableManager(_db, _db.learningLedger);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$LearningOrderTableTableManager get learningOrder =>
      $$LearningOrderTableTableManager(_db, _db.learningOrder);
  $$TrackLearningOrderTableTableManager get trackLearningOrder =>
      $$TrackLearningOrderTableTableManager(_db, _db.trackLearningOrder);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$StreakEventsTableTableManager get streakEvents =>
      $$StreakEventsTableTableManager(_db, _db.streakEvents);
  $$TextDownloadStatusesTableTableManager get textDownloadStatuses =>
      $$TextDownloadStatusesTableTableManager(_db, _db.textDownloadStatuses);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SacredWindowEntriesTableTableManager get sacredWindowEntries =>
      $$SacredWindowEntriesTableTableManager(_db, _db.sacredWindowEntries);
  $$PriorCompletionImportsTableTableManager get priorCompletionImports =>
      $$PriorCompletionImportsTableTableManager(
        _db,
        _db.priorCompletionImports,
      );
  $$SyncKvTableTableManager get syncKv =>
      $$SyncKvTableTableManager(_db, _db.syncKv);
  $$PointsBalanceTableTableManager get pointsBalance =>
      $$PointsBalanceTableTableManager(_db, _db.pointsBalance);
  $$PointsLedgerTableTableManager get pointsLedger =>
      $$PointsLedgerTableTableManager(_db, _db.pointsLedger);
  $$RewardRedemptionsTableTableManager get rewardRedemptions =>
      $$RewardRedemptionsTableTableManager(_db, _db.rewardRedemptions);
}
