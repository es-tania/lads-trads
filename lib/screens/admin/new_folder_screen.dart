import 'package:material_ui/material_ui.dart';

import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

class NewFolderScreen extends StatelessWidget {
  const NewFolderScreen({super.key, this.editing});

  /// Nom du dossier modifié, ou `null` pour une création.
  final String? editing;

  @override
  Widget build(BuildContext context) {
    final creating = editing == null;
    return AdminPage(
      modal: true,
      eyebrow: creating ? null : editing,
      title: creating ? 'Nouveau dossier' : 'Modifier le dossier',
      bottomLabel: creating ? 'Créer le dossier' : 'Enregistrer',
      onBottom: () => Navigator.maybePop(context),
      children: const [
        InkComingSoon(
          text: 'Nom, personnage et type : Memoria (4★ ou 5★), Myths, Secret Time, Tender Moment ou Autre.',
        ),
      ],
    );
  }
}
