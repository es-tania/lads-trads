import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Importer une histoire',
      bottomLabel: 'Importer',
      onBottom: () => showStepSnack(context, 'L\'import arrive à l\'étape 5.'),
      children: [
        const InkSectionLabel('Fichiers'),
        const InkComingSoon(text: 'FR.docx, EN.docx et l\'image de couverture.'),
        const SizedBox(height: 32),
        const InkSectionLabel('Classement'),
        const InkComingSoon(text: 'Personnage, dossier et titre.'),
        const SizedBox(height: 32),
        const InkSectionLabel('À vérifier'),
        InkGroup(
          children: [
            AdminLink(
              label: 'Relire ligne à ligne',
              icon: Icons.subject_rounded,
              onTap: () => Navigator.pushNamed(context, Routes.editor),
            ),
          ],
        ),
      ],
    );
  }
}
