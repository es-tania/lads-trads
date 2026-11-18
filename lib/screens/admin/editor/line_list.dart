/// Liste des répliques d'une partie dans l'éditeur.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../text/line_labels.dart';
import '../../../theme/ink.dart';
import '../../../widgets/markup_field.dart';
import 'choice_block.dart';

/// Répliques d'une partie, choix et branches compris.
class EditorLineList extends StatelessWidget {
  const EditorLineList({
    super.key,
    required this.lines,
    required this.selected,
    required this.onEdit,
    required this.onInsertAfter,
    required this.onEditOption,
    required this.onAddOption,
    required this.onAddToBranch,
  });

  final List<LineRow> lines;
  final int? selected;

  /// [where] : « L.003 » ou « branche A », pour le surtitre du panneau.
  final void Function(LineRow line, String where) onEdit;
  final void Function(LineRow line, String where) onInsertAfter;
  final void Function(LineRow option, String letter, int branchLines) onEditOption;
  final void Function(LineRow choice, String nextLetter) onAddOption;
  final void Function(LineRow option, String letter) onAddToBranch;

  @override
  Widget build(BuildContext context) {
    final children = <int, List<LineRow>>{};
    for (final l in lines) {
      if (l.parentId != null) children.putIfAbsent(l.parentId!, () => []).add(l);
    }

    final rows = <Widget>[];
    // Même numérotation que la fenêtre flottante : un choix compte les
    // répliques de sa première branche.
    var number = 0;
    for (final line in lines.where((l) => l.parentId == null)) {
      if (line.kind == LineRowKind.option) continue;
      if (line.kind == LineRowKind.choice) {
        final options = children[line.id] ?? const <LineRow>[];
        rows.add(
          EditorChoiceBlock(
            number: lineLabel(number + 1),
            options: [for (final o in options) (o, children[o.id] ?? const <LineRow>[])],
            selected: selected,
            onEdit: onEdit,
            onInsertAfter: onInsertAfter,
            onEditOption: onEditOption,
            onAddOption: () => onAddOption(line, optionLetter(options.length)),
            onAddToBranch: onAddToBranch,
          ),
        );
        number += options.isEmpty ? 0 : (children[options.first.id] ?? const []).length;
        if (selected == line.id) rows.add(EditorInsertDivider(onTap: () => onInsertAfter(line, 'le choix')));
        continue;
      }
      number++;
      final where = lineLabel(number);
      rows.add(
        EditorLineTile(number: where, line: line, selected: selected == line.id, onTap: () => onEdit(line, where)),
      );
      if (selected == line.id) rows.add(EditorInsertDivider(onTap: () => onInsertAfter(line, where)));
    }
    if (rows.isEmpty) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aucune réplique dans cette partie.', style: InkText.body),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: rows);
  }
}

class EditorLineTile extends StatelessWidget {
  const EditorLineTile({
    super.key,
    required this.number,
    required this.line,
    required this.selected,
    required this.onTap,
  });

  final String number;
  final LineRow line;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: selected
              ? BoxDecoration(
                  color: InkColors.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: InkColors.accentSoft),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  number,
                  style: InkText.count.copyWith(height: 20 / 12, color: selected ? InkColors.accent : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: EditorLineText(line: line)),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.edit_outlined, size: 16, color: InkColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Personnage au-dessus du texte.
class EditorLineText extends StatelessWidget {
  const EditorLineText({super.key, required this.line, this.compact = false});

  final LineRow line;

  /// Dans une branche : personnage et texte sur la même ligne.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final speaker = line.speaker;
    final narration = line.kind == LineRowKind.narration || speaker == null;
    final textStyle = TextStyle(
      fontFamily: InkFonts.display,
      fontSize: 17,
      height: 1.4,
      color: narration ? InkColors.textMuted : InkColors.text,
      fontStyle: line.kind == LineRowKind.thought ? FontStyle.italic : FontStyle.normal,
    );
    final speakerStyle = TextStyle(
      fontFamily: InkFonts.ui,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: narration ? InkColors.textMuted : InkColors.forSpeaker(speaker),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Text.rich(
            TextSpan(
              children: [
                if (!narration) TextSpan(text: '$speaker  ', style: speakerStyle),
                markupTextSpan(line.text, style: textStyle),
              ],
            ),
          )
        else ...[
          if (!narration) ...[Text(speaker, style: speakerStyle), const SizedBox(height: 2)],
          MarkupText(line.text, style: textStyle),
        ],
      ],
    );
  }
}

/// Fine ligne avec un « + » : insère une réplique à cet endroit.
class EditorInsertDivider extends StatelessWidget {
  const EditorInsertDivider({super.key, required this.onTap, this.indent = 48});

  final VoidCallback onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Insérer une réplique ici',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: EdgeInsets.only(left: indent + 8, right: 8),
            child: const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add_rounded, size: 16, color: InkColors.textFaint),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
