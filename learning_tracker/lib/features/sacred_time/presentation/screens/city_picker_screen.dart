import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city_search_exception.dart';
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
                  _searchErrorMessage(e, AppLocalizations.of(context)!),
                ),
              ),
              data: (cities) {
                if (_query.length < 2) {
                  return _IdleHint(theme: theme);
                }
                if (cities.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.cityPickerNoMatches(_query),
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

/// Resolves a `citySearchProvider` [AsyncValue.error] to a localized,
/// user-facing string.
///
/// AUD-sacred_time-03 (EH-5): [CitiesRepository] converts its raw SQLite/I-O
/// exceptions into a typed [CitySearchException] before they reach this
/// provider, so the common case switches on [CitySearchException.code] and
/// never touches [CitySearchException.debugDetail] (logs only). Any other
/// error shape — defence in depth against a future call site that throws
/// something else into this provider — still falls back to the generic
/// string rather than ever rendering `error.toString()`.
String _searchErrorMessage(Object error, AppLocalizations l10n) {
  final code = error is CitySearchException
      ? error.code
      : CitySearchErrorCode.unknown;
  return switch (code) {
    CitySearchErrorCode.database => l10n.cityPickerSearchErrorDatabase,
    CitySearchErrorCode.unknown => l10n.cityPickerSearchErrorGeneric,
  };
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
          AppLocalizations.of(context)!.cityPickerIdleHint,
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

/// Returns false for numeric-only GeoNames admin1 codes (e.g. "05", "123")
/// that carry no human-readable meaning and should be suppressed in labels.
bool _isReadableRegion(String? admin1) {
  if (admin1 == null || admin1.isEmpty) return false;
  return !RegExp(r'^\d+$').hasMatch(admin1);
}

String _subtitleFor(City city) {
  final parts = <String>[
    if (_isReadableRegion(city.admin1)) city.admin1!,
    city.countryCode,
  ];
  return parts.join(' · ');
}

String _formatCityLabel(City city) {
  final parts = <String>[
    city.name,
    if (_isReadableRegion(city.admin1)) city.admin1!,
    city.countryCode,
  ];
  return parts.join(', ');
}
