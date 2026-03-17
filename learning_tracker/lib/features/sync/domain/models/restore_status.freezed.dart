// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'restore_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RestoreStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestoreStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RestoreStatus()';
}


}

/// @nodoc
class $RestoreStatusCopyWith<$Res>  {
$RestoreStatusCopyWith(RestoreStatus _, $Res Function(RestoreStatus) __);
}


/// Adds pattern-matching-related methods to [RestoreStatus].
extension RestoreStatusPatterns on RestoreStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RestoreStatusIdle value)?  idle,TResult Function( RestoreStatusChecking value)?  checking,TResult Function( RestoreStatusRestoring value)?  restoring,TResult Function( RestoreStatusComplete value)?  complete,TResult Function( RestoreStatusError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RestoreStatusIdle() when idle != null:
return idle(_that);case RestoreStatusChecking() when checking != null:
return checking(_that);case RestoreStatusRestoring() when restoring != null:
return restoring(_that);case RestoreStatusComplete() when complete != null:
return complete(_that);case RestoreStatusError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RestoreStatusIdle value)  idle,required TResult Function( RestoreStatusChecking value)  checking,required TResult Function( RestoreStatusRestoring value)  restoring,required TResult Function( RestoreStatusComplete value)  complete,required TResult Function( RestoreStatusError value)  error,}){
final _that = this;
switch (_that) {
case RestoreStatusIdle():
return idle(_that);case RestoreStatusChecking():
return checking(_that);case RestoreStatusRestoring():
return restoring(_that);case RestoreStatusComplete():
return complete(_that);case RestoreStatusError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RestoreStatusIdle value)?  idle,TResult? Function( RestoreStatusChecking value)?  checking,TResult? Function( RestoreStatusRestoring value)?  restoring,TResult? Function( RestoreStatusComplete value)?  complete,TResult? Function( RestoreStatusError value)?  error,}){
final _that = this;
switch (_that) {
case RestoreStatusIdle() when idle != null:
return idle(_that);case RestoreStatusChecking() when checking != null:
return checking(_that);case RestoreStatusRestoring() when restoring != null:
return restoring(_that);case RestoreStatusComplete() when complete != null:
return complete(_that);case RestoreStatusError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  checking,TResult Function( String phase,  int completedSteps,  int totalSteps)?  restoring,TResult Function( int collectionsRestored)?  complete,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RestoreStatusIdle() when idle != null:
return idle();case RestoreStatusChecking() when checking != null:
return checking();case RestoreStatusRestoring() when restoring != null:
return restoring(_that.phase,_that.completedSteps,_that.totalSteps);case RestoreStatusComplete() when complete != null:
return complete(_that.collectionsRestored);case RestoreStatusError() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  checking,required TResult Function( String phase,  int completedSteps,  int totalSteps)  restoring,required TResult Function( int collectionsRestored)  complete,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case RestoreStatusIdle():
return idle();case RestoreStatusChecking():
return checking();case RestoreStatusRestoring():
return restoring(_that.phase,_that.completedSteps,_that.totalSteps);case RestoreStatusComplete():
return complete(_that.collectionsRestored);case RestoreStatusError():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  checking,TResult? Function( String phase,  int completedSteps,  int totalSteps)?  restoring,TResult? Function( int collectionsRestored)?  complete,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case RestoreStatusIdle() when idle != null:
return idle();case RestoreStatusChecking() when checking != null:
return checking();case RestoreStatusRestoring() when restoring != null:
return restoring(_that.phase,_that.completedSteps,_that.totalSteps);case RestoreStatusComplete() when complete != null:
return complete(_that.collectionsRestored);case RestoreStatusError() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class RestoreStatusIdle implements RestoreStatus {
  const RestoreStatusIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestoreStatusIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RestoreStatus.idle()';
}


}




/// @nodoc


class RestoreStatusChecking implements RestoreStatus {
  const RestoreStatusChecking();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestoreStatusChecking);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RestoreStatus.checking()';
}


}




/// @nodoc


class RestoreStatusRestoring implements RestoreStatus {
  const RestoreStatusRestoring({required this.phase, required this.completedSteps, required this.totalSteps});
  

 final  String phase;
 final  int completedSteps;
 final  int totalSteps;

/// Create a copy of RestoreStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestoreStatusRestoringCopyWith<RestoreStatusRestoring> get copyWith => _$RestoreStatusRestoringCopyWithImpl<RestoreStatusRestoring>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestoreStatusRestoring&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.completedSteps, completedSteps) || other.completedSteps == completedSteps)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps));
}


@override
int get hashCode => Object.hash(runtimeType,phase,completedSteps,totalSteps);

@override
String toString() {
  return 'RestoreStatus.restoring(phase: $phase, completedSteps: $completedSteps, totalSteps: $totalSteps)';
}


}

/// @nodoc
abstract mixin class $RestoreStatusRestoringCopyWith<$Res> implements $RestoreStatusCopyWith<$Res> {
  factory $RestoreStatusRestoringCopyWith(RestoreStatusRestoring value, $Res Function(RestoreStatusRestoring) _then) = _$RestoreStatusRestoringCopyWithImpl;
@useResult
$Res call({
 String phase, int completedSteps, int totalSteps
});




}
/// @nodoc
class _$RestoreStatusRestoringCopyWithImpl<$Res>
    implements $RestoreStatusRestoringCopyWith<$Res> {
  _$RestoreStatusRestoringCopyWithImpl(this._self, this._then);

  final RestoreStatusRestoring _self;
  final $Res Function(RestoreStatusRestoring) _then;

/// Create a copy of RestoreStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? completedSteps = null,Object? totalSteps = null,}) {
  return _then(RestoreStatusRestoring(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as String,completedSteps: null == completedSteps ? _self.completedSteps : completedSteps // ignore: cast_nullable_to_non_nullable
as int,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class RestoreStatusComplete implements RestoreStatus {
  const RestoreStatusComplete({required this.collectionsRestored});
  

 final  int collectionsRestored;

/// Create a copy of RestoreStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestoreStatusCompleteCopyWith<RestoreStatusComplete> get copyWith => _$RestoreStatusCompleteCopyWithImpl<RestoreStatusComplete>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestoreStatusComplete&&(identical(other.collectionsRestored, collectionsRestored) || other.collectionsRestored == collectionsRestored));
}


@override
int get hashCode => Object.hash(runtimeType,collectionsRestored);

@override
String toString() {
  return 'RestoreStatus.complete(collectionsRestored: $collectionsRestored)';
}


}

/// @nodoc
abstract mixin class $RestoreStatusCompleteCopyWith<$Res> implements $RestoreStatusCopyWith<$Res> {
  factory $RestoreStatusCompleteCopyWith(RestoreStatusComplete value, $Res Function(RestoreStatusComplete) _then) = _$RestoreStatusCompleteCopyWithImpl;
@useResult
$Res call({
 int collectionsRestored
});




}
/// @nodoc
class _$RestoreStatusCompleteCopyWithImpl<$Res>
    implements $RestoreStatusCompleteCopyWith<$Res> {
  _$RestoreStatusCompleteCopyWithImpl(this._self, this._then);

  final RestoreStatusComplete _self;
  final $Res Function(RestoreStatusComplete) _then;

/// Create a copy of RestoreStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? collectionsRestored = null,}) {
  return _then(RestoreStatusComplete(
collectionsRestored: null == collectionsRestored ? _self.collectionsRestored : collectionsRestored // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class RestoreStatusError implements RestoreStatus {
  const RestoreStatusError({required this.message});
  

 final  String message;

/// Create a copy of RestoreStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestoreStatusErrorCopyWith<RestoreStatusError> get copyWith => _$RestoreStatusErrorCopyWithImpl<RestoreStatusError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestoreStatusError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'RestoreStatus.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $RestoreStatusErrorCopyWith<$Res> implements $RestoreStatusCopyWith<$Res> {
  factory $RestoreStatusErrorCopyWith(RestoreStatusError value, $Res Function(RestoreStatusError) _then) = _$RestoreStatusErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$RestoreStatusErrorCopyWithImpl<$Res>
    implements $RestoreStatusErrorCopyWith<$Res> {
  _$RestoreStatusErrorCopyWithImpl(this._self, this._then);

  final RestoreStatusError _self;
  final $Res Function(RestoreStatusError) _then;

/// Create a copy of RestoreStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(RestoreStatusError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
