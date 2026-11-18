import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../state/admin_mode.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_widgets.dart';
import 'character_content.dart';
import 'character_tabs.dart';

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
                  if (admin) const EditCharactersLink(),
                  SizedBox(height: admin ? 16 : 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CharacterContent(character: current, characters: characters, admin: admin),
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
    Widget bubble(Character character) => CharacterBubble(
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
          height: CharacterBubble.height,
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
