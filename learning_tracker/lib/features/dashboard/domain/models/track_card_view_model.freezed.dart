// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_card_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NextTaskData {

/// Rendered display label (respects Hebrew Terms toggle).
 String get displayLabel;/// Sefaria ref for navigation — null when nothing is queued.
 String? get sefariaRef;/// True when this comes from a calendar-program (vs. self-paced) queue.
 bool get isProgram;
/// Create a copy of NextTaskData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NextTaskDataCopyWith<NextTaskData> get copyWith => _$NextTaskDataCopyWithImpl<NextTaskData>(this as NextTaskData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NextTaskData&&(identical(other.displayLabel, displayLabel) || other.displayLabel == displayLabel)&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.isProgram, isProgram) || other.isProgram == isProgram));
}


@override
int get hashCode => Object.hash(runtimeType,displayLabel,sefariaRef,isProgram);

@override
String toString() {
  return 'NextTaskData(displayLabel: $displayLabel, sefariaRef: $sefariaRef, isProgram: $isProgram)';
}


}

/// @nodoc
abstract mixin class $NextTaskDataCopyWith<$Res>  {
  factory $NextTaskDataCopyWith(NextTaskData value, $Res Function(NextTaskData) _then) = _$NextTaskDataCopyWithImpl;
@useResult
$Res call({
 String displayLabel, String? sefariaRef, bool isProgram
});




}
/// @nodoc
class _$NextTaskDataCopyWithImpl<$Res>
    implements $NextTaskDataCopyWith<$Res> {
  _$NextTaskDataCopyWithImpl(this._self, this._then);

  final NextTaskData _self;
  final $Res Function(NextTaskData) _then;

/// Create a copy of NextTaskData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayLabel = null,Object? sefariaRef = freezed,Object? isProgram = null,}) {
  return _then(_self.copyWith(
displayLabel: null == displayLabel ? _self.displayLabel : displayLabel // ignore: cast_nullable_to_non_nullable
as String,sefariaRef: freezed == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String?,isProgram: null == isProgram ? _self.isProgram : isProgram // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NextTaskData].
extension NextTaskDataPatterns on NextTaskData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NextTaskData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NextTaskData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NextTaskData value)  $default,){
final _that = this;
switch (_that) {
case _NextTaskData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NextTaskData value)?  $default,){
final _that = this;
switch (_that) {
case _NextTaskData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String displayLabel,  String? sefariaRef,  bool isProgram)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NextTaskData() when $default != null:
return $default(_that.displayLabel,_that.sefariaRef,_that.isProgram);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String displayLabel,  String? sefariaRef,  bool isProgram)  $default,) {final _that = this;
switch (_that) {
case _NextTaskData():
return $default(_that.displayLabel,_that.sefariaRef,_that.isProgram);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String displayLabel,  String? sefariaRef,  bool isProgram)?  $default,) {final _that = this;
switch (_that) {
case _NextTaskData() when $default != null:
return $default(_that.displayLabel,_that.sefariaRef,_that.isProgram);case _:
  return null;

}
}

}

/// @nodoc


class _NextTaskData implements NextTaskData {
  const _NextTaskData({required this.displayLabel, this.sefariaRef, this.isProgram = false});
  

/// Rendered display label (respects Hebrew Terms toggle).
@override final  String displayLabel;
/// Sefaria ref for navigation — null when nothing is queued.
@override final  String? sefariaRef;
/// True when this comes from a calendar-program (vs. self-paced) queue.
@override@JsonKey() final  bool isProgram;

/// Create a copy of NextTaskData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NextTaskDataCopyWith<_NextTaskData> get copyWith => __$NextTaskDataCopyWithImpl<_NextTaskData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NextTaskData&&(identical(other.displayLabel, displayLabel) || other.displayLabel == displayLabel)&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.isProgram, isProgram) || other.isProgram == isProgram));
}


@override
int get hashCode => Object.hash(runtimeType,displayLabel,sefariaRef,isProgram);

@override
String toString() {
  return 'NextTaskData(displayLabel: $displayLabel, sefariaRef: $sefariaRef, isProgram: $isProgram)';
}


}

/// @nodoc
abstract mixin class _$NextTaskDataCopyWith<$Res> implements $NextTaskDataCopyWith<$Res> {
  factory _$NextTaskDataCopyWith(_NextTaskData value, $Res Function(_NextTaskData) _then) = __$NextTaskDataCopyWithImpl;
@override @useResult
$Res call({
 String displayLabel, String? sefariaRef, bool isProgram
});




}
/// @nodoc
class __$NextTaskDataCopyWithImpl<$Res>
    implements _$NextTaskDataCopyWith<$Res> {
  __$NextTaskDataCopyWithImpl(this._self, this._then);

  final _NextTaskData _self;
  final $Res Function(_NextTaskData) _then;

/// Create a copy of NextTaskData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayLabel = null,Object? sefariaRef = freezed,Object? isProgram = null,}) {
  return _then(_NextTaskData(
displayLabel: null == displayLabel ? _self.displayLabel : displayLabel // ignore: cast_nullable_to_non_nullable
as String,sefariaRef: freezed == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String?,isProgram: null == isProgram ? _self.isProgram : isProgram // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$LifetimeLearningData {

/// Fraction learned (0.0–1.0).
 double get fraction;/// Pre-formatted percentage string (e.g. "37%"). Null while loading.
 String? get displayPercent;/// True when the entire curriculum has been completed.
 bool get isComplete;
/// Create a copy of LifetimeLearningData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LifetimeLearningDataCopyWith<LifetimeLearningData> get copyWith => _$LifetimeLearningDataCopyWithImpl<LifetimeLearningData>(this as LifetimeLearningData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LifetimeLearningData&&(identical(other.fraction, fraction) || other.fraction == fraction)&&(identical(other.displayPercent, displayPercent) || other.displayPercent == displayPercent)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete));
}


@override
int get hashCode => Object.hash(runtimeType,fraction,displayPercent,isComplete);

@override
String toString() {
  return 'LifetimeLearningData(fraction: $fraction, displayPercent: $displayPercent, isComplete: $isComplete)';
}


}

/// @nodoc
abstract mixin class $LifetimeLearningDataCopyWith<$Res>  {
  factory $LifetimeLearningDataCopyWith(LifetimeLearningData value, $Res Function(LifetimeLearningData) _then) = _$LifetimeLearningDataCopyWithImpl;
@useResult
$Res call({
 double fraction, String? displayPercent, bool isComplete
});




}
/// @nodoc
class _$LifetimeLearningDataCopyWithImpl<$Res>
    implements $LifetimeLearningDataCopyWith<$Res> {
  _$LifetimeLearningDataCopyWithImpl(this._self, this._then);

  final LifetimeLearningData _self;
  final $Res Function(LifetimeLearningData) _then;

/// Create a copy of LifetimeLearningData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fraction = null,Object? displayPercent = freezed,Object? isComplete = null,}) {
  return _then(_self.copyWith(
fraction: null == fraction ? _self.fraction : fraction // ignore: cast_nullable_to_non_nullable
as double,displayPercent: freezed == displayPercent ? _self.displayPercent : displayPercent // ignore: cast_nullable_to_non_nullable
as String?,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LifetimeLearningData].
extension LifetimeLearningDataPatterns on LifetimeLearningData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LifetimeLearningData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LifetimeLearningData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LifetimeLearningData value)  $default,){
final _that = this;
switch (_that) {
case _LifetimeLearningData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LifetimeLearningData value)?  $default,){
final _that = this;
switch (_that) {
case _LifetimeLearningData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double fraction,  String? displayPercent,  bool isComplete)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LifetimeLearningData() when $default != null:
return $default(_that.fraction,_that.displayPercent,_that.isComplete);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double fraction,  String? displayPercent,  bool isComplete)  $default,) {final _that = this;
switch (_that) {
case _LifetimeLearningData():
return $default(_that.fraction,_that.displayPercent,_that.isComplete);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double fraction,  String? displayPercent,  bool isComplete)?  $default,) {final _that = this;
switch (_that) {
case _LifetimeLearningData() when $default != null:
return $default(_that.fraction,_that.displayPercent,_that.isComplete);case _:
  return null;

}
}

}

/// @nodoc


class _LifetimeLearningData implements LifetimeLearningData {
  const _LifetimeLearningData({required this.fraction, this.displayPercent, required this.isComplete});
  

/// Fraction learned (0.0–1.0).
@override final  double fraction;
/// Pre-formatted percentage string (e.g. "37%"). Null while loading.
@override final  String? displayPercent;
/// True when the entire curriculum has been completed.
@override final  bool isComplete;

/// Create a copy of LifetimeLearningData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LifetimeLearningDataCopyWith<_LifetimeLearningData> get copyWith => __$LifetimeLearningDataCopyWithImpl<_LifetimeLearningData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LifetimeLearningData&&(identical(other.fraction, fraction) || other.fraction == fraction)&&(identical(other.displayPercent, displayPercent) || other.displayPercent == displayPercent)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete));
}


@override
int get hashCode => Object.hash(runtimeType,fraction,displayPercent,isComplete);

@override
String toString() {
  return 'LifetimeLearningData(fraction: $fraction, displayPercent: $displayPercent, isComplete: $isComplete)';
}


}

/// @nodoc
abstract mixin class _$LifetimeLearningDataCopyWith<$Res> implements $LifetimeLearningDataCopyWith<$Res> {
  factory _$LifetimeLearningDataCopyWith(_LifetimeLearningData value, $Res Function(_LifetimeLearningData) _then) = __$LifetimeLearningDataCopyWithImpl;
@override @useResult
$Res call({
 double fraction, String? displayPercent, bool isComplete
});




}
/// @nodoc
class __$LifetimeLearningDataCopyWithImpl<$Res>
    implements _$LifetimeLearningDataCopyWith<$Res> {
  __$LifetimeLearningDataCopyWithImpl(this._self, this._then);

  final _LifetimeLearningData _self;
  final $Res Function(_LifetimeLearningData) _then;

/// Create a copy of LifetimeLearningData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fraction = null,Object? displayPercent = freezed,Object? isComplete = null,}) {
  return _then(_LifetimeLearningData(
fraction: null == fraction ? _self.fraction : fraction // ignore: cast_nullable_to_non_nullable
as double,displayPercent: freezed == displayPercent ? _self.displayPercent : displayPercent // ignore: cast_nullable_to_non_nullable
as String?,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$TrackCardViewModel {

// ── Identity ─────────────────────────────────────────────────────────────
 int get trackId; CurriculumId get curriculumId;/// Which of the four data shapes this card represents.
 TrackCardShape get shape;// ── Header ───────────────────────────────────────────────────────────────
/// Primary label: "{TrackType} · {CurriculumName}"
 String get displayNamePrimary;/// Secondary label (Hebrew name). Null when Hebrew Terms toggle is on
/// and the primary is already in Hebrew.
 String? get displayNameSecondary;/// Accent colour derived from the curriculum (for the book-icon circle).
 int get curriculumColorValue;// ── Breadcrumb ───────────────────────────────────────────────────────────
 NextTaskData get nextTask;/// UI label above the breadcrumb ("NEXT TASK" / "CURRENT FOCUS").
 String get breadcrumbLabel;// ── Stat grid ────────────────────────────────────────────────────────────
/// Count of review (chazara) tasks due.
 int get reviewCount;/// Count of new-learning / on-time program tasks.
 int get dueTodayCount;/// Count of overdue / missed tasks.
 int get overdueCount;/// Human-readable label for the review (chazara) column.
 String get chazaraLabel;// ── Lifetime learning ────────────────────────────────────────────────────
 LifetimeLearningData get lifetime;// ── Shape-specific optional fields ───────────────────────────────────────
/// Populated for [TrackCardShape.programCalendar].
 CalendarPosition? get calendarPos;/// Populated for [TrackCardShape.deadlineGoal] and
/// [TrackCardShape.velocityGoal].
 PaceStatus? get paceStatus;/// Populated for [TrackCardShape.momentum].
 MomentumStatus? get momentum;/// Populated for any shape when chazara stages are configured.
 ChazaraStatus? get chazaraStatus;// ── Empty-queue hint ─────────────────────────────────────────────────────
/// Shown below the stat grid when the queue is empty.
/// Null when there are tasks queued.
 String? get emptyQueueHint;
/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackCardViewModelCopyWith<TrackCardViewModel> get copyWith => _$TrackCardViewModelCopyWithImpl<TrackCardViewModel>(this as TrackCardViewModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackCardViewModel&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.shape, shape) || other.shape == shape)&&(identical(other.displayNamePrimary, displayNamePrimary) || other.displayNamePrimary == displayNamePrimary)&&(identical(other.displayNameSecondary, displayNameSecondary) || other.displayNameSecondary == displayNameSecondary)&&(identical(other.curriculumColorValue, curriculumColorValue) || other.curriculumColorValue == curriculumColorValue)&&(identical(other.nextTask, nextTask) || other.nextTask == nextTask)&&(identical(other.breadcrumbLabel, breadcrumbLabel) || other.breadcrumbLabel == breadcrumbLabel)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.dueTodayCount, dueTodayCount) || other.dueTodayCount == dueTodayCount)&&(identical(other.overdueCount, overdueCount) || other.overdueCount == overdueCount)&&(identical(other.chazaraLabel, chazaraLabel) || other.chazaraLabel == chazaraLabel)&&(identical(other.lifetime, lifetime) || other.lifetime == lifetime)&&(identical(other.calendarPos, calendarPos) || other.calendarPos == calendarPos)&&(identical(other.paceStatus, paceStatus) || other.paceStatus == paceStatus)&&(identical(other.momentum, momentum) || other.momentum == momentum)&&(identical(other.chazaraStatus, chazaraStatus) || other.chazaraStatus == chazaraStatus)&&(identical(other.emptyQueueHint, emptyQueueHint) || other.emptyQueueHint == emptyQueueHint));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,curriculumId,shape,displayNamePrimary,displayNameSecondary,curriculumColorValue,nextTask,breadcrumbLabel,reviewCount,dueTodayCount,overdueCount,chazaraLabel,lifetime,calendarPos,paceStatus,momentum,chazaraStatus,emptyQueueHint);

@override
String toString() {
  return 'TrackCardViewModel(trackId: $trackId, curriculumId: $curriculumId, shape: $shape, displayNamePrimary: $displayNamePrimary, displayNameSecondary: $displayNameSecondary, curriculumColorValue: $curriculumColorValue, nextTask: $nextTask, breadcrumbLabel: $breadcrumbLabel, reviewCount: $reviewCount, dueTodayCount: $dueTodayCount, overdueCount: $overdueCount, chazaraLabel: $chazaraLabel, lifetime: $lifetime, calendarPos: $calendarPos, paceStatus: $paceStatus, momentum: $momentum, chazaraStatus: $chazaraStatus, emptyQueueHint: $emptyQueueHint)';
}


}

/// @nodoc
abstract mixin class $TrackCardViewModelCopyWith<$Res>  {
  factory $TrackCardViewModelCopyWith(TrackCardViewModel value, $Res Function(TrackCardViewModel) _then) = _$TrackCardViewModelCopyWithImpl;
@useResult
$Res call({
 int trackId, CurriculumId curriculumId, TrackCardShape shape, String displayNamePrimary, String? displayNameSecondary, int curriculumColorValue, NextTaskData nextTask, String breadcrumbLabel, int reviewCount, int dueTodayCount, int overdueCount, String chazaraLabel, LifetimeLearningData lifetime, CalendarPosition? calendarPos, PaceStatus? paceStatus, MomentumStatus? momentum, ChazaraStatus? chazaraStatus, String? emptyQueueHint
});


$NextTaskDataCopyWith<$Res> get nextTask;$LifetimeLearningDataCopyWith<$Res> get lifetime;$CalendarPositionCopyWith<$Res>? get calendarPos;$PaceStatusCopyWith<$Res>? get paceStatus;$MomentumStatusCopyWith<$Res>? get momentum;$ChazaraStatusCopyWith<$Res>? get chazaraStatus;

}
/// @nodoc
class _$TrackCardViewModelCopyWithImpl<$Res>
    implements $TrackCardViewModelCopyWith<$Res> {
  _$TrackCardViewModelCopyWithImpl(this._self, this._then);

  final TrackCardViewModel _self;
  final $Res Function(TrackCardViewModel) _then;

/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackId = null,Object? curriculumId = null,Object? shape = null,Object? displayNamePrimary = null,Object? displayNameSecondary = freezed,Object? curriculumColorValue = null,Object? nextTask = null,Object? breadcrumbLabel = null,Object? reviewCount = null,Object? dueTodayCount = null,Object? overdueCount = null,Object? chazaraLabel = null,Object? lifetime = null,Object? calendarPos = freezed,Object? paceStatus = freezed,Object? momentum = freezed,Object? chazaraStatus = freezed,Object? emptyQueueHint = freezed,}) {
  return _then(_self.copyWith(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,shape: null == shape ? _self.shape : shape // ignore: cast_nullable_to_non_nullable
as TrackCardShape,displayNamePrimary: null == displayNamePrimary ? _self.displayNamePrimary : displayNamePrimary // ignore: cast_nullable_to_non_nullable
as String,displayNameSecondary: freezed == displayNameSecondary ? _self.displayNameSecondary : displayNameSecondary // ignore: cast_nullable_to_non_nullable
as String?,curriculumColorValue: null == curriculumColorValue ? _self.curriculumColorValue : curriculumColorValue // ignore: cast_nullable_to_non_nullable
as int,nextTask: null == nextTask ? _self.nextTask : nextTask // ignore: cast_nullable_to_non_nullable
as NextTaskData,breadcrumbLabel: null == breadcrumbLabel ? _self.breadcrumbLabel : breadcrumbLabel // ignore: cast_nullable_to_non_nullable
as String,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,dueTodayCount: null == dueTodayCount ? _self.dueTodayCount : dueTodayCount // ignore: cast_nullable_to_non_nullable
as int,overdueCount: null == overdueCount ? _self.overdueCount : overdueCount // ignore: cast_nullable_to_non_nullable
as int,chazaraLabel: null == chazaraLabel ? _self.chazaraLabel : chazaraLabel // ignore: cast_nullable_to_non_nullable
as String,lifetime: null == lifetime ? _self.lifetime : lifetime // ignore: cast_nullable_to_non_nullable
as LifetimeLearningData,calendarPos: freezed == calendarPos ? _self.calendarPos : calendarPos // ignore: cast_nullable_to_non_nullable
as CalendarPosition?,paceStatus: freezed == paceStatus ? _self.paceStatus : paceStatus // ignore: cast_nullable_to_non_nullable
as PaceStatus?,momentum: freezed == momentum ? _self.momentum : momentum // ignore: cast_nullable_to_non_nullable
as MomentumStatus?,chazaraStatus: freezed == chazaraStatus ? _self.chazaraStatus : chazaraStatus // ignore: cast_nullable_to_non_nullable
as ChazaraStatus?,emptyQueueHint: freezed == emptyQueueHint ? _self.emptyQueueHint : emptyQueueHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NextTaskDataCopyWith<$Res> get nextTask {
  
  return $NextTaskDataCopyWith<$Res>(_self.nextTask, (value) {
    return _then(_self.copyWith(nextTask: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LifetimeLearningDataCopyWith<$Res> get lifetime {
  
  return $LifetimeLearningDataCopyWith<$Res>(_self.lifetime, (value) {
    return _then(_self.copyWith(lifetime: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CalendarPositionCopyWith<$Res>? get calendarPos {
    if (_self.calendarPos == null) {
    return null;
  }

  return $CalendarPositionCopyWith<$Res>(_self.calendarPos!, (value) {
    return _then(_self.copyWith(calendarPos: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaceStatusCopyWith<$Res>? get paceStatus {
    if (_self.paceStatus == null) {
    return null;
  }

  return $PaceStatusCopyWith<$Res>(_self.paceStatus!, (value) {
    return _then(_self.copyWith(paceStatus: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MomentumStatusCopyWith<$Res>? get momentum {
    if (_self.momentum == null) {
    return null;
  }

  return $MomentumStatusCopyWith<$Res>(_self.momentum!, (value) {
    return _then(_self.copyWith(momentum: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChazaraStatusCopyWith<$Res>? get chazaraStatus {
    if (_self.chazaraStatus == null) {
    return null;
  }

  return $ChazaraStatusCopyWith<$Res>(_self.chazaraStatus!, (value) {
    return _then(_self.copyWith(chazaraStatus: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrackCardViewModel].
extension TrackCardViewModelPatterns on TrackCardViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackCardViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackCardViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackCardViewModel value)  $default,){
final _that = this;
switch (_that) {
case _TrackCardViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackCardViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _TrackCardViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int trackId,  CurriculumId curriculumId,  TrackCardShape shape,  String displayNamePrimary,  String? displayNameSecondary,  int curriculumColorValue,  NextTaskData nextTask,  String breadcrumbLabel,  int reviewCount,  int dueTodayCount,  int overdueCount,  String chazaraLabel,  LifetimeLearningData lifetime,  CalendarPosition? calendarPos,  PaceStatus? paceStatus,  MomentumStatus? momentum,  ChazaraStatus? chazaraStatus,  String? emptyQueueHint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackCardViewModel() when $default != null:
return $default(_that.trackId,_that.curriculumId,_that.shape,_that.displayNamePrimary,_that.displayNameSecondary,_that.curriculumColorValue,_that.nextTask,_that.breadcrumbLabel,_that.reviewCount,_that.dueTodayCount,_that.overdueCount,_that.chazaraLabel,_that.lifetime,_that.calendarPos,_that.paceStatus,_that.momentum,_that.chazaraStatus,_that.emptyQueueHint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int trackId,  CurriculumId curriculumId,  TrackCardShape shape,  String displayNamePrimary,  String? displayNameSecondary,  int curriculumColorValue,  NextTaskData nextTask,  String breadcrumbLabel,  int reviewCount,  int dueTodayCount,  int overdueCount,  String chazaraLabel,  LifetimeLearningData lifetime,  CalendarPosition? calendarPos,  PaceStatus? paceStatus,  MomentumStatus? momentum,  ChazaraStatus? chazaraStatus,  String? emptyQueueHint)  $default,) {final _that = this;
switch (_that) {
case _TrackCardViewModel():
return $default(_that.trackId,_that.curriculumId,_that.shape,_that.displayNamePrimary,_that.displayNameSecondary,_that.curriculumColorValue,_that.nextTask,_that.breadcrumbLabel,_that.reviewCount,_that.dueTodayCount,_that.overdueCount,_that.chazaraLabel,_that.lifetime,_that.calendarPos,_that.paceStatus,_that.momentum,_that.chazaraStatus,_that.emptyQueueHint);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int trackId,  CurriculumId curriculumId,  TrackCardShape shape,  String displayNamePrimary,  String? displayNameSecondary,  int curriculumColorValue,  NextTaskData nextTask,  String breadcrumbLabel,  int reviewCount,  int dueTodayCount,  int overdueCount,  String chazaraLabel,  LifetimeLearningData lifetime,  CalendarPosition? calendarPos,  PaceStatus? paceStatus,  MomentumStatus? momentum,  ChazaraStatus? chazaraStatus,  String? emptyQueueHint)?  $default,) {final _that = this;
switch (_that) {
case _TrackCardViewModel() when $default != null:
return $default(_that.trackId,_that.curriculumId,_that.shape,_that.displayNamePrimary,_that.displayNameSecondary,_that.curriculumColorValue,_that.nextTask,_that.breadcrumbLabel,_that.reviewCount,_that.dueTodayCount,_that.overdueCount,_that.chazaraLabel,_that.lifetime,_that.calendarPos,_that.paceStatus,_that.momentum,_that.chazaraStatus,_that.emptyQueueHint);case _:
  return null;

}
}

}

/// @nodoc


class _TrackCardViewModel extends TrackCardViewModel {
  const _TrackCardViewModel({required this.trackId, required this.curriculumId, required this.shape, required this.displayNamePrimary, this.displayNameSecondary, required this.curriculumColorValue, required this.nextTask, required this.breadcrumbLabel, required this.reviewCount, required this.dueTodayCount, required this.overdueCount, required this.chazaraLabel, required this.lifetime, this.calendarPos, this.paceStatus, this.momentum, this.chazaraStatus, this.emptyQueueHint}): super._();
  

// ── Identity ─────────────────────────────────────────────────────────────
@override final  int trackId;
@override final  CurriculumId curriculumId;
/// Which of the four data shapes this card represents.
@override final  TrackCardShape shape;
// ── Header ───────────────────────────────────────────────────────────────
/// Primary label: "{TrackType} · {CurriculumName}"
@override final  String displayNamePrimary;
/// Secondary label (Hebrew name). Null when Hebrew Terms toggle is on
/// and the primary is already in Hebrew.
@override final  String? displayNameSecondary;
/// Accent colour derived from the curriculum (for the book-icon circle).
@override final  int curriculumColorValue;
// ── Breadcrumb ───────────────────────────────────────────────────────────
@override final  NextTaskData nextTask;
/// UI label above the breadcrumb ("NEXT TASK" / "CURRENT FOCUS").
@override final  String breadcrumbLabel;
// ── Stat grid ────────────────────────────────────────────────────────────
/// Count of review (chazara) tasks due.
@override final  int reviewCount;
/// Count of new-learning / on-time program tasks.
@override final  int dueTodayCount;
/// Count of overdue / missed tasks.
@override final  int overdueCount;
/// Human-readable label for the review (chazara) column.
@override final  String chazaraLabel;
// ── Lifetime learning ────────────────────────────────────────────────────
@override final  LifetimeLearningData lifetime;
// ── Shape-specific optional fields ───────────────────────────────────────
/// Populated for [TrackCardShape.programCalendar].
@override final  CalendarPosition? calendarPos;
/// Populated for [TrackCardShape.deadlineGoal] and
/// [TrackCardShape.velocityGoal].
@override final  PaceStatus? paceStatus;
/// Populated for [TrackCardShape.momentum].
@override final  MomentumStatus? momentum;
/// Populated for any shape when chazara stages are configured.
@override final  ChazaraStatus? chazaraStatus;
// ── Empty-queue hint ─────────────────────────────────────────────────────
/// Shown below the stat grid when the queue is empty.
/// Null when there are tasks queued.
@override final  String? emptyQueueHint;

/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackCardViewModelCopyWith<_TrackCardViewModel> get copyWith => __$TrackCardViewModelCopyWithImpl<_TrackCardViewModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackCardViewModel&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.shape, shape) || other.shape == shape)&&(identical(other.displayNamePrimary, displayNamePrimary) || other.displayNamePrimary == displayNamePrimary)&&(identical(other.displayNameSecondary, displayNameSecondary) || other.displayNameSecondary == displayNameSecondary)&&(identical(other.curriculumColorValue, curriculumColorValue) || other.curriculumColorValue == curriculumColorValue)&&(identical(other.nextTask, nextTask) || other.nextTask == nextTask)&&(identical(other.breadcrumbLabel, breadcrumbLabel) || other.breadcrumbLabel == breadcrumbLabel)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.dueTodayCount, dueTodayCount) || other.dueTodayCount == dueTodayCount)&&(identical(other.overdueCount, overdueCount) || other.overdueCount == overdueCount)&&(identical(other.chazaraLabel, chazaraLabel) || other.chazaraLabel == chazaraLabel)&&(identical(other.lifetime, lifetime) || other.lifetime == lifetime)&&(identical(other.calendarPos, calendarPos) || other.calendarPos == calendarPos)&&(identical(other.paceStatus, paceStatus) || other.paceStatus == paceStatus)&&(identical(other.momentum, momentum) || other.momentum == momentum)&&(identical(other.chazaraStatus, chazaraStatus) || other.chazaraStatus == chazaraStatus)&&(identical(other.emptyQueueHint, emptyQueueHint) || other.emptyQueueHint == emptyQueueHint));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,curriculumId,shape,displayNamePrimary,displayNameSecondary,curriculumColorValue,nextTask,breadcrumbLabel,reviewCount,dueTodayCount,overdueCount,chazaraLabel,lifetime,calendarPos,paceStatus,momentum,chazaraStatus,emptyQueueHint);

@override
String toString() {
  return 'TrackCardViewModel(trackId: $trackId, curriculumId: $curriculumId, shape: $shape, displayNamePrimary: $displayNamePrimary, displayNameSecondary: $displayNameSecondary, curriculumColorValue: $curriculumColorValue, nextTask: $nextTask, breadcrumbLabel: $breadcrumbLabel, reviewCount: $reviewCount, dueTodayCount: $dueTodayCount, overdueCount: $overdueCount, chazaraLabel: $chazaraLabel, lifetime: $lifetime, calendarPos: $calendarPos, paceStatus: $paceStatus, momentum: $momentum, chazaraStatus: $chazaraStatus, emptyQueueHint: $emptyQueueHint)';
}


}

/// @nodoc
abstract mixin class _$TrackCardViewModelCopyWith<$Res> implements $TrackCardViewModelCopyWith<$Res> {
  factory _$TrackCardViewModelCopyWith(_TrackCardViewModel value, $Res Function(_TrackCardViewModel) _then) = __$TrackCardViewModelCopyWithImpl;
@override @useResult
$Res call({
 int trackId, CurriculumId curriculumId, TrackCardShape shape, String displayNamePrimary, String? displayNameSecondary, int curriculumColorValue, NextTaskData nextTask, String breadcrumbLabel, int reviewCount, int dueTodayCount, int overdueCount, String chazaraLabel, LifetimeLearningData lifetime, CalendarPosition? calendarPos, PaceStatus? paceStatus, MomentumStatus? momentum, ChazaraStatus? chazaraStatus, String? emptyQueueHint
});


@override $NextTaskDataCopyWith<$Res> get nextTask;@override $LifetimeLearningDataCopyWith<$Res> get lifetime;@override $CalendarPositionCopyWith<$Res>? get calendarPos;@override $PaceStatusCopyWith<$Res>? get paceStatus;@override $MomentumStatusCopyWith<$Res>? get momentum;@override $ChazaraStatusCopyWith<$Res>? get chazaraStatus;

}
/// @nodoc
class __$TrackCardViewModelCopyWithImpl<$Res>
    implements _$TrackCardViewModelCopyWith<$Res> {
  __$TrackCardViewModelCopyWithImpl(this._self, this._then);

  final _TrackCardViewModel _self;
  final $Res Function(_TrackCardViewModel) _then;

/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? curriculumId = null,Object? shape = null,Object? displayNamePrimary = null,Object? displayNameSecondary = freezed,Object? curriculumColorValue = null,Object? nextTask = null,Object? breadcrumbLabel = null,Object? reviewCount = null,Object? dueTodayCount = null,Object? overdueCount = null,Object? chazaraLabel = null,Object? lifetime = null,Object? calendarPos = freezed,Object? paceStatus = freezed,Object? momentum = freezed,Object? chazaraStatus = freezed,Object? emptyQueueHint = freezed,}) {
  return _then(_TrackCardViewModel(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,shape: null == shape ? _self.shape : shape // ignore: cast_nullable_to_non_nullable
as TrackCardShape,displayNamePrimary: null == displayNamePrimary ? _self.displayNamePrimary : displayNamePrimary // ignore: cast_nullable_to_non_nullable
as String,displayNameSecondary: freezed == displayNameSecondary ? _self.displayNameSecondary : displayNameSecondary // ignore: cast_nullable_to_non_nullable
as String?,curriculumColorValue: null == curriculumColorValue ? _self.curriculumColorValue : curriculumColorValue // ignore: cast_nullable_to_non_nullable
as int,nextTask: null == nextTask ? _self.nextTask : nextTask // ignore: cast_nullable_to_non_nullable
as NextTaskData,breadcrumbLabel: null == breadcrumbLabel ? _self.breadcrumbLabel : breadcrumbLabel // ignore: cast_nullable_to_non_nullable
as String,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,dueTodayCount: null == dueTodayCount ? _self.dueTodayCount : dueTodayCount // ignore: cast_nullable_to_non_nullable
as int,overdueCount: null == overdueCount ? _self.overdueCount : overdueCount // ignore: cast_nullable_to_non_nullable
as int,chazaraLabel: null == chazaraLabel ? _self.chazaraLabel : chazaraLabel // ignore: cast_nullable_to_non_nullable
as String,lifetime: null == lifetime ? _self.lifetime : lifetime // ignore: cast_nullable_to_non_nullable
as LifetimeLearningData,calendarPos: freezed == calendarPos ? _self.calendarPos : calendarPos // ignore: cast_nullable_to_non_nullable
as CalendarPosition?,paceStatus: freezed == paceStatus ? _self.paceStatus : paceStatus // ignore: cast_nullable_to_non_nullable
as PaceStatus?,momentum: freezed == momentum ? _self.momentum : momentum // ignore: cast_nullable_to_non_nullable
as MomentumStatus?,chazaraStatus: freezed == chazaraStatus ? _self.chazaraStatus : chazaraStatus // ignore: cast_nullable_to_non_nullable
as ChazaraStatus?,emptyQueueHint: freezed == emptyQueueHint ? _self.emptyQueueHint : emptyQueueHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NextTaskDataCopyWith<$Res> get nextTask {
  
  return $NextTaskDataCopyWith<$Res>(_self.nextTask, (value) {
    return _then(_self.copyWith(nextTask: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LifetimeLearningDataCopyWith<$Res> get lifetime {
  
  return $LifetimeLearningDataCopyWith<$Res>(_self.lifetime, (value) {
    return _then(_self.copyWith(lifetime: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CalendarPositionCopyWith<$Res>? get calendarPos {
    if (_self.calendarPos == null) {
    return null;
  }

  return $CalendarPositionCopyWith<$Res>(_self.calendarPos!, (value) {
    return _then(_self.copyWith(calendarPos: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaceStatusCopyWith<$Res>? get paceStatus {
    if (_self.paceStatus == null) {
    return null;
  }

  return $PaceStatusCopyWith<$Res>(_self.paceStatus!, (value) {
    return _then(_self.copyWith(paceStatus: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MomentumStatusCopyWith<$Res>? get momentum {
    if (_self.momentum == null) {
    return null;
  }

  return $MomentumStatusCopyWith<$Res>(_self.momentum!, (value) {
    return _then(_self.copyWith(momentum: value));
  });
}/// Create a copy of TrackCardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChazaraStatusCopyWith<$Res>? get chazaraStatus {
    if (_self.chazaraStatus == null) {
    return null;
  }

  return $ChazaraStatusCopyWith<$Res>(_self.chazaraStatus!, (value) {
    return _then(_self.copyWith(chazaraStatus: value));
  });
}
}

// dart format on
