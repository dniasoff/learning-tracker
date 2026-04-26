import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: l10n.syncTitle)),
      body: Center(child: Text(l10n.syncScreenBody)),
    );
  }
}
