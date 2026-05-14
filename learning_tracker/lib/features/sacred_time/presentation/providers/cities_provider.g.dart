// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cities_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(citiesRepository)
final citiesRepositoryProvider = CitiesRepositoryProvider._();

final class CitiesRepositoryProvider
    extends
        $FunctionalProvider<
          CitiesRepository,
          CitiesRepository,
          CitiesRepository
        >
    with $Provider<CitiesRepository> {
  CitiesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'citiesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$citiesRepositoryHash();

  @$internal
  @override
  $ProviderElement<CitiesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CitiesRepository create(Ref ref) {
    return citiesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CitiesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CitiesRepository>(value),
    );
  }
}

String _$citiesRepositoryHash() => r'da54fdeb7dfb0e3935d23ec471090eb2ac53bdca';

/// Typeahead search results for the city picker. Empty query returns no
/// results; the picker shows a country-scoped list separately when idle.

@ProviderFor(citySearch)
final citySearchProvider = CitySearchFamily._();

/// Typeahead search results for the city picker. Empty query returns no
/// results; the picker shows a country-scoped list separately when idle.

final class CitySearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<City>>,
          List<City>,
          FutureOr<List<City>>
        >
    with $FutureModifier<List<City>>, $FutureProvider<List<City>> {
  /// Typeahead search results for the city picker. Empty query returns no
  /// results; the picker shows a country-scoped list separately when idle.
  CitySearchProvider._({
    required CitySearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'citySearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$citySearchHash();

  @override
  String toString() {
    return r'citySearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<City>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<City>> create(Ref ref) {
    final argument = this.argument as String;
    return citySearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CitySearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$citySearchHash() => r'546ef740c323276540c3790e075f6918eba4a6c5';

/// Typeahead search results for the city picker. Empty query returns no
/// results; the picker shows a country-scoped list separately when idle.

final class CitySearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<City>>, String> {
  CitySearchFamily._()
    : super(
        retry: null,
        name: r'citySearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Typeahead search results for the city picker. Empty query returns no
  /// results; the picker shows a country-scoped list separately when idle.

  CitySearchProvider call(String query) =>
      CitySearchProvider._(argument: query, from: this);

  @override
  String toString() => r'citySearchProvider';
}
