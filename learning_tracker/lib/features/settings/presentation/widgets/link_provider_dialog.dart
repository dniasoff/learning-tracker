import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/features/settings/domain/services/account_management_service.dart';

/// Shows a dialog listing available providers that can be linked.
Future<void> showLinkProviderDialog({
  required BuildContext context,
  required AccountManagementService service,
}) async {
  final linkedProviders = service.getLinkedProviders();
  final hasPassword = linkedProviders.contains('password');
  final hasGoogle = linkedProviders.contains('google.com');

  if (hasPassword && hasGoogle) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available sign-in methods are already linked.'),
        ),
      );
    }
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => _LinkProviderDialog(
      service: service,
      hasPassword: hasPassword,
      hasGoogle: hasGoogle,
    ),
  );
}

class _LinkProviderDialog extends StatefulWidget {
  const _LinkProviderDialog({
    required this.service,
    required this.hasPassword,
    required this.hasGoogle,
  });

  final AccountManagementService service;
  final bool hasPassword;
  final bool hasGoogle;

  @override
  State<_LinkProviderDialog> createState() => _LinkProviderDialogState();
}

class _LinkProviderDialogState extends State<_LinkProviderDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showEmailForm = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _linkGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.service.linkGoogleProvider();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google account linked successfully.')),
        );
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        setState(() => _loading = false);
      } else {
        setState(() {
          _error = 'Failed to link Google account.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to link Google account.';
        _loading = false;
      });
    }
  }

  Future<void> _linkEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.length < 6) {
      setState(() => _error = 'Enter a valid email and password (6+ chars).');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.service.linkEmailProvider(
        _emailController.text,
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email/password account linked successfully.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to link email account.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add another sign-in method to your account.'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          if (!widget.hasGoogle)
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Google'),
              trailing: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onTap: _loading ? null : _linkGoogle,
            ),
          if (!widget.hasPassword) ...[
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email/Password'),
              trailing: const Icon(Icons.add),
              onTap: _loading
                  ? null
                  : () => setState(() => _showEmailForm = true),
            ),
            if (_showEmailForm) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _linkEmail,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Link Email'),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
