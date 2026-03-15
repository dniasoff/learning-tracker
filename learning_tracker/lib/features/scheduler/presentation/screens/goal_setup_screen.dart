import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';

/// Screen for creating or editing a learning goal.
///
/// Renders a form with a target percentage slider (default 100%),
/// Gregorian date picker, and Hebrew date picker toggle.
class GoalSetupScreen extends StatefulWidget {
  final CurriculumId curriculumId;
  final GoalEntity? existingGoal;

  const GoalSetupScreen({
    super.key,
    required this.curriculumId,
    this.existingGoal,
  });

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  late double _targetPercent;
  DateTime? _targetDate;
  bool _useHebrewDate = false;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _targetPercent = widget.existingGoal?.targetPercent ?? 100.0;
    _targetDate = widget.existingGoal?.targetDate;
    _descriptionController = TextEditingController(
      text: widget.existingGoal?.description ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickGregorianDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _targetDate = picked.toUtc());
    }
  }

  Future<void> _pickHebrewDate() async {
    final picked = await HebrewDatePicker.show(
      context,
      initialDate: _targetDate,
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _submit() {
    Navigator.of(context).pop(
      GoalFormResult(
        targetPercent: _targetPercent,
        targetDate: _targetDate,
        description: _descriptionController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingGoal != null ? 'Edit Goal' : 'New Goal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., Finish all Mishnayos by bar mitzvah',
              ),
            ),
            const SizedBox(height: 24),
            // Target percentage slider
            Text(
              'Target: ${_targetPercent.round()}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _targetPercent,
              min: 1,
              max: 100,
              divisions: 99,
              label: '${_targetPercent.round()}%',
              onChanged: (v) => setState(() => _targetPercent = v),
            ),
            const SizedBox(height: 24),
            // Date picker toggle
            SwitchListTile(
              title: const Text('Use Hebrew date'),
              value: _useHebrewDate,
              onChanged: (v) => setState(() => _useHebrewDate = v),
            ),
            const SizedBox(height: 8),
            // Date selection
            ListTile(
              title: Text(
                _targetDate != null
                    ? 'Target: ${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'
                    : 'No deadline (learn at your own pace)',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _useHebrewDate
                        ? _pickHebrewDate
                        : _pickGregorianDate,
                  ),
                  if (_targetDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _targetDate = null),
                    ),
                ],
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _submit,
              child: Text(
                widget.existingGoal != null ? 'Update Goal' : 'Create Goal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Result returned from GoalSetupScreen.
class GoalFormResult {
  final double targetPercent;
  final DateTime? targetDate;
  final String description;

  const GoalFormResult({
    required this.targetPercent,
    this.targetDate,
    this.description = '',
  });
}
