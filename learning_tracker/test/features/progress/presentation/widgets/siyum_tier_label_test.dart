// Tests for siyumTierLabel — the localized label shown next to each tier in
// the siyum-granularity selector.
//
// Asserts the per-curriculum, per-level words resolve from the shared label
// system (never a hardcoded English word) and match the scope the milestone
// emission uses, plus the "Whole {curriculum}" ARB for the curriculum tier.
@Tags(['progress'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_tier_label.dart';

import '../../../../helpers/pump_app.dart';

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride(this._on);
  final bool _on;
  @override
  bool build() => _on;
}

class _VariantOverride extends CurrentTransliterationVariant {
  _VariantOverride();
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

/// Renders the resolved label so tests can read it off the widget tree.
class _Probe extends ConsumerWidget {
  const _Probe({required this.curriculum, required this.level});
  final CurriculumId curriculum;
  final MilestoneLevel level;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(siyumTierLabel(ref, context, curriculum: curriculum, level: level));
}

Future<String> _label(
  WidgetTester tester, {
  required CurriculumId curriculum,
  required MilestoneLevel level,
  bool hebrew = false,
}) async {
  await tester.pumpWidget(
    pumpApp(
      // The UI locale drives which ARB ("Whole …" vs "כל …") backs the
      // curriculum tier; the Hebrew-Terms toggle drives the level words.
      locale: hebrew ? const Locale('he') : const Locale('en'),
      overrides: [
        useHebrewTermsProvider.overrideWith(
          () => _UseHebrewTermsOverride(hebrew),
        ),
        currentTransliterationVariantProvider.overrideWith(
          _VariantOverride.new,
        ),
      ],
      child: _Probe(curriculum: curriculum, level: level),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  group('siyumTierLabel — English (Ashkenazi) level words', () {
    testWidgets('Mishnayos: unit=Masechta, aggregate=Seder', (tester) async {
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.mishnayos,
          level: MilestoneLevel.unit,
        ),
        'Masechta',
      );
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.mishnayos,
          level: MilestoneLevel.aggregate,
        ),
        'Seder',
      );
    });

    testWidgets('Mishneh Torah: unit=Hilchos, aggregate=Sefer', (tester) async {
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.mishnehTorah,
          level: MilestoneLevel.unit,
        ),
        'Hilchos',
      );
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.mishnehTorah,
          level: MilestoneLevel.aggregate,
        ),
        'Sefer',
      );
    });

    testWidgets('Chumash: unit word is Sefer (not the "חומש" display quirk)', (
      tester,
    ) async {
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.chumash,
          level: MilestoneLevel.unit,
        ),
        'Sefer',
      );
    });

    testWidgets('Mishna Berurah: unit=Siman', (tester) async {
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.mishnaBerurah,
          level: MilestoneLevel.unit,
        ),
        'Siman',
      );
    });
  });

  group('siyumTierLabel — curriculum tier renders "Whole {curriculum}"', () {
    testWidgets('Chumash → "Whole Chumash"', (tester) async {
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.chumash,
          level: MilestoneLevel.curriculum,
        ),
        'Whole Chumash',
      );
    });
  });

  group('siyumTierLabel — Hebrew mode is localized', () {
    testWidgets('Mishnayos unit word is מסכת', (tester) async {
      expect(
        await _label(
          tester,
          curriculum: CurriculumId.mishnayos,
          level: MilestoneLevel.unit,
          hebrew: true,
        ),
        'מסכת',
      );
    });

    testWidgets('curriculum tier starts with כל', (tester) async {
      final label = await _label(
        tester,
        curriculum: CurriculumId.chumash,
        level: MilestoneLevel.curriculum,
        hebrew: true,
      );
      expect(label, startsWith('כל'));
    });
  });
}
