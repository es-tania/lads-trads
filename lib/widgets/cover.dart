import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// Couverture d'une histoire, ou un emplacement vide s'il n'y en a pas.
class StoryCover extends StatelessWidget {
  const StoryCover({super.key, required this.path, this.radius = 12, this.emptyLabel = 'Pas d\'image', this.decodeWidth = 400});

  final String? path;
  final double radius;
  final String? emptyLabel;

  /// Largeur de décodage en pixels : évite de garder en mémoire des images
  /// de plusieurs mégaoctets pour une vignette.
  final int decodeWidth;

  @override
  Widget build(BuildContext context) {
    final placeholder = CoverPlaceholder(radius: radius, label: emptyLabel);
    if (path == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(path!),
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

/// Emplacement d'une couverture absente.
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
