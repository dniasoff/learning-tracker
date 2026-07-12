// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'parent_dashboard_aggregator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ParentDashboardData {

 List<ParentCurriculumSummary> get curricula; int get globalPoints; int get currentStreak; int get maxStreak; List<RecentCompletion> get recentCompletions; EngagementMetrics get engagement;
/// Create a copy of ParentDashboardData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParentDashboardDataCopyWith<ParentDashboardData> get copyWith => _$ParentDashboardDataCopyWithImpl<ParentDashboardData>(this as ParentDashboardData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParentDashboardData&&const DeepCollectionEquality().equals(other.curricula, curricula)&&(identical(other.globalPoints, globalPoints) || other.globalPoints == globalPoints)&&(identical(other.currentStreak, currentStreak) || other.currentStreak == currentStreak)&&(identical(other.maxStreak, maxStreak) || other.maxStreak == maxStreak)&&const DeepCollectionEquality().equals(other.recentCompletions, recentCompletions)&&(identical(other.engagement, engagement) || other.engagement == engagement));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(curricula),globalPoints,currentStreak,maxStreak,const DeepCollectionEquality().hash(recentCompletions),engagement);

@override
String toString() {
  return 'ParentDashboardData(curricula: $curricula, globalPoints: $globalPoints, currentStreak: $currentStreak, maxStreak: $maxStreak, recentCompletions: $recentCompletions, engagement: $engagement)';
}


}

/// @nodoc
abstract mixin class $ParentDashboardDataCopyWith<$Res>  {
  factory $ParentDashboardDataCopyWith(ParentDashboardData value, $Res Function(ParentDashboardData) _then) = _$ParentDashboardDataCopyWithImpl;
@useResult
$Res call({
 List<ParentCurriculumSummary> curricula, int globalPoints, int currentStreak, int maxStreak, List<RecentCompletion> recentCompletions, EngagementMetrics engagement
});


$EngagementMetricsCopyWith<$Res> get engagement;

}
/// @nodoc
class _$ParentDashboardDataCopyWithImpl<$Res>
    implements $ParentDashboardDataCopyWith<$Res> {
  _$ParentDashboardDataCopyWithImpl(this._self, this._then);

  final ParentDashboardData _self;
  final $Res Function(ParentDashboardData) _then;

/// Create a copy of ParentDashboardData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curricula = null,Object? globalPoints = null,Object? currentStreak = null,Object? maxStreak = null,Object? recentCompletions = null,Object? engagement = null,}) {
  return _then(_self.copyWith(
curricula: null == curricula ? _self.curricula : curricula // ignore: cast_nullable_to_non_nullable
as List<ParentCurriculumSummary>,globalPoints: null == globalPoints ? _self.globalPoints : globalPoints // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,maxStreak: null == maxStreak ? _self.maxStreak : maxStreak // ignore: cast_nullable_to_non_nullable
as int,recentCompletions: null == recentCompletions ? _self.recentCompletions : recentCompletions // ignore: cast_nullable_to_non_nullable
as List<RecentCompletion>,engagement: null == engagement ? _self.engagement : engagement // ignore: cast_nullable_to_non_nullable
as EngagementMetrics,
  ));
}
/// Create a copy of ParentDashboardData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EngagementMetricsCopyWith<$Res> get engagement {
  
  return $EngagementMetricsCopyWith<$Res>(_self.engagement, (value) {
    return _then(_self.copyWith(engagement: value));
  });
}
}


/// Adds pattern-matching-related methods to [ParentDashboardData].
extension ParentDashboardDataPatterns on ParentDashboardData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParentDashboardData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParentDashboardData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParentDashboardData value)  $default,){
final _that = this;
switch (_that) {
case _ParentDashboardData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParentDashboardData value)?  $default,){
final _that = this;
switch (_that) {
case _ParentDashboardData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ParentCurriculumSummary> curricula,  int globalPoints,  int currentStreak,  int maxStreak,  List<RecentCompletion> recentCompletions,  EngagementMetrics engagement)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParentDashboardData() when $default != null:
return $default(_that.curricula,_that.globalPoints,_that.currentStreak,_that.maxStreak,_that.recentCompletions,_that.engagement);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ParentCurriculumSummary> curricula,  int globalPoints,  int currentStreak,  int maxStreak,  List<RecentCompletion> recentCompletions,  EngagementMetrics engagement)  $default,) {final _that = this;
switch (_that) {
case _ParentDashboardData():
return $default(_that.curricula,_that.globalPoints,_that.currentStreak,_that.maxStreak,_that.recentCompletions,_that.engagement);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ParentCurriculumSummary> curricula,  int globalPoints,  int currentStreak,  int maxStreak,  List<RecentCompletion> recentCompletions,  EngagementMetrics engagement)?  $default,) {final _that = this;
switch (_that) {
case _ParentDashboardData() when $default != null:
return $default(_that.curricula,_that.globalPoints,_that.currentStreak,_that.maxStreak,_that.recentCompletions,_that.engagement);case _:
  return null;

}
}

}

/// @nodoc


class _ParentDashboardData implements ParentDashboardData {
  const _ParentDashboardData({required final  List<ParentCurriculumSummary> curricula, required this.globalPoints, required this.currentStreak, required this.maxStreak, required final  List<RecentCompletion> recentCompletions, required this.engagement}): _curricula = curricula,_recentCompletions = recentCompletions;
  

 final  List<ParentCurriculumSummary> _curricula;
@override List<ParentCurriculumSummary> get curricula {
  if (_curricula is EqualUnmodifiableListView) return _curricula;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_curricula);
}

@override final  int globalPoints;
@override final  int currentStreak;
@override final  int maxStreak;
 final  List<RecentCompletion> _recentCompletions;
@override List<RecentCompletion> get recentCompletions {
  if (_recentCompletions is EqualUnmodifiableListView) return _recentCompletions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentCompletions);
}

@override final  EngagementMetrics engagement;

/// Create a copy of ParentDashboardData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParentDashboardDataCopyWith<_ParentDashboardData> get copyWith => __$ParentDashboardDataCopyWithImpl<_ParentDashboardData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParentDashboardData&&const DeepCollectionEquality().equals(other._curricula, _curricula)&&(identical(other.globalPoints, globalPoints) || other.globalPoints == globalPoints)&&(identical(other.currentStreak, currentStreak) || other.currentStreak == currentStreak)&&(identical(other.maxStreak, maxStreak) || other.maxStreak == maxStreak)&&const DeepCollectionEquality().equals(other._recentCompletions, _recentCompletions)&&(identical(other.engagement, engagement) || other.engagement == engagement));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_curricula),globalPoints,currentStreak,maxStreak,const DeepCollectionEquality().hash(_recentCompletions),engagement);

@override
String toString() {
  return 'ParentDashboardData(curricula: $curricula, globalPoints: $globalPoints, currentStreak: $currentStreak, maxStreak: $maxStreak, recentCompletions: $recentCompletions, engagement: $engagement)';
}


}

/// @nodoc
abstract mixin class _$ParentDashboardDataCopyWith<$Res> implements $ParentDashboardDataCopyWith<$Res> {
  factory _$ParentDashboardDataCopyWith(_ParentDashboardData value, $Res Function(_ParentDashboardData) _then) = __$ParentDashboardDataCopyWithImpl;
@override @useResult
$Res call({
 List<ParentCurriculumSummary> curricula, int globalPoints, int currentStreak, int maxStreak, List<RecentCompletion> recentCompletions, EngagementMetrics engagement
});


@override $EngagementMetricsCopyWith<$Res> get engagement;

}
/// @nodoc
class __$ParentDashboardDataCopyWithImpl<$Res>
    implements _$ParentDashboardDataCopyWith<$Res> {
  __$ParentDashboardDataCopyWithImpl(this._self, this._then);

  final _ParentDashboardData _self;
  final $Res Function(_ParentDashboardData) _then;

/// Create a copy of ParentDashboardData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curricula = null,Object? globalPoints = null,Object? currentStreak = null,Object? maxStreak = null,Object? recentCompletions = null,Object? engagement = null,}) {
  return _then(_ParentDashboardData(
curricula: null == curricula ? _self._curricula : curricula // ignore: cast_nullable_to_non_nullable
as List<ParentCurriculumSummary>,globalPoints: null == globalPoints ? _self.globalPoints : globalPoints // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,maxStreak: null == maxStreak ? _self.maxStreak : maxStreak // ignore: cast_nullable_to_non_nullable
as int,recentCompletions: null == recentCompletions ? _self._recentCompletions : recentCompletions // ignore: cast_nullable_to_non_nullable
as List<RecentCompletion>,engagement: null == engagement ? _self.engagement : engagement // ignore: cast_nullable_to_non_nullable
as EngagementMetrics,
  ));
}

/// Create a copy of ParentDashboardData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EngagementMetricsCopyWith<$Res> get engagement {
  
  return $EngagementMetricsCopyWith<$Res>(_self.engagement, (value) {
    return _then(_self.copyWith(engagement: value));
  });
}
}

/// @nodoc
mixin _$ParentCurriculumSummary {

 CurriculumId get curriculum; double get completionPercentage; PaceStatusType get paceStatus; int get points;
/// Create a copy of ParentCurriculumSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParentCurriculumSummaryCopyWith<ParentCurriculumSummary> get copyWith => _$ParentCurriculumSummaryCopyWithImpl<ParentCurriculumSummary>(this as ParentCurriculumSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParentCurriculumSummary&&(identical(other.curriculum, curriculum) || other.curriculum == curriculum)&&(identical(other.completionPercentage, completionPercentage) || other.completionPercentage == completionPercentage)&&(identical(other.paceStatus, paceStatus) || other.paceStatus == paceStatus)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,curriculum,completionPercentage,paceStatus,points);

@override
String toString() {
  return 'ParentCurriculumSummary(curriculum: $curriculum, completionPercentage: $completionPercentage, paceStatus: $paceStatus, points: $points)';
}


}

/// @nodoc
abstract mixin class $ParentCurriculumSummaryCopyWith<$Res>  {
  factory $ParentCurriculumSummaryCopyWith(ParentCurriculumSummary value, $Res Function(ParentCurriculumSummary) _then) = _$ParentCurriculumSummaryCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculum, double completionPercentage, PaceStatusType paceStatus, int points
});




}
/// @nodoc
class _$ParentCurriculumSummaryCopyWithImpl<$Res>
    implements $ParentCurriculumSummaryCopyWith<$Res> {
  _$ParentCurriculumSummaryCopyWithImpl(this._self, this._then);

  final ParentCurriculumSummary _self;
  final $Res Function(ParentCurriculumSummary) _then;

/// Create a copy of ParentCurriculumSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculum = null,Object? completionPercentage = null,Object? paceStatus = null,Object? points = null,}) {
  return _then(_self.copyWith(
curriculum: null == curriculum ? _self.curriculum : curriculum // ignore: cast_nullable_to_non_nullable
as CurriculumId,completionPercentage: null == completionPercentage ? _self.completionPercentage : completionPercentage // ignore: cast_nullable_to_non_nullable
as double,paceStatus: null == paceStatus ? _self.paceStatus : paceStatus // ignore: cast_nullable_to_non_nullable
as PaceStatusType,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ParentCurriculumSummary].
extension ParentCurriculumSummaryPatterns on ParentCurriculumSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParentCurriculumSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParentCurriculumSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParentCurriculumSummary value)  $default,){
final _that = this;
switch (_that) {
case _ParentCurriculumSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParentCurriculumSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ParentCurriculumSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculum,  double completionPercentage,  PaceStatusType paceStatus,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParentCurriculumSummary() when $default != null:
return $default(_that.curriculum,_that.completionPercentage,_that.paceStatus,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculum,  double completionPercentage,  PaceStatusType paceStatus,  int points)  $default,) {final _that = this;
switch (_that) {
case _ParentCurriculumSummary():
return $default(_that.curriculum,_that.completionPercentage,_that.paceStatus,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculum,  double completionPercentage,  PaceStatusType paceStatus,  int points)?  $default,) {final _that = this;
switch (_that) {
case _ParentCurriculumSummary() when $default != null:
return $default(_that.curriculum,_that.completionPercentage,_that.paceStatus,_that.points);case _:
  return null;

}
}

}

/// @nodoc


class _ParentCurriculumSummary implements ParentCurriculumSummary {
  const _ParentCurriculumSummary({required this.curriculum, required this.completionPercentage, required this.paceStatus, required this.points});
  

@override final  CurriculumId curriculum;
@override final  double completionPercentage;
@override final  PaceStatusType paceStatus;
@override final  int points;

/// Create a copy of ParentCurriculumSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParentCurriculumSummaryCopyWith<_ParentCurriculumSummary> get copyWith => __$ParentCurriculumSummaryCopyWithImpl<_ParentCurriculumSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParentCurriculumSummary&&(identical(other.curriculum, curriculum) || other.curriculum == curriculum)&&(identical(other.completionPercentage, completionPercentage) || other.completionPercentage == completionPercentage)&&(identical(other.paceStatus, paceStatus) || other.paceStatus == paceStatus)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,curriculum,completionPercentage,paceStatus,points);

@override
String toString() {
  return 'ParentCurriculumSummary(curriculum: $curriculum, completionPercentage: $completionPercentage, paceStatus: $paceStatus, points: $points)';
}


}

/// @nodoc
abstract mixin class _$ParentCurriculumSummaryCopyWith<$Res> implements $ParentCurriculumSummaryCopyWith<$Res> {
  factory _$ParentCurriculumSummaryCopyWith(_ParentCurriculumSummary value, $Res Function(_ParentCurriculumSummary) _then) = __$ParentCurriculumSummaryCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculum, double completionPercentage, PaceStatusType paceStatus, int points
});




}
/// @nodoc
class __$ParentCurriculumSummaryCopyWithImpl<$Res>
    implements _$ParentCurriculumSummaryCopyWith<$Res> {
  __$ParentCurriculumSummaryCopyWithImpl(this._self, this._then);

  final _ParentCurriculumSummary _self;
  final $Res Function(_ParentCurriculumSummary) _then;

/// Create a copy of ParentCurriculumSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculum = null,Object? completionPercentage = null,Object? paceStatus = null,Object? points = null,}) {
  return _then(_ParentCurriculumSummary(
curriculum: null == curriculum ? _self.curriculum : curriculum // ignore: cast_nullable_to_non_nullable
as CurriculumId,completionPercentage: null == completionPercentage ? _self.completionPercentage : completionPercentage // ignore: cast_nullable_to_non_nullable
as double,paceStatus: null == paceStatus ? _self.paceStatus : paceStatus // ignore: cast_nullable_to_non_nullable
as PaceStatusType,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$RecentCompletion {

 String get sefariaRef; String get curriculumId; DateTime get completedAt; int get points;
/// Create a copy of RecentCompletion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecentCompletionCopyWith<RecentCompletion> get copyWith => _$RecentCompletionCopyWithImpl<RecentCompletion>(this as RecentCompletion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecentCompletion&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,curriculumId,completedAt,points);

@override
String toString() {
  return 'RecentCompletion(sefariaRef: $sefariaRef, curriculumId: $curriculumId, completedAt: $completedAt, points: $points)';
}


}

/// @nodoc
abstract mixin class $RecentCompletionCopyWith<$Res>  {
  factory $RecentCompletionCopyWith(RecentCompletion value, $Res Function(RecentCompletion) _then) = _$RecentCompletionCopyWithImpl;
@useResult
$Res call({
 String sefariaRef, String curriculumId, DateTime completedAt, int points
});




}
/// @nodoc
class _$RecentCompletionCopyWithImpl<$Res>
    implements $RecentCompletionCopyWith<$Res> {
  _$RecentCompletionCopyWithImpl(this._self, this._then);

  final RecentCompletion _self;
  final $Res Function(RecentCompletion) _then;

/// Create a copy of RecentCompletion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sefariaRef = null,Object? curriculumId = null,Object? completedAt = null,Object? points = null,}) {
  return _then(_self.copyWith(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RecentCompletion].
extension RecentCompletionPatterns on RecentCompletion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecentCompletion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecentCompletion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecentCompletion value)  $default,){
final _that = this;
switch (_that) {
case _RecentCompletion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecentCompletion value)?  $default,){
final _that = this;
switch (_that) {
case _RecentCompletion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sefariaRef,  String curriculumId,  DateTime completedAt,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecentCompletion() when $default != null:
return $default(_that.sefariaRef,_that.curriculumId,_that.completedAt,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sefariaRef,  String curriculumId,  DateTime completedAt,  int points)  $default,) {final _that = this;
switch (_that) {
case _RecentCompletion():
return $default(_that.sefariaRef,_that.curriculumId,_that.completedAt,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sefariaRef,  String curriculumId,  DateTime completedAt,  int points)?  $default,) {final _that = this;
switch (_that) {
case _RecentCompletion() when $default != null:
return $default(_that.sefariaRef,_that.curriculumId,_that.completedAt,_that.points);case _:
  return null;

}
}

}

/// @nodoc


class _RecentCompletion implements RecentCompletion {
  const _RecentCompletion({required this.sefariaRef, required this.curriculumId, required this.completedAt, required this.points});
  

@override final  String sefariaRef;
@override final  String curriculumId;
@override final  DateTime completedAt;
@override final  int points;

/// Create a copy of RecentCompletion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecentCompletionCopyWith<_RecentCompletion> get copyWith => __$RecentCompletionCopyWithImpl<_RecentCompletion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecentCompletion&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,curriculumId,completedAt,points);

@override
String toString() {
  return 'RecentCompletion(sefariaRef: $sefariaRef, curriculumId: $curriculumId, completedAt: $completedAt, points: $points)';
}


}

/// @nodoc
abstract mixin class _$RecentCompletionCopyWith<$Res> implements $RecentCompletionCopyWith<$Res> {
  factory _$RecentCompletionCopyWith(_RecentCompletion value, $Res Function(_RecentCompletion) _then) = __$RecentCompletionCopyWithImpl;
@override @useResult
$Res call({
 String sefariaRef, String curriculumId, DateTime completedAt, int points
});




}
/// @nodoc
class __$RecentCompletionCopyWithImpl<$Res>
    implements _$RecentCompletionCopyWith<$Res> {
  __$RecentCompletionCopyWithImpl(this._self, this._then);

  final _RecentCompletion _self;
  final $Res Function(_RecentCompletion) _then;

/// Create a copy of RecentCompletion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sefariaRef = null,Object? curriculumId = null,Object? completedAt = null,Object? points = null,}) {
  return _then(_RecentCompletion(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$EngagementMetrics {

 int get daysActiveThisWeek; double get averageDailyCompletions;
/// Create a copy of EngagementMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngagementMetricsCopyWith<EngagementMetrics> get copyWith => _$EngagementMetricsCopyWithImpl<EngagementMetrics>(this as EngagementMetrics, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EngagementMetrics&&(identical(other.daysActiveThisWeek, daysActiveThisWeek) || other.daysActiveThisWeek == daysActiveThisWeek)&&(identical(other.averageDailyCompletions, averageDailyCompletions) || other.averageDailyCompletions == averageDailyCompletions));
}


@override
int get hashCode => Object.hash(runtimeType,daysActiveThisWeek,averageDailyCompletions);

@override
String toString() {
  return 'EngagementMetrics(daysActiveThisWeek: $daysActiveThisWeek, averageDailyCompletions: $averageDailyCompletions)';
}


}

/// @nodoc
abstract mixin class $EngagementMetricsCopyWith<$Res>  {
  factory $EngagementMetricsCopyWith(EngagementMetrics value, $Res Function(EngagementMetrics) _then) = _$EngagementMetricsCopyWithImpl;
@useResult
$Res call({
 int daysActiveThisWeek, double averageDailyCompletions
});




}
/// @nodoc
class _$EngagementMetricsCopyWithImpl<$Res>
    implements $EngagementMetricsCopyWith<$Res> {
  _$EngagementMetricsCopyWithImpl(this._self, this._then);

  final EngagementMetrics _self;
  final $Res Function(EngagementMetrics) _then;

/// Create a copy of EngagementMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? daysActiveThisWeek = null,Object? averageDailyCompletions = null,}) {
  return _then(_self.copyWith(
daysActiveThisWeek: null == daysActiveThisWeek ? _self.daysActiveThisWeek : daysActiveThisWeek // ignore: cast_nullable_to_non_nullable
as int,averageDailyCompletions: null == averageDailyCompletions ? _self.averageDailyCompletions : averageDailyCompletions // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [EngagementMetrics].
extension EngagementMetricsPatterns on EngagementMetrics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EngagementMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EngagementMetrics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EngagementMetrics value)  $default,){
final _that = this;
switch (_that) {
case _EngagementMetrics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EngagementMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _EngagementMetrics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int daysActiveThisWeek,  double averageDailyCompletions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EngagementMetrics() when $default != null:
return $default(_that.daysActiveThisWeek,_that.averageDailyCompletions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int daysActiveThisWeek,  double averageDailyCompletions)  $default,) {final _that = this;
switch (_that) {
case _EngagementMetrics():
return $default(_that.daysActiveThisWeek,_that.averageDailyCompletions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int daysActiveThisWeek,  double averageDailyCompletions)?  $default,) {final _that = this;
switch (_that) {
case _EngagementMetrics() when $default != null:
return $default(_that.daysActiveThisWeek,_that.averageDailyCompletions);case _:
  return null;

}
}

}

/// @nodoc


class _EngagementMetrics implements EngagementMetrics {
  const _EngagementMetrics({required this.daysActiveThisWeek, required this.averageDailyCompletions});
  

@override final  int daysActiveThisWeek;
@override final  double averageDailyCompletions;

/// Create a copy of EngagementMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EngagementMetricsCopyWith<_EngagementMetrics> get copyWith => __$EngagementMetricsCopyWithImpl<_EngagementMetrics>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EngagementMetrics&&(identical(other.daysActiveThisWeek, daysActiveThisWeek) || other.daysActiveThisWeek == daysActiveThisWeek)&&(identical(other.averageDailyCompletions, averageDailyCompletions) || other.averageDailyCompletions == averageDailyCompletions));
}


@override
int get hashCode => Object.hash(runtimeType,daysActiveThisWeek,averageDailyCompletions);

@override
String toString() {
  return 'EngagementMetrics(daysActiveThisWeek: $daysActiveThisWeek, averageDailyCompletions: $averageDailyCompletions)';
}


}

/// @nodoc
abstract mixin class _$EngagementMetricsCopyWith<$Res> implements $EngagementMetricsCopyWith<$Res> {
  factory _$EngagementMetricsCopyWith(_EngagementMetrics value, $Res Function(_EngagementMetrics) _then) = __$EngagementMetricsCopyWithImpl;
@override @useResult
$Res call({
 int daysActiveThisWeek, double averageDailyCompletions
});




}
/// @nodoc
class __$EngagementMetricsCopyWithImpl<$Res>
    implements _$EngagementMetricsCopyWith<$Res> {
  __$EngagementMetricsCopyWithImpl(this._self, this._then);

  final _EngagementMetrics _self;
  final $Res Function(_EngagementMetrics) _then;

/// Create a copy of EngagementMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? daysActiveThisWeek = null,Object? averageDailyCompletions = null,}) {
  return _then(_EngagementMetrics(
daysActiveThisWeek: null == daysActiveThisWeek ? _self.daysActiveThisWeek : daysActiveThisWeek // ignore: cast_nullable_to_non_nullable
as int,averageDailyCompletions: null == averageDailyCompletions ? _self.averageDailyCompletions : averageDailyCompletions // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
