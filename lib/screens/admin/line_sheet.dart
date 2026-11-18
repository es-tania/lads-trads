import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_segmented.dart';
import '../../widgets/ink_sheet.dart';
import '../../widgets/markup_field.dart';

const _danger = Color(0xFFE5484D);

/// Contenu saisi dans le panneau d'une réplique.
class LineDraft {
  const LineDraft({required this.kind, required this.text, this.speaker, this.note});

  final LineRowKind kind;
  final String text;
  final String? speaker;
  final String? note;
}

/// Ce que la traductrice a demandé en fermant le panneau.
sealed class LineSheetResult {
  const LineSheetResult();
}

class LineSaved extends LineSheetResult {
  const LineSaved(this.draft);
  final LineDraft draft;
}

class LineInsert extends LineSheetResult {
  const LineInsert({required this.after});
  final bool after;
}

class LineDeleted extends LineSheetResult {
  const LineDeleted();
}

/// Ouvre le panneau d'une réplique : [line] à modifier, ou `null` pour une
/// nouvelle réplique. [speakers] : personnages proposés.
Future<LineSheetResult?> showLineSheet(
  BuildContext context, {
  required String eyebrow,
  required int storyId,
  required List<String> speakers,
  LineRow? line,
  LineDraft? initial,
}) {
  return showInkSheet<LineSheetResult>(
    context,
    builder: (_) => _LineSheet(eyebrow: eyebrow, storyId: storyId, speakers: speakers, line: line, initial: initial),
  );
}

class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.eyebrow, required this.storyId, required this.speakers, this.line, this.initial});

  final String eyebrow;

  /// Histoire de la réplique, pour renommer un personnage partout dedans.
  final int storyId;
  final List<String> speakers;
  final LineRow? line;
  final LineDraft? initial;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late LineRowKind _kind;
  String? _speaker;
  late final List<String> _speakers;
  late final MarkupController _text;
  late final TextEditingController _note;

  bool get _creating => widget.line == null;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    final initial = widget.initial;
    _kind = line?.kind ?? initial?.kind ?? LineRowKind.dialogue;
    _speaker = line?.speaker ?? initial?.speaker;
    _speakers = [...widget.speakers];
    if (_speaker != null && !_speakers.contains(_speaker)) _speakers.add(_speaker!);
    _text = MarkupController(markup: line?.text ?? initial?.text ?? '')..addListener(_refresh);
    _note = TextEditingController(text: line?.note ?? initial?.note ?? '');
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _note.dispose();
    super.dispose();
  }

  LineDraft get _draft => LineDraft(
    kind: _kind,
    text: _text.markup,
    speaker: _kind == LineRowKind.narration ? null : _speaker,
    note: _note.text,
  );

  bool get _valid => _text.text.trim().isNotEmpty && (_kind == LineRowKind.narration || _speaker != null);

  Future<void> _otherSpeaker() async {
    final name = await showDialog<String>(context: context, builder: (_) => const _SpeakerDialog());
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    setState(() {
      if (!_speakers.contains(trimmed)) _speakers.add(trimmed);
      _speaker = trimmed;
    });
  }

  /// Corrige le nom du personnage choisi dans toutes ses répliques (de
  /// l'histoire, ou de toutes les histoires).
  Future<void> _renameSpeaker() async {
    final from = _speaker;
    if (from == null) return;
    final library = context.library;
    // Un nom tapé avec « Autre » n'est pas encore en base : il change ici seulement.
    final saved = widget.speakers.contains(from);
    final counts = saved ? await library.speakerCounts(from, widget.storyId) : null;
    if (!mounted) return;
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => _RenameSpeakerDialog(name: from, counts: counts),
    );
    if (result == null || !mounted) return;
    final (to, everywhere) = result;
    if (saved) await library.renameSpeaker(from, to, storyId: everywhere ? null : widget.storyId);
    if (!mounted) return;
    setState(() {
      final i = _speakers.indexOf(from);
      _speakers.remove(to);
      _speakers.insert(i.clamp(0, _speakers.length), to);
      _speakers.remove(from);
      _speaker = to;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InkColors.raised,
        title: const Text('Supprimer la réplique ?'),
        content: const Text('Elle sera effacée de l\'histoire.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context, const LineDeleted());
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final changedText = line != null && _text.markup.trim() != line.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSheetHeader(eyebrow: widget.eyebrow, title: _creating ? 'Nouvelle réplique' : 'Modifier la réplique'),
        const SizedBox(height: 20),
        _Labeled(
          label: 'Type',
          child: InkSegmented<LineRowKind>(
            value: _kind,
            options: const {
              LineRowKind.dialogue: 'Réplique',
              LineRowKind.thought: 'Pensée',
              LineRowKind.narration: 'Narration',
            },
            onChanged: (k) => setState(() {
              _kind = k;
              // Une pensée est celle de « Moi » dans les histoires du jeu.
              if (k == LineRowKind.thought && _speaker == null) _speaker = 'Moi';
            }),
          ),
        ),
        if (_kind != LineRowKind.narration) ...[
          const SizedBox(height: 20),
          _Labeled(
            label: 'Personnage',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _speakers)
                  _SpeakerChip(name: name, selected: name == _speaker, onTap: () => setState(() => _speaker = name)),
                _SpeakerChip(name: 'Autre', other: true, onTap: _otherSpeaker),
              ],
            ),
          ),
          if (_speaker != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _renameSpeaker,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 13),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text('Renommer « $_speaker »', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
        const SizedBox(height: 20),
        _Labeled(
          label: 'Texte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkupField(
                controller: _text,
                autofocus: _creating,
                minLines: 3,
                maxLines: 8,
                style: const TextStyle(fontFamily: InkFonts.display, fontSize: 19, height: 1.4, color: InkColors.text),
                decoration: inkSheetField(strong: true),
              ),
              if (changedText) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Avant : ',
                    children: [
                      markupTextSpan(
                        line.text,
                        style: const TextStyle(
                          fontFamily: InkFonts.display,
                          fontSize: 15,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Color(0x4DEEF0F5),
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13, color: InkColors.textFaint),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Labeled(
          label: 'Note de traduction',
          child: TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: inkSheetField(hint: 'Visible seulement en admin'),
          ),
        ),
        if (!_creating) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SmallButton(
                  label: 'Insérer avant',
                  onTap: () => Navigator.pop(context, const LineInsert(after: false)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallButton(
                  label: 'Insérer après',
                  onTap: () => Navigator.pop(context, const LineInsert(after: true)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: 'Supprimer la réplique',
                  onPressed: _delete,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    foregroundColor: _danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0x4DE5484D)),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        InkSheetActions(
          label: _creating ? 'Ajouter' : 'Enregistrer',
          onPressed: _valid ? () => Navigator.pop(context, LineSaved(_draft)) : null,
        ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: InkColors.textMuted)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SpeakerChip extends StatelessWidget {
  const _SpeakerChip({required this.name, required this.onTap, this.selected = false, this.other = false});

  final String name;
  final bool selected;
  final bool other;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 36,
            // Un nom très long est coupé avec « … ».
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? InkColors.raised : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected || other ? InkColors.borderStrong : InkColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!other) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: InkColors.forSpeaker(name), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(Icons.add_rounded, size: 14, color: InkColors.textMuted),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Tooltip(
                    message: name,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: selected ? InkColors.text : InkColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0x00000000),
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 14),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Nouveau nom d'un personnage, et où le changer. Renvoie (nom, partout).
class _RenameSpeakerDialog extends StatefulWidget {
  const _RenameSpeakerDialog({required this.name, required this.counts});

  final String name;

  /// Répliques concernées ; `null` pour un nom pas encore enregistré.
  final ({int inStory, int everywhere})? counts;

  @override
  State<_RenameSpeakerDialog> createState() => _RenameSpeakerDialogState();
}

class _RenameSpeakerDialogState extends State<_RenameSpeakerDialog> {
  late final _name = TextEditingController(text: widget.name)..addListener(() => setState(() {}));
  var _everywhere = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static String _lines(int n) => n == 1 ? '1 réplique' : '$n répliques';

  @override
  Widget build(BuildContext context) {
    final counts = widget.counts;
    final to = _name.text.trim();
    final others = counts == null ? 0 : counts.everywhere - counts.inStory;
    return AlertDialog(
      backgroundColor: InkColors.surface,
      title: const Text('Renommer le personnage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Nom'),
          ),
          if (counts != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_lines(counts.inStory)} dans cette histoire',
              style: const TextStyle(fontSize: 13, color: InkColors.textMuted),
            ),
            if (others > 0)
              CheckboxListTile(
                value: _everywhere,
                onChanged: (v) => setState(() => _everywhere = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Dans toutes les histoires', style: TextStyle(fontSize: 15)),
                subtitle: Text(
                  '+ ${_lines(others)} ailleurs',
                  style: const TextStyle(fontSize: 13, color: InkColors.textFaint),
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: to.isEmpty || to == widget.name ? null : () => Navigator.pop(context, (to, _everywhere)),
          child: const Text('Renommer'),
        ),
      ],
    );
  }
}

class _SpeakerDialog extends StatefulWidget {
  const _SpeakerDialog();

  @override
  State<_SpeakerDialog> createState() => _SpeakerDialogState();
}

class _SpeakerDialogState extends State<_SpeakerDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: InkColors.surface,
      title: const Text('Autre personnage'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Nom'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, _name.text),
            child: const Text('Choisir'),
          ),
        ),
      ],
    );
  }
}

/// Panneau d'une branche : renommer, supprimer, ou créer ([option] `null`).
Future<OptionSheetResult?> showOptionSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  LineRow? option,
  int branchLines = 0,
}) {
  return showInkSheet<OptionSheetResult>(
    context,
    builder: (_) => _OptionSheet(eyebrow: eyebrow, title: title, option: option, branchLines: branchLines),
  );
}

sealed class OptionSheetResult {
  const OptionSheetResult();
}

class OptionSaved extends OptionSheetResult {
  const OptionSaved(this.label);
  final String label;
}

class OptionDeleted extends OptionSheetResult {
  const OptionDeleted();
}

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({required this.eyebrow, required this.title, required this.branchLines, this.option});

  final String eyebrow;
  final String title;
  final LineRow? option;
  final int branchLines;

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late final _label = TextEditingController(text: widget.option?.text ?? '')..addListener(() => setState(() {}));

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final n = widget.branchLines;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InkColors.raised,
        title: const Text('Supprimer la branche ?'),
        content: Text(
          n == 0
              ? 'La branche est vide.'
              : n == 1
              ? 'Sa réplique sera effacée aussi.'
              : 'Ses $n répliques seront effacées aussi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context, const OptionDeleted());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSheetHeader(eyebrow: widget.eyebrow, title: widget.title),
        const SizedBox(height: 20),
        _Labeled(
          label: 'Libellé du choix',
          child: TextField(
            controller: _label,
            autofocus: widget.option == null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontFamily: InkFonts.display, fontSize: 18, color: InkColors.text),
            decoration: inkSheetField(strong: true),
          ),
        ),
        if (widget.option != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(
                foregroundColor: _danger,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 14),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Supprimer la branche'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        InkSheetActions(
          label: widget.option == null ? 'Ajouter' : 'Enregistrer',
          onPressed: _label.text.trim().isEmpty ? null : () => Navigator.pop(context, OptionSaved(_label.text)),
        ),
      ],
    );
  }
}
