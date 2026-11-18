import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/library_repository.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/image_crop.dart';
import '../../widgets/ink_widgets.dart';

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
    final name = await showDialog<String>(context: context, builder: (_) => const _AddCharacterDialog());
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

/// Demande le nom et ajoute le personnage. Renvoie le nom ajouté.
class _AddCharacterDialog extends StatefulWidget {
  const _AddCharacterDialog();

  @override
  State<_AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<_AddCharacterDialog> {
  final _name = TextEditingController();
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.library.addCharacter(name);
      if (mounted) Navigator.pop(context, name);
    } on DuplicateCharacterException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Ajout impossible : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: InkColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: InkColors.border),
      ),
      title: const Text(
        'Ajouter un personnage',
        style: TextStyle(fontFamily: InkFonts.display, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: 'Nom', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty || _saving ? null : _submit,
            child: const Text('Ajouter'),
          ),
        ),
      ],
    );
  }
}

/// Panneau du bas : choisir l'image d'un personnage et placer le cercle.
Future<void> showCharacterImageSheet(BuildContext context, Character character) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: InkColors.surface,
    barrierColor: InkColors.barrier,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: InkColors.borderSoft),
    ),
    builder: (_) => _ImageSheet(character: character),
  );
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: InkColors.borderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
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
                    textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 14),
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
                    const Text('Glisse le cercle sur le visage', style: TextStyle(fontSize: 13, color: InkColors.textFaint)),
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
                      textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 15),
                    ),
                    child: const Text('Choisir une image'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: image == null || _saving ? null : _save,
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
