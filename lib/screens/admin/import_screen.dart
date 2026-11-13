
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../docx/docx_reader.dart';
import '../../docx/story_model.dart';
import '../../docx/story_parser.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_widgets.dart';

/// Fichier choisi par la traductrice.
class _Picked {
  const _Picked(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Dossier proposé dans la liste : existant, ou à créer à l'import.
class _FolderChoice {
  const _FolderChoice({required this.name, required this.type, this.rarity, this.id});

  final int? id;
  final String name;
  final FolderType type;
  final int? rarity;

  /// Deux choix sont le même dossier s'ils désignent le même dossier existant,
  /// ou le même type à créer.
  String get key => id != null ? 'id:$id' : 'new:${type.code}:$rarity';
}

const _defaultChoices = [
  _FolderChoice(name: 'Memoria 5★', type: FolderType.memoria, rarity: 5),
  _FolderChoice(name: 'Memoria 4★', type: FolderType.memoria, rarity: 4),
  _FolderChoice(name: 'Myths', type: FolderType.myths),
  _FolderChoice(name: 'Secret Time', type: FolderType.secretTime),
  _FolderChoice(name: 'Tender Moment', type: FolderType.tenderMoment),
];

/// Analyse dans un isolat séparé : une longue histoire (Myths) peut prendre
/// une seconde, l'interface reste fluide pendant ce temps.
ParsedStory _parseInBackground((Uint8List, Uint8List) files) => parseStoryDocx(fr: files.$1, en: files.$2);

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.characterId});

  /// Personnage sélectionné dans la bibliothèque au moment d'ouvrir l'import.
  final int? characterId;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  _Picked? _fr;
  _Picked? _en;
  _Picked? _cover;
  ParsedStory? _parsed;
  String? _error;
  var _parsing = false;
  var _saving = false;

  int? _characterId;
  String? _folderKey;
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _characterId = widget.characterId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<_Picked?> _pick({required bool image}) async {
    final file = await FilePicker.pickFile(
      type: image ? FileType.image : FileType.custom,
      allowedExtensions: image ? null : const ['docx'],
    );
    if (file == null) return null;
    return _Picked(file.name, await file.readAsBytes());
  }

  Future<void> _pickDocx({required bool french}) async {
    final picked = await _pick(image: false);
    if (picked == null || !mounted) return;
    setState(() => french ? _fr = picked : _en = picked);
    await _parse();
  }

  Future<void> _pickCover() async {
    final picked = await _pick(image: true);
    if (picked != null && mounted) setState(() => _cover = picked);
  }

  Future<void> _parse() async {
    final fr = _fr;
    final en = _en;
    if (fr == null || en == null) return;
    setState(() {
      _parsing = true;
      _error = null;
    });
    try {
      final parsed = await compute(_parseInBackground, (fr.bytes, en.bytes));
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        if (_title.text.trim().isEmpty) _title.text = parsed.title.fr;
        _folderKey ??= _guessFolder(parsed)?.key;
      });
    } on DocxFormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Lecture impossible : $e');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  /// « Into The Canvas (Memoria) » → dossier Memoria 5★ par défaut.
  _FolderChoice? _guessFolder(ParsedStory parsed) {
    final hint = (parsed.subtitle ?? '').toLowerCase();
    if (hint.contains('memoria') || hint.contains('memories')) return _defaultChoices[0];
    if (hint.contains('myth')) return _defaultChoices[2];
    if (hint.contains('secret')) return _defaultChoices[3];
    if (hint.contains('tender')) return _defaultChoices[4];
    return null;
  }

  Future<void> _import(List<_FolderChoice> choices) async {
    final parsed = _parsed;
    final characterId = _characterId;
    final choice = choices.where((c) => c.key == _folderKey).firstOrNull;
    if (parsed == null || characterId == null || choice == null) return;

    setState(() => _saving = true);
    final library = context.library;
    try {
      final folderId = choice.id ?? await library.folderFor(characterId, choice.type, rarity: choice.rarity);
      final storyId = await library.saveStory(
        folderId: folderId,
        title: _title.text,
        parsed: parsed,
        coverBytes: _cover?.bytes,
        coverName: _cover?.name,
      );
      if (!mounted) return;
      showStepSnack(context, 'Histoire importée.');
      await Navigator.pushReplacementNamed(context, Routes.story, arguments: storyId);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showStepSnack(context, 'Import impossible : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LibraryQuery<(List<Character>, List<Folder>)>(
      args: _characterId,
      load: (library) async {
        final characters = await library.characters();
        final id = _characterId ?? characters.first.id;
        return (characters, await library.folders(id));
      },
      builder: (context, data) {
        final (characters, folders) = data;
        _characterId ??= characters.first.id;
        final choices = _folderChoices(folders);
        if (!choices.any((c) => c.key == _folderKey)) _folderKey = null;
        final ready = _parsed != null && _folderKey != null && !_saving && !_parsing;

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
                          'Importer une histoire',
                          style: InkText.screenTitle.copyWith(fontSize: 24),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const InkSectionLabel('Fichiers'),
                      _filesGroup(),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFF28B82))),
                      ],
                      const SizedBox(height: 24),
                      const InkSectionLabel('Classement'),
                      _classification(characters, choices),
                      if (_parsed != null) ...[
                        const SizedBox(height: 24),
                        _Checks(parsed: _parsed!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: InkBottomAction(
            label: _saving ? 'Import en cours…' : 'Importer',
            onPressed: ready ? () => _import(choices) : null,
          ),
        );
      },
    );
  }

  List<_FolderChoice> _folderChoices(List<Folder> folders) {
    final existing = [
      for (final f in folders) _FolderChoice(id: f.id, name: f.name, type: f.type, rarity: f.rarity),
    ];
    // Types par défaut pas encore créés pour ce personnage.
    final missing = _defaultChoices.where(
      (d) => !folders.any((f) => f.type == d.type && f.rarity == d.rarity),
    );
    return [...existing, ...missing];
  }

  Widget _filesGroup() {
    final parsed = _parsed;
    final lines = parsed?.parts.fold<int>(0, (n, p) => n + p.allLines.length);
    String? frInfo;
    String? enInfo;
    if (_parsing) {
      frInfo = enInfo = 'Lecture…';
    } else if (parsed != null) {
      frInfo = '$lines répliques · ${parsed.parts.length} parties';
      enInfo = parsed.untranslated.isEmpty ? 'aligné' : 'aligné · ${parsed.untranslated.length} lignes du jeu ignorées';
    }

    return InkGroup(
      children: [
        _FileRow(
          badge: const _Badge('FR'),
          title: 'Texte français',
          detail: _fr == null ? 'Choisir FR.docx' : [_fr!.name, ?frInfo].join(' · '),
          onTap: () => _pickDocx(french: true),
          changeLabel: _fr == null ? 'Choisir' : 'Changer',
        ),
        _FileRow(
          badge: const _Badge('EN'),
          title: 'Texte anglais',
          subtitle: 'pour la synchro',
          detail: _en == null ? 'Choisir EN.docx' : [_en!.name, ?enInfo].join(' · '),
          onTap: () => _pickDocx(french: false),
          changeLabel: _en == null ? 'Choisir' : 'Changer',
        ),
        _FileRow(
          badge: _cover == null
              ? const _Badge(null)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(_cover!.bytes, width: 30, height: 40, fit: BoxFit.cover, cacheWidth: 90),
                ),
          title: 'Couverture',
          subtitle: 'facultative',
          detail: _cover?.name ?? 'Choisir une image',
          onTap: _pickCover,
          changeLabel: _cover == null ? 'Choisir' : 'Changer',
        ),
      ],
    );
  }

  Widget _classification(List<Character> characters, List<_FolderChoice> choices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(
                label: 'Personnage',
                child: DropdownButtonFormField<int>(
                  initialValue: _characterId,
                  isExpanded: true,
                  dropdownColor: InkColors.raised,
                  items: [for (final c in characters) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (id) => setState(() {
                    _characterId = id;
                    // Les dossiers existants changent avec le personnage : on
                    // garde le même type si possible.
                    final previous = choices.where((c) => c.key == _folderKey).firstOrNull;
                    _folderKey = previous == null
                        ? null
                        : _FolderChoice(name: previous.name, type: previous.type, rarity: previous.rarity).key;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Dossier',
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_characterId),
                  initialValue: _folderKey,
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
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Titre',
          child: TextField(controller: _title, textCapitalization: TextCapitalization.sentences),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: InkColors.textMuted)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: InkColors.raised, borderRadius: BorderRadius.circular(4)),
      child: text == null
          ? const Icon(Icons.image_outlined, size: 16, color: InkColors.textFaint)
          : Text(text!, style: const TextStyle(fontFamily: InkFonts.mono, fontSize: 11)),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.badge,
    required this.title,
    required this.detail,
    required this.onTap,
    required this.changeLabel,
    this.subtitle,
  });

  final Widget badge;
  final String title;
  final String? subtitle;
  final String detail;
  final VoidCallback onTap;
  final String changeLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: title,
                      style: InkText.row,
                      children: [
                        if (subtitle != null)
                          TextSpan(
                            text: '  $subtitle',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: InkColors.textFaint),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: InkText.count, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            TextButton(onPressed: onTap, child: Text(changeLabel, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }
}

/// Section « À vérifier » : avertissements du parseur.
class _Checks extends StatelessWidget {
  const _Checks({required this.parsed});

  final ParsedStory parsed;

  @override
  Widget build(BuildContext context) {
    final warnings = parsed.warnings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkSectionLabel(warnings.isEmpty ? 'À vérifier' : 'À vérifier · ${warnings.length}'),
        if (warnings.isEmpty)
          const InkComingSoon(text: 'Rien à signaler : FR et EN sont alignés.')
        else
          InkGroup(
            children: [
              for (final w in warnings.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(w.paragraph == null ? '—' : '§${w.paragraph}', style: InkText.count),
                      ),
                      Expanded(child: Text(w.message, style: const TextStyle(fontSize: 14, height: 1.35))),
                    ],
                  ),
                ),
              if (warnings.length > 20)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('… et ${warnings.length - 20} autres.', style: InkText.body),
                ),
            ],
          ),
      ],
    );
  }
}
