import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../data/services.dart';
import '../../../theme/ink.dart';
import '../../../widgets/ink_labeled.dart';
import '../../../widgets/ink_segmented.dart';
import '../../../widgets/ink_sheet.dart';
import '../../../widgets/markup_field.dart';
import 'speaker_dialogs.dart';

/// Contenu saisi dans le panneau d'une réplique.
class LineDraft {
  const LineDraft({required this.kind, required this.text, this.speaker});

  final LineRowKind kind;
  final String text;
  final String? speaker;
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
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  LineDraft get _draft => LineDraft(
    kind: _kind,
    text: _text.markup,
    speaker: _kind == LineRowKind.narration ? null : _speaker,
  );

  bool get _valid => _text.text.trim().isNotEmpty && (_kind == LineRowKind.narration || _speaker != null);

  Future<void> _otherSpeaker() async {
    final name = await showDialog<String>(context: context, builder: (_) => const NewSpeakerDialog());
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
      builder: (_) => RenameSpeakerDialog(name: from, counts: counts),
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
            style: TextButton.styleFrom(foregroundColor: InkColors.danger),
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
        InkLabeled(
          gap: 8,
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
          InkLabeled(
            gap: 8,
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
        InkLabeled(
          gap: 8,
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
                          decorationColor: InkColors.strike,
                        ),
                      ),
                    ],
                  ),
                  style: InkText.hint,
                ),
              ],
            ],
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
                    foregroundColor: InkColors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: InkColors.dangerBorder),
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
        backgroundColor: InkColors.transparent,
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: InkText.buttonSmall,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
