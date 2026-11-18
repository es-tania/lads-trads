/// Contenu d'un personnage : histoires récentes et dossiers.
library;

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/cover.dart';
import '../../widgets/ink_widgets.dart';
import '../admin/folder_sheet.dart';

/// Histoires récentes et dossiers du personnage choisi.
class CharacterContent extends StatelessWidget {
  const CharacterContent({super.key, required this.character, required this.characters, required this.admin});

  final Character character;
  final List<Character> characters;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return LibraryQuery<(List<Story>, List<Folder>)>(
      args: character.id,
      load: (library) async => (await library.recentStories(character.id), await library.folders(character.id)),
      builder: (context, data) {
        final (recent, folders) = data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recent.isNotEmpty) ...[
              const InkSectionLabel('Ajoutées récemment'),
              RecentStoriesGrid(stories: recent),
              const SizedBox(height: 32),
            ],
            InkSectionLabel(
              'Dossiers de ${character.name}',
              trailing: admin
                  ? TextButton.icon(
                      onPressed: () => showFolderSheet(context, characters: characters, characterId: character.id),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Nouveau dossier'),
                    )
                  : null,
            ),
            if (folders.isEmpty)
              InkComingSoon(
                text: admin
                    ? 'Aucune histoire pour ${character.name}. Touche « + » en haut pour en ajouter une.'
                    : 'Aucune histoire traduite pour ${character.name} pour l\'instant.',
              )
            else
              InkGroup(children: [for (final folder in folders) FolderRow(folder: folder)]),
          ],
        );
      },
    );
  }
}

class RecentStoriesGrid extends StatelessWidget {
  const RecentStoriesGrid({super.key, required this.stories});

  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: i < stories.length
                ? InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pushNamed(context, Routes.story, arguments: stories[i].id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 3 / 4,
                          child: StoryCover(cover: stories[i].cover, radius: 10, emptyLabel: null, decodeWidth: 300),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stories[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context) {
    final hasCovers = folder.covers.isNotEmpty;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, Routes.folder, arguments: folder.id),
      child: SizedBox(
        height: hasCovers ? 64 : 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 18, color: InkColors.textFaint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name, style: InkText.row),
                    if (folder.type == FolderType.other) const Text('dossier perso', style: InkText.hint),
                  ],
                ),
              ),
              if (hasCovers) ...[CoverStack(covers: folder.covers), const SizedBox(width: 12)],
              Text('${folder.storyCount}', style: InkText.count),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jusqu'à trois couvertures qui se chevauchent.
class CoverStack extends StatelessWidget {
  const CoverStack({super.key, required this.covers});

  final List<CoverImage> covers;

  @override
  Widget build(BuildContext context) {
    const w = 24.0;
    const overlap = 8.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: w + (covers.length - 1) * (w - overlap) + 4,
        height: 36,
        child: Stack(
          children: [
            for (final (i, cover) in covers.indexed)
              Positioned(
                left: i * (w - overlap),
                top: 0,
                child: Container(
                  width: w + 4,
                  height: 36,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: InkColors.surface, borderRadius: BorderRadius.circular(6)),
                  child: StoryCover(cover: cover, radius: 4, emptyLabel: null, decodeWidth: 96),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
