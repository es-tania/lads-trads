import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/services.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int? _characterId;

  void _toggleAdmin() {
    HapticFeedback.mediumImpact();
    adminMode.value = !adminMode.value;
    showStepSnack(context, adminMode.value ? 'Mode admin activé' : 'Mode admin désactivé');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: adminMode,
          builder: (context, admin, _) => LibraryQuery<List<Character>>(
            load: (library) => library.characters(),
            builder: (context, characters) {
              final current = characters.firstWhere(
                (c) => c.id == _characterId,
                orElse: () => characters.first,
              );
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _header(admin, current),
                  const SizedBox(height: 16),
                  _characterTabs(characters, current),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _CharacterContent(character: current, admin: admin),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(bool admin, Character current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin ? 'Traductions FR · admin' : 'Traductions FR', style: InkText.eyebrow),
                const SizedBox(height: 4),
                // Appui long : bascule le mode admin (connexion à l'étape 6).
                GestureDetector(
                  onLongPress: _toggleAdmin,
                  child: const Text('Bibliothèque', style: InkText.screenTitle),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Rechercher',
            onPressed: () => Navigator.pushNamed(context, Routes.search),
            style: IconButton.styleFrom(
              backgroundColor: InkColors.surface,
              side: const BorderSide(color: InkColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.search_rounded, size: 18),
          ),
          if (admin) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, Routes.import, arguments: current.id),
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.only(left: 10, right: 12),
                textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Importer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _characterTabs(List<Character> characters, Character current) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: characters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final character = characters[i];
          final selected = character.id == current.id;
          return Semantics(
            selected: selected,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _characterId = character.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? InkColors.raised : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? InkColors.borderStrong : const Color(0x00000000)),
                ),
                child: Text(
                  character.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: selected ? InkColors.text : InkColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Histoires récentes et dossiers du personnage choisi.
class _CharacterContent extends StatelessWidget {
  const _CharacterContent({required this.character, required this.admin});

  final Character character;
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
              _RecentGrid(stories: recent),
              const SizedBox(height: 32),
            ],
            InkSectionLabel(
              'Dossiers de ${character.name}',
              trailing: admin
                  ? TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, Routes.newFolder),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Nouveau dossier'),
                    )
                  : null,
            ),
            if (folders.isEmpty)
              InkComingSoon(
                text: admin
                    ? 'Aucune histoire pour ${character.name}. Touche « Importer » pour en ajouter une.'
                    : 'Aucune histoire traduite pour ${character.name} pour l\'instant.',
              )
            else
              InkGroup(children: [for (final folder in folders) _FolderRow(folder: folder)]),
          ],
        );
      },
    );
  }
}

class _RecentGrid extends StatelessWidget {
  const _RecentGrid({required this.stories});

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
                          child: StoryCover(path: stories[i].coverPath, radius: 10, emptyLabel: null, decodeWidth: 300),
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

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context) {
    final hasCovers = folder.covers.isNotEmpty;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, Routes.folder, arguments: folder.id),
      child: SizedBox(
        height: hasCovers ? 64 : 56,
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
                    if (folder.type == FolderType.other)
                      const Text('dossier perso', style: TextStyle(fontSize: 13, color: InkColors.textFaint)),
                  ],
                ),
              ),
              if (hasCovers) ...[_CoverStack(paths: folder.covers), const SizedBox(width: 12)],
              Text('${folder.storyCount}', style: InkText.count),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jusqu'à trois couvertures qui se chevauchent.
class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    const w = 24.0;
    const overlap = 8.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: w + (paths.length - 1) * (w - overlap) + 4,
        height: 36,
        child: Stack(
          children: [
            for (final (i, path) in paths.indexed)
              Positioned(
                left: i * (w - overlap),
                top: 0,
                child: Container(
                  width: w + 4,
                  height: 36,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: InkColors.surface, borderRadius: BorderRadius.circular(6)),
                  child: StoryCover(path: path, radius: 4, emptyLabel: null, decodeWidth: 96),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
