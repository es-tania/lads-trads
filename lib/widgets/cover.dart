import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/ink.dart';
import 'image_crop.dart';

/// Couverture d'une histoire, cadrée comme choisi, ou un emplacement vide
/// s'il n'y en a pas.
class StoryCover extends StatelessWidget {
  const StoryCover({super.key, required this.cover, this.radius = 12, this.emptyLabel = 'Pas d\'image', this.decodeWidth = 400});

  final CoverImage? cover;
  final double radius;
  final String? emptyLabel;

  /// Largeur de décodage en pixels : évite de garder en mémoire des images
  /// de plusieurs mégaoctets pour une vignette.
  final int decodeWidth;

  @override
  Widget build(BuildContext context) {
    final placeholder = CoverPlaceholder(radius: radius, label: emptyLabel);
    final cover = this.cover;
    if (cover == null) return placeholder;
    final crop = cover.crop;
    if (crop != null) {
      // Un cadre plus petit agrandit l'image : on la décode plus large pour
      // qu'elle reste nette.
      final width = (decodeWidth / crop.d.clamp(ImageCrop.minSize, 1.0)).round().clamp(decodeWidth, 2048);
      return CroppedImage(
        image: ResizeImage(FileImage(File(cover.path)), width: width),
        crop: crop,
        radius: radius,
        placeholder: placeholder,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(cover.path),
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
            Text(label!, style: InkText.hint),
          ],
        ],
      ),
    );
  }
}
