// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journey_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JourneyViewModel {

 List<CurriculumJourney> get curricula; int get totalCompletions; int get totalUniqueUnits;
/// Create a copy of JourneyViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JourneyViewModelCopyWith<JourneyViewModel> get copyWith => _$JourneyViewModelCopyWithImpl<JourneyViewModel>(this as JourneyViewModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyViewModel&&const DeepCollectionEquality().equals(other.curricula, curricula)&&(identical(other.totalCompletions, totalCompletions) || other.totalCompletions == totalCompletions)&&(identical(other.totalUniqueUnits, totalUniqueUnits) || other.totalUniqueUnits == totalUniqueUnits));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(curricula),totalCompletions,totalUniqueUnits);

@override
String toString() {
  return 'JourneyViewModel(curricula: $curricula, totalCompletions: $totalCompletions, totalUniqueUnits: $totalUniqueUnits)';
}


}

/// @nodoc
abstract mixin class $JourneyViewModelCopyWith<$Res>  {
  factory $JourneyViewModelCopyWith(JourneyViewModel value, $Res Function(JourneyViewModel) _then) = _$JourneyViewModelCopyWithImpl;
@useResult
$Res call({
 List<CurriculumJourney> curricula, int totalCompletions, int totalUniqueUnits
});




}
/// @nodoc
class _$JourneyViewModelCopyWithImpl<$Res>
    implements $JourneyViewModelCopyWith<$Res> {
  _$JourneyViewModelCopyWithImpl(this._self, this._then);

  final JourneyViewModel _self;
  final $Res Function(JourneyViewModel) _then;

/// Create a copy of JourneyViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curricula = null,Object? totalCompletions = null,Object? totalUniqueUnits = null,}) {
  return _then(_self.copyWith(
curricula: null == curricula ? _self.curricula : curricula // ignore: cast_nullable_to_non_nullable
as List<CurriculumJourney>,totalCompletions: null == totalCompletions ? _self.totalCompletions : totalCompletions // ignore: cast_nullable_to_non_nullable
as int,totalUniqueUnits: null == totalUniqueUnits ? _self.totalUniqueUnits : totalUniqueUnits // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [JourneyViewModel].
extension JourneyViewModelPatterns on JourneyViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JourneyViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JourneyViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JourneyViewModel value)  $default,){
final _that = this;
switch (_that) {
case _JourneyViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JourneyViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _JourneyViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CurriculumJourney> curricula,  int totalCompletions,  int totalUniqueUnits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JourneyViewModel() when $default != null:
return $default(_that.curricula,_that.totalCompletions,_that.totalUniqueUnits);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CurriculumJourney> curricula,  int totalCompletions,  int totalUniqueUnits)  $default,) {final _that = this;
switch (_that) {
case _JourneyViewModel():
return $default(_that.curricula,_that.totalCompletions,_that.totalUniqueUnits);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CurriculumJourney> curricula,  int totalCompletions,  int totalUniqueUnits)?  $default,) {final _that = this;
switch (_that) {
case _JourneyViewModel() when $default != null:
return $default(_that.curricula,_that.totalCompletions,_that.totalUniqueUnits);case _:
  return null;

}
}

}

/// @nodoc


class _JourneyViewModel implements JourneyViewModel {
  const _JourneyViewModel({required final  List<CurriculumJourney> curricula, required this.totalCompletions, required this.totalUniqueUnits}): _curricula = curricula;
  

 final  List<CurriculumJourney> _curricula;
@override List<CurriculumJourney> get curricula {
  if (_curricula is EqualUnmodifiableListView) return _curricula;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_curricula);
}

@override final  int totalCompletions;
@override final  int totalUniqueUnits;

/// Create a copy of JourneyViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JourneyViewModelCopyWith<_JourneyViewModel> get copyWith => __$JourneyViewModelCopyWithImpl<_JourneyViewModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JourneyViewModel&&const DeepCollectionEquality().equals(other._curricula, _curricula)&&(identical(other.totalCompletions, totalCompletions) || other.totalCompletions == totalCompletions)&&(identical(other.totalUniqueUnits, totalUniqueUnits) || other.totalUniqueUnits == totalUniqueUnits));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_curricula),totalCompletions,totalUniqueUnits);

@override
String toString() {
  return 'JourneyViewModel(curricula: $curricula, totalCompletions: $totalCompletions, totalUniqueUnits: $totalUniqueUnits)';
}


}

/// @nodoc
abstract mixin class _$JourneyViewModelCopyWith<$Res> implements $JourneyViewModelCopyWith<$Res> {
  factory _$JourneyViewModelCopyWith(_JourneyViewModel value, $Res Function(_JourneyViewModel) _then) = __$JourneyViewModelCopyWithImpl;
@override @useResult
$Res call({
 List<CurriculumJourney> curricula, int totalCompletions, int totalUniqueUnits
});




}
/// @nodoc
class __$JourneyViewModelCopyWithImpl<$Res>
    implements _$JourneyViewModelCopyWith<$Res> {
  __$JourneyViewModelCopyWithImpl(this._self, this._then);

  final _JourneyViewModel _self;
  final $Res Function(_JourneyViewModel) _then;

/// Create a copy of JourneyViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curricula = null,Object? totalCompletions = null,Object? totalUniqueUnits = null,}) {
  return _then(_JourneyViewModel(
curricula: null == curricula ? _self._curricula : curricula // ignore: cast_nullable_to_non_nullable
as List<CurriculumJourney>,totalCompletions: null == totalCompletions ? _self.totalCompletions : totalCompletions // ignore: cast_nullable_to_non_nullable
as int,totalUniqueUnits: null == totalUniqueUnits ? _self.totalUniqueUnits : totalUniqueUnits // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$CurriculumJourney {

 CurriculumId get curriculumId; List<UnitCompletion> get completions; int get uniqueUnitsCompleted; int get totalUnitsAvailable; List<MilestoneAchievement> get milestones;
/// Create a copy of CurriculumJourney
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurriculumJourneyCopyWith<CurriculumJourney> get copyWith => _$CurriculumJourneyCopyWithImpl<CurriculumJourney>(this as CurriculumJourney, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurriculumJourney&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&const DeepCollectionEquality().equals(other.completions, completions)&&(identical(other.uniqueUnitsCompleted, uniqueUnitsCompleted) || other.uniqueUnitsCompleted == uniqueUnitsCompleted)&&(identical(other.totalUnitsAvailable, totalUnitsAvailable) || other.totalUnitsAvailable == totalUnitsAvailable)&&const DeepCollectionEquality().equals(other.milestones, milestones));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,const DeepCollectionEquality().hash(completions),uniqueUnitsCompleted,totalUnitsAvailable,const DeepCollectionEquality().hash(milestones));

@override
String toString() {
  return 'CurriculumJourney(curriculumId: $curriculumId, completions: $completions, uniqueUnitsCompleted: $uniqueUnitsCompleted, totalUnitsAvailable: $totalUnitsAvailable, milestones: $milestones)';
}


}

/// @nodoc
abstract mixin class $CurriculumJourneyCopyWith<$Res>  {
  factory $CurriculumJourneyCopyWith(CurriculumJourney value, $Res Function(CurriculumJourney) _then) = _$CurriculumJourneyCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculumId, List<UnitCompletion> completions, int uniqueUnitsCompleted, int totalUnitsAvailable, List<MilestoneAchievement> milestones
});




}
/// @nodoc
class _$CurriculumJourneyCopyWithImpl<$Res>
    implements $CurriculumJourneyCopyWith<$Res> {
  _$CurriculumJourneyCopyWithImpl(this._self, this._then);

  final CurriculumJourney _self;
  final $Res Function(CurriculumJourney) _then;

/// Create a copy of CurriculumJourney
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? completions = null,Object? uniqueUnitsCompleted = null,Object? totalUnitsAvailable = null,Object? milestones = null,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,completions: null == completions ? _self.completions : completions // ignore: cast_nullable_to_non_nullable
as List<UnitCompletion>,uniqueUnitsCompleted: null == uniqueUnitsCompleted ? _self.uniqueUnitsCompleted : uniqueUnitsCompleted // ignore: cast_nullable_to_non_nullable
as int,totalUnitsAvailable: null == totalUnitsAvailable ? _self.totalUnitsAvailable : totalUnitsAvailable // ignore: cast_nullable_to_non_nullable
as int,milestones: null == milestones ? _self.milestones : milestones // ignore: cast_nullable_to_non_nullable
as List<MilestoneAchievement>,
  ));
}

}


/// Adds pattern-matching-related methods to [CurriculumJourney].
extension CurriculumJourneyPatterns on CurriculumJourney {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurriculumJourney value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurriculumJourney() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurriculumJourney value)  $default,){
final _that = this;
switch (_that) {
case _CurriculumJourney():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurriculumJourney value)?  $default,){
final _that = this;
switch (_that) {
case _CurriculumJourney() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  List<UnitCompletion> completions,  int uniqueUnitsCompleted,  int totalUnitsAvailable,  List<MilestoneAchievement> milestones)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurriculumJourney() when $default != null:
return $default(_that.curriculumId,_that.completions,_that.uniqueUnitsCompleted,_that.totalUnitsAvailable,_that.milestones);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  List<UnitCompletion> completions,  int uniqueUnitsCompleted,  int totalUnitsAvailable,  List<MilestoneAchievement> milestones)  $default,) {final _that = this;
switch (_that) {
case _CurriculumJourney():
return $default(_that.curriculumId,_that.completions,_that.uniqueUnitsCompleted,_that.totalUnitsAvailable,_that.milestones);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculumId,  List<UnitCompletion> completions,  int uniqueUnitsCompleted,  int totalUnitsAvailable,  List<MilestoneAchievement> milestones)?  $default,) {final _that = this;
switch (_that) {
case _CurriculumJourney() when $default != null:
return $default(_that.curriculumId,_that.completions,_that.uniqueUnitsCompleted,_that.totalUnitsAvailable,_that.milestones);case _:
  return null;

}
}

}

/// @nodoc


class _CurriculumJourney implements CurriculumJourney {
  const _CurriculumJourney({required this.curriculumId, required final  List<UnitCompletion> completions, required this.uniqueUnitsCompleted, required this.totalUnitsAvailable, required final  List<MilestoneAchievement> milestones}): _completions = completions,_milestones = milestones;
  

@override final  CurriculumId curriculumId;
 final  List<UnitCompletion> _completions;
@override List<UnitCompletion> get completions {
  if (_completions is EqualUnmodifiableListView) return _completions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_completions);
}

@override final  int uniqueUnitsCompleted;
@override final  int totalUnitsAvailable;
 final  List<MilestoneAchievement> _milestones;
@override List<MilestoneAchievement> get milestones {
  if (_milestones is EqualUnmodifiableListView) return _milestones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_milestones);
}


/// Create a copy of CurriculumJourney
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurriculumJourneyCopyWith<_CurriculumJourney> get copyWith => __$CurriculumJourneyCopyWithImpl<_CurriculumJourney>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurriculumJourney&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&const DeepCollectionEquality().equals(other._completions, _completions)&&(identical(other.uniqueUnitsCompleted, uniqueUnitsCompleted) || other.uniqueUnitsCompleted == uniqueUnitsCompleted)&&(identical(other.totalUnitsAvailable, totalUnitsAvailable) || other.totalUnitsAvailable == totalUnitsAvailable)&&const DeepCollectionEquality().equals(other._milestones, _milestones));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,const DeepCollectionEquality().hash(_completions),uniqueUnitsCompleted,totalUnitsAvailable,const DeepCollectionEquality().hash(_milestones));

@override
String toString() {
  return 'CurriculumJourney(curriculumId: $curriculumId, completions: $completions, uniqueUnitsCompleted: $uniqueUnitsCompleted, totalUnitsAvailable: $totalUnitsAvailable, milestones: $milestones)';
}


}

/// @nodoc
abstract mixin class _$CurriculumJourneyCopyWith<$Res> implements $CurriculumJourneyCopyWith<$Res> {
  factory _$CurriculumJourneyCopyWith(_CurriculumJourney value, $Res Function(_CurriculumJourney) _then) = __$CurriculumJourneyCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculumId, List<UnitCompletion> completions, int uniqueUnitsCompleted, int totalUnitsAvailable, List<MilestoneAchievement> milestones
});




}
/// @nodoc
class __$CurriculumJourneyCopyWithImpl<$Res>
    implements _$CurriculumJourneyCopyWith<$Res> {
  __$CurriculumJourneyCopyWithImpl(this._self, this._then);

  final _CurriculumJourney _self;
  final $Res Function(_CurriculumJourney) _then;

/// Create a copy of CurriculumJourney
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? completions = null,Object? uniqueUnitsCompleted = null,Object? totalUnitsAvailable = null,Object? milestones = null,}) {
  return _then(_CurriculumJourney(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,completions: null == completions ? _self._completions : completions // ignore: cast_nullable_to_non_nullable
as List<UnitCompletion>,uniqueUnitsCompleted: null == uniqueUnitsCompleted ? _self.uniqueUnitsCompleted : uniqueUnitsCompleted // ignore: cast_nullable_to_non_nullable
as int,totalUnitsAvailable: null == totalUnitsAvailable ? _self.totalUnitsAvailable : totalUnitsAvailable // ignore: cast_nullable_to_non_nullable
as int,milestones: null == milestones ? _self._milestones : milestones // ignore: cast_nullable_to_non_nullable
as List<MilestoneAchievement>,
  ));
}


}

/// @nodoc
mixin _$UnitCompletion {

 String get unitIdentifier; String get entryScope; String get entryKey; String? get parentL1Key; TrackType get trackType; DateTime get completedAt; int get completionNumber; bool get isManual;
/// Create a copy of UnitCompletion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnitCompletionCopyWith<UnitCompletion> get copyWith => _$UnitCompletionCopyWithImpl<UnitCompletion>(this as UnitCompletion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnitCompletion&&(identical(other.unitIdentifier, unitIdentifier) || other.unitIdentifier == unitIdentifier)&&(identical(other.entryScope, entryScope) || other.entryScope == entryScope)&&(identical(other.entryKey, entryKey) || other.entryKey == entryKey)&&(identical(other.parentL1Key, parentL1Key) || other.parentL1Key == parentL1Key)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.completionNumber, completionNumber) || other.completionNumber == completionNumber)&&(identical(other.isManual, isManual) || other.isManual == isManual));
}


@override
int get hashCode => Object.hash(runtimeType,unitIdentifier,entryScope,entryKey,parentL1Key,trackType,completedAt,completionNumber,isManual);

@override
String toString() {
  return 'UnitCompletion(unitIdentifier: $unitIdentifier, entryScope: $entryScope, entryKey: $entryKey, parentL1Key: $parentL1Key, trackType: $trackType, completedAt: $completedAt, completionNumber: $completionNumber, isManual: $isManual)';
}


}

/// @nodoc
abstract mixin class $UnitCompletionCopyWith<$Res>  {
  factory $UnitCompletionCopyWith(UnitCompletion value, $Res Function(UnitCompletion) _then) = _$UnitCompletionCopyWithImpl;
@useResult
$Res call({
 String unitIdentifier, String entryScope, String entryKey, String? parentL1Key, TrackType trackType, DateTime completedAt, int completionNumber, bool isManual
});




}
/// @nodoc
class _$UnitCompletionCopyWithImpl<$Res>
    implements $UnitCompletionCopyWith<$Res> {
  _$UnitCompletionCopyWithImpl(this._self, this._then);

  final UnitCompletion _self;
  final $Res Function(UnitCompletion) _then;

/// Create a copy of UnitCompletion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? unitIdentifier = null,Object? entryScope = null,Object? entryKey = null,Object? parentL1Key = freezed,Object? trackType = null,Object? completedAt = null,Object? completionNumber = null,Object? isManual = null,}) {
  return _then(_self.copyWith(
unitIdentifier: null == unitIdentifier ? _self.unitIdentifier : unitIdentifier // ignore: cast_nullable_to_non_nullable
as String,entryScope: null == entryScope ? _self.entryScope : entryScope // ignore: cast_nullable_to_non_nullable
as String,entryKey: null == entryKey ? _self.entryKey : entryKey // ignore: cast_nullable_to_non_nullable
as String,parentL1Key: freezed == parentL1Key ? _self.parentL1Key : parentL1Key // ignore: cast_nullable_to_non_nullable
as String?,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as TrackType,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completionNumber: null == completionNumber ? _self.completionNumber : completionNumber // ignore: cast_nullable_to_non_nullable
as int,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UnitCompletion].
extension UnitCompletionPatterns on UnitCompletion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnitCompletion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnitCompletion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnitCompletion value)  $default,){
final _that = this;
switch (_that) {
case _UnitCompletion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnitCompletion value)?  $default,){
final _that = this;
switch (_that) {
case _UnitCompletion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String unitIdentifier,  String entryScope,  String entryKey,  String? parentL1Key,  TrackType trackType,  DateTime completedAt,  int completionNumber,  bool isManual)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnitCompletion() when $default != null:
return $default(_that.unitIdentifier,_that.entryScope,_that.entryKey,_that.parentL1Key,_that.trackType,_that.completedAt,_that.completionNumber,_that.isManual);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String unitIdentifier,  String entryScope,  String entryKey,  String? parentL1Key,  TrackType trackType,  DateTime completedAt,  int completionNumber,  bool isManual)  $default,) {final _that = this;
switch (_that) {
case _UnitCompletion():
return $default(_that.unitIdentifier,_that.entryScope,_that.entryKey,_that.parentL1Key,_that.trackType,_that.completedAt,_that.completionNumber,_that.isManual);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String unitIdentifier,  String entryScope,  String entryKey,  String? parentL1Key,  TrackType trackType,  DateTime completedAt,  int completionNumber,  bool isManual)?  $default,) {final _that = this;
switch (_that) {
case _UnitCompletion() when $default != null:
return $default(_that.unitIdentifier,_that.entryScope,_that.entryKey,_that.parentL1Key,_that.trackType,_that.completedAt,_that.completionNumber,_that.isManual);case _:
  return null;

}
}

}

/// @nodoc


class _UnitCompletion implements UnitCompletion {
  const _UnitCompletion({required this.unitIdentifier, required this.entryScope, required this.entryKey, this.parentL1Key, required this.trackType, required this.completedAt, required this.completionNumber, required this.isManual});
  

@override final  String unitIdentifier;
@override final  String entryScope;
@override final  String entryKey;
@override final  String? parentL1Key;
@override final  TrackType trackType;
@override final  DateTime completedAt;
@override final  int completionNumber;
@override final  bool isManual;

/// Create a copy of UnitCompletion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnitCompletionCopyWith<_UnitCompletion> get copyWith => __$UnitCompletionCopyWithImpl<_UnitCompletion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnitCompletion&&(identical(other.unitIdentifier, unitIdentifier) || other.unitIdentifier == unitIdentifier)&&(identical(other.entryScope, entryScope) || other.entryScope == entryScope)&&(identical(other.entryKey, entryKey) || other.entryKey == entryKey)&&(identical(other.parentL1Key, parentL1Key) || other.parentL1Key == parentL1Key)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.completionNumber, completionNumber) || other.completionNumber == completionNumber)&&(identical(other.isManual, isManual) || other.isManual == isManual));
}


@override
int get hashCode => Object.hash(runtimeType,unitIdentifier,entryScope,entryKey,parentL1Key,trackType,completedAt,completionNumber,isManual);

@override
String toString() {
  return 'UnitCompletion(unitIdentifier: $unitIdentifier, entryScope: $entryScope, entryKey: $entryKey, parentL1Key: $parentL1Key, trackType: $trackType, completedAt: $completedAt, completionNumber: $completionNumber, isManual: $isManual)';
}


}

/// @nodoc
abstract mixin class _$UnitCompletionCopyWith<$Res> implements $UnitCompletionCopyWith<$Res> {
  factory _$UnitCompletionCopyWith(_UnitCompletion value, $Res Function(_UnitCompletion) _then) = __$UnitCompletionCopyWithImpl;
@override @useResult
$Res call({
 String unitIdentifier, String entryScope, String entryKey, String? parentL1Key, TrackType trackType, DateTime completedAt, int completionNumber, bool isManual
});




}
/// @nodoc
class __$UnitCompletionCopyWithImpl<$Res>
    implements _$UnitCompletionCopyWith<$Res> {
  __$UnitCompletionCopyWithImpl(this._self, this._then);

  final _UnitCompletion _self;
  final $Res Function(_UnitCompletion) _then;

/// Create a copy of UnitCompletion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? unitIdentifier = null,Object? entryScope = null,Object? entryKey = null,Object? parentL1Key = freezed,Object? trackType = null,Object? completedAt = null,Object? completionNumber = null,Object? isManual = null,}) {
  return _then(_UnitCompletion(
unitIdentifier: null == unitIdentifier ? _self.unitIdentifier : unitIdentifier // ignore: cast_nullable_to_non_nullable
as String,entryScope: null == entryScope ? _self.entryScope : entryScope // ignore: cast_nullable_to_non_nullable
as String,entryKey: null == entryKey ? _self.entryKey : entryKey // ignore: cast_nullable_to_non_nullable
as String,parentL1Key: freezed == parentL1Key ? _self.parentL1Key : parentL1Key // ignore: cast_nullable_to_non_nullable
as String?,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as TrackType,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completionNumber: null == completionNumber ? _self.completionNumber : completionNumber // ignore: cast_nullable_to_non_nullable
as int,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$MilestoneAchievement {

 String get type; String get displayName; DateTime get achievedAt;
/// Create a copy of MilestoneAchievement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MilestoneAchievementCopyWith<MilestoneAchievement> get copyWith => _$MilestoneAchievementCopyWithImpl<MilestoneAchievement>(this as MilestoneAchievement, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MilestoneAchievement&&(identical(other.type, type) || other.type == type)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.achievedAt, achievedAt) || other.achievedAt == achievedAt));
}


@override
int get hashCode => Object.hash(runtimeType,type,displayName,achievedAt);

@override
String toString() {
  return 'MilestoneAchievement(type: $type, displayName: $displayName, achievedAt: $achievedAt)';
}


}

/// @nodoc
abstract mixin class $MilestoneAchievementCopyWith<$Res>  {
  factory $MilestoneAchievementCopyWith(MilestoneAchievement value, $Res Function(MilestoneAchievement) _then) = _$MilestoneAchievementCopyWithImpl;
@useResult
$Res call({
 String type, String displayName, DateTime achievedAt
});




}
/// @nodoc
class _$MilestoneAchievementCopyWithImpl<$Res>
    implements $MilestoneAchievementCopyWith<$Res> {
  _$MilestoneAchievementCopyWithImpl(this._self, this._then);

  final MilestoneAchievement _self;
  final $Res Function(MilestoneAchievement) _then;

/// Create a copy of MilestoneAchievement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? displayName = null,Object? achievedAt = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,achievedAt: null == achievedAt ? _self.achievedAt : achievedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MilestoneAchievement].
extension MilestoneAchievementPatterns on MilestoneAchievement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MilestoneAchievement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MilestoneAchievement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MilestoneAchievement value)  $default,){
final _that = this;
switch (_that) {
case _MilestoneAchievement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MilestoneAchievement value)?  $default,){
final _that = this;
switch (_that) {
case _MilestoneAchievement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String displayName,  DateTime achievedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MilestoneAchievement() when $default != null:
return $default(_that.type,_that.displayName,_that.achievedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String displayName,  DateTime achievedAt)  $default,) {final _that = this;
switch (_that) {
case _MilestoneAchievement():
return $default(_that.type,_that.displayName,_that.achievedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String displayName,  DateTime achievedAt)?  $default,) {final _that = this;
switch (_that) {
case _MilestoneAchievement() when $default != null:
return $default(_that.type,_that.displayName,_that.achievedAt);case _:
  return null;

}
}

}

/// @nodoc


class _MilestoneAchievement implements MilestoneAchievement {
  const _MilestoneAchievement({required this.type, required this.displayName, required this.achievedAt});
  

@override final  String type;
@override final  String displayName;
@override final  DateTime achievedAt;

/// Create a copy of MilestoneAchievement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MilestoneAchievementCopyWith<_MilestoneAchievement> get copyWith => __$MilestoneAchievementCopyWithImpl<_MilestoneAchievement>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MilestoneAchievement&&(identical(other.type, type) || other.type == type)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.achievedAt, achievedAt) || other.achievedAt == achievedAt));
}


@override
int get hashCode => Object.hash(runtimeType,type,displayName,achievedAt);

@override
String toString() {
  return 'MilestoneAchievement(type: $type, displayName: $displayName, achievedAt: $achievedAt)';
}


}

/// @nodoc
abstract mixin class _$MilestoneAchievementCopyWith<$Res> implements $MilestoneAchievementCopyWith<$Res> {
  factory _$MilestoneAchievementCopyWith(_MilestoneAchievement value, $Res Function(_MilestoneAchievement) _then) = __$MilestoneAchievementCopyWithImpl;
@override @useResult
$Res call({
 String type, String displayName, DateTime achievedAt
});




}
/// @nodoc
class __$MilestoneAchievementCopyWithImpl<$Res>
    implements _$MilestoneAchievementCopyWith<$Res> {
  __$MilestoneAchievementCopyWithImpl(this._self, this._then);

  final _MilestoneAchievement _self;
  final $Res Function(_MilestoneAchievement) _then;

/// Create a copy of MilestoneAchievement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? displayName = null,Object? achievedAt = null,}) {
  return _then(_MilestoneAchievement(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,achievedAt: null == achievedAt ? _self.achievedAt : achievedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
