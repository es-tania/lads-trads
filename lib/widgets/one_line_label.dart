import 'package:material_ui/material_ui.dart';

/// Texte de bouton qui reste sur une ligne : s'il manque de place (écran
/// étroit, texte agrandi dans les réglages du téléphone), il rapetisse au
/// lieu de passer à la ligne.
class OneLineLabel extends StatelessWidget {
  const OneLineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}
