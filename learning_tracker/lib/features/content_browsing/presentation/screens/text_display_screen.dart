import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/reader_phrase_translation.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/segment_with_glosses.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_write_gate.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class TextDisplayScreen extends ConsumerStatefulWidget {
  const TextDisplayScreen({
    super.key,
    @PathParam('sefariaRef') required this.sefariaRef,
  });

  final String sefariaRef;

  @override
  ConsumerState<TextDisplayScreen> createState() => _TextDisplayScreenState();
}

// READER CHEVRON TAP-SWALLOW FIX (deferred item, run11-acceptance-sweep):
// the ref currently on screen used to be `widget.sefariaRef` directly, and
// the prev/next chevrons advanced by calling `context.router.replace(...)`
// with the adjacent ref — a FULL ROUTE REPLACE that tears down this widget
// and mounts a brand-new one for the new ref. Rebuilding from scratch means
// `adjacentContentRefsProvider(newRef)` (async — it awaits
// `curriculumContentProvider`) starts back at AsyncLoading, and with no
// listener bridging the gap `curriculumContentProvider` itself gets
// auto-disposed and must re-fetch from scratch. During that
// replace+rebuild+recompute window both chevrons render `onPressed: null`
// (disabled) — a real user's rapid taps land on a disabled button and are
// silently dropped (Flutter never queues a tap on a disabled control), not
// merely debounced.
//
// Fix has two parts, both needed to close the window completely:
//
//  1. The displayed ref is now in-widget STATE (`_currentRef`, seeded from
//     `widget.sefariaRef` once). Prev/next mutate that state directly
//     (`setState`) instead of navigating — no route transition, no widget
//     teardown. Deep-linking is unaffected: the state is still seeded from
//     the route's path param, so a direct `/text/<ref>` link (a genuinely
//     NEW `TextDisplayScreen` instance) opens exactly where it should.
//
//  2. Adjacency is now read SYNCHRONOUSLY off [ContentIndex.adjacent] (an
//     O(1) lookup already used elsewhere, e.g. the related adapter)
//     instead of the async `adjacentContentRefsProvider`. Measured (widget
//     test, real navigation vs. real setState): even with local state, an
//     async family provider re-keyed per ref still shows one real
//     (frame-boundary) `AsyncLoading` gap after every tap, which is enough
//     for a rapid-tap sequence to hit a momentarily-disabled button and
//     drop a tap. `contentIndexProvider` is keepAlive and, once warm (it is
//     already a dependency of this screen for the curriculum-name prefix
//     below), `.adjacent(ref)` returns instantly with no async gap at all
//     — so every chevron tap synchronously computes the next state, with
//     nothing to race.
class _TextDisplayScreenState extends ConsumerState<TextDisplayScreen> {
  late String _currentRef = widget.sefariaRef;

  @override
  Widget build(BuildContext context) {
    final sefariaRef = _currentRef;
    final textAsync = ref.watch(textContentProvider(sefariaRef));
    final fontSize = ref.watch(fontSizeProvider);
    final showNikud = ref.watch(showNikudProvider);
    final showTranslation = ref.watch(showReaderTranslationProvider);
    final translationLanguage = ref.watch(readerTranslationLanguageProvider);
    final theme = Theme.of(context);

    // Single label renderer drives the AppBar — full breadcrumb chain so
    // the user always knows where they are (Sefer › Perek › Mishna / Daf).
    // Wraps onto multiple lines if needed; the AppBar grows to fit.
    final chainAsync = ref.watch(renderedDisplayForRefProvider(sefariaRef));
    final chainTitle = chainAsync.when(
      data: (v) => v,
      loading: () => '…',
      error: (_, __) => sefariaRef.replaceAll('_', ' '),
    );

    // contentIndexProvider is keepAlive so the lookup is O(1) once warm —
    // shared with the curriculum-name resolution below (#16), and now also
    // the source of prev/next adjacency (see the fix note above).
    final contentIndex = ref.watch(contentIndexProvider).asData?.value;
    final adj = contentIndex?.adjacent(sefariaRef);
    final prevRef = adj?.prev?.sefariaRef;
    final nextRef = adj?.next?.sefariaRef;

    // #14 — fire-and-forget background prefetch so the SQLite read is warm
    // before the user taps ‹ or ›, eliminating the ~8s "Loading text…" spinner.
    // Uses ref.read (non-reactive) + .ignore() to swallow both the result and
    // any error; textContentProvider is auto-dispose so no leak occurs.
    if (nextRef != null) {
      ref.read(textContentProvider(nextRef).future).ignore();
    }
    if (prevRef != null) {
      ref.read(textContentProvider(prevRef).future).ignore();
    }

    // #16 — resolve the curriculum root name so the AppBar title can
    // disambiguate shared seder/masechta names (e.g. ברכות in Mishnah vs Bavli).
    final curriculumId = contentIndex != null
        ? _curriculumIdForRef(sefariaRef, contentIndex)
        : null;
    final curriculumName = curriculumId != null
        ? curriculumLabelText(ref, curriculum: curriculumId)
        : null;

    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          curriculumName != null ? '$curriculumName › $chainTitle' : chainTitle,
          textAlign: TextAlign.center,
          maxLines: 3,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: context.colors.brandInk,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        actions: [
          if ((textAsync.asData?.value?.segments.any(
                    (segment) => segment.englishText.isNotEmpty,
                  ) ??
                  false) ||
              (translationLanguage != 'sefaria' &&
                  (textAsync.asData?.value?.hebrewText.isNotEmpty ?? false)))
            IconButton(
              key: const Key('text_display_translation_toggle'),
              icon: Icon(showTranslation ? Icons.translate : Icons.g_translate),
              tooltip: showTranslation
                  ? AppLocalizations.of(context)!.textReaderHideTranslation
                  : AppLocalizations.of(context)!.textReaderShowTranslation,
              onPressed: () => ref
                  .read(showReaderTranslationProvider.notifier)
                  .set(!showTranslation),
            ),
          if (textAsync.asData?.value?.hebrewText.isNotEmpty ?? false)
            IconButton(
              key: const Key('text_display_language_picker'),
              icon: const Icon(Icons.language),
              tooltip: AppLocalizations.of(
                context,
              )!.textReaderTranslationLanguage,
              onPressed: () => _showTranslationLanguagePicker(
                context,
                ref,
                translationLanguage,
              ),
            ),
          IconButton(
            key: const Key('text_display_prev_button'),
            icon: const Icon(Icons.chevron_left),
            tooltip: AppLocalizations.of(context)!.textReaderTooltipPrevious,
            onPressed: prevRef != null
                ? () => setState(() => _currentRef = prevRef)
                : null,
          ),
          IconButton(
            key: const Key('text_display_next_button'),
            icon: const Icon(Icons.chevron_right),
            tooltip: AppLocalizations.of(context)!.textReaderTooltipNext,
            onPressed: nextRef != null
                ? () => setState(() => _currentRef = nextRef)
                : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: textAsync.when(
          data: (textContent) {
            if (textContent == null) {
              return const _OfflineMessage();
            }
            return _TextContentView(
              textContent: textContent,
              fontSize: fontSize,
              showNikud: showNikud,
              showTranslation: showTranslation,
              translationLanguage: translationLanguage,
              sefariaRef: sefariaRef,
            );
          },
          loading: () => const _LoadingView(),
          error: (error, stack) => const _ErrorView(),
        ),
      ),
    );
  }
}

Future<void> _showTranslationLanguagePicker(
  BuildContext context,
  WidgetRef ref,
  String selected,
) async {
  final isHebrew = Localizations.localeOf(context).languageCode == 'he';
  final l10n = AppLocalizations.of(context)!;
  var query = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final languages = readerLanguages.where((language) {
            final search =
                '${language.code} ${language.nativeName} ${language.englishName} ${language.hebrewName}'
                    .toLowerCase();
            return search.contains(query.toLowerCase());
          });
          return AlertDialog(
            title: Text(l10n.textReaderTranslationLanguageDialogTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('text_display_language_search'),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.textReaderSearchLanguages,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          key: const Key('reader_language_sefaria'),
                          title: Text(l10n.textReaderSefariaEnglish),
                          subtitle: Text(l10n.textReaderOfflineLabel),
                          trailing: selected == 'sefaria'
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            ref
                                .read(
                                  readerTranslationLanguageProvider.notifier,
                                )
                                .setLanguage('sefaria');
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        for (final language in languages)
                          ListTile(
                            key: Key('reader_language_${language.code}'),
                            title: Text(language.label(isHebrew)),
                            trailing: selected == language.code
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () {
                              ref
                                  .read(
                                    readerTranslationLanguageProvider.notifier,
                                  )
                                  .setLanguage(language.code);
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.textReaderClose),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Maps [sefariaRef] to its [CurriculumId] via the pre-built [ContentIndex].
/// Returns null when the ref is not found or the storage key is unrecognised.
CurriculumId? _curriculumIdForRef(String sefariaRef, ContentIndex index) {
  final item = index.lookup(sefariaRef);
  if (item == null) return null;
  return CurriculumId.fromStorageKey(item.curriculumId);
}

/// Loading view with spinner and message.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.loadingText),
        ],
      ),
    );
  }
}

/// Message shown when text is unavailable (not cached and API unreachable).
class _OfflineMessage extends StatelessWidget {
  const _OfflineMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.textReaderTextUnavailableTitle,
              style: AppTextStyles.titleMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.textReaderCheckConnection,
              style: AppTextStyles.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view.
class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.textReaderFailedToLoad,
            style: AppTextStyles.titleMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.textReaderCheckConnection,
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Main text content view redesigned as a learning reader.
class _TextContentView extends StatelessWidget {
  const _TextContentView({
    required this.textContent,
    required this.fontSize,
    required this.showNikud,
    required this.showTranslation,
    required this.translationLanguage,
    required this.sefariaRef,
  });

  final TextContent textContent;
  final FontSize fontSize;
  final bool showNikud;
  final bool showTranslation;
  final String translationLanguage;
  final String sefariaRef;

  @override
  Widget build(BuildContext context) {
    final segments = textContent.segments
        .where(
          (s) =>
              s.hebrewText.isNotEmpty ||
              (showTranslation &&
                  translationLanguage == 'sefaria' &&
                  s.englishText.isNotEmpty),
        )
        .toList(growable: false);
    final showSegmentNumbers =
        segments.length > 1 && segments.any((s) => s.number != null);
    final hasHebrew = textContent.hebrewText.isNotEmpty;
    final hasContent = segments.isNotEmpty;
    final label = hasHebrew
        ? AppLocalizations.of(context)!.textReaderHebrewTab
        : AppLocalizations.of(context)!.textReaderEnglishTab;
    final labelBackground = hasHebrew
        ? context.colors.statusDanger
        : context.colors.brandBlue;
    final alignLabelRight = !hasHebrew;
    final hebrewStyle = AppTextStyles.hebrewBodyLarge.copyWith(
      fontSize: 26 * fontSize.multiplier,
      height: 1.65,
      color: context.colors.brandInk,
    );
    final glossStyle = AppTextStyles.bodyLarge.copyWith(
      fontSize: 15 * fontSize.multiplier,
      height: 1.45,
      color: context.colors.brandInk.withValues(alpha: 0.78),
    );

    return CustomScrollView(
      slivers: [
        if (hasContent)
          SliverPadding(
            // Preserve the original card inset; the floating section label
            // remains positioned independently above the card edge.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            sliver: SliverList.builder(
              itemCount: segments.length,
              itemBuilder: (context, index) => _ReaderSegmentCard(
                key: ValueKey('reader_segment_${segments[index].sefariaRef}'),
                segment: segments[index],
                isFirst: index == 0,
                isLast: index == segments.length - 1,
                label: label,
                labelBackground: labelBackground,
                alignLabelRight: alignLabelRight,
                showNumber:
                    showSegmentNumbers && segments[index].number != null,
                showNikud: showNikud,
                showTranslation: showTranslation,
                translationLanguage: translationLanguage,
                hebrewStyle: hebrewStyle,
                glossStyle: glossStyle,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: context.colors.surfaceF5,
              border: Border(
                top: BorderSide(
                  color: context.colors.brandOutline.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: _CompletionSection(sefariaRef: sefariaRef),
          ),
        ),
      ],
    );
  }
}

/// A lazily-built segment in the continuous source-and-gloss reader card.
class _ReaderSegmentCard extends ConsumerWidget {
  const _ReaderSegmentCard({
    super.key,
    required this.segment,
    required this.isFirst,
    required this.isLast,
    required this.label,
    required this.labelBackground,
    required this.alignLabelRight,
    required this.showNumber,
    required this.showNikud,
    required this.showTranslation,
    required this.translationLanguage,
    required this.hebrewStyle,
    required this.glossStyle,
  });

  final TextSegment segment;
  final bool isFirst;
  final bool isLast;
  final String label;
  final Color labelBackground;
  final bool alignLabelRight;
  final bool showNumber;
  final bool showNikud;
  final bool showTranslation;
  final String translationLanguage;
  final TextStyle hebrewStyle;
  final TextStyle glossStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.only(
      topLeft: isFirst ? const Radius.circular(28) : Radius.zero,
      topRight: isFirst ? const Radius.circular(28) : Radius.zero,
      bottomLeft: isLast ? const Radius.circular(28) : Radius.zero,
      bottomRight: isLast ? const Radius.circular(28) : Radius.zero,
    );
    final borderSide = BorderSide(
      color: context.colors.brandOutline.withValues(alpha: 0.45),
    );
    final card = Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        isFirst ? 26 : 0,
        20,
        isLast ? 18 : 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: context.colors.brandInk.withValues(alpha: 0.04),
                  blurRadius: 11,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
        border: Border(
          left: borderSide,
          right: borderSide,
          top: isFirst ? borderSide : BorderSide.none,
          bottom: isLast ? borderSide : BorderSide.none,
        ),
      ),
      child: SegmentWithGlosses(
        segment: segment,
        glosses:
            showTranslation &&
                translationLanguage == 'sefaria' &&
                segment.englishText.isNotEmpty
            ? [
                SegmentGloss(
                  text: segment.englishText,
                  direction: TextDirection.ltr,
                  style: glossStyle,
                  marker:
                      segment.hebrewText.isEmpty &&
                          showNumber &&
                          segment.number != null
                      ? segment.number.toString()
                      : null,
                ),
              ]
            : showTranslation &&
                  translationLanguage != 'sefaria' &&
                  segment.hebrewText.isNotEmpty
            ? _aiGlosses(context, ref, segment, translationLanguage, glossStyle)
            : const [],
        showNumber: showNumber,
        showNikud: showNikud,
        hebrewStyle: hebrewStyle,
      ),
    );
    if (!isFirst) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -12,
          left: alignLabelRight ? null : 0,
          right: alignLabelRight ? 0 : null,
          child: _ReaderSectionLabel(label: label, background: labelBackground),
        ),
      ],
    );
  }

  List<SegmentGloss> _aiGlosses(
    BuildContext context,
    WidgetRef ref,
    TextSegment segment,
    String language,
    TextStyle style,
  ) {
    final async = ref.watch(
      phraseTranslationProvider(
        PhraseTranslationKey(segment.sefariaRef, language),
      ),
    );
    final l10n = AppLocalizations.of(context)!;
    final values = <SegmentGloss>[];
    if (async.hasValue) {
      for (final phrase in async.requireValue) {
        values.add(
          SegmentGloss(
            text: phrase.source,
            direction: TextDirection.rtl,
            style: style.copyWith(fontSize: style.fontSize! * .92),
          ),
        );
        values.add(
          SegmentGloss(
            text: phrase.translation,
            direction: TextDirection.ltr,
            style: style,
          ),
        );
      }
      values.add(
        SegmentGloss(
          text: l10n.textReaderMachineTranslated,
          direction: TextDirection.ltr,
          style: style.copyWith(
            fontSize: style.fontSize! * .75,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
      return values;
    }
    if (async.isLoading) {
      values.add(
        SegmentGloss(
          text: l10n.textReaderLoadingTranslation,
          direction: TextDirection.ltr,
          style: style,
        ),
      );
    } else {
      values.add(
        SegmentGloss(
          text: l10n.textReaderTranslationUnavailable,
          direction: TextDirection.ltr,
          style: style.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      );
      if (segment.englishText.isNotEmpty)
        values.add(
          SegmentGloss(
            text: segment.englishText,
            direction: TextDirection.ltr,
            style: style,
          ),
        );
      values.add(
        SegmentGloss(
          text: l10n.textReaderRetryTranslation,
          direction: TextDirection.ltr,
          style: style.copyWith(decoration: TextDecoration.underline),
          onTap: () => ref.invalidate(
            phraseTranslationProvider(
              PhraseTranslationKey(segment.sefariaRef, language),
            ),
          ),
        ),
      );
    }
    if (segment.englishText.isNotEmpty && async.isLoading)
      values.add(
        SegmentGloss(
          text: segment.englishText,
          direction: TextDirection.ltr,
          style: style,
        ),
      );
    return values;
  }
}

class _ReaderSectionLabel extends StatelessWidget {
  const _ReaderSectionLabel({required this.label, required this.background});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.26),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Next distinct daily-task item in [tasks] after any entries that share
/// [currentRef] (same reader URL).
DailyTask? _nextDailyTaskAfter(List<DailyTask> tasks, String currentRef) {
  final firstIdx = tasks.indexWhere(
    (t) => t.contentItemSefariaRef == currentRef,
  );
  if (firstIdx < 0) return null;
  var i = firstIdx;
  while (i < tasks.length && tasks[i].contentItemSefariaRef == currentRef) {
    i++;
  }
  if (i >= tasks.length) return null;
  return tasks[i];
}

/// Like [_nextDailyTaskAfter] but skips a SET of just-completed refs — used by
/// daf-atomic completion, where one mark clears both amudim of a daf, so the
/// next task must skip past every ref in the marked daf.
DailyTask? _nextDailyTaskAfterRefs(List<DailyTask> tasks, Set<String> refs) {
  final firstIdx = tasks.indexWhere(
    (t) => refs.contains(t.contentItemSefariaRef),
  );
  if (firstIdx < 0) return null;
  for (var i = firstIdx + 1; i < tasks.length; i++) {
    if (!refs.contains(tasks[i].contentItemSefariaRef)) return tasks[i];
  }
  return null;
}

/// Mark completion section. Resolves the curriculum + stage for this sefariaRef
/// from today's scheduled tasks, then records the task's refs as ONE
/// `LearningCommands.capture` (Story 1.11, DNI-473: a `main`, `dated` batch
/// whose `pts_` entries the command attaches, AD-50), offers Undo for exactly
/// that batch (UX-DR-154) and rolls the optimistic "done" state back when the
/// server rejects it for good (UX-DR-107/147).
class _CompletionSection extends ConsumerStatefulWidget {
  const _CompletionSection({required this.sefariaRef});

  final String sefariaRef;

  @override
  ConsumerState<_CompletionSection> createState() => _CompletionSectionState();
}

class _CompletionSectionState extends ConsumerState<_CompletionSection> {
  bool _saving = false;

  /// The content refs to complete for [task]. On a COARSE-paced track
  /// (paceGranularity = daf/perek/seif) this returns every leaf of the current
  /// coarse unit — the daf's amudim (e.g. 2a + 2b) — so one mark completes the
  /// whole daf. On a fine/leaf-paced track it returns just the current ref.
  Future<List<String>> _refsToMark(DailyTask task) async {
    final goals = await ref
        .read(goalRepositoryProvider)
        .getGoals(task.curriculumId);
    final goal = goals.firstOrNull;
    final isCoarse = goal?.paceGranularity != null;
    if (!isCoarse) return [widget.sefariaRef];
    final items = await ref.read(
      curriculumContentProvider(task.curriculumId).future,
    );
    return coarseUnitLeafRefs(items, widget.sefariaRef);
  }

  /// The optimistic "done" key of each event this section recorded, so a
  /// permanent rejection or an Undo rolls back exactly those refs.
  final _keysByEvent = <String, String>{};

  // Read once while mounted: an Undo tapped after this reader has moved on
  // to the next task (the snackbar outlives the route) still rolls back.
  late final OptimisticCompletionState _optimistic;
  late final CompletionCommitted _committed;

  @override
  void initState() {
    super.initState();
    _optimistic = ref.read(optimisticCompletionStateProvider.notifier);
    _committed = ref.read(completionCommittedProvider.notifier);
  }

  void _applyOptimistic(Map<String, String> keysByEvent) {
    _keysByEvent.addAll(keysByEvent);
    keysByEvent.values.forEach(_optimistic.add);
    _committed.increment();
  }

  void _rollBack(Iterable<String> eventIds) {
    for (final id in eventIds) {
      final key = _keysByEvent.remove(id);
      if (key != null) _optimistic.remove(key);
    }
    _committed.increment();
  }

  /// A retried failure was saved: re-apply the refs this section recorded
  /// under its (unchanged) event ids.
  void _reapply(PendingFailure failure) => _applyOptimistic({
    for (final id in failure.eventIds)
      if (_recordedKeys[id] case final key?) id: key,
  });

  /// Every key this section recorded, by event id, kept for a successful
  /// retry after a rollback (a retry re-sends the same event ids).
  final _recordedKeys = <String, String>{};

  Future<void> _handleComplete(
    DailyTask task,
    String trackType, {
    required ResolvedSession session,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final tasksBefore = await ref.read(allDailyTasksProvider.future);

      // Phase 2a — daf-atomic marking: on a COARSE-paced track (daf/perek/seif)
      // one mark completes the WHOLE coarse unit (e.g. both amudim 2a+2b of a
      // daf), because the daf — not the amud — is the unit the learner marks.
      // Story 1.11 (DNI-473): the whole unit is ONE capture (one tap, one
      // batch): one learn event per amud, in task order.
      final markRefs = await _refsToMark(task);
      final nextAfterComplete = _nextDailyTaskAfterRefs(
        tasksBefore,
        markRefs.toSet(),
      );

      // H1: the live completion routes through MarkLiveCompletionUseCase by
      // session role. AC-6 (DNI-473): the owner branch writes through
      // LearningCommands.capture. DNI-486: the tutor branch is the talmid's
      // TutorLearningCommands.capture, whose one write is
      // TutorWriteService.recordLearning (no client Firestore write, and no
      // result before the callable answers).
      final markLiveUseCase = MarkLiveCompletionUseCase<CaptureResult>(
        session: session,
      );
      Future<CaptureResult> capture(LearningCommands? commands) {
        if (commands == null) throw const _NoActiveLearnerException();
        _commands = commands;
        return commands.capture(
          curriculumId: task.curriculumId.storageKey,
          refs: markRefs,
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
          stage: task.stageOrder,
          gesture: CaptureGesture.taskTick,
          taps: 1,
        );
      }

      final result = await markLiveUseCase.call(
        () async => capture(await ref.read(learningCommandsProvider.future)),
        tutorWrite: () async =>
            capture(await ref.read(tutorLearningCommandsProvider.future)),
      );
      final commands = _commands!;

      final keys = [
        for (final markRef in markRefs)
          optimisticKey(
            sefariaRef: markRef,
            stageId: task.stageOrder,
            trackType: trackType,
          ),
      ];
      // A tutor capture stamped inside the learner's lock is kept but not
      // counted (DNI-486 AC-7): it changes nothing on screen.
      final recorded = result is CaptureSuccess
          ? {
              for (
                var i = 0;
                i < result.eventIds.length && i < keys.length;
                i++
              )
                if (!result.keptNotCounted.contains(result.eventIds[i]))
                  result.eventIds[i]: keys[i],
            }
          : const <String, String>{};
      if (recorded.isNotEmpty) {
        _recordedKeys.addAll(recorded);
        _applyOptimistic(recorded);
      }

      if (mounted) {
        setState(() => _saving = false);
      }
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      showCaptureOutcome(
        context,
        result: result,
        commands: commands,
        message: AppLocalizations.of(context)!.markedComplete,
        messenger: messenger,
        onUndone: () => _rollBack(recorded.keys),
        learnerName: ref.read(tutorLearnerNameProvider),
      );

      if (recorded.isNotEmpty && mounted && nextAfterComplete != null) {
        await context.router.replace(
          TextDisplayRoute(sefariaRef: nextAfterComplete.contentItemSefariaRef),
        );
      }
    } on Exception catch (e, st) {
      // Typed so a programming-error Error subtype (TypeError/StateError)
      // escaping the mark-completion path propagates to the zone's
      // uncaught-error handler instead of being shown as an ordinary
      // "Could not save" snackbar, same as any other expected write
      // failure (AUD-content_browsing-09, EH-4).
      AppLogger.instance.error(
        event: 'Failed to mark completion',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotSave(e.toString()),
            ),
            // warningSnackbarFill (not brandWarningDeep): brandWarningDeep is
            // an INK role that lightens in dark mode for text-on-tint use —
            // used as a SnackBar FILL it washed out to pale cream in dark,
            // dropping the theme's default near-white content text to a
            // measured 1.36:1. warningSnackbarFill stays deep in both themes
            // so that default text stays legible (AUD content-and-learning
            // dark-mode burndown).
            backgroundColor: context.colors.warningSnackbarFill,
          ),
        );
      }
    }
  }

  LearningCommands? _commands;

  // W6.15/W6.17 / WS3.3e (DEC-21): Returns true only when the current user
  // is *actively viewing a talmid's profile context* (i.e. has passed the
  // TutorPinEntryGate for a specific child). When true, live-mark actions
  // are disabled (FR-3, FR-6.2).
  //
  // Fix for DEC-21 dual-role bug: previously checked incomingTutorGrantsProvider,
  // which returned true whenever the user had ANY active grant — causing a tutor
  // who also has their own adult profile to have live-mark wrongly disabled on
  // their *own* profile. The correct gate is the active selection provider,
  // which is non-null only while inside a specific talmid's context.
  bool _isTutorSession(WidgetRef ref) {
    return ref.watch(activeTutoredProfileSelectionProvider) != null;
  }

  // H1: Build a ResolvedSession that reflects the current user's role so
  // _handleComplete can route through MarkLiveCompletionUseCase.
  // The session only needs to carry the correct isTutorSession flag — the
  // profile/grant details are not required for the domain guard.
  ResolvedSession _sessionForCurrentUser(WidgetRef ref, bool isTutor) {
    if (isTutor) {
      // L3: use the real active tutored selection (carries the talmid's
      // profile, grant id, and the parent-configured permissions) instead of
      // an empty placeholder. Falls back to a minimal selection only if the
      // provider is somehow null while isTutor is true (should not happen,
      // since isTutor is derived from the same provider).
      final selection = ref.read(activeTutoredProfileSelectionProvider);
      return ResolvedSession.forTutor(
        selection:
            selection ??
            const TutoredProfileSelection(
              profileId: '',
              ownerUid: '',
              grantId: '',
              permissions: TutorPermissions(),
            ),
      );
    }
    return ResolvedSession.forOwner(
      selection: const OwnProfileSelection(profileId: '', ownerUid: ''),
      isChildMode: false,
    );
  }

  @override
  Widget build(BuildContext context) => PendingCaptureFailureListener(
    onFailure: (failure) => _rollBack(failure.eventIds),
    onRetried: _reapply,
    child: _buildSection(context),
  );

  Widget _buildSection(BuildContext context) {
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);

    return dailyTasksAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          Icon(
            Icons.error_outline,
            color: context.colors.brandWarning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              )!.unableToLoadCompletionContext(e.toString()),
              style: TextStyle(
                fontSize: 13,
                color: context.colors.brandInkMuted,
              ),
            ),
          ),
        ],
      ),
      data: (tasks) {
        final matches = tasks.where(
          (t) => t.contentItemSefariaRef == widget.sefariaRef,
        );
        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        final task = matches.first;
        final nextTask = _nextDailyTaskAfter(tasks, widget.sefariaRef);
        final trackTypeAsync = ref.watch(
          trackStorageKeyForTrackIdProvider(task.curriculumId),
        );
        return trackTypeAsync.when(
          loading: () => const SizedBox(
            height: 44,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (trackType) {
            final completedByOrderParams = (
              sefariaRef: widget.sefariaRef,
              stageId: task.stageOrder,
              trackType: trackType,
            );
            final isCompletedByOrderAsync = ref.watch(
              isStageCompletedProvider(completedByOrderParams),
            );

            final completionError = isCompletedByOrderAsync.hasError
                ? isCompletedByOrderAsync.error!
                : null;
            if (completionError != null) {
              return SizedBox(
                height: 110,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: context.colors.brandWarning,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.errorGeneric(completionError.toString()),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.brandInkMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Reuse the single completion signal so the reader
                        // stays a pure consumer of completion state.
                        ref
                            .read(completionCommittedProvider.notifier)
                            .increment();
                      },
                      child: Text(AppLocalizations.of(context)!.actionRetry),
                    ),
                  ],
                ),
              );
            }
            if (isCompletedByOrderAsync.asData == null) {
              return const SizedBox(
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final isDone = isCompletedByOrderAsync.requireValue;

            final nextLabel =
                AppLocalizations.of(context)?.textReaderNextDailyTask ??
                'Next daily task';

            // DNI-486: a tutor records the talmid's learning through the
            // tutor callables (deviation #7); without the parent's
            // `can_edit_learning` the control stays visible but disabled.
            final isTutor = _isTutorSession(ref);
            // AC-4/AC-5/AC-6: without the parent's canEditLearning, offline,
            // or with the talmid locked, the tutor's button stays visible but
            // disabled (40%, disabled semantics) with one note saying why.
            final tutorBlocked =
                isTutor &&
                ref.watch(tutorWriteAvailabilityProvider).blocksTutor;
            final l10n = AppLocalizations.of(context)!;

            // R2: SafeArea(top:false) so the mark-complete / next-task buttons
            // are never clipped by the system navigation-bar inset at the bottom.
            return SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // W6.17/W6.18: Wrap in Tooltip when disabled due to tutor mode.
                  TutorDisabledControl(
                    blocked: tutorBlocked,
                    child: Tooltip(
                      // W6.18: Tooltip text — shown only when the button is
                      // disabled for tutor reasons (not for "already done").
                      message: tutorBlocked
                          ? tutorWriteNoteText(
                                  l10n,
                                  ref.watch(tutorWriteAvailabilityProvider),
                                ) ??
                                ''
                          : '',
                      child: FilledButton(
                        // W6.17: Disable for tutors regardless of isDone state.
                        // H1: session is passed so _handleComplete routes through
                        // MarkLiveCompletionUseCase for domain-layer enforcement.
                        onPressed: (_saving || isDone || tutorBlocked)
                            ? null
                            : () => _handleComplete(
                                task,
                                trackType,
                                session: _sessionForCurrentUser(ref, isTutor),
                              ),
                        style: FilledButton.styleFrom(
                          // W6.17: When in tutor mode, show a muted amber
                          // colour to visually communicate the disabled state.
                          backgroundColor: tutorBlocked
                              ? context.colors.goldAmber.withValues(alpha: 0.3)
                              : isDone
                              ? context.colors.brandGoldDeep
                              : context.colors.brandBlue,
                          // AUD-content_browsing-08: theme's onPrimary token
                          // (matches error_display.dart / app_error_view.dart)
                          // instead of a raw Colors.white literal — onPrimary
                          // is white in both the light and dark theme today,
                          // but repaints if that ever changes.
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          elevation: tutorBlocked ? 0 : 2,
                          disabledBackgroundColor: tutorBlocked
                              ? context.colors.goldAmber.withValues(alpha: 0.2)
                              : null,
                          disabledForegroundColor: tutorBlocked
                              ? context.colors.goldAmber.withValues(alpha: 0.7)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saving)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colors.brandCreamCard,
                                ),
                              )
                            else
                              Icon(
                                // W6.17: When tutor, show a school/lock icon.
                                tutorBlocked
                                    ? Icons.school_rounded
                                    : isDone
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline_rounded,
                                size: 20,
                              ),
                            const SizedBox(width: 10),
                            Text(
                              tutorBlocked
                                  ? l10n.markCompleteTutorUnavailable
                                  : isDone
                                  ? l10n.markCompleteCompletedStage(
                                      domainTermLabels(
                                        ref,
                                      ).resolveStoredStageName(task.stageName),
                                    )
                                  : l10n.markComplete,
                              style: const TextStyle(
                                fontSize: 31 / 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isTutor)
                    const TutorWriteNote(padding: EdgeInsets.only(top: 8)),
                  if (nextTask != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.router.replace(
                        TextDisplayRoute(
                          sefariaRef: nextTask.contentItemSefariaRef,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        nextLabel,
                        style: const TextStyle(
                          fontSize: 31 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: BorderSide(
                          color: context.colors.brandBlue.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The learning commands are not available (no active learner, or the
/// account is not ready): nothing was recorded.
class _NoActiveLearnerException implements Exception {
  const _NoActiveLearnerException();

  @override
  String toString() => 'no active learner';
}
