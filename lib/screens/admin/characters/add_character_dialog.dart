/// Dialogue pour ajouter un personnage.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/library_repository.dart';
import '../../../data/services.dart';
import '../../../theme/ink.dart';

/// Demande le nom et ajoute le personnage. Renvoie le nom ajouté.
class AddCharacterDialog extends StatefulWidget {
  const AddCharacterDialog({super.key});

  @override
  State<AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<AddCharacterDialog> {
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
