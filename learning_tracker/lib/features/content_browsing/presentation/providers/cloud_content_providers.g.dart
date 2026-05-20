// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_content_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the CloudContentService (singleton).
///
/// Retained for potential future use (content updates, text downloads).

@ProviderFor(cloudContentService)
final cloudContentServiceProvider = CloudContentServiceProvider._();

/// Provides the CloudContentService (singleton).
///
/// Retained for potential future use (content updates, text downloads).

final class CloudContentServiceProvider
    extends
        $FunctionalProvider<
          CloudContentService,
          CloudContentService,
          CloudContentService
        >
    with $Provider<CloudContentService> {
  /// Provides the CloudContentService (singleton).
  ///
  /// Retained for potential future use (content updates, text downloads).
  CloudContentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudContentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudContentServiceHash();

  @$internal
  @override
  $ProviderElement<CloudContentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CloudContentService create(Ref ref) {
    return cloudContentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudContentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudContentService>(value),
    );
  }
}

String _$cloudContentServiceHash() =>
    r'bf3d50d9b620cf52a4f68ad23e8ba657cd467b24';

/// Provides the TextDownloadStatusDao from UserDatabase.

@ProviderFor(contentDownloadStatusDaoProvider)
final contentDownloadStatusDaoProviderProvider =
    ContentDownloadStatusDaoProviderProvider._();

/// Provides the TextDownloadStatusDao from UserDatabase.

final class ContentDownloadStatusDaoProviderProvider
    extends
        $FunctionalProvider<
          TextDownloadStatusDao,
          TextDownloadStatusDao,
          TextDownloadStatusDao
        >
    with $Provider<TextDownloadStatusDao> {
  /// Provides the TextDownloadStatusDao from UserDatabase.
  ContentDownloadStatusDaoProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentDownloadStatusDaoProviderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDownloadStatusDaoProviderHash();

  @$internal
  @override
  $ProviderElement<TextDownloadStatusDao> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TextDownloadStatusDao create(Ref ref) {
    return contentDownloadStatusDaoProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TextDownloadStatusDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TextDownloadStatusDao>(value),
    );
  }
}

String _$contentDownloadStatusDaoProviderHash() =>
    r'3073acbed4592b8fffdc0c03fea5637d1074c2f7';
