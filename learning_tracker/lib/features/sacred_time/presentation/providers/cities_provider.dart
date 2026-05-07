import 'package:learning_tracker/features/sacred_time/data/services/cities_repository.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cities_provider.g.dart';

@Riverpod(keepAlive: true)
CitiesRepository citiesRepository(Ref ref) {
  final repo = CitiesRepository();
  ref.onDispose(repo.dispose);
  return repo;
}

/// Typeahead search results for the city picker. Empty query returns no
/// results; the picker shows a country-scoped list separately when idle.
@riverpod
Future<List<City>> citySearch(Ref ref, String query) async {
  final repo = ref.watch(citiesRepositoryProvider);
  return repo.searchByPrefix(query);
}
