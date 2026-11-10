import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/settings/domain/app_credits.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => const AboutScreenContent();
}

/// About page content kept separate so contact data and link launching can be
/// injected in widget tests without becoming route arguments.
class AboutScreenContent extends StatelessWidget {
  const AboutScreenContent({
    super.key,
    this.creators = appCreators,
    this.launchUri,
  });

  final List<AppCreator> creators;
  final Future<bool> Function(Uri uri)? launchUri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final creatorsWithContact = creators
        .where((creator) => creator.hasContact)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.aboutDescription,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null || info.version.isEmpty) {
                  return const SizedBox.shrink();
                }
                final version = info.buildNumber.isEmpty
                    ? l10n.aboutVersion(info.version)
                    : l10n.aboutVersionWithBuild(
                        info.version,
                        info.buildNumber,
                      );
                return Text(
                  version,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 32),
            _SectionTitle(title: l10n.aboutCreatedBy),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < creators.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    ListTile(title: Text(creators[index].name)),
                  ],
                ],
              ),
            ),
            if (creatorsWithContact.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionTitle(title: l10n.aboutContactUs),
              Card(
                child: Column(
                  children: [
                    for (final creator in creatorsWithContact)
                      _CreatorContactRows(
                        creator: creator,
                        launch: launchUri ?? launchUrl,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on AppCreator {
  bool get hasContact =>
      _hasValue(email) ||
      _hasValue(phone) ||
      _hasValue(whatsAppDigits) ||
      _hasValue(website);

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;
}

class _CreatorContactRows extends StatelessWidget {
  const _CreatorContactRows({required this.creator, required this.launch});

  final AppCreator creator;
  final Future<bool> Function(Uri uri) launch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];

    void addContact({
      required String? value,
      required String label,
      required IconData icon,
      required Uri uri,
      String? displayedValue,
    }) {
      if (value == null || value.trim().isEmpty) return;
      if (rows.isNotEmpty) rows.add(const Divider(height: 1));
      rows.add(
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(displayedValue ?? value),
          onTap: () async {
            await launch(uri);
          },
        ),
      );
    }

    addContact(
      value: creator.email,
      label: l10n.aboutEmail,
      icon: Icons.email_outlined,
      uri: Uri(scheme: 'mailto', path: creator.email ?? ''),
    );
    addContact(
      value: creator.phone,
      label: l10n.aboutPhone,
      icon: Icons.phone_outlined,
      uri: Uri(scheme: 'tel', path: creator.phone ?? ''),
    );
    final whatsapp = creator.whatsAppDigits;
    addContact(
      value: whatsapp,
      label: l10n.aboutWhatsApp,
      icon: Icons.chat_outlined,
      uri: Uri.https('wa.me', '/${whatsapp ?? ''}'),
      displayedValue: whatsapp == null ? null : '+$whatsapp',
    );
    final website = creator.website;
    addContact(
      value: website,
      label: l10n.aboutWebsite,
      icon: Icons.language_outlined,
      uri: website == null ? Uri() : Uri.parse(website),
    );

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            creator.name,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...rows,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}
