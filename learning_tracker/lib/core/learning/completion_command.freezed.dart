// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'completion_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CompletionCommand {

 int get profileId; String get curriculumId; String get sefariaRef; int get stageId; String get trackType; int get trackId; DateTime get completedAt; int get points;
/// Create a copy of CompletionCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompletionCommandCopyWith<CompletionCommand> get copyWith => _$CompletionCommandCopyWithImpl<CompletionCommand>(this as CompletionCommand, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompletionCommand&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,profileId,curriculumId,sefariaRef,stageId,trackType,trackId,completedAt,points);

@override
String toString() {
  return 'CompletionCommand(profileId: $profileId, curriculumId: $curriculumId, sefariaRef: $sefariaRef, stageId: $stageId, trackType: $trackType, trackId: $trackId, completedAt: $completedAt, points: $points)';
}


}

/// @nodoc
abstract mixin class $CompletionCommandCopyWith<$Res>  {
  factory $CompletionCommandCopyWith(CompletionCommand value, $Res Function(CompletionCommand) _then) = _$CompletionCommandCopyWithImpl;
@useResult
$Res call({
 int profileId, String curriculumId, String sefariaRef, int stageId, String trackType, int trackId, DateTime completedAt, int points
});




}
/// @nodoc
class _$CompletionCommandCopyWithImpl<$Res>
    implements $CompletionCommandCopyWith<$Res> {
  _$CompletionCommandCopyWithImpl(this._self, this._then);

  final CompletionCommand _self;
  final $Res Function(CompletionCommand) _then;

/// Create a copy of CompletionCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? curriculumId = null,Object? sefariaRef = null,Object? stageId = null,Object? trackType = null,Object? trackId = null,Object? completedAt = null,Object? points = null,}) {
  return _then(_self.copyWith(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,stageId: null == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CompletionCommand].
extension CompletionCommandPatterns on CompletionCommand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompletionCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompletionCommand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompletionCommand value)  $default,){
final _that = this;
switch (_that) {
case _CompletionCommand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompletionCommand value)?  $default,){
final _that = this;
switch (_that) {
case _CompletionCommand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int profileId,  String curriculumId,  String sefariaRef,  int stageId,  String trackType,  int trackId,  DateTime completedAt,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompletionCommand() when $default != null:
return $default(_that.profileId,_that.curriculumId,_that.sefariaRef,_that.stageId,_that.trackType,_that.trackId,_that.completedAt,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int profileId,  String curriculumId,  String sefariaRef,  int stageId,  String trackType,  int trackId,  DateTime completedAt,  int points)  $default,) {final _that = this;
switch (_that) {
case _CompletionCommand():
return $default(_that.profileId,_that.curriculumId,_that.sefariaRef,_that.stageId,_that.trackType,_that.trackId,_that.completedAt,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int profileId,  String curriculumId,  String sefariaRef,  int stageId,  String trackType,  int trackId,  DateTime completedAt,  int points)?  $default,) {final _that = this;
switch (_that) {
case _CompletionCommand() when $default != null:
return $default(_that.profileId,_that.curriculumId,_that.sefariaRef,_that.stageId,_that.trackType,_that.trackId,_that.completedAt,_that.points);case _:
  return null;

}
}

}

/// @nodoc


class _CompletionCommand implements CompletionCommand {
  const _CompletionCommand({required this.profileId, required this.curriculumId, required this.sefariaRef, required this.stageId, required this.trackType, required this.trackId, required this.completedAt, required this.points});
  

@override final  int profileId;
@override final  String curriculumId;
@override final  String sefariaRef;
@override final  int stageId;
@override final  String trackType;
@override final  int trackId;
@override final  DateTime completedAt;
@override final  int points;

/// Create a copy of CompletionCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompletionCommandCopyWith<_CompletionCommand> get copyWith => __$CompletionCommandCopyWithImpl<_CompletionCommand>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompletionCommand&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,profileId,curriculumId,sefariaRef,stageId,trackType,trackId,completedAt,points);

@override
String toString() {
  return 'CompletionCommand(profileId: $profileId, curriculumId: $curriculumId, sefariaRef: $sefariaRef, stageId: $stageId, trackType: $trackType, trackId: $trackId, completedAt: $completedAt, points: $points)';
}


}

/// @nodoc
abstract mixin class _$CompletionCommandCopyWith<$Res> implements $CompletionCommandCopyWith<$Res> {
  factory _$CompletionCommandCopyWith(_CompletionCommand value, $Res Function(_CompletionCommand) _then) = __$CompletionCommandCopyWithImpl;
@override @useResult
$Res call({
 int profileId, String curriculumId, String sefariaRef, int stageId, String trackType, int trackId, DateTime completedAt, int points
});




}
/// @nodoc
class __$CompletionCommandCopyWithImpl<$Res>
    implements _$CompletionCommandCopyWith<$Res> {
  __$CompletionCommandCopyWithImpl(this._self, this._then);

  final _CompletionCommand _self;
  final $Res Function(_CompletionCommand) _then;

/// Create a copy of CompletionCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? curriculumId = null,Object? sefariaRef = null,Object? stageId = null,Object? trackType = null,Object? trackId = null,Object? completedAt = null,Object? points = null,}) {
  return _then(_CompletionCommand(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String,sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,stageId: null == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
