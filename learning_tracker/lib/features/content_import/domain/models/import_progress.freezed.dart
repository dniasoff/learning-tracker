// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'import_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImportProgress {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportProgress);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ImportProgress()';
}


}

/// @nodoc
class $ImportProgressCopyWith<$Res>  {
$ImportProgressCopyWith(ImportProgress _, $Res Function(ImportProgress) __);
}


/// Adds pattern-matching-related methods to [ImportProgress].
extension ImportProgressPatterns on ImportProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Idle value)?  idle,TResult Function( _Fetching value)?  fetching,TResult Function( _Parsing value)?  parsing,TResult Function( _Storing value)?  storing,TResult Function( _Completed value)?  completed,TResult Function( _Error value)?  error,TResult Function( _Cancelled value)?  cancelled,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle(_that);case _Fetching() when fetching != null:
return fetching(_that);case _Parsing() when parsing != null:
return parsing(_that);case _Storing() when storing != null:
return storing(_that);case _Completed() when completed != null:
return completed(_that);case _Error() when error != null:
return error(_that);case _Cancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Idle value)  idle,required TResult Function( _Fetching value)  fetching,required TResult Function( _Parsing value)  parsing,required TResult Function( _Storing value)  storing,required TResult Function( _Completed value)  completed,required TResult Function( _Error value)  error,required TResult Function( _Cancelled value)  cancelled,}){
final _that = this;
switch (_that) {
case _Idle():
return idle(_that);case _Fetching():
return fetching(_that);case _Parsing():
return parsing(_that);case _Storing():
return storing(_that);case _Completed():
return completed(_that);case _Error():
return error(_that);case _Cancelled():
return cancelled(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Idle value)?  idle,TResult? Function( _Fetching value)?  fetching,TResult? Function( _Parsing value)?  parsing,TResult? Function( _Storing value)?  storing,TResult? Function( _Completed value)?  completed,TResult? Function( _Error value)?  error,TResult? Function( _Cancelled value)?  cancelled,}){
final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle(_that);case _Fetching() when fetching != null:
return fetching(_that);case _Parsing() when parsing != null:
return parsing(_that);case _Storing() when storing != null:
return storing(_that);case _Completed() when completed != null:
return completed(_that);case _Error() when error != null:
return error(_that);case _Cancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( String curriculumId)?  fetching,TResult Function( String curriculumId,  int itemsFetched)?  parsing,TResult Function( String curriculumId,  int totalItems,  int storedItems)?  storing,TResult Function( String curriculumId,  int totalItems)?  completed,TResult Function( String curriculumId,  String message,  String? errorCode)?  error,TResult Function( String curriculumId)?  cancelled,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle();case _Fetching() when fetching != null:
return fetching(_that.curriculumId);case _Parsing() when parsing != null:
return parsing(_that.curriculumId,_that.itemsFetched);case _Storing() when storing != null:
return storing(_that.curriculumId,_that.totalItems,_that.storedItems);case _Completed() when completed != null:
return completed(_that.curriculumId,_that.totalItems);case _Error() when error != null:
return error(_that.curriculumId,_that.message,_that.errorCode);case _Cancelled() when cancelled != null:
return cancelled(_that.curriculumId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( String curriculumId)  fetching,required TResult Function( String curriculumId,  int itemsFetched)  parsing,required TResult Function( String curriculumId,  int totalItems,  int storedItems)  storing,required TResult Function( String curriculumId,  int totalItems)  completed,required TResult Function( String curriculumId,  String message,  String? errorCode)  error,required TResult Function( String curriculumId)  cancelled,}) {final _that = this;
switch (_that) {
case _Idle():
return idle();case _Fetching():
return fetching(_that.curriculumId);case _Parsing():
return parsing(_that.curriculumId,_that.itemsFetched);case _Storing():
return storing(_that.curriculumId,_that.totalItems,_that.storedItems);case _Completed():
return completed(_that.curriculumId,_that.totalItems);case _Error():
return error(_that.curriculumId,_that.message,_that.errorCode);case _Cancelled():
return cancelled(_that.curriculumId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( String curriculumId)?  fetching,TResult? Function( String curriculumId,  int itemsFetched)?  parsing,TResult? Function( String curriculumId,  int totalItems,  int storedItems)?  storing,TResult? Function( String curriculumId,  int totalItems)?  completed,TResult? Function( String curriculumId,  String message,  String? errorCode)?  error,TResult? Function( String curriculumId)?  cancelled,}) {final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle();case _Fetching() when fetching != null:
return fetching(_that.curriculumId);case _Parsing() when parsing != null:
return parsing(_that.curriculumId,_that.itemsFetched);case _Storing() when storing != null:
return storing(_that.curriculumId,_that.totalItems,_that.storedItems);case _Completed() when completed != null:
return completed(_that.curriculumId,_that.totalItems);case _Error() when error != null:
return error(_that.curriculumId,_that.message,_that.errorCode);case _Cancelled() when cancelled != null:
return cancelled(_that.curriculumId);case _:
  return null;

}
}

}

/// @nodoc


class _Idle implements ImportProgress {
  const _Idle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Idle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ImportProgress.idle()';
}


}




/// @nodoc


class _Fetching implements ImportProgress {
  const _Fetching({required this.curriculumId});
  

 final  String curriculumId;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FetchingCopyWith<_Fetching> get copyWith => __$FetchingCopyWithImpl<_Fetching>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Fetching&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId);

@override
String toString() {
  return 'ImportProgress.fetching(curriculumId: $curriculumId)';
}


}

/// @nodoc
abstract mixin class _$FetchingCopyWith<$Res> implements $ImportProgressCopyWith<$Res> {
  factory _$FetchingCopyWith(_Fetching value, $Res Function(_Fetching) _then) = __$FetchingCopyWithImpl;
@useResult
$Res call({
 String curriculumId
});




}
/// @nodoc
class __$FetchingCopyWithImpl<$Res>
    implements _$FetchingCopyWith<$Res> {
  __$FetchingCopyWithImpl(this._self, this._then);

  final _Fetching _self;
  final $Res Function(_Fetching) _then;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,}) {
  return _then(_Fetching(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _Parsing implements ImportProgress {
  const _Parsing({required this.curriculumId, required this.itemsFetched});
  

 final  String curriculumId;
 final  int itemsFetched;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParsingCopyWith<_Parsing> get copyWith => __$ParsingCopyWithImpl<_Parsing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Parsing&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.itemsFetched, itemsFetched) || other.itemsFetched == itemsFetched));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,itemsFetched);

@override
String toString() {
  return 'ImportProgress.parsing(curriculumId: $curriculumId, itemsFetched: $itemsFetched)';
}


}

/// @nodoc
abstract mixin class _$ParsingCopyWith<$Res> implements $ImportProgressCopyWith<$Res> {
  factory _$ParsingCopyWith(_Parsing value, $Res Function(_Parsing) _then) = __$ParsingCopyWithImpl;
@useResult
$Res call({
 String curriculumId, int itemsFetched
});




}
/// @nodoc
class __$ParsingCopyWithImpl<$Res>
    implements _$ParsingCopyWith<$Res> {
  __$ParsingCopyWithImpl(this._self, this._then);

  final _Parsing _self;
  final $Res Function(_Parsing) _then;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? itemsFetched = null,}) {
  return _then(_Parsing(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,itemsFetched: null == itemsFetched ? _self.itemsFetched : itemsFetched // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _Storing implements ImportProgress {
  const _Storing({required this.curriculumId, required this.totalItems, required this.storedItems});
  

 final  String curriculumId;
 final  int totalItems;
 final  int storedItems;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoringCopyWith<_Storing> get copyWith => __$StoringCopyWithImpl<_Storing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Storing&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems)&&(identical(other.storedItems, storedItems) || other.storedItems == storedItems));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,totalItems,storedItems);

@override
String toString() {
  return 'ImportProgress.storing(curriculumId: $curriculumId, totalItems: $totalItems, storedItems: $storedItems)';
}


}

/// @nodoc
abstract mixin class _$StoringCopyWith<$Res> implements $ImportProgressCopyWith<$Res> {
  factory _$StoringCopyWith(_Storing value, $Res Function(_Storing) _then) = __$StoringCopyWithImpl;
@useResult
$Res call({
 String curriculumId, int totalItems, int storedItems
});




}
/// @nodoc
class __$StoringCopyWithImpl<$Res>
    implements _$StoringCopyWith<$Res> {
  __$StoringCopyWithImpl(this._self, this._then);

  final _Storing _self;
  final $Res Function(_Storing) _then;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? totalItems = null,Object? storedItems = null,}) {
  return _then(_Storing(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,storedItems: null == storedItems ? _self.storedItems : storedItems // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _Completed implements ImportProgress {
  const _Completed({required this.curriculumId, required this.totalItems});
  

 final  String curriculumId;
 final  int totalItems;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompletedCopyWith<_Completed> get copyWith => __$CompletedCopyWithImpl<_Completed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Completed&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,totalItems);

@override
String toString() {
  return 'ImportProgress.completed(curriculumId: $curriculumId, totalItems: $totalItems)';
}


}

/// @nodoc
abstract mixin class _$CompletedCopyWith<$Res> implements $ImportProgressCopyWith<$Res> {
  factory _$CompletedCopyWith(_Completed value, $Res Function(_Completed) _then) = __$CompletedCopyWithImpl;
@useResult
$Res call({
 String curriculumId, int totalItems
});




}
/// @nodoc
class __$CompletedCopyWithImpl<$Res>
    implements _$CompletedCopyWith<$Res> {
  __$CompletedCopyWithImpl(this._self, this._then);

  final _Completed _self;
  final $Res Function(_Completed) _then;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? totalItems = null,}) {
  return _then(_Completed(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _Error implements ImportProgress {
  const _Error({required this.curriculumId, required this.message, this.errorCode});
  

 final  String curriculumId;
 final  String message;
 final  String? errorCode;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorCopyWith<_Error> get copyWith => __$ErrorCopyWithImpl<_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Error&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.message, message) || other.message == message)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,message,errorCode);

@override
String toString() {
  return 'ImportProgress.error(curriculumId: $curriculumId, message: $message, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $ImportProgressCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) = __$ErrorCopyWithImpl;
@useResult
$Res call({
 String curriculumId, String message, String? errorCode
});




}
/// @nodoc
class __$ErrorCopyWithImpl<$Res>
    implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? message = null,Object? errorCode = freezed,}) {
  return _then(_Error(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class _Cancelled implements ImportProgress {
  const _Cancelled({required this.curriculumId});
  

 final  String curriculumId;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CancelledCopyWith<_Cancelled> get copyWith => __$CancelledCopyWithImpl<_Cancelled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cancelled&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId);

@override
String toString() {
  return 'ImportProgress.cancelled(curriculumId: $curriculumId)';
}


}

/// @nodoc
abstract mixin class _$CancelledCopyWith<$Res> implements $ImportProgressCopyWith<$Res> {
  factory _$CancelledCopyWith(_Cancelled value, $Res Function(_Cancelled) _then) = __$CancelledCopyWithImpl;
@useResult
$Res call({
 String curriculumId
});




}
/// @nodoc
class __$CancelledCopyWithImpl<$Res>
    implements _$CancelledCopyWith<$Res> {
  __$CancelledCopyWithImpl(this._self, this._then);

  final _Cancelled _self;
  final $Res Function(_Cancelled) _then;

/// Create a copy of ImportProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,}) {
  return _then(_Cancelled(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
