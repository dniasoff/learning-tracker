// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_assembly.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TaskAssembly {

/// Tasks sorted by priority (overdueProgram → todayProgram →
/// overdueChazara → scheduledChazara → newLearning).
 List<DailyTask> get tasks;/// Human-readable label for the strategy that produced this assembly.
 String get strategyName;
/// Create a copy of TaskAssembly
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskAssemblyCopyWith<TaskAssembly> get copyWith => _$TaskAssemblyCopyWithImpl<TaskAssembly>(this as TaskAssembly, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskAssembly&&const DeepCollectionEquality().equals(other.tasks, tasks)&&(identical(other.strategyName, strategyName) || other.strategyName == strategyName));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tasks),strategyName);

@override
String toString() {
  return 'TaskAssembly(tasks: $tasks, strategyName: $strategyName)';
}


}

/// @nodoc
abstract mixin class $TaskAssemblyCopyWith<$Res>  {
  factory $TaskAssemblyCopyWith(TaskAssembly value, $Res Function(TaskAssembly) _then) = _$TaskAssemblyCopyWithImpl;
@useResult
$Res call({
 List<DailyTask> tasks, String strategyName
});




}
/// @nodoc
class _$TaskAssemblyCopyWithImpl<$Res>
    implements $TaskAssemblyCopyWith<$Res> {
  _$TaskAssemblyCopyWithImpl(this._self, this._then);

  final TaskAssembly _self;
  final $Res Function(TaskAssembly) _then;

/// Create a copy of TaskAssembly
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tasks = null,Object? strategyName = null,}) {
  return _then(_self.copyWith(
tasks: null == tasks ? _self.tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<DailyTask>,strategyName: null == strategyName ? _self.strategyName : strategyName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskAssembly].
extension TaskAssemblyPatterns on TaskAssembly {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskAssembly value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskAssembly() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskAssembly value)  $default,){
final _that = this;
switch (_that) {
case _TaskAssembly():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskAssembly value)?  $default,){
final _that = this;
switch (_that) {
case _TaskAssembly() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DailyTask> tasks,  String strategyName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskAssembly() when $default != null:
return $default(_that.tasks,_that.strategyName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DailyTask> tasks,  String strategyName)  $default,) {final _that = this;
switch (_that) {
case _TaskAssembly():
return $default(_that.tasks,_that.strategyName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DailyTask> tasks,  String strategyName)?  $default,) {final _that = this;
switch (_that) {
case _TaskAssembly() when $default != null:
return $default(_that.tasks,_that.strategyName);case _:
  return null;

}
}

}

/// @nodoc


class _TaskAssembly extends TaskAssembly {
  const _TaskAssembly({required final  List<DailyTask> tasks, required this.strategyName}): _tasks = tasks,super._();
  

/// Tasks sorted by priority (overdueProgram → todayProgram →
/// overdueChazara → scheduledChazara → newLearning).
 final  List<DailyTask> _tasks;
/// Tasks sorted by priority (overdueProgram → todayProgram →
/// overdueChazara → scheduledChazara → newLearning).
@override List<DailyTask> get tasks {
  if (_tasks is EqualUnmodifiableListView) return _tasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tasks);
}

/// Human-readable label for the strategy that produced this assembly.
@override final  String strategyName;

/// Create a copy of TaskAssembly
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskAssemblyCopyWith<_TaskAssembly> get copyWith => __$TaskAssemblyCopyWithImpl<_TaskAssembly>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskAssembly&&const DeepCollectionEquality().equals(other._tasks, _tasks)&&(identical(other.strategyName, strategyName) || other.strategyName == strategyName));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tasks),strategyName);

@override
String toString() {
  return 'TaskAssembly(tasks: $tasks, strategyName: $strategyName)';
}


}

/// @nodoc
abstract mixin class _$TaskAssemblyCopyWith<$Res> implements $TaskAssemblyCopyWith<$Res> {
  factory _$TaskAssemblyCopyWith(_TaskAssembly value, $Res Function(_TaskAssembly) _then) = __$TaskAssemblyCopyWithImpl;
@override @useResult
$Res call({
 List<DailyTask> tasks, String strategyName
});




}
/// @nodoc
class __$TaskAssemblyCopyWithImpl<$Res>
    implements _$TaskAssemblyCopyWith<$Res> {
  __$TaskAssemblyCopyWithImpl(this._self, this._then);

  final _TaskAssembly _self;
  final $Res Function(_TaskAssembly) _then;

/// Create a copy of TaskAssembly
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tasks = null,Object? strategyName = null,}) {
  return _then(_TaskAssembly(
tasks: null == tasks ? _self._tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<DailyTask>,strategyName: null == strategyName ? _self.strategyName : strategyName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
