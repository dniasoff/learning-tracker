import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';

@RoutePage()
class TextDisplayScreen extends ConsumerWidget {
  const TextDisplayScreen({
    super.key,
    @PathParam('sefariaRef') required this.sefariaRef,
  });

  final String sefariaRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textAsync = ref.watch(textContentProvider(sefariaRef));
    final fontSize = ref.watch(fontSizeProvider);
    final showNikud = ref.watch(showNikudProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: sefariaRef),
        actions: [
          IconButton(
            icon: Icon(showNikud ? Icons.format_clear : Icons.text_fields),
            tooltip: showNikud ? 'Hide Nikud' : 'Show Nikud',
            onPressed: () => ref.read(showNikudProvider.notifier).toggle(),
          ),
          _FontSizeSelector(currentSize: fontSize),
        ],
      ),
      body: SafeArea(top: false, child: textAsync.when(
        data: (textContent) {
          if (textContent == null) {
            return const _OfflineMessage();
          }
          return _TextContentView(
            textContent: textContent,
            fontSize: fontSize,
            showNikud: showNikud,
          );
        },
        loading: () => const _LoadingView(),
        error: (error, stack) => _ErrorView(error: error),
      )),
    );
  }
}

/// Loading view with spinner and message.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading text...'),
        ],
      ),
    );
  }
}

/// Download required message view.
class _OfflineMessage extends StatelessWidget {
  const _OfflineMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Text content not yet downloaded',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download this curriculum\'s text from the settings to read offline.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.router.push(const SettingsRoute()),
              icon: const Icon(Icons.download),
              label: const Text('Go to Downloads'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to load text',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Font size selector popup menu.
class _FontSizeSelector extends ConsumerWidget {
  const _FontSizeSelector({required this.currentSize});

  final FontSize currentSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<FontSize>(
      icon: const Icon(Icons.format_size),
      tooltip: 'Font Size',
      onSelected: (size) {
        ref.read(fontSizeProvider.notifier).setFontSize(size);
      },
      itemBuilder: (context) => FontSize.values.map((size) {
        return PopupMenuItem<FontSize>(
          value: size,
          child: Row(
            children: [
              if (size == currentSize)
                const Icon(Icons.check, size: 20)
              else
                const SizedBox(width: 20),
              const SizedBox(width: 8),
              Text(size.label),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Main text content view with Hebrew and English text.
class _TextContentView extends StatelessWidget {
  const _TextContentView({
    required this.textContent,
    required this.fontSize,
    required this.showNikud,
  });

  final TextContent textContent;
  final FontSize fontSize;
  final bool showNikud;

  @override
  Widget build(BuildContext context) {
    final displayHebrew = showNikud
        ? textContent.hebrewText
        : HebrewUtils.stripNikud(textContent.hebrewText);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hebrew text (RTL)
          if (textContent.hebrewText.isNotEmpty) ...[
            Text(
              'Hebrew',
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayHebrew,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTextStyles.hebrewBodyLarge.copyWith(
                fontSize: 18 * fontSize.multiplier,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 32),
          ],

          // English text (LTR)
          if (textContent.englishText.isNotEmpty) ...[
            Text(
              'English',
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              textContent.englishText,
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: 16 * fontSize.multiplier,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Mark completion buttons (visible, not wired)
          const _CompletionButtons(),

          const SizedBox(height: 32),

          // Sefaria attribution
          const _SefariaAttribution(),
        ],
      ),
    );
  }
}

/// Mark completion buttons (Epic 3 will wire these).
class _CompletionButtons extends StatelessWidget {
  const _CompletionButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: null, // Not wired yet (Epic 3)
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Mark as Reviewed'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: null, // Not wired yet (Epic 3)
          icon: const Icon(Icons.check_circle),
          label: const Text('Mark Complete'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// Sefaria attribution footer.
class _SefariaAttribution extends StatelessWidget {
  const _SefariaAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Content from Sefaria',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
