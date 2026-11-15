import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/services.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';
import 'admin/folder_sheet.dart';

class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key, required this.folderId});

  final int folderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: adminMode,
          builder: (context, admin, _) => LibraryQuery<(Folder?, List<Story>, List<Character>)>(
            args: folderId,
            load: (library) async =>
                (await library.folder(folderId), await library.stories(folderId), await library.characters()),
            builder: (context, data) {
              final (folder, stories, characters) = data;
              if (folder == null) return const InkTopBar();
              final character = characters.firstWhere((c) => c.id == folder.characterId).name;
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  InkTopBar(
                    actions: [
                      if (admin)
                        IconButton(
                          tooltip: 'Modifier le dossier',
                          onPressed: () => showFolderSheet(context, characters: characters, folder: folder),
                          icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        ),
                    ],
                  ),
                  InkHeading(
                    eyebrow: character,
                    title: folder.name,
                    count: stories.length == 1 ? '1 histoire' : '${stories.length} histoires',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: stories.isEmpty
                        ? const InkComingSoon(text: 'Ce dossier est vide.')
                        : _StoryGrid(stories: stories),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Deux colonnes ; la hauteur de chaque tuile suit son titre.
class _StoryGrid extends StatelessWidget {
  const _StoryGrid({required this.stories});

  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final tileWidth = (box.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 24,
          children: [
            for (final story in stories)
              SizedBox(
                width: tileWidth,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, Routes.story, arguments: story.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(aspectRatio: 3 / 4, child: StoryCover(cover: story.cover)),
                      const SizedBox(height: 8),
                      Text(story.title, style: InkText.row, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
