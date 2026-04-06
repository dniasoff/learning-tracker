import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';

/// Result returned after the learning process wizard completes.
///
/// Domain-layer wrapper around [WizardResult] — safe to import from
/// domain services without crossing into presentation.
class LearningProcessWizardResult {
  const LearningProcessWizardResult({required this.wizardResult});
  final WizardResult wizardResult;
}
