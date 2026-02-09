// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'completion_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CompletionRequest {

 String get curriculumId; int get contentItemId; int get stageId; String get trackType;
/// Create a copy of CompletionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompletionRequestCopyWith<CompletionRequest> get copyWith => _$CompletionRequestCopyWithImpl<CompletionRequest>(this as CompletionRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompletionRequest&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.contentItemId, contentItemId) || other.contentItemId == contentItemId)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.trackType, trackType) || other.trackType == trackType));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,contentItemId,stageId,trackType);

@override
String toString() {
  return 'CompletionRequest(curriculumId: $curriculumId, contentItemId: $contentItemId, stageId: $stageId, trackType: $trackType)';
}


}

/// @nodoc
abstract mixin class $CompletionRequestCopyWith<$Res>  {
  factory $CompletionRequestCopyWith(CompletionRequest value, $Res Function(CompletionRequest) _then) = _$CompletionRequestCopyWithImpl;
@useResult
$Res call({
 String curriculumId, int contentItemId, int stageId, String trackType
});




}
/// @nodoc
class _$CompletionRequestCopyWithImpl<$Res>
    implements $CompletionRequestCopyWith<$Res> {
  _$CompletionRequestCopyWithImpl(this._self, this._then);

  final CompletionRequest _self;
  final $Res Function(CompletionRequest) _then;

/// Create a copy of CompletionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? contentItemId = null,Object? stageId = null,Object? trackType = null,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,contentItemId: null == contentItemId ? _self.contentItemId : contentItemId // ignore: cast_nullable_to_non_nullable
as int,stageId: null == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CompletionRequest].
extension CompletionRequestPatterns on CompletionRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompletionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompletionRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompletionRequest value)  $default,){
final _that = this;
switch (_that) {
case _CompletionRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompletionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CompletionRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String curriculumId,  int contentItemId,  int stageId,  String trackType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompletionRequest() when $default != null:
return $default(_that.curriculumId,_that.contentItemId,_that.stageId,_that.trackType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String curriculumId,  int contentItemId,  int stageId,  String trackType)  $default,) {final _that = this;
switch (_that) {
case _CompletionRequest():
return $default(_that.curriculumId,_that.contentItemId,_that.stageId,_that.trackType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String curriculumId,  int contentItemId,  int stageId,  String trackType)?  $default,) {final _that = this;
switch (_that) {
case _CompletionRequest() when $default != null:
return $default(_that.curriculumId,_that.contentItemId,_that.stageId,_that.trackType);case _:
  return null;

}
}

}

/// @nodoc


class _CompletionRequest implements CompletionRequest {
  const _CompletionRequest({required this.curriculumId, required this.contentItemId, required this.stageId, required this.trackType});
  

@override final  String curriculumId;
@override final  int contentItemId;
@override final  int stageId;
@override final  String trackType;

/// Create a copy of CompletionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompletionRequestCopyWith<_CompletionRequest> get copyWith => __$CompletionRequestCopyWithImpl<_CompletionRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompletionRequest&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.contentItemId, contentItemId) || other.contentItemId == contentItemId)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.trackType, trackType) || other.trackType == trackType));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,contentItemId,stageId,trackType);

@override
String toString() {
  return 'CompletionRequest(curriculumId: $curriculumId, contentItemId: $contentItemId, stageId: $stageId, trackType: $trackType)';
}


}

/// @nodoc
abstract mixin class _$CompletionRequestCopyWith<$Res> implements $CompletionRequestCopyWith<$Res> {
  factory _$CompletionRequestCopyWith(_CompletionRequest value, $Res Function(_CompletionRequest) _then) = __$CompletionRequestCopyWithImpl;
@override @useResult
$Res call({
 String curriculumId, int contentItemId, int stageId, String trackType
});




}
/// @nodoc
class __$CompletionRequestCopyWithImpl<$Res>
    implements _$CompletionRequestCopyWith<$Res> {
  __$CompletionRequestCopyWithImpl(this._self, this._then);

  final _CompletionRequest _self;
  final $Res Function(_CompletionRequest) _then;

/// Create a copy of CompletionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? contentItemId = null,Object? stageId = null,Object? trackType = null,}) {
  return _then(_CompletionRequest(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,contentItemId: null == contentItemId ? _self.contentItemId : contentItemId // ignore: cast_nullable_to_non_nullable
as int,stageId: null == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$BulkCompletionRequest {

 String get curriculumId; List<int> get contentItemIds; int get stageId; String get trackType;
/// Create a copy of BulkCompletionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BulkCompletionRequestCopyWith<BulkCompletionRequest> get copyWith => _$BulkCompletionRequestCopyWithImpl<BulkCompletionRequest>(this as BulkCompletionRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BulkCompletionRequest&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&const DeepCollectionEquality().equals(other.contentItemIds, contentItemIds)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.trackType, trackType) || other.trackType == trackType));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,const DeepCollectionEquality().hash(contentItemIds),stageId,trackType);

@override
String toString() {
  return 'BulkCompletionRequest(curriculumId: $curriculumId, contentItemIds: $contentItemIds, stageId: $stageId, trackType: $trackType)';
}


}

/// @nodoc
abstract mixin class $BulkCompletionRequestCopyWith<$Res>  {
  factory $BulkCompletionRequestCopyWith(BulkCompletionRequest value, $Res Function(BulkCompletionRequest) _then) = _$BulkCompletionRequestCopyWithImpl;
@useResult
$Res call({
 String curriculumId, List<int> contentItemIds, int stageId, String trackType
});




}
/// @nodoc
class _$BulkCompletionRequestCopyWithImpl<$Res>
    implements $BulkCompletionRequestCopyWith<$Res> {
  _$BulkCompletionRequestCopyWithImpl(this._self, this._then);

  final BulkCompletionRequest _self;
  final $Res Function(BulkCompletionRequest) _then;

/// Create a copy of BulkCompletionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? contentItemIds = null,Object? stageId = null,Object? trackType = null,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,contentItemIds: null == contentItemIds ? _self.contentItemIds : contentItemIds // ignore: cast_nullable_to_non_nullable
as List<int>,stageId: null == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BulkCompletionRequest].
extension BulkCompletionRequestPatterns on BulkCompletionRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BulkCompletionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BulkCompletionRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BulkCompletionRequest value)  $default,){
final _that = this;
switch (_that) {
case _BulkCompletionRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BulkCompletionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _BulkCompletionRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String curriculumId,  List<int> contentItemIds,  int stageId,  String trackType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BulkCompletionRequest() when $default != null:
return $default(_that.curriculumId,_that.contentItemIds,_that.stageId,_that.trackType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String curriculumId,  List<int> contentItemIds,  int stageId,  String trackType)  $default,) {final _that = this;
switch (_that) {
case _BulkCompletionRequest():
return $default(_that.curriculumId,_that.contentItemIds,_that.stageId,_that.trackType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String curriculumId,  List<int> contentItemIds,  int stageId,  String trackType)?  $default,) {final _that = this;
switch (_that) {
case _BulkCompletionRequest() when $default != null:
return $default(_that.curriculumId,_that.contentItemIds,_that.stageId,_that.trackType);case _:
  return null;

}
}

}

/// @nodoc


class _BulkCompletionRequest implements BulkCompletionRequest {
  const _BulkCompletionRequest({required this.curriculumId, required final  List<int> contentItemIds, required this.stageId, required this.trackType}): _contentItemIds = contentItemIds;
  

@override final  String curriculumId;
 final  List<int> _contentItemIds;
@override List<int> get contentItemIds {
  if (_contentItemIds is EqualUnmodifiableListView) return _contentItemIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contentItemIds);
}

@override final  int stageId;
@override final  String trackType;

/// Create a copy of BulkCompletionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BulkCompletionRequestCopyWith<_BulkCompletionRequest> get copyWith => __$BulkCompletionRequestCopyWithImpl<_BulkCompletionRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BulkCompletionRequest&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&const DeepCollectionEquality().equals(other._contentItemIds, _contentItemIds)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.trackType, trackType) || other.trackType == trackType));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,const DeepCollectionEquality().hash(_contentItemIds),stageId,trackType);

@override
String toString() {
  return 'BulkCompletionRequest(curriculumId: $curriculumId, contentItemIds: $contentItemIds, stageId: $stageId, trackType: $trackType)';
}


}

/// @nodoc
abstract mixin class _$BulkCompletionRequestCopyWith<$Res> implements $BulkCompletionRequestCopyWith<$Res> {
  factory _$BulkCompletionRequestCopyWith(_BulkCompletionRequest value, $Res Function(_BulkCompletionRequest) _then) = __$BulkCompletionRequestCopyWithImpl;
@override @useResult
$Res call({
 String curriculumId, List<int> contentItemIds, int stageId, String trackType
});




}
/// @nodoc
class __$BulkCompletionRequestCopyWithImpl<$Res>
    implements _$BulkCompletionRequestCopyWith<$Res> {
  __$BulkCompletionRequestCopyWithImpl(this._self, this._then);

  final _BulkCompletionRequest _self;
  final $Res Function(_BulkCompletionRequest) _then;

/// Create a copy of BulkCompletionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? contentItemIds = null,Object? stageId = null,Object? trackType = null,}) {
  return _then(_BulkCompletionRequest(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,contentItemIds: null == contentItemIds ? _self._contentItemIds : contentItemIds // ignore: cast_nullable_to_non_nullable
as List<int>,stageId: null == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
