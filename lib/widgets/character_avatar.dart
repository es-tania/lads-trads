import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/ink.dart';
import 'image_crop.dart';

/// Image d'un personnage dans le stockage de l'app, décodée à une taille
/// raisonnable : une photo de plusieurs mégaoctets ne reste pas en mémoire
/// pour une bulle de 48 points.
ImageProvider characterImage(String path, {int width = 512}) => ResizeImage(FileImage(File(path)), width: width);

/// Bulle ronde d'un personnage : l'image recadrée, ou l'initiale.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.size,
    required this.initial,
    this.image,
    this.crop,
    this.dashed = false,
  });

  /// Bulle d'un personnage enregistré.
  CharacterAvatar.of(Character character, {Key? key, required double size, bool dashed = false})
      : this(
          key: key,
          size: size,
          initial: character.initial,
          image: character.imagePath == null ? null : characterImage(character.imagePath!),
          crop: character.crop,
          dashed: dashed,
        );

  final double size;
  final String initial;
  final ImageProvider? image;

  /// Cercle choisi sur l'image ; `null` : cadrage par défaut.
  final ImageCrop? crop;

  /// Sans image : bordure en pointillés au lieu d'un fond plein (écran admin).
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Initial(size: size, initial: initial, dashed: dashed);
    final provider = image;
    return SizedBox.square(
      dimension: size,
      child: provider == null
          ? placeholder
          : CroppedImage(image: provider, crop: crop ?? ImageCrop.character, oval: true, placeholder: placeholder),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.size, required this.initial, required this.dashed});

  final double size;
  final String initial;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      initial,
      style: TextStyle(
        fontFamily: InkFonts.display,
        fontSize: (size * 0.36).roundToDouble(),
        fontWeight: FontWeight.w500,
        height: 1,
        color: dashed ? InkColors.textFaint : InkColors.textMuted,
      ),
    );
    if (dashed) {
      return CustomPaint(
        painter: DashedOutlinePainter(color: InkColors.borderDashed, radius: size / 2),
        child: Center(child: text),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: InkColors.raised, shape: BoxShape.circle),
      child: Center(child: text),
    );
  }
}

/// Contour en pointillés d'un rectangle arrondi (ou d'un cercle si
/// [radius] vaut la moitié du côté).
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({required this.color, required this.radius, this.dash = 4, this.gap = 3});

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(0.5);
    final outline = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, radius - 0.5))));
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter old) =>
      old.color != color || old.radius != radius || old.dash != dash || old.gap != gap;
}
