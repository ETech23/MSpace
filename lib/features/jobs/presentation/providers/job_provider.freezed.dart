// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$JobState {
  List<JobModel> get customerJobs => throw _privateConstructorUsedError;
  List<JobMatchModel> get artisanMatches => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isPosting => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  JobModel? get activeJob => throw _privateConstructorUsedError;

  /// Create a copy of JobState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobStateCopyWith<JobState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobStateCopyWith<$Res> {
  factory $JobStateCopyWith(JobState value, $Res Function(JobState) then) =
      _$JobStateCopyWithImpl<$Res, JobState>;
  @useResult
  $Res call(
      {List<JobModel> customerJobs,
      List<JobMatchModel> artisanMatches,
      bool isLoading,
      bool isPosting,
      String? error,
      JobModel? activeJob});
}

/// @nodoc
class _$JobStateCopyWithImpl<$Res, $Val extends JobState>
    implements $JobStateCopyWith<$Res> {
  _$JobStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JobState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? customerJobs = null,
    Object? artisanMatches = null,
    Object? isLoading = null,
    Object? isPosting = null,
    Object? error = freezed,
    Object? activeJob = freezed,
  }) {
    return _then(_value.copyWith(
      customerJobs: null == customerJobs
          ? _value.customerJobs
          : customerJobs // ignore: cast_nullable_to_non_nullable
              as List<JobModel>,
      artisanMatches: null == artisanMatches
          ? _value.artisanMatches
          : artisanMatches // ignore: cast_nullable_to_non_nullable
              as List<JobMatchModel>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isPosting: null == isPosting
          ? _value.isPosting
          : isPosting // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      activeJob: freezed == activeJob
          ? _value.activeJob
          : activeJob // ignore: cast_nullable_to_non_nullable
              as JobModel?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobStateImplCopyWith<$Res>
    implements $JobStateCopyWith<$Res> {
  factory _$$JobStateImplCopyWith(
          _$JobStateImpl value, $Res Function(_$JobStateImpl) then) =
      __$$JobStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<JobModel> customerJobs,
      List<JobMatchModel> artisanMatches,
      bool isLoading,
      bool isPosting,
      String? error,
      JobModel? activeJob});
}

/// @nodoc
class __$$JobStateImplCopyWithImpl<$Res>
    extends _$JobStateCopyWithImpl<$Res, _$JobStateImpl>
    implements _$$JobStateImplCopyWith<$Res> {
  __$$JobStateImplCopyWithImpl(
      _$JobStateImpl _value, $Res Function(_$JobStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? customerJobs = null,
    Object? artisanMatches = null,
    Object? isLoading = null,
    Object? isPosting = null,
    Object? error = freezed,
    Object? activeJob = freezed,
  }) {
    return _then(_$JobStateImpl(
      customerJobs: null == customerJobs
          ? _value._customerJobs
          : customerJobs // ignore: cast_nullable_to_non_nullable
              as List<JobModel>,
      artisanMatches: null == artisanMatches
          ? _value._artisanMatches
          : artisanMatches // ignore: cast_nullable_to_non_nullable
              as List<JobMatchModel>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isPosting: null == isPosting
          ? _value.isPosting
          : isPosting // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      activeJob: freezed == activeJob
          ? _value.activeJob
          : activeJob // ignore: cast_nullable_to_non_nullable
              as JobModel?,
    ));
  }
}

/// @nodoc

class _$JobStateImpl implements _JobState {
  const _$JobStateImpl(
      {final List<JobModel> customerJobs = const [],
      final List<JobMatchModel> artisanMatches = const [],
      this.isLoading = false,
      this.isPosting = false,
      this.error,
      this.activeJob})
      : _customerJobs = customerJobs,
        _artisanMatches = artisanMatches;

  final List<JobModel> _customerJobs;
  @override
  @JsonKey()
  List<JobModel> get customerJobs {
    if (_customerJobs is EqualUnmodifiableListView) return _customerJobs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customerJobs);
  }

  final List<JobMatchModel> _artisanMatches;
  @override
  @JsonKey()
  List<JobMatchModel> get artisanMatches {
    if (_artisanMatches is EqualUnmodifiableListView) return _artisanMatches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artisanMatches);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isPosting;
  @override
  final String? error;
  @override
  final JobModel? activeJob;

  @override
  String toString() {
    return 'JobState(customerJobs: $customerJobs, artisanMatches: $artisanMatches, isLoading: $isLoading, isPosting: $isPosting, error: $error, activeJob: $activeJob)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobStateImpl &&
            const DeepCollectionEquality()
                .equals(other._customerJobs, _customerJobs) &&
            const DeepCollectionEquality()
                .equals(other._artisanMatches, _artisanMatches) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isPosting, isPosting) ||
                other.isPosting == isPosting) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality().equals(other.activeJob, activeJob));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_customerJobs),
      const DeepCollectionEquality().hash(_artisanMatches),
      isLoading,
      isPosting,
      error,
      const DeepCollectionEquality().hash(activeJob));

  /// Create a copy of JobState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobStateImplCopyWith<_$JobStateImpl> get copyWith =>
      __$$JobStateImplCopyWithImpl<_$JobStateImpl>(this, _$identity);
}

abstract class _JobState implements JobState {
  const factory _JobState(
      {final List<JobModel> customerJobs,
      final List<JobMatchModel> artisanMatches,
      final bool isLoading,
      final bool isPosting,
      final String? error,
      final JobModel? activeJob}) = _$JobStateImpl;

  @override
  List<JobModel> get customerJobs;
  @override
  List<JobMatchModel> get artisanMatches;
  @override
  bool get isLoading;
  @override
  bool get isPosting;
  @override
  String? get error;
  @override
  JobModel? get activeJob;

  /// Create a copy of JobState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobStateImplCopyWith<_$JobStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
