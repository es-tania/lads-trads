/// Un choix dans l'éditeur, avec ses branches.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../text/line_labels.dart';
import '../../../theme/ink.dart';
import 'line_list.dart';

class EditorChoiceBlock extends StatelessWidget {
  const EditorChoiceBlock({
    super.key,
    required this.number,
    required this.options,
    required this.selected,
    required this.onEdit,
    required this.onInsertAfter,
    required this.onEditOption,
    required this.onAddOption,
    required this.onAddToBranch,
  });

  final String number;
  final List<(LineRow, List<LineRow>)> options;
  final int? selected;
  final void Function(LineRow line, String where) onEdit;
  final void Function(LineRow line, String where) onInsertAfter;
  final void Function(LineRow option, String letter, int branchLines) onEditOption;
  final VoidCallback onAddOption;
  final void Function(LineRow option, String letter) onAddToBranch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(number, style: InkText.count.copyWith(height: 28 / 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choix',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: InkColors.textMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: onAddOption,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Ajouter une branche'),
                    ),
                  ],
                ),
                for (final (i, (option, branch)) in options.indexed) ...[
                  const SizedBox(height: 12),
                  EditorBranch(
                    letter: optionLetter(i),
                    option: option,
                    lines: branch,
                    selected: selected,
                    onEdit: onEdit,
                    onInsertAfter: onInsertAfter,
                    onEditOption: () => onEditOption(option, optionLetter(i), branch.length),
                    onAdd: () => onAddToBranch(option, optionLetter(i)),
                  ),
                ],
                const SizedBox(height: 12),
                Text('--- suite commune', style: InkText.count),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditorBranch extends StatelessWidget {
  const EditorBranch({
    super.key,
    required this.letter,
    required this.option,
    required this.lines,
    required this.selected,
    required this.onEdit,
    required this.onInsertAfter,
    required this.onEditOption,
    required this.onAdd,
  });

  final String letter;
  final LineRow option;
  final List<LineRow> lines;
  final int? selected;
  final void Function(LineRow line, String where) onEdit;
  final void Function(LineRow line, String where) onInsertAfter;
  final VoidCallback onEditOption;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final where = 'branche $letter';
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: InkColors.borderStrong)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onEditOption,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$letter  ', style: InkText.count),
                      TextSpan(text: option.text),
                    ],
                  ),
                  style: InkText.label,
                ),
              ),
            ),
            for (final line in lines) ...[
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onEdit(line, where),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: selected == line.id
                      ? BoxDecoration(
                          color: InkColors.raised,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: InkColors.accentSoft),
                        )
                      : null,
                  child: EditorLineText(line: line, compact: true),
                ),
              ),
              if (selected == line.id) EditorInsertDivider(indent: 0, onTap: () => onInsertAfter(line, where)),
            ],
            if (lines.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAdd,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Ajouter une réplique'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
