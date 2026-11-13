import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// Emplacement d'une couverture absente (pointillés de la maquette remplacés
/// par une bordure pleine : Flutter n'a pas de bordure en pointillés native).
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({super.key, this.radius = 12, this.label = 'Pas d\'image'});

  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: InkColors.borderStrong),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 18, color: InkColors.textFaint),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(label!, style: const TextStyle(fontSize: 13, color: InkColors.textFaint)),
          ],
        ],
      ),
    );
  }
}
