import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Stage 7: Name the track with a smart default pre-filled.
///
/// Default is based on program name, scope, or curriculum.
class TrackLabelStep extends StatefulWidget {
  const TrackLabelStep({
    required this.defaultLabel,
    required this.onComplete,
    super.key,
  });

  final String defaultLabel;
  final ValueChanged<String> onComplete;

  @override
  State<TrackLabelStep> createState() => _TrackLabelStepState();
}

class _TrackLabelStepState extends State<TrackLabelStep> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onComplete(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.trackNameThisTrack,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.trackNameSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _controller,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.trackNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _submit,
              child: Text(AppLocalizations.of(context)!.actionContinue),
            ),
          ],
        ),
      ),
    );
  }
}
