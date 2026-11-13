import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

class StoryAdminScreen extends StatelessWidget {
  const StoryAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Fiche de l\'histoire',
      bottomLabel: 'Enregistrer',
      onBottom: () => Navigator.maybePop(context),
      children: [
        const InkComingSoon(text: 'Couverture, titre, personnage et dossier.'),
        const SizedBox(height: 32),
        const InkSectionLabel('Contenu'),
        InkGroup(
          children: [
            AdminLink(
              label: 'Modifier les répliques',
              icon: Icons.edit_note_rounded,
              onTap: () => Navigator.pushNamed(context, Routes.editor),
            ),
            AdminLink(
              label: 'Remplacer les fichiers',
              icon: Icons.upload_file_outlined,
              onTap: () => Navigator.pushNamed(context, Routes.import),
            ),
            AdminLink(
              label: 'Exporter en .docx',
              icon: Icons.download_outlined,
              onTap: () => Navigator.pushNamed(context, Routes.export),
            ),
          ],
        ),
      ],
    );
  }
}
