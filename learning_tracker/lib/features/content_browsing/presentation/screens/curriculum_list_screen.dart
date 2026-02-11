import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';

@RoutePage()
class CurriculumListScreen extends ConsumerWidget {
  const CurriculumListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Content')),
      body: ListView.builder(
        itemCount: CurriculumId.values.length,
        itemBuilder: (context, index) {
          final curriculum = CurriculumId.values[index];
          return _CurriculumListTile(curriculum: curriculum);
        },
      ),
    );
  }
}

class _CurriculumListTile extends ConsumerWidget {
  const _CurriculumListTile({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(curriculumContentProvider(curriculum));

    return contentAsync.when(
      data: (items) {
        final leafCount = items.where((item) => item.isLeaf).length;

        return ListTile(
          leading: Icon(_getIcon(curriculum), size: 40),
          title: Text(
            curriculum.displayNameEn,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            curriculum.displayNameHe,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontFamily: 'Noto Sans Hebrew'),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.left,
          ),
          trailing: Text(
            '$leafCount items',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () {
            context.router.push(
              ContentHierarchyRoute(curriculumId: curriculum.storageKey),
            );
          },
        );
      },
      loading: () => ListTile(
        leading: Icon(_getIcon(curriculum), size: 40),
        title: Text(curriculum.displayNameEn),
        subtitle: const Text('Loading...'),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => ListTile(
        leading: Icon(_getIcon(curriculum), size: 40, color: Colors.red),
        title: Text(curriculum.displayNameEn),
        subtitle: Text('Error: ${error.toString()}'),
      ),
    );
  }

  IconData _getIcon(CurriculumId curriculum) {
    return switch (curriculum) {
      CurriculumId.mishnayos => Icons.menu_book,
      CurriculumId.bavli => Icons.book,
      CurriculumId.yerushalmi => Icons.auto_stories,
      CurriculumId.mishnaBerurah => Icons.library_books,
      CurriculumId.chumash => Icons.import_contacts,
    };
  }
}
