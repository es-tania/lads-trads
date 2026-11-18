/// Panneau du bas : choisir l'image d'un personnage et placer le cercle.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../data/services.dart';
import '../../../theme/ink.dart';
import '../../../widgets/character_avatar.dart';
import '../../../widgets/image_crop.dart';
import '../../../widgets/ink_sheet.dart';
import '../../../widgets/ink_widgets.dart';
import '../../../widgets/one_line_label.dart';

/// Panneau du bas : choisir l'image d'un personnage et placer le cercle.
Future<void> showCharacterImageSheet(BuildContext context, Character character) {
  return showInkSheet<void>(context, scrollable: false, builder: (_) => _ImageSheet(character: character));
}

class _ImageSheet extends StatefulWidget {
  const _ImageSheet({required this.character});

  final Character character;

  @override
  State<_ImageSheet> createState() => _ImageSheetState();
}

class _ImageSheetState extends State<_ImageSheet> {
  /// Largeur de décodage pour l'éditeur et l'aperçu (assez fine pour un
  /// écran de téléphone, sans garder la photo entière en mémoire).
  static const _decodeWidth = 1024;

  Uint8List? _pickedBytes;
  String? _pickedName;
  ImageProvider? _image;
  late ImageCrop _crop;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final path = widget.character.imagePath;
    _image = path == null ? null : characterImage(path, width: _decodeWidth);
    _crop = widget.character.crop ?? ImageCrop.character;
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedName = file.name;
      _image = ResizeImage(MemoryImage(bytes), width: _decodeWidth);
      _crop = ImageCrop.character;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final library = context.library;
    final id = widget.character.id;
    try {
      final bytes = _pickedBytes;
      if (bytes != null) {
        await library.setCharacterImage(id, bytes, _pickedName ?? 'image.png', crop: _crop);
      } else {
        await library.setImageCrop(id, _crop);
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showInkSnack(context, 'Enregistrement impossible : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final name = widget.character.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InkSheetGrabber(color: InkColors.borderStrong),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Image de $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: InkFonts.display, fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: InkText.buttonSmall,
              ),
              child: const Text('Annuler'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (image == null)
          const _NoImage()
        else
          ResolvedImage(
            image: image,
            placeholder: const SizedBox(height: 240),
            builder: (context, img) => Column(
              children: [
                ImageCropEditor(image: img, crop: _crop, oval: true, onChanged: (c) => setState(() => _crop = c)),
                const SizedBox(height: 8),
                const Text('Glisse le cercle sur le visage', style: InkText.hint),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (image != null) ...[
              Semantics(
                label: 'Aperçu',
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: InkColors.borderSoft, spreadRadius: 1)],
                  ),
                  child: CharacterAvatar(size: 48, initial: widget.character.initial, image: image, crop: _crop),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _pick,
                style: OutlinedButton.styleFrom(
                  backgroundColor: InkColors.raised,
                  minimumSize: const Size(44, 48),
                  padding: InkSpacing.compactButton,
                  textStyle: InkText.button,
                ),
                child: const OneLineLabel('Choisir une image'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: image == null || _saving ? null : _save,
                style: FilledButton.styleFrom(padding: InkSpacing.compactButton),
                child: const OneLineLabel('Enregistrer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DashedOutlinePainter(color: InkColors.borderStrong, radius: 12),
      child: Container(
        height: 240,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(color: InkColors.bg, borderRadius: BorderRadius.circular(12)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 20, color: InkColors.textFaint),
            SizedBox(height: 8),
            Text("Aucune image pour l'instant", style: TextStyle(fontSize: 14, color: InkColors.textFaint)),
          ],
        ),
      ),
    );
  }
}
