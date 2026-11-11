import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';
import 'package:learning_tracker/features/social/presentation/providers/learning_group_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class LearningGroupsScreen extends ConsumerStatefulWidget {
  const LearningGroupsScreen({
    super.key,
    required this.profileId,
    required this.isAdult,
  });

  final String profileId;
  final bool isAdult;

  @override
  ConsumerState<LearningGroupsScreen> createState() =>
      _LearningGroupsScreenState();
}

class _LearningGroupsScreenState extends ConsumerState<LearningGroupsScreen> {
  bool _busy = false;

  LearningGroupRepository get _repo =>
      ref.read(learningGroupRepositoryProvider);
  String? get _parentSessionId => ref.read(parentSessionIdProvider);

  Future<void> _refresh() async {
    ref.invalidate(
      learningGroupsProvider((
        profileId: widget.profileId,
        parentSessionId: _parentSessionId,
      )),
    );
  }

  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final school = TextEditingController();
    final values = await showDialog<(String, String?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupCreate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 64,
              decoration: InputDecoration(labelText: l10n.groupName),
            ),
            TextField(
              controller: school,
              decoration: InputDecoration(
                labelText: l10n.groupSchoolIdOptional,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              name.text.trim(),
              school.text.trim().isEmpty ? null : school.text.trim(),
            )),
            child: Text(l10n.groupCreate),
          ),
        ],
      ),
    );
    name.dispose();
    school.dispose();
    if (values == null || values.$1.isEmpty) return;
    await _run(() async {
      await _repo.create(
        name: values.$1,
        profileId: widget.profileId,
        schoolId: values.$2,
      );
      await _refresh();
    }, success: l10n.groupCreateSuccess);
  }

  Future<void> _joinGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final code = TextEditingController();
    final invite = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupJoin),
        content: TextField(
          controller: code,
          decoration: InputDecoration(labelText: l10n.groupInviteEntry),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, code.text.trim()),
            child: Text(l10n.groupJoinConfirm),
          ),
        ],
      ),
    );
    code.dispose();
    if (invite == null || invite.isEmpty) return;
    try {
      final preview = await _repo.previewInvite(
        inviteCode: invite,
        profileId: widget.profileId,
        parentSessionId: _parentSessionId,
      );
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(preview.name),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(preview.adminName),
                  subtitle: Text(l10n.groupAdmin),
                ),
                const Divider(),
                Text(
                  l10n.groupMembers,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final member in preview.members)
                  ListTile(dense: true, title: Text(member)),
                if (preview.childConsentRequired)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(l10n.groupJoinConsent),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.groupJoinConfirm),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      await _run(() async {
        await _repo.join(
          inviteCode: invite,
          profileId: widget.profileId,
          memberRevision: preview.memberRevision,
          parentSessionId: _parentSessionId,
        );
        await _refresh();
      });
    } catch (_) {
      if (mounted) _error(l10n.errorWithMessage);
    }
  }

  Future<void> _openGroup(LearningGroupSummary summary) async {
    final l10n = AppLocalizations.of(context)!;
    LearningGroupDetails details;
    try {
      details = await _repo.getGroup(
        groupId: summary.groupId,
        profileId: widget.profileId,
        parentSessionId: _parentSessionId,
      );
    } catch (_) {
      if (mounted) _error(l10n.errorWithMessage);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                details.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                details.groupType == 'school'
                    ? l10n.groupSchoolHosted
                    : l10n.groupPrivate,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.groupMembers,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final member in details.members)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      member.displayName.characters.firstOrNull ?? '?',
                    ),
                  ),
                  title: Text(member.displayName),
                  subtitle: member.role == 'admin'
                      ? Text(l10n.groupAdmin)
                      : null,
                  onTap: member.isSelf
                      ? null
                      : () => context.router.push(
                          SocialSummaryProfileRoute(
                            summaryId: member.summaryId,
                          ),
                        ),
                  trailing: details.role == 'admin' && !member.isSelf
                      ? PopupMenuButton<String>(
                          onSelected: (action) =>
                              _memberAction(details, member, action),
                          itemBuilder: (context) => [
                            if (member.mode == LearningGroupMemberMode.adult)
                              PopupMenuItem(
                                value: 'admin',
                                child: Text(l10n.groupTransferAdmin),
                              ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(l10n.groupRemoveMember),
                            ),
                          ],
                        )
                      : null,
                ),
              const Divider(),
              if (details.role == 'admin') ...[
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(l10n.groupInvite),
                  onTap: () {
                    Navigator.pop(context);
                    _createInvite(details);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.groupDelete),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteGroup(details);
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.groupLeave),
                  onTap: () {
                    Navigator.pop(context);
                    _leaveGroup(details);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _memberAction(
    LearningGroupDetails group,
    LearningGroupMember member,
    String action,
  ) async {
    await _run(() async {
      if (action == 'admin') {
        await _repo.transferAdmin(
          groupId: group.groupId,
          memberId: member.memberId,
        );
      } else {
        await _repo.removeMember(
          groupId: group.groupId,
          memberId: member.memberId,
        );
      }
      await _refresh();
    });
  }

  Future<void> _createInvite(LearningGroupDetails group) async {
    final l10n = AppLocalizations.of(context)!;
    await _run(() async {
      final code = await _repo.createInvite(groupId: group.groupId);
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) _message(l10n.groupInvitationCreated(code));
    });
  }

  Future<void> _leaveGroup(LearningGroupDetails group) async {
    await _run(() async {
      await _repo.leave(
        groupId: group.groupId,
        profileId: widget.profileId,
        parentSessionId: _parentSessionId,
      );
      await _refresh();
    });
  }

  Future<void> _deleteGroup(LearningGroupDetails group) async {
    await _run(() async {
      await _repo.delete(groupId: group.groupId);
      await _refresh();
    });
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (success != null && mounted) _message(success);
    } catch (_) {
      if (mounted) _error(AppLocalizations.of(context)!.errorWithMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  void _error(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parentSessionId = ref.watch(parentSessionIdProvider);
    final groups = ref.watch(
      learningGroupsProvider((
        profileId: widget.profileId,
        parentSessionId: parentSessionId,
      )),
    );
    final approvals = !widget.isAdult && parentSessionId != null
        ? ref.watch(
            groupApprovalsProvider((
              profileId: widget.profileId,
              parentSessionId: parentSessionId,
            )),
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupTitle),
        actions: [
          IconButton(
            tooltip: l10n.groupJoin,
            onPressed: _busy ? null : _joinGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
          if (widget.isAdult)
            IconButton(
              tooltip: l10n.groupCreate,
              onPressed: _busy ? null : _createGroup,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (approvals != null) ...[
                Text(
                  l10n.groupParentApprovals,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                approvals.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(l10n.errorWithMessage),
                  data: (items) => items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(l10n.groupNoApprovals),
                        )
                      : Column(
                          children: [
                            for (final item in items)
                              Card(
                                child: ListTile(
                                  title: Text(item.displayName),
                                  subtitle: Text(item.groupName),
                                  trailing: IconButton(
                                    tooltip: item.approved
                                        ? l10n.groupRevokeMember
                                        : l10n.groupApproveMember,
                                    icon: Icon(
                                      item.approved
                                          ? Icons.remove_circle_outline
                                          : Icons.check_circle_outline,
                                    ),
                                    onPressed: parentSessionId == null
                                        ? null
                                        : () => _approve(item, parentSessionId),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const Divider(height: 32),
              ],
              groups.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.errorWithMessage)),
                data: (items) => items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.groupNoGroups),
                        ),
                      )
                    : Column(
                        children: [
                          for (final group in items)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.groups_outlined),
                                title: Text(group.name),
                                subtitle: Text(
                                  '${group.groupType == 'school' ? l10n.groupSchoolHosted : l10n.groupPrivate} · ${group.memberCount} ${l10n.groupMembers.toLowerCase()}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openGroup(group),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _approve(
    GroupParentApproval item,
    String parentSessionId,
  ) async {
    await _run(() async {
      await _repo.setApproval(
        approvalId: item.approvalId,
        profileId: widget.profileId,
        approved: !item.approved,
        parentSessionId: parentSessionId,
      );
      ref.invalidate(
        groupApprovalsProvider((
          profileId: widget.profileId,
          parentSessionId: parentSessionId,
        )),
      );
    });
  }
}
