import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/services.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/character_avatar.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';
import 'admin/folder_sheet.dart';

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
    showInkSnack(context, adminMode.value ? 'Mode admin activé' : 'Mode admin désactivé');
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
                  if (admin) const _EditCharactersLink(),
                  SizedBox(height: admin ? 16 : 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _CharacterContent(character: current, characters: characters, admin: admin),
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
            // Icône seule : le « + » suffit, l'infobulle garde le nom.
            IconButton.filled(
              tooltip: 'Importer',
              onPressed: () => Navigator.pushNamed(context, Routes.import, arguments: current.id),
              style: IconButton.styleFrom(
                backgroundColor: InkColors.text,
                foregroundColor: InkColors.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _characterTabs(List<Character> characters, Character current) {
    // Comme la maquette : six bulles tiennent sur un écran de 390 points.
    const itemWidth = 52.0;
    const minGap = 4.0;
    const scrollGap = 12.0;
    Widget bubble(Character character) => _CharacterBubble(
          character: character,
          selected: character.id == current.id,
          width: itemWidth,
          onTap: () => setState(() => _characterId = character.id),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        const side = 20.0 - (itemWidth - 48) / 2;
        final available = constraints.maxWidth - 2 * side;
        final fits = characters.length * itemWidth + (characters.length - 1) * minGap <= available;
        // Peu de personnages : réparties sur la largeur. Beaucoup : elles défilent.
        if (fits) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: side),
            child: Row(
              mainAxisAlignment: characters.length == 1 ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
              children: [for (final c in characters) bubble(c)],
            ),
          );
        }
        return SizedBox(
          height: _CharacterBubble.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: side),
            itemCount: characters.length,
            separatorBuilder: (_, _) => const SizedBox(width: scrollGap),
            itemBuilder: (context, i) => bubble(characters[i]),
          ),
        );
      },
    );
  }
}

/// Onglet d'un personnage : bulle recadrée et nom dessous.
class _CharacterBubble extends StatelessWidget {
  const _CharacterBubble({required this.character, required this.selected, required this.width, required this.onTap});

  /// Anneau (4) + bulle (48) + espace (8) + nom (16) + anneau sous la bulle.
  static const height = 4 + 48 + 8 + 16 + 4.0;

  final Character character;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Sélectionné : anneau clair de 2 px, décalé de 2 px.
                  boxShadow: selected
                      ? const [
                          BoxShadow(color: InkColors.text, spreadRadius: 4),
                          BoxShadow(color: InkColors.bg, spreadRadius: 2),
                        ]
                      : const [BoxShadow(color: InkColors.borderSoft, spreadRadius: 1)],
                ),
                child: ExcludeSemantics(child: CharacterAvatar.of(character, size: 48)),
              ),
              const SizedBox(height: 8),
              Text(
                character.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // L'onglet a une hauteur fixe : un texte très agrandi dans les
                // réglages du téléphone ne grandit plus au-delà de 115 %.
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? InkColors.text : InkColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lien admin vers l'écran Personnages, sous les bulles à droite.
class _EditCharactersLink extends StatelessWidget {
  const _EditCharactersLink();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pushNamed(context, Routes.characters),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: InkColors.textFaint),
                SizedBox(width: 4),
                Text('Modifier les personnages', style: TextStyle(fontSize: 12, color: InkColors.textFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Histoires récentes et dossiers du personnage choisi.
class _CharacterContent extends StatelessWidget {
  const _CharacterContent({required this.character, required this.characters, required this.admin});

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
              _RecentGrid(stories: recent),
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

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder});

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
                    if (folder.type == FolderType.other)
                      const Text('dossier perso', style: InkText.hint),
                  ],
                ),
              ),
              if (hasCovers) ...[_CoverStack(covers: folder.covers), const SizedBox(width: 12)],
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
  const _CoverStack({required this.covers});

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
