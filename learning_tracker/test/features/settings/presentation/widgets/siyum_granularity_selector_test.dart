// Widget tests for SiyumGranularitySelector (TQ-3: pumped through the shared
// `pumpApp` rig, which wires GlobalCupertinoLocalizations + the other l10n
// delegates).
//
// Verifies:
//   * a Mishnayos-family curriculum (multi-seder content) offers 3 tiers;
//   * Chumash (level-1-only content) offers 2 tiers;
//   * tapping a tier drives the real `siyumGranularityProvider` notifier and
//     persists the choice to SharedPreferences.
//
// The tier count flows through the REAL `availableSiyumTiersProvider` (hence
// the real `_hasAggregateLevel`) over pinned content, so these tests also
// pin the aggregate-detection behaviour end to end.
@Tags(['settings'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/siyum_granularity_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final String _id;
  @override
  String build() => _id;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride();
  @override
  bool build() => false;
}

class _VariantOverride extends CurrentTransliterationVariant {
  _VariantOverride();
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

/// Mishnayos content with two sederim (each with two masechtos) — a meaningful
/// aggregate tier (2 groups) → 3 tiers offered.
List<ContentItem> _mishnayosContent() => const [
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Berakhot',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berakhot',
    sefariaRef: 'Mishnah Berakhot 1.1',
    sortOrder: 0,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Peah',
    displayNameHe: 'פאה',
    displayNameEn: 'Peah',
    sefariaRef: 'Mishnah Peah 1.1',
    sortOrder: 1,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Moed',
    level2: 'Shabbat',
    displayNameHe: 'שבת',
    displayNameEn: 'Shabbat',
    sefariaRef: 'Mishnah Shabbat 1.1',
    sortOrder: 2,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Moed',
    level2: 'Eruvin',
    displayNameHe: 'עירובין',
    displayNameEn: 'Eruvin',
    sefariaRef: 'Mishnah Eruvin 1.1',
    sortOrder: 3,
    isLeaf: true,
  ),
];

/// Chumash content — level-1-only (sefer IS the unit, no aggregate) → 2 tiers.
List<ContentItem> _chumashContent() => const [
  ContentItem(
    curriculumId: 'chumash',
    level1: 'Bereshit',
    displayNameHe: 'בראשית',
    displayNameEn: 'Bereshit',
    sefariaRef: 'Bereshit 1.1',
    sortOrder: 0,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'chumash',
    level1: 'Shemot',
    displayNameHe: 'שמות',
    displayNameEn: 'Shemot',
    sefariaRef: 'Shemot 1.1',
    sortOrder: 1,
    isLeaf: true,
  ),
];

ProviderContainer _container({
  required CurriculumId curriculum,
  required List<ContentItem> content,
}) {
  final container = ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(
        () => _ProfileIdOverride(_profileId),
      ),
      useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
      currentTransliterationVariantProvider.overrideWith(_VariantOverride.new),
      curriculumContentProvider(
        curriculum,
      ).overrideWith((ref) => Future.value(content)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Mishnayos (multi-seder) offers 3 tiers', (tester) async {
    final container = _container(
      curriculum: CurriculumId.mishnayos,
      content: _mishnayosContent(),
    );
    await tester.pumpWidget(
      pumpApp(
        container: container,
        child: const Scaffold(
          body: SiyumGranularitySelector(curriculum: CurriculumId.mishnayos),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(RadioListTile<MilestoneLevel>),
      findsNWidgets(3),
      reason: 'unit (Masechta) + aggregate (Seder) + whole → 3 tiers',
    );
  });

  testWidgets('Chumash (level-1-only) offers 2 tiers', (tester) async {
    final container = _container(
      curriculum: CurriculumId.chumash,
      content: _chumashContent(),
    );
    await tester.pumpWidget(
      pumpApp(
        container: container,
        child: const Scaffold(
          body: SiyumGranularitySelector(curriculum: CurriculumId.chumash),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(RadioListTile<MilestoneLevel>),
      findsNWidgets(2),
      reason: 'Chumash has no aggregate tier → unit (Sefer) + whole only',
    );
  });

  testWidgets('selecting a tier persists it (unit → curriculum)', (
    tester,
  ) async {
    final container = _container(
      curriculum: CurriculumId.chumash,
      content: _chumashContent(),
    );
    await tester.pumpWidget(
      pumpApp(
        container: container,
        child: const Scaffold(
          body: SiyumGranularitySelector(curriculum: CurriculumId.chumash),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(siyumGranularityProvider(CurriculumId.chumash)),
      MilestoneLevel.unit,
      reason: 'starts at the default finest tier',
    );

    // Order is finest → coarsest, so the last radio is the whole-curriculum
    // (coarsest) tier.
    await tester.tap(find.byType(RadioListTile<MilestoneLevel>).last);
    await tester.pumpAndSettle();

    expect(
      container.read(siyumGranularityProvider(CurriculumId.chumash)),
      MilestoneLevel.curriculum,
      reason: 'tapping the whole-curriculum radio updates the provider',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('siyum_granularity_p${_profileId}_chumash'),
      MilestoneLevel.curriculum.name,
      reason: 'the choice is persisted to SharedPreferences',
    );
  });
}
