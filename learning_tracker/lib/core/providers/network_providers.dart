import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/core/network/dio_client.dart';
import 'package:learning_tracker/core/network/sefaria/bavli_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/chumash_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/mishna_berurah_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/mishna_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/yerushalmi_fetcher.dart';

/// Provider for the configured Dio instance targeting the Sefaria API.
final dioClientProvider = Provider<Dio>((ref) {
  return createSefariaClient();
});

/// Provider for the connectivity service.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider for the Mishnayos content fetcher.
final mishnaFetcherProvider = Provider<CurriculumContentFetcher>((ref) {
  return MishnaFetcher(dio: ref.watch(dioClientProvider));
});

/// Provider for the Bavli content fetcher.
final bavliFetcherProvider = Provider<CurriculumContentFetcher>((ref) {
  return BavliFetcher(dio: ref.watch(dioClientProvider));
});

/// Provider for the Yerushalmi content fetcher.
final yerushalmiFetcherProvider = Provider<CurriculumContentFetcher>((ref) {
  return YerushalmiFetcher(dio: ref.watch(dioClientProvider));
});

/// Provider for the Mishna Berurah content fetcher.
final mishnaBerurahFetcherProvider = Provider<CurriculumContentFetcher>((ref) {
  return MishnaBerurahFetcher(dio: ref.watch(dioClientProvider));
});

/// Provider for the Chumash content fetcher.
final chumashFetcherProvider = Provider<CurriculumContentFetcher>((ref) {
  return ChumashFetcher(dio: ref.watch(dioClientProvider));
});

/// Provider that returns all curriculum content fetchers.
final allFetchersProvider = Provider<List<CurriculumContentFetcher>>((ref) {
  return [
    ref.watch(mishnaFetcherProvider),
    ref.watch(bavliFetcherProvider),
    ref.watch(yerushalmiFetcherProvider),
    ref.watch(mishnaBerurahFetcherProvider),
    ref.watch(chumashFetcherProvider),
  ];
});
