import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Consent is explicit for adults; child enrollment is shown behind the PIN
/// gate and still records the parent's staff-progress consent on the server.
@RoutePage()
class JoinSchoolScreen extends ConsumerStatefulWidget {
  const JoinSchoolScreen({
    super.key,
    required this.inviteCode,
    required this.profileId,
    required this.isChild,
    this.parentSessionId,
  });

  final String inviteCode;
  final String profileId;
  final bool isChild;
  final String? parentSessionId;

  @override
  ConsumerState<JoinSchoolScreen> createState() => _JoinSchoolScreenState();
}

class _JoinSchoolScreenState extends ConsumerState<JoinSchoolScreen> {
  bool _consented = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolJoinTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.schoolStaffProgressNotice,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          CheckboxListTile(
            value: _consented,
            onChanged: _saving
                ? null
                : (value) => setState(() => _consented = value == true),
            title: Text(
              widget.isChild
                  ? l10n.schoolParentProgressConsent
                  : l10n.schoolProgressConsent,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !_consented || _saving ? null : _join,
            child: _saving
                ? const CircularProgressIndicator()
                : Text(l10n.schoolJoinAction),
          ),
        ],
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(schoolRepositoryProvider)
          .join(
            inviteCode: widget.inviteCode,
            profileId: widget.profileId,
            parentSessionId: widget.parentSessionId,
            progressConsent: true,
          );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.schoolJoinSucceeded),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
