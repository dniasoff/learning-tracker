// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'add_track_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AddTrackResult {

 CurriculumId get curriculumId; String get label; int? get programId; String? get programName; List<ScopeEntry>? get scopeSelections; Map<int, String> get studyDays;/// Opaque wizard result — cast to `LearningProcessWizardResult`.
 Object? get wizardResult;/// Opaque goal result — cast to `GoalEntity`.
 Object? get goalResult;/// Opaque bulk mark result — cast to `BulkMarkResult`.
 Object? get bulkMarkResult;/// Sefaria ref for program starting position (Screen 8 program mode).
 String? get startingRef;
/// Create a copy of AddTrackResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AddTrackResultCopyWith<AddTrackResult> get copyWith => _$AddTrackResultCopyWithImpl<AddTrackResult>(this as AddTrackResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AddTrackResult&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.label, label) || other.label == label)&&(identical(other.programId, programId) || other.programId == programId)&&(identical(other.programName, programName) || other.programName == programName)&&const DeepCollectionEquality().equals(other.scopeSelections, scopeSelections)&&const DeepCollectionEquality().equals(other.studyDays, studyDays)&&const DeepCollectionEquality().equals(other.wizardResult, wizardResult)&&const DeepCollectionEquality().equals(other.goalResult, goalResult)&&const DeepCollectionEquality().equals(other.bulkMarkResult, bulkMarkResult)&&(identical(other.startingRef, startingRef) || other.startingRef == startingRef));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,label,programId,programName,const DeepCollectionEquality().hash(scopeSelections),const DeepCollectionEquality().hash(studyDays),const DeepCollectionEquality().hash(wizardResult),const DeepCollectionEquality().hash(goalResult),const DeepCollectionEquality().hash(bulkMarkResult),startingRef);

@override
String toString() {
  return 'AddTrackResult(curriculumId: $curriculumId, label: $label, programId: $programId, programName: $programName, scopeSelections: $scopeSelections, studyDays: $studyDays, wizardResult: $wizardResult, goalResult: $goalResult, bulkMarkResult: $bulkMarkResult, startingRef: $startingRef)';
}


}

/// @nodoc
abstract mixin class $AddTrackResultCopyWith<$Res>  {
  factory $AddTrackResultCopyWith(AddTrackResult value, $Res Function(AddTrackResult) _then) = _$AddTrackResultCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculumId, String label, int? programId, String? programName, List<ScopeEntry>? scopeSelections, Map<int, String> studyDays, Object? wizardResult, Object? goalResult, Object? bulkMarkResult, String? startingRef
});




}
/// @nodoc
class _$AddTrackResultCopyWithImpl<$Res>
    implements $AddTrackResultCopyWith<$Res> {
  _$AddTrackResultCopyWithImpl(this._self, this._then);

  final AddTrackResult _self;
  final $Res Function(AddTrackResult) _then;

/// Create a copy of AddTrackResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? label = null,Object? programId = freezed,Object? programName = freezed,Object? scopeSelections = freezed,Object? studyDays = null,Object? wizardResult = freezed,Object? goalResult = freezed,Object? bulkMarkResult = freezed,Object? startingRef = freezed,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,programId: freezed == programId ? _self.programId : programId // ignore: cast_nullable_to_non_nullable
as int?,programName: freezed == programName ? _self.programName : programName // ignore: cast_nullable_to_non_nullable
as String?,scopeSelections: freezed == scopeSelections ? _self.scopeSelections : scopeSelections // ignore: cast_nullable_to_non_nullable
as List<ScopeEntry>?,studyDays: null == studyDays ? _self.studyDays : studyDays // ignore: cast_nullable_to_non_nullable
as Map<int, String>,wizardResult: freezed == wizardResult ? _self.wizardResult : wizardResult ,goalResult: freezed == goalResult ? _self.goalResult : goalResult ,bulkMarkResult: freezed == bulkMarkResult ? _self.bulkMarkResult : bulkMarkResult ,startingRef: freezed == startingRef ? _self.startingRef : startingRef // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AddTrackResult].
extension AddTrackResultPatterns on AddTrackResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AddTrackResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AddTrackResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AddTrackResult value)  $default,){
final _that = this;
switch (_that) {
case _AddTrackResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AddTrackResult value)?  $default,){
final _that = this;
switch (_that) {
case _AddTrackResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  String label,  int? programId,  String? programName,  List<ScopeEntry>? scopeSelections,  Map<int, String> studyDays,  Object? wizardResult,  Object? goalResult,  Object? bulkMarkResult,  String? startingRef)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AddTrackResult() when $default != null:
return $default(_that.curriculumId,_that.label,_that.programId,_that.programName,_that.scopeSelections,_that.studyDays,_that.wizardResult,_that.goalResult,_that.bulkMarkResult,_that.startingRef);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  String label,  int? programId,  String? programName,  List<ScopeEntry>? scopeSelections,  Map<int, String> studyDays,  Object? wizardResult,  Object? goalResult,  Object? bulkMarkResult,  String? startingRef)  $default,) {final _that = this;
switch (_that) {
case _AddTrackResult():
return $default(_that.curriculumId,_that.label,_that.programId,_that.programName,_that.scopeSelections,_that.studyDays,_that.wizardResult,_that.goalResult,_that.bulkMarkResult,_that.startingRef);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculumId,  String label,  int? programId,  String? programName,  List<ScopeEntry>? scopeSelections,  Map<int, String> studyDays,  Object? wizardResult,  Object? goalResult,  Object? bulkMarkResult,  String? startingRef)?  $default,) {final _that = this;
switch (_that) {
case _AddTrackResult() when $default != null:
return $default(_that.curriculumId,_that.label,_that.programId,_that.programName,_that.scopeSelections,_that.studyDays,_that.wizardResult,_that.goalResult,_that.bulkMarkResult,_that.startingRef);case _:
  return null;

}
}

}

/// @nodoc


class _AddTrackResult implements AddTrackResult {
  const _AddTrackResult({required this.curriculumId, required this.label, this.programId, this.programName, final  List<ScopeEntry>? scopeSelections, required final  Map<int, String> studyDays, this.wizardResult, this.goalResult, this.bulkMarkResult, this.startingRef}): _scopeSelections = scopeSelections,_studyDays = studyDays;
  

@override final  CurriculumId curriculumId;
@override final  String label;
@override final  int? programId;
@override final  String? programName;
 final  List<ScopeEntry>? _scopeSelections;
@override List<ScopeEntry>? get scopeSelections {
  final value = _scopeSelections;
  if (value == null) return null;
  if (_scopeSelections is EqualUnmodifiableListView) return _scopeSelections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  Map<int, String> _studyDays;
@override Map<int, String> get studyDays {
  if (_studyDays is EqualUnmodifiableMapView) return _studyDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_studyDays);
}

/// Opaque wizard result — cast to `LearningProcessWizardResult`.
@override final  Object? wizardResult;
/// Opaque goal result — cast to `GoalEntity`.
@override final  Object? goalResult;
/// Opaque bulk mark result — cast to `BulkMarkResult`.
@override final  Object? bulkMarkResult;
/// Sefaria ref for program starting position (Screen 8 program mode).
@override final  String? startingRef;

/// Create a copy of AddTrackResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddTrackResultCopyWith<_AddTrackResult> get copyWith => __$AddTrackResultCopyWithImpl<_AddTrackResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AddTrackResult&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.label, label) || other.label == label)&&(identical(other.programId, programId) || other.programId == programId)&&(identical(other.programName, programName) || other.programName == programName)&&const DeepCollectionEquality().equals(other._scopeSelections, _scopeSelections)&&const DeepCollectionEquality().equals(other._studyDays, _studyDays)&&const DeepCollectionEquality().equals(other.wizardResult, wizardResult)&&const DeepCollectionEquality().equals(other.goalResult, goalResult)&&const DeepCollectionEquality().equals(other.bulkMarkResult, bulkMarkResult)&&(identical(other.startingRef, startingRef) || other.startingRef == startingRef));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,label,programId,programName,const DeepCollectionEquality().hash(_scopeSelections),const DeepCollectionEquality().hash(_studyDays),const DeepCollectionEquality().hash(wizardResult),const DeepCollectionEquality().hash(goalResult),const DeepCollectionEquality().hash(bulkMarkResult),startingRef);

@override
String toString() {
  return 'AddTrackResult(curriculumId: $curriculumId, label: $label, programId: $programId, programName: $programName, scopeSelections: $scopeSelections, studyDays: $studyDays, wizardResult: $wizardResult, goalResult: $goalResult, bulkMarkResult: $bulkMarkResult, startingRef: $startingRef)';
}


}

/// @nodoc
abstract mixin class _$AddTrackResultCopyWith<$Res> implements $AddTrackResultCopyWith<$Res> {
  factory _$AddTrackResultCopyWith(_AddTrackResult value, $Res Function(_AddTrackResult) _then) = __$AddTrackResultCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculumId, String label, int? programId, String? programName, List<ScopeEntry>? scopeSelections, Map<int, String> studyDays, Object? wizardResult, Object? goalResult, Object? bulkMarkResult, String? startingRef
});




}
/// @nodoc
class __$AddTrackResultCopyWithImpl<$Res>
    implements _$AddTrackResultCopyWith<$Res> {
  __$AddTrackResultCopyWithImpl(this._self, this._then);

  final _AddTrackResult _self;
  final $Res Function(_AddTrackResult) _then;

/// Create a copy of AddTrackResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? label = null,Object? programId = freezed,Object? programName = freezed,Object? scopeSelections = freezed,Object? studyDays = null,Object? wizardResult = freezed,Object? goalResult = freezed,Object? bulkMarkResult = freezed,Object? startingRef = freezed,}) {
  return _then(_AddTrackResult(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,programId: freezed == programId ? _self.programId : programId // ignore: cast_nullable_to_non_nullable
as int?,programName: freezed == programName ? _self.programName : programName // ignore: cast_nullable_to_non_nullable
as String?,scopeSelections: freezed == scopeSelections ? _self._scopeSelections : scopeSelections // ignore: cast_nullable_to_non_nullable
as List<ScopeEntry>?,studyDays: null == studyDays ? _self._studyDays : studyDays // ignore: cast_nullable_to_non_nullable
as Map<int, String>,wizardResult: freezed == wizardResult ? _self.wizardResult : wizardResult ,goalResult: freezed == goalResult ? _self.goalResult : goalResult ,bulkMarkResult: freezed == bulkMarkResult ? _self.bulkMarkResult : bulkMarkResult ,startingRef: freezed == startingRef ? _self.startingRef : startingRef // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ScopeEntry {

 int get level; String get value;
/// Create a copy of ScopeEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScopeEntryCopyWith<ScopeEntry> get copyWith => _$ScopeEntryCopyWithImpl<ScopeEntry>(this as ScopeEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScopeEntry&&(identical(other.level, level) || other.level == level)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,level,value);

@override
String toString() {
  return 'ScopeEntry(level: $level, value: $value)';
}


}

/// @nodoc
abstract mixin class $ScopeEntryCopyWith<$Res>  {
  factory $ScopeEntryCopyWith(ScopeEntry value, $Res Function(ScopeEntry) _then) = _$ScopeEntryCopyWithImpl;
@useResult
$Res call({
 int level, String value
});




}
/// @nodoc
class _$ScopeEntryCopyWithImpl<$Res>
    implements $ScopeEntryCopyWith<$Res> {
  _$ScopeEntryCopyWithImpl(this._self, this._then);

  final ScopeEntry _self;
  final $Res Function(ScopeEntry) _then;

/// Create a copy of ScopeEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? value = null,}) {
  return _then(_self.copyWith(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ScopeEntry].
extension ScopeEntryPatterns on ScopeEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScopeEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScopeEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScopeEntry value)  $default,){
final _that = this;
switch (_that) {
case _ScopeEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScopeEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ScopeEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int level,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScopeEntry() when $default != null:
return $default(_that.level,_that.value);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int level,  String value)  $default,) {final _that = this;
switch (_that) {
case _ScopeEntry():
return $default(_that.level,_that.value);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int level,  String value)?  $default,) {final _that = this;
switch (_that) {
case _ScopeEntry() when $default != null:
return $default(_that.level,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _ScopeEntry implements ScopeEntry {
  const _ScopeEntry({required this.level, required this.value});
  

@override final  int level;
@override final  String value;

/// Create a copy of ScopeEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScopeEntryCopyWith<_ScopeEntry> get copyWith => __$ScopeEntryCopyWithImpl<_ScopeEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScopeEntry&&(identical(other.level, level) || other.level == level)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,level,value);

@override
String toString() {
  return 'ScopeEntry(level: $level, value: $value)';
}


}

/// @nodoc
abstract mixin class _$ScopeEntryCopyWith<$Res> implements $ScopeEntryCopyWith<$Res> {
  factory _$ScopeEntryCopyWith(_ScopeEntry value, $Res Function(_ScopeEntry) _then) = __$ScopeEntryCopyWithImpl;
@override @useResult
$Res call({
 int level, String value
});




}
/// @nodoc
class __$ScopeEntryCopyWithImpl<$Res>
    implements _$ScopeEntryCopyWith<$Res> {
  __$ScopeEntryCopyWithImpl(this._self, this._then);

  final _ScopeEntry _self;
  final $Res Function(_ScopeEntry) _then;

/// Create a copy of ScopeEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? value = null,}) {
  return _then(_ScopeEntry(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AddTrackState {

 AddTrackStep get currentStep; CurriculumId? get curriculumId; List<ScopeEntry>? get scopeSelections; int? get programId; String? get programName;/// Full program object for reading stagesConfig metadata.
/// Opaque Object? to avoid importing DB types into domain.
 Object? get selectedProgram; Map<int, String>? get studyDays; Object? get wizardResult; Object? get goalResult; String? get trackLabel; Object? get bulkMarkResult; String? get startingRef; bool get contentActivated;
/// Create a copy of AddTrackState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AddTrackStateCopyWith<AddTrackState> get copyWith => _$AddTrackStateCopyWithImpl<AddTrackState>(this as AddTrackState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AddTrackState&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&const DeepCollectionEquality().equals(other.scopeSelections, scopeSelections)&&(identical(other.programId, programId) || other.programId == programId)&&(identical(other.programName, programName) || other.programName == programName)&&const DeepCollectionEquality().equals(other.selectedProgram, selectedProgram)&&const DeepCollectionEquality().equals(other.studyDays, studyDays)&&const DeepCollectionEquality().equals(other.wizardResult, wizardResult)&&const DeepCollectionEquality().equals(other.goalResult, goalResult)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&const DeepCollectionEquality().equals(other.bulkMarkResult, bulkMarkResult)&&(identical(other.startingRef, startingRef) || other.startingRef == startingRef)&&(identical(other.contentActivated, contentActivated) || other.contentActivated == contentActivated));
}


@override
int get hashCode => Object.hash(runtimeType,currentStep,curriculumId,const DeepCollectionEquality().hash(scopeSelections),programId,programName,const DeepCollectionEquality().hash(selectedProgram),const DeepCollectionEquality().hash(studyDays),const DeepCollectionEquality().hash(wizardResult),const DeepCollectionEquality().hash(goalResult),trackLabel,const DeepCollectionEquality().hash(bulkMarkResult),startingRef,contentActivated);

@override
String toString() {
  return 'AddTrackState(currentStep: $currentStep, curriculumId: $curriculumId, scopeSelections: $scopeSelections, programId: $programId, programName: $programName, selectedProgram: $selectedProgram, studyDays: $studyDays, wizardResult: $wizardResult, goalResult: $goalResult, trackLabel: $trackLabel, bulkMarkResult: $bulkMarkResult, startingRef: $startingRef, contentActivated: $contentActivated)';
}


}

/// @nodoc
abstract mixin class $AddTrackStateCopyWith<$Res>  {
  factory $AddTrackStateCopyWith(AddTrackState value, $Res Function(AddTrackState) _then) = _$AddTrackStateCopyWithImpl;
@useResult
$Res call({
 AddTrackStep currentStep, CurriculumId? curriculumId, List<ScopeEntry>? scopeSelections, int? programId, String? programName, Object? selectedProgram, Map<int, String>? studyDays, Object? wizardResult, Object? goalResult, String? trackLabel, Object? bulkMarkResult, String? startingRef, bool contentActivated
});




}
/// @nodoc
class _$AddTrackStateCopyWithImpl<$Res>
    implements $AddTrackStateCopyWith<$Res> {
  _$AddTrackStateCopyWithImpl(this._self, this._then);

  final AddTrackState _self;
  final $Res Function(AddTrackState) _then;

/// Create a copy of AddTrackState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentStep = null,Object? curriculumId = freezed,Object? scopeSelections = freezed,Object? programId = freezed,Object? programName = freezed,Object? selectedProgram = freezed,Object? studyDays = freezed,Object? wizardResult = freezed,Object? goalResult = freezed,Object? trackLabel = freezed,Object? bulkMarkResult = freezed,Object? startingRef = freezed,Object? contentActivated = null,}) {
  return _then(_self.copyWith(
currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as AddTrackStep,curriculumId: freezed == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId?,scopeSelections: freezed == scopeSelections ? _self.scopeSelections : scopeSelections // ignore: cast_nullable_to_non_nullable
as List<ScopeEntry>?,programId: freezed == programId ? _self.programId : programId // ignore: cast_nullable_to_non_nullable
as int?,programName: freezed == programName ? _self.programName : programName // ignore: cast_nullable_to_non_nullable
as String?,selectedProgram: freezed == selectedProgram ? _self.selectedProgram : selectedProgram ,studyDays: freezed == studyDays ? _self.studyDays : studyDays // ignore: cast_nullable_to_non_nullable
as Map<int, String>?,wizardResult: freezed == wizardResult ? _self.wizardResult : wizardResult ,goalResult: freezed == goalResult ? _self.goalResult : goalResult ,trackLabel: freezed == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String?,bulkMarkResult: freezed == bulkMarkResult ? _self.bulkMarkResult : bulkMarkResult ,startingRef: freezed == startingRef ? _self.startingRef : startingRef // ignore: cast_nullable_to_non_nullable
as String?,contentActivated: null == contentActivated ? _self.contentActivated : contentActivated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AddTrackState].
extension AddTrackStatePatterns on AddTrackState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AddTrackState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AddTrackState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AddTrackState value)  $default,){
final _that = this;
switch (_that) {
case _AddTrackState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AddTrackState value)?  $default,){
final _that = this;
switch (_that) {
case _AddTrackState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AddTrackStep currentStep,  CurriculumId? curriculumId,  List<ScopeEntry>? scopeSelections,  int? programId,  String? programName,  Object? selectedProgram,  Map<int, String>? studyDays,  Object? wizardResult,  Object? goalResult,  String? trackLabel,  Object? bulkMarkResult,  String? startingRef,  bool contentActivated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AddTrackState() when $default != null:
return $default(_that.currentStep,_that.curriculumId,_that.scopeSelections,_that.programId,_that.programName,_that.selectedProgram,_that.studyDays,_that.wizardResult,_that.goalResult,_that.trackLabel,_that.bulkMarkResult,_that.startingRef,_that.contentActivated);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AddTrackStep currentStep,  CurriculumId? curriculumId,  List<ScopeEntry>? scopeSelections,  int? programId,  String? programName,  Object? selectedProgram,  Map<int, String>? studyDays,  Object? wizardResult,  Object? goalResult,  String? trackLabel,  Object? bulkMarkResult,  String? startingRef,  bool contentActivated)  $default,) {final _that = this;
switch (_that) {
case _AddTrackState():
return $default(_that.currentStep,_that.curriculumId,_that.scopeSelections,_that.programId,_that.programName,_that.selectedProgram,_that.studyDays,_that.wizardResult,_that.goalResult,_that.trackLabel,_that.bulkMarkResult,_that.startingRef,_that.contentActivated);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AddTrackStep currentStep,  CurriculumId? curriculumId,  List<ScopeEntry>? scopeSelections,  int? programId,  String? programName,  Object? selectedProgram,  Map<int, String>? studyDays,  Object? wizardResult,  Object? goalResult,  String? trackLabel,  Object? bulkMarkResult,  String? startingRef,  bool contentActivated)?  $default,) {final _that = this;
switch (_that) {
case _AddTrackState() when $default != null:
return $default(_that.currentStep,_that.curriculumId,_that.scopeSelections,_that.programId,_that.programName,_that.selectedProgram,_that.studyDays,_that.wizardResult,_that.goalResult,_that.trackLabel,_that.bulkMarkResult,_that.startingRef,_that.contentActivated);case _:
  return null;

}
}

}

/// @nodoc


class _AddTrackState implements AddTrackState {
  const _AddTrackState({this.currentStep = AddTrackStep.curriculum, this.curriculumId, final  List<ScopeEntry>? scopeSelections, this.programId, this.programName, this.selectedProgram, final  Map<int, String>? studyDays, this.wizardResult, this.goalResult, this.trackLabel, this.bulkMarkResult, this.startingRef, this.contentActivated = false}): _scopeSelections = scopeSelections,_studyDays = studyDays;
  

@override@JsonKey() final  AddTrackStep currentStep;
@override final  CurriculumId? curriculumId;
 final  List<ScopeEntry>? _scopeSelections;
@override List<ScopeEntry>? get scopeSelections {
  final value = _scopeSelections;
  if (value == null) return null;
  if (_scopeSelections is EqualUnmodifiableListView) return _scopeSelections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  int? programId;
@override final  String? programName;
/// Full program object for reading stagesConfig metadata.
/// Opaque Object? to avoid importing DB types into domain.
@override final  Object? selectedProgram;
 final  Map<int, String>? _studyDays;
@override Map<int, String>? get studyDays {
  final value = _studyDays;
  if (value == null) return null;
  if (_studyDays is EqualUnmodifiableMapView) return _studyDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  Object? wizardResult;
@override final  Object? goalResult;
@override final  String? trackLabel;
@override final  Object? bulkMarkResult;
@override final  String? startingRef;
@override@JsonKey() final  bool contentActivated;

/// Create a copy of AddTrackState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddTrackStateCopyWith<_AddTrackState> get copyWith => __$AddTrackStateCopyWithImpl<_AddTrackState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AddTrackState&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&const DeepCollectionEquality().equals(other._scopeSelections, _scopeSelections)&&(identical(other.programId, programId) || other.programId == programId)&&(identical(other.programName, programName) || other.programName == programName)&&const DeepCollectionEquality().equals(other.selectedProgram, selectedProgram)&&const DeepCollectionEquality().equals(other._studyDays, _studyDays)&&const DeepCollectionEquality().equals(other.wizardResult, wizardResult)&&const DeepCollectionEquality().equals(other.goalResult, goalResult)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&const DeepCollectionEquality().equals(other.bulkMarkResult, bulkMarkResult)&&(identical(other.startingRef, startingRef) || other.startingRef == startingRef)&&(identical(other.contentActivated, contentActivated) || other.contentActivated == contentActivated));
}


@override
int get hashCode => Object.hash(runtimeType,currentStep,curriculumId,const DeepCollectionEquality().hash(_scopeSelections),programId,programName,const DeepCollectionEquality().hash(selectedProgram),const DeepCollectionEquality().hash(_studyDays),const DeepCollectionEquality().hash(wizardResult),const DeepCollectionEquality().hash(goalResult),trackLabel,const DeepCollectionEquality().hash(bulkMarkResult),startingRef,contentActivated);

@override
String toString() {
  return 'AddTrackState(currentStep: $currentStep, curriculumId: $curriculumId, scopeSelections: $scopeSelections, programId: $programId, programName: $programName, selectedProgram: $selectedProgram, studyDays: $studyDays, wizardResult: $wizardResult, goalResult: $goalResult, trackLabel: $trackLabel, bulkMarkResult: $bulkMarkResult, startingRef: $startingRef, contentActivated: $contentActivated)';
}


}

/// @nodoc
abstract mixin class _$AddTrackStateCopyWith<$Res> implements $AddTrackStateCopyWith<$Res> {
  factory _$AddTrackStateCopyWith(_AddTrackState value, $Res Function(_AddTrackState) _then) = __$AddTrackStateCopyWithImpl;
@override @useResult
$Res call({
 AddTrackStep currentStep, CurriculumId? curriculumId, List<ScopeEntry>? scopeSelections, int? programId, String? programName, Object? selectedProgram, Map<int, String>? studyDays, Object? wizardResult, Object? goalResult, String? trackLabel, Object? bulkMarkResult, String? startingRef, bool contentActivated
});




}
/// @nodoc
class __$AddTrackStateCopyWithImpl<$Res>
    implements _$AddTrackStateCopyWith<$Res> {
  __$AddTrackStateCopyWithImpl(this._self, this._then);

  final _AddTrackState _self;
  final $Res Function(_AddTrackState) _then;

/// Create a copy of AddTrackState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentStep = null,Object? curriculumId = freezed,Object? scopeSelections = freezed,Object? programId = freezed,Object? programName = freezed,Object? selectedProgram = freezed,Object? studyDays = freezed,Object? wizardResult = freezed,Object? goalResult = freezed,Object? trackLabel = freezed,Object? bulkMarkResult = freezed,Object? startingRef = freezed,Object? contentActivated = null,}) {
  return _then(_AddTrackState(
currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as AddTrackStep,curriculumId: freezed == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId?,scopeSelections: freezed == scopeSelections ? _self._scopeSelections : scopeSelections // ignore: cast_nullable_to_non_nullable
as List<ScopeEntry>?,programId: freezed == programId ? _self.programId : programId // ignore: cast_nullable_to_non_nullable
as int?,programName: freezed == programName ? _self.programName : programName // ignore: cast_nullable_to_non_nullable
as String?,selectedProgram: freezed == selectedProgram ? _self.selectedProgram : selectedProgram ,studyDays: freezed == studyDays ? _self._studyDays : studyDays // ignore: cast_nullable_to_non_nullable
as Map<int, String>?,wizardResult: freezed == wizardResult ? _self.wizardResult : wizardResult ,goalResult: freezed == goalResult ? _self.goalResult : goalResult ,trackLabel: freezed == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String?,bulkMarkResult: freezed == bulkMarkResult ? _self.bulkMarkResult : bulkMarkResult ,startingRef: freezed == startingRef ? _self.startingRef : startingRef // ignore: cast_nullable_to_non_nullable
as String?,contentActivated: null == contentActivated ? _self.contentActivated : contentActivated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
