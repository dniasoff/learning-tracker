// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ContentItemsTable extends ContentItems
    with TableInfo<$ContentItemsTable, ContentItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _level1Meta = const VerificationMeta('level1');
  @override
  late final GeneratedColumn<String> level1 = GeneratedColumn<String>(
    'level1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _level2Meta = const VerificationMeta('level2');
  @override
  late final GeneratedColumn<String> level2 = GeneratedColumn<String>(
    'level2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _level3Meta = const VerificationMeta('level3');
  @override
  late final GeneratedColumn<String> level3 = GeneratedColumn<String>(
    'level3',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _level4Meta = const VerificationMeta('level4');
  @override
  late final GeneratedColumn<String> level4 = GeneratedColumn<String>(
    'level4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameHeMeta = const VerificationMeta(
    'displayNameHe',
  );
  @override
  late final GeneratedColumn<String> displayNameHe = GeneratedColumn<String>(
    'display_name_he',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameEnMeta = const VerificationMeta(
    'displayNameEn',
  );
  @override
  late final GeneratedColumn<String> displayNameEn = GeneratedColumn<String>(
    'display_name_en',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _isLeafMeta = const VerificationMeta('isLeaf');
  @override
  late final GeneratedColumn<bool> isLeaf = GeneratedColumn<bool>(
    'is_leaf',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_leaf" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    curriculumId,
    level1,
    level2,
    level3,
    level4,
    displayNameHe,
    displayNameEn,
    sefariaRef,
    sortOrder,
    isLeaf,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('level1')) {
      context.handle(
        _level1Meta,
        level1.isAcceptableOrUnknown(data['level1']!, _level1Meta),
      );
    } else if (isInserting) {
      context.missing(_level1Meta);
    }
    if (data.containsKey('level2')) {
      context.handle(
        _level2Meta,
        level2.isAcceptableOrUnknown(data['level2']!, _level2Meta),
      );
    }
    if (data.containsKey('level3')) {
      context.handle(
        _level3Meta,
        level3.isAcceptableOrUnknown(data['level3']!, _level3Meta),
      );
    }
    if (data.containsKey('level4')) {
      context.handle(
        _level4Meta,
        level4.isAcceptableOrUnknown(data['level4']!, _level4Meta),
      );
    }
    if (data.containsKey('display_name_he')) {
      context.handle(
        _displayNameHeMeta,
        displayNameHe.isAcceptableOrUnknown(
          data['display_name_he']!,
          _displayNameHeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameHeMeta);
    }
    if (data.containsKey('display_name_en')) {
      context.handle(
        _displayNameEnMeta,
        displayNameEn.isAcceptableOrUnknown(
          data['display_name_en']!,
          _displayNameEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameEnMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('is_leaf')) {
      context.handle(
        _isLeafMeta,
        isLeaf.isAcceptableOrUnknown(data['is_leaf']!, _isLeafMeta),
      );
    } else if (isInserting) {
      context.missing(_isLeafMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {curriculumId, level1, level2, level3, level4},
  ];
  @override
  ContentItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      level1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level1'],
      )!,
      level2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level2'],
      ),
      level3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level3'],
      ),
      level4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level4'],
      ),
      displayNameHe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_he'],
      )!,
      displayNameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_en'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isLeaf: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_leaf'],
      )!,
    );
  }

  @override
  $ContentItemsTable createAlias(String alias) {
    return $ContentItemsTable(attachedDatabase, alias);
  }
}

class ContentItem extends DataClass implements Insertable<ContentItem> {
  final int id;
  final String curriculumId;
  final String level1;
  final String? level2;
  final String? level3;
  final String? level4;
  final String displayNameHe;
  final String displayNameEn;
  final String? sefariaRef;
  final int sortOrder;
  final bool isLeaf;
  const ContentItem({
    required this.id,
    required this.curriculumId,
    required this.level1,
    this.level2,
    this.level3,
    this.level4,
    required this.displayNameHe,
    required this.displayNameEn,
    this.sefariaRef,
    required this.sortOrder,
    required this.isLeaf,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['level1'] = Variable<String>(level1);
    if (!nullToAbsent || level2 != null) {
      map['level2'] = Variable<String>(level2);
    }
    if (!nullToAbsent || level3 != null) {
      map['level3'] = Variable<String>(level3);
    }
    if (!nullToAbsent || level4 != null) {
      map['level4'] = Variable<String>(level4);
    }
    map['display_name_he'] = Variable<String>(displayNameHe);
    map['display_name_en'] = Variable<String>(displayNameEn);
    if (!nullToAbsent || sefariaRef != null) {
      map['sefaria_ref'] = Variable<String>(sefariaRef);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_leaf'] = Variable<bool>(isLeaf);
    return map;
  }

  ContentItemsCompanion toCompanion(bool nullToAbsent) {
    return ContentItemsCompanion(
      id: Value(id),
      curriculumId: Value(curriculumId),
      level1: Value(level1),
      level2: level2 == null && nullToAbsent
          ? const Value.absent()
          : Value(level2),
      level3: level3 == null && nullToAbsent
          ? const Value.absent()
          : Value(level3),
      level4: level4 == null && nullToAbsent
          ? const Value.absent()
          : Value(level4),
      displayNameHe: Value(displayNameHe),
      displayNameEn: Value(displayNameEn),
      sefariaRef: sefariaRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sefariaRef),
      sortOrder: Value(sortOrder),
      isLeaf: Value(isLeaf),
    );
  }

  factory ContentItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentItem(
      id: serializer.fromJson<int>(json['id']),
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      level1: serializer.fromJson<String>(json['level1']),
      level2: serializer.fromJson<String?>(json['level2']),
      level3: serializer.fromJson<String?>(json['level3']),
      level4: serializer.fromJson<String?>(json['level4']),
      displayNameHe: serializer.fromJson<String>(json['displayNameHe']),
      displayNameEn: serializer.fromJson<String>(json['displayNameEn']),
      sefariaRef: serializer.fromJson<String?>(json['sefariaRef']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isLeaf: serializer.fromJson<bool>(json['isLeaf']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'level1': serializer.toJson<String>(level1),
      'level2': serializer.toJson<String?>(level2),
      'level3': serializer.toJson<String?>(level3),
      'level4': serializer.toJson<String?>(level4),
      'displayNameHe': serializer.toJson<String>(displayNameHe),
      'displayNameEn': serializer.toJson<String>(displayNameEn),
      'sefariaRef': serializer.toJson<String?>(sefariaRef),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isLeaf': serializer.toJson<bool>(isLeaf),
    };
  }

  ContentItem copyWith({
    int? id,
    String? curriculumId,
    String? level1,
    Value<String?> level2 = const Value.absent(),
    Value<String?> level3 = const Value.absent(),
    Value<String?> level4 = const Value.absent(),
    String? displayNameHe,
    String? displayNameEn,
    Value<String?> sefariaRef = const Value.absent(),
    int? sortOrder,
    bool? isLeaf,
  }) => ContentItem(
    id: id ?? this.id,
    curriculumId: curriculumId ?? this.curriculumId,
    level1: level1 ?? this.level1,
    level2: level2.present ? level2.value : this.level2,
    level3: level3.present ? level3.value : this.level3,
    level4: level4.present ? level4.value : this.level4,
    displayNameHe: displayNameHe ?? this.displayNameHe,
    displayNameEn: displayNameEn ?? this.displayNameEn,
    sefariaRef: sefariaRef.present ? sefariaRef.value : this.sefariaRef,
    sortOrder: sortOrder ?? this.sortOrder,
    isLeaf: isLeaf ?? this.isLeaf,
  );
  ContentItem copyWithCompanion(ContentItemsCompanion data) {
    return ContentItem(
      id: data.id.present ? data.id.value : this.id,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      level1: data.level1.present ? data.level1.value : this.level1,
      level2: data.level2.present ? data.level2.value : this.level2,
      level3: data.level3.present ? data.level3.value : this.level3,
      level4: data.level4.present ? data.level4.value : this.level4,
      displayNameHe: data.displayNameHe.present
          ? data.displayNameHe.value
          : this.displayNameHe,
      displayNameEn: data.displayNameEn.present
          ? data.displayNameEn.value
          : this.displayNameEn,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isLeaf: data.isLeaf.present ? data.isLeaf.value : this.isLeaf,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentItem(')
          ..write('id: $id, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('level1: $level1, ')
          ..write('level2: $level2, ')
          ..write('level3: $level3, ')
          ..write('level4: $level4, ')
          ..write('displayNameHe: $displayNameHe, ')
          ..write('displayNameEn: $displayNameEn, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isLeaf: $isLeaf')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    curriculumId,
    level1,
    level2,
    level3,
    level4,
    displayNameHe,
    displayNameEn,
    sefariaRef,
    sortOrder,
    isLeaf,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentItem &&
          other.id == this.id &&
          other.curriculumId == this.curriculumId &&
          other.level1 == this.level1 &&
          other.level2 == this.level2 &&
          other.level3 == this.level3 &&
          other.level4 == this.level4 &&
          other.displayNameHe == this.displayNameHe &&
          other.displayNameEn == this.displayNameEn &&
          other.sefariaRef == this.sefariaRef &&
          other.sortOrder == this.sortOrder &&
          other.isLeaf == this.isLeaf);
}

class ContentItemsCompanion extends UpdateCompanion<ContentItem> {
  final Value<int> id;
  final Value<String> curriculumId;
  final Value<String> level1;
  final Value<String?> level2;
  final Value<String?> level3;
  final Value<String?> level4;
  final Value<String> displayNameHe;
  final Value<String> displayNameEn;
  final Value<String?> sefariaRef;
  final Value<int> sortOrder;
  final Value<bool> isLeaf;
  const ContentItemsCompanion({
    this.id = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.level1 = const Value.absent(),
    this.level2 = const Value.absent(),
    this.level3 = const Value.absent(),
    this.level4 = const Value.absent(),
    this.displayNameHe = const Value.absent(),
    this.displayNameEn = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isLeaf = const Value.absent(),
  });
  ContentItemsCompanion.insert({
    this.id = const Value.absent(),
    required String curriculumId,
    required String level1,
    this.level2 = const Value.absent(),
    this.level3 = const Value.absent(),
    this.level4 = const Value.absent(),
    required String displayNameHe,
    required String displayNameEn,
    this.sefariaRef = const Value.absent(),
    required int sortOrder,
    required bool isLeaf,
  }) : curriculumId = Value(curriculumId),
       level1 = Value(level1),
       displayNameHe = Value(displayNameHe),
       displayNameEn = Value(displayNameEn),
       sortOrder = Value(sortOrder),
       isLeaf = Value(isLeaf);
  static Insertable<ContentItem> custom({
    Expression<int>? id,
    Expression<String>? curriculumId,
    Expression<String>? level1,
    Expression<String>? level2,
    Expression<String>? level3,
    Expression<String>? level4,
    Expression<String>? displayNameHe,
    Expression<String>? displayNameEn,
    Expression<String>? sefariaRef,
    Expression<int>? sortOrder,
    Expression<bool>? isLeaf,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (level1 != null) 'level1': level1,
      if (level2 != null) 'level2': level2,
      if (level3 != null) 'level3': level3,
      if (level4 != null) 'level4': level4,
      if (displayNameHe != null) 'display_name_he': displayNameHe,
      if (displayNameEn != null) 'display_name_en': displayNameEn,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isLeaf != null) 'is_leaf': isLeaf,
    });
  }

  ContentItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? curriculumId,
    Value<String>? level1,
    Value<String?>? level2,
    Value<String?>? level3,
    Value<String?>? level4,
    Value<String>? displayNameHe,
    Value<String>? displayNameEn,
    Value<String?>? sefariaRef,
    Value<int>? sortOrder,
    Value<bool>? isLeaf,
  }) {
    return ContentItemsCompanion(
      id: id ?? this.id,
      curriculumId: curriculumId ?? this.curriculumId,
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      level4: level4 ?? this.level4,
      displayNameHe: displayNameHe ?? this.displayNameHe,
      displayNameEn: displayNameEn ?? this.displayNameEn,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      sortOrder: sortOrder ?? this.sortOrder,
      isLeaf: isLeaf ?? this.isLeaf,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (level1.present) {
      map['level1'] = Variable<String>(level1.value);
    }
    if (level2.present) {
      map['level2'] = Variable<String>(level2.value);
    }
    if (level3.present) {
      map['level3'] = Variable<String>(level3.value);
    }
    if (level4.present) {
      map['level4'] = Variable<String>(level4.value);
    }
    if (displayNameHe.present) {
      map['display_name_he'] = Variable<String>(displayNameHe.value);
    }
    if (displayNameEn.present) {
      map['display_name_en'] = Variable<String>(displayNameEn.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isLeaf.present) {
      map['is_leaf'] = Variable<bool>(isLeaf.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentItemsCompanion(')
          ..write('id: $id, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('level1: $level1, ')
          ..write('level2: $level2, ')
          ..write('level3: $level3, ')
          ..write('level4: $level4, ')
          ..write('displayNameHe: $displayNameHe, ')
          ..write('displayNameEn: $displayNameEn, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isLeaf: $isLeaf')
          ..write(')'))
        .toString();
  }
}

class $CurriculumHierarchyConfigTable extends CurriculumHierarchyConfig
    with
        TableInfo<
          $CurriculumHierarchyConfigTable,
          CurriculumHierarchyConfigData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurriculumHierarchyConfigTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _level1LabelMeta = const VerificationMeta(
    'level1Label',
  );
  @override
  late final GeneratedColumn<String> level1Label = GeneratedColumn<String>(
    'level1_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _level2LabelMeta = const VerificationMeta(
    'level2Label',
  );
  @override
  late final GeneratedColumn<String> level2Label = GeneratedColumn<String>(
    'level2_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _level3LabelMeta = const VerificationMeta(
    'level3Label',
  );
  @override
  late final GeneratedColumn<String> level3Label = GeneratedColumn<String>(
    'level3_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _level4LabelMeta = const VerificationMeta(
    'level4Label',
  );
  @override
  late final GeneratedColumn<String> level4Label = GeneratedColumn<String>(
    'level4_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxLevelsMeta = const VerificationMeta(
    'maxLevels',
  );
  @override
  late final GeneratedColumn<int> maxLevels = GeneratedColumn<int>(
    'max_levels',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    curriculumId,
    level1Label,
    level2Label,
    level3Label,
    level4Label,
    maxLevels,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'curriculum_hierarchy_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurriculumHierarchyConfigData> instance, {
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
    if (data.containsKey('level1_label')) {
      context.handle(
        _level1LabelMeta,
        level1Label.isAcceptableOrUnknown(
          data['level1_label']!,
          _level1LabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_level1LabelMeta);
    }
    if (data.containsKey('level2_label')) {
      context.handle(
        _level2LabelMeta,
        level2Label.isAcceptableOrUnknown(
          data['level2_label']!,
          _level2LabelMeta,
        ),
      );
    }
    if (data.containsKey('level3_label')) {
      context.handle(
        _level3LabelMeta,
        level3Label.isAcceptableOrUnknown(
          data['level3_label']!,
          _level3LabelMeta,
        ),
      );
    }
    if (data.containsKey('level4_label')) {
      context.handle(
        _level4LabelMeta,
        level4Label.isAcceptableOrUnknown(
          data['level4_label']!,
          _level4LabelMeta,
        ),
      );
    }
    if (data.containsKey('max_levels')) {
      context.handle(
        _maxLevelsMeta,
        maxLevels.isAcceptableOrUnknown(data['max_levels']!, _maxLevelsMeta),
      );
    } else if (isInserting) {
      context.missing(_maxLevelsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {curriculumId};
  @override
  CurriculumHierarchyConfigData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurriculumHierarchyConfigData(
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      level1Label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level1_label'],
      )!,
      level2Label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level2_label'],
      ),
      level3Label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level3_label'],
      ),
      level4Label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level4_label'],
      ),
      maxLevels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_levels'],
      )!,
    );
  }

  @override
  $CurriculumHierarchyConfigTable createAlias(String alias) {
    return $CurriculumHierarchyConfigTable(attachedDatabase, alias);
  }
}

class CurriculumHierarchyConfigData extends DataClass
    implements Insertable<CurriculumHierarchyConfigData> {
  final String curriculumId;
  final String level1Label;
  final String? level2Label;
  final String? level3Label;
  final String? level4Label;
  final int maxLevels;
  const CurriculumHierarchyConfigData({
    required this.curriculumId,
    required this.level1Label,
    this.level2Label,
    this.level3Label,
    this.level4Label,
    required this.maxLevels,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['level1_label'] = Variable<String>(level1Label);
    if (!nullToAbsent || level2Label != null) {
      map['level2_label'] = Variable<String>(level2Label);
    }
    if (!nullToAbsent || level3Label != null) {
      map['level3_label'] = Variable<String>(level3Label);
    }
    if (!nullToAbsent || level4Label != null) {
      map['level4_label'] = Variable<String>(level4Label);
    }
    map['max_levels'] = Variable<int>(maxLevels);
    return map;
  }

  CurriculumHierarchyConfigCompanion toCompanion(bool nullToAbsent) {
    return CurriculumHierarchyConfigCompanion(
      curriculumId: Value(curriculumId),
      level1Label: Value(level1Label),
      level2Label: level2Label == null && nullToAbsent
          ? const Value.absent()
          : Value(level2Label),
      level3Label: level3Label == null && nullToAbsent
          ? const Value.absent()
          : Value(level3Label),
      level4Label: level4Label == null && nullToAbsent
          ? const Value.absent()
          : Value(level4Label),
      maxLevels: Value(maxLevels),
    );
  }

  factory CurriculumHierarchyConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurriculumHierarchyConfigData(
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      level1Label: serializer.fromJson<String>(json['level1Label']),
      level2Label: serializer.fromJson<String?>(json['level2Label']),
      level3Label: serializer.fromJson<String?>(json['level3Label']),
      level4Label: serializer.fromJson<String?>(json['level4Label']),
      maxLevels: serializer.fromJson<int>(json['maxLevels']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'curriculumId': serializer.toJson<String>(curriculumId),
      'level1Label': serializer.toJson<String>(level1Label),
      'level2Label': serializer.toJson<String?>(level2Label),
      'level3Label': serializer.toJson<String?>(level3Label),
      'level4Label': serializer.toJson<String?>(level4Label),
      'maxLevels': serializer.toJson<int>(maxLevels),
    };
  }

  CurriculumHierarchyConfigData copyWith({
    String? curriculumId,
    String? level1Label,
    Value<String?> level2Label = const Value.absent(),
    Value<String?> level3Label = const Value.absent(),
    Value<String?> level4Label = const Value.absent(),
    int? maxLevels,
  }) => CurriculumHierarchyConfigData(
    curriculumId: curriculumId ?? this.curriculumId,
    level1Label: level1Label ?? this.level1Label,
    level2Label: level2Label.present ? level2Label.value : this.level2Label,
    level3Label: level3Label.present ? level3Label.value : this.level3Label,
    level4Label: level4Label.present ? level4Label.value : this.level4Label,
    maxLevels: maxLevels ?? this.maxLevels,
  );
  CurriculumHierarchyConfigData copyWithCompanion(
    CurriculumHierarchyConfigCompanion data,
  ) {
    return CurriculumHierarchyConfigData(
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      level1Label: data.level1Label.present
          ? data.level1Label.value
          : this.level1Label,
      level2Label: data.level2Label.present
          ? data.level2Label.value
          : this.level2Label,
      level3Label: data.level3Label.present
          ? data.level3Label.value
          : this.level3Label,
      level4Label: data.level4Label.present
          ? data.level4Label.value
          : this.level4Label,
      maxLevels: data.maxLevels.present ? data.maxLevels.value : this.maxLevels,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumHierarchyConfigData(')
          ..write('curriculumId: $curriculumId, ')
          ..write('level1Label: $level1Label, ')
          ..write('level2Label: $level2Label, ')
          ..write('level3Label: $level3Label, ')
          ..write('level4Label: $level4Label, ')
          ..write('maxLevels: $maxLevels')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    curriculumId,
    level1Label,
    level2Label,
    level3Label,
    level4Label,
    maxLevels,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurriculumHierarchyConfigData &&
          other.curriculumId == this.curriculumId &&
          other.level1Label == this.level1Label &&
          other.level2Label == this.level2Label &&
          other.level3Label == this.level3Label &&
          other.level4Label == this.level4Label &&
          other.maxLevels == this.maxLevels);
}

class CurriculumHierarchyConfigCompanion
    extends UpdateCompanion<CurriculumHierarchyConfigData> {
  final Value<String> curriculumId;
  final Value<String> level1Label;
  final Value<String?> level2Label;
  final Value<String?> level3Label;
  final Value<String?> level4Label;
  final Value<int> maxLevels;
  final Value<int> rowid;
  const CurriculumHierarchyConfigCompanion({
    this.curriculumId = const Value.absent(),
    this.level1Label = const Value.absent(),
    this.level2Label = const Value.absent(),
    this.level3Label = const Value.absent(),
    this.level4Label = const Value.absent(),
    this.maxLevels = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurriculumHierarchyConfigCompanion.insert({
    required String curriculumId,
    required String level1Label,
    this.level2Label = const Value.absent(),
    this.level3Label = const Value.absent(),
    this.level4Label = const Value.absent(),
    required int maxLevels,
    this.rowid = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       level1Label = Value(level1Label),
       maxLevels = Value(maxLevels);
  static Insertable<CurriculumHierarchyConfigData> custom({
    Expression<String>? curriculumId,
    Expression<String>? level1Label,
    Expression<String>? level2Label,
    Expression<String>? level3Label,
    Expression<String>? level4Label,
    Expression<int>? maxLevels,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (level1Label != null) 'level1_label': level1Label,
      if (level2Label != null) 'level2_label': level2Label,
      if (level3Label != null) 'level3_label': level3Label,
      if (level4Label != null) 'level4_label': level4Label,
      if (maxLevels != null) 'max_levels': maxLevels,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurriculumHierarchyConfigCompanion copyWith({
    Value<String>? curriculumId,
    Value<String>? level1Label,
    Value<String?>? level2Label,
    Value<String?>? level3Label,
    Value<String?>? level4Label,
    Value<int>? maxLevels,
    Value<int>? rowid,
  }) {
    return CurriculumHierarchyConfigCompanion(
      curriculumId: curriculumId ?? this.curriculumId,
      level1Label: level1Label ?? this.level1Label,
      level2Label: level2Label ?? this.level2Label,
      level3Label: level3Label ?? this.level3Label,
      level4Label: level4Label ?? this.level4Label,
      maxLevels: maxLevels ?? this.maxLevels,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (level1Label.present) {
      map['level1_label'] = Variable<String>(level1Label.value);
    }
    if (level2Label.present) {
      map['level2_label'] = Variable<String>(level2Label.value);
    }
    if (level3Label.present) {
      map['level3_label'] = Variable<String>(level3Label.value);
    }
    if (level4Label.present) {
      map['level4_label'] = Variable<String>(level4Label.value);
    }
    if (maxLevels.present) {
      map['max_levels'] = Variable<int>(maxLevels.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurriculumHierarchyConfigCompanion(')
          ..write('curriculumId: $curriculumId, ')
          ..write('level1Label: $level1Label, ')
          ..write('level2Label: $level2Label, ')
          ..write('level3Label: $level3Label, ')
          ..write('level4Label: $level4Label, ')
          ..write('maxLevels: $maxLevels, ')
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
    {curriculumId, stageOrder},
  ];
  @override
  StageDefinition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StageDefinition(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
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
  final String curriculumId;
  final int stageOrder;
  final String stageName;
  final int delayDays;
  final bool isDefault;
  const StageDefinition({
    required this.id,
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
      'curriculumId': serializer.toJson<String>(curriculumId),
      'stageOrder': serializer.toJson<int>(stageOrder),
      'stageName': serializer.toJson<String>(stageName),
      'delayDays': serializer.toJson<int>(delayDays),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  StageDefinition copyWith({
    int? id,
    String? curriculumId,
    int? stageOrder,
    String? stageName,
    int? delayDays,
    bool? isDefault,
  }) => StageDefinition(
    id: id ?? this.id,
    curriculumId: curriculumId ?? this.curriculumId,
    stageOrder: stageOrder ?? this.stageOrder,
    stageName: stageName ?? this.stageName,
    delayDays: delayDays ?? this.delayDays,
    isDefault: isDefault ?? this.isDefault,
  );
  StageDefinition copyWithCompanion(StageDefinitionsCompanion data) {
    return StageDefinition(
      id: data.id.present ? data.id.value : this.id,
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
          other.curriculumId == this.curriculumId &&
          other.stageOrder == this.stageOrder &&
          other.stageName == this.stageName &&
          other.delayDays == this.delayDays &&
          other.isDefault == this.isDefault);
}

class StageDefinitionsCompanion extends UpdateCompanion<StageDefinition> {
  final Value<int> id;
  final Value<String> curriculumId;
  final Value<int> stageOrder;
  final Value<String> stageName;
  final Value<int> delayDays;
  final Value<bool> isDefault;
  const StageDefinitionsCompanion({
    this.id = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.stageOrder = const Value.absent(),
    this.stageName = const Value.absent(),
    this.delayDays = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  StageDefinitionsCompanion.insert({
    this.id = const Value.absent(),
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
    Expression<String>? curriculumId,
    Expression<int>? stageOrder,
    Expression<String>? stageName,
    Expression<int>? delayDays,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (stageOrder != null) 'stage_order': stageOrder,
      if (stageName != null) 'stage_name': stageName,
      if (delayDays != null) 'delay_days': delayDays,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  StageDefinitionsCompanion copyWith({
    Value<int>? id,
    Value<String>? curriculumId,
    Value<int>? stageOrder,
    Value<String>? stageName,
    Value<int>? delayDays,
    Value<bool>? isDefault,
  }) {
    return StageDefinitionsCompanion(
      id: id ?? this.id,
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
  static const VerificationMeta _contentItemIdMeta = const VerificationMeta(
    'contentItemId',
  );
  @override
  late final GeneratedColumn<int> contentItemId = GeneratedColumn<int>(
    'content_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    curriculumId,
    contentItemId,
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
    if (data.containsKey('content_item_id')) {
      context.handle(
        _contentItemIdMeta,
        contentItemId.isAcceptableOrUnknown(
          data['content_item_id']!,
          _contentItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentItemIdMeta);
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
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      contentItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_item_id'],
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
  final String curriculumId;
  final int contentItemId;
  final int stageId;
  final String trackType;
  final DateTime completedAt;
  final int points;
  const Completion({
    required this.id,
    required this.curriculumId,
    required this.contentItemId,
    required this.stageId,
    required this.trackType,
    required this.completedAt,
    required this.points,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['content_item_id'] = Variable<int>(contentItemId);
    map['stage_id'] = Variable<int>(stageId);
    map['track_type'] = Variable<String>(trackType);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['points'] = Variable<int>(points);
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(
      id: Value(id),
      curriculumId: Value(curriculumId),
      contentItemId: Value(contentItemId),
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
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      contentItemId: serializer.fromJson<int>(json['contentItemId']),
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
      'curriculumId': serializer.toJson<String>(curriculumId),
      'contentItemId': serializer.toJson<int>(contentItemId),
      'stageId': serializer.toJson<int>(stageId),
      'trackType': serializer.toJson<String>(trackType),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'points': serializer.toJson<int>(points),
    };
  }

  Completion copyWith({
    int? id,
    String? curriculumId,
    int? contentItemId,
    int? stageId,
    String? trackType,
    DateTime? completedAt,
    int? points,
  }) => Completion(
    id: id ?? this.id,
    curriculumId: curriculumId ?? this.curriculumId,
    contentItemId: contentItemId ?? this.contentItemId,
    stageId: stageId ?? this.stageId,
    trackType: trackType ?? this.trackType,
    completedAt: completedAt ?? this.completedAt,
    points: points ?? this.points,
  );
  Completion copyWithCompanion(CompletionsCompanion data) {
    return Completion(
      id: data.id.present ? data.id.value : this.id,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      contentItemId: data.contentItemId.present
          ? data.contentItemId.value
          : this.contentItemId,
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
          ..write('curriculumId: $curriculumId, ')
          ..write('contentItemId: $contentItemId, ')
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
    curriculumId,
    contentItemId,
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
          other.curriculumId == this.curriculumId &&
          other.contentItemId == this.contentItemId &&
          other.stageId == this.stageId &&
          other.trackType == this.trackType &&
          other.completedAt == this.completedAt &&
          other.points == this.points);
}

class CompletionsCompanion extends UpdateCompanion<Completion> {
  final Value<int> id;
  final Value<String> curriculumId;
  final Value<int> contentItemId;
  final Value<int> stageId;
  final Value<String> trackType;
  final Value<DateTime> completedAt;
  final Value<int> points;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.contentItemId = const Value.absent(),
    this.stageId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.points = const Value.absent(),
  });
  CompletionsCompanion.insert({
    this.id = const Value.absent(),
    required String curriculumId,
    required int contentItemId,
    required int stageId,
    required String trackType,
    required DateTime completedAt,
    this.points = const Value.absent(),
  }) : curriculumId = Value(curriculumId),
       contentItemId = Value(contentItemId),
       stageId = Value(stageId),
       trackType = Value(trackType),
       completedAt = Value(completedAt);
  static Insertable<Completion> custom({
    Expression<int>? id,
    Expression<String>? curriculumId,
    Expression<int>? contentItemId,
    Expression<int>? stageId,
    Expression<String>? trackType,
    Expression<DateTime>? completedAt,
    Expression<int>? points,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (contentItemId != null) 'content_item_id': contentItemId,
      if (stageId != null) 'stage_id': stageId,
      if (trackType != null) 'track_type': trackType,
      if (completedAt != null) 'completed_at': completedAt,
      if (points != null) 'points': points,
    });
  }

  CompletionsCompanion copyWith({
    Value<int>? id,
    Value<String>? curriculumId,
    Value<int>? contentItemId,
    Value<int>? stageId,
    Value<String>? trackType,
    Value<DateTime>? completedAt,
    Value<int>? points,
  }) {
    return CompletionsCompanion(
      id: id ?? this.id,
      curriculumId: curriculumId ?? this.curriculumId,
      contentItemId: contentItemId ?? this.contentItemId,
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
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (contentItemId.present) {
      map['content_item_id'] = Variable<int>(contentItemId.value);
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
          ..write('curriculumId: $curriculumId, ')
          ..write('contentItemId: $contentItemId, ')
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
  static const VerificationMeta _contentItemIdMeta = const VerificationMeta(
    'contentItemId',
  );
  @override
  late final GeneratedColumn<int> contentItemId = GeneratedColumn<int>(
    'content_item_id',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    curriculumId,
    trackType,
    contentItemId,
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
    if (data.containsKey('content_item_id')) {
      context.handle(
        _contentItemIdMeta,
        contentItemId.isAcceptableOrUnknown(
          data['content_item_id']!,
          _contentItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentItemIdMeta);
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
    {curriculumId, trackType},
  ];
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      trackType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_type'],
      )!,
      contentItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_item_id'],
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
  final String curriculumId;
  final String trackType;
  final int contentItemId;
  final DateTime updatedAt;
  const Bookmark({
    required this.id,
    required this.curriculumId,
    required this.trackType,
    required this.contentItemId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['track_type'] = Variable<String>(trackType);
    map['content_item_id'] = Variable<int>(contentItemId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      curriculumId: Value(curriculumId),
      trackType: Value(trackType),
      contentItemId: Value(contentItemId),
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
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      trackType: serializer.fromJson<String>(json['trackType']),
      contentItemId: serializer.fromJson<int>(json['contentItemId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'trackType': serializer.toJson<String>(trackType),
      'contentItemId': serializer.toJson<int>(contentItemId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bookmark copyWith({
    int? id,
    String? curriculumId,
    String? trackType,
    int? contentItemId,
    DateTime? updatedAt,
  }) => Bookmark(
    id: id ?? this.id,
    curriculumId: curriculumId ?? this.curriculumId,
    trackType: trackType ?? this.trackType,
    contentItemId: contentItemId ?? this.contentItemId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      trackType: data.trackType.present ? data.trackType.value : this.trackType,
      contentItemId: data.contentItemId.present
          ? data.contentItemId.value
          : this.contentItemId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('contentItemId: $contentItemId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, curriculumId, trackType, contentItemId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.curriculumId == this.curriculumId &&
          other.trackType == this.trackType &&
          other.contentItemId == this.contentItemId &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<String> curriculumId;
  final Value<String> trackType;
  final Value<int> contentItemId;
  final Value<DateTime> updatedAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.trackType = const Value.absent(),
    this.contentItemId = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String curriculumId,
    required String trackType,
    required int contentItemId,
    required DateTime updatedAt,
  }) : curriculumId = Value(curriculumId),
       trackType = Value(trackType),
       contentItemId = Value(contentItemId),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<String>? curriculumId,
    Expression<String>? trackType,
    Expression<int>? contentItemId,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (trackType != null) 'track_type': trackType,
      if (contentItemId != null) 'content_item_id': contentItemId,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? curriculumId,
    Value<String>? trackType,
    Value<int>? contentItemId,
    Value<DateTime>? updatedAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      curriculumId: curriculumId ?? this.curriculumId,
      trackType: trackType ?? this.trackType,
      contentItemId: contentItemId ?? this.contentItemId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (trackType.present) {
      map['track_type'] = Variable<String>(trackType.value);
    }
    if (contentItemId.present) {
      map['content_item_id'] = Variable<int>(contentItemId.value);
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
          ..write('curriculumId: $curriculumId, ')
          ..write('trackType: $trackType, ')
          ..write('contentItemId: $contentItemId, ')
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
  static const VerificationMeta _contentItemIdMeta = const VerificationMeta(
    'contentItemId',
  );
  @override
  late final GeneratedColumn<int> contentItemId = GeneratedColumn<int>(
    'content_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    curriculumId,
    contentItemId,
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
    if (data.containsKey('content_item_id')) {
      context.handle(
        _contentItemIdMeta,
        contentItemId.isAcceptableOrUnknown(
          data['content_item_id']!,
          _contentItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentItemIdMeta);
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
    {curriculumId, contentItemId},
  ];
  @override
  LearningOrderData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningOrderData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      curriculumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_id'],
      )!,
      contentItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_item_id'],
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
  final String curriculumId;
  final int contentItemId;
  final int userSortOrder;
  const LearningOrderData({
    required this.id,
    required this.curriculumId,
    required this.contentItemId,
    required this.userSortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['curriculum_id'] = Variable<String>(curriculumId);
    map['content_item_id'] = Variable<int>(contentItemId);
    map['user_sort_order'] = Variable<int>(userSortOrder);
    return map;
  }

  LearningOrderCompanion toCompanion(bool nullToAbsent) {
    return LearningOrderCompanion(
      id: Value(id),
      curriculumId: Value(curriculumId),
      contentItemId: Value(contentItemId),
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
      curriculumId: serializer.fromJson<String>(json['curriculumId']),
      contentItemId: serializer.fromJson<int>(json['contentItemId']),
      userSortOrder: serializer.fromJson<int>(json['userSortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'curriculumId': serializer.toJson<String>(curriculumId),
      'contentItemId': serializer.toJson<int>(contentItemId),
      'userSortOrder': serializer.toJson<int>(userSortOrder),
    };
  }

  LearningOrderData copyWith({
    int? id,
    String? curriculumId,
    int? contentItemId,
    int? userSortOrder,
  }) => LearningOrderData(
    id: id ?? this.id,
    curriculumId: curriculumId ?? this.curriculumId,
    contentItemId: contentItemId ?? this.contentItemId,
    userSortOrder: userSortOrder ?? this.userSortOrder,
  );
  LearningOrderData copyWithCompanion(LearningOrderCompanion data) {
    return LearningOrderData(
      id: data.id.present ? data.id.value : this.id,
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
      contentItemId: data.contentItemId.present
          ? data.contentItemId.value
          : this.contentItemId,
      userSortOrder: data.userSortOrder.present
          ? data.userSortOrder.value
          : this.userSortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningOrderData(')
          ..write('id: $id, ')
          ..write('curriculumId: $curriculumId, ')
          ..write('contentItemId: $contentItemId, ')
          ..write('userSortOrder: $userSortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, curriculumId, contentItemId, userSortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningOrderData &&
          other.id == this.id &&
          other.curriculumId == this.curriculumId &&
          other.contentItemId == this.contentItemId &&
          other.userSortOrder == this.userSortOrder);
}

class LearningOrderCompanion extends UpdateCompanion<LearningOrderData> {
  final Value<int> id;
  final Value<String> curriculumId;
  final Value<int> contentItemId;
  final Value<int> userSortOrder;
  const LearningOrderCompanion({
    this.id = const Value.absent(),
    this.curriculumId = const Value.absent(),
    this.contentItemId = const Value.absent(),
    this.userSortOrder = const Value.absent(),
  });
  LearningOrderCompanion.insert({
    this.id = const Value.absent(),
    required String curriculumId,
    required int contentItemId,
    required int userSortOrder,
  }) : curriculumId = Value(curriculumId),
       contentItemId = Value(contentItemId),
       userSortOrder = Value(userSortOrder);
  static Insertable<LearningOrderData> custom({
    Expression<int>? id,
    Expression<String>? curriculumId,
    Expression<int>? contentItemId,
    Expression<int>? userSortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (curriculumId != null) 'curriculum_id': curriculumId,
      if (contentItemId != null) 'content_item_id': contentItemId,
      if (userSortOrder != null) 'user_sort_order': userSortOrder,
    });
  }

  LearningOrderCompanion copyWith({
    Value<int>? id,
    Value<String>? curriculumId,
    Value<int>? contentItemId,
    Value<int>? userSortOrder,
  }) {
    return LearningOrderCompanion(
      id: id ?? this.id,
      curriculumId: curriculumId ?? this.curriculumId,
      contentItemId: contentItemId ?? this.contentItemId,
      userSortOrder: userSortOrder ?? this.userSortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    if (contentItemId.present) {
      map['content_item_id'] = Variable<int>(contentItemId.value);
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
          ..write('curriculumId: $curriculumId, ')
          ..write('contentItemId: $contentItemId, ')
          ..write('userSortOrder: $userSortOrder')
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
    title,
    description,
    pointsThreshold,
    isRevealed,
    isEarned,
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
  final String title;
  final String description;
  final int pointsThreshold;
  final bool isRevealed;
  final bool isEarned;
  final String? curriculumId;
  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsThreshold,
    required this.isRevealed,
    required this.isEarned,
    this.curriculumId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['points_threshold'] = Variable<int>(pointsThreshold);
    map['is_revealed'] = Variable<bool>(isRevealed);
    map['is_earned'] = Variable<bool>(isEarned);
    if (!nullToAbsent || curriculumId != null) {
      map['curriculum_id'] = Variable<String>(curriculumId);
    }
    return map;
  }

  RewardsCompanion toCompanion(bool nullToAbsent) {
    return RewardsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      pointsThreshold: Value(pointsThreshold),
      isRevealed: Value(isRevealed),
      isEarned: Value(isEarned),
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
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      pointsThreshold: serializer.fromJson<int>(json['pointsThreshold']),
      isRevealed: serializer.fromJson<bool>(json['isRevealed']),
      isEarned: serializer.fromJson<bool>(json['isEarned']),
      curriculumId: serializer.fromJson<String?>(json['curriculumId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'pointsThreshold': serializer.toJson<int>(pointsThreshold),
      'isRevealed': serializer.toJson<bool>(isRevealed),
      'isEarned': serializer.toJson<bool>(isEarned),
      'curriculumId': serializer.toJson<String?>(curriculumId),
    };
  }

  Reward copyWith({
    int? id,
    String? title,
    String? description,
    int? pointsThreshold,
    bool? isRevealed,
    bool? isEarned,
    Value<String?> curriculumId = const Value.absent(),
  }) => Reward(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    pointsThreshold: pointsThreshold ?? this.pointsThreshold,
    isRevealed: isRevealed ?? this.isRevealed,
    isEarned: isEarned ?? this.isEarned,
    curriculumId: curriculumId.present ? curriculumId.value : this.curriculumId,
  );
  Reward copyWithCompanion(RewardsCompanion data) {
    return Reward(
      id: data.id.present ? data.id.value : this.id,
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
      curriculumId: data.curriculumId.present
          ? data.curriculumId.value
          : this.curriculumId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reward(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pointsThreshold: $pointsThreshold, ')
          ..write('isRevealed: $isRevealed, ')
          ..write('isEarned: $isEarned, ')
          ..write('curriculumId: $curriculumId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    pointsThreshold,
    isRevealed,
    isEarned,
    curriculumId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reward &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.pointsThreshold == this.pointsThreshold &&
          other.isRevealed == this.isRevealed &&
          other.isEarned == this.isEarned &&
          other.curriculumId == this.curriculumId);
}

class RewardsCompanion extends UpdateCompanion<Reward> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<int> pointsThreshold;
  final Value<bool> isRevealed;
  final Value<bool> isEarned;
  final Value<String?> curriculumId;
  const RewardsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.pointsThreshold = const Value.absent(),
    this.isRevealed = const Value.absent(),
    this.isEarned = const Value.absent(),
    this.curriculumId = const Value.absent(),
  });
  RewardsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String description,
    required int pointsThreshold,
    this.isRevealed = const Value.absent(),
    this.isEarned = const Value.absent(),
    this.curriculumId = const Value.absent(),
  }) : title = Value(title),
       description = Value(description),
       pointsThreshold = Value(pointsThreshold);
  static Insertable<Reward> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? pointsThreshold,
    Expression<bool>? isRevealed,
    Expression<bool>? isEarned,
    Expression<String>? curriculumId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (pointsThreshold != null) 'points_threshold': pointsThreshold,
      if (isRevealed != null) 'is_revealed': isRevealed,
      if (isEarned != null) 'is_earned': isEarned,
      if (curriculumId != null) 'curriculum_id': curriculumId,
    });
  }

  RewardsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? description,
    Value<int>? pointsThreshold,
    Value<bool>? isRevealed,
    Value<bool>? isEarned,
    Value<String?>? curriculumId,
  }) {
    return RewardsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      pointsThreshold: pointsThreshold ?? this.pointsThreshold,
      isRevealed: isRevealed ?? this.isRevealed,
      isEarned: isEarned ?? this.isEarned,
      curriculumId: curriculumId ?? this.curriculumId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
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
    if (curriculumId.present) {
      map['curriculum_id'] = Variable<String>(curriculumId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pointsThreshold: $pointsThreshold, ')
          ..write('isRevealed: $isRevealed, ')
          ..write('isEarned: $isEarned, ')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ContentItemsTable contentItems = $ContentItemsTable(this);
  late final $CurriculumHierarchyConfigTable curriculumHierarchyConfig =
      $CurriculumHierarchyConfigTable(this);
  late final $StageDefinitionsTable stageDefinitions = $StageDefinitionsTable(
    this,
  );
  late final $CompletionsTable completions = $CompletionsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $LearningOrderTable learningOrder = $LearningOrderTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $RewardsTable rewards = $RewardsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final ContentDao contentDao = ContentDao(this as AppDatabase);
  late final CompletionDao completionDao = CompletionDao(this as AppDatabase);
  late final StageDao stageDao = StageDao(this as AppDatabase);
  late final BookmarkDao bookmarkDao = BookmarkDao(this as AppDatabase);
  late final LearningOrderDao learningOrderDao = LearningOrderDao(
    this as AppDatabase,
  );
  late final UserProfileDao userProfileDao = UserProfileDao(
    this as AppDatabase,
  );
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    contentItems,
    curriculumHierarchyConfig,
    stageDefinitions,
    completions,
    bookmarks,
    learningOrder,
    userProfiles,
    rewards,
    syncQueue,
  ];
}

typedef $$ContentItemsTableCreateCompanionBuilder =
    ContentItemsCompanion Function({
      Value<int> id,
      required String curriculumId,
      required String level1,
      Value<String?> level2,
      Value<String?> level3,
      Value<String?> level4,
      required String displayNameHe,
      required String displayNameEn,
      Value<String?> sefariaRef,
      required int sortOrder,
      required bool isLeaf,
    });
typedef $$ContentItemsTableUpdateCompanionBuilder =
    ContentItemsCompanion Function({
      Value<int> id,
      Value<String> curriculumId,
      Value<String> level1,
      Value<String?> level2,
      Value<String?> level3,
      Value<String?> level4,
      Value<String> displayNameHe,
      Value<String> displayNameEn,
      Value<String?> sefariaRef,
      Value<int> sortOrder,
      Value<bool> isLeaf,
    });

class $$ContentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentItemsTable> {
  $$ContentItemsTableFilterComposer({
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

  ColumnFilters<String> get level1 => $composableBuilder(
    column: $table.level1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level2 => $composableBuilder(
    column: $table.level2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level3 => $composableBuilder(
    column: $table.level3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level4 => $composableBuilder(
    column: $table.level4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayNameHe => $composableBuilder(
    column: $table.displayNameHe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayNameEn => $composableBuilder(
    column: $table.displayNameEn,
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

  ColumnFilters<bool> get isLeaf => $composableBuilder(
    column: $table.isLeaf,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentItemsTable> {
  $$ContentItemsTableOrderingComposer({
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

  ColumnOrderings<String> get level1 => $composableBuilder(
    column: $table.level1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level2 => $composableBuilder(
    column: $table.level2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level3 => $composableBuilder(
    column: $table.level3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level4 => $composableBuilder(
    column: $table.level4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayNameHe => $composableBuilder(
    column: $table.displayNameHe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayNameEn => $composableBuilder(
    column: $table.displayNameEn,
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

  ColumnOrderings<bool> get isLeaf => $composableBuilder(
    column: $table.isLeaf,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentItemsTable> {
  $$ContentItemsTableAnnotationComposer({
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

  GeneratedColumn<String> get level1 =>
      $composableBuilder(column: $table.level1, builder: (column) => column);

  GeneratedColumn<String> get level2 =>
      $composableBuilder(column: $table.level2, builder: (column) => column);

  GeneratedColumn<String> get level3 =>
      $composableBuilder(column: $table.level3, builder: (column) => column);

  GeneratedColumn<String> get level4 =>
      $composableBuilder(column: $table.level4, builder: (column) => column);

  GeneratedColumn<String> get displayNameHe => $composableBuilder(
    column: $table.displayNameHe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayNameEn => $composableBuilder(
    column: $table.displayNameEn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isLeaf =>
      $composableBuilder(column: $table.isLeaf, builder: (column) => column);
}

class $$ContentItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentItemsTable,
          ContentItem,
          $$ContentItemsTableFilterComposer,
          $$ContentItemsTableOrderingComposer,
          $$ContentItemsTableAnnotationComposer,
          $$ContentItemsTableCreateCompanionBuilder,
          $$ContentItemsTableUpdateCompanionBuilder,
          (
            ContentItem,
            BaseReferences<_$AppDatabase, $ContentItemsTable, ContentItem>,
          ),
          ContentItem,
          PrefetchHooks Function()
        > {
  $$ContentItemsTableTableManager(_$AppDatabase db, $ContentItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> curriculumId = const Value.absent(),
                Value<String> level1 = const Value.absent(),
                Value<String?> level2 = const Value.absent(),
                Value<String?> level3 = const Value.absent(),
                Value<String?> level4 = const Value.absent(),
                Value<String> displayNameHe = const Value.absent(),
                Value<String> displayNameEn = const Value.absent(),
                Value<String?> sefariaRef = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isLeaf = const Value.absent(),
              }) => ContentItemsCompanion(
                id: id,
                curriculumId: curriculumId,
                level1: level1,
                level2: level2,
                level3: level3,
                level4: level4,
                displayNameHe: displayNameHe,
                displayNameEn: displayNameEn,
                sefariaRef: sefariaRef,
                sortOrder: sortOrder,
                isLeaf: isLeaf,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String curriculumId,
                required String level1,
                Value<String?> level2 = const Value.absent(),
                Value<String?> level3 = const Value.absent(),
                Value<String?> level4 = const Value.absent(),
                required String displayNameHe,
                required String displayNameEn,
                Value<String?> sefariaRef = const Value.absent(),
                required int sortOrder,
                required bool isLeaf,
              }) => ContentItemsCompanion.insert(
                id: id,
                curriculumId: curriculumId,
                level1: level1,
                level2: level2,
                level3: level3,
                level4: level4,
                displayNameHe: displayNameHe,
                displayNameEn: displayNameEn,
                sefariaRef: sefariaRef,
                sortOrder: sortOrder,
                isLeaf: isLeaf,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentItemsTable,
      ContentItem,
      $$ContentItemsTableFilterComposer,
      $$ContentItemsTableOrderingComposer,
      $$ContentItemsTableAnnotationComposer,
      $$ContentItemsTableCreateCompanionBuilder,
      $$ContentItemsTableUpdateCompanionBuilder,
      (
        ContentItem,
        BaseReferences<_$AppDatabase, $ContentItemsTable, ContentItem>,
      ),
      ContentItem,
      PrefetchHooks Function()
    >;
typedef $$CurriculumHierarchyConfigTableCreateCompanionBuilder =
    CurriculumHierarchyConfigCompanion Function({
      required String curriculumId,
      required String level1Label,
      Value<String?> level2Label,
      Value<String?> level3Label,
      Value<String?> level4Label,
      required int maxLevels,
      Value<int> rowid,
    });
typedef $$CurriculumHierarchyConfigTableUpdateCompanionBuilder =
    CurriculumHierarchyConfigCompanion Function({
      Value<String> curriculumId,
      Value<String> level1Label,
      Value<String?> level2Label,
      Value<String?> level3Label,
      Value<String?> level4Label,
      Value<int> maxLevels,
      Value<int> rowid,
    });

class $$CurriculumHierarchyConfigTableFilterComposer
    extends Composer<_$AppDatabase, $CurriculumHierarchyConfigTable> {
  $$CurriculumHierarchyConfigTableFilterComposer({
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

  ColumnFilters<String> get level1Label => $composableBuilder(
    column: $table.level1Label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level2Label => $composableBuilder(
    column: $table.level2Label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level3Label => $composableBuilder(
    column: $table.level3Label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level4Label => $composableBuilder(
    column: $table.level4Label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxLevels => $composableBuilder(
    column: $table.maxLevels,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurriculumHierarchyConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $CurriculumHierarchyConfigTable> {
  $$CurriculumHierarchyConfigTableOrderingComposer({
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

  ColumnOrderings<String> get level1Label => $composableBuilder(
    column: $table.level1Label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level2Label => $composableBuilder(
    column: $table.level2Label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level3Label => $composableBuilder(
    column: $table.level3Label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level4Label => $composableBuilder(
    column: $table.level4Label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxLevels => $composableBuilder(
    column: $table.maxLevels,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurriculumHierarchyConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurriculumHierarchyConfigTable> {
  $$CurriculumHierarchyConfigTableAnnotationComposer({
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

  GeneratedColumn<String> get level1Label => $composableBuilder(
    column: $table.level1Label,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level2Label => $composableBuilder(
    column: $table.level2Label,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level3Label => $composableBuilder(
    column: $table.level3Label,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level4Label => $composableBuilder(
    column: $table.level4Label,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxLevels =>
      $composableBuilder(column: $table.maxLevels, builder: (column) => column);
}

class $$CurriculumHierarchyConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurriculumHierarchyConfigTable,
          CurriculumHierarchyConfigData,
          $$CurriculumHierarchyConfigTableFilterComposer,
          $$CurriculumHierarchyConfigTableOrderingComposer,
          $$CurriculumHierarchyConfigTableAnnotationComposer,
          $$CurriculumHierarchyConfigTableCreateCompanionBuilder,
          $$CurriculumHierarchyConfigTableUpdateCompanionBuilder,
          (
            CurriculumHierarchyConfigData,
            BaseReferences<
              _$AppDatabase,
              $CurriculumHierarchyConfigTable,
              CurriculumHierarchyConfigData
            >,
          ),
          CurriculumHierarchyConfigData,
          PrefetchHooks Function()
        > {
  $$CurriculumHierarchyConfigTableTableManager(
    _$AppDatabase db,
    $CurriculumHierarchyConfigTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurriculumHierarchyConfigTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CurriculumHierarchyConfigTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CurriculumHierarchyConfigTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> curriculumId = const Value.absent(),
                Value<String> level1Label = const Value.absent(),
                Value<String?> level2Label = const Value.absent(),
                Value<String?> level3Label = const Value.absent(),
                Value<String?> level4Label = const Value.absent(),
                Value<int> maxLevels = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurriculumHierarchyConfigCompanion(
                curriculumId: curriculumId,
                level1Label: level1Label,
                level2Label: level2Label,
                level3Label: level3Label,
                level4Label: level4Label,
                maxLevels: maxLevels,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String curriculumId,
                required String level1Label,
                Value<String?> level2Label = const Value.absent(),
                Value<String?> level3Label = const Value.absent(),
                Value<String?> level4Label = const Value.absent(),
                required int maxLevels,
                Value<int> rowid = const Value.absent(),
              }) => CurriculumHierarchyConfigCompanion.insert(
                curriculumId: curriculumId,
                level1Label: level1Label,
                level2Label: level2Label,
                level3Label: level3Label,
                level4Label: level4Label,
                maxLevels: maxLevels,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurriculumHierarchyConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurriculumHierarchyConfigTable,
      CurriculumHierarchyConfigData,
      $$CurriculumHierarchyConfigTableFilterComposer,
      $$CurriculumHierarchyConfigTableOrderingComposer,
      $$CurriculumHierarchyConfigTableAnnotationComposer,
      $$CurriculumHierarchyConfigTableCreateCompanionBuilder,
      $$CurriculumHierarchyConfigTableUpdateCompanionBuilder,
      (
        CurriculumHierarchyConfigData,
        BaseReferences<
          _$AppDatabase,
          $CurriculumHierarchyConfigTable,
          CurriculumHierarchyConfigData
        >,
      ),
      CurriculumHierarchyConfigData,
      PrefetchHooks Function()
    >;
typedef $$StageDefinitionsTableCreateCompanionBuilder =
    StageDefinitionsCompanion Function({
      Value<int> id,
      required String curriculumId,
      required int stageOrder,
      required String stageName,
      required int delayDays,
      Value<bool> isDefault,
    });
typedef $$StageDefinitionsTableUpdateCompanionBuilder =
    StageDefinitionsCompanion Function({
      Value<int> id,
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
                Value<String> curriculumId = const Value.absent(),
                Value<int> stageOrder = const Value.absent(),
                Value<String> stageName = const Value.absent(),
                Value<int> delayDays = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => StageDefinitionsCompanion(
                id: id,
                curriculumId: curriculumId,
                stageOrder: stageOrder,
                stageName: stageName,
                delayDays: delayDays,
                isDefault: isDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String curriculumId,
                required int stageOrder,
                required String stageName,
                required int delayDays,
                Value<bool> isDefault = const Value.absent(),
              }) => StageDefinitionsCompanion.insert(
                id: id,
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
      required String curriculumId,
      required int contentItemId,
      required int stageId,
      required String trackType,
      required DateTime completedAt,
      Value<int> points,
    });
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<int> id,
      Value<String> curriculumId,
      Value<int> contentItemId,
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

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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
                Value<String> curriculumId = const Value.absent(),
                Value<int> contentItemId = const Value.absent(),
                Value<int> stageId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> points = const Value.absent(),
              }) => CompletionsCompanion(
                id: id,
                curriculumId: curriculumId,
                contentItemId: contentItemId,
                stageId: stageId,
                trackType: trackType,
                completedAt: completedAt,
                points: points,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String curriculumId,
                required int contentItemId,
                required int stageId,
                required String trackType,
                required DateTime completedAt,
                Value<int> points = const Value.absent(),
              }) => CompletionsCompanion.insert(
                id: id,
                curriculumId: curriculumId,
                contentItemId: contentItemId,
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
      required String curriculumId,
      required String trackType,
      required int contentItemId,
      required DateTime updatedAt,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<String> curriculumId,
      Value<String> trackType,
      Value<int> contentItemId,
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

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackType => $composableBuilder(
    column: $table.trackType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackType =>
      $composableBuilder(column: $table.trackType, builder: (column) => column);

  GeneratedColumn<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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
                Value<String> curriculumId = const Value.absent(),
                Value<String> trackType = const Value.absent(),
                Value<int> contentItemId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                curriculumId: curriculumId,
                trackType: trackType,
                contentItemId: contentItemId,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String curriculumId,
                required String trackType,
                required int contentItemId,
                required DateTime updatedAt,
              }) => BookmarksCompanion.insert(
                id: id,
                curriculumId: curriculumId,
                trackType: trackType,
                contentItemId: contentItemId,
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
typedef $$LearningOrderTableCreateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      required String curriculumId,
      required int contentItemId,
      required int userSortOrder,
    });
typedef $$LearningOrderTableUpdateCompanionBuilder =
    LearningOrderCompanion Function({
      Value<int> id,
      Value<String> curriculumId,
      Value<int> contentItemId,
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

  ColumnFilters<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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

  ColumnOrderings<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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

  GeneratedColumn<String> get curriculumId => $composableBuilder(
    column: $table.curriculumId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentItemId => $composableBuilder(
    column: $table.contentItemId,
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
                Value<String> curriculumId = const Value.absent(),
                Value<int> contentItemId = const Value.absent(),
                Value<int> userSortOrder = const Value.absent(),
              }) => LearningOrderCompanion(
                id: id,
                curriculumId: curriculumId,
                contentItemId: contentItemId,
                userSortOrder: userSortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String curriculumId,
                required int contentItemId,
                required int userSortOrder,
              }) => LearningOrderCompanion.insert(
                id: id,
                curriculumId: curriculumId,
                contentItemId: contentItemId,
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
      required String title,
      required String description,
      required int pointsThreshold,
      Value<bool> isRevealed,
      Value<bool> isEarned,
      Value<String?> curriculumId,
    });
typedef $$RewardsTableUpdateCompanionBuilder =
    RewardsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> description,
      Value<int> pointsThreshold,
      Value<bool> isRevealed,
      Value<bool> isEarned,
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
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> pointsThreshold = const Value.absent(),
                Value<bool> isRevealed = const Value.absent(),
                Value<bool> isEarned = const Value.absent(),
                Value<String?> curriculumId = const Value.absent(),
              }) => RewardsCompanion(
                id: id,
                title: title,
                description: description,
                pointsThreshold: pointsThreshold,
                isRevealed: isRevealed,
                isEarned: isEarned,
                curriculumId: curriculumId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String description,
                required int pointsThreshold,
                Value<bool> isRevealed = const Value.absent(),
                Value<bool> isEarned = const Value.absent(),
                Value<String?> curriculumId = const Value.absent(),
              }) => RewardsCompanion.insert(
                id: id,
                title: title,
                description: description,
                pointsThreshold: pointsThreshold,
                isRevealed: isRevealed,
                isEarned: isEarned,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ContentItemsTableTableManager get contentItems =>
      $$ContentItemsTableTableManager(_db, _db.contentItems);
  $$CurriculumHierarchyConfigTableTableManager get curriculumHierarchyConfig =>
      $$CurriculumHierarchyConfigTableTableManager(
        _db,
        _db.curriculumHierarchyConfig,
      );
  $$StageDefinitionsTableTableManager get stageDefinitions =>
      $$StageDefinitionsTableTableManager(_db, _db.stageDefinitions);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$LearningOrderTableTableManager get learningOrder =>
      $$LearningOrderTableTableManager(_db, _db.learningOrder);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$RewardsTableTableManager get rewards =>
      $$RewardsTableTableManager(_db, _db.rewards);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
