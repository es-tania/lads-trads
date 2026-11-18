/// Panneau d'une branche d'un choix : son libellé, ou la supprimer.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../theme/ink.dart';
import '../../../widgets/ink_labeled.dart';
import '../../../widgets/ink_sheet.dart';

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
            style: TextButton.styleFrom(foregroundColor: InkColors.danger),
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
        InkLabeled(
          gap: 8,
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
                foregroundColor: InkColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: InkText.buttonSmall,
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
