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
    email,
    firebaseUid,
    passwordHash,
    tier,
    displayName,
    userMode,
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
  final String userMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Account({
    required this.id,
    required this.email,
    this.firebaseUid,
    this.passwordHash,
    required this.tier,
    required this.displayName,
    required this.userMode,
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
    map['user_mode'] = Variable<String>(userMode);
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
      userMode: Value(userMode),
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
      'email': serializer.toJson<String>(email),
      'firebaseUid': serializer.toJson<String?>(firebaseUid),
      'passwordHash': serializer.toJson<String?>(passwordHash),
      'tier': serializer.toJson<String>(tier),
      'displayName': serializer.toJson<String>(displayName),
      'userMode': serializer.toJson<String>(userMode),
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
    String? userMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Account(
    id: id ?? this.id,
    email: email ?? this.email,
    firebaseUid: firebaseUid.present ? firebaseUid.value : this.firebaseUid,
    passwordHash: passwordHash.present ? passwordHash.value : this.passwordHash,
    tier: tier ?? this.tier,
    displayName: displayName ?? this.displayName,
    userMode: userMode ?? this.userMode,
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
      userMode: data.userMode.present ? data.userMode.value : this.userMode,
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
          ..write('userMode: $userMode, ')
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
    userMode,
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
          other.userMode == this.userMode &&
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
  final Value<String> userMode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.tier = const Value.absent(),
    this.displayName = const Value.absent(),
    this.userMode = const Value.absent(),
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
    required String userMode,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : email = Value(email),
       tier = Value(tier),
       displayName = Value(displayName),
       userMode = Value(userMode),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? email,
    Expression<String>? firebaseUid,
    Expression<String>? passwordHash,
    Expression<String>? tier,
    Expression<String>? displayName,
    Expression<String>? userMode,
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
      if (userMode != null) 'user_mode': userMode,
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
    Value<String>? userMode,
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
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('tier: $tier, ')
          ..write('displayName: $displayName, ')
          ..write('userMode: $userMode, ')
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
    );
  }

  @override
  $LearnerProfilesTable createAlias(String alias) {
    return $LearnerProfilesTable(attachedDatabase, alias);
  }
}

class LearnerProfile extends DataClass implements Insertable<LearnerProfile> {
  final int id;
  final int accountId;
  final String displayName;
  final String mode;
  final int avatarIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LearnerProfile({
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

  LearnerProfilesCompanion toCompanion(bool nullToAbsent) {
    return LearnerProfilesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      displayName: Value(displayName),
      mode: Value(mode),
      avatarIndex: Value(avatarIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
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

  LearnerProfile copyWith({
    int? id,
    int? accountId,
    String? displayName,
    String? mode,
    int? avatarIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LearnerProfile(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    displayName: displayName ?? this.displayName,
    mode: mode ?? this.mode,
    avatarIndex: avatarIndex ?? this.avatarIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
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
      (other is LearnerProfile &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.displayName == this.displayName &&
          other.mode == this.mode &&
          other.avatarIndex == this.avatarIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LearnerProfilesCompanion extends UpdateCompanion<LearnerProfile> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> displayName;
  final Value<String> mode;
  final Value<int> avatarIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LearnerProfilesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.mode = const Value.absent(),
    this.avatarIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LearnerProfilesCompanion.insert({
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
  static Insertable<LearnerProfile> custom({
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

  LearnerProfilesCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? displayName,
    Value<String>? mode,
    Value<int>? avatarIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LearnerProfilesCompanion(
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
    return (StringBuffer('LearnerProfilesCompanion(')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
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
    trackType,
    isActive,
    activatedAt,
    deactivatedAt,
    paceResetDate,
    deletedAt,
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
    if (data.containsKey('pace_reset_date')) {
      context.handle(
        _paceResetDateMeta,
        paceResetDate.isAcceptableOrUnknown(
          data['pace_reset_date']!,
          _paceResetDateMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
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
      paceResetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pace_reset_date'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
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

  /// track_type from TrackType enum storageKey
  final String trackType;

  /// Whether this track is currently active for this curriculum
  final bool isActive;

  /// When this track was activated (or reactivated) for this curriculum
  final DateTime activatedAt;

  /// When this track was last deactivated (null if currently active)
  final DateTime? deactivatedAt;

  /// Date when pace was last reset (for Reset Pace recovery action).
  /// Null if pace has never been reset.
  final DateTime? paceResetDate;

  /// When this track was soft-deleted (null if not deleted).
  ///
  /// Tracks are never hard-deleted; setting this field is the only allowed
  /// delete operation. Any non-null value means the track is logically deleted.
  final DateTime? deletedAt;
  const CurriculumTrack({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackType,
    required this.isActive,
    required this.activatedAt,
    this.deactivatedAt,
    this.paceResetDate,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_type'] = Variable<String>(trackType);
    map['is_active'] = Variable<bool>(isActive);
    map['activated_at'] = Variable<DateTime>(activatedAt);
    if (!nullToAbsent || deactivatedAt != null) {
      map['deactivated_at'] = Variable<DateTime>(deactivatedAt);
    }
    if (!nullToAbsent || paceResetDate != null) {
      map['pace_reset_date'] = Variable<DateTime>(paceResetDate);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CurriculumTracksCompanion toCompanion(bool nullToAbsent) {
    return CurriculumTracksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      curriculumId: Value(curriculumId),
      trackType: Value(trackType),
      isActive: Value(isActive),
      activatedAt: Value(activatedAt),
      deactivatedAt: deactivatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deactivatedAt),
      paceResetDate: paceResetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(paceResetDate),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
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
      trackType: serializer.fromJson<String>(json['trackType']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      activatedAt: serializer.fromJson<DateTime>(json['activatedAt']),
      deactivatedAt: serializer.fromJson<DateTime?>(json['deactivatedAt']),
      paceResetDate: serializer.fromJson<DateTime?>(json['paceResetDate']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
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
      'isActive': serializer.toJson<bool>(isActive),
      'activatedAt': serializer.toJson<DateTime>(activatedAt),
      'deactivatedAt': serializer.toJson<DateTime?>(deactivatedAt),
      'paceResetDate': serializer.toJson<DateTime?>(paceResetDate),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CurriculumTrack copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? trackType,
    bool? isActive,
    DateTime? activatedAt,
    Value<DateTime?> deactivatedAt = const Value.absent(),
    Value<DateTime?> paceResetDate = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CurriculumTrack(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackType: trackType ?? this.trackType,
    isActive: isActive ?? this.isActive,
    activatedAt: activatedAt ?? this.activatedAt,
    deactivatedAt: deactivatedAt.present
        ? deactivatedAt.value
        : this.deactivatedAt,
    paceResetDate: paceResetDate.present
        ? paceResetDate.value
        : this.paceResetDate,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CurriculumTrack copyWithCompanion(CurriculumTracksCompanion data) {
    return CurriculumTrack(
      id: data.id.present ? data.id.value : this.id,
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
      paceResetDate: data.paceResetDate.present
          ? data.paceResetDate.value
          : this.paceResetDate,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumTrack(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('isActive: $isActive, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('deactivatedAt: $deactivatedAt, ')
          ..write('paceResetDate: $paceResetDate, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    curriculumId,
    trackType,
    isActive,
    activatedAt,
    deactivatedAt,
    paceResetDate,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurriculumTrack &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.curriculumId == this.curriculumId &&
          other.trackType == this.trackType &&
          other.isActive == this.isActive &&
          other.activatedAt == this.activatedAt &&
          other.deactivatedAt == this.deactivatedAt &&
          other.paceResetDate == this.paceResetDate &&
          other.deletedAt == this.deletedAt);
}

class CurriculumTracksCompanion extends UpdateCompanion<CurriculumTrack> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> trackType;
  final Value<bool> isActive;
  final Value<DateTime> activatedAt;
  final Value<DateTime?> deactivatedAt;
  final Value<DateTime?> paceResetDate;
  final Value<DateTime?> deletedAt;
  const CurriculumTracksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.isActive = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.deactivatedAt = const Value.absent(),
    this.paceResetDate = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  CurriculumTracksCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required String trackType,
    this.isActive = const Value.absent(),
    required DateTime activatedAt,
    this.deactivatedAt = const Value.absent(),
    this.paceResetDate = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackType = Value(trackType),
       activatedAt = Value(activatedAt);
  static Insertable<CurriculumTrack> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? trackType,
    Expression<bool>? isActive,
    Expression<DateTime>? activatedAt,
    Expression<DateTime>? deactivatedAt,
    Expression<DateTime>? paceResetDate,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackType != null) 'track_type': trackType,
      if (isActive != null) 'is_active': isActive,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (deactivatedAt != null) 'deactivated_at': deactivatedAt,
      if (paceResetDate != null) 'pace_reset_date': paceResetDate,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  CurriculumTracksCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? trackType,
    Value<bool>? isActive,
    Value<DateTime>? activatedAt,
    Value<DateTime?>? deactivatedAt,
    Value<DateTime?>? paceResetDate,
    Value<DateTime?>? deletedAt,
  }) {
    return CurriculumTracksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackType: trackType ?? this.trackType,
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      paceResetDate: paceResetDate ?? this.paceResetDate,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<DateTime>(activatedAt.value);
    }
    if (deactivatedAt.present) {
      map['deactivated_at'] = Variable<DateTime>(deactivatedAt.value);
    }
    if (paceResetDate.present) {
      map['pace_reset_date'] = Variable<DateTime>(paceResetDate.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumTracksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('isActive: $isActive, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('deactivatedAt: $deactivatedAt, ')
          ..write('paceResetDate: $paceResetDate, ')
          ..write('deletedAt: $deletedAt')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    trackId,
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
  final int trackId;

  /// Which hierarchy level the scope applies to (1-4, matching level1-level4).
  final int scopeLevel;

  /// The value at that level (e.g., "Seder Zeraim", "Berachos").
  final String scopeValue;
  final DateTime createdAt;
  const CurriculumScope({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
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
    map['track_id'] = Variable<int>(trackId);
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
      trackId: Value(trackId),
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
      trackId: serializer.fromJson<int>(json['trackId']),
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
      'trackId': serializer.toJson<int>(trackId),
      'scopeLevel': serializer.toJson<int>(scopeLevel),
      'scopeValue': serializer.toJson<String>(scopeValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
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
  }) => CurriculumScope(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    trackId: trackId ?? this.trackId,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
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
          ..write('trackId: $trackId, ')
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
    trackId,
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
          other.trackId == this.trackId &&
          other.scopeLevel == this.scopeLevel &&
          other.scopeValue == this.scopeValue &&
          other.createdAt == this.createdAt);
}

class CurriculumScopesCompanion extends UpdateCompanion<CurriculumScope> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<int> trackId;
  final Value<int> scopeLevel;
  final Value<String> scopeValue;
  final Value<DateTime> createdAt;
  const CurriculumScopesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.scopeLevel = const Value.absent(),
    this.scopeValue = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CurriculumScopesCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int scopeLevel,
    required String scopeValue,
    required DateTime createdAt,
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
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackId != null) 'track_id': trackId,
      if (scopeLevel != null) 'scope_level': scopeLevel,
      if (scopeValue != null) 'scope_value': scopeValue,
      if (createdAt != null) 'created_at': createdAt,
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
  }) {
    return CurriculumScopesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      trackId: trackId ?? this.trackId,
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
          ..write('createdAt: $createdAt')
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
    trackId,
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final int trackId;
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
    required this.trackId,
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
    map['track_id'] = Variable<int>(trackId);
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
      trackId: Value(trackId),
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
      trackId: serializer.fromJson<int>(json['trackId']),
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
      'trackId': serializer.toJson<int>(trackId),
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
    int? trackId,
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
    trackId: trackId ?? this.trackId,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
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
          ..write('trackId: $trackId, ')
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
    trackId,
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
          other.trackId == this.trackId &&
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
  final Value<int> trackId;
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
    this.trackId = const Value.absent(),
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
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    this.isDefault = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.daysOfWeek = const Value.absent(),
    this.rollingWindowSize = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       trackId = Value(trackId),
       stageOrder = Value(stageOrder),
       stageName = Value(stageName),
       delayDays = Value(delayDays);
  static Insertable<StageDefinition> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<int>? trackId,
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
      if (trackId != null) 'track_id': trackId,
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
    Value<int>? trackId,
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
      trackId: trackId ?? this.trackId,
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
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
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
          ..write('trackId: $trackId, ')
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES curriculum_tracks (id)',
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
  static const VerificationMeta _derivedFromEventsMeta = const VerificationMeta(
    'derivedFromEvents',
  );
  @override
  late final GeneratedColumn<bool> derivedFromEvents = GeneratedColumn<bool>(
    'derived_from_events',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("derived_from_events" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    completedAt,
    points,
    derivedFromEvents,
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
    } else if (isInserting) {
      context.missing(_trackIdMeta);
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
    if (data.containsKey('derived_from_events')) {
      context.handle(
        _derivedFromEventsMeta,
        derivedFromEvents.isAcceptableOrUnknown(
          data['derived_from_events']!,
          _derivedFromEventsMeta,
        ),
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
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      derivedFromEvents: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}derived_from_events'],
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;
  final int trackId;
  final DateTime completedAt;
  final int points;

  /// C1: true when this row was derived from a completion_events write.
  /// false for legacy rows written before C1 was deployed.
  final bool derivedFromEvents;
  const Completion({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    required this.trackId,
    required this.completedAt,
    required this.points,
    required this.derivedFromEvents,
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
    map['track_id'] = Variable<int>(trackId);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['points'] = Variable<int>(points);
    map['derived_from_events'] = Variable<bool>(derivedFromEvents);
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
      trackId: Value(trackId),
      completedAt: Value(completedAt),
      points: Value(points),
      derivedFromEvents: Value(derivedFromEvents),
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
      trackId: serializer.fromJson<int>(json['trackId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      points: serializer.fromJson<int>(json['points']),
      derivedFromEvents: serializer.fromJson<bool>(json['derivedFromEvents']),
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
      'trackId': serializer.toJson<int>(trackId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'points': serializer.toJson<int>(points),
      'derivedFromEvents': serializer.toJson<bool>(derivedFromEvents),
    };
  }

  Completion copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? stageId,
    String? trackType,
    int? trackId,
    DateTime? completedAt,
    int? points,
    bool? derivedFromEvents,
  }) => Completion(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    stageId: stageId ?? this.stageId,
    trackType: trackType ?? this.trackType,
    trackId: trackId ?? this.trackId,
    completedAt: completedAt ?? this.completedAt,
    points: points ?? this.points,
    derivedFromEvents: derivedFromEvents ?? this.derivedFromEvents,
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
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      points: data.points.present ? data.points.value : this.points,
      derivedFromEvents: data.derivedFromEvents.present
          ? data.derivedFromEvents.value
          : this.derivedFromEvents,
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
          ..write('trackId: $trackId, ')
          ..write('completedAt: $completedAt, ')
          ..write('points: $points, ')
          ..write('derivedFromEvents: $derivedFromEvents')
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
    completedAt,
    points,
    derivedFromEvents,
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
          other.trackId == this.trackId &&
          other.completedAt == this.completedAt &&
          other.points == this.points &&
          other.derivedFromEvents == this.derivedFromEvents);
}

class CompletionsCompanion extends UpdateCompanion<Completion> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> stageId;
  final Value<String> trackType;
  final Value<int> trackId;
  final Value<DateTime> completedAt;
  final Value<int> points;
  final Value<bool> derivedFromEvents;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.stageId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.trackId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.points = const Value.absent(),
    this.derivedFromEvents = const Value.absent(),
  });
  CompletionsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required int trackId,
    required DateTime completedAt,
    this.points = const Value.absent(),
    this.derivedFromEvents = const Value.absent(),
  }) : profileId = Value(profileId),
       curriculumId = Value(curriculumId),
       sefariaRef = Value(sefariaRef),
       stageId = Value(stageId),
       trackType = Value(trackType),
       trackId = Value(trackId),
       completedAt = Value(completedAt);
  static Insertable<Completion> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? curriculumId,
    Expression<String>? sefariaRef,
    Expression<int>? stageId,
    Expression<String>? trackType,
    Expression<int>? trackId,
    Expression<DateTime>? completedAt,
    Expression<int>? points,
    Expression<bool>? derivedFromEvents,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (stageId != null) 'stage_id': stageId,
      if (trackType != null) 'track_type': trackType,
      if (trackId != null) 'track_id': trackId,
      if (completedAt != null) 'completed_at': completedAt,
      if (points != null) 'points': points,
      if (derivedFromEvents != null) 'derived_from_events': derivedFromEvents,
    });
  }

  CompletionsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? stageId,
    Value<String>? trackType,
    Value<int>? trackId,
    Value<DateTime>? completedAt,
    Value<int>? points,
    Value<bool>? derivedFromEvents,
  }) {
    return CompletionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      stageId: stageId ?? this.stageId,
      trackType: trackType ?? this.trackType,
      trackId: trackId ?? this.trackId,
      completedAt: completedAt ?? this.completedAt,
      points: points ?? this.points,
      derivedFromEvents: derivedFromEvents ?? this.derivedFromEvents,
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
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (derivedFromEvents.present) {
      map['derived_from_events'] = Variable<bool>(derivedFromEvents.value);
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
          ..write('trackId: $trackId, ')
          ..write('completedAt: $completedAt, ')
          ..write('points: $points, ')
          ..write('derivedFromEvents: $derivedFromEvents')
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
    if (data.containsKey('unit_type')) {
      context.handle(
        _entryScopeMeta,
        entryScope.isAcceptableOrUnknown(data['unit_type']!, _entryScopeMeta),
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

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  final int profileId;

  /// ULID identifying the logical ledger entry across devices. Two devices
  /// writing the same entry use the same ULID so the UNIQUE composite
  /// `(profileId, ulid)` collapses duplicates. Auto-generated client-side
  /// when omitted on insert.
  final String ulid;
  final String curriculumId;
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
    map['unit_type'] = Variable<String>(entryScope);
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
      if (entryScope != null) 'unit_type': entryScope,
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
      map['unit_type'] = Variable<String>(entryScope.value);
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    curriculumId,
    sefariaRef,
    userSortOrder,
    updatedAt,
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
  final DateTime updatedAt;
  const LearningOrderData({
    required this.id,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.userSortOrder,
    required this.updatedAt,
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
    };
  }

  LearningOrderData copyWith({
    int? id,
    int? profileId,
    String? curriculumId,
    String? sefariaRef,
    int? userSortOrder,
    DateTime? updatedAt,
  }) => LearningOrderData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    curriculumId: curriculumId ?? this.curriculumId,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    userSortOrder: userSortOrder ?? this.userSortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
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
          ..write('updatedAt: $updatedAt')
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
          other.updatedAt == this.updatedAt);
}

class LearningOrderCompanion extends UpdateCompanion<LearningOrderData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> curriculumId;
  final Value<String> sefariaRef;
  final Value<int> userSortOrder;
  final Value<DateTime> updatedAt;
  const LearningOrderCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.userSortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LearningOrderCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int userSortOrder,
    this.updatedAt = const Value.absent(),
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
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (userSortOrder != null) 'user_sort_order': userSortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LearningOrderCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? curriculumId,
    Value<String>? sefariaRef,
    Value<int>? userSortOrder,
    Value<DateTime>? updatedAt,
  }) {
    return LearningOrderCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      curriculumId: curriculumId ?? this.curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      userSortOrder: userSortOrder ?? this.userSortOrder,
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
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (userSortOrder.present) {
      map['user_sort_order'] = Variable<int>(userSortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
          ..write('updatedAt: $updatedAt')
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
    'pace_unit',
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
    if (data.containsKey('pace_unit')) {
      context.handle(
        _pacePeriodMeta,
        pacePeriod.isAcceptableOrUnknown(data['pace_unit']!, _pacePeriodMeta),
      );
    }
    if (data.containsKey('learning_unit')) {
      context.handle(
        _paceGranularityMeta,
        paceGranularity.isAcceptableOrUnknown(
          data['learning_unit']!,
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
        data['${effectivePrefix}pace_unit'],
      ),
      paceGranularity: attachedDatabase.typeMapping.read(
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
      map['pace_unit'] = Variable<String>(pacePeriod);
    }
    if (!nullToAbsent || paceGranularity != null) {
      map['learning_unit'] = Variable<String>(paceGranularity);
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
      if (pacePeriod != null) 'pace_unit': pacePeriod,
      if (paceGranularity != null) 'learning_unit': paceGranularity,
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
      map['pace_unit'] = Variable<String>(pacePeriod.value);
    }
    if (paceGranularity.present) {
      map['learning_unit'] = Variable<String>(paceGranularity.value);
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
    requiredDuringInsert: true,
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
    defaultValue: const Constant<int>(0),
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
    defaultValue: const Constant<int>(0),
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
    } else if (isInserting) {
      context.missing(_profileIdMeta);
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
    required int profileId,
    this.currentStreak = const Value.absent(),
    this.maxStreak = const Value.absent(),
    this.lastCompletionDate = const Value.absent(),
    this.graceUsedDate = const Value.absent(),
    this.gracePeriodDays = const Value.absent(),
  }) : profileId = Value(profileId);
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
  static const VerificationMeta _entityKeyMeta = const VerificationMeta(
    'entityKey',
  );
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'entity_key',
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
    entityKey,
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
    if (data.containsKey('entity_key')) {
      context.handle(
        _entityKeyMeta,
        entityKey.isAcceptableOrUnknown(data['entity_key']!, _entityKeyMeta),
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
      entityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_key'],
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

  /// I-5: Stable entity key for dedup (e.g. "track_config:42", "profile:1").
  /// Null for operations that do not require dedup (legacy callers, one-off events).
  /// UNIQUE — INSERT OR REPLACE on this key keeps only the latest payload.
  final String? entityKey;
  const SyncQueueData({
    required this.id,
    required this.operationType,
    required this.payload,
    required this.queuedAt,
    required this.retryCount,
    this.lastError,
    this.entityKey,
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
    if (!nullToAbsent || entityKey != null) {
      map['entity_key'] = Variable<String>(entityKey);
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
      entityKey: entityKey == null && nullToAbsent
          ? const Value.absent()
          : Value(entityKey),
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
      entityKey: serializer.fromJson<String?>(json['entityKey']),
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
      'entityKey': serializer.toJson<String?>(entityKey),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? operationType,
    String? payload,
    DateTime? queuedAt,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    Value<String?> entityKey = const Value.absent(),
  }) => SyncQueueData(
    id: id ?? this.id,
    operationType: operationType ?? this.operationType,
    payload: payload ?? this.payload,
    queuedAt: queuedAt ?? this.queuedAt,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    entityKey: entityKey.present ? entityKey.value : this.entityKey,
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
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
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
          ..write('lastError: $lastError, ')
          ..write('entityKey: $entityKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationType,
    payload,
    queuedAt,
    retryCount,
    lastError,
    entityKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.operationType == this.operationType &&
          other.payload == this.payload &&
          other.queuedAt == this.queuedAt &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.entityKey == this.entityKey);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> operationType;
  final Value<String> payload;
  final Value<DateTime> queuedAt;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<String?> entityKey;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payload = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.entityKey = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String operationType,
    required String payload,
    required DateTime queuedAt,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.entityKey = const Value.absent(),
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
    Expression<String>? entityKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationType != null) 'operation_type': operationType,
      if (payload != null) 'payload': payload,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (entityKey != null) 'entity_key': entityKey,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? operationType,
    Value<String>? payload,
    Value<DateTime>? queuedAt,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<String?>? entityKey,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      entityKey: entityKey ?? this.entityKey,
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
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
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
          ..write('lastError: $lastError, ')
          ..write('entityKey: $entityKey')
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
  late final $CompletionsTable completions = $CompletionsTable(this);
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
  late final $StreaksTable streaks = $StreaksTable(this);
  late final $StreakEventsTable streakEvents = $StreakEventsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $TextDownloadStatusesTable textDownloadStatuses =
      $TextDownloadStatusesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SacredWindowEntriesTable sacredWindowEntries =
      $SacredWindowEntriesTable(this);
  late final Index completionsPidxPidCurCompleted = Index(
    'completions_pidx_pid_cur_completed',
    'CREATE INDEX completions_pidx_pid_cur_completed ON completions (profile_id, curriculum_id, completed_at DESC)',
  );
  late final Index completionsNaturalKey = Index(
    'completions_natural_key',
    'CREATE INDEX completions_natural_key ON completions (profile_id, sefaria_ref, stage_id, track_type)',
  );
  late final Index completionEventsNaturalKey = Index(
    'completion_events_natural_key',
    'CREATE UNIQUE INDEX completion_events_natural_key ON completion_events (profile_id, sefaria_ref, stage_id, track_type)',
  );
  late final Index learningLedgerProfileCreated = Index(
    'learning_ledger_profile_created',
    'CREATE INDEX learning_ledger_profile_created ON learning_ledger (profile_id, created_at)',
  );
  late final Index learningLedgerProfileUlid = Index(
    'learning_ledger_profile_ulid',
    'CREATE UNIQUE INDEX learning_ledger_profile_ulid ON learning_ledger (profile_id, ulid)',
  );
  late final Index streakEventsNaturalKey = Index(
    'streak_events_natural_key',
    'CREATE UNIQUE INDEX streak_events_natural_key ON streak_events (profile_id, day_utc, event_type)',
  );
  late final Index syncQueueEntityKey = Index(
    'sync_queue_entity_key',
    'CREATE UNIQUE INDEX sync_queue_entity_key ON sync_queue (entity_key)',
  );
  late final Index outboxProfileKind = Index(
    'outbox_profile_kind',
    'CREATE INDEX outbox_profile_kind ON outbox (profile_id, entity_kind)',
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
  late final StreakDao streakDao = StreakDao(this as UserDatabase);
  late final StreakEventDao streakEventDao = StreakEventDao(
    this as UserDatabase,
  );
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as UserDatabase);
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
    completions,
    completionEvents,
    dailyPlans,
    learningLedger,
    bookmarks,
    learningOrder,
    trackLearningOrder,
    goals,
    streaks,
    streakEvents,
    syncQueue,
    textDownloadStatuses,
    outbox,
    sacredWindowEntries,
    completionsPidxPidCurCompleted,
    completionsNaturalKey,
    completionEventsNaturalKey,
    learningLedgerProfileCreated,
    learningLedgerProfileUlid,
    streakEventsNaturalKey,
    syncQueueEntityKey,
    outboxProfileKind,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
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
      result: [TableUpdate('completions', kind: UpdateKind.delete)],
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
      result: [TableUpdate('goals', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learner_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('streak_events', kind: UpdateKind.delete)],
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
      required String userMode,
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
      Value<String> userMode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

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

  GeneratedColumn<String> get userMode =>
      $composableBuilder(column: $table.userMode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
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
          (Account, BaseReferences<_$UserDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
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
                Value<String> userMode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                email: email,
                firebaseUid: firebaseUid,
                passwordHash: passwordHash,
                tier: tier,
                displayName: displayName,
                userMode: userMode,
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
                required String userMode,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => AccountsCompanion.insert(
                id: id,
                email: email,
                firebaseUid: firebaseUid,
                passwordHash: passwordHash,
                tier: tier,
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
      (Account, BaseReferences<_$UserDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
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
    });

final class $$LearnerProfilesTableReferences
    extends
        BaseReferences<_$UserDatabase, $LearnerProfilesTable, LearnerProfile> {
  $$LearnerProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

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

  static MultiTypedResultKey<$CompletionsTable, List<Completion>>
  _completionsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.completions,
    aliasName: $_aliasNameGenerator(
      db.learnerProfiles.id,
      db.completions.profileId,
    ),
  );

  $$CompletionsTableProcessedTableManager get completionsRefs {
    final manager = $$CompletionsTableTableManager(
      $_db,
      $_db.completions,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_completionsRefsTable($_db));
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

  Expression<bool> completionsRefs(
    Expression<bool> Function($$CompletionsTableFilterComposer f) f,
  ) {
    final $$CompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableFilterComposer(
            $db: $db,
            $table: $db.completions,
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

  Expression<T> completionsRefs<T extends Object>(
    Expression<T> Function($$CompletionsTableAnnotationComposer a) f,
  ) {
    final $$CompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.completions,
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
            bool stageDefinitionsRefs,
            bool completionsRefs,
            bool completionEventsRefs,
            bool learningLedgerRefs,
            bool bookmarksRefs,
            bool goalsRefs,
            bool streakEventsRefs,
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
              }) => LearnerProfilesCompanion(
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
              }) => LearnerProfilesCompanion.insert(
                id: id,
                accountId: accountId,
                displayName: displayName,
                mode: mode,
                avatarIndex: avatarIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
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
                stageDefinitionsRefs = false,
                completionsRefs = false,
                completionEventsRefs = false,
                learningLedgerRefs = false,
                bookmarksRefs = false,
                goalsRefs = false,
                streakEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stageDefinitionsRefs) db.stageDefinitions,
                    if (completionsRefs) db.completions,
                    if (completionEventsRefs) db.completionEvents,
                    if (learningLedgerRefs) db.learningLedger,
                    if (bookmarksRefs) db.bookmarks,
                    if (goalsRefs) db.goals,
                    if (streakEventsRefs) db.streakEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
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
                      if (completionsRefs)
                        await $_getPrefetchedData<
                          LearnerProfile,
                          $LearnerProfilesTable,
                          Completion
                        >(
                          currentTable: table,
                          referencedTable: $$LearnerProfilesTableReferences
                              ._completionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearnerProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).completionsRefs,
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
        bool stageDefinitionsRefs,
        bool completionsRefs,
        bool completionEventsRefs,
        bool learningLedgerRefs,
        bool bookmarksRefs,
        bool goalsRefs,
        bool streakEventsRefs,
      })
    >;
typedef $$CurriculumTracksTableCreateCompanionBuilder =
    CurriculumTracksCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required String trackType,
      Value<bool> isActive,
      required DateTime activatedAt,
      Value<DateTime?> deactivatedAt,
      Value<DateTime?> paceResetDate,
      Value<DateTime?> deletedAt,
    });
typedef $$CurriculumTracksTableUpdateCompanionBuilder =
    CurriculumTracksCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> trackType,
      Value<bool> isActive,
      Value<DateTime> activatedAt,
      Value<DateTime?> deactivatedAt,
      Value<DateTime?> paceResetDate,
      Value<DateTime?> deletedAt,
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

  static MultiTypedResultKey<$CompletionsTable, List<Completion>>
  _completionsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.completions,
    aliasName: $_aliasNameGenerator(
      db.curriculumTracks.id,
      db.completions.trackId,
    ),
  );

  $$CompletionsTableProcessedTableManager get completionsRefs {
    final manager = $$CompletionsTableTableManager(
      $_db,
      $_db.completions,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_completionsRefsTable($_db));
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

  ColumnFilters<DateTime> get paceResetDate => $composableBuilder(
    column: $table.paceResetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  Expression<bool> completionsRefs(
    Expression<bool> Function($$CompletionsTableFilterComposer f) f,
  ) {
    final $$CompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableFilterComposer(
            $db: $db,
            $table: $db.completions,
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

  ColumnOrderings<DateTime> get paceResetDate => $composableBuilder(
    column: $table.paceResetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<DateTime> get paceResetDate => $composableBuilder(
    column: $table.paceResetDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

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

  Expression<T> completionsRefs<T extends Object>(
    Expression<T> Function($$CompletionsTableAnnotationComposer a) f,
  ) {
    final $$CompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.completions,
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
            bool completionsRefs,
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
                Value<String> trackType = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> activatedAt = const Value.absent(),
                Value<DateTime?> deactivatedAt = const Value.absent(),
                Value<DateTime?> paceResetDate = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => CurriculumTracksCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                isActive: isActive,
                activatedAt: activatedAt,
                deactivatedAt: deactivatedAt,
                paceResetDate: paceResetDate,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required String trackType,
                Value<bool> isActive = const Value.absent(),
                required DateTime activatedAt,
                Value<DateTime?> deactivatedAt = const Value.absent(),
                Value<DateTime?> paceResetDate = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => CurriculumTracksCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackType: trackType,
                isActive: isActive,
                activatedAt: activatedAt,
                deactivatedAt: deactivatedAt,
                paceResetDate: paceResetDate,
                deletedAt: deletedAt,
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
                completionsRefs = false,
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
                    if (completionsRefs) db.completions,
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
                      if (completionsRefs)
                        await $_getPrefetchedData<
                          CurriculumTrack,
                          $CurriculumTracksTable,
                          Completion
                        >(
                          currentTable: table,
                          referencedTable: $$CurriculumTracksTableReferences
                              ._completionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CurriculumTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).completionsRefs,
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
        bool completionsRefs,
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
          PrefetchHooks Function({bool trackId})
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
              }) => CurriculumScopesCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                scopeLevel: scopeLevel,
                scopeValue: scopeValue,
                createdAt: createdAt,
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
              }) => CurriculumScopesCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                scopeLevel: scopeLevel,
                scopeValue: scopeValue,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CurriculumScopesTableReferences(db, table, e),
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
      PrefetchHooks Function({bool trackId})
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
      Value<int> trackId,
      Value<int> stageOrder,
      Value<String> stageName,
      Value<int> delayDays,
      Value<bool> isDefault,
      Value<String> scheduleType,
      Value<String?> daysOfWeek,
      Value<int?> rollingWindowSize,
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
                Value<int> delayDays = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String> scheduleType = const Value.absent(),
                Value<String?> daysOfWeek = const Value.absent(),
                Value<int?> rollingWindowSize = const Value.absent(),
              }) => StageDefinitionsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
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
                required int profileId,
                required String curriculumId,
                required int trackId,
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
                trackId: trackId,
                stageOrder: stageOrder,
                stageName: stageName,
                delayDays: delayDays,
                isDefault: isDefault,
                scheduleType: scheduleType,
                daysOfWeek: daysOfWeek,
                rollingWindowSize: rollingWindowSize,
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
typedef $$CompletionsTableCreateCompanionBuilder =
    CompletionsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required String trackType,
      required int trackId,
      required DateTime completedAt,
      Value<int> points,
      Value<bool> derivedFromEvents,
    });
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> stageId,
      Value<String> trackType,
      Value<int> trackId,
      Value<DateTime> completedAt,
      Value<int> points,
      Value<bool> derivedFromEvents,
    });

final class $$CompletionsTableReferences
    extends BaseReferences<_$UserDatabase, $CompletionsTable, Completion> {
  $$CompletionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LearnerProfilesTable _profileIdTable(_$UserDatabase db) =>
      db.learnerProfiles.createAlias(
        $_aliasNameGenerator(db.completions.profileId, db.learnerProfiles.id),
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
        $_aliasNameGenerator(db.completions.trackId, db.curriculumTracks.id),
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

class $$CompletionsTableFilterComposer
    extends Composer<_$UserDatabase, $CompletionsTable> {
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

  ColumnFilters<bool> get derivedFromEvents => $composableBuilder(
    column: $table.derivedFromEvents,
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

class $$CompletionsTableOrderingComposer
    extends Composer<_$UserDatabase, $CompletionsTable> {
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

  ColumnOrderings<bool> get derivedFromEvents => $composableBuilder(
    column: $table.derivedFromEvents,
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

class $$CompletionsTableAnnotationComposer
    extends Composer<_$UserDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<bool> get derivedFromEvents => $composableBuilder(
    column: $table.derivedFromEvents,
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

class $$CompletionsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $CompletionsTable,
          Completion,
          $$CompletionsTableFilterComposer,
          $$CompletionsTableOrderingComposer,
          $$CompletionsTableAnnotationComposer,
          $$CompletionsTableCreateCompanionBuilder,
          $$CompletionsTableUpdateCompanionBuilder,
          (Completion, $$CompletionsTableReferences),
          Completion,
          PrefetchHooks Function({bool profileId, bool trackId})
        > {
  $$CompletionsTableTableManager(_$UserDatabase db, $CompletionsTable table)
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
                Value<int> trackId = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<bool> derivedFromEvents = const Value.absent(),
              }) => CompletionsCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                trackId: trackId,
                completedAt: completedAt,
                points: points,
                derivedFromEvents: derivedFromEvents,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required String sefariaRef,
                required int stageId,
                required String trackType,
                required int trackId,
                required DateTime completedAt,
                Value<int> points = const Value.absent(),
                Value<bool> derivedFromEvents = const Value.absent(),
              }) => CompletionsCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: stageId,
                trackType: trackType,
                trackId: trackId,
                completedAt: completedAt,
                points: points,
                derivedFromEvents: derivedFromEvents,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CompletionsTableReferences(db, table, e),
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
                                referencedTable: $$CompletionsTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$CompletionsTableReferences
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
                                referencedTable: $$CompletionsTableReferences
                                    ._trackIdTable(db),
                                referencedColumn: $$CompletionsTableReferences
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

typedef $$CompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $CompletionsTable,
      Completion,
      $$CompletionsTableFilterComposer,
      $$CompletionsTableOrderingComposer,
      $$CompletionsTableAnnotationComposer,
      $$CompletionsTableCreateCompanionBuilder,
      $$CompletionsTableUpdateCompanionBuilder,
      (Completion, $$CompletionsTableReferences),
      Completion,
      PrefetchHooks Function({bool profileId, bool trackId})
    >;
typedef $$CompletionEventsTableCreateCompanionBuilder =
    CompletionEventsCompanion Function({
      Value<int> id,
      required int profileId,
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required String trackType,
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
    });
typedef $$LearningOrderTableUpdateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> curriculumId,
      Value<String> sefariaRef,
      Value<int> userSortOrder,
      Value<DateTime> updatedAt,
    });

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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
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
          (
            LearningOrderData,
            BaseReferences<
              _$UserDatabase,
              $LearningOrderTable,
              LearningOrderData
            >,
          ),
          LearningOrderData,
          PrefetchHooks Function()
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
              }) => LearningOrderCompanion(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                userSortOrder: userSortOrder,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String curriculumId,
                required String sefariaRef,
                required int userSortOrder,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LearningOrderCompanion.insert(
                id: id,
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                userSortOrder: userSortOrder,
                updatedAt: updatedAt,
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
      _$UserDatabase,
      $LearningOrderTable,
      LearningOrderData,
      $$LearningOrderTableFilterComposer,
      $$LearningOrderTableOrderingComposer,
      $$LearningOrderTableAnnotationComposer,
      $$LearningOrderTableCreateCompanionBuilder,
      $$LearningOrderTableUpdateCompanionBuilder,
      (
        LearningOrderData,
        BaseReferences<_$UserDatabase, $LearningOrderTable, LearningOrderData>,
      ),
      LearningOrderData,
      PrefetchHooks Function()
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
typedef $$StreaksTableCreateCompanionBuilder =
    StreaksCompanion Function({
      Value<int> id,
      required int profileId,
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
    extends Composer<_$UserDatabase, $StreaksTable> {
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
    extends Composer<_$UserDatabase, $StreaksTable> {
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
    extends Composer<_$UserDatabase, $StreaksTable> {
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
          _$UserDatabase,
          $StreaksTable,
          Streak,
          $$StreaksTableFilterComposer,
          $$StreaksTableOrderingComposer,
          $$StreaksTableAnnotationComposer,
          $$StreaksTableCreateCompanionBuilder,
          $$StreaksTableUpdateCompanionBuilder,
          (Streak, BaseReferences<_$UserDatabase, $StreaksTable, Streak>),
          Streak,
          PrefetchHooks Function()
        > {
  $$StreaksTableTableManager(_$UserDatabase db, $StreaksTable table)
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
                required int profileId,
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
      _$UserDatabase,
      $StreaksTable,
      Streak,
      $$StreaksTableFilterComposer,
      $$StreaksTableOrderingComposer,
      $$StreaksTableAnnotationComposer,
      $$StreaksTableCreateCompanionBuilder,
      $$StreaksTableUpdateCompanionBuilder,
      (Streak, BaseReferences<_$UserDatabase, $StreaksTable, Streak>),
      Streak,
      PrefetchHooks Function()
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
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String operationType,
      required String payload,
      required DateTime queuedAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<String?> entityKey,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> operationType,
      Value<String> payload,
      Value<DateTime> queuedAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<String?> entityKey,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$UserDatabase, $SyncQueueTable> {
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

  ColumnFilters<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$UserDatabase, $SyncQueueTable> {
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

  ColumnOrderings<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$UserDatabase, $SyncQueueTable> {
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

  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$UserDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$UserDatabase db, $SyncQueueTable table)
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
                Value<String?> entityKey = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                operationType: operationType,
                payload: payload,
                queuedAt: queuedAt,
                retryCount: retryCount,
                lastError: lastError,
                entityKey: entityKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationType,
                required String payload,
                required DateTime queuedAt,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> entityKey = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                operationType: operationType,
                payload: payload,
                queuedAt: queuedAt,
                retryCount: retryCount,
                lastError: lastError,
                entityKey: entityKey,
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
      _$UserDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$UserDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
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
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
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
  $$StreaksTableTableManager get streaks =>
      $$StreaksTableTableManager(_db, _db.streaks);
  $$StreakEventsTableTableManager get streakEvents =>
      $$StreakEventsTableTableManager(_db, _db.streakEvents);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$TextDownloadStatusesTableTableManager get textDownloadStatuses =>
      $$TextDownloadStatusesTableTableManager(_db, _db.textDownloadStatuses);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SacredWindowEntriesTableTableManager get sacredWindowEntries =>
      $$SacredWindowEntriesTableTableManager(_db, _db.sacredWindowEntries);
}
