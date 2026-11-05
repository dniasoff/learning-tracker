import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/data/repositories/firestore_hidden_content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/hidden_content_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _EmptyContentRepository implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId id) async =>
      throw UnimplementedError();

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => [];

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

void main() {
  testWidgets('shows localized hidden-content actions', (tester) async {
    final hiddenRepository = FirestoreHiddenContentRepository(
      firestore: FakeFirebaseFirestore(),
      ownerUid: 'owner',
      profileId: 'profile',
      resolveFunctions: () async => throw UnimplementedError(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(
            _EmptyContentRepository(),
          ),
          hiddenContentRepositoryProvider.overrideWith(
            (ref) async => hiddenRepository,
          ),
          hiddenContentRefsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HiddenContentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hidden content'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
