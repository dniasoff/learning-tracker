import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';

/// Settings card for the Sacred Time feature. Hard-on (no disable toggle).
/// Lets the user choose location source (detect / manual city), refresh, and
/// flip the in-Israel one-day-chag override.
class SacredTimeSettingsCard extends ConsumerWidget {
  const SacredTimeSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = ref.watch(sacredLocationProvider);
    final inIsrael = ref.watch(inIsraelProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12061D56),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(theme: theme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App is silenced and locked during Shabbos and Yom Tov. '
                  'Times computed locally from your location with a 15-minute '
                  'cushion.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _LocationRow(location: location),
                const SizedBox(height: 12),
                _LocationActions(),
                const Divider(height: 28),
                _InIsraelRow(value: inIsrael),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF11389F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          const Text(
            'SACRED TIME',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            'Always on',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location});

  final SacredLocation? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = location == null
        ? 'No location set'
        : (location!.cityLabel ??
              '${location!.latitude.toStringAsFixed(3)}, '
                  '${location!.longitude.toStringAsFixed(3)}');
    final sourceLabel = location == null
        ? null
        : switch (location!.source) {
            SacredLocationSource.detected => 'Detected automatically',
            SacredLocationSource.manualCity => 'Chosen from city list',
            SacredLocationSource.manualCoords => 'Manual coordinates',
          };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.place_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (sourceLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sourceLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationActions extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LocationActions> createState() => _LocationActionsState();
}

class _LocationActionsState extends ConsumerState<_LocationActions> {
  bool _detecting = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _detecting ? null : _detect,
            icon: _detecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: const Text('Detect'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _detecting ? null : _pickCity,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Choose city'),
          ),
        ),
      ],
    );
  }

  Future<void> _detect() async {
    setState(() => _detecting = true);
    try {
      final result = await ref.read(sacredLocationProvider.notifier).detect();
      if (!mounted) return;
      _showOutcome(result);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _pickCity() async {
    await context.pushRoute(const CityPickerRoute());
  }

  void _showOutcome(LocationFetchResult result) {
    final messenger = ScaffoldMessenger.of(context);
    final message = switch (result) {
      LocationFetchSuccess() => 'Location updated.',
      LocationFetchPermissionDenied(:final permanentlyDenied) =>
        permanentlyDenied
            ? 'Location permission permanently denied. Open system settings to allow.'
            : 'Location permission denied.',
      LocationFetchServiceDisabled() =>
        'Location services are turned off on this device.',
      LocationFetchError(:final message) =>
        'Could not detect location: $message',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InIsraelRow extends ConsumerWidget {
  const _InIsraelRow({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I am in Israel',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'One-day chag if on. Auto-set when you detect or choose a city, '
                'flip if you are visiting.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: (v) => ref.read(inIsraelProvider.notifier).setInIsrael(v),
        ),
      ],
    );
  }
}
