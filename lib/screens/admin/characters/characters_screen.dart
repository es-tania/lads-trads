
import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../data/services.dart';
import '../../../theme/ink.dart';
import '../../../widgets/character_avatar.dart';
import '../../../widgets/ink_widgets.dart';
import 'add_character_dialog.dart';
import 'character_image_sheet.dart';

/// Écran admin : image et recadrage de chaque personnage, ajout d'un personnage.
class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LibraryQuery<List<Character>>(
          load: (library) => library.characters(),
          builder: (context, characters) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Retour',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    ),
                    Text('Personnages', style: InkText.screenTitle.copyWith(fontSize: 24)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Touche un personnage pour changer son image', style: InkText.eyebrow),
                    const SizedBox(height: 8),
                    InkGroup(children: [for (final c in characters) _CharacterRow(character: c)]),
                    const SizedBox(height: 16),
                    const _AddCharacterButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterRow extends StatelessWidget {
  const _CharacterRow({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final hasImage = character.imagePath != null;
    return InkRow(
      height: 64,
      label: character.name,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: hasImage ? const [BoxShadow(color: InkColors.borderSoft, spreadRadius: 1)] : null,
        ),
        child: CharacterAvatar.of(character, size: 44, dashed: true),
      ),
      trailing: Text(
        hasImage ? 'Changer' : 'Ajouter une image',
        style: TextStyle(fontSize: 14, color: hasImage ? InkColors.textMuted : InkColors.accent),
      ),
      onTap: () => showCharacterImageSheet(context, character),
    );
  }
}

class _AddCharacterButton extends StatelessWidget {
  const _AddCharacterButton();

  Future<void> _add(BuildContext context) async {
    final name = await showDialog<String>(context: context, builder: (_) => const AddCharacterDialog());
    if (name != null && context.mounted) showInkSnack(context, '$name ajouté.');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _add(context),
        child: CustomPaint(
          painter: const DashedOutlinePainter(color: InkColors.borderStrong, radius: 10),
          child: const SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: InkColors.textMuted),
                SizedBox(width: 8),
                Text('Ajouter un personnage', style: TextStyle(fontSize: 15, color: InkColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
