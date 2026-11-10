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
  static const VerificationMeta _parallelTextCountMeta = const VerificationMeta(
    'parallelTextCount',
  );
  @override
  late final GeneratedColumn<int> parallelTextCount = GeneratedColumn<int>(
    'parallel_text_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _parshaAliyahCountMeta = const VerificationMeta(
    'parshaAliyahCount',
  );
  @override
  late final GeneratedColumn<int> parshaAliyahCount = GeneratedColumn<int>(
    'parsha_aliyah_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    parallelTextCount,
    parshaAliyahCount,
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
    if (data.containsKey('parallel_text_count')) {
      context.handle(
        _parallelTextCountMeta,
        parallelTextCount.isAcceptableOrUnknown(
          data['parallel_text_count']!,
          _parallelTextCountMeta,
        ),
      );
    }
    if (data.containsKey('parsha_aliyah_count')) {
      context.handle(
        _parshaAliyahCountMeta,
        parshaAliyahCount.isAcceptableOrUnknown(
          data['parsha_aliyah_count']!,
          _parshaAliyahCountMeta,
        ),
      );
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
      parallelTextCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parallel_text_count'],
      )!,
      parshaAliyahCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parsha_aliyah_count'],
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

  /// Number of bundled Onkelos and Rashi text rows.
  final int parallelTextCount;

  /// Number of bundled weekly and festival aliyah boundary rows.
  final int parshaAliyahCount;

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
    required this.parallelTextCount,
    required this.parshaAliyahCount,
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
    map['parallel_text_count'] = Variable<int>(parallelTextCount);
    map['parsha_aliyah_count'] = Variable<int>(parshaAliyahCount);
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
      parallelTextCount: Value(parallelTextCount),
      parshaAliyahCount: Value(parshaAliyahCount),
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
      parallelTextCount: serializer.fromJson<int>(json['parallelTextCount']),
      parshaAliyahCount: serializer.fromJson<int>(json['parshaAliyahCount']),
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
      'parallelTextCount': serializer.toJson<int>(parallelTextCount),
      'parshaAliyahCount': serializer.toJson<int>(parshaAliyahCount),
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
    int? parallelTextCount,
    int? parshaAliyahCount,
    Value<String?> contentHash = const Value.absent(),
    String? minAppVersion,
  }) => SeedMetadataData(
    version: version ?? this.version,
    builtAt: builtAt ?? this.builtAt,
    buildId: buildId ?? this.buildId,
    textCacheCount: textCacheCount ?? this.textCacheCount,
    calendarCycleCount: calendarCycleCount ?? this.calendarCycleCount,
    parallelTextCount: parallelTextCount ?? this.parallelTextCount,
    parshaAliyahCount: parshaAliyahCount ?? this.parshaAliyahCount,
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
      parallelTextCount: data.parallelTextCount.present
          ? data.parallelTextCount.value
          : this.parallelTextCount,
      parshaAliyahCount: data.parshaAliyahCount.present
          ? data.parshaAliyahCount.value
          : this.parshaAliyahCount,
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
          ..write('parallelTextCount: $parallelTextCount, ')
          ..write('parshaAliyahCount: $parshaAliyahCount, ')
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
    parallelTextCount,
    parshaAliyahCount,
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
          other.parallelTextCount == this.parallelTextCount &&
          other.parshaAliyahCount == this.parshaAliyahCount &&
          other.contentHash == this.contentHash &&
          other.minAppVersion == this.minAppVersion);
}

class SeedMetadataCompanion extends UpdateCompanion<SeedMetadataData> {
  final Value<int> version;
  final Value<String> builtAt;
  final Value<String> buildId;
  final Value<int> textCacheCount;
  final Value<int> calendarCycleCount;
  final Value<int> parallelTextCount;
  final Value<int> parshaAliyahCount;
  final Value<String?> contentHash;
  final Value<String> minAppVersion;
  const SeedMetadataCompanion({
    this.version = const Value.absent(),
    this.builtAt = const Value.absent(),
    this.buildId = const Value.absent(),
    this.textCacheCount = const Value.absent(),
    this.calendarCycleCount = const Value.absent(),
    this.parallelTextCount = const Value.absent(),
    this.parshaAliyahCount = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.minAppVersion = const Value.absent(),
  });
  SeedMetadataCompanion.insert({
    this.version = const Value.absent(),
    required String builtAt,
    required String buildId,
    required int textCacheCount,
    required int calendarCycleCount,
    this.parallelTextCount = const Value.absent(),
    this.parshaAliyahCount = const Value.absent(),
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
    Expression<int>? parallelTextCount,
    Expression<int>? parshaAliyahCount,
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
      if (parallelTextCount != null) 'parallel_text_count': parallelTextCount,
      if (parshaAliyahCount != null) 'parsha_aliyah_count': parshaAliyahCount,
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
    Value<int>? parallelTextCount,
    Value<int>? parshaAliyahCount,
    Value<String?>? contentHash,
    Value<String>? minAppVersion,
  }) {
    return SeedMetadataCompanion(
      version: version ?? this.version,
      builtAt: builtAt ?? this.builtAt,
      buildId: buildId ?? this.buildId,
      textCacheCount: textCacheCount ?? this.textCacheCount,
      calendarCycleCount: calendarCycleCount ?? this.calendarCycleCount,
      parallelTextCount: parallelTextCount ?? this.parallelTextCount,
      parshaAliyahCount: parshaAliyahCount ?? this.parshaAliyahCount,
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
    if (parallelTextCount.present) {
      map['parallel_text_count'] = Variable<int>(parallelTextCount.value);
    }
    if (parshaAliyahCount.present) {
      map['parsha_aliyah_count'] = Variable<int>(parshaAliyahCount.value);
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
          ..write('parallelTextCount: $parallelTextCount, ')
          ..write('parshaAliyahCount: $parshaAliyahCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('minAppVersion: $minAppVersion')
          ..write(')'))
        .toString();
  }
}

class $ParallelTextTable extends ParallelText
    with TableInfo<$ParallelTextTable, ParallelTextData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParallelTextTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _versionTitleMeta = const VerificationMeta(
    'versionTitle',
  );
  @override
  late final GeneratedColumn<String> versionTitle = GeneratedColumn<String>(
    'version_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceKey,
    sefariaRef,
    hebrewText,
    englishText,
    versionTitle,
    license,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parallel_text';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParallelTextData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
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
    }
    if (data.containsKey('version_title')) {
      context.handle(
        _versionTitleMeta,
        versionTitle.isAcceptableOrUnknown(
          data['version_title']!,
          _versionTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionTitleMeta);
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
      );
    } else if (isInserting) {
      context.missing(_licenseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceKey, sefariaRef};
  @override
  ParallelTextData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParallelTextData(
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
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
      versionTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_title'],
      )!,
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      )!,
    );
  }

  @override
  $ParallelTextTable createAlias(String alias) {
    return $ParallelTextTable(attachedDatabase, alias);
  }
}

class ParallelTextData extends DataClass
    implements Insertable<ParallelTextData> {
  final String sourceKey;
  final String sefariaRef;
  final String hebrewText;
  final String englishText;
  final String versionTitle;
  final String license;
  const ParallelTextData({
    required this.sourceKey,
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
    required this.versionTitle,
    required this.license,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_key'] = Variable<String>(sourceKey);
    map['sefaria_ref'] = Variable<String>(sefariaRef);
    map['hebrew_text'] = Variable<String>(hebrewText);
    map['english_text'] = Variable<String>(englishText);
    map['version_title'] = Variable<String>(versionTitle);
    map['license'] = Variable<String>(license);
    return map;
  }

  ParallelTextCompanion toCompanion(bool nullToAbsent) {
    return ParallelTextCompanion(
      sourceKey: Value(sourceKey),
      sefariaRef: Value(sefariaRef),
      hebrewText: Value(hebrewText),
      englishText: Value(englishText),
      versionTitle: Value(versionTitle),
      license: Value(license),
    );
  }

  factory ParallelTextData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParallelTextData(
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      sefariaRef: serializer.fromJson<String>(json['sefariaRef']),
      hebrewText: serializer.fromJson<String>(json['hebrewText']),
      englishText: serializer.fromJson<String>(json['englishText']),
      versionTitle: serializer.fromJson<String>(json['versionTitle']),
      license: serializer.fromJson<String>(json['license']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceKey': serializer.toJson<String>(sourceKey),
      'sefariaRef': serializer.toJson<String>(sefariaRef),
      'hebrewText': serializer.toJson<String>(hebrewText),
      'englishText': serializer.toJson<String>(englishText),
      'versionTitle': serializer.toJson<String>(versionTitle),
      'license': serializer.toJson<String>(license),
    };
  }

  ParallelTextData copyWith({
    String? sourceKey,
    String? sefariaRef,
    String? hebrewText,
    String? englishText,
    String? versionTitle,
    String? license,
  }) => ParallelTextData(
    sourceKey: sourceKey ?? this.sourceKey,
    sefariaRef: sefariaRef ?? this.sefariaRef,
    hebrewText: hebrewText ?? this.hebrewText,
    englishText: englishText ?? this.englishText,
    versionTitle: versionTitle ?? this.versionTitle,
    license: license ?? this.license,
  );
  ParallelTextData copyWithCompanion(ParallelTextCompanion data) {
    return ParallelTextData(
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      sefariaRef: data.sefariaRef.present
          ? data.sefariaRef.value
          : this.sefariaRef,
      hebrewText: data.hebrewText.present
          ? data.hebrewText.value
          : this.hebrewText,
      englishText: data.englishText.present
          ? data.englishText.value
          : this.englishText,
      versionTitle: data.versionTitle.present
          ? data.versionTitle.value
          : this.versionTitle,
      license: data.license.present ? data.license.value : this.license,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParallelTextData(')
          ..write('sourceKey: $sourceKey, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('hebrewText: $hebrewText, ')
          ..write('englishText: $englishText, ')
          ..write('versionTitle: $versionTitle, ')
          ..write('license: $license')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceKey,
    sefariaRef,
    hebrewText,
    englishText,
    versionTitle,
    license,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParallelTextData &&
          other.sourceKey == this.sourceKey &&
          other.sefariaRef == this.sefariaRef &&
          other.hebrewText == this.hebrewText &&
          other.englishText == this.englishText &&
          other.versionTitle == this.versionTitle &&
          other.license == this.license);
}

class ParallelTextCompanion extends UpdateCompanion<ParallelTextData> {
  final Value<String> sourceKey;
  final Value<String> sefariaRef;
  final Value<String> hebrewText;
  final Value<String> englishText;
  final Value<String> versionTitle;
  final Value<String> license;
  final Value<int> rowid;
  const ParallelTextCompanion({
    this.sourceKey = const Value.absent(),
    this.sefariaRef = const Value.absent(),
    this.hebrewText = const Value.absent(),
    this.englishText = const Value.absent(),
    this.versionTitle = const Value.absent(),
    this.license = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParallelTextCompanion.insert({
    required String sourceKey,
    required String sefariaRef,
    required String hebrewText,
    this.englishText = const Value.absent(),
    required String versionTitle,
    required String license,
    this.rowid = const Value.absent(),
  }) : sourceKey = Value(sourceKey),
       sefariaRef = Value(sefariaRef),
       hebrewText = Value(hebrewText),
       versionTitle = Value(versionTitle),
       license = Value(license);
  static Insertable<ParallelTextData> custom({
    Expression<String>? sourceKey,
    Expression<String>? sefariaRef,
    Expression<String>? hebrewText,
    Expression<String>? englishText,
    Expression<String>? versionTitle,
    Expression<String>? license,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceKey != null) 'source_key': sourceKey,
      if (sefariaRef != null) 'sefaria_ref': sefariaRef,
      if (hebrewText != null) 'hebrew_text': hebrewText,
      if (englishText != null) 'english_text': englishText,
      if (versionTitle != null) 'version_title': versionTitle,
      if (license != null) 'license': license,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParallelTextCompanion copyWith({
    Value<String>? sourceKey,
    Value<String>? sefariaRef,
    Value<String>? hebrewText,
    Value<String>? englishText,
    Value<String>? versionTitle,
    Value<String>? license,
    Value<int>? rowid,
  }) {
    return ParallelTextCompanion(
      sourceKey: sourceKey ?? this.sourceKey,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      hebrewText: hebrewText ?? this.hebrewText,
      englishText: englishText ?? this.englishText,
      versionTitle: versionTitle ?? this.versionTitle,
      license: license ?? this.license,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (sefariaRef.present) {
      map['sefaria_ref'] = Variable<String>(sefariaRef.value);
    }
    if (hebrewText.present) {
      map['hebrew_text'] = Variable<String>(hebrewText.value);
    }
    if (englishText.present) {
      map['english_text'] = Variable<String>(englishText.value);
    }
    if (versionTitle.present) {
      map['version_title'] = Variable<String>(versionTitle.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParallelTextCompanion(')
          ..write('sourceKey: $sourceKey, ')
          ..write('sefariaRef: $sefariaRef, ')
          ..write('hebrewText: $hebrewText, ')
          ..write('englishText: $englishText, ')
          ..write('versionTitle: $versionTitle, ')
          ..write('license: $license, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParshaAliyotTable extends ParshaAliyot
    with TableInfo<$ParshaAliyotTable, ParshaAliyotData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParshaAliyotTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _portionKeyMeta = const VerificationMeta(
    'portionKey',
  );
  @override
  late final GeneratedColumn<String> portionKey = GeneratedColumn<String>(
    'portion_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portionNameMeta = const VerificationMeta(
    'portionName',
  );
  @override
  late final GeneratedColumn<String> portionName = GeneratedColumn<String>(
    'portion_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('any'),
  );
  static const VerificationMeta _aliyahNumberMeta = const VerificationMeta(
    'aliyahNumber',
  );
  @override
  late final GeneratedColumn<int> aliyahNumber = GeneratedColumn<int>(
    'aliyah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startRefMeta = const VerificationMeta(
    'startRef',
  );
  @override
  late final GeneratedColumn<String> startRef = GeneratedColumn<String>(
    'start_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endRefMeta = const VerificationMeta('endRef');
  @override
  late final GeneratedColumn<String> endRef = GeneratedColumn<String>(
    'end_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    portionKey,
    portionName,
    region,
    aliyahNumber,
    startRef,
    endRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parsha_aliyot';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParshaAliyotData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('portion_key')) {
      context.handle(
        _portionKeyMeta,
        portionKey.isAcceptableOrUnknown(data['portion_key']!, _portionKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_portionKeyMeta);
    }
    if (data.containsKey('portion_name')) {
      context.handle(
        _portionNameMeta,
        portionName.isAcceptableOrUnknown(
          data['portion_name']!,
          _portionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_portionNameMeta);
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('aliyah_number')) {
      context.handle(
        _aliyahNumberMeta,
        aliyahNumber.isAcceptableOrUnknown(
          data['aliyah_number']!,
          _aliyahNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aliyahNumberMeta);
    }
    if (data.containsKey('start_ref')) {
      context.handle(
        _startRefMeta,
        startRef.isAcceptableOrUnknown(data['start_ref']!, _startRefMeta),
      );
    } else if (isInserting) {
      context.missing(_startRefMeta);
    }
    if (data.containsKey('end_ref')) {
      context.handle(
        _endRefMeta,
        endRef.isAcceptableOrUnknown(data['end_ref']!, _endRefMeta),
      );
    } else if (isInserting) {
      context.missing(_endRefMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {portionKey, region, aliyahNumber};
  @override
  ParshaAliyotData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParshaAliyotData(
      portionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portion_key'],
      )!,
      portionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portion_name'],
      )!,
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      )!,
      aliyahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aliyah_number'],
      )!,
      startRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_ref'],
      )!,
      endRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_ref'],
      )!,
    );
  }

  @override
  $ParshaAliyotTable createAlias(String alias) {
    return $ParshaAliyotTable(attachedDatabase, alias);
  }
}

class ParshaAliyotData extends DataClass
    implements Insertable<ParshaAliyotData> {
  final String portionKey;
  final String portionName;
  final String region;
  final int aliyahNumber;
  final String startRef;
  final String endRef;
  const ParshaAliyotData({
    required this.portionKey,
    required this.portionName,
    required this.region,
    required this.aliyahNumber,
    required this.startRef,
    required this.endRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['portion_key'] = Variable<String>(portionKey);
    map['portion_name'] = Variable<String>(portionName);
    map['region'] = Variable<String>(region);
    map['aliyah_number'] = Variable<int>(aliyahNumber);
    map['start_ref'] = Variable<String>(startRef);
    map['end_ref'] = Variable<String>(endRef);
    return map;
  }

  ParshaAliyotCompanion toCompanion(bool nullToAbsent) {
    return ParshaAliyotCompanion(
      portionKey: Value(portionKey),
      portionName: Value(portionName),
      region: Value(region),
      aliyahNumber: Value(aliyahNumber),
      startRef: Value(startRef),
      endRef: Value(endRef),
    );
  }

  factory ParshaAliyotData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParshaAliyotData(
      portionKey: serializer.fromJson<String>(json['portionKey']),
      portionName: serializer.fromJson<String>(json['portionName']),
      region: serializer.fromJson<String>(json['region']),
      aliyahNumber: serializer.fromJson<int>(json['aliyahNumber']),
      startRef: serializer.fromJson<String>(json['startRef']),
      endRef: serializer.fromJson<String>(json['endRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'portionKey': serializer.toJson<String>(portionKey),
      'portionName': serializer.toJson<String>(portionName),
      'region': serializer.toJson<String>(region),
      'aliyahNumber': serializer.toJson<int>(aliyahNumber),
      'startRef': serializer.toJson<String>(startRef),
      'endRef': serializer.toJson<String>(endRef),
    };
  }

  ParshaAliyotData copyWith({
    String? portionKey,
    String? portionName,
    String? region,
    int? aliyahNumber,
    String? startRef,
    String? endRef,
  }) => ParshaAliyotData(
    portionKey: portionKey ?? this.portionKey,
    portionName: portionName ?? this.portionName,
    region: region ?? this.region,
    aliyahNumber: aliyahNumber ?? this.aliyahNumber,
    startRef: startRef ?? this.startRef,
    endRef: endRef ?? this.endRef,
  );
  ParshaAliyotData copyWithCompanion(ParshaAliyotCompanion data) {
    return ParshaAliyotData(
      portionKey: data.portionKey.present
          ? data.portionKey.value
          : this.portionKey,
      portionName: data.portionName.present
          ? data.portionName.value
          : this.portionName,
      region: data.region.present ? data.region.value : this.region,
      aliyahNumber: data.aliyahNumber.present
          ? data.aliyahNumber.value
          : this.aliyahNumber,
      startRef: data.startRef.present ? data.startRef.value : this.startRef,
      endRef: data.endRef.present ? data.endRef.value : this.endRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParshaAliyotData(')
          ..write('portionKey: $portionKey, ')
          ..write('portionName: $portionName, ')
          ..write('region: $region, ')
          ..write('aliyahNumber: $aliyahNumber, ')
          ..write('startRef: $startRef, ')
          ..write('endRef: $endRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    portionKey,
    portionName,
    region,
    aliyahNumber,
    startRef,
    endRef,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParshaAliyotData &&
          other.portionKey == this.portionKey &&
          other.portionName == this.portionName &&
          other.region == this.region &&
          other.aliyahNumber == this.aliyahNumber &&
          other.startRef == this.startRef &&
          other.endRef == this.endRef);
}

class ParshaAliyotCompanion extends UpdateCompanion<ParshaAliyotData> {
  final Value<String> portionKey;
  final Value<String> portionName;
  final Value<String> region;
  final Value<int> aliyahNumber;
  final Value<String> startRef;
  final Value<String> endRef;
  final Value<int> rowid;
  const ParshaAliyotCompanion({
    this.portionKey = const Value.absent(),
    this.portionName = const Value.absent(),
    this.region = const Value.absent(),
    this.aliyahNumber = const Value.absent(),
    this.startRef = const Value.absent(),
    this.endRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParshaAliyotCompanion.insert({
    required String portionKey,
    required String portionName,
    this.region = const Value.absent(),
    required int aliyahNumber,
    required String startRef,
    required String endRef,
    this.rowid = const Value.absent(),
  }) : portionKey = Value(portionKey),
       portionName = Value(portionName),
       aliyahNumber = Value(aliyahNumber),
       startRef = Value(startRef),
       endRef = Value(endRef);
  static Insertable<ParshaAliyotData> custom({
    Expression<String>? portionKey,
    Expression<String>? portionName,
    Expression<String>? region,
    Expression<int>? aliyahNumber,
    Expression<String>? startRef,
    Expression<String>? endRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (portionKey != null) 'portion_key': portionKey,
      if (portionName != null) 'portion_name': portionName,
      if (region != null) 'region': region,
      if (aliyahNumber != null) 'aliyah_number': aliyahNumber,
      if (startRef != null) 'start_ref': startRef,
      if (endRef != null) 'end_ref': endRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParshaAliyotCompanion copyWith({
    Value<String>? portionKey,
    Value<String>? portionName,
    Value<String>? region,
    Value<int>? aliyahNumber,
    Value<String>? startRef,
    Value<String>? endRef,
    Value<int>? rowid,
  }) {
    return ParshaAliyotCompanion(
      portionKey: portionKey ?? this.portionKey,
      portionName: portionName ?? this.portionName,
      region: region ?? this.region,
      aliyahNumber: aliyahNumber ?? this.aliyahNumber,
      startRef: startRef ?? this.startRef,
      endRef: endRef ?? this.endRef,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (portionKey.present) {
      map['portion_key'] = Variable<String>(portionKey.value);
    }
    if (portionName.present) {
      map['portion_name'] = Variable<String>(portionName.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (aliyahNumber.present) {
      map['aliyah_number'] = Variable<int>(aliyahNumber.value);
    }
    if (startRef.present) {
      map['start_ref'] = Variable<String>(startRef.value);
    }
    if (endRef.present) {
      map['end_ref'] = Variable<String>(endRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParshaAliyotCompanion(')
          ..write('portionKey: $portionKey, ')
          ..write('portionName: $portionName, ')
          ..write('region: $region, ')
          ..write('aliyahNumber: $aliyahNumber, ')
          ..write('startRef: $startRef, ')
          ..write('endRef: $endRef, ')
          ..write('rowid: $rowid')
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
  late final $ParallelTextTable parallelText = $ParallelTextTable(this);
  late final $ParshaAliyotTable parshaAliyot = $ParshaAliyotTable(this);
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
    parallelText,
    parshaAliyot,
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
      Value<int> parallelTextCount,
      Value<int> parshaAliyahCount,
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
      Value<int> parallelTextCount,
      Value<int> parshaAliyahCount,
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

  ColumnFilters<int> get parallelTextCount => $composableBuilder(
    column: $table.parallelTextCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parshaAliyahCount => $composableBuilder(
    column: $table.parshaAliyahCount,
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

  ColumnOrderings<int> get parallelTextCount => $composableBuilder(
    column: $table.parallelTextCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parshaAliyahCount => $composableBuilder(
    column: $table.parshaAliyahCount,
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

  GeneratedColumn<int> get parallelTextCount => $composableBuilder(
    column: $table.parallelTextCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parshaAliyahCount => $composableBuilder(
    column: $table.parshaAliyahCount,
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
                Value<int> parallelTextCount = const Value.absent(),
                Value<int> parshaAliyahCount = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
              }) => SeedMetadataCompanion(
                version: version,
                builtAt: builtAt,
                buildId: buildId,
                textCacheCount: textCacheCount,
                calendarCycleCount: calendarCycleCount,
                parallelTextCount: parallelTextCount,
                parshaAliyahCount: parshaAliyahCount,
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
                Value<int> parallelTextCount = const Value.absent(),
                Value<int> parshaAliyahCount = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
              }) => SeedMetadataCompanion.insert(
                version: version,
                builtAt: builtAt,
                buildId: buildId,
                textCacheCount: textCacheCount,
                calendarCycleCount: calendarCycleCount,
                parallelTextCount: parallelTextCount,
                parshaAliyahCount: parshaAliyahCount,
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
typedef $$ParallelTextTableCreateCompanionBuilder =
    ParallelTextCompanion Function({
      required String sourceKey,
      required String sefariaRef,
      required String hebrewText,
      Value<String> englishText,
      required String versionTitle,
      required String license,
      Value<int> rowid,
    });
typedef $$ParallelTextTableUpdateCompanionBuilder =
    ParallelTextCompanion Function({
      Value<String> sourceKey,
      Value<String> sefariaRef,
      Value<String> hebrewText,
      Value<String> englishText,
      Value<String> versionTitle,
      Value<String> license,
      Value<int> rowid,
    });

class $$ParallelTextTableFilterComposer
    extends Composer<_$ContentDatabase, $ParallelTextTable> {
  $$ParallelTextTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnFilters<String> get versionTitle => $composableBuilder(
    column: $table.versionTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParallelTextTableOrderingComposer
    extends Composer<_$ContentDatabase, $ParallelTextTable> {
  $$ParallelTextTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

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

  ColumnOrderings<String> get versionTitle => $composableBuilder(
    column: $table.versionTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParallelTextTableAnnotationComposer
    extends Composer<_$ContentDatabase, $ParallelTextTable> {
  $$ParallelTextTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

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

  GeneratedColumn<String> get versionTitle => $composableBuilder(
    column: $table.versionTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);
}

class $$ParallelTextTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $ParallelTextTable,
          ParallelTextData,
          $$ParallelTextTableFilterComposer,
          $$ParallelTextTableOrderingComposer,
          $$ParallelTextTableAnnotationComposer,
          $$ParallelTextTableCreateCompanionBuilder,
          $$ParallelTextTableUpdateCompanionBuilder,
          (
            ParallelTextData,
            BaseReferences<
              _$ContentDatabase,
              $ParallelTextTable,
              ParallelTextData
            >,
          ),
          ParallelTextData,
          PrefetchHooks Function()
        > {
  $$ParallelTextTableTableManager(
    _$ContentDatabase db,
    $ParallelTextTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParallelTextTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParallelTextTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParallelTextTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceKey = const Value.absent(),
                Value<String> sefariaRef = const Value.absent(),
                Value<String> hebrewText = const Value.absent(),
                Value<String> englishText = const Value.absent(),
                Value<String> versionTitle = const Value.absent(),
                Value<String> license = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParallelTextCompanion(
                sourceKey: sourceKey,
                sefariaRef: sefariaRef,
                hebrewText: hebrewText,
                englishText: englishText,
                versionTitle: versionTitle,
                license: license,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceKey,
                required String sefariaRef,
                required String hebrewText,
                Value<String> englishText = const Value.absent(),
                required String versionTitle,
                required String license,
                Value<int> rowid = const Value.absent(),
              }) => ParallelTextCompanion.insert(
                sourceKey: sourceKey,
                sefariaRef: sefariaRef,
                hebrewText: hebrewText,
                englishText: englishText,
                versionTitle: versionTitle,
                license: license,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParallelTextTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $ParallelTextTable,
      ParallelTextData,
      $$ParallelTextTableFilterComposer,
      $$ParallelTextTableOrderingComposer,
      $$ParallelTextTableAnnotationComposer,
      $$ParallelTextTableCreateCompanionBuilder,
      $$ParallelTextTableUpdateCompanionBuilder,
      (
        ParallelTextData,
        BaseReferences<_$ContentDatabase, $ParallelTextTable, ParallelTextData>,
      ),
      ParallelTextData,
      PrefetchHooks Function()
    >;
typedef $$ParshaAliyotTableCreateCompanionBuilder =
    ParshaAliyotCompanion Function({
      required String portionKey,
      required String portionName,
      Value<String> region,
      required int aliyahNumber,
      required String startRef,
      required String endRef,
      Value<int> rowid,
    });
typedef $$ParshaAliyotTableUpdateCompanionBuilder =
    ParshaAliyotCompanion Function({
      Value<String> portionKey,
      Value<String> portionName,
      Value<String> region,
      Value<int> aliyahNumber,
      Value<String> startRef,
      Value<String> endRef,
      Value<int> rowid,
    });

class $$ParshaAliyotTableFilterComposer
    extends Composer<_$ContentDatabase, $ParshaAliyotTable> {
  $$ParshaAliyotTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get portionKey => $composableBuilder(
    column: $table.portionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portionName => $composableBuilder(
    column: $table.portionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aliyahNumber => $composableBuilder(
    column: $table.aliyahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startRef => $composableBuilder(
    column: $table.startRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endRef => $composableBuilder(
    column: $table.endRef,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParshaAliyotTableOrderingComposer
    extends Composer<_$ContentDatabase, $ParshaAliyotTable> {
  $$ParshaAliyotTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get portionKey => $composableBuilder(
    column: $table.portionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portionName => $composableBuilder(
    column: $table.portionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aliyahNumber => $composableBuilder(
    column: $table.aliyahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startRef => $composableBuilder(
    column: $table.startRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endRef => $composableBuilder(
    column: $table.endRef,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParshaAliyotTableAnnotationComposer
    extends Composer<_$ContentDatabase, $ParshaAliyotTable> {
  $$ParshaAliyotTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get portionKey => $composableBuilder(
    column: $table.portionKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get portionName => $composableBuilder(
    column: $table.portionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<int> get aliyahNumber => $composableBuilder(
    column: $table.aliyahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startRef =>
      $composableBuilder(column: $table.startRef, builder: (column) => column);

  GeneratedColumn<String> get endRef =>
      $composableBuilder(column: $table.endRef, builder: (column) => column);
}

class $$ParshaAliyotTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $ParshaAliyotTable,
          ParshaAliyotData,
          $$ParshaAliyotTableFilterComposer,
          $$ParshaAliyotTableOrderingComposer,
          $$ParshaAliyotTableAnnotationComposer,
          $$ParshaAliyotTableCreateCompanionBuilder,
          $$ParshaAliyotTableUpdateCompanionBuilder,
          (
            ParshaAliyotData,
            BaseReferences<
              _$ContentDatabase,
              $ParshaAliyotTable,
              ParshaAliyotData
            >,
          ),
          ParshaAliyotData,
          PrefetchHooks Function()
        > {
  $$ParshaAliyotTableTableManager(
    _$ContentDatabase db,
    $ParshaAliyotTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParshaAliyotTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParshaAliyotTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParshaAliyotTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> portionKey = const Value.absent(),
                Value<String> portionName = const Value.absent(),
                Value<String> region = const Value.absent(),
                Value<int> aliyahNumber = const Value.absent(),
                Value<String> startRef = const Value.absent(),
                Value<String> endRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParshaAliyotCompanion(
                portionKey: portionKey,
                portionName: portionName,
                region: region,
                aliyahNumber: aliyahNumber,
                startRef: startRef,
                endRef: endRef,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String portionKey,
                required String portionName,
                Value<String> region = const Value.absent(),
                required int aliyahNumber,
                required String startRef,
                required String endRef,
                Value<int> rowid = const Value.absent(),
              }) => ParshaAliyotCompanion.insert(
                portionKey: portionKey,
                portionName: portionName,
                region: region,
                aliyahNumber: aliyahNumber,
                startRef: startRef,
                endRef: endRef,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParshaAliyotTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $ParshaAliyotTable,
      ParshaAliyotData,
      $$ParshaAliyotTableFilterComposer,
      $$ParshaAliyotTableOrderingComposer,
      $$ParshaAliyotTableAnnotationComposer,
      $$ParshaAliyotTableCreateCompanionBuilder,
      $$ParshaAliyotTableUpdateCompanionBuilder,
      (
        ParshaAliyotData,
        BaseReferences<_$ContentDatabase, $ParshaAliyotTable, ParshaAliyotData>,
      ),
      ParshaAliyotData,
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
  $$ParallelTextTableTableManager get parallelText =>
      $$ParallelTextTableTableManager(_db, _db.parallelText);
  $$ParshaAliyotTableTableManager get parshaAliyot =>
      $$ParshaAliyotTableTableManager(_db, _db.parshaAliyot);
}
