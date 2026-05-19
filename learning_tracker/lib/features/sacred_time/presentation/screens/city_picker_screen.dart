import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/cities_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Typeahead picker over the bundled cities dataset (~33k cities).
/// On selection, persists as the user's manual location and pops the route
/// returning the chosen [City] so callers can react.
@RoutePage()
class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _query.length < 2
        ? const AsyncValue<List<City>>.data(<City>[])
        : ref.watch(citySearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.cityPickerTitle),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              inputFormatters: const [TrimLeadingSpaceFormatter()],
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.cityPickerHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context)!.errorSearchFailed(e.toString()),
                ),
              ),
              data: (cities) {
                if (_query.length < 2) {
                  return _IdleHint(theme: theme);
                }
                if (cities.isEmpty) {
                  return Center(
                    child: Text(
                      'No matches for "$_query".',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: cities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _CityRow(city: cities[i], onTap: _select),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _select(City city) async {
    await ref
        .read(sacredLocationProvider.notifier)
        .setManualCity(
          latitude: city.latitude,
          longitude: city.longitude,
          cityLabel: _formatCityLabel(city),
          countryCode: city.countryCode,
        );
    if (!mounted) return;
    context.router.pop(city);
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Start typing to search ~33,000 cities.\n'
          'Type at least 2 letters.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.city, required this.onTap});

  final City city;
  final ValueChanged<City> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(city.name),
      subtitle: Text(
        _subtitleFor(city),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => onTap(city),
    );
  }
}

String _subtitleFor(City city) {
  final parts = <String>[
    if (city.admin1 != null && city.admin1!.isNotEmpty) city.admin1!,
    city.countryCode,
  ];
  return parts.join(' · ');
}

String _formatCityLabel(City city) {
  final parts = <String>[
    city.name,
    if (city.admin1 != null && city.admin1!.isNotEmpty) city.admin1!,
    city.countryCode,
  ];
  return parts.join(', ');
}
