/// Dialogues du panneau d'une réplique : renommer un personnage, en choisir un autre.
library;

import 'package:material_ui/material_ui.dart';

import '../../../theme/ink.dart';

/// Nouveau nom d'un personnage, et où le changer. Renvoie (nom, partout).
class RenameSpeakerDialog extends StatefulWidget {
  const RenameSpeakerDialog({super.key, required this.name, required this.counts});

  final String name;

  /// Répliques concernées ; `null` pour un nom pas encore enregistré.
  final ({int inStory, int everywhere})? counts;

  @override
  State<RenameSpeakerDialog> createState() => _RenameSpeakerDialogState();
}

class _RenameSpeakerDialogState extends State<RenameSpeakerDialog> {
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
            Text('${_lines(counts.inStory)} dans cette histoire', style: InkText.label),
            if (others > 0)
              CheckboxListTile(
                value: _everywhere,
                onChanged: (v) => setState(() => _everywhere = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Dans toutes les histoires', style: TextStyle(fontSize: 15)),
                subtitle: Text('+ ${_lines(others)} ailleurs', style: InkText.hint),
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

class NewSpeakerDialog extends StatefulWidget {
  const NewSpeakerDialog({super.key});

  @override
  State<NewSpeakerDialog> createState() => _SpeakerDialogState();
}

class _SpeakerDialogState extends State<NewSpeakerDialog> {
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
