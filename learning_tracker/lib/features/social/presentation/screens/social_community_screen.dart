import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/social/domain/social_graph.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class SocialCommunityScreen extends ConsumerStatefulWidget {
  const SocialCommunityScreen({super.key, this.parentMode = false});

  final bool parentMode;

  @override
  ConsumerState<SocialCommunityScreen> createState() =>
      _SocialCommunityScreenState();
}

class _SocialCommunityScreenState extends ConsumerState<SocialCommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _schoolId = TextEditingController();
  final _exactName = TextEditingController();
  SocialSearchPage? _searchPage;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tabs.dispose();
    _schoolId.dispose();
    _exactName.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(socialConnectionsProvider);
    } catch (_) {
      if (mounted)
        setState(() => _error = AppLocalizations.of(context)!.errorWithMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<({String profileId, String? parentSessionId})?> _scope() async {
    final profile = await ref.read(activeProfileProvider.future);
    if (profile == null) return null;
    final parentSessionId = ref.read(parentSessionIdProvider);
    if (profile.mode.name == 'child' && parentSessionId == null) return null;
    return (profileId: profile.profileId, parentSessionId: parentSessionId);
  }

  Future<void> _search() async {
    final scope = await _scope();
    if (scope == null ||
        _schoolId.text.trim().isEmpty ||
        _exactName.text.trim().isEmpty) {
      return;
    }
    await _perform(() async {
      final page = await ref
          .read(socialGraphRepositoryProvider)
          .searchSchool(
            profileId: scope.profileId,
            schoolId: _schoolId.text.trim(),
            exactName: _exactName.text.trim(),
            parentSessionId: scope.parentSessionId,
          );
      if (mounted) setState(() => _searchPage = page);
    });
  }

  Future<void> _sendRequest(SocialProfileCard target) async {
    final scope = await _scope();
    final profile = await ref.read(activeProfileProvider.future);
    if (scope == null || profile == null) return;
    await _perform(() async {
      await ref
          .read(socialGraphRepositoryProvider)
          .upsertProfile(
            profileId: profile.profileId,
            displayName: profile.displayName,
            avatarId: int.tryParse(profile.avatar) ?? 0,
            parentSessionId: scope.parentSessionId,
          );
      await ref
          .read(socialGraphRepositoryProvider)
          .sendRequest(
            fromProfileId: scope.profileId,
            toSocialProfileId: target.socialProfileId,
            parentSessionId: scope.parentSessionId,
          );
      if (mounted) setState(() => _searchPage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileId = ref.watch(activeProfileIdProvider);
    final sessionId = ref.watch(parentSessionIdProvider);
    final connections = profileId == null
        ? null
        : ref.watch(
            socialConnectionsProvider((
              profileId: profileId,
              parentSessionId: sessionId,
            )),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.parentMode
              ? l10n.communityParentControls
              : l10n.communityTitle,
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.communityFollowers),
            Tab(text: l10n.communityFollowing),
            Tab(text: l10n.communityRequests),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.parentMode && profileId != null && sessionId != null)
              _ChildSocialControlsEditor(
                profileId: profileId,
                parentSessionId: sessionId,
              ),
            Expanded(
              child: connections == null
                  ? const Center(child: CircularProgressIndicator())
                  : connections.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) =>
                          Center(child: Text(l10n.errorWithMessage)),
                      data: (value) => TabBarView(
                        controller: _tabs,
                        children: [
                          _relationshipList(value.followers, incoming: true),
                          _relationshipList(value.following, incoming: false),
                          _requests(value),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFindPeople,
        icon: const Icon(Icons.person_search_outlined),
        label: Text(l10n.communityFindPeople),
      ),
    );
  }

  Widget _relationshipList(
    List<SocialRelationship> items, {
    required bool incoming,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) return Center(child: Text(l10n.communityNoConnections));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Text(
          l10n.communityPrivacyNotice,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final item in items)
          _relationshipTile(
            item,
            targetId: incoming
                ? item.fromSocialProfileId
                : item.toSocialProfileId,
            name: incoming ? item.fromDisplayName : item.toDisplayName,
            summaryId: incoming ? item.fromSummaryId : item.toSummaryId,
          ),
      ],
    );
  }

  Widget _relationshipTile(
    SocialRelationship item, {
    required String targetId,
    required String? name,
    required String? summaryId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text((name ?? '?').characters.first.toUpperCase()),
        ),
        title: Text(name ?? l10n.communityUnavailableProfile),
        subtitle: Text(item.state.name),
        onTap: summaryId == null
            ? null
            : () => context.router.push(
                SocialSummaryProfileRoute(summaryId: summaryId),
              ),
        trailing: IconButton(
          tooltip: l10n.communityRemove,
          icon: const Icon(Icons.more_vert),
          onPressed: _busy ? null : () => _relationshipActions(targetId),
        ),
      ),
    );
  }

  Widget _requests(SocialConnections value) {
    final l10n = AppLocalizations.of(context)!;
    final incoming = value.incomingRequests
        .where((r) => r.state == FollowRequestState.pending)
        .toList();
    if (incoming.isEmpty && value.outgoingRequests.isEmpty) {
      return Center(child: Text(l10n.communityNoRequests));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        for (final request in incoming)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  (request.fromDisplayName ?? '?').characters.first
                      .toUpperCase(),
                ),
              ),
              title: Text(
                request.fromDisplayName ?? l10n.communityUnavailableProfile,
              ),
              subtitle: Text(l10n.communityRequests),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: l10n.communityApprove,
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: _busy
                        ? null
                        : () => _review(request, accept: true),
                  ),
                  IconButton(
                    tooltip: l10n.communityDecline,
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: _busy
                        ? null
                        : () => _review(request, accept: false),
                  ),
                ],
              ),
            ),
          ),
        for (final request in value.outgoingRequests)
          ListTile(
            title: Text(
              request.toDisplayName ?? l10n.communityUnavailableProfile,
            ),
            subtitle: Text(l10n.communityRequestPending),
          ),
      ],
    );
  }

  Future<void> _review(
    SocialRelationship request, {
    required bool accept,
  }) async {
    final scope = await _scope();
    if (scope == null) return;
    await _perform(
      () => ref
          .read(socialGraphRepositoryProvider)
          .reviewRequest(
            requestId: request.id,
            profileId: scope.profileId,
            accept: accept,
            parentSessionId: scope.parentSessionId,
          ),
    );
  }

  Future<void> _remove(String targetId) async {
    final scope = await _scope();
    if (scope == null) return;
    await _perform(
      () => ref
          .read(socialGraphRepositoryProvider)
          .removeConnection(
            profileId: scope.profileId,
            toSocialProfileId: targetId,
            parentSessionId: scope.parentSessionId,
          ),
    );
  }

  Future<void> _block(String targetId) async {
    final scope = await _scope();
    if (scope == null) return;
    await _perform(
      () => ref
          .read(socialGraphRepositoryProvider)
          .blockProfile(
            profileId: scope.profileId,
            toSocialProfileId: targetId,
            parentSessionId: scope.parentSessionId,
          ),
    );
  }

  Future<void> _relationshipActions(String targetId) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: Text(l10n.communityRemove),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(l10n.communityBlock),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (action == 'remove') await _remove(targetId);
    if (action == 'block') await _block(targetId);
  }

  Future<void> _openFindPeople() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.communityFindPeople,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(l10n.communitySearchOnlySchool),
                const SizedBox(height: 12),
                TextField(
                  controller: _schoolId,
                  decoration: InputDecoration(
                    labelText: l10n.communitySchoolId,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _exactName,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: l10n.communityExactName,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          _search();
                          setModalState(() {});
                        },
                  icon: const Icon(Icons.search),
                  label: Text(l10n.communitySearch),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_searchPage case final page?)
                  for (final person in page.profiles)
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          person.displayName.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(person.displayName),
                      onTap: person.summaryId == null
                          ? null
                          : () => context.router.push(
                              SocialSummaryProfileRoute(
                                summaryId: person.summaryId!,
                              ),
                            ),
                      trailing: IconButton(
                        tooltip: l10n.communitySendRequest,
                        icon: const Icon(Icons.person_add_alt_1),
                        onPressed: _busy ? null : () => _sendRequest(person),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildSocialControlsEditor extends ConsumerWidget {
  const _ChildSocialControlsEditor({
    required this.profileId,
    required this.parentSessionId,
  });

  final String profileId;
  final String parentSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controls = ref.watch(
      socialChildControlsProvider((
        profileId: profileId,
        parentSessionId: parentSessionId,
      )),
    );
    return controls.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(l10n.errorWithMessage),
      ),
      data: (value) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.communityPauseSharing),
              value: value.paused,
              onChanged: (paused) async {
                await ref
                    .read(socialGraphRepositoryProvider)
                    .setChildControls(
                      profileId: profileId,
                      parentSessionId: parentSessionId,
                      allowedSchoolIds: value.allowedSchoolIds,
                      paused: paused,
                    );
                ref.invalidate(
                  socialChildControlsProvider((
                    profileId: profileId,
                    parentSessionId: parentSessionId,
                  )),
                );
                ref.invalidate(socialConnectionsProvider);
              },
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.communityAllowedSchools),
              subtitle: Text(
                value.allowedSchoolIds.isEmpty
                    ? l10n.communityNoAllowedSchools
                    : value.allowedSchoolIds.join(', '),
              ),
              children: [
                TextFormField(
                  key: ValueKey(value.allowedSchoolIds.join('|')),
                  initialValue: value.allowedSchoolIds.join(', '),
                  decoration: InputDecoration(
                    labelText: l10n.communitySchoolIds,
                    helperText: l10n.communitySchoolIdsHelp,
                  ),
                  onFieldSubmitted: (raw) async {
                    final schools = raw
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toSet()
                        .toList();
                    await ref
                        .read(socialGraphRepositoryProvider)
                        .setChildControls(
                          profileId: profileId,
                          parentSessionId: parentSessionId,
                          allowedSchoolIds: schools,
                          paused: value.paused,
                        );
                    ref.invalidate(
                      socialChildControlsProvider((
                        profileId: profileId,
                        parentSessionId: parentSessionId,
                      )),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
