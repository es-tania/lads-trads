/// Onglets des personnages en haut de la bibliothèque.
library;

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../theme/ink.dart';
import '../../widgets/character_avatar.dart';

/// Onglet d'un personnage : bulle recadrée et nom dessous.
class CharacterBubble extends StatelessWidget {
  const CharacterBubble({
    super.key,
    required this.character,
    required this.selected,
    required this.width,
    required this.onTap,
  });

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
class EditCharactersLink extends StatelessWidget {
  const EditCharactersLink({super.key});

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
