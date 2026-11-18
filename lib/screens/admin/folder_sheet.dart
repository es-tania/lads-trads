import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/library_repository.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_sheet.dart';
import '../../widgets/ink_labeled.dart';

/// Panneau du bas pour créer un dossier, ou modifier [folder].
///
/// En création, [characterId] est le personnage proposé ; le nouveau
/// dossier s'ouvre ensuite.
Future<void> showFolderSheet(
  BuildContext context, {
  required List<Character> characters,
  int? characterId,
  Folder? folder,
}) {
  return showInkSheet<void>(
    context,
    builder: (_) => _FolderSheet(
      characters: characters,
      characterId: folder?.characterId ?? characterId ?? characters.first.id,
      folder: folder,
      navigator: Navigator.of(context),
    ),
  );
}

/// Types proposés, dans l'ordre de la maquette.
const _types = [FolderType.memoria, FolderType.myths, FolderType.secretTime, FolderType.tenderMoment, FolderType.other];

class _FolderSheet extends StatefulWidget {
  const _FolderSheet({required this.characters, required this.characterId, required this.navigator, this.folder});

  final List<Character> characters;
  final int characterId;
  final Folder? folder;

  /// Navigateur de l'écran d'origine : ouvre le dossier créé, ou ferme
  /// l'écran du dossier supprimé.
  final NavigatorState navigator;

  @override
  State<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<_FolderSheet> {
  late int _characterId;
  late FolderType _type;
  late int _rarity;
  late final TextEditingController _name;

  /// Tant que le nom n'a pas été touché, il suit le type choisi.
  late bool _nameEdited;
  String? _error;
  var _saving = false;

  bool get _editing => widget.folder != null;

  @override
  void initState() {
    super.initState();
    final folder = widget.folder;
    _characterId = widget.characterId;
    _type = folder?.type ?? FolderType.memoria;
    _rarity = folder?.rarity ?? 5;
    _nameEdited = folder != null;
    _name = TextEditingController(text: folder?.name ?? _defaultName());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// « Autre » : pas de nom par défaut, la traductrice le choisit.
  String _defaultName() => _type == FolderType.other ? '' : Folder.defaultName(_type, rarity: _rarity);

  void _setType(FolderType type, {int? rarity}) {
    setState(() {
      _type = type;
      if (rarity != null) _rarity = rarity;
      _error = null;
      if (!_nameEdited) _name.text = _defaultName();
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final library = context.library;
    final rarity = _type == FolderType.memoria ? _rarity : null;
    try {
      final folder = widget.folder;
      if (folder != null) {
        await library.updateFolder(folder.id, characterId: _characterId, name: name, type: _type, rarity: rarity);
        if (mounted) Navigator.pop(context);
      } else {
        if (await library.folderNameTaken(_characterId, name)) throw DuplicateFolderException(name);
        final id = await library.createFolder(_characterId, name, _type, rarity: rarity);
        if (!mounted) return;
        Navigator.pop(context);
        await widget.navigator.pushNamed(Routes.folder, arguments: id);
      }
    } on DuplicateFolderException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Enregistrement impossible : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final folder = widget.folder!;
    final library = context.library;
    final count = (await library.stories(folder.id)).length;
    if (!mounted) return;
    if (count > 0) {
      setState(
        () => _error = count == 1
            ? 'Ce dossier contient 1 histoire : déplace-la ou supprime-la d\'abord.'
            : 'Ce dossier contient $count histoires : déplace-les ou supprime-les d\'abord.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InkColors.raised,
        title: const Text('Supprimer le dossier ?'),
        content: Text('« ${folder.name} » est vide. Il disparaîtra de la bibliothèque.'),
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
    await library.deleteFolder(folder.id);
    if (!mounted) return;
    Navigator.pop(context);
    // L'écran du dossier n'a plus rien à montrer.
    widget.navigator.popUntil((route) => route.settings.name != Routes.folder);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSheetHeader(title: _editing ? 'Modifier le dossier' : 'Nouveau dossier', titleSize: 22),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkLabeled(
                label: 'Nom',
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: inkSheetField(hint: 'Nom du dossier', strong: true),
                  onChanged: (_) => setState(() {
                    _nameEdited = true;
                    _error = null;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkLabeled(
                label: 'Personnage',
                child: DropdownButtonFormField<int>(
                  initialValue: _characterId,
                  isExpanded: true,
                  dropdownColor: InkColors.raised,
                  decoration: inkSheetField(),
                  items: [for (final c in widget.characters) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (id) => setState(() {
                    _characterId = id ?? _characterId;
                    _error = null;
                  }),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: InkText.error),
        ],
        const SizedBox(height: 20),
        InkLabeled(
          label: "Type d'histoire",
          gap: 8,
          child: _TypeList(selected: _type, onChanged: _setType),
        ),
        if (_type == FolderType.memoria) ...[
          const SizedBox(height: 20),
          InkLabeled(
            label: 'Rareté',
            gap: 8,
            child: _RarityPicker(
              value: _rarity,
              onChanged: (r) => _setType(FolderType.memoria, rarity: r),
            ),
          ),
        ],
        if (_editing) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: InkColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: InkText.buttonSmall,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Supprimer le dossier'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => InkSheetActions(
            label: _editing ? 'Enregistrer' : 'Créer le dossier',
            onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}


/// Liste de boutons radio : un type par ligne.
class _TypeList extends StatelessWidget {
  const _TypeList({required this.selected, required this.onChanged});

  final FolderType selected;
  final void Function(FolderType type) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: InkColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InkColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, type) in _types.indexed) ...[
              if (i > 0) const SizedBox(height: 2),
              _TypeOption(type: type, selected: type == selected, onTap: () => onChanged(type)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.type, required this.selected, required this.onTap});

  final FolderType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: selected ? InkColors.raised : null, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? InkColors.accent : InkColors.textFaint, width: 1.5),
                ),
                child: selected
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: InkColors.accent, shape: BoxShape.circle),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(type.label, style: const TextStyle(fontSize: 15, color: InkColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4★ ou 5★, en deux boutons côte à côte.
class _RarityPicker extends StatelessWidget {
  const _RarityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: InkColors.bg, borderRadius: BorderRadius.circular(10)),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            for (final (i, rarity) in const [4, 5].indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  selected: rarity == value,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onChanged(rarity),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rarity == value ? InkColors.raised : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$rarity★',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: rarity == value ? FontWeight.w500 : FontWeight.w400,
                          color: rarity == value ? InkColors.text : InkColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
