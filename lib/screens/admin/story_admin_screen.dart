import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/library_repository.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/cover.dart';
import '../../widgets/image_crop.dart';
import '../../widgets/ink_widgets.dart';
import 'export_sheet.dart';
import 'folder_choice.dart';
import '../../widgets/ink_labeled.dart';
import '../../widgets/one_line_label.dart';

/// Ce que la fiche affiche, chargé d'un coup.
typedef _StoryData = ({
  Story? story,
  Folder? folder,
  List<Part> parts,
  List<Character> characters,
  int? foldersOf,
  List<Folder> folders,
});

/// Fiche admin d'une histoire : couverture, titre, classement et contenu.
/// Rien n'est écrit avant « Enregistrer ».
class StoryAdminScreen extends StatefulWidget {
  const StoryAdminScreen({super.key, required this.storyId});

  final int storyId;

  @override
  State<StoryAdminScreen> createState() => _StoryAdminScreenState();
}

class _StoryAdminScreenState extends State<StoryAdminScreen> {
  final _title = TextEditingController();
  var _ready = false;

  /// Classement d'origine, pour savoir s'il a changé.
  String _originalTitle = '';
  String? _originalFolderKey;

  int? _characterId;
  String? _folderKey;

  /// Nouvelle couverture choisie, ou couverture retirée.
  Uint8List? _coverBytes;
  String? _coverName;
  var _coverRemoved = false;

  /// Cadrage choisi pour la couverture (nouvelle ou actuelle), pas encore
  /// enregistré.
  ImageCrop? _coverCrop;
  var _cropChanged = false;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<_StoryData> _load(LibraryRepository library) async {
    final story = await library.story(widget.storyId);
    final folder = story == null ? null : await library.folder(story.folderId);
    final characterId = _characterId ?? folder?.characterId;
    return (
      story: story,
      folder: folder,
      parts: story == null ? const <Part>[] : await library.parts(story.id),
      characters: await library.characters(),
      foldersOf: characterId,
      folders: characterId == null ? const <Folder>[] : await library.folders(characterId),
    );
  }

  Future<void> _pickCover() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    // On cadre tout de suite la nouvelle image ; annuler la laisse de côté.
    final crop = await showCoverCropSheet(context, image: _memoryImage(bytes));
    if (crop == null || !mounted) return;
    setState(() {
      _coverBytes = bytes;
      _coverName = file.name;
      _coverRemoved = false;
      _coverCrop = crop;
      _cropChanged = true;
    });
  }

  /// Recadre la couverture affichée (nouvelle ou actuelle).
  Future<void> _recrop(Story story) async {
    final bytes = _coverBytes;
    final ImageProvider image = bytes != null ? _memoryImage(bytes) : ResizeImage(FileImage(File(story.coverPath!)), width: 1024);
    final crop = await showCoverCropSheet(context, image: image, initial: _coverCrop ?? story.coverCrop);
    if (crop == null || !mounted) return;
    setState(() {
      _coverCrop = crop;
      _cropChanged = true;
    });
  }

  static ImageProvider _memoryImage(Uint8List bytes) => ResizeImage(MemoryImage(bytes), width: 1024);

  void _removeCover() => setState(() {
        _coverBytes = null;
        _coverName = null;
        _coverRemoved = true;
        _coverCrop = null;
        _cropChanged = false;
      });

  bool get _dirty =>
      _title.text.trim() != _originalTitle ||
      _folderKey != _originalFolderKey ||
      _coverBytes != null ||
      _coverRemoved ||
      _cropChanged;

  Future<void> _save(List<FolderChoice> choices) async {
    final choice = choices.where((c) => c.key == _folderKey).firstOrNull;
    final characterId = _characterId;
    if (choice == null || characterId == null) return;
    setState(() => _saving = true);
    final library = context.library;
    final id = widget.storyId;
    try {
      final folderId = choice.id ?? await library.folderFor(characterId, choice.type, rarity: choice.rarity);
      await library.updateStory(id, title: _title.text, folderId: folderId);
      if (_coverBytes != null) {
        await library.setCover(id, _coverBytes!, _coverName ?? 'cover.png', crop: _coverCrop);
      } else if (_coverRemoved) {
        await library.removeCover(id);
      } else if (_cropChanged && _coverCrop != null) {
        await library.setCoverCrop(id, _coverCrop!);
      }
      if (!mounted) return;
      showInkSnack(context, 'Fiche enregistrée.');
      Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showInkSnack(context, 'Enregistrement impossible : $e');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InkColors.raised,
        title: const Text('Supprimer l\'histoire ?'),
        content: const Text('Ses parties, ses répliques et sa couverture seront effacées de ce téléphone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: InkColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.library.deleteStory(widget.storyId);
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.settings.name == Routes.folder || route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return LibraryQuery<_StoryData>(
      args: _characterId,
      load: _load,
      builder: (context, data) {
        final story = data.story;
        final folder = data.folder;
        if (story == null || folder == null) {
          return const Scaffold(body: SafeArea(child: InkTopBar()));
        }
        if (!_ready) {
          _ready = true;
          _originalTitle = story.title;
          _title
            ..text = story.title
            // Branché après le remplissage : pas de setState pendant le build.
            ..addListener(() => setState(() {}));
          _characterId = folder.characterId;
          _originalFolderKey = _folderKey = 'id:${folder.id}';
        }
        final choices = folderChoices(data.folders);
        // Après un changement de personnage : « Memoria 5★ à créer » devient
        // son dossier Memoria 5★ s'il en a déjà un.
        // Seulement une fois les dossiers du nouveau personnage chargés.
        if (data.foldersOf == _characterId && _folderKey != null && !choices.any((c) => c.key == _folderKey)) {
          _folderKey = choices.where((c) => c.asNew.key == _folderKey).firstOrNull?.key;
        }
        final choice = choices.where((c) => c.key == _folderKey).firstOrNull;
        final canSave = _dirty && choice != null && _title.text.trim().isNotEmpty && !_saving;
        final lineCount = data.parts.fold<int>(0, (n, p) => n + p.lineCount);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
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
                      Expanded(
                        child: Text(
                          "Fiche de l'histoire",
                          style: InkText.screenTitle.copyWith(fontSize: 22),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _coverSection(story),
                      const SizedBox(height: 24),
                      InkLabeled(
                        label: 'Titre',
                        child: TextField(controller: _title, textCapitalization: TextCapitalization.sentences),
                      ),
                      const SizedBox(height: 16),
                      _classification(data.characters, choices),
                      const SizedBox(height: 16),
                      if (choice != null)
                        Text(
                          'Type ${choice.type == FolderType.memoria ? 'Memoria' : choice.type.label}, repris du dossier',
                          style: InkText.hint,
                        ),
                      const SizedBox(height: 24),
                      const InkSectionLabel('Contenu'),
                      InkGroup(
                        children: [
                          InkRow(
                            label: 'Modifier les dialogues',
                            leading: const Icon(Icons.edit_outlined, size: 18, color: InkColors.textFaint),
                            trailing: Text(
                              '${data.parts.length} ${data.parts.length == 1 ? 'partie' : 'parties'} · $lineCount',
                              style: InkText.count,
                            ),
                            onTap: () => Navigator.pushNamed(context, Routes.editor, arguments: story.id),
                          ),
                          InkRow(
                            label: 'Remplacer par un .docx',
                            leading: const Icon(Icons.upload_outlined, size: 18, color: InkColors.textFaint),
                            onTap: () => Navigator.pushNamed(context, Routes.replaceContent, arguments: story.id),
                          ),
                          InkRow(
                            label: 'Exporter en .docx',
                            leading: const Icon(Icons.download_outlined, size: 18, color: InkColors.textFaint),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: InkColors.textFaint),
                            onTap: () => showExportSheet(context, story),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: InkColors.danger,
                      minimumSize: const Size(44, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: InkText.button,
                    ),
                    child: const Text('Supprimer'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave ? () => _save(choices) : null,
                      child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _coverSection(Story story) {
    final Widget cover;
    if (_coverBytes != null) {
      cover = CroppedImage(
        image: _memoryImage(_coverBytes!),
        crop: _coverCrop ?? ImageCrop.full,
        radius: 12,
        placeholder: const CoverPlaceholder(label: null),
      );
    } else {
      final current = story.coverPath == null || _coverRemoved ? null : CoverImage(story.coverPath!, _coverCrop ?? story.coverCrop);
      cover = StoryCover(cover: current, emptyLabel: null, decodeWidth: 360);
    }
    final hasCover = _coverBytes != null || (!_coverRemoved && story.coverPath != null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: hasCover ? 'Couverture actuelle' : 'Pas de couverture',
          child: SizedBox(width: 120, height: 160, child: cover),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Couverture', style: InkText.label),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickCover,
                style: OutlinedButton.styleFrom(minimumSize: const Size(44, 40), padding: InkSpacing.compactButton),
                icon: const Icon(Icons.image_outlined, size: 16, color: InkColors.textMuted),
                label: OneLineLabel(hasCover ? "Changer l'image" : 'Choisir une image'),
              ),
              if (hasCover) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : () => _recrop(story),
                        style: TextButton.styleFrom(minimumSize: const Size(44, 32)),
                        child: const Text('Recadrer'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : _removeCover,
                        style: TextButton.styleFrom(minimumSize: const Size(44, 32)),
                        child: const Text('Retirer'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              const Text('Portrait 3:4 · depuis la galerie', style: TextStyle(fontSize: 12, color: InkColors.textFaint)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _classification(List<Character> characters, List<FolderChoice> choices) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkLabeled(
            label: 'Personnage',
            child: DropdownButtonFormField<int>(
              initialValue: _characterId,
              isExpanded: true,
              dropdownColor: InkColors.raised,
              items: [for (final c in characters) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (id) => setState(() {
                if (id == null || id == _characterId) return;
                _characterId = id;
                // Les dossiers changent avec le personnage : on garde le même
                // type, à créer s'il n'existe pas encore chez lui.
                final previous = choices.where((c) => c.key == _folderKey).firstOrNull;
                _folderKey = previous?.asNew.key;
              }),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkLabeled(
            label: 'Dossier',
            child: DropdownButtonFormField<String>(
              key: ValueKey(_characterId),
              initialValue: choices.any((c) => c.key == _folderKey) ? _folderKey : null,
              isExpanded: true,
              hint: const Text('Choisir'),
              dropdownColor: InkColors.raised,
              items: [
                for (final c in choices)
                  DropdownMenuItem(
                    value: c.key,
                    child: Text(c.id == null ? '${c.name} (nouveau)' : c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (key) => setState(() => _folderKey = key),
            ),
          ),
        ),
      ],
    );
  }
}

