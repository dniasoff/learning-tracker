// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_database.dart';

// ignore_for_file: type=lint
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

class $CalendarCyclesTable extends CalendarCycles
    with TableInfo<$CalendarCyclesTable, CalendarCycle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarCyclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _programKeyMeta = const VerificationMeta(
    'programKey',
  );
  @override
  late final GeneratedColumn<String> programKey = GeneratedColumn<String>(
    'program_key',
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
  static const VerificationMeta _sefariaRefHeMeta = const VerificationMeta(
    'sefariaRefHe',
  );
  @override
  late final GeneratedColumn<String> sefariaRefHe = GeneratedColumn<String>(
    'sefaria_ref_he',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    programKey,
    dateKey,
    sefariaRef,
    sefariaRefHe,
    displayName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_cycles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarCycle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('program_key')) {
      context.handle(
        _programKeyMeta,
        programKey.isAcceptableOrUnknown(data['program_key']!, _programKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_programKeyMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('sefaria_ref')) {
      context.handle(
        _sefariaRefMeta,
        sefariaRef.isAcceptableOrUnknown(data['sefaria_ref']!, _sefariaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sefariaRefMeta);
    }
    if (data.containsKey('sefaria_ref_he')) {
      context.handle(
        _sefariaRefHeMeta,
        sefariaRefHe.isAcceptableOrUnknown(
          data['sefaria_ref_he']!,
          _sefariaRefHeMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {programKey, dateKey};
  @override
  CalendarCycle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarCycle(
      programKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_key'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      sefariaRefHe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref_he'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
    );
  }

  @override
  $CalendarCyclesTable createAlias(String alias) {
    return $CalendarCyclesTable(attachedDatabase, alias);
  }
}

class CalendarCycle extends DataClass implements Insertable<CalendarCycle> {
  /// Program key matching CalendarProgramRegistry IDs
  /// e.g., 'daf_yomi', 'mishna_yomit', 'nach_yomi'
  final String programKey;

  /// Date in 'YYYY-MM-DD' format (ISO 8601)
  final String dateKey;

  /// Sefaria ref for this program on this date (English).
  /// e.g., 'Berakhot 2a', 'Mishnah Berakhot 1.1'
  final String sefariaRef;

  /// Sefaria ref for this program on this date (Hebrew, `heRef` from
  /// /api/calendars). Null when the API didn't return one.
  /// e.g., 'ברכות ב׳', 'משנה ברכות א׳:א׳'
  final String? sefariaRefHe;

  /// Human-readable display name (localized)
  final String displayName;
  const CalendarCycle({
    required this.programKey,
    required this.dateKey,
    required this.sefariaRef,
    this.sefariaRefHe,
    required this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['program_key'] = Variable<String>(programKey);
    map['date_key'] = Variable<String>(dateKey);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    if (!nullToAbsent || sefariaRefHe != null) {
      map['sefaria_ref_he'] = Variable<String>(sefariaRefHe);
    }
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  CalendarCyclesCompanion toCompanion(bool nullToAbsent) {
    return CalendarCyclesCompanion(
      programKey: Value(programKey),
      dateKey: Value(dateKey),
      sefariaRef: Value(sefariaRef),
      sefariaRefHe: sefariaRefHe == null && nullToAbsent
          ? const Value.absent()
          : Value(sefariaRefHe),
      displayName: Value(displayName),
    );
  }

  factory CalendarCycle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarCycle(
      programKey: serializer.fromJson<String>(json['programKey']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      sefariaRefHe: serializer.fromJson<String?>(json['sefariaRefHe']),
      displayName: serializer.fromJson<String>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'programKey': serializer.toJson<String>(programKey),
      'dateKey': serializer.toJson<String>(dateKey),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'sefariaRefHe': serializer.toJson<String?>(sefariaRefHe),
      'displayName': serializer.toJson<String>(displayName),
    };
  }

  CalendarCycle copyWith({
    String? programKey,
    String? dateKey,
    String? sefariaRef,
    Value<String?> sefariaRefHe = const Value.absent(),
    String? displayName,
  }) => CalendarCycle(
    programKey: programKey ?? this.programKey,
    dateKey: dateKey ?? this.dateKey,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    sefariaRefHe: sefariaRefHe.present ? sefariaRefHe.value : this.sefariaRefHe,
    displayName: displayName ?? this.displayName,
  );
  CalendarCycle copyWithCompanion(CalendarCyclesCompanion data) {
    return CalendarCycle(
      programKey: data.programKey.present
          ? data.programKey.value
          : this.programKey,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      sefariaRefHe: data.sefariaRefHe.present
          ? data.sefariaRefHe.value
          : this.sefariaRefHe,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCycle(')
          ..write('programKey: $programKey, ')
          ..write('dateKey: $dateKey, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('sefariaRefHe: $sefariaRefHe, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(programKey, dateKey, sefariaRef, sefariaRefHe, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarCycle &&
          other.programKey == this.programKey &&
          other.dateKey == this.dateKey &&
          other.sefariaRef == this.sefariaRef &&
          other.sefariaRefHe == this.sefariaRefHe &&
          other.displayName == this.displayName);
}

class CalendarCyclesCompanion extends UpdateCompanion<CalendarCycle> {
  final Value<String> programKey;
  final Value<String> dateKey;
  final Value<String> sefariaRef;
  final Value<String?> sefariaRefHe;
  final Value<String> displayName;
  final Value<int> rowid;
  const CalendarCyclesCompanion({
    this.programKey = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.sefariaRefHe = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarCyclesCompanion.insert({
    required String programKey,
    required String dateKey,
    required String sefariaRef,
    this.sefariaRefHe = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : programKey = Value(programKey),
       dateKey = Value(dateKey),
       sefariaRef = Value(sefariaRef);
  static Insertable<CalendarCycle> custom({
    Expression<String>? programKey,
    Expression<String>? dateKey,
    Expression<String>? sefariaRef,
    Expression<String>? sefariaRefHe,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (programKey != null) 'program_key': programKey,
      if (dateKey != null) 'date_key': dateKey,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (sefariaRefHe != null) 'sefaria_ref_he': sefariaRefHe,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarCyclesCompanion copyWith({
    Value<String>? programKey,
    Value<String>? dateKey,
    Value<String>? sefariaRef,
    Value<String?>? sefariaRefHe,
    Value<String>? displayName,
    Value<int>? rowid,
  }) {
    return CalendarCyclesCompanion(
      programKey: programKey ?? this.programKey,
      dateKey: dateKey ?? this.dateKey,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      sefariaRefHe: sefariaRefHe ?? this.sefariaRefHe,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (programKey.present) {
      map['program_key'] = Variable<String>(programKey.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (sefariaRefHe.present) {
      map['sefaria_ref_he'] = Variable<String>(sefariaRefHe.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCyclesCompanion(')
          ..write('programKey: $programKey, ')
          ..write('dateKey: $dateKey, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('sefariaRefHe: $sefariaRefHe, ')
          ..write('displayName: $displayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyContentTable extends DailyContent
    with TableInfo<$DailyContentTable, DailyContentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyContentTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _englishTextMeta = const VerificationMeta(
    'englishText',
  );
  @override
  late final GeneratedColumn<String> englishText = GeneratedColumn<String>(
    'english_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [sefariaRef, englishText, hebrewText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_content';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyContentData> instance, {
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
    if (data.containsKey('english_text')) {
      context.handle(
        _englishTextMeta,
        englishText.isAcceptableOrUnknown(
          data['english_text']!,
          _englishTextMeta,
        ),
      );
    }
    if (data.containsKey('hebrew_text')) {
      context.handle(
        _hebrewTextMeta,
        hebrewText.isAcceptableOrUnknown(data['hebrew_text']!, _hebrewTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sefariaRef};
  @override
  DailyContentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyContentData(
      sefariaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sefaria_ref'],
      )!,
      englishText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}english_text'],
      )!,
      hebrewText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hebrew_text'],
      )!,
    );
  }

  @override
  $DailyContentTable createAlias(String alias) {
    return $DailyContentTable(attachedDatabase, alias);
  }
}

class DailyContentData extends DataClass
    implements Insertable<DailyContentData> {
  final String sefariaRef;

  /// English text of the reading, ready to display.
  final String englishText;

  /// Hebrew text of the reading, ready to display.
  final String hebrewText;
  const DailyContentData({
    required this.sefariaRef,
    required this.englishText,
    required this.hebrewText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['english_text'] = Variable<String>(englishText);
    map['hebrew_text'] = Variable<String>(hebrewText);
    return map;
  }

  DailyContentCompanion toCompanion(bool nullToAbsent) {
    return DailyContentCompanion(
      sefariaRef: Value(sefariaRef),
      englishText: Value(englishText),
      hebrewText: Value(hebrewText),
    );
  }

  factory DailyContentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyContentData(
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      englishText: serializer.fromJson<String>(json['englishText']),
      hebrewText: serializer.fromJson<String>(json['hebrewText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'englishText': serializer.toJson<String>(englishText),
      'hebrewText': serializer.toJson<String>(hebrewText),
    };
  }

  DailyContentData copyWith({
    String? sefariaRef,
    String? englishText,
    String? hebrewText,
  }) => DailyContentData(
    sefariaRef: sefariaRef ?? this.sefariaRef,
    englishText: englishText ?? this.englishText,
    hebrewText: hebrewText ?? this.hebrewText,
  );
  DailyContentData copyWithCompanion(DailyContentCompanion data) {
    return DailyContentData(
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      englishText: data.englishText.present
          ? data.englishText.value
          : this.englishText,
      hebrewText: data.hebrewText.present
          ? data.hebrewText.value
          : this.hebrewText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyContentData(')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('englishText: $englishText, ')
          ..write('hebrewText: $hebrewText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sefariaRef, englishText, hebrewText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyContentData &&
          other.sefariaRef == this.sefariaRef &&
          other.englishText == this.englishText &&
          other.hebrewText == this.hebrewText);
}

class DailyContentCompanion extends UpdateCompanion<DailyContentData> {
  final Value<String> sefariaRef;
  final Value<String> englishText;
  final Value<String> hebrewText;
  final Value<int> rowid;
  const DailyContentCompanion({
    this.sefariaRef = const Value.absent(),
    this.englishText = const Value.absent(),
    this.hebrewText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyContentCompanion.insert({
    required String sefariaRef,
    this.englishText = const Value.absent(),
    this.hebrewText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sefariaRef = Value(sefariaRef);
  static Insertable<DailyContentData> custom({
    Expression<String>? sefariaRef,
    Expression<String>? englishText,
    Expression<String>? hebrewText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (englishText != null) 'english_text': englishText,
      if (hebrewText != null) 'hebrew_text': hebrewText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyContentCompanion copyWith({
    Value<String>? sefariaRef,
    Value<String>? englishText,
    Value<String>? hebrewText,
    Value<int>? rowid,
  }) {
    return DailyContentCompanion(
      sefariaRef: sefariaRef ?? this.sefariaRef,
      englishText: englishText ?? this.englishText,
      hebrewText: hebrewText ?? this.hebrewText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (englishText.present) {
      map['english_text'] = Variable<String>(englishText.value);
    }
    if (hebrewText.present) {
      map['hebrew_text'] = Variable<String>(hebrewText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyContentCompanion(')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('englishText: $englishText, ')
          ..write('hebrewText: $hebrewText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeedMetadataTable extends SeedMetadata
    with TableInfo<$SeedMetadataTable, SeedMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeedMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _builtAtMeta = const VerificationMeta(
    'builtAt',
  );
  @override
  late final GeneratedColumn<String> builtAt = GeneratedColumn<String>(
    'built_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _buildIdMeta = const VerificationMeta(
    'buildId',
  );
  @override
  late final GeneratedColumn<String> buildId = GeneratedColumn<String>(
    'build_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textCacheCountMeta = const VerificationMeta(
    'textCacheCount',
  );
  @override
  late final GeneratedColumn<int> textCacheCount = GeneratedColumn<int>(
    'text_cache_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarCycleCountMeta =
      const VerificationMeta('calendarCycleCount');
  @override
  late final GeneratedColumn<int> calendarCycleCount = GeneratedColumn<int>(
    'calendar_cycle_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minAppVersionMeta = const VerificationMeta(
    'minAppVersion',
  );
  @override
  late final GeneratedColumn<String> minAppVersion = GeneratedColumn<String>(
    'min_app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1.0.0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    builtAt,
    buildId,
    textCacheCount,
    calendarCycleCount,
    contentHash,
    minAppVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seed_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeedMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('built_at')) {
      context.handle(
        _builtAtMeta,
        builtAt.isAcceptableOrUnknown(data['built_at']!, _builtAtMeta),
      );
    } else if (isInserting) {
      context.missing(_builtAtMeta);
    }
    if (data.containsKey('build_id')) {
      context.handle(
        _buildIdMeta,
        buildId.isAcceptableOrUnknown(data['build_id']!, _buildIdMeta),
      );
    } else if (isInserting) {
      context.missing(_buildIdMeta);
    }
    if (data.containsKey('text_cache_count')) {
      context.handle(
        _textCacheCountMeta,
        textCacheCount.isAcceptableOrUnknown(
          data['text_cache_count']!,
          _textCacheCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textCacheCountMeta);
    }
    if (data.containsKey('calendar_cycle_count')) {
      context.handle(
        _calendarCycleCountMeta,
        calendarCycleCount.isAcceptableOrUnknown(
          data['calendar_cycle_count']!,
          _calendarCycleCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calendarCycleCountMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('min_app_version')) {
      context.handle(
        _minAppVersionMeta,
        minAppVersion.isAcceptableOrUnknown(
          data['min_app_version']!,
          _minAppVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {version};
  @override
  SeedMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeedMetadataData(
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      builtAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}built_at'],
      )!,
      buildId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}build_id'],
      )!,
      textCacheCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}text_cache_count'],
      )!,
      calendarCycleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calendar_cycle_count'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      minAppVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}min_app_version'],
      )!,
    );
  }

  @override
  $SeedMetadataTable createAlias(String alias) {
    return $SeedMetadataTable(attachedDatabase, alias);
  }
}

class SeedMetadataData extends DataClass
    implements Insertable<SeedMetadataData> {
  /// Monotonically increasing version number set at build time
  final int version;

  /// ISO 8601 timestamp of when the seed DB was built
  final String builtAt;

  /// Git SHA or build identifier of the content pipeline run
  final String buildId;

  /// Number of TextCache rows in this seed
  final int textCacheCount;

  /// Number of CalendarCycles rows in this seed
  final int calendarCycleCount;

  /// SHA-256 hash of all content (refs + calendar keys) for integrity checks.
  /// Null when not computed by the seed build pipeline.
  final String? contentHash;

  /// Minimum app version required to read this seed format
  final String minAppVersion;
  const SeedMetadataData({
    required this.version,
    required this.builtAt,
    required this.buildId,
    required this.textCacheCount,
    required this.calendarCycleCount,
    this.contentHash,
    required this.minAppVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    map['built_at'] = Variable<String>(builtAt);
    map['build_id'] = Variable<String>(buildId);
    map['text_cache_count'] = Variable<int>(textCacheCount);
    map['calendar_cycle_count'] = Variable<int>(calendarCycleCount);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['min_app_version'] = Variable<String>(minAppVersion);
    return map;
  }

  SeedMetadataCompanion toCompanion(bool nullToAbsent) {
    return SeedMetadataCompanion(
      version: Value(version),
      builtAt: Value(builtAt),
      buildId: Value(buildId),
      textCacheCount: Value(textCacheCount),
      calendarCycleCount: Value(calendarCycleCount),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      minAppVersion: Value(minAppVersion),
    );
  }

  factory SeedMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeedMetadataData(
      version: serializer.fromJson<int>(json['version']),
      builtAt: serializer.fromJson<String>(json['builtAt']),
      buildId: serializer.fromJson<String>(json['buildId']),
      textCacheCount: serializer.fromJson<int>(json['textCacheCount']),
      calendarCycleCount: serializer.fromJson<int>(json['calendarCycleCount']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      minAppVersion: serializer.fromJson<String>(json['minAppVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'builtAt': serializer.toJson<String>(builtAt),
      'buildId': serializer.toJson<String>(buildId),
      'textCacheCount': serializer.toJson<int>(textCacheCount),
      'calendarCycleCount': serializer.toJson<int>(calendarCycleCount),
      'contentHash': serializer.toJson<String?>(contentHash),
      'minAppVersion': serializer.toJson<String>(minAppVersion),
    };
  }

  SeedMetadataData copyWith({
    int? version,
    String? builtAt,
    String? buildId,
    int? textCacheCount,
    int? calendarCycleCount,
    Value<String?> contentHash = const Value.absent(),
    String? minAppVersion,
  }) => SeedMetadataData(
    version: version ?? this.version,
    builtAt: builtAt ?? this.builtAt,
    buildId: buildId ?? this.buildId,
    textCacheCount: textCacheCount ?? this.textCacheCount,
    calendarCycleCount: calendarCycleCount ?? this.calendarCycleCount,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    minAppVersion: minAppVersion ?? this.minAppVersion,
  );
  SeedMetadataData copyWithCompanion(SeedMetadataCompanion data) {
    return SeedMetadataData(
      version: data.version.present ? data.version.value : this.version,
      builtAt: data.builtAt.present ? data.builtAt.value : this.builtAt,
      buildId: data.buildId.present ? data.buildId.value : this.buildId,
      textCacheCount: data.textCacheCount.present
          ? data.textCacheCount.value
          : this.textCacheCount,
      calendarCycleCount: data.calendarCycleCount.present
          ? data.calendarCycleCount.value
          : this.calendarCycleCount,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      minAppVersion: data.minAppVersion.present
          ? data.minAppVersion.value
          : this.minAppVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeedMetadataData(')
          ..write('version: $version, ')
          ..write('builtAt: $builtAt, ')
          ..write('buildId: $buildId, ')
          ..write('textCacheCount: $textCacheCount, ')
          ..write('calendarCycleCount: $calendarCycleCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('minAppVersion: $minAppVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    builtAt,
    buildId,
    textCacheCount,
    calendarCycleCount,
    contentHash,
    minAppVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeedMetadataData &&
          other.version == this.version &&
          other.builtAt == this.builtAt &&
          other.buildId == this.buildId &&
          other.textCacheCount == this.textCacheCount &&
          other.calendarCycleCount == this.calendarCycleCount &&
          other.contentHash == this.contentHash &&
          other.minAppVersion == this.minAppVersion);
}

class SeedMetadataCompanion extends UpdateCompanion<SeedMetadataData> {
  final Value<int> version;
  final Value<String> builtAt;
  final Value<String> buildId;
  final Value<int> textCacheCount;
  final Value<int> calendarCycleCount;
  final Value<String?> contentHash;
  final Value<String> minAppVersion;
  const SeedMetadataCompanion({
    this.version = const Value.absent(),
    this.builtAt = const Value.absent(),
    this.buildId = const Value.absent(),
    this.textCacheCount = const Value.absent(),
    this.calendarCycleCount = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.minAppVersion = const Value.absent(),
  });
  SeedMetadataCompanion.insert({
    this.version = const Value.absent(),
    required String builtAt,
    required String buildId,
    required int textCacheCount,
    required int calendarCycleCount,
    this.contentHash = const Value.absent(),
    this.minAppVersion = const Value.absent(),
  }) : builtAt = Value(builtAt),
       buildId = Value(buildId),
       textCacheCount = Value(textCacheCount),
       calendarCycleCount = Value(calendarCycleCount);
  static Insertable<SeedMetadataData> custom({
    Expression<int>? version,
    Expression<String>? builtAt,
    Expression<String>? buildId,
    Expression<int>? textCacheCount,
    Expression<int>? calendarCycleCount,
    Expression<String>? contentHash,
    Expression<String>? minAppVersion,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (builtAt != null) 'built_at': builtAt,
      if (buildId != null) 'build_id': buildId,
      if (textCacheCount != null) 'text_cache_count': textCacheCount,
      if (calendarCycleCount != null)
        'calendar_cycle_count': calendarCycleCount,
      if (contentHash != null) 'content_hash': contentHash,
      if (minAppVersion != null) 'min_app_version': minAppVersion,
    });
  }

  SeedMetadataCompanion copyWith({
    Value<int>? version,
    Value<String>? builtAt,
    Value<String>? buildId,
    Value<int>? textCacheCount,
    Value<int>? calendarCycleCount,
    Value<String?>? contentHash,
    Value<String>? minAppVersion,
  }) {
    return SeedMetadataCompanion(
      version: version ?? this.version,
      builtAt: builtAt ?? this.builtAt,
      buildId: buildId ?? this.buildId,
      textCacheCount: textCacheCount ?? this.textCacheCount,
      calendarCycleCount: calendarCycleCount ?? this.calendarCycleCount,
      contentHash: contentHash ?? this.contentHash,
      minAppVersion: minAppVersion ?? this.minAppVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (builtAt.present) {
      map['built_at'] = Variable<String>(builtAt.value);
    }
    if (buildId.present) {
      map['build_id'] = Variable<String>(buildId.value);
    }
    if (textCacheCount.present) {
      map['text_cache_count'] = Variable<int>(textCacheCount.value);
    }
    if (calendarCycleCount.present) {
      map['calendar_cycle_count'] = Variable<int>(calendarCycleCount.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (minAppVersion.present) {
      map['min_app_version'] = Variable<String>(minAppVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeedMetadataCompanion(')
          ..write('version: $version, ')
          ..write('builtAt: $builtAt, ')
          ..write('buildId: $buildId, ')
          ..write('textCacheCount: $textCacheCount, ')
          ..write('calendarCycleCount: $calendarCycleCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('minAppVersion: $minAppVersion')
          ..write(')'))
        .toString();
  }
}

abstract class _$ContentDatabase extends GeneratedDatabase {
  _$ContentDatabase(QueryExecutor e) : super(e);
  $ContentDatabaseManager get managers => $ContentDatabaseManager(this);
  late final $TextCacheTable textCache = $TextCacheTable(this);
  late final $CalendarCyclesTable calendarCycles = $CalendarCyclesTable(this);
  late final $DailyContentTable dailyContent = $DailyContentTable(this);
  late final $SeedMetadataTable seedMetadata = $SeedMetadataTable(this);
  late final ContentTextCacheDao contentTextCacheDao = ContentTextCacheDao(
    this as ContentDatabase,
  );
  late final CalendarCycleDao calendarCycleDao = CalendarCycleDao(
    this as ContentDatabase,
  );
  late final DailyContentDao dailyContentDao = DailyContentDao(
    this as ContentDatabase,
  );
  late final SeedMetadataDao seedMetadataDao = SeedMetadataDao(
    this as ContentDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    textCache,
    calendarCycles,
    dailyContent,
    seedMetadata,
  ];
}

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
    extends Composer<_$ContentDatabase, $TextCacheTable> {
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
    extends Composer<_$ContentDatabase, $TextCacheTable> {
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
    extends Composer<_$ContentDatabase, $TextCacheTable> {
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
          _$ContentDatabase,
          $TextCacheTable,
          TextCacheData,
          $$TextCacheTableFilterComposer,
          $$TextCacheTableOrderingComposer,
          $$TextCacheTableAnnotationComposer,
          $$TextCacheTableCreateCompanionBuilder,
          $$TextCacheTableUpdateCompanionBuilder,
          (
            TextCacheData,
            BaseReferences<_$ContentDatabase, $TextCacheTable, TextCacheData>,
          ),
          TextCacheData,
          PrefetchHooks Function()
        > {
  $$TextCacheTableTableManager(_$ContentDatabase db, $TextCacheTable table)
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
      _$ContentDatabase,
      $TextCacheTable,
      TextCacheData,
      $$TextCacheTableFilterComposer,
      $$TextCacheTableOrderingComposer,
      $$TextCacheTableAnnotationComposer,
      $$TextCacheTableCreateCompanionBuilder,
      $$TextCacheTableUpdateCompanionBuilder,
      (
        TextCacheData,
        BaseReferences<_$ContentDatabase, $TextCacheTable, TextCacheData>,
      ),
      TextCacheData,
      PrefetchHooks Function()
    >;
typedef $$CalendarCyclesTableCreateCompanionBuilder =
    CalendarCyclesCompanion Function({
      required String programKey,
      required String dateKey,
      required String sefariaRef,
      Value<String?> sefariaRefHe,
      Value<String> displayName,
      Value<int> rowid,
    });
typedef $$CalendarCyclesTableUpdateCompanionBuilder =
    CalendarCyclesCompanion Function({
      Value<String> programKey,
      Value<String> dateKey,
      Value<String> sefariaRef,
      Value<String?> sefariaRefHe,
      Value<String> displayName,
      Value<int> rowid,
    });

class $$CalendarCyclesTableFilterComposer
    extends Composer<_$ContentDatabase, $CalendarCyclesTable> {
  $$CalendarCyclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get programKey => $composableBuilder(
    column: $table.programKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sefariaRefHe => $composableBuilder(
    column: $table.sefariaRefHe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarCyclesTableOrderingComposer
    extends Composer<_$ContentDatabase, $CalendarCyclesTable> {
  $$CalendarCyclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get programKey => $composableBuilder(
    column: $table.programKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sefariaRefHe => $composableBuilder(
    column: $table.sefariaRefHe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarCyclesTableAnnotationComposer
    extends Composer<_$ContentDatabase, $CalendarCyclesTable> {
  $$CalendarCyclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get programKey => $composableBuilder(
    column: $table.programKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<String> get sefariaRef => $composableBuilder(
    column: $table.sefariaRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sefariaRefHe => $composableBuilder(
    column: $table.sefariaRefHe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );
}

class $$CalendarCyclesTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $CalendarCyclesTable,
          CalendarCycle,
          $$CalendarCyclesTableFilterComposer,
          $$CalendarCyclesTableOrderingComposer,
          $$CalendarCyclesTableAnnotationComposer,
          $$CalendarCyclesTableCreateCompanionBuilder,
          $$CalendarCyclesTableUpdateCompanionBuilder,
          (
            CalendarCycle,
            BaseReferences<
              _$ContentDatabase,
              $CalendarCyclesTable,
              CalendarCycle
            >,
          ),
          CalendarCycle,
          PrefetchHooks Function()
        > {
  $$CalendarCyclesTableTableManager(
    _$ContentDatabase db,
    $CalendarCyclesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarCyclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarCyclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarCyclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> programKey = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<String?> sefariaRefHe = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarCyclesCompanion(
                programKey: programKey,
                dateKey: dateKey,
                sefariaRef: sefariaRef,
                sefariaRefHe: sefariaRefHe,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String programKey,
                required String dateKey,
                required String sefariaRef,
                Value<String?> sefariaRefHe = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarCyclesCompanion.insert(
                programKey: programKey,
                dateKey: dateKey,
                sefariaRef: sefariaRef,
                sefariaRefHe: sefariaRefHe,
                displayName: displayName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarCyclesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $CalendarCyclesTable,
      CalendarCycle,
      $$CalendarCyclesTableFilterComposer,
      $$CalendarCyclesTableOrderingComposer,
      $$CalendarCyclesTableAnnotationComposer,
      $$CalendarCyclesTableCreateCompanionBuilder,
      $$CalendarCyclesTableUpdateCompanionBuilder,
      (
        CalendarCycle,
        BaseReferences<_$ContentDatabase, $CalendarCyclesTable, CalendarCycle>,
      ),
      CalendarCycle,
      PrefetchHooks Function()
    >;
typedef $$DailyContentTableCreateCompanionBuilder =
    DailyContentCompanion Function({
      required String sefariaRef,
      Value<String> englishText,
      Value<String> hebrewText,
      Value<int> rowid,
    });
typedef $$DailyContentTableUpdateCompanionBuilder =
    DailyContentCompanion Function({
      Value<String> sefariaRef,
      Value<String> englishText,
      Value<String> hebrewText,
      Value<int> rowid,
    });

class $$DailyContentTableFilterComposer
    extends Composer<_$ContentDatabase, $DailyContentTable> {
  $$DailyContentTableFilterComposer({
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

  ColumnFilters<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hebrewText => $composableBuilder(
    column: $table.hebrewText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyContentTableOrderingComposer
    extends Composer<_$ContentDatabase, $DailyContentTable> {
  $$DailyContentTableOrderingComposer({
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

  ColumnOrderings<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hebrewText => $composableBuilder(
    column: $table.hebrewText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyContentTableAnnotationComposer
    extends Composer<_$ContentDatabase, $DailyContentTable> {
  $$DailyContentTableAnnotationComposer({
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

  GeneratedColumn<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hebrewText => $composableBuilder(
    column: $table.hebrewText,
    builder: (column) => column,
  );
}

class $$DailyContentTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $DailyContentTable,
          DailyContentData,
          $$DailyContentTableFilterComposer,
          $$DailyContentTableOrderingComposer,
          $$DailyContentTableAnnotationComposer,
          $$DailyContentTableCreateCompanionBuilder,
          $$DailyContentTableUpdateCompanionBuilder,
          (
            DailyContentData,
            BaseReferences<
              _$ContentDatabase,
              $DailyContentTable,
              DailyContentData
            >,
          ),
          DailyContentData,
          PrefetchHooks Function()
        > {
  $$DailyContentTableTableManager(
    _$ContentDatabase db,
    $DailyContentTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyContentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyContentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyContentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sefariaRef = const Value.absent(),
                Value<String> englishText = const Value.absent(),
                Value<String> hebrewText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyContentCompanion(
                sefariaRef: sefariaRef,
                englishText: englishText,
                hebrewText: hebrewText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sefariaRef,
                Value<String> englishText = const Value.absent(),
                Value<String> hebrewText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyContentCompanion.insert(
                sefariaRef: sefariaRef,
                englishText: englishText,
                hebrewText: hebrewText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyContentTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $DailyContentTable,
      DailyContentData,
      $$DailyContentTableFilterComposer,
      $$DailyContentTableOrderingComposer,
      $$DailyContentTableAnnotationComposer,
      $$DailyContentTableCreateCompanionBuilder,
      $$DailyContentTableUpdateCompanionBuilder,
      (
        DailyContentData,
        BaseReferences<_$ContentDatabase, $DailyContentTable, DailyContentData>,
      ),
      DailyContentData,
      PrefetchHooks Function()
    >;
typedef $$SeedMetadataTableCreateCompanionBuilder =
    SeedMetadataCompanion Function({
      Value<int> version,
      required String builtAt,
      required String buildId,
      required int textCacheCount,
      required int calendarCycleCount,
      Value<String?> contentHash,
      Value<String> minAppVersion,
    });
typedef $$SeedMetadataTableUpdateCompanionBuilder =
    SeedMetadataCompanion Function({
      Value<int> version,
      Value<String> builtAt,
      Value<String> buildId,
      Value<int> textCacheCount,
      Value<int> calendarCycleCount,
      Value<String?> contentHash,
      Value<String> minAppVersion,
    });

class $$SeedMetadataTableFilterComposer
    extends Composer<_$ContentDatabase, $SeedMetadataTable> {
  $$SeedMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get builtAt => $composableBuilder(
    column: $table.builtAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get buildId => $composableBuilder(
    column: $table.buildId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get textCacheCount => $composableBuilder(
    column: $table.textCacheCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calendarCycleCount => $composableBuilder(
    column: $table.calendarCycleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeedMetadataTableOrderingComposer
    extends Composer<_$ContentDatabase, $SeedMetadataTable> {
  $$SeedMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get builtAt => $composableBuilder(
    column: $table.builtAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get buildId => $composableBuilder(
    column: $table.buildId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get textCacheCount => $composableBuilder(
    column: $table.textCacheCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calendarCycleCount => $composableBuilder(
    column: $table.calendarCycleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeedMetadataTableAnnotationComposer
    extends Composer<_$ContentDatabase, $SeedMetadataTable> {
  $$SeedMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get builtAt =>
      $composableBuilder(column: $table.builtAt, builder: (column) => column);

  GeneratedColumn<String> get buildId =>
      $composableBuilder(column: $table.buildId, builder: (column) => column);

  GeneratedColumn<int> get textCacheCount => $composableBuilder(
    column: $table.textCacheCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calendarCycleCount => $composableBuilder(
    column: $table.calendarCycleCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => column,
  );
}

class $$SeedMetadataTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $SeedMetadataTable,
          SeedMetadataData,
          $$SeedMetadataTableFilterComposer,
          $$SeedMetadataTableOrderingComposer,
          $$SeedMetadataTableAnnotationComposer,
          $$SeedMetadataTableCreateCompanionBuilder,
          $$SeedMetadataTableUpdateCompanionBuilder,
          (
            SeedMetadataData,
            BaseReferences<
              _$ContentDatabase,
              $SeedMetadataTable,
              SeedMetadataData
            >,
          ),
          SeedMetadataData,
          PrefetchHooks Function()
        > {
  $$SeedMetadataTableTableManager(
    _$ContentDatabase db,
    $SeedMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeedMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeedMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeedMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String> builtAt = const Value.absent(),
                Value<String> buildId = const Value.absent(),
                Value<int> textCacheCount = const Value.absent(),
                Value<int> calendarCycleCount = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
              }) => SeedMetadataCompanion(
                version: version,
                builtAt: builtAt,
                buildId: buildId,
                textCacheCount: textCacheCount,
                calendarCycleCount: calendarCycleCount,
                contentHash: contentHash,
                minAppVersion: minAppVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                required String builtAt,
                required String buildId,
                required int textCacheCount,
                required int calendarCycleCount,
                Value<String?> contentHash = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
              }) => SeedMetadataCompanion.insert(
                version: version,
                builtAt: builtAt,
                buildId: buildId,
                textCacheCount: textCacheCount,
                calendarCycleCount: calendarCycleCount,
                contentHash: contentHash,
                minAppVersion: minAppVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeedMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $SeedMetadataTable,
      SeedMetadataData,
      $$SeedMetadataTableFilterComposer,
      $$SeedMetadataTableOrderingComposer,
      $$SeedMetadataTableAnnotationComposer,
      $$SeedMetadataTableCreateCompanionBuilder,
      $$SeedMetadataTableUpdateCompanionBuilder,
      (
        SeedMetadataData,
        BaseReferences<_$ContentDatabase, $SeedMetadataTable, SeedMetadataData>,
      ),
      SeedMetadataData,
      PrefetchHooks Function()
    >;

class $ContentDatabaseManager {
  final _$ContentDatabase _db;
  $ContentDatabaseManager(this._db);
  $$TextCacheTableTableManager get textCache =>
      $$TextCacheTableTableManager(_db, _db.textCache);
  $$CalendarCyclesTableTableManager get calendarCycles =>
      $$CalendarCyclesTableTableManager(_db, _db.calendarCycles);
  $$DailyContentTableTableManager get dailyContent =>
      $$DailyContentTableTableManager(_db, _db.dailyContent);
  $$SeedMetadataTableTableManager get seedMetadata =>
      $$SeedMetadataTableTableManager(_db, _db.seedMetadata);
}
