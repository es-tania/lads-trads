import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/ink.dart';

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
  final CharacterCrop? crop;

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
          : ResolvedImage(
              image: provider,
              placeholder: placeholder,
              builder: (context, img) => CustomPaint(
                size: Size.square(size),
                painter: _CropPainter(img, crop ?? CharacterCrop.fallback),
              ),
            ),
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
        painter: DashedOutlinePainter(color: const Color(0x33EEF0F5), radius: size / 2),
        child: Center(child: text),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: InkColors.raised, shape: BoxShape.circle),
      child: Center(child: text),
    );
  }
}

/// Peint le carré de recadrage de l'image dans un disque.
class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.crop);

  final ui.Image image;
  final CharacterCrop crop;

  @override
  void paint(Canvas canvas, Size size) {
    final source = crop.squareIn(Size(image.width.toDouble(), image.height.toDouble()));
    final dest = Offset.zero & size;
    canvas
      ..save()
      ..clipPath(Path()..addOval(dest))
      ..drawImageRect(image, source, dest, Paint()..filterQuality = FilterQuality.medium)
      ..restore();
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.crop != crop;
}

/// Décode [image] et donne l'image prête à peindre ; [placeholder] en
/// attendant, ou si le fichier est illisible.
class ResolvedImage extends StatefulWidget {
  const ResolvedImage({super.key, required this.image, required this.builder, required this.placeholder});

  final ImageProvider image;
  final Widget Function(BuildContext context, ui.Image image) builder;
  final Widget placeholder;

  @override
  State<ResolvedImage> createState() => _ResolvedImageState();
}

class _ResolvedImageState extends State<ResolvedImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener(
    (info, _) {
      if (!mounted) return;
      setState(() {
        _info?.dispose();
        _info = info;
      });
    },
    onError: (_, _) {
      if (mounted) setState(() => _info = null);
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ResolvedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return info == null ? widget.placeholder : widget.builder(context, info.image);
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
