import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/repositories/minimum_app_version_repository.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class MinimumAppVersionGate extends ConsumerStatefulWidget {
  const MinimumAppVersionGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MinimumAppVersionGate> createState() =>
      _MinimumAppVersionGateState();
}

class _MinimumAppVersionGateState extends ConsumerState<MinimumAppVersionGate>
    with WidgetsBindingObserver {
  bool _mustUpdate = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkMinimumVersion());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkMinimumVersion());
    }
  }

  Future<void> _checkMinimumVersion() async {
    if (_checking) return;
    _checking = true;
    try {
      final required = await ref
          .read(minimumAppVersionCheckerProvider)
          .shouldBlockApp();
      if (mounted && _mustUpdate != required) {
        setState(() => _mustUpdate = required);
      }
    } on Object {
      // A failed or offline check leaves the app usable.
      if (mounted && _mustUpdate) setState(() => _mustUpdate = false);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _mustUpdate ? const MinimumAppVersionScreen() : widget.child;
}

class MinimumAppVersionScreen extends StatelessWidget {
  const MinimumAppVersionScreen({super.key});

  static final playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.jcom.torah.learning_tracker',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    l10n.minimumAppVersionTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.minimumAppVersionMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => launchUrl(
                      playStoreUri,
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.minimumAppVersionUpdateAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
