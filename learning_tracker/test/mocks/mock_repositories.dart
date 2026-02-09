/// Shared mock repositories for testing
/// Uses mocktail (no codegen) as per project standards
library;

import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

// Auth Repository
class MockAuthRepository extends Mock implements AuthRepository {}
