// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_analysis.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchedulerAnalysis {

/// Completion map: sefariaRef → { stageOrder → completedAt }.
 Map<String, Map<int, DateTime>> get completionMap;/// Stages sorted ascending by stageOrder.
 List<SchedulerStage> get sortedStages;/// Content items sorted in learning order (custom or default).
 List<SchedulerContentItem> get orderedItems;/// Ordered sefaria refs derived from [orderedItems].
 List<String> get orderedRefs;/// Refs that have never been started (no first-stage completion and
/// not in [priorlyShownRefs]).  Used by new-learning task assembly.
 List<String> get newLearningRefs;/// Number of new leaf items (or coarse units) to assign today.
 int get newItemsPerDay;/// Total chazara tasks already identified (overdue + scheduled).
/// Strategies use this to cap or balance new-learning output.
 int get chazaraLoadCount;/// True when today is a study day (new learning is permitted).
 bool get isStudyDay;/// The first-stage stageOrder value for quick access.
 int get firstStageOrder;
/// Create a copy of SchedulerAnalysis
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerAnalysisCopyWith<SchedulerAnalysis> get copyWith => _$SchedulerAnalysisCopyWithImpl<SchedulerAnalysis>(this as SchedulerAnalysis, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerAnalysis&&const DeepCollectionEquality().equals(other.completionMap, completionMap)&&const DeepCollectionEquality().equals(other.sortedStages, sortedStages)&&const DeepCollectionEquality().equals(other.orderedItems, orderedItems)&&const DeepCollectionEquality().equals(other.orderedRefs, orderedRefs)&&const DeepCollectionEquality().equals(other.newLearningRefs, newLearningRefs)&&(identical(other.newItemsPerDay, newItemsPerDay) || other.newItemsPerDay == newItemsPerDay)&&(identical(other.chazaraLoadCount, chazaraLoadCount) || other.chazaraLoadCount == chazaraLoadCount)&&(identical(other.isStudyDay, isStudyDay) || other.isStudyDay == isStudyDay)&&(identical(other.firstStageOrder, firstStageOrder) || other.firstStageOrder == firstStageOrder));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(completionMap),const DeepCollectionEquality().hash(sortedStages),const DeepCollectionEquality().hash(orderedItems),const DeepCollectionEquality().hash(orderedRefs),const DeepCollectionEquality().hash(newLearningRefs),newItemsPerDay,chazaraLoadCount,isStudyDay,firstStageOrder);

@override
String toString() {
  return 'SchedulerAnalysis(completionMap: $completionMap, sortedStages: $sortedStages, orderedItems: $orderedItems, orderedRefs: $orderedRefs, newLearningRefs: $newLearningRefs, newItemsPerDay: $newItemsPerDay, chazaraLoadCount: $chazaraLoadCount, isStudyDay: $isStudyDay, firstStageOrder: $firstStageOrder)';
}


}

/// @nodoc
abstract mixin class $SchedulerAnalysisCopyWith<$Res>  {
  factory $SchedulerAnalysisCopyWith(SchedulerAnalysis value, $Res Function(SchedulerAnalysis) _then) = _$SchedulerAnalysisCopyWithImpl;
@useResult
$Res call({
 Map<String, Map<int, DateTime>> completionMap, List<SchedulerStage> sortedStages, List<SchedulerContentItem> orderedItems, List<String> orderedRefs, List<String> newLearningRefs, int newItemsPerDay, int chazaraLoadCount, bool isStudyDay, int firstStageOrder
});




}
/// @nodoc
class _$SchedulerAnalysisCopyWithImpl<$Res>
    implements $SchedulerAnalysisCopyWith<$Res> {
  _$SchedulerAnalysisCopyWithImpl(this._self, this._then);

  final SchedulerAnalysis _self;
  final $Res Function(SchedulerAnalysis) _then;

/// Create a copy of SchedulerAnalysis
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? completionMap = null,Object? sortedStages = null,Object? orderedItems = null,Object? orderedRefs = null,Object? newLearningRefs = null,Object? newItemsPerDay = null,Object? chazaraLoadCount = null,Object? isStudyDay = null,Object? firstStageOrder = null,}) {
  return _then(_self.copyWith(
completionMap: null == completionMap ? _self.completionMap : completionMap // ignore: cast_nullable_to_non_nullable
as Map<String, Map<int, DateTime>>,sortedStages: null == sortedStages ? _self.sortedStages : sortedStages // ignore: cast_nullable_to_non_nullable
as List<SchedulerStage>,orderedItems: null == orderedItems ? _self.orderedItems : orderedItems // ignore: cast_nullable_to_non_nullable
as List<SchedulerContentItem>,orderedRefs: null == orderedRefs ? _self.orderedRefs : orderedRefs // ignore: cast_nullable_to_non_nullable
as List<String>,newLearningRefs: null == newLearningRefs ? _self.newLearningRefs : newLearningRefs // ignore: cast_nullable_to_non_nullable
as List<String>,newItemsPerDay: null == newItemsPerDay ? _self.newItemsPerDay : newItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,chazaraLoadCount: null == chazaraLoadCount ? _self.chazaraLoadCount : chazaraLoadCount // ignore: cast_nullable_to_non_nullable
as int,isStudyDay: null == isStudyDay ? _self.isStudyDay : isStudyDay // ignore: cast_nullable_to_non_nullable
as bool,firstStageOrder: null == firstStageOrder ? _self.firstStageOrder : firstStageOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerAnalysis].
extension SchedulerAnalysisPatterns on SchedulerAnalysis {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerAnalysis value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerAnalysis() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerAnalysis value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerAnalysis():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerAnalysis value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerAnalysis() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, Map<int, DateTime>> completionMap,  List<SchedulerStage> sortedStages,  List<SchedulerContentItem> orderedItems,  List<String> orderedRefs,  List<String> newLearningRefs,  int newItemsPerDay,  int chazaraLoadCount,  bool isStudyDay,  int firstStageOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerAnalysis() when $default != null:
return $default(_that.completionMap,_that.sortedStages,_that.orderedItems,_that.orderedRefs,_that.newLearningRefs,_that.newItemsPerDay,_that.chazaraLoadCount,_that.isStudyDay,_that.firstStageOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, Map<int, DateTime>> completionMap,  List<SchedulerStage> sortedStages,  List<SchedulerContentItem> orderedItems,  List<String> orderedRefs,  List<String> newLearningRefs,  int newItemsPerDay,  int chazaraLoadCount,  bool isStudyDay,  int firstStageOrder)  $default,) {final _that = this;
switch (_that) {
case _SchedulerAnalysis():
return $default(_that.completionMap,_that.sortedStages,_that.orderedItems,_that.orderedRefs,_that.newLearningRefs,_that.newItemsPerDay,_that.chazaraLoadCount,_that.isStudyDay,_that.firstStageOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, Map<int, DateTime>> completionMap,  List<SchedulerStage> sortedStages,  List<SchedulerContentItem> orderedItems,  List<String> orderedRefs,  List<String> newLearningRefs,  int newItemsPerDay,  int chazaraLoadCount,  bool isStudyDay,  int firstStageOrder)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerAnalysis() when $default != null:
return $default(_that.completionMap,_that.sortedStages,_that.orderedItems,_that.orderedRefs,_that.newLearningRefs,_that.newItemsPerDay,_that.chazaraLoadCount,_that.isStudyDay,_that.firstStageOrder);case _:
  return null;

}
}

}

/// @nodoc


class _SchedulerAnalysis implements SchedulerAnalysis {
  const _SchedulerAnalysis({required final  Map<String, Map<int, DateTime>> completionMap, required final  List<SchedulerStage> sortedStages, required final  List<SchedulerContentItem> orderedItems, required final  List<String> orderedRefs, required final  List<String> newLearningRefs, required this.newItemsPerDay, required this.chazaraLoadCount, required this.isStudyDay, required this.firstStageOrder}): _completionMap = completionMap,_sortedStages = sortedStages,_orderedItems = orderedItems,_orderedRefs = orderedRefs,_newLearningRefs = newLearningRefs;
  

/// Completion map: sefariaRef → { stageOrder → completedAt }.
 final  Map<String, Map<int, DateTime>> _completionMap;
/// Completion map: sefariaRef → { stageOrder → completedAt }.
@override Map<String, Map<int, DateTime>> get completionMap {
  if (_completionMap is EqualUnmodifiableMapView) return _completionMap;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_completionMap);
}

/// Stages sorted ascending by stageOrder.
 final  List<SchedulerStage> _sortedStages;
/// Stages sorted ascending by stageOrder.
@override List<SchedulerStage> get sortedStages {
  if (_sortedStages is EqualUnmodifiableListView) return _sortedStages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sortedStages);
}

/// Content items sorted in learning order (custom or default).
 final  List<SchedulerContentItem> _orderedItems;
/// Content items sorted in learning order (custom or default).
@override List<SchedulerContentItem> get orderedItems {
  if (_orderedItems is EqualUnmodifiableListView) return _orderedItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_orderedItems);
}

/// Ordered sefaria refs derived from [orderedItems].
 final  List<String> _orderedRefs;
/// Ordered sefaria refs derived from [orderedItems].
@override List<String> get orderedRefs {
  if (_orderedRefs is EqualUnmodifiableListView) return _orderedRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_orderedRefs);
}

/// Refs that have never been started (no first-stage completion and
/// not in [priorlyShownRefs]).  Used by new-learning task assembly.
 final  List<String> _newLearningRefs;
/// Refs that have never been started (no first-stage completion and
/// not in [priorlyShownRefs]).  Used by new-learning task assembly.
@override List<String> get newLearningRefs {
  if (_newLearningRefs is EqualUnmodifiableListView) return _newLearningRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_newLearningRefs);
}

/// Number of new leaf items (or coarse units) to assign today.
@override final  int newItemsPerDay;
/// Total chazara tasks already identified (overdue + scheduled).
/// Strategies use this to cap or balance new-learning output.
@override final  int chazaraLoadCount;
/// True when today is a study day (new learning is permitted).
@override final  bool isStudyDay;
/// The first-stage stageOrder value for quick access.
@override final  int firstStageOrder;

/// Create a copy of SchedulerAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerAnalysisCopyWith<_SchedulerAnalysis> get copyWith => __$SchedulerAnalysisCopyWithImpl<_SchedulerAnalysis>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerAnalysis&&const DeepCollectionEquality().equals(other._completionMap, _completionMap)&&const DeepCollectionEquality().equals(other._sortedStages, _sortedStages)&&const DeepCollectionEquality().equals(other._orderedItems, _orderedItems)&&const DeepCollectionEquality().equals(other._orderedRefs, _orderedRefs)&&const DeepCollectionEquality().equals(other._newLearningRefs, _newLearningRefs)&&(identical(other.newItemsPerDay, newItemsPerDay) || other.newItemsPerDay == newItemsPerDay)&&(identical(other.chazaraLoadCount, chazaraLoadCount) || other.chazaraLoadCount == chazaraLoadCount)&&(identical(other.isStudyDay, isStudyDay) || other.isStudyDay == isStudyDay)&&(identical(other.firstStageOrder, firstStageOrder) || other.firstStageOrder == firstStageOrder));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_completionMap),const DeepCollectionEquality().hash(_sortedStages),const DeepCollectionEquality().hash(_orderedItems),const DeepCollectionEquality().hash(_orderedRefs),const DeepCollectionEquality().hash(_newLearningRefs),newItemsPerDay,chazaraLoadCount,isStudyDay,firstStageOrder);

@override
String toString() {
  return 'SchedulerAnalysis(completionMap: $completionMap, sortedStages: $sortedStages, orderedItems: $orderedItems, orderedRefs: $orderedRefs, newLearningRefs: $newLearningRefs, newItemsPerDay: $newItemsPerDay, chazaraLoadCount: $chazaraLoadCount, isStudyDay: $isStudyDay, firstStageOrder: $firstStageOrder)';
}


}

/// @nodoc
abstract mixin class _$SchedulerAnalysisCopyWith<$Res> implements $SchedulerAnalysisCopyWith<$Res> {
  factory _$SchedulerAnalysisCopyWith(_SchedulerAnalysis value, $Res Function(_SchedulerAnalysis) _then) = __$SchedulerAnalysisCopyWithImpl;
@override @useResult
$Res call({
 Map<String, Map<int, DateTime>> completionMap, List<SchedulerStage> sortedStages, List<SchedulerContentItem> orderedItems, List<String> orderedRefs, List<String> newLearningRefs, int newItemsPerDay, int chazaraLoadCount, bool isStudyDay, int firstStageOrder
});




}
/// @nodoc
class __$SchedulerAnalysisCopyWithImpl<$Res>
    implements _$SchedulerAnalysisCopyWith<$Res> {
  __$SchedulerAnalysisCopyWithImpl(this._self, this._then);

  final _SchedulerAnalysis _self;
  final $Res Function(_SchedulerAnalysis) _then;

/// Create a copy of SchedulerAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? completionMap = null,Object? sortedStages = null,Object? orderedItems = null,Object? orderedRefs = null,Object? newLearningRefs = null,Object? newItemsPerDay = null,Object? chazaraLoadCount = null,Object? isStudyDay = null,Object? firstStageOrder = null,}) {
  return _then(_SchedulerAnalysis(
completionMap: null == completionMap ? _self._completionMap : completionMap // ignore: cast_nullable_to_non_nullable
as Map<String, Map<int, DateTime>>,sortedStages: null == sortedStages ? _self._sortedStages : sortedStages // ignore: cast_nullable_to_non_nullable
as List<SchedulerStage>,orderedItems: null == orderedItems ? _self._orderedItems : orderedItems // ignore: cast_nullable_to_non_nullable
as List<SchedulerContentItem>,orderedRefs: null == orderedRefs ? _self._orderedRefs : orderedRefs // ignore: cast_nullable_to_non_nullable
as List<String>,newLearningRefs: null == newLearningRefs ? _self._newLearningRefs : newLearningRefs // ignore: cast_nullable_to_non_nullable
as List<String>,newItemsPerDay: null == newItemsPerDay ? _self.newItemsPerDay : newItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,chazaraLoadCount: null == chazaraLoadCount ? _self.chazaraLoadCount : chazaraLoadCount // ignore: cast_nullable_to_non_nullable
as int,isStudyDay: null == isStudyDay ? _self.isStudyDay : isStudyDay // ignore: cast_nullable_to_non_nullable
as bool,firstStageOrder: null == firstStageOrder ? _self.firstStageOrder : firstStageOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
