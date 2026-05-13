// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchedulerInput {

/// The curriculum being scheduled.
 CurriculumId get curriculumId;/// The track this run is for (0 = no specific track, used in tests).
 int get trackId;/// Display label for the track (e.g. 'personal').
 String get trackLabel;/// UTC clock value for this scheduling run.
 DateTime get today;/// All leaf content items for the curriculum, in sort order.
 List<SchedulerContentItem> get contentItems;/// All completion records visible to this track.
 List<SchedulerCompletion> get completions;/// Stage definitions for the curriculum, ordered by stageOrder.
 List<SchedulerStage> get stages;/// Target pace in leaf items (or coarse units) per day.
/// Non-null for self-paced pace-goal tracks.
 double? get pacePerDay;/// Coarse learning unit key (e.g. 'perek', 'daf'). When set and
/// different from the curriculum leaf, [pacePerDay] is interpreted as
/// coarse-unit count, not leaf count.
 String? get paceGranularity;/// When the track was activated. Required for snapshot-based pacing.
 DateTime? get trackStartedAt;/// Goal deadline. Non-null for deadline-goal tracks.
 DateTime? get goalDeadline;/// True when today is a configured study day for this track.
 bool get isStudyDay;/// Number of study days per week (1–7). Used for deadline pacing.
 int get studyDaysPerWeek;/// Exact count of study days from today through the deadline inclusive.
/// When set, deadline pacing uses this instead of approximating.
 int? get studyDaysInDeadlineWindow;/// Refs that appeared in any prior-day snapshot for this track.
/// Used by the snapshot path to identify overdue and new items.
 Set<String> get priorlyShownRefs;/// Default new items per day when no pacing signal is present.
 int get defaultNewItemsPerDay;
/// Create a copy of SchedulerInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerInputCopyWith<SchedulerInput> get copyWith => _$SchedulerInputCopyWithImpl<SchedulerInput>(this as SchedulerInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerInput&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&(identical(other.today, today) || other.today == today)&&const DeepCollectionEquality().equals(other.contentItems, contentItems)&&const DeepCollectionEquality().equals(other.completions, completions)&&const DeepCollectionEquality().equals(other.stages, stages)&&(identical(other.pacePerDay, pacePerDay) || other.pacePerDay == pacePerDay)&&(identical(other.paceGranularity, paceGranularity) || other.paceGranularity == paceGranularity)&&(identical(other.trackStartedAt, trackStartedAt) || other.trackStartedAt == trackStartedAt)&&(identical(other.goalDeadline, goalDeadline) || other.goalDeadline == goalDeadline)&&(identical(other.isStudyDay, isStudyDay) || other.isStudyDay == isStudyDay)&&(identical(other.studyDaysPerWeek, studyDaysPerWeek) || other.studyDaysPerWeek == studyDaysPerWeek)&&(identical(other.studyDaysInDeadlineWindow, studyDaysInDeadlineWindow) || other.studyDaysInDeadlineWindow == studyDaysInDeadlineWindow)&&const DeepCollectionEquality().equals(other.priorlyShownRefs, priorlyShownRefs)&&(identical(other.defaultNewItemsPerDay, defaultNewItemsPerDay) || other.defaultNewItemsPerDay == defaultNewItemsPerDay));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,trackId,trackLabel,today,const DeepCollectionEquality().hash(contentItems),const DeepCollectionEquality().hash(completions),const DeepCollectionEquality().hash(stages),pacePerDay,paceGranularity,trackStartedAt,goalDeadline,isStudyDay,studyDaysPerWeek,studyDaysInDeadlineWindow,const DeepCollectionEquality().hash(priorlyShownRefs),defaultNewItemsPerDay);

@override
String toString() {
  return 'SchedulerInput(curriculumId: $curriculumId, trackId: $trackId, trackLabel: $trackLabel, today: $today, contentItems: $contentItems, completions: $completions, stages: $stages, pacePerDay: $pacePerDay, paceGranularity: $paceGranularity, trackStartedAt: $trackStartedAt, goalDeadline: $goalDeadline, isStudyDay: $isStudyDay, studyDaysPerWeek: $studyDaysPerWeek, studyDaysInDeadlineWindow: $studyDaysInDeadlineWindow, priorlyShownRefs: $priorlyShownRefs, defaultNewItemsPerDay: $defaultNewItemsPerDay)';
}


}

/// @nodoc
abstract mixin class $SchedulerInputCopyWith<$Res>  {
  factory $SchedulerInputCopyWith(SchedulerInput value, $Res Function(SchedulerInput) _then) = _$SchedulerInputCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculumId, int trackId, String trackLabel, DateTime today, List<SchedulerContentItem> contentItems, List<SchedulerCompletion> completions, List<SchedulerStage> stages, double? pacePerDay, String? paceGranularity, DateTime? trackStartedAt, DateTime? goalDeadline, bool isStudyDay, int studyDaysPerWeek, int? studyDaysInDeadlineWindow, Set<String> priorlyShownRefs, int defaultNewItemsPerDay
});




}
/// @nodoc
class _$SchedulerInputCopyWithImpl<$Res>
    implements $SchedulerInputCopyWith<$Res> {
  _$SchedulerInputCopyWithImpl(this._self, this._then);

  final SchedulerInput _self;
  final $Res Function(SchedulerInput) _then;

/// Create a copy of SchedulerInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? trackId = null,Object? trackLabel = null,Object? today = null,Object? contentItems = null,Object? completions = null,Object? stages = null,Object? pacePerDay = freezed,Object? paceGranularity = freezed,Object? trackStartedAt = freezed,Object? goalDeadline = freezed,Object? isStudyDay = null,Object? studyDaysPerWeek = null,Object? studyDaysInDeadlineWindow = freezed,Object? priorlyShownRefs = null,Object? defaultNewItemsPerDay = null,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,trackLabel: null == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as DateTime,contentItems: null == contentItems ? _self.contentItems : contentItems // ignore: cast_nullable_to_non_nullable
as List<SchedulerContentItem>,completions: null == completions ? _self.completions : completions // ignore: cast_nullable_to_non_nullable
as List<SchedulerCompletion>,stages: null == stages ? _self.stages : stages // ignore: cast_nullable_to_non_nullable
as List<SchedulerStage>,pacePerDay: freezed == pacePerDay ? _self.pacePerDay : pacePerDay // ignore: cast_nullable_to_non_nullable
as double?,paceGranularity: freezed == paceGranularity ? _self.paceGranularity : paceGranularity // ignore: cast_nullable_to_non_nullable
as String?,trackStartedAt: freezed == trackStartedAt ? _self.trackStartedAt : trackStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,goalDeadline: freezed == goalDeadline ? _self.goalDeadline : goalDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,isStudyDay: null == isStudyDay ? _self.isStudyDay : isStudyDay // ignore: cast_nullable_to_non_nullable
as bool,studyDaysPerWeek: null == studyDaysPerWeek ? _self.studyDaysPerWeek : studyDaysPerWeek // ignore: cast_nullable_to_non_nullable
as int,studyDaysInDeadlineWindow: freezed == studyDaysInDeadlineWindow ? _self.studyDaysInDeadlineWindow : studyDaysInDeadlineWindow // ignore: cast_nullable_to_non_nullable
as int?,priorlyShownRefs: null == priorlyShownRefs ? _self.priorlyShownRefs : priorlyShownRefs // ignore: cast_nullable_to_non_nullable
as Set<String>,defaultNewItemsPerDay: null == defaultNewItemsPerDay ? _self.defaultNewItemsPerDay : defaultNewItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerInput].
extension SchedulerInputPatterns on SchedulerInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerInput value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerInput value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  int trackId,  String trackLabel,  DateTime today,  List<SchedulerContentItem> contentItems,  List<SchedulerCompletion> completions,  List<SchedulerStage> stages,  double? pacePerDay,  String? paceGranularity,  DateTime? trackStartedAt,  DateTime? goalDeadline,  bool isStudyDay,  int studyDaysPerWeek,  int? studyDaysInDeadlineWindow,  Set<String> priorlyShownRefs,  int defaultNewItemsPerDay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerInput() when $default != null:
return $default(_that.curriculumId,_that.trackId,_that.trackLabel,_that.today,_that.contentItems,_that.completions,_that.stages,_that.pacePerDay,_that.paceGranularity,_that.trackStartedAt,_that.goalDeadline,_that.isStudyDay,_that.studyDaysPerWeek,_that.studyDaysInDeadlineWindow,_that.priorlyShownRefs,_that.defaultNewItemsPerDay);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  int trackId,  String trackLabel,  DateTime today,  List<SchedulerContentItem> contentItems,  List<SchedulerCompletion> completions,  List<SchedulerStage> stages,  double? pacePerDay,  String? paceGranularity,  DateTime? trackStartedAt,  DateTime? goalDeadline,  bool isStudyDay,  int studyDaysPerWeek,  int? studyDaysInDeadlineWindow,  Set<String> priorlyShownRefs,  int defaultNewItemsPerDay)  $default,) {final _that = this;
switch (_that) {
case _SchedulerInput():
return $default(_that.curriculumId,_that.trackId,_that.trackLabel,_that.today,_that.contentItems,_that.completions,_that.stages,_that.pacePerDay,_that.paceGranularity,_that.trackStartedAt,_that.goalDeadline,_that.isStudyDay,_that.studyDaysPerWeek,_that.studyDaysInDeadlineWindow,_that.priorlyShownRefs,_that.defaultNewItemsPerDay);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculumId,  int trackId,  String trackLabel,  DateTime today,  List<SchedulerContentItem> contentItems,  List<SchedulerCompletion> completions,  List<SchedulerStage> stages,  double? pacePerDay,  String? paceGranularity,  DateTime? trackStartedAt,  DateTime? goalDeadline,  bool isStudyDay,  int studyDaysPerWeek,  int? studyDaysInDeadlineWindow,  Set<String> priorlyShownRefs,  int defaultNewItemsPerDay)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerInput() when $default != null:
return $default(_that.curriculumId,_that.trackId,_that.trackLabel,_that.today,_that.contentItems,_that.completions,_that.stages,_that.pacePerDay,_that.paceGranularity,_that.trackStartedAt,_that.goalDeadline,_that.isStudyDay,_that.studyDaysPerWeek,_that.studyDaysInDeadlineWindow,_that.priorlyShownRefs,_that.defaultNewItemsPerDay);case _:
  return null;

}
}

}

/// @nodoc


class _SchedulerInput implements SchedulerInput {
  const _SchedulerInput({required this.curriculumId, required this.trackId, required this.trackLabel, required this.today, required final  List<SchedulerContentItem> contentItems, required final  List<SchedulerCompletion> completions, required final  List<SchedulerStage> stages, this.pacePerDay, this.paceGranularity, this.trackStartedAt, this.goalDeadline, this.isStudyDay = true, this.studyDaysPerWeek = 7, this.studyDaysInDeadlineWindow, final  Set<String> priorlyShownRefs = const <String>{}, this.defaultNewItemsPerDay = 5}): _contentItems = contentItems,_completions = completions,_stages = stages,_priorlyShownRefs = priorlyShownRefs;
  

/// The curriculum being scheduled.
@override final  CurriculumId curriculumId;
/// The track this run is for (0 = no specific track, used in tests).
@override final  int trackId;
/// Display label for the track (e.g. 'personal').
@override final  String trackLabel;
/// UTC clock value for this scheduling run.
@override final  DateTime today;
/// All leaf content items for the curriculum, in sort order.
 final  List<SchedulerContentItem> _contentItems;
/// All leaf content items for the curriculum, in sort order.
@override List<SchedulerContentItem> get contentItems {
  if (_contentItems is EqualUnmodifiableListView) return _contentItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contentItems);
}

/// All completion records visible to this track.
 final  List<SchedulerCompletion> _completions;
/// All completion records visible to this track.
@override List<SchedulerCompletion> get completions {
  if (_completions is EqualUnmodifiableListView) return _completions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_completions);
}

/// Stage definitions for the curriculum, ordered by stageOrder.
 final  List<SchedulerStage> _stages;
/// Stage definitions for the curriculum, ordered by stageOrder.
@override List<SchedulerStage> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// Target pace in leaf items (or coarse units) per day.
/// Non-null for self-paced pace-goal tracks.
@override final  double? pacePerDay;
/// Coarse learning unit key (e.g. 'perek', 'daf'). When set and
/// different from the curriculum leaf, [pacePerDay] is interpreted as
/// coarse-unit count, not leaf count.
@override final  String? paceGranularity;
/// When the track was activated. Required for snapshot-based pacing.
@override final  DateTime? trackStartedAt;
/// Goal deadline. Non-null for deadline-goal tracks.
@override final  DateTime? goalDeadline;
/// True when today is a configured study day for this track.
@override@JsonKey() final  bool isStudyDay;
/// Number of study days per week (1–7). Used for deadline pacing.
@override@JsonKey() final  int studyDaysPerWeek;
/// Exact count of study days from today through the deadline inclusive.
/// When set, deadline pacing uses this instead of approximating.
@override final  int? studyDaysInDeadlineWindow;
/// Refs that appeared in any prior-day snapshot for this track.
/// Used by the snapshot path to identify overdue and new items.
 final  Set<String> _priorlyShownRefs;
/// Refs that appeared in any prior-day snapshot for this track.
/// Used by the snapshot path to identify overdue and new items.
@override@JsonKey() Set<String> get priorlyShownRefs {
  if (_priorlyShownRefs is EqualUnmodifiableSetView) return _priorlyShownRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_priorlyShownRefs);
}

/// Default new items per day when no pacing signal is present.
@override@JsonKey() final  int defaultNewItemsPerDay;

/// Create a copy of SchedulerInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerInputCopyWith<_SchedulerInput> get copyWith => __$SchedulerInputCopyWithImpl<_SchedulerInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerInput&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&(identical(other.today, today) || other.today == today)&&const DeepCollectionEquality().equals(other._contentItems, _contentItems)&&const DeepCollectionEquality().equals(other._completions, _completions)&&const DeepCollectionEquality().equals(other._stages, _stages)&&(identical(other.pacePerDay, pacePerDay) || other.pacePerDay == pacePerDay)&&(identical(other.paceGranularity, paceGranularity) || other.paceGranularity == paceGranularity)&&(identical(other.trackStartedAt, trackStartedAt) || other.trackStartedAt == trackStartedAt)&&(identical(other.goalDeadline, goalDeadline) || other.goalDeadline == goalDeadline)&&(identical(other.isStudyDay, isStudyDay) || other.isStudyDay == isStudyDay)&&(identical(other.studyDaysPerWeek, studyDaysPerWeek) || other.studyDaysPerWeek == studyDaysPerWeek)&&(identical(other.studyDaysInDeadlineWindow, studyDaysInDeadlineWindow) || other.studyDaysInDeadlineWindow == studyDaysInDeadlineWindow)&&const DeepCollectionEquality().equals(other._priorlyShownRefs, _priorlyShownRefs)&&(identical(other.defaultNewItemsPerDay, defaultNewItemsPerDay) || other.defaultNewItemsPerDay == defaultNewItemsPerDay));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,trackId,trackLabel,today,const DeepCollectionEquality().hash(_contentItems),const DeepCollectionEquality().hash(_completions),const DeepCollectionEquality().hash(_stages),pacePerDay,paceGranularity,trackStartedAt,goalDeadline,isStudyDay,studyDaysPerWeek,studyDaysInDeadlineWindow,const DeepCollectionEquality().hash(_priorlyShownRefs),defaultNewItemsPerDay);

@override
String toString() {
  return 'SchedulerInput(curriculumId: $curriculumId, trackId: $trackId, trackLabel: $trackLabel, today: $today, contentItems: $contentItems, completions: $completions, stages: $stages, pacePerDay: $pacePerDay, paceGranularity: $paceGranularity, trackStartedAt: $trackStartedAt, goalDeadline: $goalDeadline, isStudyDay: $isStudyDay, studyDaysPerWeek: $studyDaysPerWeek, studyDaysInDeadlineWindow: $studyDaysInDeadlineWindow, priorlyShownRefs: $priorlyShownRefs, defaultNewItemsPerDay: $defaultNewItemsPerDay)';
}


}

/// @nodoc
abstract mixin class _$SchedulerInputCopyWith<$Res> implements $SchedulerInputCopyWith<$Res> {
  factory _$SchedulerInputCopyWith(_SchedulerInput value, $Res Function(_SchedulerInput) _then) = __$SchedulerInputCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculumId, int trackId, String trackLabel, DateTime today, List<SchedulerContentItem> contentItems, List<SchedulerCompletion> completions, List<SchedulerStage> stages, double? pacePerDay, String? paceGranularity, DateTime? trackStartedAt, DateTime? goalDeadline, bool isStudyDay, int studyDaysPerWeek, int? studyDaysInDeadlineWindow, Set<String> priorlyShownRefs, int defaultNewItemsPerDay
});




}
/// @nodoc
class __$SchedulerInputCopyWithImpl<$Res>
    implements _$SchedulerInputCopyWith<$Res> {
  __$SchedulerInputCopyWithImpl(this._self, this._then);

  final _SchedulerInput _self;
  final $Res Function(_SchedulerInput) _then;

/// Create a copy of SchedulerInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? trackId = null,Object? trackLabel = null,Object? today = null,Object? contentItems = null,Object? completions = null,Object? stages = null,Object? pacePerDay = freezed,Object? paceGranularity = freezed,Object? trackStartedAt = freezed,Object? goalDeadline = freezed,Object? isStudyDay = null,Object? studyDaysPerWeek = null,Object? studyDaysInDeadlineWindow = freezed,Object? priorlyShownRefs = null,Object? defaultNewItemsPerDay = null,}) {
  return _then(_SchedulerInput(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,trackLabel: null == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as DateTime,contentItems: null == contentItems ? _self._contentItems : contentItems // ignore: cast_nullable_to_non_nullable
as List<SchedulerContentItem>,completions: null == completions ? _self._completions : completions // ignore: cast_nullable_to_non_nullable
as List<SchedulerCompletion>,stages: null == stages ? _self._stages : stages // ignore: cast_nullable_to_non_nullable
as List<SchedulerStage>,pacePerDay: freezed == pacePerDay ? _self.pacePerDay : pacePerDay // ignore: cast_nullable_to_non_nullable
as double?,paceGranularity: freezed == paceGranularity ? _self.paceGranularity : paceGranularity // ignore: cast_nullable_to_non_nullable
as String?,trackStartedAt: freezed == trackStartedAt ? _self.trackStartedAt : trackStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,goalDeadline: freezed == goalDeadline ? _self.goalDeadline : goalDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,isStudyDay: null == isStudyDay ? _self.isStudyDay : isStudyDay // ignore: cast_nullable_to_non_nullable
as bool,studyDaysPerWeek: null == studyDaysPerWeek ? _self.studyDaysPerWeek : studyDaysPerWeek // ignore: cast_nullable_to_non_nullable
as int,studyDaysInDeadlineWindow: freezed == studyDaysInDeadlineWindow ? _self.studyDaysInDeadlineWindow : studyDaysInDeadlineWindow // ignore: cast_nullable_to_non_nullable
as int?,priorlyShownRefs: null == priorlyShownRefs ? _self._priorlyShownRefs : priorlyShownRefs // ignore: cast_nullable_to_non_nullable
as Set<String>,defaultNewItemsPerDay: null == defaultNewItemsPerDay ? _self.defaultNewItemsPerDay : defaultNewItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
