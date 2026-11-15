import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/ink.dart';
import 'ink_sheet.dart';

/// Une image vue à travers son cadre : un cercle (personnage) ou un
/// rectangle (couverture), de la forme de la place qu'on lui donne.
class CroppedImage extends StatelessWidget {
  const CroppedImage({
    super.key,
    required this.image,
    required this.crop,
    required this.placeholder,
    this.oval = false,
    this.radius = 0,
  });

  final ImageProvider image;
  final ImageCrop crop;
  final Widget placeholder;
  final bool oval;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ResolvedImage(
      image: image,
      placeholder: placeholder,
      builder: (context, img) => CustomPaint(
        size: Size.infinite,
        painter: _CroppedPainter(img, crop, oval: oval, radius: radius),
      ),
    );
  }
}

class _CroppedPainter extends CustomPainter {
  _CroppedPainter(this.image, this.crop, {required this.oval, required this.radius});

  final ui.Image image;
  final ImageCrop crop;
  final bool oval;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final source = crop.frameIn(
      Size(image.width.toDouble(), image.height.toDouble()),
      aspect: size.width / size.height,
    );
    final dest = Offset.zero & size;
    final clip = oval
        ? (Path()..addOval(dest))
        : (Path()..addRRect(RRect.fromRectAndRadius(dest, Radius.circular(radius))));
    canvas
      ..save()
      ..clipPath(clip)
      ..drawImageRect(image, source, dest, Paint()..filterQuality = FilterQuality.medium)
      ..restore();
  }

  @override
  bool shouldRepaint(_CroppedPainter old) =>
      old.image != image || old.crop != crop || old.oval != oval || old.radius != radius;
}

/// L'image entière, avec un cadre à faire glisser et un curseur pour sa
/// taille. [aspect] : largeur sur hauteur du cadre ; [oval] : un cercle.
class ImageCropEditor extends StatelessWidget {
  const ImageCropEditor({
    super.key,
    required this.image,
    required this.crop,
    required this.onChanged,
    this.aspect = 1,
    this.oval = false,
    this.maxHeight = 360,
  });

  final ui.Image image;
  final ImageCrop crop;
  final ValueChanged<ImageCrop> onChanged;
  final double aspect;
  final bool oval;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = image.width.toDouble();
        final h = image.height.toDouble();
        final scale = math.min(constraints.maxWidth / w, maxHeight / h);
        final shown = Size(w * scale, h * scale);
        final current = crop.clampTo(shown, aspect: aspect);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Déplacer le cadrage',
              child: RawGestureDetector(
                // Le glissement part tout de suite : il ne doit pas être pris
                // par le panneau, qui se fermerait en glissant vers le bas.
                gestures: {
                  ImmediateMultiDragGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                    ImmediateMultiDragGestureRecognizer.new,
                    (recognizer) => recognizer.onStart = (_) {
                      var moving = current;
                      return _CropDrag((delta) {
                        moving = ImageCrop(
                          x: moving.x + delta.dx / shown.width,
                          y: moving.y + delta.dy / shown.height,
                          d: moving.d,
                        ).clampTo(shown, aspect: aspect);
                        onChanged(moving);
                      });
                    },
                  ),
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    size: shown,
                    painter: _EditorPainter(image, current, aspect: aspect, oval: oval),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.photo_size_select_small_rounded, size: 16, color: InkColors.textFaint),
                Expanded(
                  child: Semantics(
                    label: 'Taille du cadre',
                    child: Slider(
                      value: current.d.clamp(ImageCrop.minSize, 1.0),
                      min: ImageCrop.minSize,
                      semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                      onChanged: (d) =>
                          onChanged(ImageCrop(x: current.x, y: current.y, d: d).clampTo(shown, aspect: aspect)),
                    ),
                  ),
                ),
                const Icon(Icons.photo_size_select_large_rounded, size: 18, color: InkColors.textFaint),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CropDrag extends Drag {
  _CropDrag(this.onDelta);

  final ValueChanged<Offset> onDelta;

  @override
  void update(DragUpdateDetails details) => onDelta(details.delta);
}

class _EditorPainter extends CustomPainter {
  _EditorPainter(this.image, this.crop, {required this.aspect, required this.oval});

  final ui.Image image;
  final ImageCrop crop;
  final double aspect;
  final bool oval;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      all,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final frame = crop.frameIn(size, aspect: aspect);
    final shade = Paint()..color = const Color(0x9E0B0D14);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = InkColors.text;
    final hole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(all);
    // Extérieur du cadre assombri, contour clair.
    if (oval) {
      canvas
        ..drawPath(hole..addOval(frame), shade)
        ..drawOval(frame.deflate(1), stroke);
    } else {
      final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(6));
      canvas
        ..drawPath(hole..addRRect(rrect), shade)
        ..drawRRect(rrect.deflate(1), stroke);
    }
  }

  @override
  bool shouldRepaint(_EditorPainter old) =>
      old.image != image || old.crop != crop || old.aspect != aspect || old.oval != oval;
}

/// Panneau pour cadrer une couverture : glisser le cadre 3:4, régler sa
/// taille, voir le rendu. Renvoie le cadrage choisi, `null` si annulé.
Future<ImageCrop?> showCoverCropSheet(BuildContext context, {required ImageProvider image, ImageCrop? initial}) {
  return showInkSheet<ImageCrop>(
    context,
    builder: (_) => _CoverCropSheet(image: image, initial: initial ?? ImageCrop.full),
  );
}

class _CoverCropSheet extends StatefulWidget {
  const _CoverCropSheet({required this.image, required this.initial});

  final ImageProvider image;
  final ImageCrop initial;

  @override
  State<_CoverCropSheet> createState() => _CoverCropSheetState();
}

class _CoverCropSheetState extends State<_CoverCropSheet> {
  late var _crop = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InkSheetHeader(title: 'Cadrer la couverture'),
        const SizedBox(height: 16),
        ResolvedImage(
          image: widget.image,
          placeholder: const SizedBox(height: 240),
          builder: (context, img) => ImageCropEditor(
            image: img,
            crop: _crop,
            aspect: coverAspect,
            onChanged: (c) => setState(() => _crop = c),
          ),
        ),
        const Text(
          'Glisse le cadre, et règle sa taille avec le curseur',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: InkColors.textFaint),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Semantics(
              label: 'Aperçu',
              child: SizedBox(
                width: 48,
                height: 64,
                child: CroppedImage(image: widget.image, crop: _crop, radius: 6, placeholder: const SizedBox.shrink()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: InkSheetActions(label: 'Valider', onPressed: () => Navigator.pop(context, _crop))),
          ],
        ),
      ],
    );
  }
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

